CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`TRAJECTORY_STOP_DETECTOR`
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP>>,
    max_diameter FLOAT64,
    min_duration_sec FLOAT64,
    min_duration_min FLOAT64,
    min_duration_hour FLOAT64,
    min_duration_day FLOAT64
)
RETURNS ARRAY<STRUCT<stop_id STRING, geometry STRING, start_time TIMESTAMP, end_time TIMESTAMP, duration_s FLOAT64>>
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

def main(
    traj_id,
    trajectory,
    max_diameter,
    min_duration_sec,
    min_duration_min,
    min_duration_hour,
    min_duration_day,
):
    # build the DataFrame
    df = pd.DataFrame.from_records(trajectory)

    # build the GeoDataFrame
    gdf = (
      gpd.GeoDataFrame(
        df[['t']],
        geometry=gpd.points_from_xy(df.lon, df.lat),
        crs=4326
      )
      .set_index('t')
    )

    # build the Trajectory object
    traj = mpd.Trajectory(gdf, traj_id)

    result = (
        mpd.TrajectoryStopDetector(traj)
        .get_stop_points(
            max_diameter=max_diameter,
            min_duration=timedelta(
                days=min_duration_day,
                hours=min_duration_hour,
                minutes=min_duration_min,
                seconds=min_duration_sec,
            ),
        )
    )

    result = result.reset_index()
    result['geometry'] = result.geometry.to_wkt()

    return result.to_dict(orient='records')
""";
