EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE
        `%s`
    (
        %s STRING,
        %s ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING >>
    );
    ''',
    REPLACE(output_table, '`', ''),
    input_traj_id_column,
    input_tpoints_column
);
