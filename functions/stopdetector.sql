CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`TRAJECTORY_STOP_POINTS`
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    max_diameter FLOAT64,
    min_duration FLOAT64,
    duration_unit STRING
)
RETURNS ARRAY<STRUCT<stop_id STRING, geometry STRING, start_time TIMESTAMP, end_time TIMESTAMP, duration_s FLOAT64>>
LANGUAGE python
OPTIONS (
    entry_point='main',
    runtime_version='python-3.11',
    packages=['numpy','pandas', 'geopandas','movingpandas==0.22.3']
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
    min_duration,
    duration_unit,
):
    # Unit mapping from English names to short names
    time_units = {
        "Seconds": "seconds",
        "Minutes": "minutes",
        "Hours": "hours",
        "Days": "days"
    }

    # build the DataFrame
    df = pd.DataFrame.from_records(trajectory)

    if df.shape[0] <= 1:
        # Return no know stops
        return []

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

    # Convert duration to timedelta
    kwargs = {time_units[duration_unit]: min_duration}
    duration_td = timedelta(**kwargs)

    result = (
        mpd.TrajectoryStopDetector(traj)
        .get_stop_points(
            max_diameter=max_diameter,
            min_duration=duration_td,
        )
    )

    result = result.reset_index()
    result['geometry'] = result.geometry.to_wkt()

    return result.to_dict(orient='records')
""";


CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`TRAJECTORY_STOP_SEGMENTS`
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    max_diameter FLOAT64,
    min_duration FLOAT64,
    duration_unit STRING
)
RETURNS ARRAY<STRUCT<stop_id STRING, lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>
LANGUAGE python
OPTIONS (
    entry_point='main',
    runtime_version='python-3.11',
    packages=['numpy','pandas', 'geopandas','movingpandas==0.22.3']
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
    min_duration,
    duration_unit,
):
    # Unit mapping from English names to short names
    time_units = {
        "Seconds": "seconds",
        "Minutes": "minutes",
        "Hours": "hours",
        "Days": "days"
    }

    # build the DataFrame
    df = pd.DataFrame.from_records(trajectory)

    if df.shape[0] <= 1:
        # Return no know stops
        return []

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

    # Convert duration to timedelta
    kwargs = {time_units[duration_unit]: min_duration}
    duration_td = timedelta(**kwargs)

    result = (
        mpd.TrajectoryStopDetector(traj)
        .get_stop_segments(
            max_diameter=max_diameter,
            min_duration=duration_td,
        )
    )

    if not result:
        return []

    result = result.to_point_gdf().reset_index()
    result['lon'] = result.geometry.x.astype(np.float64)
    result['lat'] = result.geometry.y.astype(np.float64)
    result['stop_id'] = result.traj_id
    result = result.drop(columns=['traj_id', 'geometry'])

    return result.to_dict(orient='records')
""";
