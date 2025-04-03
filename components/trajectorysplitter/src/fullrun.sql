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
            @@workflows_temp@@.TRAJECTORY_STOP_SPLITTER(
                %s,
                %s,
                %f, %f, %f, %f,
                %f,
                %f
            )
        ) AS p
        GROUP BY %s, p.seg_id
        ORDER BY %s, p.seg_id
    ''',
    output_table,
    traj_id_col,
    input_table,
    traj_id_col,
    tpoints_col,
    min_duration_sec, min_duration_min, min_duration_hour, min_duration_day,
    max_diameter,
    min_length,
    traj_id_col,
    traj_id_col
);
