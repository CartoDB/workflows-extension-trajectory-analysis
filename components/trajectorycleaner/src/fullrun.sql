EXECUTE IMMEDIATE FORMAT(
    '''
    CREATE OR REPLACE TABLE
        `%s`
    AS
    WITH
        cleaned_cte AS (
            SELECT
                traj_id,
                ARRAY_AGG(
                    STRUCT(
                      s.lon AS lon,
                      s.lat AS lat,
                      TIMESTAMP(s.t) AS t,
                      s.properties AS properties
                    )
                    ORDER BY t
                ) AS tpoints
            FROM `%s`,
            UNNEST(
                @@workflows_temp@@.TRAJECTORY_OUTLIER_CLEANER(
                    %s,
                    %s,
                    %f
                )
            ) AS s
            GROUP BY traj_id
        )
    SELECT
        input.* EXCEPT ( %s ),
        cleaned.tpoints AS %s
    FROM
        `%s` input
    INNER JOIN
        cleaned_cte cleaned
    ON input.%s = cleaned.traj_id
    ''',
    REPLACE(output_table, '`', ''),
    REPLACE(input_table, '`', ''),
    traj_id_col,
    tpoints_col,
    speed_threshold,
    tpoints_col,
    tpoints_col,
    REPLACE(input_table, '`', ''),
    traj_id_col
);
