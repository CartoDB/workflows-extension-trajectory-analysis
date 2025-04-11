EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE
        `%s`
    AS SELECT * FROM `%s` WHERE FALSE;
    ''',
    REPLACE(output_table, '`', ''),
    REPLACE(input_table, '`', '')
);
