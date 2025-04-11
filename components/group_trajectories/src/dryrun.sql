EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE `%s`
    OPTIONS (
        expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    )
    AS (
        SELECT %s AS %s, 
        ARRAY_AGG(STRUCT(CAST(%s AS FLOAT64) AS lon,CAST(%s AS FLOAT64) AS lat, CAST(%s AS TIMESTAMP) AS t, %s AS properties)) AS %s,
        FROM `%s`
        WHERE 1 = 0
        GROUP BY %s
    )
    ''',
    REPLACE(output_table, '`', ''),
    input_traj_id_column, input_traj_id_column,
    input_lon_column,
    input_lat_column,
    input_t_column,
    input_properties_column,
    input_tpoints_column, 
    REPLACE(input_table, '`', ''),
    input_traj_id_column
);
