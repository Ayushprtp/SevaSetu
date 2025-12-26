-- ============================================
-- SEVASETU ADMIN HIERARCHY SYSTEM
-- ============================================
-- Hierarchy: System Admin > State Admin > Department Admin > Office Admin > Worker
-- Each level can manage the level below them
-- ============================================

-- SECTION 1: Create admin_roles table
CREATE TABLE IF NOT EXISTS admin_roles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('system_admin', 'state_admin', 'department_admin', 'office_admin', 'worker')),
    -- Scope of authority
    state TEXT,                    -- For state_admin and below
    department TEXT,               -- For department_admin and below
    office_id UUID REFERENCES offices(id) ON DELETE SET NULL,  -- For office_admin and worker
    -- Who created this role
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    -- Ensure unique role per scope
    UNIQUE(user_id, role, state, department, office_id)
);

-- SECTION 2: Create indexes
CREATE INDEX IF NOT EXISTS idx_admin_roles_user ON admin_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_roles_role ON admin_roles(role);
CREATE INDEX IF NOT EXISTS idx_admin_roles_state ON admin_roles(state);
CREATE INDEX IF NOT EXISTS idx_admin_roles_department ON admin_roles(department);
CREATE INDEX IF NOT EXISTS idx_admin_roles_office ON admin_roles(office_id);
CREATE INDEX IF NOT EXISTS idx_admin_roles_created_by ON admin_roles(created_by);

-- SECTION 3: Enable RLS
ALTER TABLE admin_roles ENABLE ROW LEVEL SECURITY;

-- SECTION 4: RLS Policies for admin_roles
-- System admins can see all roles
DROP POLICY IF EXISTS "system_admin_full_access" ON admin_roles;
CREATE POLICY "system_admin_full_access" ON admin_roles
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admin_roles ar 
            WHERE ar.user_id = auth.uid() 
            AND ar.role = 'system_admin' 
            AND ar.is_active = TRUE
        )
    );

-- Users can see their own roles
DROP POLICY IF EXISTS "users_view_own_roles" ON admin_roles;
CREATE POLICY "users_view_own_roles" ON admin_roles
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- State admins can see roles in their state
DROP POLICY IF EXISTS "state_admin_view_state_roles" ON admin_roles;
CREATE POLICY "state_admin_view_state_roles" ON admin_roles
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admin_roles ar 
            WHERE ar.user_id = auth.uid() 
            AND ar.role = 'state_admin' 
            AND ar.state = admin_roles.state
            AND ar.is_active = TRUE
        )
    );

-- SECTION 5: Function to check if user has a specific role
CREATE OR REPLACE FUNCTION has_role(p_user_id UUID, p_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM admin_roles 
        WHERE user_id = p_user_id 
        AND role = p_role 
        AND is_active = TRUE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 6: Function to check if user can manage another user
CREATE OR REPLACE FUNCTION can_manage_user(p_manager_id UUID, p_target_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    manager_role TEXT;
    manager_state TEXT;
    manager_dept TEXT;
    manager_office UUID;
    target_role TEXT;
    target_state TEXT;
    target_dept TEXT;
    target_office UUID;
BEGIN
    -- Get manager's highest role
    SELECT role, state, department, office_id 
    INTO manager_role, manager_state, manager_dept, manager_office
    FROM admin_roles 
    WHERE user_id = p_manager_id AND is_active = TRUE
    ORDER BY 
        CASE role 
            WHEN 'system_admin' THEN 1
            WHEN 'state_admin' THEN 2
            WHEN 'department_admin' THEN 3
            WHEN 'office_admin' THEN 4
            WHEN 'worker' THEN 5
        END
    LIMIT 1;

    -- Get target's role
    SELECT role, state, department, office_id 
    INTO target_role, target_state, target_dept, target_office
    FROM admin_roles 
    WHERE user_id = p_target_user_id AND is_active = TRUE
    ORDER BY 
        CASE role 
            WHEN 'system_admin' THEN 1
            WHEN 'state_admin' THEN 2
            WHEN 'department_admin' THEN 3
            WHEN 'office_admin' THEN 4
            WHEN 'worker' THEN 5
        END
    LIMIT 1;

    -- System admin can manage everyone except other system admins
    IF manager_role = 'system_admin' THEN
        RETURN target_role != 'system_admin' OR target_role IS NULL;
    END IF;

    -- State admin can manage department_admin, office_admin, worker in their state
    IF manager_role = 'state_admin' THEN
        RETURN target_role IN ('department_admin', 'office_admin', 'worker') 
            AND target_state = manager_state;
    END IF;

    -- Department admin can manage office_admin, worker in their department
    IF manager_role = 'department_admin' THEN
        RETURN target_role IN ('office_admin', 'worker') 
            AND target_state = manager_state 
            AND target_dept = manager_dept;
    END IF;

    -- Office admin can manage workers in their office
    IF manager_role = 'office_admin' THEN
        RETURN target_role = 'worker' 
            AND target_office = manager_office;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 7: Function to get user's role info
CREATE OR REPLACE FUNCTION get_user_role(p_user_id UUID)
RETURNS TABLE (
    role TEXT,
    state TEXT,
    department TEXT,
    office_id UUID,
    office_name TEXT,
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ar.role,
        ar.state,
        ar.department,
        ar.office_id,
        o.name as office_name,
        ar.is_active
    FROM admin_roles ar
    LEFT JOIN offices o ON ar.office_id = o.id
    WHERE ar.user_id = p_user_id AND ar.is_active = TRUE
    ORDER BY 
        CASE ar.role 
            WHEN 'system_admin' THEN 1
            WHEN 'state_admin' THEN 2
            WHEN 'department_admin' THEN 3
            WHEN 'office_admin' THEN 4
            WHEN 'worker' THEN 5
        END
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 8: Function to add a new admin (with permission check)
CREATE OR REPLACE FUNCTION add_admin_role(
    p_target_user_id UUID,
    p_role TEXT,
    p_state TEXT DEFAULT NULL,
    p_department TEXT DEFAULT NULL,
    p_office_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    caller_id UUID;
    caller_role TEXT;
    caller_state TEXT;
    caller_dept TEXT;
    new_role_id UUID;
BEGIN
    caller_id := auth.uid();
    
    -- Get caller's role
    SELECT role, state, department INTO caller_role, caller_state, caller_dept
    FROM admin_roles 
    WHERE user_id = caller_id AND is_active = TRUE
    ORDER BY 
        CASE role 
            WHEN 'system_admin' THEN 1
            WHEN 'state_admin' THEN 2
            WHEN 'department_admin' THEN 3
            WHEN 'office_admin' THEN 4
        END
    LIMIT 1;

    -- Permission checks
    IF caller_role IS NULL THEN
        RAISE EXCEPTION 'You do not have permission to add admin roles';
    END IF;

    -- System admin can add state_admin
    IF p_role = 'state_admin' AND caller_role != 'system_admin' THEN
        RAISE EXCEPTION 'Only system admin can add state admins';
    END IF;

    -- State admin can add department_admin in their state
    IF p_role = 'department_admin' THEN
        IF caller_role NOT IN ('system_admin', 'state_admin') THEN
            RAISE EXCEPTION 'Only system/state admin can add department admins';
        END IF;
        IF caller_role = 'state_admin' AND caller_state != p_state THEN
            RAISE EXCEPTION 'You can only add department admins in your state';
        END IF;
    END IF;

    -- Department admin can add office_admin in their department
    IF p_role = 'office_admin' THEN
        IF caller_role NOT IN ('system_admin', 'state_admin', 'department_admin') THEN
            RAISE EXCEPTION 'You do not have permission to add office admins';
        END IF;
        IF caller_role = 'department_admin' AND (caller_state != p_state OR caller_dept != p_department) THEN
            RAISE EXCEPTION 'You can only add office admins in your department';
        END IF;
    END IF;

    -- Office admin can add workers in their office
    IF p_role = 'worker' THEN
        IF caller_role NOT IN ('system_admin', 'state_admin', 'department_admin', 'office_admin') THEN
            RAISE EXCEPTION 'You do not have permission to add workers';
        END IF;
    END IF;

    -- Insert the new role
    INSERT INTO admin_roles (user_id, role, state, department, office_id, created_by)
    VALUES (p_target_user_id, p_role, p_state, p_department, p_office_id, caller_id)
    RETURNING id INTO new_role_id;

    RETURN new_role_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 9: Function to remove admin role (with permission check)
CREATE OR REPLACE FUNCTION remove_admin_role(p_role_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    caller_id UUID;
    target_user_id UUID;
BEGIN
    caller_id := auth.uid();
    
    SELECT user_id INTO target_user_id FROM admin_roles WHERE id = p_role_id;
    
    IF NOT can_manage_user(caller_id, target_user_id) THEN
        RAISE EXCEPTION 'You do not have permission to remove this role';
    END IF;

    UPDATE admin_roles SET is_active = FALSE, updated_at = NOW() WHERE id = p_role_id;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 10: Function to get users manageable by current user
CREATE OR REPLACE FUNCTION get_manageable_users()
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    role TEXT,
    state TEXT,
    department TEXT,
    office_name TEXT,
    created_at TIMESTAMP
) AS $$
DECLARE
    caller_id UUID;
    caller_role TEXT;
    caller_state TEXT;
    caller_dept TEXT;
    caller_office UUID;
BEGIN
    caller_id := auth.uid();
    
    SELECT ar.role, ar.state, ar.department, ar.office_id 
    INTO caller_role, caller_state, caller_dept, caller_office
    FROM admin_roles ar
    WHERE ar.user_id = caller_id AND ar.is_active = TRUE
    ORDER BY 
        CASE ar.role 
            WHEN 'system_admin' THEN 1
            WHEN 'state_admin' THEN 2
            WHEN 'department_admin' THEN 3
            WHEN 'office_admin' THEN 4
        END
    LIMIT 1;

    IF caller_role = 'system_admin' THEN
        RETURN QUERY
        SELECT ar.user_id, u.email, ar.role, ar.state, ar.department, o.name, ar.created_at
        FROM admin_roles ar
        JOIN auth.users u ON ar.user_id = u.id
        LEFT JOIN offices o ON ar.office_id = o.id
        WHERE ar.is_active = TRUE AND ar.role != 'system_admin';
    ELSIF caller_role = 'state_admin' THEN
        RETURN QUERY
        SELECT ar.user_id, u.email, ar.role, ar.state, ar.department, o.name, ar.created_at
        FROM admin_roles ar
        JOIN auth.users u ON ar.user_id = u.id
        LEFT JOIN offices o ON ar.office_id = o.id
        WHERE ar.is_active = TRUE 
        AND ar.state = caller_state 
        AND ar.role IN ('department_admin', 'office_admin', 'worker');
    ELSIF caller_role = 'department_admin' THEN
        RETURN QUERY
        SELECT ar.user_id, u.email, ar.role, ar.state, ar.department, o.name, ar.created_at
        FROM admin_roles ar
        JOIN auth.users u ON ar.user_id = u.id
        LEFT JOIN offices o ON ar.office_id = o.id
        WHERE ar.is_active = TRUE 
        AND ar.state = caller_state 
        AND ar.department = caller_dept
        AND ar.role IN ('office_admin', 'worker');
    ELSIF caller_role = 'office_admin' THEN
        RETURN QUERY
        SELECT ar.user_id, u.email, ar.role, ar.state, ar.department, o.name, ar.created_at
        FROM admin_roles ar
        JOIN auth.users u ON ar.user_id = u.id
        LEFT JOIN offices o ON ar.office_id = o.id
        WHERE ar.is_active = TRUE 
        AND ar.office_id = caller_office
        AND ar.role = 'worker';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 11: Function to get issues for admin based on their scope
CREATE OR REPLACE FUNCTION get_admin_issues(
    p_status TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    category TEXT,
    description TEXT,
    address TEXT,
    status TEXT,
    priority_score INTEGER,
    is_high_priority BOOLEAN,
    created_at TIMESTAMP,
    assigned_department TEXT,
    assigned_office_name TEXT
) AS $$
DECLARE
    caller_id UUID;
    caller_role TEXT;
    caller_state TEXT;
    caller_dept TEXT;
    caller_office UUID;
BEGIN
    caller_id := auth.uid();
    
    SELECT ar.role, ar.state, ar.department, ar.office_id 
    INTO caller_role, caller_state, caller_dept, caller_office
    FROM admin_roles ar
    WHERE ar.user_id = caller_id AND ar.is_active = TRUE
    ORDER BY 
        CASE ar.role 
            WHEN 'system_admin' THEN 1
            WHEN 'state_admin' THEN 2
            WHEN 'department_admin' THEN 3
            WHEN 'office_admin' THEN 4
            WHEN 'worker' THEN 5
        END
    LIMIT 1;

    IF caller_role = 'system_admin' THEN
        RETURN QUERY
        SELECT ci.id, ci.category, ci.description, ci.address, ci.status, 
               ci.priority_score, ci.is_high_priority, ci.created_at,
               ci.assigned_department, o.name
        FROM civic_issues ci
        LEFT JOIN offices o ON ci.assigned_office_id = o.id
        WHERE (p_status IS NULL OR ci.status = p_status)
        ORDER BY ci.priority_score DESC, ci.created_at DESC
        LIMIT p_limit OFFSET p_offset;
    ELSIF caller_role = 'state_admin' THEN
        RETURN QUERY
        SELECT ci.id, ci.category, ci.description, ci.address, ci.status, 
               ci.priority_score, ci.is_high_priority, ci.created_at,
               ci.assigned_department, o.name
        FROM civic_issues ci
        LEFT JOIN offices o ON ci.assigned_office_id = o.id
        WHERE ci.state = caller_state
        AND (p_status IS NULL OR ci.status = p_status)
        ORDER BY ci.priority_score DESC, ci.created_at DESC
        LIMIT p_limit OFFSET p_offset;
    ELSIF caller_role = 'department_admin' THEN
        RETURN QUERY
        SELECT ci.id, ci.category, ci.description, ci.address, ci.status, 
               ci.priority_score, ci.is_high_priority, ci.created_at,
               ci.assigned_department, o.name
        FROM civic_issues ci
        LEFT JOIN offices o ON ci.assigned_office_id = o.id
        WHERE ci.state = caller_state
        AND ci.assigned_department = caller_dept
        AND (p_status IS NULL OR ci.status = p_status)
        ORDER BY ci.priority_score DESC, ci.created_at DESC
        LIMIT p_limit OFFSET p_offset;
    ELSIF caller_role IN ('office_admin', 'worker') THEN
        RETURN QUERY
        SELECT ci.id, ci.category, ci.description, ci.address, ci.status, 
               ci.priority_score, ci.is_high_priority, ci.created_at,
               ci.assigned_department, o.name
        FROM civic_issues ci
        LEFT JOIN offices o ON ci.assigned_office_id = o.id
        WHERE ci.assigned_office_id = caller_office
        AND (p_status IS NULL OR ci.status = p_status)
        ORDER BY ci.priority_score DESC, ci.created_at DESC
        LIMIT p_limit OFFSET p_offset;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 12: Add comments
COMMENT ON TABLE admin_roles IS 'Hierarchical admin roles: system_admin > state_admin > department_admin > office_admin > worker';
COMMENT ON FUNCTION has_role IS 'Check if a user has a specific role';
COMMENT ON FUNCTION can_manage_user IS 'Check if one user can manage another based on hierarchy';
COMMENT ON FUNCTION add_admin_role IS 'Add a new admin role with permission checks';
COMMENT ON FUNCTION get_admin_issues IS 'Get issues visible to the current admin based on their scope';

-- ============================================
-- ADMIN HIERARCHY MIGRATION COMPLETE!
-- ============================================
