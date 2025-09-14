-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own profile" ON users;
DROP POLICY IF EXISTS "Users can update their own profile" ON users;
DROP POLICY IF EXISTS "Users can insert their own profile" ON users;
DROP POLICY IF EXISTS "Users can view their own verification" ON user_verification;
DROP POLICY IF EXISTS "Users can update their own verification" ON user_verification;
DROP POLICY IF EXISTS "Users can insert their own verification" ON user_verification;
DROP POLICY IF EXISTS "Everyone can view all issues" ON civic_issues;
DROP POLICY IF EXISTS "Authenticated users can create issues" ON civic_issues;
DROP POLICY IF EXISTS "Users can update their own issues" ON civic_issues;
DROP POLICY IF EXISTS "Users can delete their own issues" ON civic_issues;
DROP POLICY IF EXISTS "Authenticated users can view upvotes" ON issue_upvotes;
DROP POLICY IF EXISTS "Authenticated users can create upvotes" ON issue_upvotes;
DROP POLICY IF EXISTS "Users can delete their own upvotes" ON issue_upvotes;
DROP POLICY IF EXISTS "Authenticated users can view clusters" ON issue_clusters;
DROP POLICY IF EXISTS "Admin can create clusters" ON issue_clusters;
DROP POLICY IF EXISTS "Admin can update clusters" ON issue_clusters;
DROP POLICY IF EXISTS "Authenticated users can view cluster members" ON cluster_members;
DROP POLICY IF EXISTS "Admin can manage cluster members" ON cluster_members;

-- Enable Row Level Security (RLS) for all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_verification ENABLE ROW LEVEL SECURITY;
ALTER TABLE civic_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE issue_upvotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE issue_clusters ENABLE ROW LEVEL SECURITY;
ALTER TABLE cluster_members ENABLE ROW LEVEL SECURITY;

-- Policies for users table
-- Users can view all profiles (for issue reporting transparency)
CREATE POLICY "Users can view all profiles" ON users
FOR SELECT USING (true);

CREATE POLICY "Users can update their own profile" ON users
FOR UPDATE USING (auth.uid() = id);

-- Users can insert their own profile (needed for initial creation)
CREATE POLICY "Users can insert their own profile" ON users
FOR INSERT WITH CHECK (auth.uid() = id);

-- Policies for user_verification table
-- Users can view their own verification status
CREATE POLICY "Users can view their own verification" ON user_verification
FOR SELECT USING (user_id = auth.uid());

-- Users can update their own verification status
CREATE POLICY "Users can update their own verification" ON user_verification
FOR UPDATE USING (user_id = auth.uid());

-- Users can insert their own verification record
CREATE POLICY "Users can insert their own verification" ON user_verification
FOR INSERT WITH CHECK (user_id = auth.uid());

-- Policies for civic_issues table
-- Everyone can view all issues (public feed)
CREATE POLICY "Everyone can view all issues" ON civic_issues
FOR SELECT USING (true);

-- Authenticated users can create issues
CREATE POLICY "Authenticated users can create issues" ON civic_issues
FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own issues
CREATE POLICY "Users can update their own issues" ON civic_issues
FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own issues
CREATE POLICY "Users can delete their own issues" ON civic_issues
FOR DELETE USING (auth.uid() = user_id);

-- Policies for issue_upvotes table
-- Authenticated users can view all upvotes
CREATE POLICY "Authenticated users can view upvotes" ON issue_upvotes
FOR SELECT USING (true);

-- Authenticated users can create upvotes
CREATE POLICY "Authenticated users can create upvotes" ON issue_upvotes
FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can delete their own upvotes
CREATE POLICY "Users can delete their own upvotes" ON issue_upvotes
FOR DELETE USING (auth.uid() = user_id);

-- Policies for issue_clusters table
-- Authenticated users can view clusters
CREATE POLICY "Authenticated users can view clusters" ON issue_clusters
FOR SELECT USING (true);

-- Admin or system can create/update clusters (this would need to be adjusted based on your app's needs)
CREATE POLICY "Admin can create clusters" ON issue_clusters
FOR INSERT WITH CHECK (true); -- Adjust this condition based on your admin logic

CREATE POLICY "Admin can update clusters" ON issue_clusters
FOR UPDATE USING (true); -- Adjust this condition based on your admin logic

-- Policies for cluster_members table
-- Authenticated users can view cluster members
CREATE POLICY "Authenticated users can view cluster members" ON cluster_members
FOR SELECT USING (true);

-- Admin or system can manage cluster members (this would need to be adjusted based on your app's needs)
CREATE POLICY "Admin can manage cluster members" ON cluster_members
FOR ALL USING (true); -- Adjust this condition based on your admin logic

-- Storage bucket policies for 'media' bucket
-- These policies need to be applied in the Supabase dashboard under Storage > Buckets > media > Policies
-- For reference, here are the policy definitions that should be created in the dashboard:

-- 1. Insert policy (for uploading):
--   Name: Authenticated users can upload media
--   Allowed operations: INSERT
--   Policy definition: (bucket_id = 'media' AND auth.uid() IS NOT NULL)

-- 2. Select policy (for reading):
--   Name: Authenticated users can read media
--   Allowed operations: SELECT
--   Policy definition: (bucket_id = 'media')

-- 3. Update policy (for updating):
--   Name: Users can update their own media
--   Allowed operations: UPDATE
--   Policy definition: (bucket_id = 'media' AND auth.uid()::text = owner_id)

-- 4. Delete policy (for deleting):
--   Name: Users can delete their own media
--   Allowed operations: DELETE
--   Policy definition: (bucket_id = 'media' AND auth.uid()::text = owner_id)