EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE
        `%s`
    AS (
        WITH
            traj_cte AS (
                SELECT %s, %s FROM `%s` LIMIT 1
            ),
            polygon_cte AS (
                SELECT * FROM `%s` LIMIT 1
            )
        SELECT
            %s
        FROM
            traj_cte t CROSS JOIN polygon_cte p
        WHERE FALSE
    );
    ''',
    REPLACE(output_table, '`', ''),
    traj_id_col, tpoints_col, REPLACE(input_table, '`', ''),
    REPLACE(input_table_polygon, '`', ''),
    CASE WHEN return_polygon_properties THEN 't.*, p.*' ELSE 't.*' END
);
