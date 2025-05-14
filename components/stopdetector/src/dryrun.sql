IF method = 'Points' THEN
    EXECUTE IMMEDIATE FORMAT(
        '''
        CREATE TABLE IF NOT EXISTS
            `%s`
        (
            %s STRING,
            stop_id STRING,
            geom GEOGRAPHY,
            start_time TIMESTAMP,
            end_time TIMESTAMP,
            duration_s FLOAT64
        )
        OPTIONS (
            expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
        );
        ''',
        REPLACE(output_table, '`', ''),
        traj_id_col
    );
ELSEIF method = 'Segments' THEN
    EXECUTE IMMEDIATE FORMAT(
        '''
        CREATE TABLE IF NOT EXISTS
            `%s`
        (
            %s STRING,
            stop_id STRING,
            %s ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>
        ) OPTIONS (
            expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
        );
        ''',
        REPLACE(output_table, '`', ''),
        traj_id_col,
        tpoints_col
    );
END IF;
