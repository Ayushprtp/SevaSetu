-- Step 10: Function to find offices by department
CREATE OR REPLACE FUNCTION find_offices_by_department(
    p_department TEXT,
    p_district TEXT,
    p_state TEXT
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    department TEXT,
    district TEXT,
    state TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_state_level BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id,
        o.name,
        o.department,
        o.district,
        o.state,
        ST_Y(o.location::geometry) AS latitude,
        ST_X(o.location::geometry) AS longitude,
        o.is_state_level
    FROM offices o
    WHERE o.department = p_department
    AND (o.district = p_district OR o.is_state_level = TRUE)
    AND o.state = p_state
    ORDER BY o.is_state_level ASC;
END;
$$ LANGUAGE plpgsql;
