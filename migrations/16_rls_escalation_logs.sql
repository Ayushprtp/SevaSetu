-- Step 16: Enable RLS on escalation_logs table
ALTER TABLE escalation_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view escalation logs for their issues" ON escalation_logs;

CREATE POLICY "Users can view escalation logs for their issues" ON escalation_logs
    FOR SELECT TO authenticated
    USING (issue_id IN (SELECT id FROM civic_issues WHERE user_id = auth.uid()));
