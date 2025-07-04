DECLARE create_output_query STRING;

-- Set variables based on whether the workflow is executed via API
IF REGEXP_CONTAINS(output_table, r'^[^.]+\.[^.]+\.[^.]+$') THEN
    SET create_output_query = FORMAT('CREATE TABLE IF NOT EXISTS `%s` OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY))', REPLACE(output_table, '`', ''));
ELSE
    SET create_output_query = FORMAT('CREATE TEMPORARY TABLE `%s`', REPLACE(output_table, '`', ''));
END IF;

EXECUTE IMMEDIATE FORMAT(
    '''
    %s
    AS
    WITH
        metrics_cte AS (
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
                    %t,
                    %t,
                    %t,
                    %t,
                    %t,
                    '%s',
                    '%s',
                    '%s',                     
                    '%s',
                    '%s',
                    '%s', '%s', '%s', '%s', '%s', '%s'
                )
            ) AS s
            GROUP BY %s
        )
    SELECT
        input.* EXCEPT (%s),
        metrics.tpoints AS %s
    FROM
        `%s` input
    INNER JOIN
        metrics_cte metrics
    ON input.%s = metrics.%s
    ORDER BY input.%s
    ''',
    create_output_query,
    input_traj_id_column,
    REPLACE(input_table, '`', ''),
    input_traj_id_column,
    input_tpoints_column,
    input_distance_bool, 
    input_duration_bool,
    input_direction_bool,
    input_speed_bool, 
    input_acceleration_bool,
    IFNULL(input_distance_column, ''), 
    IFNULL(input_duration_column, ''),
    IFNULL(input_direction_column, ''),
    IFNULL(input_speed_column, ''), 
    IFNULL(input_acceleration_column, ''),
    IFNULL(input_distance_unit_distance, ''),
    IFNULL(input_speed_unit_distance, ''),
    IFNULL(input_acceleration_unit_distance, ''),
    IFNULL(input_duration_unit_time, ''),
    IFNULL(input_speed_unit_time, ''),
    IFNULL(input_acceleration_unit_time, ''),
    input_traj_id_column,
    input_tpoints_column,
    input_tpoints_column,
    REPLACE(input_table, '`', ''),
    input_traj_id_column,
    input_traj_id_column,
    input_traj_id_column
);