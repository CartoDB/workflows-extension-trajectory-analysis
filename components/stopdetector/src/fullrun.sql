IF method = "Points" THEN
    EXECUTE IMMEDIATE FORMAT(
        '''
        CREATE OR REPLACE TABLE
            `%s`
        AS
            SELECT
                traj_id,
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
                    %f, %f, %f, %f
                )
            ) AS s
            ORDER BY traj_id, s.stop_id
        ''',
        REPLACE(output_table, '`', ''),
        REPLACE(input_table, '`', ''),
        traj_id_col,
        tpoints_col,
        max_diameter,
        min_duration_sec, min_duration_min, min_duration_hour, min_duration_day
    );
ELSEIF method = 'Segments' THEN
    EXECUTE IMMEDIATE FORMAT(
        '''
        CREATE OR REPLACE TABLE
            `%s`
        AS
            SELECT
                traj_id,
                s.stop_id,
                ARRAY_AGG(
                    STRUCT(
                      s.lon AS lon,
                      s.lat AS lat,
                      TIMESTAMP(s.t) AS t
                    )
                    ORDER BY t
                ) AS tpoints
            FROM `%s`,
            UNNEST(
                @@workflows_temp@@.TRAJECTORY_STOP_SEGMENTS(
                    %s,
                    %s,
                    %f,
                    %f, %f, %f, %f
                )
            ) AS s
            GROUP BY traj_id, s.stop_id
            ORDER BY traj_id, s.stop_id
        ''',
        REPLACE(output_table, '`', ''),
        REPLACE(input_table, '`', ''),
        traj_id_col,
        tpoints_col,
        max_diameter,
        min_duration_sec, min_duration_min, min_duration_hour, min_duration_day
    );
END IF;
