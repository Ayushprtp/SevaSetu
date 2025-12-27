-- Complete fix for all database functions
-- Run this in Supabase SQL Editor

-- Drop existing functions first
DROP FUNCTION IF EXISTS create_civic_issue_v2(UUID, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, TEXT, TEXT[], TEXT, JSONB);
DROP FUNCTION IF EXISTS get_issues_within_radius(DOUBLE PRECISION, DOUBLE PRECISION, INTEGER);
DROP FUNCTION IF EXISTS update_issue_ai_analysis(UUID, JSONB, INTEGER, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS assign_issue_to_office(UUID, UUID, BOOLEAN);

-- 1. Create civic issue function with SECURITY DEFINER
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
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    new_issue_id UUID;
    location_geom GEOGRAPHY;
    v_severity TEXT := 'MEDIUM';
    v_detected_category TEXT;
    v_priority INTEGER := 0;
    v_is_high_priority BOOLEAN := FALSE;
    v_rec_priority_text TEXT;
BEGIN
    -- Generate UUID explicitly
    new_issue_id := gen_random_uuid();
    
    -- Create geography point from lat/lng
    location_geom := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::GEOGRAPHY;
    v_detected_category := p_category;

    -- Extract AI analysis data if provided
    IF p_ai_analysis IS NOT NULL THEN
        v_severity := COALESCE(p_ai_analysis->>'severity_level', 'MEDIUM');
        v_detected_category := COALESCE(p_ai_analysis->>'detected_category', p_category);
        v_rec_priority_text := p_ai_analysis->>'recommended_priority';
        
        IF v_rec_priority_text IS NOT NULL AND v_rec_priority_text ~ '^[0-9]+$' THEN
            v_priority := v_rec_priority_text::INTEGER;
        END IF;
        
        v_is_high_priority := (v_severity = 'CRITICAL') OR (v_priority > 70);
    END IF;

    -- Insert the new issue with explicit ID
    INSERT INTO civic_issues (
        id, user_id, category, description, location, address,
        district, state, media_files, voice_note_url,
        priority_score, ai_analysis, severity_level,
        is_high_priority, status, upvotes,
        created_at, updated_at
    ) VALUES (
        new_issue_id, p_user_id, p_category, p_description, location_geom, p_address,
        p_district, p_state, p_media_urls, p_voice_note_url,
        v_priority, p_ai_analysis, v_severity,
        v_is_high_priority, 'reported', 0,
        NOW(), NOW()
    );

    RETURN new_issue_id;
END;
$$;

-- 2. Get issues within radius function with SECURITY DEFINER
CREATE OR REPLACE FUNCTION get_issues_within_radius(
    user_lat DOUBLE PRECISION,
    user_lng DOUBLE PRECISION,
    radius_km INTEGER DEFAULT 15
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    category TEXT,
    description TEXT,
    address TEXT,
    upvotes INTEGER,
    priority_score INTEGER,
    status TEXT,
    created_at TIMESTAMP,
    media_files TEXT[],
    distance_km DOUBLE PRECISION,
    is_high_priority BOOLEAN,
    severity_level TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ci.id,
        ci.user_id,
        ci.category,
        ci.description,
        ci.address,
        COALESCE(ci.upvotes, 0) as upvotes,
        COALESCE(ci.priority_score, 0) as priority_score,
        ci.status,
        ci.created_at,
        ci.media_files,
        ST_Distance(
            ci.location, 
            ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::GEOGRAPHY
        ) / 1000.0 AS distance_km,
        COALESCE(ci.is_high_priority, FALSE) as is_high_priority,
        COALESCE(ci.severity_level, 'MEDIUM') as severity_level
    FROM civic_issues ci
    WHERE ci.location IS NOT NULL
      AND ST_DWithin(
          ci.location,
          ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::GEOGRAPHY,
          radius_km * 1000
      )
    ORDER BY ci.priority_score DESC NULLS LAST, ci.created_at DESC;
END;
$$;

-- 3. Update AI analysis function with SECURITY DEFINER
CREATE OR REPLACE FUNCTION update_issue_ai_analysis(
    p_issue_id UUID,
    p_ai_analysis JSONB,
    p_priority_score INTEGER,
    p_is_high_priority BOOLEAN,
    p_escalation_level TEXT DEFAULT 'none'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE civic_issues
    SET ai_analysis = p_ai_analysis,
        priority_score = p_priority_score,
        is_high_priority = p_is_high_priority,
        escalation_level = p_escalation_level,
        updated_at = NOW()
    WHERE id = p_issue_id;
END;
$$;

-- 4. Assign issue to office function with SECURITY DEFINER
CREATE OR REPLACE FUNCTION assign_issue_to_office(
    p_issue_id UUID,
    p_office_id UUID,
    p_escalated BOOLEAN DEFAULT FALSE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_department TEXT;
BEGIN
    -- Get department from office
    SELECT department INTO v_department
    FROM offices
    WHERE id = p_office_id;

    UPDATE civic_issues
    SET assigned_office_id = p_office_id,
        assigned_department = v_department,
        status = CASE WHEN p_escalated THEN 'escalated' ELSE 'assigned' END,
        updated_at = NOW()
    WHERE id = p_issue_id;
END;
$$;

-- 5. Ensure all required columns exist
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS is_high_priority BOOLEAN DEFAULT FALSE;
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS severity_level TEXT DEFAULT 'MEDIUM';
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS district TEXT;
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS state TEXT;
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS ai_analysis JSONB;
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS escalation_level TEXT DEFAULT 'none';
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS assigned_office_id UUID;
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS assigned_department TEXT;

-- 6. RLS Policies for civic_issues
ALTER TABLE civic_issues ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Anyone can view issues" ON civic_issues;
DROP POLICY IF EXISTS "Users can create issues" ON civic_issues;
DROP POLICY IF EXISTS "Users can update own issues" ON civic_issues;
DROP POLICY IF EXISTS "Workers can update assigned issues" ON civic_issues;

-- Create policies
CREATE POLICY "Anyone can view issues" ON civic_issues
    FOR SELECT USING (true);

CREATE POLICY "Users can create issues" ON civic_issues
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own issues" ON civic_issues
    FOR UPDATE USING (auth.uid() = user_id);

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION create_civic_issue_v2 TO authenticated;
GRANT EXECUTE ON FUNCTION get_issues_within_radius TO authenticated;
GRANT EXECUTE ON FUNCTION update_issue_ai_analysis TO authenticated;
GRANT EXECUTE ON FUNCTION assign_issue_to_office TO authenticated;

-- Also grant to anon for public access to view issues
GRANT EXECUTE ON FUNCTION get_issues_within_radius TO anon;
