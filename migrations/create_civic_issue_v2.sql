-- Create the create_civic_issue_v2 function
-- Run this in your Supabase SQL Editor

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
    v_severity TEXT := 'MEDIUM';
    v_detected_category TEXT;
    v_priority INTEGER := 0;
    v_is_high_priority BOOLEAN := FALSE;
    v_rec_priority_text TEXT;
BEGIN
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

    -- Insert the new issue
    INSERT INTO civic_issues (
        user_id, category, description, location, address,
        district, state, media_files, voice_note_url,
        priority_score, ai_analysis, severity_level,
        is_high_priority, status,
        created_at, updated_at
    ) VALUES (
        p_user_id, p_category, p_description, location_geom, p_address,
        p_district, p_state, p_media_urls, p_voice_note_url,
        v_priority, p_ai_analysis, v_severity,
        v_is_high_priority, 'reported',
        NOW(), NOW()
    ) RETURNING id INTO new_issue_id;

    RETURN new_issue_id;
END;
$$ LANGUAGE plpgsql;

-- Also create the update_issue_ai_analysis function
CREATE OR REPLACE FUNCTION update_issue_ai_analysis(
    p_issue_id UUID,
    p_ai_analysis JSONB,
    p_priority_score INTEGER,
    p_is_high_priority BOOLEAN,
    p_escalation_level TEXT DEFAULT 'none'
)
RETURNS VOID AS $$
BEGIN
    UPDATE civic_issues
    SET ai_analysis = p_ai_analysis,
        priority_score = p_priority_score,
        is_high_priority = p_is_high_priority,
        escalation_level = p_escalation_level,
        updated_at = NOW()
    WHERE id = p_issue_id;
END;
$$ LANGUAGE plpgsql;

-- Create assign_issue_to_office function
CREATE OR REPLACE FUNCTION assign_issue_to_office(
    p_issue_id UUID,
    p_office_id UUID,
    p_escalated BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS $$
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
$$ LANGUAGE plpgsql;
