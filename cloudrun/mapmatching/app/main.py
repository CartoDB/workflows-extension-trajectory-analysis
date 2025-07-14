from flask import Flask, request, jsonify
import logging
import os
import time
import pandas as pd

from map_matching import MappyMatch

app = Flask(__name__)

logger = logging.getLogger()
logging.basicConfig(format='%(asctime)s %(message)s', datefmt='%Y-%m-%d %I:%M:%S %p',
                    level=logging.INFO)

def parse_request_input(request_json):
    # calls will always contain a single element in this case
    # print(len(request_json["calls"]))
    call = request_json["calls"][0]

    input = dict(
        tpoints = call[0],
        distance_epsilon = call[1],
        similarity_cutoff = call[2],
        cutting_threshold = call[3],
        random_cuts = call[4],
        distance_threshold = call[5],
        road_nw = call[6],
        buffer_radius = call[7]
    )
    return input

def solve_map_matching(input):
    absolute_start = time.time()

    # Set road network
    road_nw = input["road_nw"]

    # Format GPS trace data
    gps_trace = pd.DataFrame.from_records(input["tpoints"])
    print(gps_trace.columns)
    gps_trace = gps_trace.sort_values('t').reset_index()
    gps_trace = gps_trace.rename(columns={'index': 'coordinate_id', 'lat': 'latitude', 'lon':'longitude'})

    # Set advanced options
    config = {}
    config.update({'distance_epsilon': float(input['distance_epsilon'])} if input['distance_epsilon'] else {})
    config.update({'similarity_cutoff': float(input['similarity_cutoff'])} if input['similarity_cutoff'] else {})
    config.update({'cutting_threshold': float(input['cutting_threshold'])} if input['cutting_threshold'] else {})
    config.update({'random_cuts': int(input['random_cuts'])} if input['random_cuts'] else {})
    config.update({'distance_threshold': float(input['distance_threshold'])} if input['distance_threshold'] else {})
    buffer_radius = input["buffer_radius"]

    # Run Map-matching
    mm = MappyMatch(gps_trace, road_nw, buffer_radius, 'LCSS', config, verbose = True)
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
