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
            LIMIT 0
        ),
        unnested_points AS(
            SELECT
            CTE.* EXCEPT (%s),
            ST_GEOGPOINT(0.0, 0.0) AS geom,
            TIMESTAMP('1970-01-01') AS t,
            '' AS properties
            FROM CTE, UNNEST([]) AS tpoint
        )
        %s
    )
    ''',
    REPLACE(output_table, '`', ''),
    REPLACE(input_table, '`', ''),
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
                    p1.geom AS geom_end,
                    p1.t AS t_end,
                    p1.properties AS properties_end,
                    ST_GEOGPOINT(0.0, 0.0) AS geom
                FROM numbered_points p1
                LIMIT 0
            )
            SELECT * FROM segments
            ''',
            input_traj_id_column
        )
    END
);
