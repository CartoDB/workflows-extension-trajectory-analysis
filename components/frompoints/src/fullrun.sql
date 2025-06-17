DECLARE non_points INT64;

EXECUTE IMMEDIATE FORMAT(
    '''
    SELECT COUNT(*)
    FROM `%s`
    WHERE ST_GEOMETRYTYPE(%s) != 'ST_Point'
    ''',
    REPLACE(input_table, '`', ''),
    input_geom_column
) INTO non_points;

IF non_points > 0 THEN
    RAISE USING MESSAGE = FORMAT('Error: Found %d non-point geometries in column %s. Only POINT geometries are supported.', non_points, input_geom_column);
END IF;

EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE `%s`
    OPTIONS (
        expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    )
    AS (
        SELECT
            %s,
            ARRAY_AGG(
                STRUCT(
                    ST_X(%s) AS lon,
                    ST_Y(%s) AS lat,
                    CAST(%s AS TIMESTAMP) AS t,
                    %s
                )
                ORDER BY %s
            ) AS %s,
        FROM `%s`
        GROUP BY %s
    )
    ''',
    REPLACE(output_table, '`', ''),
    input_traj_id_column,
    input_geom_column,
    input_geom_column,
    input_t_column,
    CASE WHEN (input_properties_columns IS NULL OR input_properties_columns = '') THEN
        "'{}' AS properties"
    ELSE
        FORMAT('TO_JSON_STRING((SELECT AS STRUCT %s)) AS properties', input_properties_columns)
    END,
    input_t_column,
    input_tpoints_column, 
    REPLACE(input_table, '`', ''),
    input_traj_id_column
);
