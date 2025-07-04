from flask import Flask, request, jsonify
import logging
import os
import time

import geopandas as gpd
import pandas as pd

from map_matching import MappyMatch
from shapely import wkt

app = Flask(__name__)

logger = logging.getLogger()
logging.basicConfig(format='%(asctime)s %(message)s', datefmt='%Y-%m-%d %I:%M:%S %p',
                    level=logging.INFO)

def parse_request_input(request_json):
    # calls will always contain a single element in this case
    # print(len(request_json["calls"]))
    call = request_json["calls"][0]

    input = dict(
        latitude = call[0],
        longitude = call[1],
        distance_epsilon = call[2],
        similarity_cutoff = call[3],
        cutting_threshold = call[4],
        random_cuts = call[5],
        distance_threshold = call[6],
        nxmap_bool = call[2],
        road_id = call[3],
        road_geom = call[4]
    )
    return input

def extract_data(input, items):
    df = {}
    for item in items:
        df.update(input[item])
    df = pd.DataFrame(df)

    return df

def solve_map_matching(input):
    absolute_start = time.time()

    # Format GPS trace data
    gps_trace = extract_data(input, ['latitude', 'longitude'])
    gps_trace = gps_trace.reset_index()
    gps_trace.columns = ['coordinate_id','latitude','longitude']
    
    # Format road network data
    road_nw = None
    if input["nxmap_bool"]:
        road_nw = extract_data(input, ['road_id', 'road_geom'])
        road_nw = road_nw.sort_values('road_id').reset_index(drop=True)
        road_nw.columns = ['road_id','geom']
        road_nw = gpd.GeoDataFrame(road_nw, geometry='geom')

    # Set advanced options
    config = {}
    config.update({'distance_epsilon': float(input['distance_epsilon'])} if input['distance_epsilon'] else {})
    config.update({'similarity_cutoff': float(input['similarity_cutoff'])} if input['similarity_cutoff'] else {})
    config.update({'cutting_threshold': float(input['cutting_threshold'])} if input['cutting_threshold'] else {})
    config.update({'random_cuts': int(input['random_cuts'])} if input['random_cuts'] else {})
    config.update({'distance_threshold': float(input['distance_threshold'])} if input['distance_threshold'] else {})

    # Run Map-matching
    mm = MappyMatch(gps_trace, road_nw, 'LCSS', config, verbose = True)
    solution_found = mm.solve()
    if solution_found:
        output = mm.res.copy()
    else:
        raise Exception("No solution found")

    absolute_end = time.time() - absolute_start
    print("Time of execution: {}".format(absolute_end))

    return output


@app.route("/", methods=['POST'])
def mapmatching():
    try:
        request_json = request.get_json()
        input = parse_request_input(request_json)
        output = solve_map_matching(input)
        replies = output.to_dict(orient='list')

        return_json = jsonify( { "replies" :  [replies]} )

    except Exception as e:
        return_json = jsonify( { "errorMessage": e } ), 400

    return return_json

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
