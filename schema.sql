-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    first_name TEXT,
    last_name TEXT,
    username TEXT UNIQUE,
    mobile_number TEXT,
    id_type TEXT,
    id_value TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- User verification table
CREATE TABLE IF NOT EXISTS user_verification (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    verification_status TEXT DEFAULT 'pending',
    id_document_url TEXT,
    selfie_url TEXT,
    verified_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Civic issues table
CREATE TABLE IF NOT EXISTS civic_issues (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    category TEXT NOT NULL,
    description TEXT,
    location geography(POINT, 4326), -- PostGIS geography for GPS coordinates
    address TEXT,
    media_files TEXT[], -- Array of URLs to media files in Supabase storage
    voice_note_url TEXT,
    priority_score INTEGER DEFAULT 0,
    upvotes INTEGER DEFAULT 0,
    assigned_department TEXT,
    status TEXT DEFAULT 'reported',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Issue upvotes table (for tracking who upvoted what)
CREATE TABLE IF NOT EXISTS issue_upvotes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    issue_id UUID REFERENCES civic_issues(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, issue_id) -- Prevent duplicate upvotes
);

-- Issue clustering table (for grouping similar issues)
CREATE TABLE IF NOT EXISTS issue_clusters (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    primary_issue_id UUID REFERENCES civic_issues(id),
    cluster_radius INTEGER DEFAULT 15, -- in meters
    created_at TIMESTAMP DEFAULT NOW()
);

-- Cluster members table (issues that belong to a cluster)
CREATE TABLE IF NOT EXISTS cluster_members (
    cluster_id UUID REFERENCES issue_clusters(id),
    issue_id UUID REFERENCES civic_issues(id),
    added_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (cluster_id, issue_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_civic_issues_location ON civic_issues USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_civic_issues_category ON civic_issues (category);
CREATE INDEX IF NOT EXISTS idx_civic_issues_priority ON civic_issues (priority_score DESC);
CREATE INDEX IF NOT EXISTS idx_civic_issues_created ON civic_issues (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_civic_issues_status ON civic_issues (status);
CREATE INDEX IF NOT EXISTS idx_issue_upvotes_issue ON issue_upvotes (issue_id);
CREATE INDEX IF NOT EXISTS idx_issue_upvotes_user ON issue_upvotes (user_id);

-- Function to calculate priority score
CREATE OR REPLACE FUNCTION calculate_priority_score(issue_id UUID)
RETURNS INTEGER AS $$
DECLARE
    report_count INTEGER;
    upvote_count INTEGER;
    category_multiplier INTEGER;
    age_bonus INTEGER;
    severity_weight INTEGER;
    base_score INTEGER;
BEGIN
    -- Get basic counts
    SELECT COUNT(*) INTO report_count
    FROM cluster_members cm1
    JOIN cluster_members cm2 ON cm1.cluster_id = cm2.cluster_id
    WHERE cm2.issue_id = $1;
    
    SELECT upvotes INTO upvote_count FROM civic_issues WHERE id = $1;
    
    -- Category multipliers
    SELECT CASE
        WHEN category = 'POWER_CUT' THEN 5
        WHEN category = 'WATER_LEAK' THEN 4
        WHEN category = 'SEWAGE_OVERFLOW' THEN 4
        WHEN category IN ('POTHOLE', 'GARBAGE') THEN 1
        ELSE 1
    END INTO category_multiplier
    FROM civic_issues WHERE id = $1;
    
    -- Age bonus (newer issues get bonus)
    SELECT CASE
        WHEN EXTRACT(DAY FROM (NOW() - created_at)) < 1 THEN 10
        WHEN EXTRACT(DAY FROM (NOW() - created_at)) < 7 THEN 5
        ELSE 0
    END INTO age_bonus
    FROM civic_issues WHERE id = $1;
    
    -- Severity weight (could be extended)
    severity_weight := 0;
    
    -- Calculate base score
    base_score := (COALESCE(report_count, 1) * 2) +
                  (COALESCE(upvote_count, 0) * 3) +
                  category_multiplier +
                  age_bonus +
                  severity_weight;
    
    RETURN base_score;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update priority score when upvotes change
CREATE OR REPLACE FUNCTION update_priority_score()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        UPDATE civic_issues 
        SET priority_score = calculate_priority_score(NEW.issue_id),
            updated_at = NOW()
        WHERE id = NEW.issue_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE civic_issues 
        SET priority_score = calculate_priority_score(OLD.issue_id),
            updated_at = NOW()
        WHERE id = OLD.issue_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for upvotes
DROP TRIGGER IF EXISTS trigger_update_priority_on_upvote ON issue_upvotes;
CREATE TRIGGER trigger_update_priority_on_upvote
AFTER INSERT OR UPDATE OR DELETE ON issue_upvotes
FOR EACH ROW EXECUTE FUNCTION update_priority_score();

-- Function to find issues within radius
CREATE OR REPLACE FUNCTION get_issues_within_radius(
    user_lat DOUBLE PRECISION,
    user_lng DOUBLE PRECISION,
    radius_km INTEGER DEFAULT 15
)
RETURNS TABLE (
    id UUID,
    category TEXT,
    description TEXT,
    address TEXT,
    upvotes INTEGER,
    priority_score INTEGER,
    status TEXT,
    created_at TIMESTAMP,
    distance_km DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ci.id,
        ci.category,
        ci.description,
        ci.address,
        ci.upvotes,
        ci.priority_score,
        ci.status,
        ci.created_at,
        ST_Distance(
            ci.location, 
            ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::GEOGRAPHY
        ) / 1000 AS distance_km
    FROM civic_issues ci
    WHERE ST_DWithin(
        ci.location,
        ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::GEOGRAPHY,
        radius_km * 1000  -- Convert km to meters
    )
    AND ci.status != 'completed'
    ORDER BY ci.priority_score DESC, ci.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to upvote an issue
DROP FUNCTION IF EXISTS upvote_issue(UUID, UUID);

CREATE OR REPLACE FUNCTION upvote_issue(p_user_id UUID, p_issue_id UUID)
RETURNS INTEGER AS $$
DECLARE
    current_upvotes INTEGER;
BEGIN
    -- Insert upvote if not exists
    INSERT INTO issue_upvotes (user_id, issue_id)
    VALUES (p_user_id, p_issue_id)
    ON CONFLICT (user_id, issue_id) DO NOTHING;

    -- Update the upvotes count in civic_issues
    UPDATE civic_issues
    SET upvotes = (SELECT COUNT(*) FROM issue_upvotes WHERE issue_upvotes.issue_id = p_issue_id)
    WHERE id = p_issue_id
    RETURNING upvotes INTO current_upvotes;

    RETURN current_upvotes;
END;
$$ LANGUAGE plpgsql;

-- Function to create a new issue
CREATE OR REPLACE FUNCTION create_civic_issue(
    user_id UUID,
    category TEXT,
    description TEXT,
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    address TEXT,
    media_urls TEXT[],
    voice_note_url TEXT
)
RETURNS UUID AS $$
DECLARE
    new_issue_id UUID;
    location_geom GEOGRAPHY;
BEGIN
    -- Create geography point from lat/lng
    location_geom := ST_SetSRID(ST_MakePoint(lng, lat), 4326)::GEOGRAPHY;
    
    -- Insert new issue
    INSERT INTO civic_issues (
        user_id, category, description, location, address,
        media_files, voice_note_url, priority_score
    ) VALUES (
        user_id, category, description, location_geom, address,
        media_urls, voice_note_url, 0
    ) RETURNING id INTO new_issue_id;
    
    -- Initialize priority score
    UPDATE civic_issues 
    SET priority_score = calculate_priority_score(new_issue_id)
    WHERE id = new_issue_id;
    
    RETURN new_issue_id;
END;
$$ LANGUAGE plpgsql;

-- Function to create a public.users entry when a new auth.users entry is created
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, first_name, last_name, username, mobile_number, id_type, id_value)
  VALUES (
    NEW.id, 
    NULL, 
    NULL, 
    NEW.email, 
    NULL, 
    NULL, 
    NULL
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call handle_new_user() when a new user is created in auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();