CREATE OR REPLACE FUNCTION `cartodb-on-gcp-datascience.mapmatching._map_matching`(
        latitude JSON,
        longitude JSON,
        nxmap_bool BOOLEAN,
        road_id JSON,
        road_geom JSON
) RETURNS JSON 
REMOTE WITH CONNECTION `267312430260.us.tb-connection-hackathon`  
OPTIONS( max_batching_rows = 1, endpoint = 'https://map-matching-267312430260.us-east1.run.app'
);