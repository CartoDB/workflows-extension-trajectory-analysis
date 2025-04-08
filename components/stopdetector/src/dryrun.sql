IF method = 'Points' THEN
    EXECUTE IMMEDIATE FORMAT(
        '''
        CREATE OR REPLACE TABLE
            `%s`
        (
            traj_id STRING,
            stop_id STRING,
            geom GEOGRAPHY,
            start_time TIMESTAMP,
            end_time TIMESTAMP,
            duration_s FLOAT64
        );
        ''',
        REPLACE(output_table, '`', '')
    );
ELSEIF method = 'Segments' THEN
    EXECUTE IMMEDIATE FORMAT(
        '''
        CREATE OR REPLACE TABLE
            `%s`
        (
            traj_id STRING,
            stop_id STRING,
            tpoints ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP>>
        );
        ''',
        REPLACE(output_table, '`', '')
    );
END IF;
