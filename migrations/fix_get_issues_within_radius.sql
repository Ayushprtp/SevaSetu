-- Fix the get_issues_within_radius function to return all needed columns
-- Run this in your Supabase SQL Editor

DROP FUNCTION IF EXISTS get_issues_within_radius(DOUBLE PRECISION, DOUBLE PRECISION, INTEGER);

CREATE OR REPLACE FUNCTION get_issues_within_radius(
    user_lat DOUBLE PRECISION,
    user_lng DOUBLE PRECISION,
    radius_km INTEGER DEFAULT 15
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    category TEXT,
    description TEXT,
    address TEXT,
    upvotes INTEGER,
    priority_score INTEGER,
    status TEXT,
    created_at TIMESTAMP,
    media_files TEXT[],
    distance_km DOUBLE PRECISION,
    is_high_priority BOOLEAN,
    severity_level TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ci.id,
        ci.user_id,
        ci.category,
        ci.description,
        ci.address,
        ci.upvotes,
        ci.priority_score,
        ci.status,
        ci.created_at,
        ci.media_files,
        ST_Distance(
            ci.location, 
            ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::GEOGRAPHY
        ) / 1000 AS distance_km,
        COALESCE(ci.is_high_priority, FALSE) as is_high_priority,
        COALESCE(ci.severity_level, 'MEDIUM') as severity_level
    FROM civic_issues ci
    WHERE ci.location IS NOT NULL
      AND ST_DWithin(
          ci.location,
          ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::GEOGRAPHY,
          radius_km * 1000  -- Convert km to meters
      )
      AND ci.status NOT IN ('completed', 'resolved')
    ORDER BY ci.priority_score DESC, ci.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Also ensure the civic_issues table has all required columns
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS is_high_priority BOOLEAN DEFAULT FALSE;
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS severity_level TEXT DEFAULT 'MEDIUM';
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS district TEXT;
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS state TEXT;
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS ai_analysis JSONB;
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS escalation_level TEXT DEFAULT 'none';
ALTER TABLE civic_issues ADD COLUMN IF NOT EXISTS assigned_office_id UUID;
