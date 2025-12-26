-- Step 14: Function to assign issue to office
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
        INSERT INTO escalation_logs (issue_id, from_level, to_level, triggered_by, actions_taken)
        VALUES (p_issue_id, 'district', 'state', 'system', ARRAY['Escalated to state level office']);
    END IF;
END;
$$ LANGUAGE plpgsql;
