CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`TRAJECTORY_METRICS`
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    input_distance_bool BOOLEAN,
    input_duration_bool BOOLEAN,
    input_direction_bool BOOLEAN,
    input_speed_bool BOOLEAN,
    input_acceleration_bool BOOLEAN,
    input_distance_column STRING,
    input_duration_column STRING,
    input_direction_column STRING,
    input_speed_column STRING,
    input_acceleration_column STRING,
    input_distance_unit_distance STRING, input_speed_unit_distance STRING, input_acceleration_unit_distance STRING,
    input_duration_unit_time STRING, input_speed_unit_time STRING, input_acceleration_unit_time STRING
)
RETURNS ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>
LANGUAGE python
OPTIONS (
    entry_point='main',
    runtime_version='python-3.11',
    packages=['numpy','pandas', 'geopandas==1.1.0','movingpandas==0.22.3']
)
AS r"""
from datetime import timedelta

import numpy as np
import pandas as pd
import geopandas as gpd
import movingpandas as mpd
import json

def main(
    traj_id,
    trajectory,
    input_distance_bool,
    input_duration_bool,
    input_direction_bool,
    input_speed_bool,
    input_acceleration_bool,
    input_distance_column,
    input_duration_column,
    input_direction_column,
    input_speed_column,
    input_acceleration_column,
    input_distance_unit_distance,
    input_speed_unit_distance,
    input_acceleration_unit_distance,
    input_duration_unit_time,
    input_speed_unit_time,
    input_acceleration_unit_time
):
    # Unit mapping from English names to short names
    distance_units = {
        "Kilometers": "km",
        "Meters": "m",
        "Miles": "mi",
        "Nautical Miles": "nm"
    }

    time_units = {
        "Seconds": "s",
        "Minutes": "min",
        "Hours": "h",
        "Days": "d"
    }

    # Unit conversion factors from seconds
    time_conversions = {
        "Seconds": 1,
        "Minutes": 60,
        "Hours": 3600,
        "Days": 86400
    }
    # build the DataFrame
    df = pd.DataFrame.from_records(trajectory)

    if df.shape[0] == 0:
        return []

    # check input metrics
    input_metrics = (input_distance_bool, input_duration_bool, input_direction_bool, input_speed_bool, input_acceleration_bool)
    if not any(input_metrics):
        raise ValueError(f'Select at least one metric to compute')

    # check properties names
    input_metrics_names = (input_distance_column, input_duration_column, input_direction_column, input_speed_column, input_acceleration_column)
    col_names = list(pd.json_normalize(df['properties'].apply(lambda x : json.loads(x))).columns)
    dup_names = [x for x in input_metrics_names if x in col_names]
    if len(dup_names) > 0:
        raise ValueError(f'The following properties already exist: {dup_names}')

    def merge_json(row):
        properties_json = json.loads(row['properties']) if isinstance(row['properties'], str) else row['properties']
        other_fields = {
            input_distance_column: row.get(input_distance_column),
            input_duration_column: row.get(input_duration_column),
            input_direction_column: row.get(input_direction_column),
            input_speed_column: row.get(input_speed_column),
            input_acceleration_column: row.get(input_acceleration_column),
        }
         # Filter out empty (non-computed) metrics
        other_fields = {key: value for key, value in other_fields.items() if key}

        # Merge properties JSON with the other fields
        return json.dumps({**properties_json, **other_fields})

    # Check if trajectory has enough unique timestamps for metric calculations
    if df.empty or df.t.nunique() <= 1:
        # Return the original trajectory with empty columns for computed metrics
        result = df.copy()
        if input_distance_bool:
            result[input_distance_column] = None
        if input_duration_bool:
            result[input_duration_column] = None
        if input_direction_bool:
            result[input_direction_column] = None
        if input_speed_bool:
            result[input_speed_column] = None
        if input_acceleration_bool:
            result[input_acceleration_column] = None

        result['properties'] = result.apply(merge_json, axis=1)
        result = result[['lon', 'lat', 't', 'properties']]
        return result.to_dict(orient='records')

    # build the GeoDataFrame
    gdf = (
      gpd.GeoDataFrame(
        df[['t', 'properties']],
        geometry=gpd.points_from_xy(df.lon, df.lat),
        crs=4326
      )
      .set_index('t')
    )

    # build the Trajectory object
    traj = mpd.Trajectory(gdf, traj_id)

    if input_distance_bool:
        traj = traj.add_distance(name=input_distance_column, units=distance_units[input_distance_unit_distance])
    if input_duration_bool:
        traj = traj.add_timedelta(name=input_duration_column)
    if input_direction_bool:
        traj = traj.add_direction(name=input_direction_column)
    if input_speed_bool:
        traj = traj.add_speed(name=input_speed_column, units=(distance_units[input_speed_unit_distance], time_units[input_speed_unit_time]))
    if input_acceleration_bool:
        traj = traj.add_acceleration(name=input_acceleration_column, units=(distance_units[input_acceleration_unit_distance], time_units[input_acceleration_unit_time], time_units[input_acceleration_unit_time]))

    result = traj.to_point_gdf().reset_index()
    result['lon'] = result.geometry.x.astype(np.float64)
    result['lat'] = result.geometry.y.astype(np.float64)
    result = result[['lon', 'lat', 't', 'properties']+[x for x in input_metrics_names if x]]
    if input_duration_bool:
        result[input_duration_column] = result[input_duration_column].apply(
            lambda x: x.total_seconds() / time_conversions[input_duration_unit_time] if pd.notna(x) else 0
        )

    result['properties'] = result.apply(merge_json, axis=1)
    result = result[['lon', 'lat', 't', 'properties']]

    return result.to_dict(orient='records')
""";
