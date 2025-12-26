-- Step 9: Create indexes for escalation_logs
CREATE INDEX IF NOT EXISTS idx_escalation_logs_issue ON escalation_logs (issue_id);
CREATE INDEX IF NOT EXISTS idx_escalation_logs_created ON escalation_logs (created_at DESC);
