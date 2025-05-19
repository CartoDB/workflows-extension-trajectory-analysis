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
            position_cte AS (
                SELECT * FROM `%s` LIMIT 1
            )
        SELECT
            %s,
            0.0 AS %s
        FROM
            traj_cte t CROSS JOIN position_cte p
        WHERE FALSE
    );
    ''',
    REPLACE(output_table, '`', ''),
    REPLACE(input_table, '`', ''),
    REPLACE(input_table_position, '`', ''),
    CASE WHEN return_position_properties AND position_key_col IS NOT NULL THEN
        FORMAT(
            't.* , p.* EXCEPT ( %s )',
            position_key_col
        )
    WHEN return_position_properties AND position_key_col IS NULL THEN
        't.*, p.*'
    ELSE
        't.*'
    END,
    distance_output_col
);
