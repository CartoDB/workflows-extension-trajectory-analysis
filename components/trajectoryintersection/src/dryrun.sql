EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE TABLE IF NOT EXISTS
        `%s`
    OPTIONS (
        expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    )
    AS (
        WITH
            traj_cte AS (
                SELECT * FROM `%s` LIMIT 1
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
    REPLACE(input_table, '`', ''),
    REPLACE(input_table_polygon, '`', ''),
    CASE WHEN return_polygon_properties AND polygon_key_col IS NOT NULL THEN
        FORMAT(
            't.* , p.* EXCEPT ( %s )',
            polygon_key_col
        )
    WHEN return_polygon_properties AND polygon_key_col IS NULL THEN
        't.*, p.*'
    ELSE
        't.*'
    END
);
