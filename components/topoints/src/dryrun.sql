EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE
        `%s`
    (
        %s
    );
    ''',
    REPLACE(output_table, '`', ''),
    CASE WHEN NOT output_lines THEN
        FORMAT(
            '''
            %s STRING,
            lon FLOAT64,
            lat FLOAT64,
            t TIMESTAMP,
            properties STRING
            ''',
            input_traj_id_column
        )
    WHEN output_lines THEN
        FORMAT(
            '''
            %s STRING,
            lon_start FLOAT64,
            lat_start FLOAT64,
            t_start TIMESTAMP,
            properties_start STRING,
            lon_end FLOAT64,
            lat_end FLOAT64,
            t_end TIMESTAMP,
            properties_end STRING,
            geom GEOGRAPHY
            ''',
            input_traj_id_column
        )
    END
);
