EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE TABLE IF NOT EXISTS
        `%s`
    OPTIONS (
        expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    )
    AS
        SELECT
            input.* EXCEPT ( %s ),
            ARRAY_AGG(
                STRUCT(
                    s.lon AS lon,
                    s.lat AS lat,
                    TIMESTAMP(s.t) AS t,
                    s.properties AS properties
                )
                ORDER BY s.t
            ) AS %s
        FROM `%s` input,
        UNNEST(
            @@workflows_temp@@.TRAJECTORY_SIMPLIFIER(
                %s,
                %s,
                %f
            )
        ) AS s
        GROUP BY %s
    ''',
    REPLACE(output_table, '`', ''),
    tpoints_col,
    tpoints_col,
    REPLACE(input_table, '`', ''),
    traj_id_col,
    tpoints_col,
    rounding_precision,
    traj_id_col
);
