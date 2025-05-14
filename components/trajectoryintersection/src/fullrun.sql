EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE TABLE IF NOT EXISTS
        `%s`
    OPTIONS (
        expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    )
    AS
        WITH polygon_cte AS(
        SELECT
            *,
            ST_ASTEXT(%s) AS %s_str,
        FROM `%s`
        )
        SELECT
        %s,
        @@workflows_temp@@.TRAJECTORY_INTERSECTION(
            %s,
            %s,
            %s_str,
            '%s'
        ) AS %s
        %s
        FROM %s
    ''',
    REPLACE(output_table, '`', ''),
    polygon_col, polygon_col,
    REPLACE(input_table_polygon, '`', ''),
    traj_id_col,
    traj_id_col,
    tpoints_col,
    polygon_col,
    intersection_method,
    tpoints_col,
    CASE WHEN return_polygon_properties THEN
        FORMAT(
            ', p.* EXCEPT (%s_str)',
            polygon_col
        )
    ELSE
        ''
    END,
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
