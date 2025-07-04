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
        WITH polygon_cte AS(
            SELECT
                *,
                ST_ASTEXT(%s) AS %s_str
            FROM
                `%s`
        )
        SELECT
            %s,
            @@workflows_temp@@.TRAJECTORY_INTERSECTION(
                %s,
                %s,
                %s_str,
                '%s'
            ) AS %s,
        FROM
            %s
    ''',
    create_output_query,
    polygon_col, polygon_col,
    REPLACE(input_table_polygon, '`', ''),
    CASE WHEN return_polygon_properties THEN
        FORMAT(
            't.* EXCEPT (%s), p.* EXCEPT (%s_str %s)',
            tpoints_col,
            polygon_col,
            CASE WHEN polygon_key_col IS NOT NULL THEN
                ', ' || polygon_key_col
            ELSE
                ''
            END
        )
    ELSE
        FORMAT(
            't.* EXCEPT (%s)',
            tpoints_col
        )
    END,
    traj_id_col,
    tpoints_col,
    polygon_col,
    intersection_method,
    tpoints_col,
    CASE WHEN join_type = 'Cross Join' THEN
        FORMAT(
            '`%s` t CROSS JOIN polygon_cte p',
            REPLACE(input_table, '`', '')
        )
    WHEN join_type = 'Key Join' THEN
        FORMAT(
            '`%s` t INNER JOIN polygon_cte p ON t.%s = p.%s',
            REPLACE(input_table, '`', ''),
            traj_key_col,
            polygon_key_col
        )
    END
);
