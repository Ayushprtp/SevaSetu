-- ============================================
-- SEVASETU ADMIN ANALYTICS FUNCTIONS
-- ============================================

-- SECTION 1: Get analytics for system admin (all states)
CREATE OR REPLACE FUNCTION get_system_analytics()
RETURNS TABLE (
    total_issues BIGINT,
    pending_issues BIGINT,
    in_progress_issues BIGINT,
    resolved_issues BIGINT,
    high_priority_issues BIGINT,
    avg_priority_score NUMERIC,
    issues_today BIGINT,
    issues_this_week BIGINT,
    total_offices BIGINT,
    total_admins BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_issues,
        COUNT(*) FILTER (WHERE ci.status = 'reported')::BIGINT as pending_issues,
        COUNT(*) FILTER (WHERE ci.status IN ('assigned', 'in_progress'))::BIGINT as in_progress_issues,
        COUNT(*) FILTER (WHERE ci.status IN ('resolved', 'completed'))::BIGINT as resolved_issues,
        COUNT(*) FILTER (WHERE ci.is_high_priority = TRUE)::BIGINT as high_priority_issues,
        COALESCE(AVG(ci.priority_score), 0)::NUMERIC as avg_priority_score,
        COUNT(*) FILTER (WHERE ci.created_at >= CURRENT_DATE)::BIGINT as issues_today,
        COUNT(*) FILTER (WHERE ci.created_at >= CURRENT_DATE - INTERVAL '7 days')::BIGINT as issues_this_week,
        (SELECT COUNT(*) FROM offices)::BIGINT as total_offices,
        (SELECT COUNT(*) FROM admin_roles WHERE is_active = TRUE)::BIGINT as total_admins
    FROM civic_issues ci;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 2: Get state-wise breakdown for system admin
CREATE OR REPLACE FUNCTION get_state_breakdown()
RETURNS TABLE (
    state TEXT,
    total_issues BIGINT,
    pending_issues BIGINT,
    resolved_issues BIGINT,
    high_priority_issues BIGINT,
    avg_resolution_days NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ci.state,
        COUNT(*)::BIGINT as total_issues,
        COUNT(*) FILTER (WHERE ci.status = 'reported')::BIGINT as pending_issues,
        COUNT(*) FILTER (WHERE ci.status IN ('resolved', 'completed'))::BIGINT as resolved_issues,
        COUNT(*) FILTER (WHERE ci.is_high_priority = TRUE)::BIGINT as high_priority_issues,
        COALESCE(AVG(
            CASE WHEN ci.status IN ('resolved', 'completed') 
            THEN EXTRACT(EPOCH FROM (ci.updated_at - ci.created_at)) / 86400 
            END
        ), 0)::NUMERIC as avg_resolution_days
    FROM civic_issues ci
    WHERE ci.state IS NOT NULL
    GROUP BY ci.state
    ORDER BY total_issues DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 3: Get analytics for state admin
CREATE OR REPLACE FUNCTION get_state_analytics(p_state TEXT)
RETURNS TABLE (
    total_issues BIGINT,
    pending_issues BIGINT,
    in_progress_issues BIGINT,
    resolved_issues BIGINT,
    high_priority_issues BIGINT,
    avg_priority_score NUMERIC,
    issues_today BIGINT,
    issues_this_week BIGINT,
    total_offices BIGINT,
    total_workers BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_issues,
        COUNT(*) FILTER (WHERE ci.status = 'reported')::BIGINT as pending_issues,
        COUNT(*) FILTER (WHERE ci.status IN ('assigned', 'in_progress'))::BIGINT as in_progress_issues,
        COUNT(*) FILTER (WHERE ci.status IN ('resolved', 'completed'))::BIGINT as resolved_issues,
        COUNT(*) FILTER (WHERE ci.is_high_priority = TRUE)::BIGINT as high_priority_issues,
        COALESCE(AVG(ci.priority_score), 0)::NUMERIC as avg_priority_score,
        COUNT(*) FILTER (WHERE ci.created_at >= CURRENT_DATE)::BIGINT as issues_today,
        COUNT(*) FILTER (WHERE ci.created_at >= CURRENT_DATE - INTERVAL '7 days')::BIGINT as issues_this_week,
        (SELECT COUNT(*) FROM offices WHERE offices.state = p_state)::BIGINT as total_offices,
        (SELECT COUNT(*) FROM admin_roles WHERE admin_roles.state = p_state AND role = 'worker' AND is_active = TRUE)::BIGINT as total_workers
    FROM civic_issues ci
    WHERE ci.state = p_state;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 4: Get department breakdown for state admin
CREATE OR REPLACE FUNCTION get_department_breakdown(p_state TEXT)
RETURNS TABLE (
    department TEXT,
    total_issues BIGINT,
    pending_issues BIGINT,
    resolved_issues BIGINT,
    high_priority_issues BIGINT,
    avg_resolution_days NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ci.assigned_department as department,
        COUNT(*)::BIGINT as total_issues,
        COUNT(*) FILTER (WHERE ci.status = 'reported')::BIGINT as pending_issues,
        COUNT(*) FILTER (WHERE ci.status IN ('resolved', 'completed'))::BIGINT as resolved_issues,
        COUNT(*) FILTER (WHERE ci.is_high_priority = TRUE)::BIGINT as high_priority_issues,
        COALESCE(AVG(
            CASE WHEN ci.status IN ('resolved', 'completed') 
            THEN EXTRACT(EPOCH FROM (ci.updated_at - ci.created_at)) / 86400 
            END
        ), 0)::NUMERIC as avg_resolution_days
    FROM civic_issues ci
    WHERE ci.state = p_state AND ci.assigned_department IS NOT NULL
    GROUP BY ci.assigned_department
    ORDER BY total_issues DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 5: Get analytics for department admin
CREATE OR REPLACE FUNCTION get_department_analytics(p_state TEXT, p_department TEXT)
RETURNS TABLE (
    total_issues BIGINT,
    pending_issues BIGINT,
    in_progress_issues BIGINT,
    resolved_issues BIGINT,
    high_priority_issues BIGINT,
    avg_priority_score NUMERIC,
    issues_today BIGINT,
    issues_this_week BIGINT,
    total_offices BIGINT,
    total_workers BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_issues,
        COUNT(*) FILTER (WHERE ci.status = 'reported')::BIGINT as pending_issues,
        COUNT(*) FILTER (WHERE ci.status IN ('assigned', 'in_progress'))::BIGINT as in_progress_issues,
        COUNT(*) FILTER (WHERE ci.status IN ('resolved', 'completed'))::BIGINT as resolved_issues,
        COUNT(*) FILTER (WHERE ci.is_high_priority = TRUE)::BIGINT as high_priority_issues,
        COALESCE(AVG(ci.priority_score), 0)::NUMERIC as avg_priority_score,
        COUNT(*) FILTER (WHERE ci.created_at >= CURRENT_DATE)::BIGINT as issues_today,
        COUNT(*) FILTER (WHERE ci.created_at >= CURRENT_DATE - INTERVAL '7 days')::BIGINT as issues_this_week,
        (SELECT COUNT(*) FROM offices WHERE offices.state = p_state AND offices.department = p_department)::BIGINT as total_offices,
        (SELECT COUNT(*) FROM admin_roles WHERE admin_roles.state = p_state AND admin_roles.department = p_department AND role = 'worker' AND is_active = TRUE)::BIGINT as total_workers
    FROM civic_issues ci
    WHERE ci.state = p_state AND ci.assigned_department = p_department;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 6: Get office breakdown for department admin
CREATE OR REPLACE FUNCTION get_office_breakdown(p_state TEXT, p_department TEXT)
RETURNS TABLE (
    office_id UUID,
    office_name TEXT,
    district TEXT,
    total_issues BIGINT,
    pending_issues BIGINT,
    resolved_issues BIGINT,
    worker_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id as office_id,
        o.name as office_name,
        o.district,
        COUNT(ci.id)::BIGINT as total_issues,
        COUNT(ci.id) FILTER (WHERE ci.status = 'reported')::BIGINT as pending_issues,
        COUNT(ci.id) FILTER (WHERE ci.status IN ('resolved', 'completed'))::BIGINT as resolved_issues,
        (SELECT COUNT(*) FROM admin_roles ar WHERE ar.office_id = o.id AND ar.role = 'worker' AND ar.is_active = TRUE)::BIGINT as worker_count
    FROM offices o
    LEFT JOIN civic_issues ci ON ci.assigned_office_id = o.id
    WHERE o.state = p_state AND o.department = p_department
    GROUP BY o.id, o.name, o.district
    ORDER BY total_issues DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 7: Get analytics for office admin
CREATE OR REPLACE FUNCTION get_office_analytics(p_office_id UUID)
RETURNS TABLE (
    total_issues BIGINT,
    pending_issues BIGINT,
    in_progress_issues BIGINT,
    resolved_issues BIGINT,
    high_priority_issues BIGINT,
    avg_priority_score NUMERIC,
    issues_today BIGINT,
    issues_this_week BIGINT,
    total_workers BIGINT,
    avg_resolution_hours NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_issues,
        COUNT(*) FILTER (WHERE ci.status = 'reported')::BIGINT as pending_issues,
        COUNT(*) FILTER (WHERE ci.status IN ('assigned', 'in_progress'))::BIGINT as in_progress_issues,
        COUNT(*) FILTER (WHERE ci.status IN ('resolved', 'completed'))::BIGINT as resolved_issues,
        COUNT(*) FILTER (WHERE ci.is_high_priority = TRUE)::BIGINT as high_priority_issues,
        COALESCE(AVG(ci.priority_score), 0)::NUMERIC as avg_priority_score,
        COUNT(*) FILTER (WHERE ci.created_at >= CURRENT_DATE)::BIGINT as issues_today,
        COUNT(*) FILTER (WHERE ci.created_at >= CURRENT_DATE - INTERVAL '7 days')::BIGINT as issues_this_week,
        (SELECT COUNT(*) FROM admin_roles WHERE office_id = p_office_id AND role = 'worker' AND is_active = TRUE)::BIGINT as total_workers,
        COALESCE(AVG(
            CASE WHEN ci.status IN ('resolved', 'completed') 
            THEN EXTRACT(EPOCH FROM (ci.updated_at - ci.created_at)) / 3600 
            END
        ), 0)::NUMERIC as avg_resolution_hours
    FROM civic_issues ci
    WHERE ci.assigned_office_id = p_office_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 8: Get worker stats for office admin
CREATE OR REPLACE FUNCTION get_worker_stats(p_office_id UUID)
RETURNS TABLE (
    worker_id UUID,
    worker_email TEXT,
    assigned_issues BIGINT,
    resolved_issues BIGINT,
    in_progress_issues BIGINT,
    avg_resolution_hours NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ar.user_id as worker_id,
        u.email as worker_email,
        COUNT(ci.id)::BIGINT as assigned_issues,
        COUNT(ci.id) FILTER (WHERE ci.status IN ('resolved', 'completed'))::BIGINT as resolved_issues,
        COUNT(ci.id) FILTER (WHERE ci.status = 'in_progress')::BIGINT as in_progress_issues,
        COALESCE(AVG(
            CASE WHEN ci.status IN ('resolved', 'completed') 
            THEN EXTRACT(EPOCH FROM (ci.updated_at - ci.created_at)) / 3600 
            END
        ), 0)::NUMERIC as avg_resolution_hours
    FROM admin_roles ar
    JOIN auth.users u ON ar.user_id = u.id
    LEFT JOIN civic_issues ci ON ci.assigned_worker_id = ar.user_id
    WHERE ar.office_id = p_office_id AND ar.role = 'worker' AND ar.is_active = TRUE
    GROUP BY ar.user_id, u.email
    ORDER BY resolved_issues DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 9: Get worker's own analytics
CREATE OR REPLACE FUNCTION get_worker_analytics(p_worker_id UUID)
RETURNS TABLE (
    total_assigned BIGINT,
    pending_issues BIGINT,
    in_progress_issues BIGINT,
    resolved_issues BIGINT,
    resolved_today BIGINT,
    resolved_this_week BIGINT,
    avg_resolution_hours NUMERIC,
    high_priority_pending BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_assigned,
        COUNT(*) FILTER (WHERE ci.status = 'assigned')::BIGINT as pending_issues,
        COUNT(*) FILTER (WHERE ci.status = 'in_progress')::BIGINT as in_progress_issues,
        COUNT(*) FILTER (WHERE ci.status IN ('resolved', 'completed'))::BIGINT as resolved_issues,
        COUNT(*) FILTER (WHERE ci.status IN ('resolved', 'completed') AND ci.updated_at >= CURRENT_DATE)::BIGINT as resolved_today,
        COUNT(*) FILTER (WHERE ci.status IN ('resolved', 'completed') AND ci.updated_at >= CURRENT_DATE - INTERVAL '7 days')::BIGINT as resolved_this_week,
        COALESCE(AVG(
            CASE WHEN ci.status IN ('resolved', 'completed') 
            THEN EXTRACT(EPOCH FROM (ci.updated_at - ci.created_at)) / 3600 
            END
        ), 0)::NUMERIC as avg_resolution_hours,
        COUNT(*) FILTER (WHERE ci.is_high_priority = TRUE AND ci.status NOT IN ('resolved', 'completed'))::BIGINT as high_priority_pending
    FROM civic_issues ci
    WHERE ci.assigned_worker_id = p_worker_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 10: Get category breakdown
CREATE OR REPLACE FUNCTION get_category_breakdown(
    p_state TEXT DEFAULT NULL,
    p_department TEXT DEFAULT NULL,
    p_office_id UUID DEFAULT NULL
)
RETURNS TABLE (
    category TEXT,
    total_issues BIGINT,
    pending_issues BIGINT,
    resolved_issues BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ci.category,
        COUNT(*)::BIGINT as total_issues,
        COUNT(*) FILTER (WHERE ci.status = 'reported')::BIGINT as pending_issues,
        COUNT(*) FILTER (WHERE ci.status IN ('resolved', 'completed'))::BIGINT as resolved_issues
    FROM civic_issues ci
    WHERE 
        (p_state IS NULL OR ci.state = p_state)
        AND (p_department IS NULL OR ci.assigned_department = p_department)
        AND (p_office_id IS NULL OR ci.assigned_office_id = p_office_id)
    GROUP BY ci.category
    ORDER BY total_issues DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 11: Add assigned_worker_id column to civic_issues if not exists
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS assigned_worker_id UUID REFERENCES auth.users(id);
CREATE INDEX IF NOT EXISTS idx_civic_issues_worker ON civic_issues(assigned_worker_id);

-- SECTION 12: Function to assign issue to worker
CREATE OR REPLACE FUNCTION assign_issue_to_worker(
    p_issue_id UUID,
    p_worker_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    caller_id UUID;
    caller_role TEXT;
    caller_office UUID;
    worker_office UUID;
BEGIN
    caller_id := auth.uid();
    
    -- Get caller's role and office
    SELECT role, office_id INTO caller_role, caller_office
    FROM admin_roles WHERE user_id = caller_id AND is_active = TRUE
    ORDER BY CASE role WHEN 'system_admin' THEN 1 WHEN 'state_admin' THEN 2 WHEN 'department_admin' THEN 3 WHEN 'office_admin' THEN 4 END
    LIMIT 1;
    
    -- Get worker's office
    SELECT office_id INTO worker_office
    FROM admin_roles WHERE user_id = p_worker_id AND role = 'worker' AND is_active = TRUE;
    
    -- Check permissions
    IF caller_role NOT IN ('system_admin', 'state_admin', 'department_admin', 'office_admin') THEN
        RAISE EXCEPTION 'You do not have permission to assign issues';
    END IF;
    
    IF caller_role = 'office_admin' AND caller_office != worker_office THEN
        RAISE EXCEPTION 'You can only assign to workers in your office';
    END IF;
    
    -- Update the issue
    UPDATE civic_issues
    SET 
        assigned_worker_id = p_worker_id,
        status = 'assigned',
        updated_at = NOW()
    WHERE id = p_issue_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 13: Function for worker to update issue status
CREATE OR REPLACE FUNCTION update_issue_status(
    p_issue_id UUID,
    p_status TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    caller_id UUID;
    issue_worker UUID;
    caller_role TEXT;
BEGIN
    caller_id := auth.uid();
    
    -- Get issue's assigned worker
    SELECT assigned_worker_id INTO issue_worker FROM civic_issues WHERE id = p_issue_id;
    
    -- Get caller's role
    SELECT role INTO caller_role FROM admin_roles WHERE user_id = caller_id AND is_active = TRUE LIMIT 1;
    
    -- Workers can only update their own issues
    IF caller_role = 'worker' AND issue_worker != caller_id THEN
        RAISE EXCEPTION 'You can only update issues assigned to you';
    END IF;
    
    -- Validate status
    IF p_status NOT IN ('assigned', 'in_progress', 'resolved', 'completed', 'escalated') THEN
        RAISE EXCEPTION 'Invalid status';
    END IF;
    
    -- Update the issue
    UPDATE civic_issues
    SET 
        status = p_status,
        updated_at = NOW()
    WHERE id = p_issue_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SECTION 14: Get issues for worker
CREATE OR REPLACE FUNCTION get_worker_issues(
    p_worker_id UUID,
    p_status TEXT DEFAULT NULL
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
    media_files TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ci.id,
        ci.category,
        ci.description,
        ci.address,
        ci.status,
        ci.priority_score,
        ci.is_high_priority,
        ci.created_at,
        ci.media_files
    FROM civic_issues ci
    WHERE ci.assigned_worker_id = p_worker_id
    AND (p_status IS NULL OR ci.status = p_status)
    ORDER BY ci.is_high_priority DESC, ci.priority_score DESC, ci.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- ANALYTICS MIGRATION COMPLETE!
-- ============================================
