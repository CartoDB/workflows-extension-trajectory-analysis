EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE
        `%s`
    AS
        WITH polygon_cte AS(
        SELECT
            * EXCEPT (%s),
            ST_ASTEXT(%s) AS %s,
        FROM `%s`
        )
        SELECT
        %s,
        @@workflows_temp@@.TRAJECTORY_INTERSECTION(
            %s,
            %s,
            %s,
            %s,
            %s,
            '%s'
        ) AS %s
        FROM %s
    ''',
    REPLACE(output_table, '`', ''),
    polygon_col,
    polygon_col, polygon_col,
    REPLACE(input_table_polygon, '`', ''),
    traj_id_col,
    traj_id_col,
    tpoints_col,
    polygon_col,
    polygon_properties_col,
    CASE WHEN return_polygon_properties THEN 'TRUE' ELSE 'FALSE' END,
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
