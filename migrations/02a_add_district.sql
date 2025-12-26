-- Step 2a: Add district column
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS district TEXT;
