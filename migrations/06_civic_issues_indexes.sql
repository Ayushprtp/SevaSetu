-- Step 6: Create indexes for civic_issues new columns
CREATE INDEX IF NOT EXISTS idx_civic_issues_district ON civic_issues (district);
CREATE INDEX IF NOT EXISTS idx_civic_issues_state ON civic_issues (state);
CREATE INDEX IF NOT EXISTS idx_civic_issues_high_priority ON civic_issues (is_high_priority);
CREATE INDEX IF NOT EXISTS idx_civic_issues_escalation ON civic_issues (escalation_level);
CREATE INDEX IF NOT EXISTS idx_civic_issues_assigned_office ON civic_issues (assigned_office_id);
