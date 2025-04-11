EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE `%s`
    OPTIONS (
        expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    )
    AS (
        WITH CTE AS(
            SELECT *
            FROM `%s`
        )
        SELECT 
        %s AS %s, 
        tpoint.lon AS lon, 
        tpoint.lat AS lat, 
        tpoint.t AS t,
        tpoint.properties AS properties
        FROM CTE, UNNEST(%s) AS tpoint
    )
    ''',
    REPLACE(output_table, '`', ''),
    REPLACE(input_table, '`', ''),
    input_traj_id_column, input_traj_id_column,
    input_tpoints_column
);
