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
        traj_id AS traj_id, 
        tpoint.lon AS lon, 
        tpoint.lat AS lat, 
        tpoint.t AS t,
        properties AS properties
        FROM CTE, UNNEST(tpoints) AS tpoint
    )
    ''',
    REPLACE(output_table, '`', ''),
    REPLACE(input_table, '`', '')
);
