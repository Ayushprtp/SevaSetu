-- ============================================
-- MIGRATION: Add Hierarchical System Support
-- Run each step separately in Supabase SQL Editor
-- ============================================

-- Step 0: Required extensions (run first)
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Step 1: Add new columns to civic_issues (non-blocking)
ALTER TABLE civic_issues 
ADD COLUMN IF NOT EXISTS district TEXT,
ADD COLUMN IF NOT EXISTS state TEXT,
ADD COLUMN IF NOT EXISTS is_high_priority BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS ai_analysis JSONB,
ADD COLUMN IF NOT EXISTS assigned_office_id UUID,
ADD COLUMN IF NOT EXISTS escalation_level TEXT DEFAULT 'none',
ADD COLUMN IF NOT EXISTS severity_level TEXT DEFAULT 'MEDIUM',
ADD COLUMN IF NOT EXISTS detected_category TEXT;

-- Step 2: Create offices table
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

-- Step 3: Create indexes for offices
CREATE INDEX IF NOT EXISTS idx_offices_department ON offices (department);
CREATE INDEX IF NOT EXISTS idx_offices_district ON offices (district);
CREATE INDEX IF NOT EXISTS idx_offices_state ON offices (state);
CREATE INDEX IF NOT EXISTS idx_offices_location ON offices USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_offices_state_level ON offices (is_state_level);

-- Step 4: Create indexes for civic_issues
CREATE INDEX IF NOT EXISTS idx_civic_issues_district ON civic_issues (district);
CREATE INDEX IF NOT EXISTS idx_civic_issues_state ON civic_issues (state);
CREATE INDEX IF NOT EXISTS idx_civic_issues_high_priority ON civic_issues (is_high_priority);
CREATE INDEX IF NOT EXISTS idx_civic_issues_escalation ON civic_issues (escalation_level);
CREATE INDEX IF NOT EXISTS idx_civic_issues_assigned_office ON civic_issues (assigned_office_id);

-- Step 5: Add foreign key for assigned office
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'fk_assigned_office'
    ) THEN
        ALTER TABLE civic_issues 
        ADD CONSTRAINT fk_assigned_office 
        FOREIGN KEY (assigned_office_id) REFERENCES offices(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Step 6: Create escalation_logs table
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

CREATE INDEX IF NOT EXISTS idx_escalation_logs_issue ON escalation_logs (issue_id);
CREATE INDEX IF NOT EXISTS idx_escalation_logs_created ON escalation_logs (created_at DESC);


-- Step 7: Function to find offices by department
CREATE OR REPLACE FUNCTION find_offices_by_department(
    p_department TEXT,
    p_district TEXT,
    p_state TEXT
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    department TEXT,
    district TEXT,
    state TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_state_level BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id,
        o.name,
        o.department,
        o.district,
        o.state,
        ST_Y(o.location::geometry) AS latitude,
        ST_X(o.location::geometry) AS longitude,
        o.is_state_level
    FROM offices o
    WHERE o.department = p_department
    AND (o.district = p_district OR o.is_state_level = TRUE)
    AND o.state = p_state
    ORDER BY o.is_state_level ASC;
END;
$$ LANGUAGE plpgsql;

-- Step 8: Function to find nearest office
CREATE OR REPLACE FUNCTION find_nearest_office(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_department TEXT,
    p_district TEXT,
    p_state TEXT
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    department TEXT,
    district TEXT,
    state TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_state_level BOOLEAN,
    distance_km DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id,
        o.name,
        o.department,
        o.district,
        o.state,
        ST_Y(o.location::geometry) AS latitude,
        ST_X(o.location::geometry) AS longitude,
        o.is_state_level,
        ST_Distance(
            o.location,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
        ) / 1000 AS distance_km
    FROM offices o
    WHERE o.department = p_department
    AND (o.district = p_district OR o.is_state_level = TRUE)
    AND o.state = p_state
    ORDER BY distance_km ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;


-- Step 9: Function to create civic issue with AI analysis
CREATE OR REPLACE FUNCTION create_civic_issue_v2(
    p_user_id UUID,
    p_category TEXT,
    p_description TEXT,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_address TEXT,
    p_district TEXT,
    p_state TEXT,
    p_media_urls TEXT[],
    p_voice_note_url TEXT,
    p_ai_analysis JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    new_issue_id UUID;
    location_geom GEOGRAPHY;
    v_severity TEXT;
    v_detected_category TEXT;
    v_priority INTEGER := 0;
    v_is_high_priority BOOLEAN := FALSE;
    v_rec_priority_text TEXT;
BEGIN
    location_geom := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::GEOGRAPHY;

    IF p_ai_analysis IS NOT NULL THEN
        v_severity := COALESCE(p_ai_analysis->>'severity_level', 'MEDIUM');
        v_detected_category := COALESCE(p_ai_analysis->>'detected_category', p_category);
        v_rec_priority_text := p_ai_analysis->>'recommended_priority';
        
        IF v_rec_priority_text IS NOT NULL AND v_rec_priority_text ~ '^[0-9]+$' THEN
            v_priority := v_rec_priority_text::INTEGER;
        ELSE
            v_priority := 0;
        END IF;
        
        v_is_high_priority := (v_severity = 'CRITICAL') OR (v_priority > 70);
    ELSE
        v_severity := 'MEDIUM';
        v_detected_category := p_category;
    END IF;

    INSERT INTO civic_issues (
        user_id, category, description, location, address,
        district, state, media_files, voice_note_url,
        priority_score, ai_analysis, severity_level,
        detected_category, is_high_priority, status,
        created_at, updated_at
    ) VALUES (
        p_user_id, p_category, p_description, location_geom, p_address,
        p_district, p_state, p_media_urls, p_voice_note_url,
        v_priority, p_ai_analysis, v_severity,
        v_detected_category, v_is_high_priority, 'reported',
        NOW(), NOW()
    ) RETURNING id INTO new_issue_id;

    RETURN new_issue_id;
END;
$$ LANGUAGE plpgsql;

-- Step 10: Function to update issue with AI analysis
CREATE OR REPLACE FUNCTION update_issue_ai_analysis(
    p_issue_id UUID,
    p_ai_analysis JSONB,
    p_priority_score INTEGER,
    p_is_high_priority BOOLEAN,
    p_escalation_level TEXT DEFAULT 'none'
)
RETURNS VOID AS $$
DECLARE
    v_severity TEXT;
    v_detected TEXT;
BEGIN
    v_severity := COALESCE(p_ai_analysis->>'severity_level', 'MEDIUM');
    v_detected := p_ai_analysis->>'detected_category';

    UPDATE civic_issues
    SET 
        ai_analysis = p_ai_analysis,
        priority_score = p_priority_score,
        is_high_priority = p_is_high_priority,
        escalation_level = p_escalation_level,
        severity_level = v_severity,
        detected_category = v_detected,
        updated_at = NOW()
    WHERE id = p_issue_id;
END;
$$ LANGUAGE plpgsql;

-- Step 11: Function to assign issue to office
CREATE OR REPLACE FUNCTION assign_issue_to_office(
    p_issue_id UUID,
    p_office_id UUID,
    p_escalated BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS $$
DECLARE
    v_department TEXT;
BEGIN
    SELECT department INTO v_department FROM offices WHERE id = p_office_id;

    UPDATE civic_issues
    SET 
        assigned_office_id = p_office_id,
        assigned_department = v_department,
        status = 'assigned',
        updated_at = NOW()
    WHERE id = p_issue_id;

    IF p_escalated THEN
        INSERT INTO escalation_logs (issue_id, from_level, to_level, triggered_by, actions_taken, created_at)
        VALUES (p_issue_id, 'district', 'state', 'system', ARRAY['Escalated to state level office'], NOW());
    END IF;
END;
$$ LANGUAGE plpgsql;


-- Step 12: Enable RLS and create policies
ALTER TABLE offices ENABLE ROW LEVEL SECURITY;
ALTER TABLE escalation_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Offices are viewable by authenticated users" ON offices;
DROP POLICY IF EXISTS "Users can view escalation logs for their issues" ON escalation_logs;

CREATE POLICY "Offices are viewable by authenticated users" ON offices
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can view escalation logs for their issues" ON escalation_logs
    FOR SELECT TO authenticated
    USING (
        issue_id IN (
            SELECT id FROM civic_issues WHERE user_id = auth.uid()
        )
    );

-- Step 13: Add comments
COMMENT ON TABLE offices IS 'Government offices that handle civic issues by department';
COMMENT ON TABLE escalation_logs IS 'Audit log of issue escalations through the hierarchy';
COMMENT ON COLUMN civic_issues.ai_analysis IS 'JSON containing AI analysis results from Gemini Vision';
COMMENT ON COLUMN civic_issues.escalation_level IS 'Current escalation level: none, elevated, highPriority, emergency';

-- ============================================
-- SAMPLE DATA: Insert sample offices (uncomment and modify for your deployment)
-- ============================================

-- INSERT INTO offices (name, department, district, state, location, is_state_level) VALUES
-- ('PWD District Office - Mumbai', 'pwd', 'Mumbai', 'Maharashtra', 
--  ST_SetSRID(ST_MakePoint(72.8777, 19.0760), 4326)::geography, FALSE),
-- ('PWD State Office - Maharashtra', 'pwd', 'Mumbai', 'Maharashtra', 
--  ST_SetSRID(ST_MakePoint(72.8777, 19.0760), 4326)::geography, TRUE),
-- ('Sanitation District Office - Mumbai', 'sanitation', 'Mumbai', 'Maharashtra', 
--  ST_SetSRID(ST_MakePoint(72.8800, 19.0800), 4326)::geography, FALSE),
-- ('Electricity District Office - Mumbai', 'electricity', 'Mumbai', 'Maharashtra', 
--  ST_SetSRID(ST_MakePoint(72.8750, 19.0700), 4326)::geography, FALSE),
-- ('Water District Office - Mumbai', 'water', 'Mumbai', 'Maharashtra', 
--  ST_SetSRID(ST_MakePoint(72.8820, 19.0780), 4326)::geography, FALSE),
-- ('General Services - Mumbai', 'general', 'Mumbai', 'Maharashtra', 
--  ST_SetSRID(ST_MakePoint(72.8790, 19.0750), 4326)::geography, FALSE);

-- ============================================
-- VERIFICATION QUERIES (run after migration)
-- ============================================

-- Check new columns exist:
-- SELECT column_name, data_type FROM information_schema.columns 
-- WHERE table_name = 'civic_issues' AND column_name IN ('district', 'state', 'ai_analysis', 'is_high_priority');

-- Check offices table:
-- SELECT * FROM offices LIMIT 5;

-- Check functions exist:
-- SELECT routine_name FROM information_schema.routines 
-- WHERE routine_schema = 'public' AND routine_name LIKE '%office%';
