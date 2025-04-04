EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE
        %s
    (
        traj_id STRING,
        stop_id STRING,
        geom GEOGRAPHY,
        start_time TIMESTAMP,
        end_time TIMESTAMP,
        duration_s FLOAT64
    );
    ''',
    output_table
);
