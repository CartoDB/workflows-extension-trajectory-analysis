EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE TABLE IF NOT EXISTS
        `%s`
    OPTIONS (
        expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    )
    AS 
    SELECT
        %s,
        ST_GEOGFROMTEXT('') geom,
        TIMESTAMP('') t,
        TO_JSON('') properties,
        '' road_id,
        1.0 distance_to_road,
        ST_GEOGFROMTEXT('') road_geom,
    FROM `%s`
    WHERE 1 = 0
    ;
    ''',
    REPLACE(output_table, '`', ''),
    input_traj_id_column,
    REPLACE(input_table, '`', '')
);