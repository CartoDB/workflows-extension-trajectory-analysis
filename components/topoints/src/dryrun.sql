EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE TABLE IF NOT EXISTS
        `%s`
    (
        %s
    ) OPTIONS (
        expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    );
    ''',
    REPLACE(output_table, '`', ''),
    CASE WHEN NOT output_lines THEN
        FORMAT(
            '''
            %s STRING,
            geom GEOGRAPHY,
            t TIMESTAMP,
            properties STRING
            ''',
            input_traj_id_column
        )
    WHEN output_lines THEN
        FORMAT(
            '''
            %s STRING,
            geom_start GEOGRAPHY,
            t_start TIMESTAMP,
            properties_start STRING,
            geom_end GEOGRAPHY,
            t_end TIMESTAMP,
            properties_end STRING,
            geom GEOGRAPHY
            ''',
            input_traj_id_column
        )
    END
);
