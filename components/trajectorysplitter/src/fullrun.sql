EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE
        %s
    AS
        SELECT
            %s,
            p.seg_id,
            ARRAY_AGG(
                STRUCT(
                  p.lon AS lon,
                  p.lat AS lat,
                  TIMESTAMP(p.t) AS t
                )
                ORDER BY t
            ) AS tpoints
        FROM %s,
        UNNEST(
            %s
        ) AS p
        GROUP BY %s, p.seg_id
        ORDER BY %s, p.seg_id
    ''',
    output_table,
    traj_id_col,
    input_table,
    CASE WHEN method = 'Stops' THEN
        FORMAT(
            '''
            @@workflows_temp@@.TRAJECTORY_STOP_SPLITTER(
                %s,
                %s,
                %f, %f, %f, %f,
                %f,
                %f
            )
            ''',
            traj_id_col,
            tpoints_col,
            min_duration_sec, min_duration_min, min_duration_hour, min_duration_day,
            max_diameter,
            min_length
        )
    WHEN method = 'Temporal' THEN
        FORMAT(
            '''
            @@workflows_temp@@.TRAJECTORY_TEMPORAL_SPLITTER(
                %s,
                %s,
                '%s',
                %f
            )
            ''',
            traj_id_col,
            tpoints_col,
            time_mode,
            min_length
        )
    WHEN method = 'Speed' THEN
        FORMAT(
            '''
            @@workflows_temp@@.TRAJECTORY_SPEED_SPLITTER(
                %s,
                %s,
                %f,
                %f, %f, %f, %f,
                %f
            )
            ''',
            traj_id_col,
            tpoints_col,
            min_speed,
            min_duration_sec, min_duration_min, min_duration_hour, min_duration_day,
            min_length
        )
    END,
    traj_id_col,
    traj_id_col
);
