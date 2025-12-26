-- Step 8: Create escalation_logs table
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
