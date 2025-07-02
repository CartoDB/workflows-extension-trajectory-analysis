DECLARE create_output_query STRING;

-- Set variables based on whether the workflow is executed via API
IF REGEXP_CONTAINS(output_table, r'^[^.]+\.[^.]+\.[^.]+$') THEN
    SET create_output_query = FORMAT('CREATE TABLE IF NOT EXISTS `%s` OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY))', REPLACE(output_table, '`', ''));
ELSE
    SET create_output_query = FORMAT('CREATE TEMPORARY TABLE `%s`', REPLACE(output_table, '`', ''));
END IF;

EXECUTE IMMEDIATE FORMAT(
    '''
    %s
    AS
        WITH result AS (
            SELECT
                %s,
                @@workflows_temp@@.GET_VALUES_AT_TIMESTAMP(
                    %s,
                    %s,
                    '%s'
                ) AS values_at_timestamp
                FROM `%s`
        )
        SELECT
            %s,
            values_at_timestamp.t AS t,
            ST_GEOGFROMTEXT(values_at_timestamp.geom) AS geom
        FROM result
    ''',
    create_output_query,
    traj_id_col,
    traj_id_col,
    tpoints_col,
    timestamp,
    REPLACE(input_table, '`', ''),
    traj_id_col
);
