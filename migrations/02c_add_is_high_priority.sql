-- Step 2c: Add is_high_priority column
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS is_high_priority BOOLEAN DEFAULT FALSE;
