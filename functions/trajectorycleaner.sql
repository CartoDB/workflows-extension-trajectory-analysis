CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`TRAJECTORY_OUTLIER_CLEANER`
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    speed_threshold FLOAT64,
    input_unit_distance STRING,
    input_unit_time STRING
)
RETURNS ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING, logs STRING>>
LANGUAGE python
OPTIONS (
    entry_point='main',
    runtime_version='python-3.11',
    packages=['numpy','pandas', 'geopandas','movingpandas']
)
AS r"""
from datetime import timedelta
import warnings

import numpy as np
import pandas as pd
import geopandas as gpd
import movingpandas as mpd

def main(
  traj_id, 
  trajectory, 
  speed_threshold,
  input_unit_distance,
  input_unit_time
):
    # build the DataFrame
    df = pd.DataFrame.from_records(trajectory)

    if df.shape[0] <= 1:
        # Return the original trajectory
        return df.to_dict(orient='records')

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

    with warnings.catch_warnings(record=True) as caught_warnings:
        warnings.simplefilter('always') 

        result = mpd.OutlierCleaner(traj).clean(v_max=speed_threshold, units=(input_unit_distance, input_unit_time))

        result = result.to_point_gdf().reset_index()
        result['lon'] = result.geometry.x.astype(np.float64)
        result['lat'] = result.geometry.y.astype(np.float64)
        result = result.drop(columns=['traj_id', 'geometry'])

        if caught_warnings:
          result['logs'] = str(caught_warnings[0].message)
        else:
          result['logs'] = ''

        return result.to_dict(orient='records')
""";
