EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE %s
    OPTIONS (
        expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    )
    AS (
        SELECT
            *,
            @@workflows_temp@@.PYTHON_FIXED_VALUE('%s') as fixed_value_col
        FROM
            %s
    )
    ''',
    output_table,
    value,
    input_table
);
