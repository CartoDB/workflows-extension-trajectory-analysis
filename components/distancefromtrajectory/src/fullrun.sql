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
        WITH position_cte AS(
            SELECT
                *,
                ST_ASTEXT(%s) AS %s_str
            FROM
                `%s`
        )
        SELECT
            %s,
            @@workflows_temp@@.DISTANCE_FROM_TRAJECTORY(
                %s,
                %s,
                %s_str,
                '%s',
                '%s'
            ) AS %s,
            %s
        FROM
            %s
    ''',
    create_output_query,
    position_col, position_col,
    REPLACE(input_table_position, '`', ''),
    traj_id_col,
    traj_id_col,
    tpoints_col,
    position_col,
    distance_from,
    units,
    distance_output_col,
    CASE WHEN return_position_properties THEN
        FORMAT(
            't.* EXCEPT (%s), p.* EXCEPT (%s_str %s)',
            traj_id_col,
            position_col,
            CASE WHEN position_key_col IS NOT NULL THEN
                ', ' || position_key_col
            ELSE
                ''
            END
        )
    ELSE
        FORMAT(
            't.* EXCEPT (%s), p.%s',
            traj_id_col,
            position_id_col
        )
    END,
    CASE WHEN join_type = 'Cross Join' THEN
        FORMAT(
            '`%s` t CROSS JOIN position_cte p',
            REPLACE(input_table, '`', '')
        )
    WHEN join_type = 'Key Join' THEN
        FORMAT(
            '`%s` t INNER JOIN position_cte p ON t.%s = p.%s',
            REPLACE(input_table, '`', ''),
            traj_key_col,
            position_key_col
        )
    END
);
