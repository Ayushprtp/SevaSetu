-- ============================================
-- SEVASETU HIERARCHICAL SYSTEM - COMPLETE MIGRATION
-- ============================================
-- If you get "Connection terminated unexpectedly" error:
-- 1. Wait 30 seconds and try again
-- 2. Or run in Supabase Dashboard > Database > Extensions first enable PostGIS
-- 3. Then run this script
-- ============================================

-- Enable PostGIS (may already exist)
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================
-- PART 1: ADD COLUMNS TO CIVIC_ISSUES
-- ============================================

DO $$
BEGIN
    -- Add district column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='civic_issues' AND column_name='district') THEN
        ALTER TABLE civic_issues ADD COLUMN district TEXT;
    END IF;
    
    -- Add state column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='civic_issues' AND column_name='state') THEN
        ALTER TABLE civic_issues ADD COLUMN state TEXT;
    END IF;
    
    -- Add is_high_priority column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='civic_issues' AND column_name='is_high_priority') THEN
        ALTER TABLE civic_issues ADD COLUMN is_high_priority BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add ai_analysis column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='civic_issues' AND column_name='ai_analysis') THEN
        ALTER TABLE civic_issues ADD COLUMN ai_analysis JSONB;
    END IF;
    
    -- Add assigned_office_id column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='civic_issues' AND column_name='assigned_office_id') THEN
        ALTER TABLE civic_issues ADD COLUMN assigned_office_id UUID;
    END IF;
    
    -- Add escalation_level column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='civic_issues' AND column_name='escalation_level') THEN
        ALTER TABLE civic_issues ADD COLUMN escalation_level TEXT DEFAULT 'none';
    END IF;
    
    -- Add severity_level column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='civic_issues' AND column_name='severity_level') THEN
        ALTER TABLE civic_issues ADD COLUMN severity_level TEXT DEFAULT 'MEDIUM';
    END IF;
    
    -- Add detected_category column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='civic_issues' AND column_name='detected_category') THEN
        ALTER TABLE civic_issues ADD COLUMN detected_category TEXT;
    END IF;
END $$;

-- ============================================
-- PART 2: CREATE OFFICES TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS offices (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    department TEXT NOT NULL,
    district TEXT NOT NULL,
    state TEXT NOT NULL,
    location geography(POINT, 4326),
    is_state_level BOOLEAN DEFAULT FALSE,
    contact_email TEXT,
    contact_phone TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- PART 3: CREATE ESCALATION_LOGS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS escalation_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    issue_id UUID REFERENCES civic_issues(id) ON DELETE CASCADE,
    from_level TEXT,
    to_level TEXT,
    chaos_score DECIMAL(5,2),
    triggered_by TEXT,
    actions_taken TEXT[],
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- PART 4: CREATE INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_offices_department ON offices (department);
CREATE INDEX IF NOT EXISTS idx_offices_district ON offices (district);
CREATE INDEX IF NOT EXISTS idx_offices_state ON offices (state);
CREATE INDEX IF NOT EXISTS idx_offices_state_level ON offices (is_state_level);
CREATE INDEX IF NOT EXISTS idx_offices_location ON offices USING GIST (location);

CREATE INDEX IF NOT EXISTS idx_civic_issues_district ON civic_issues (district);
CREATE INDEX IF NOT EXISTS idx_civic_issues_state ON civic_issues (state);
CREATE INDEX IF NOT EXISTS idx_civic_issues_high_priority ON civic_issues (is_high_priority);
CREATE INDEX IF NOT EXISTS idx_civic_issues_escalation ON civic_issues (escalation_level);
CREATE INDEX IF NOT EXISTS idx_civic_issues_assigned_office ON civic_issues (assigned_office_id);

CREATE INDEX IF NOT EXISTS idx_escalation_logs_issue ON escalation_logs (issue_id);
CREATE INDEX IF NOT EXISTS idx_escalation_logs_created ON escalation_logs (created_at DESC);

-- ============================================
-- PART 5: ADD FOREIGN KEY
-- ============================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'fk_assigned_office') THEN
        ALTER TABLE civic_issues ADD CONSTRAINT fk_assigned_office FOREIGN KEY (assigned_office_id) REFERENCES offices(id) ON DELETE SET NULL;
    END IF;
END $$;

-- ============================================
-- PART 6: CREATE FUNCTIONS
-- ============================================

-- Function: find_offices_by_department
CREATE OR REPLACE FUNCTION find_offices_by_department(p_department TEXT, p_district TEXT, p_state TEXT)
RETURNS TABLE (id UUID, name TEXT, department TEXT, district TEXT, state TEXT, latitude DOUBLE PRECISION, longitude DOUBLE PRECISION, is_state_level BOOLEAN)
AS $$
BEGIN
    RETURN QUERY
    SELECT o.id, o.name, o.department, o.district, o.state, ST_Y(o.location::geometry), ST_X(o.location::geometry), o.is_state_level
    FROM offices o
    WHERE o.department = p_department AND (o.district = p_district OR o.is_state_level = TRUE) AND o.state = p_state
    ORDER BY o.is_state_level ASC;
END;
$$ LANGUAGE plpgsql;

-- Function: find_nearest_office
CREATE OR REPLACE FUNCTION find_nearest_office(p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION, p_department TEXT, p_district TEXT, p_state TEXT)
RETURNS TABLE (id UUID, name TEXT, department TEXT, district TEXT, state TEXT, latitude DOUBLE PRECISION, longitude DOUBLE PRECISION, is_state_level BOOLEAN, distance_km DOUBLE PRECISION)
AS $$
BEGIN
    RETURN QUERY
    SELECT o.id, o.name, o.department, o.district, o.state, ST_Y(o.location::geometry), ST_X(o.location::geometry), o.is_state_level, ST_Distance(o.location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography) / 1000
    FROM offices o
    WHERE o.department = p_department AND (o.district = p_district OR o.is_state_level = TRUE) AND o.state = p_state
    ORDER BY distance_km ASC LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function: update_issue_ai_analysis
CREATE OR REPLACE FUNCTION update_issue_ai_analysis(p_issue_id UUID, p_ai_analysis JSONB, p_priority_score INTEGER, p_is_high_priority BOOLEAN, p_escalation_level TEXT DEFAULT 'none')
RETURNS VOID AS $$
BEGIN
    UPDATE civic_issues SET ai_analysis = p_ai_analysis, priority_score = p_priority_score, is_high_priority = p_is_high_priority, escalation_level = p_escalation_level, severity_level = COALESCE(p_ai_analysis->>'severity_level', 'MEDIUM'), detected_category = p_ai_analysis->>'detected_category', updated_at = NOW() WHERE id = p_issue_id;
END;
$$ LANGUAGE plpgsql;

-- Function: assign_issue_to_office
CREATE OR REPLACE FUNCTION assign_issue_to_office(p_issue_id UUID, p_office_id UUID, p_escalated BOOLEAN DEFAULT FALSE)
RETURNS VOID AS $$
DECLARE v_department TEXT;
BEGIN
    SELECT department INTO v_department FROM offices WHERE id = p_office_id;
    UPDATE civic_issues SET assigned_office_id = p_office_id, assigned_department = v_department, status = 'assigned', updated_at = NOW() WHERE id = p_issue_id;
    IF p_escalated THEN INSERT INTO escalation_logs (issue_id, from_level, to_level, triggered_by, actions_taken) VALUES (p_issue_id, 'district', 'state', 'system', ARRAY['Escalated to state level office']); END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- PART 7: ENABLE RLS
-- ============================================

ALTER TABLE offices ENABLE ROW LEVEL SECURITY;
ALTER TABLE escalation_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "offices_select_policy" ON offices;
DROP POLICY IF EXISTS "escalation_logs_select_policy" ON escalation_logs;

CREATE POLICY "offices_select_policy" ON offices FOR SELECT TO authenticated USING (true);
CREATE POLICY "escalation_logs_select_policy" ON escalation_logs FOR SELECT TO authenticated USING (issue_id IN (SELECT id FROM civic_issues WHERE user_id = auth.uid()));

-- ============================================
-- MIGRATION COMPLETE
-- ============================================
