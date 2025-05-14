EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE TABLE IF NOT EXISTS
        `%s`
    OPTIONS (
        expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    )
    AS SELECT *, '' AS logs FROM `%s` WHERE FALSE;
    ''',
    REPLACE(output_table, '`', ''),
    REPLACE(input_table, '`', '')
);
