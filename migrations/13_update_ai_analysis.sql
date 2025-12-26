-- Step 13: Function to update issue with AI analysis
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
