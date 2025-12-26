-- Step 2e: Add assigned_office_id column
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS assigned_office_id UUID;
