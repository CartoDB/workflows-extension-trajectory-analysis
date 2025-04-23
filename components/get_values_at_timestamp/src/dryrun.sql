EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE
        `%s`
    (
        %s STRING,
        t TIMESTAMP,
        geom GEOGRAPHY
    );
    ''',
    REPLACE(output_table, '`', ''),
    traj_id_col
);
