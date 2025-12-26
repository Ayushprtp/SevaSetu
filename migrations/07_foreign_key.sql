-- Step 7: Add foreign key constraint
-- Skip this if you get "already exists" error
ALTER TABLE civic_issues 
ADD CONSTRAINT fk_assigned_office 
FOREIGN KEY (assigned_office_id) REFERENCES offices(id) ON DELETE SET NULL;
