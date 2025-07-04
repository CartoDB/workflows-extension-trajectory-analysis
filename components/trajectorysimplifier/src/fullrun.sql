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
        simplified_cte AS (
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
                @@workflows_temp@@.TRAJECTORY_SIMPLIFIER(
                    %s,
                    %s,
                    %f,
                    %f
                )
            ) AS s
            GROUP BY %s
        )
    SELECT
        input.* EXCEPT ( %s ),
        simplified.tpoints AS %s
    FROM
        `%s` input
    INNER JOIN
        simplified_cte simplified
    ON input.%s = simplified.%s
    ''',
    create_output_query,
    traj_id_col,
    REPLACE(input_table, '`', ''),
    traj_id_col,
    tpoints_col,
    tolerance,
    rounding_precision,
    traj_id_col,
    tpoints_col,
    tpoints_col,
    REPLACE(input_table, '`', ''),
    traj_id_col,
    traj_id_col
);
