IF return_polygon_properties THEN
    EXECUTE IMMEDIATE FORMAT(
        '''
        CREATE OR REPLACE TABLE
            `%s`
        AS
            WITH T AS(
            SELECT ST_ASTEXT(%s) AS %s, 
                %s
            FROM `%s` 
            )
            SELECT
            %s,
            @@workflows_temp@@.TRAJECTORY_INTERSECTION(
                %s,
                %s,
                %s,
                %s,
                TRUE,
                '%s'
            ) AS %s
            FROM `%s`
            CROSS JOIN T
        ''',
        REPLACE(output_table, '`', ''),
        polygon_col, polygon_col,
        polygon_properties_col,
        REPLACE(input_table_polygon, '`', ''),
        traj_id_col,
        traj_id_col,
        tpoints_col,
        polygon_col,
        polygon_properties_col,
        intersection_method,
        tpoints_col,
        REPLACE(input_table, '`', '')
    );
ELSE
    EXECUTE IMMEDIATE FORMAT(
        '''
        CREATE OR REPLACE TABLE
            `%s`
        AS
            WITH T AS(
            SELECT ST_ASTEXT(%s) AS %s, 
                %s
            FROM `%s` 
            )
            SELECT
            %s,
            @@workflows_temp@@.TRAJECTORY_INTERSECTION(
                %s,
                %s,
                %s,
                %s,
                FALSE,
                '%s'
            ) AS %s
            FROM `%s`
            CROSS JOIN T
        ''',
        REPLACE(output_table, '`', ''),
        polygon_col, polygon_col,
        polygon_properties_col,
        REPLACE(input_table_polygon, '`', ''),
        traj_id_col,
        traj_id_col,
        tpoints_col,
        polygon_col,
        polygon_properties_col,
        intersection_method,
        tpoints_col,
        REPLACE(input_table, '`', '')
    );
END IF;