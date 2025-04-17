EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE
        `%s`
    AS
        SELECT
            %s,
            ARRAY_AGG(
                STRUCT(
                s.lon AS lon,
                s.lat AS lat,
                TIMESTAMP(s.t) AS t,
                s.properties AS properties
                )
                ORDER BY s.t
            ) AS tpoints
        FROM `%s`,
        UNNEST(
            @@workflows_temp@@.TRAJECTORY_SIMPLIFIER(
                %s,
                %s
            )
        ) AS s
        GROUP BY %s
    ''',
    REPLACE(output_table, '`', ''),
    traj_id_col,
    REPLACE(input_table, '`', ''),
    traj_id_col,
    tpoints_col,
    traj_id_col
);
