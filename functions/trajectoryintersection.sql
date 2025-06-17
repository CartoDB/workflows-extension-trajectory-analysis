CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`TRAJECTORY_INTERSECTION`
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    polygon STRING,
    intersection_method STRING
)
RETURNS ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>
LANGUAGE python
OPTIONS (
    entry_point='main',
    runtime_version='python-3.11',
    packages=['numpy','pandas', 'geopandas','movingpandas==0.22.3']
)
AS r"""
import numpy as np
import pandas as pd
import geopandas as gpd
import movingpandas as mpd
import json
import shapely
from shapely.wkt import loads

def main(
  traj_id, 
  trajectory, 
  polygon,
  intersection_method
):
    if not trajectory:
        return trajectory

    point_based = intersection_method == 'Points'
    polygon = loads(polygon)

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
        if shapely.intersects(gdf.geometry.iloc[0], polygon):
            return trajectory
        else:
            return []

    # build the Trajectory object
    traj = mpd.Trajectory(gdf, traj_id)

    if point_based:
        result = traj.clip(polygon, point_based = True)
        if len(result) == 0:
            return []
        result = result.to_point_gdf()
        result = result.reset_index(drop=True)
    else:
        result = traj.clip(polygon, point_based = False)
        if len(result) == 0:
            return []
        result = result.to_point_gdf().reset_index()
    result['lon'] = result.geometry.x.astype(np.float64)
    result['lat'] = result.geometry.y.astype(np.float64)
    result = result[['lon','lat','t','properties']]

    return result.to_dict(orient='records')
""";
