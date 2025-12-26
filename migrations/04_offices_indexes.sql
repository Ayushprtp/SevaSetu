-- Step 4: Create indexes for offices table
CREATE INDEX IF NOT EXISTS idx_offices_department ON offices (department);
CREATE INDEX IF NOT EXISTS idx_offices_district ON offices (district);
CREATE INDEX IF NOT EXISTS idx_offices_state ON offices (state);
CREATE INDEX IF NOT EXISTS idx_offices_state_level ON offices (is_state_level);
