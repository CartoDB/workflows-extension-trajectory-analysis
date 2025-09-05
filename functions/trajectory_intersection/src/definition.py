# /// script
# requires-python = "==3.11"
# dependencies = [
#   "numpy",
#   "pandas",
#   "geopandas==1.1.0",
#   "movingpandas==0.22.3",
# ]
# ///


import geopandas as gpd  # type: ignore[import]
import movingpandas as mpd  # type: ignore[import]
import numpy as np  # type: ignore[import]
import pandas as pd  # type: ignore[import]
import shapely  # type: ignore[import]
from shapely.wkt import loads  # type: ignore[import]


def main(traj_id, trajectory, polygon, intersection_method):
    if not trajectory:
        return trajectory

    point_based = intersection_method == "Points"
    polygon = loads(polygon)

    # build the DataFrame
    df = pd.DataFrame.from_records(trajectory)

    # build the GeoDataFrame
    gdf = gpd.GeoDataFrame(
        df[["t", "properties"]], geometry=gpd.points_from_xy(df.lon, df.lat), crs=4326
    ).set_index("t")

    if df.empty or df.t.nunique() <= 1:
        if shapely.intersects(gdf.geometry.iloc[0], polygon):
            return trajectory
        else:
            return []

    # build the Trajectory object
    traj = mpd.Trajectory(gdf, traj_id)

    if point_based:
        result = traj.clip(polygon, point_based=True)
        if len(result) == 0:
            return []
        result = result.to_point_gdf()
        result = result.reset_index(drop=True)
    else:
        result = traj.clip(polygon, point_based=False)
        if len(result) == 0:
            return []
        result = result.to_point_gdf().reset_index()
    result["lon"] = result.geometry.x.astype(np.float64)
    result["lat"] = result.geometry.y.astype(np.float64)
    result = result[["lon", "lat", "t", "properties"]]

    return result.to_dict(orient="records")
