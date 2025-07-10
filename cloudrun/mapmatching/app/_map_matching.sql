CREATE OR REPLACE FUNCTION `cartodb-on-gcp-datascience.mapmatching._map_matching`(
        tpoints JSON,
        distance_epsilon FLOAT64,
        similarity_cutoff FLOAT64,
        cutting_threshold FLOAT64,
        random_cuts INT64,
        distance_threshold FLOAT64,
        nxmap_bool BOOLEAN,
        road_id JSON,
        road_geom JSON,
        start_node JSON,
        end_node JSON,
        buffer_radius INT64
) RETURNS JSON 
REMOTE WITH CONNECTION `267312430260.us.tb-connection-hackathon`  
OPTIONS( max_batching_rows = 1, endpoint = 'https://map-matching-267312430260.us-east1.run.app'
);