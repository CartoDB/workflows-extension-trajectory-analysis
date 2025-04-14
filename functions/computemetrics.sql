CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`TRAJECTORY_METRICS`
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    input_distance_column STRING,
    input_duration_column STRING,
    input_direction_column STRING,
    input_speed_column STRING,
    input_acceleration_column STRING, 
    input_unit_distance STRING, input_unit_time STRING
)
RETURNS ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>
LANGUAGE python
OPTIONS (
    entry_point='main',
    runtime_version='python-3.11',
    packages=['numpy','pandas', 'geopandas','movingpandas']
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
    input_distance_column,
    input_duration_column,
    input_direction_column,
    input_speed_column,
    input_acceleration_column,
    input_unit_distance,
    input_unit_time

):
    # build the DataFrame
    df = pd.DataFrame.from_records(trajectory)

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

    traj = traj.add_distance(name=input_distance_column, units=input_unit_distance)
    traj = traj.add_timedelta(name=input_duration_column)
    traj = traj.add_direction(name=input_direction_column)
    traj = traj.add_speed(name=input_speed_column, units=(input_unit_distance, input_unit_time))
    traj = traj.add_acceleration(name=input_acceleration_column, units=(input_unit_distance, input_unit_time, input_unit_time))

    result = traj.to_point_gdf().reset_index()
    result['lon'] = result.geometry.x.astype(np.float64)
    result['lat'] = result.geometry.y.astype(np.float64)
    result = result[['lon', 'lat', 't', 'properties',input_distance_column,input_duration_column,input_direction_column, input_speed_column,input_acceleration_column]]
    result[input_duration_column] = result[input_duration_column].apply(
        lambda x: x.total_seconds() if pd.notna(x) else 0
    )

    def merge_json(row):
        properties_json = json.loads(row['properties']) if isinstance(row['properties'], str) else row['properties']
        other_fields = {
            input_distance_column: row[input_distance_column],
            input_duration_column: row[input_duration_column],
            input_direction_column: row[input_direction_column],
            input_speed_column: row[input_speed_column],
            input_acceleration_column: row[input_acceleration_column],
        }
        # Merge properties JSON with the other fields
        return json.dumps({**properties_json, **other_fields})

    result['properties'] = result.apply(merge_json, axis=1)
    result = result[['lon', 'lat', 't', 'properties']]

    return result.to_dict(orient='records')
""";
