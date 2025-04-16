EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE
        `%s`
    AS
        SELECT 
            %s,
            ARRAY_AGG(
                STRUCT(
                  s.lon AS lon,
                  s.lat AS lat,
                  TIMESTAMP(s.t) AS t,
                  s.properties AS properties
                )
                ORDER BY s.t
            ) AS tpoints
        FROM `%s`,
        UNNEST(
            @@workflows_temp@@.TRAJECTORY_METRICS(
                %s,
                %s,
                '%s',
                '%s',
                '%s',                     
                '%s',
                '%s',
                '%s', '%s'
            )
        ) AS s
        GROUP BY %s
        ORDER BY %s
    ''',
    REPLACE(output_table, '`', ''),
    input_traj_id_column,
    REPLACE(input_table, '`', ''),
    input_traj_id_column,
    input_tpoints_column,
    input_distance_column, 
    input_duration_column,
    input_direction_column,
    input_speed_column, 
    input_acceleration_column,
    input_unit_distance,
    input_unit_time,
    input_traj_id_column,
    input_traj_id_column
);
