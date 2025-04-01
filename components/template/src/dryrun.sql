-- This is the sample code for the BigQuery dryrun.
-------------------------------------------------------

EXECUTE IMMEDIATE '''
CREATE TABLE IF NOT EXISTS ''' || output_table || '''
OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 30 DAY))
AS SELECT *, \'''' || value || '''\' AS fixed_value_col
FROM ''' || input_table || '''
WHERE 1 = 0;
''';


-- This is the sample code for the Snowflake dryrun.
---------------------------------------------------------
/*
EXECUTE IMMEDIATE '
CREATE TABLE IF NOT EXISTS ' || :output_table || '
AS SELECT *, ''' || :value || ''' AS fixed_value_col
FROM ' || :input_table || '
WHERE 1 = 0;
';
*/