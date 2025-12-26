-- Migration for new features: Push Notifications, Photo Verification, Geofencing, Issue Clustering

-- ============================================
-- 1. NOTIFICATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- Device tokens for push notifications
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT DEFAULT 'mobile',
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, token)
);

-- ============================================
-- 2. PHOTO VERIFICATION / ISSUE RESOLUTIONS
-- ============================================
CREATE TABLE IF NOT EXISTS issue_resolutions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    issue_id UUID REFERENCES civic_issues(id) ON DELETE CASCADE,
    worker_id UUID REFERENCES users(id),
    verification_photo_url TEXT,
    notes TEXT,
    photo_latitude DOUBLE PRECISION,
    photo_longitude DOUBLE PRECISION,
    resolved_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_resolutions_issue ON issue_resolutions(issue_id);
CREATE INDEX IF NOT EXISTS idx_resolutions_worker ON issue_resolutions(worker_id);

-- Add resolution fields to civic_issues if not exists
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMP;
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS resolved_by UUID REFERENCES users(id);
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS resolution_photo_url TEXT;
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS assigned_worker_id UUID REFERENCES users(id);

-- ============================================
-- 3. GEOFENCING / LOCATION VERIFICATIONS
-- ============================================
CREATE TABLE IF NOT EXISTS location_verifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    issue_id UUID REFERENCES civic_issues(id) ON DELETE CASCADE,
    worker_id UUID REFERENCES users(id),
    success BOOLEAN NOT NULL,
    distance_meters DOUBLE PRECISION,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_location_verifications_issue ON location_verifications(issue_id);


-- ============================================
-- 4. ISSUE CLUSTERING ENHANCEMENTS
-- ============================================

-- Function to find nearby similar issues
CREATE OR REPLACE FUNCTION find_nearby_similar_issues(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_category TEXT,
    p_exclude_id UUID,
    p_radius_meters DOUBLE PRECISION DEFAULT 200
)
RETURNS TABLE (
    id UUID,
    category TEXT,
    location TEXT,
    distance_meters DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ci.id,
        ci.category,
        ST_AsText(ci.location) as location,
        ST_Distance(
            ci.location,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::GEOGRAPHY
        ) as distance_meters
    FROM civic_issues ci
    WHERE ci.category = p_category
      AND ci.id != p_exclude_id
      AND ci.status NOT IN ('resolved', 'completed')
      AND ST_DWithin(
          ci.location,
          ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::GEOGRAPHY,
          p_radius_meters
      )
    ORDER BY distance_meters ASC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- Function to boost issue priority (for clustering)
CREATE OR REPLACE FUNCTION boost_issue_priority(
    p_issue_id UUID,
    p_bonus INTEGER
)
RETURNS VOID AS $$
BEGIN
    UPDATE civic_issues
    SET priority_score = LEAST(priority_score + p_bonus, 100),
        updated_at = NOW()
    WHERE id = p_issue_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 5. ASSIGNMENT FUNCTIONS
-- ============================================

-- Function to assign issue to worker
CREATE OR REPLACE FUNCTION assign_issue_to_worker(
    p_issue_id UUID,
    p_worker_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_office_id UUID;
BEGIN
    -- Get worker's office
    SELECT office_id INTO v_office_id
    FROM admin_roles
    WHERE user_id = p_worker_id AND role = 'worker' AND is_active = TRUE
    LIMIT 1;

    IF v_office_id IS NULL THEN
        RAISE EXCEPTION 'Worker not found or not active';
    END IF;

    -- Update issue
    UPDATE civic_issues
    SET assigned_worker_id = p_worker_id,
        assigned_office_id = v_office_id,
        status = 'assigned',
        updated_at = NOW()
    WHERE id = p_issue_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to update issue status (with validation)
CREATE OR REPLACE FUNCTION update_issue_status(
    p_issue_id UUID,
    p_status TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE civic_issues
    SET status = p_status,
        updated_at = NOW()
    WHERE id = p_issue_id;

    -- Log status change
    INSERT INTO issue_status_history (issue_id, status, notes, created_at)
    VALUES (p_issue_id, p_status, p_notes, NOW());

    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Status history table
CREATE TABLE IF NOT EXISTS issue_status_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    issue_id UUID REFERENCES civic_issues(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_status_history_issue ON issue_status_history(issue_id);

-- ============================================
-- 6. WORKER ISSUES FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION get_worker_issues(
    p_worker_id UUID,
    p_status TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    category TEXT,
    description TEXT,
    address TEXT,
    status TEXT,
    priority_score INTEGER,
    is_high_priority BOOLEAN,
    media_files TEXT[],
    created_at TIMESTAMP,
    assigned_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ci.id,
        ci.category,
        ci.description,
        ci.address,
        ci.status,
        ci.priority_score,
        ci.is_high_priority,
        ci.media_files,
        ci.created_at,
        ci.updated_at as assigned_at
    FROM civic_issues ci
    WHERE ci.assigned_worker_id = p_worker_id
      AND (p_status IS NULL OR ci.status = p_status)
    ORDER BY ci.is_high_priority DESC, ci.priority_score DESC, ci.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. REALTIME SUBSCRIPTIONS (Enable RLS)
-- ============================================

-- Enable realtime for notifications
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE civic_issues;

-- RLS policies for notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications"
    ON notifications FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "System can insert notifications"
    ON notifications FOR INSERT
    WITH CHECK (TRUE);

-- RLS for issue_resolutions
ALTER TABLE issue_resolutions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Workers can view resolutions"
    ON issue_resolutions FOR SELECT
    USING (TRUE);

CREATE POLICY "Workers can insert resolutions"
    ON issue_resolutions FOR INSERT
    WITH CHECK (auth.uid() = worker_id);
