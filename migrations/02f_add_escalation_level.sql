-- Step 2f: Add escalation_level column
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS escalation_level TEXT DEFAULT 'none';
