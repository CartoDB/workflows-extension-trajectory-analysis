EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE
        %s
    (
        traj_id STRING,
        seg_id STRING,
        tpoints ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP>>
    );
    ''',
    output_table
);
