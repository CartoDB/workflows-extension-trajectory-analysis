EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE TABLE IF NOT EXISTS
        `%s`
    (
        % FLOAT64,
        geom GEOGRAPHY,
        t TIMESTAMP,
        properties STRING,
        road_id FLOAT64,
        distance_to_road FLOAT64,
        geom_road GEOGRAPHY
    ) OPTIONS (
        expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    );
    ''',
    input_traj_id_column,
    REPLACE(output_table, '`', '')
);