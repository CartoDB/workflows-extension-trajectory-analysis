CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`DISTANCE_FROM_TRAJECTORY`
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    position STRING
)
RETURNS FLOAT64
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
import json
import shapely

def main(
  traj_id,
  trajectory,
  position,
):
    if not trajectory:
        return None

    # Load the position as a geometry
    position = shapely.wkt.loads(position)

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

    if gdf.shape[0] <= 1:
        # return the distance to the only point
        return shapely.distance(position, gdf.iloc[0].geometry)
    else:
        # build the Trajectory object
        traj = mpd.Trajectory(gdf, traj_id)
        return traj.distance(other=position)
""";
