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

    if df.empty or df.t.nunique() <= 1:
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

    result = mpd.TrajectoryStopDetector(traj).get_stop_points(
        max_diameter=max_diameter,
        min_duration=duration_td,
    )

    result = result.reset_index()
    result["geometry"] = result.geometry.to_wkt()

    return result.to_dict(orient="records")
