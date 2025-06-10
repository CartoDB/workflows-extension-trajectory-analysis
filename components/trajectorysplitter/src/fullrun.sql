EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE TABLE IF NOT EXISTS
        `%s`
    OPTIONS (
        expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    )
    AS
        SELECT
            input.* EXCEPT ( %s ),
            p.seg_id,
            ARRAY_AGG(
                STRUCT(
                  p.lon AS lon,
                  p.lat AS lat,
                  TIMESTAMP(p.t) AS t,
                  p.properties AS properties
                )
                ORDER BY p.t
            ) AS %s
        FROM `%s` input,
        UNNEST(
            %s
        ) AS p
        GROUP BY input.%s, p.seg_id
        ORDER BY input.%s, p.seg_id
    ''',
    REPLACE(output_table, '`', ''),
    tpoints_col,
    tpoints_col,
    REPLACE(input_table, '`', ''),
    CASE WHEN method = 'Stops' THEN
        FORMAT(
            '''
            @@workflows_temp@@.TRAJECTORY_STOP_SPLITTER(
                %s,
                %s,
                %f, '%s',
                %f,
                %f
            )
            ''',
            traj_id_col,
            tpoints_col,
            min_duration, duration_unit,
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
                %f, '%s',
                %f
            )
            ''',
            traj_id_col,
            tpoints_col,
            min_speed,
            min_duration_sec, min_duration_min, min_duration_hour, min_duration_day,
            min_length
        )
    WHEN method = 'Observation Gap' THEN
        FORMAT(
            '''
            @@workflows_temp@@.TRAJECTORY_OBSERVATION_SPLITTER(
                %s,
                %s,
                %f, %f, %f, %f,
                %f
            )
            ''',
            traj_id_col,
            tpoints_col,
            min_duration_sec, min_duration_min, min_duration_hour, min_duration_day,
            min_length
        )
    WHEN method = 'Value Change' THEN
        FORMAT(
            '''
            @@workflows_temp@@.TRAJECTORY_VALUECHANGE_SPLITTER(
                %s,
                %s,
                '%s',
                %f
            )
            ''',
            traj_id_col,
            tpoints_col,
            valuechange_col,
            min_length
        )
    WHEN method = 'Angle Change' THEN
        FORMAT(
            '''
            @@workflows_temp@@.TRAJECTORY_ANGLECHANGE_SPLITTER(
                %s,
                %s,
                %f,
                %f,
                %f
            )
            ''',
            traj_id_col,
            tpoints_col,
            min_angle, 
            min_speed,
            min_length
        )
    END,
    traj_id_col,
    traj_id_col
);
