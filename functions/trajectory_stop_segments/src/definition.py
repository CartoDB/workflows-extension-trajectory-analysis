# /// script
# requires-python = "==3.11"
# dependencies = [
#   "numpy",
#   "pandas",
#   "geopandas==1.1.0",
#   "movingpandas==0.22.3",
# ]
# ///


from datetime import timedelta

import geopandas as gpd  # type: ignore[import]
import movingpandas as mpd  # type: ignore[import]
import numpy as np  # type: ignore[import]
import pandas as pd  # type: ignore[import]


def main(
    traj_id,
    trajectory,
    max_diameter,
    min_duration,
    duration_unit,
):
    # Unit mapping from English names to short names
    time_units = {
        "Seconds": "seconds",
        "Minutes": "minutes",
        "Hours": "hours",
        "Days": "days",
    }

    # build the DataFrame
    df = pd.DataFrame.from_records(trajectory)

    if df.shape[0] <= 1:
        # Return no know stops
        return []

    # build the GeoDataFrame
    gdf = gpd.GeoDataFrame(
        df[["t", "properties"]], geometry=gpd.points_from_xy(df.lon, df.lat), crs=4326
    ).set_index("t")

    # build the Trajectory object
    traj = mpd.Trajectory(gdf, traj_id)

    # Convert duration to timedelta
    kwargs = {time_units[duration_unit]: min_duration}
    duration_td = timedelta(**kwargs)

    result = mpd.TrajectoryStopDetector(traj).get_stop_segments(
        max_diameter=max_diameter,
        min_duration=duration_td,
    )

    if not result:
        return []

    result = result.to_point_gdf().reset_index()
    result["lon"] = result.geometry.x.astype(np.float64)
    result["lat"] = result.geometry.y.astype(np.float64)
    result["stop_id"] = result.traj_id
    result = result.drop(columns=["traj_id", "geometry"])

    return result.to_dict(orient="records")
