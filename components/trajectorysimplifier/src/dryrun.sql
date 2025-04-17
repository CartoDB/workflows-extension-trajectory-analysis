EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE
        `%s`
    (
        %s STRING,
        %s ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties JSON>>
    );
    ''',
    REPLACE(output_table, '`', ''),
    traj_id_col,
    tpoints_col
);
