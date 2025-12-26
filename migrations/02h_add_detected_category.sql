-- Step 2h: Add detected_category column
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS detected_category TEXT;
