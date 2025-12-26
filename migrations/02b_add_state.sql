-- Step 2b: Add state column
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS state TEXT;
