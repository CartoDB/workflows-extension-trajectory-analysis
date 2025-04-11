EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE `%s`
    OPTIONS (
        expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    )
    AS (
        SELECT %s AS traj_id, 
        ARRAY_AGG(STRUCT(%s AS lon, %s AS lat, %s AS t, %s AS properties)) AS tpoints,
        FROM `%s`
        GROUP BY %s
    )
    ''',
    REPLACE(output_table, '`', ''),
    input_traj_id_column,
    input_lon_column,
    input_lat_column,
    input_t_column,
    input_properties_column,
    REPLACE(input_table, '`', ''),
    input_traj_id_column
);
