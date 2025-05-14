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
    CASE WHEN return_polygon_properties THEN
        FORMAT(
            't.* EXCEPT (%s), p.* %s',
            traj_id_col,
            CASE WHEN polygon_key_col IS NOT NULL THEN
                ' EXCEPT (' || polygon_key_col || ')'
            ELSE
                ''
            END
        )
    ELSE
        FORMAT(
            't.* EXCEPT (%s)',
            traj_id_col
        )
    END
);
