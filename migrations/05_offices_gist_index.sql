-- Step 5: Create GIST index for offices location
CREATE INDEX IF NOT EXISTS idx_offices_location ON offices USING GIST (location);
