EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE TABLE IF NOT EXISTS
        `%s`
    (
        %s STRING,
        t TIMESTAMP,
        geom GEOGRAPHY
    ) OPTIONS (
        expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    );
    ''',
    REPLACE(output_table, '`', ''),
    traj_id_col
);
