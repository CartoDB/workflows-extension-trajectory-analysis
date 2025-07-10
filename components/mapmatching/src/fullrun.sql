DECLARE create_output_query STRING;
DECLARE filter_network_query STRING DEFAULT '';

-- Set variables based on whether the workflow is executed via API
IF REGEXP_CONTAINS(output_table, r'^[^.]+\.[^.]+\.[^.]+$') THEN
    SET create_output_query = FORMAT('CREATE TABLE IF NOT EXISTS `%s` OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY))', REPLACE(output_table, '`', ''));
ELSE
    SET create_output_query = FORMAT('CREATE TEMPORARY TABLE `%s`', REPLACE(output_table, '`', ''));
END IF;

IF NOT osm_road_bool THEN
    -- TODO: test whether to compute this by trajectory_id or overall, what is more performant?
    SET filter_network_query = FORMAT(
        '''
        gps_buffer AS (
            SELECT ST_BUFFER(ST_GEOGPOINT(tpoint.lon, tpoint.lat), %d) geom_buffer
            FROM `%s`, UNNEST(%s) AS tpoint
        ),
        road_network AS (
            SELECT ARRAY_AGG(%s) road_id, ARRAY_AGG(%s) road_geom, ARRAY_AGG(%s) start_node, ARRAY_AGG(%s) end_node
            FROM `%s`
            JOIN gps_buffer
            ON ST_INTERSECTS(%s, geom_buffer)
        ),
        ''',
        CAST(buffer_radius AS INT64),
        REPLACE(input_table, '`', ''),
        input_tpoints_column,
        road_id, road_geom, start_node, end_node,
        REPLACE(roads_table, '`', ''),
        road_geom
    );
END IF;

-- TODO: decide what is the best way to output the data
EXECUTE IMMEDIATE FORMAT(
    '''
    %s
    AS (
    WITH 
    %s
    mapmatching AS (
        SELECT %s, `cartodb-on-gcp-datascience.mapmatching._map_matching`(
            JSON_OBJECT("tpoints", %s),
            %f,
            %f,
            %f,
            %d,
            %f,
            %t,
            %s,
            %s,
            %s,
            %s,
            %d
        ) result
        FROM `%s` %s
    ),
    res AS (
        SELECT %s,
            CAST(lat AS FLOAT64) lat, CAST(lon AS FLOAT64) lon, CAST(t AS TIMESTAMP) t, properties, 
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
    filter_network_query,
    input_traj_id_column,
    input_tpoints_column,
    distance_epsilon,
    similarity_cutoff,
    cutting_threshold,
    CAST(random_cuts AS INT64),
    distance_threshold,
    IF(osm_road_bool, False, True),
    IF(osm_road_bool, 'NULL', "JSON_OBJECT('road_id', road_id)"),
    IF(osm_road_bool, 'NULL', "JSON_OBJECT('road_geom', road_geom)"),
    IF(osm_road_bool, 'NULL', "JSON_OBJECT('start_node', start_node)"),
    IF(osm_road_bool, 'NULL', "JSON_OBJECT('end_node', end_node)"),
    CAST(buffer_radius AS INT64),
    REPLACE(input_table, '`', ''),
    IF(osm_road_bool, '', ', road_network'),
    input_traj_id_column,
    input_traj_id_column, IF(projection_bool, 'ST_CLOSESTPOINT(road_geom, ST_GEOGPOINT(lon, lat))', 'ST_GEOGPOINT(lon, lat)')
);