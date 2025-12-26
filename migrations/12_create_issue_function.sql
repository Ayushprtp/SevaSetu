-- Step 12: Function to create civic issue with AI analysis
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
    v_priority INTEGER;
    v_is_high_priority BOOLEAN;
    v_rec_priority_text TEXT;
BEGIN
    v_priority := 0;
    v_is_high_priority := FALSE;
    location_geom := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::GEOGRAPHY;

    IF p_ai_analysis IS NOT NULL THEN
        v_severity := COALESCE(p_ai_analysis->>'severity_level', 'MEDIUM');
        v_detected_category := COALESCE(p_ai_analysis->>'detected_category', p_category);
        v_rec_priority_text := p_ai_analysis->>'recommended_priority';
        
        IF v_rec_priority_text IS NOT NULL AND v_rec_priority_text ~ '^[0-9]+$' THEN
            v_priority := v_rec_priority_text::INTEGER;
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
