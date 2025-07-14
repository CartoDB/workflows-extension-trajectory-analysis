DECLARE create_output_query STRING;
DECLARE road_nw STRING;

-- Set variables based on whether the workflow is executed via API
IF REGEXP_CONTAINS(output_table, r'^[^.]+\.[^.]+\.[^.]+$') THEN
    SET create_output_query = FORMAT('CREATE TABLE IF NOT EXISTS `%s` OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY))', REPLACE(output_table, '`', ''));
ELSE
    SET create_output_query = FORMAT('CREATE TEMPORARY TABLE `%s`', REPLACE(output_table, '`', ''));
END IF;

SET road_nw = CASE road_network
        WHEN 'Overture Maps Foundation' THEN 'OMF'
        ELSE 'OSM'
    END;
    
-- TODO: decide what is the best way to output the data
EXECUTE IMMEDIATE FORMAT(
    '''
    %s
    AS (
    WITH mapmatching AS (
        SELECT %s, `cartodb-on-gcp-datascience.mapmatching._map_matching`(
            TO_JSON(%s),
            %f,
            %f,
            %f,
            %d,
            %f,
            '%s',
            %d
        ) result
        FROM `%s`
    ),
    res AS (
        SELECT %s,
            CAST(lat AS FLOAT64) lat, CAST(lon AS FLOAT64) lon, CAST(t AS TIMESTAMP) t, TO_JSON(properties) properties, 
            road_id, CAST(distance_to_road AS FLOAT64) distance_to_road, ST_GEOGFROMTEXT(geometry) road_geom, 
        FROM mapmatching, 
        UNNEST(JSON_EXTRACT_STRING_ARRAY(result,'$.coordinate_id')) AS coordinate_id WITH OFFSET AS coordinate_id_offset
        JOIN UNNEST(JSON_EXTRACT_STRING_ARRAY(result,'$.latitude')) AS lat WITH OFFSET AS lat_offset
        ON coordinate_id_offset = lat_offset
        JOIN UNNEST(JSON_EXTRACT_STRING_ARRAY(result,'$.longitude')) AS lon WITH OFFSET AS lon_offset
        ON coordinate_id_offset = lon_offset
        JOIN UNNEST(JSON_EXTRACT_STRING_ARRAY(result,'$.t')) AS t WITH OFFSET AS t_offset
        ON coordinate_id_offset = t_offset
        JOIN UNNEST(JSON_EXTRACT_STRING_ARRAY(result,'$.properties')) AS properties WITH OFFSET AS properties_offset
        ON coordinate_id_offset = properties_offset
        JOIN UNNEST(JSON_EXTRACT_STRING_ARRAY(result,'$.road_id')) AS road_id WITH OFFSET AS road_id_offset
        ON coordinate_id_offset = road_id_offset
        JOIN UNNEST(JSON_EXTRACT_STRING_ARRAY(result,'$.distance_to_road')) AS distance_to_road WITH OFFSET AS distance_to_road_offset
        ON coordinate_id_offset = distance_to_road_offset
        JOIN UNNEST(JSON_EXTRACT_STRING_ARRAY(result,'$.geometry')) AS geometry WITH OFFSET AS geometry_offset
        ON coordinate_id_offset = geometry_offset
    )
    SELECT 
        -- *, ST_GEOGPOINT(lon, lat) geom_ori, ST_CLOSESTPOINT(road_geom, ST_GEOGPOINT(lon, lat)) geom_proj
        %s, %s AS geom, t, properties, road_id, distance_to_road, road_geom
    FROM res
    )
    ''',
    create_output_query,
    input_traj_id_column,
    input_tpoints_column,
    distance_epsilon,
    similarity_cutoff,
    cutting_threshold,
    CAST(random_cuts AS INT64),
    distance_threshold,
    road_nw,
    CAST(buffer_radius AS INT64),
    REPLACE(input_table, '`', ''),
    input_traj_id_column,
    input_traj_id_column, IF(projection_bool, 'ST_CLOSESTPOINT(road_geom, ST_GEOGPOINT(lon, lat))', 'ST_GEOGPOINT(lon, lat)')
);