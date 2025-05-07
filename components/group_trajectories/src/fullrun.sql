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
                    CAST(%s AS FLOAT64) AS lon,
                    CAST(%s AS FLOAT64) AS lat,
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
    input_lon_column,
    input_lat_column,
    input_t_column,
    CASE WHEN (input_properties_columns IS NOT NULL) THEN
        FORMAT('TO_JSON_STRING((SELECT AS STRUCT %s)) AS properties', input_properties_columns)
    ELSE
        "'{}' AS properties"
    END,
    input_t_column,
    input_tpoints_column, 
    REPLACE(input_table, '`', ''),
    input_traj_id_column
);
