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
        ),
        unnested_points AS(
            SELECT 
            CTE.* EXCEPT (%s),
            ST_GEOGPOINT(tpoint.lon, tpoint.lat) AS geom,
            tpoint.t AS t,
            tpoint.properties AS properties
            FROM CTE, UNNEST(%s) AS tpoint
        )
        %s
    )
    ''',
    REPLACE(output_table, '`', ''),
    REPLACE(input_table, '`', ''),
    input_tpoints_column,
    input_tpoints_column,
    CASE WHEN NOT output_lines THEN
        '''SELECT * FROM unnested_points'''
    WHEN output_lines THEN
        FORMAT(
            '''
            , 
            numbered_points AS (
                SELECT *,
                ROW_NUMBER() OVER (PARTITION BY %s ORDER BY t) AS rn
                FROM unnested_points
            ),
            segments AS (
                SELECT 
                    p1.* EXCEPT (geom, t, properties, rn),
                    p1.geom AS geom_start,
                    p1.t AS t_start,
                    p1.properties AS properties_start,
                    p2.geom AS geom_end,
                    p2.t AS t_end,
                    p2.properties AS properties_end,
                    ST_MAKELINE(p1.geom, p2.geom) AS geom
                FROM numbered_points p1
                JOIN numbered_points p2
                ON p1.%s = p2.%s AND p1.rn + 1 = p2.rn
            )
            SELECT * FROM segments
            ''',
            input_traj_id_column,
            input_traj_id_column, input_traj_id_column
        )
    END
);
