-- Step 15: Enable RLS on offices table
ALTER TABLE offices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Offices are viewable by authenticated users" ON offices;

CREATE POLICY "Offices are viewable by authenticated users" ON offices
    FOR SELECT TO authenticated USING (true);
