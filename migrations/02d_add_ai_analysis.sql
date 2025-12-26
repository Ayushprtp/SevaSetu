-- Step 2d: Add ai_analysis column
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS ai_analysis JSONB;
