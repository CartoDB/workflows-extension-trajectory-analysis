CREATE OR REPLACE FUNCTION 
    @@workflows_temp@@.`GET_VALUES_AT_TIMESTAMP` 
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    t_at_year FLOAT64, 
    t_at_month FLOAT64, 
    t_at_day FLOAT64, 
    t_at_hour FLOAT64, 
    t_at_minute FLOAT64, 
    t_at_second FLOAT64
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
    t_at_year,
    t_at_month,
    t_at_day,
    t_at_hour,
    t_at_minute,
    t_at_second
):

    t_at = datetime(int(t_at_year), int(t_at_month), int(t_at_day), int(t_at_hour), int(t_at_minute), int(t_at_second), tzinfo=None)

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