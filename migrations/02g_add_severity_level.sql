-- Step 2g: Add severity_level column
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS severity_level TEXT DEFAULT 'MEDIUM';
