IF method = "Points" THEN
    EXECUTE IMMEDIATE FORMAT(
        '''
        CREATE TABLE IF NOT EXISTS
            `%s`
        OPTIONS (
            expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
        )
        AS
            SELECT
                %s,
                s.stop_id,
                ST_GEOGFROMTEXT(s.geometry) AS geom,
                s.start_time,
                s.end_time,
                s.duration_s
            FROM `%s`,
            UNNEST(
                @@workflows_temp@@.TRAJECTORY_STOP_POINTS(
                    %s,
                    %s,
                    %f,
                    %f, '%s'
                )
            ) AS s
            ORDER BY %s, s.stop_id
        ''',
        REPLACE(output_table, '`', ''),
        traj_id_col,
        REPLACE(input_table, '`', ''),
        traj_id_col,
        tpoints_col,
        max_diameter,
        min_duration, duration_unit,
        traj_id_col
    );
ELSEIF method = 'Segments' THEN
    EXECUTE IMMEDIATE FORMAT(
        '''
        CREATE TABLE IF NOT EXISTS
            `%s`
        OPTIONS (
            expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
        ) AS
            SELECT
                %s,
                s.stop_id,
                ARRAY_AGG(
                    STRUCT(
                      s.lon AS lon,
                      s.lat AS lat,
                      TIMESTAMP(s.t) AS t,
                      s.properties AS properties
                    )
                    ORDER BY t
                ) AS tpoints
            FROM `%s`,
            UNNEST(
                @@workflows_temp@@.TRAJECTORY_STOP_SEGMENTS(
                    %s,
                    %s,
                    %f,
                    %f, '%s'
                )
            ) AS s
            GROUP BY %s, s.stop_id
            ORDER BY %s, s.stop_id
        ''',
        REPLACE(output_table, '`', ''),
        traj_id_col,
        REPLACE(input_table, '`', ''),
        traj_id_col,
        tpoints_col,
        max_diameter,
        min_duration, duration_unit,
        traj_id_col, traj_id_col
    );
END IF;
