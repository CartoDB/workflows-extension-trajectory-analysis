EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE
        `%s`
    AS
        SELECT s.*
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
        ORDER BY %s
    ''',
    REPLACE(output_table, '`', ''),
    REPLACE(input_table, '`', ''),
    input_traj_id_column,
    input_tpoints_column
    input_distance_column, 
    input_duration_column,
    input_direction_column,
    input_speed_column, 
    input_acceleration_column,
    input_unit_distance,
    input_unit_time,
    input_traj_id_column
);
