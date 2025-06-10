CREATE OR REPLACE FUNCTION 
    @@workflows_temp@@.`GET_VALUES_AT_TIMESTAMP` 
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    timestamp_str STRING
)
RETURNS STRUCT<t TIMESTAMP, geom STRING>
LANGUAGE python
OPTIONS (
    entry_point='main',
    runtime_version='python-3.11',
    packages=['numpy','pandas', 'geopandas','movingpandas']
)
AS r"""
import numpy as np
import pandas as pd
import geopandas as gpd
import movingpandas as mpd
from datetime import datetime, timezone
from shapely.wkt import dumps

def main(
    traj_id,
    trajectory,
    timestamp_str
):

    t_at = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))

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

     # Get the nearest positions to the provided timestamp
    geoms = traj.interpolate_position_at(t_at)

    return {
        "t": t_at,
        "geom": dumps(geoms)
    } if geoms else None
""";