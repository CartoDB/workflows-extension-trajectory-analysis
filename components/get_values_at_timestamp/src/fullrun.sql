EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE
        `%s`
    AS
        WITH result AS (
            SELECT
                %s,
                @@workflows_temp@@.GET_VALUES_AT_TIMESTAMP(
                    %s,
                    %s,
                    %f, %f, %f, %f, %f, %f
                ) AS values_at_timestamp
                FROM `%s`
        )
        SELECT
            %s,
            values_at_timestamp.t AS t,
            ST_GEOGFROMTEXT(values_at_timestamp.geom) AS geom
        FROM result
    ''',
    REPLACE(output_table, '`', ''),
    traj_id_col,
    traj_id_col,
    tpoints_col,
    t_at_year, t_at_month, t_at_day, t_at_hour, t_at_minute, t_at_second,
    REPLACE(input_table, '`', ''),
    traj_id_col
);