CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`TRAJECTORY_STOP_SPLITTER`
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    min_duration_sec FLOAT64,
    min_duration_min FLOAT64,
    min_duration_hour FLOAT64,
    min_duration_day FLOAT64,
    max_diameter FLOAT64,
    min_length FLOAT64
)
RETURNS ARRAY<STRUCT<seg_id STRING, lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>
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
    min_duration_sec,
    min_duration_min,
    min_duration_hour,
    min_duration_day,
    max_diameter,
    min_length
):
    # build the DataFrame
    df = pd.DataFrame.from_records(trajectory)

    if df.shape[0] <= 1:
        # Return the original trajectory
        df['seg_id'] = traj_id
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

    result = mpd.StopSplitter(traj).split(
        max_diameter=max_diameter,
        min_duration=timedelta(
            days=min_duration_day,
            hours=min_duration_hour,
            minutes=min_duration_min,
            seconds=min_duration_sec,
        ),
        min_length=min_length
    )

    if len(result) == 0:
        df['seg_id'] = traj_id
        return df.to_dict(orient='records')
    else:
        result = result.to_point_gdf().reset_index()
        result['lon'] = result.geometry.x.astype(np.float64)
        result['lat'] = result.geometry.y.astype(np.float64)
        result['seg_id'] = result.traj_id
        result = result.drop(columns=['traj_id', 'geometry'])
        return result.to_dict(orient='records')
""";


CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`TRAJECTORY_TEMPORAL_SPLITTER`
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    mode STRING,
    min_length FLOAT64
)
RETURNS ARRAY<STRUCT<seg_id STRING, lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>
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

def main(traj_id, trajectory, mode, min_length):
    # build the DataFrame
    df = pd.DataFrame.from_records(trajectory)

    if df.shape[0] <= 1:
        # Return the original trajectory
        df['seg_id'] = traj_id
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

    result = mpd.TemporalSplitter(traj).split(
        mode=mode.lower(),
        min_length=min_length
    )

    if len(result) == 0:
        df['seg_id'] = traj_id
        return df.to_dict(orient='records')
    else:
        result = result.to_point_gdf().reset_index()
        result['lon'] = result.geometry.x.astype(np.float64)
        result['lat'] = result.geometry.y.astype(np.float64)
        result['seg_id'] = result.traj_id
        result = result.drop(columns=['traj_id', 'geometry'])
        return result.to_dict(orient='records')
""";


CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`TRAJECTORY_SPEED_SPLITTER`
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    min_speed FLOAT64,
    min_duration_sec FLOAT64,
    min_duration_min FLOAT64,
    min_duration_hour FLOAT64,
    min_duration_day FLOAT64,
    min_length FLOAT64
)
RETURNS ARRAY<STRUCT<seg_id STRING, lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>
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
import json

def main(
    traj_id,
    trajectory,
    min_speed,
    min_duration_sec,
    min_duration_min,
    min_duration_hour,
    min_duration_day,
    min_length
):
    # build the DataFrame
    df = pd.DataFrame.from_records(trajectory)

    if df.shape[0] <= 1:
        # Return the original trajectory
        df['seg_id'] = traj_id
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

    result = mpd.SpeedSplitter(traj).split(
        speed=min_speed,
        duration=timedelta(
            days=min_duration_day,
            hours=min_duration_hour,
            minutes=min_duration_min,
            seconds=min_duration_sec,
        ),
        min_length=min_length
    )

    if len(result) == 0:
        df['seg_id'] = traj_id
        return df.to_dict(orient='records')
    else:
        result = result.to_point_gdf().reset_index()
        result['lon'] = result.geometry.x.astype(np.float64)
        result['lat'] = result.geometry.y.astype(np.float64)
        result['seg_id'] = result.traj_id
        result = result.drop(columns=['traj_id', 'geometry','speed'])
        return result.to_dict(orient='records')
""";


CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`TRAJECTORY_OBSERVATION_SPLITTER`
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    min_duration_sec FLOAT64,
    min_duration_min FLOAT64,
    min_duration_hour FLOAT64,
    min_duration_day FLOAT64,
    min_length FLOAT64
)
RETURNS ARRAY<STRUCT<seg_id STRING, lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>
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
    min_duration_sec,
    min_duration_min,
    min_duration_hour,
    min_duration_day,
    min_length
):
    # build the DataFrame
    df = pd.DataFrame.from_records(trajectory)

    if df.shape[0] <= 1:
        # Return the original trajectory
        df['seg_id'] = traj_id
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

    result = mpd.ObservationGapSplitter(traj).split(
        gap=timedelta(
            days=min_duration_day,
            hours=min_duration_hour,
            minutes=min_duration_min,
            seconds=min_duration_sec,
        ),
        min_length=min_length
    )

    if len(result) == 0:
        df['seg_id'] = traj_id
        return df.to_dict(orient='records')
    else:
        result = result.to_point_gdf().reset_index()
        result['lon'] = result.geometry.x.astype(np.float64)
        result['lat'] = result.geometry.y.astype(np.float64)
        result['seg_id'] = result.traj_id
        result = result.drop(columns=['traj_id', 'geometry'])
        return result.to_dict(orient='records')
""";


CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`TRAJECTORY_VALUECHANGE_SPLITTER`
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    valuechange_col STRING,
    min_length FLOAT64
)
RETURNS ARRAY<STRUCT<seg_id STRING, lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>
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
import json

def main(traj_id, trajectory, valuechange_col, min_length):
    # build the DataFrame
    df = pd.DataFrame.from_records(trajectory)
    df['properties_dict'] = df['properties'].apply(json.loads)
    df[valuechange_col] = df['properties_dict'].apply(lambda x: x.get(valuechange_col))

    # check that valuechange_col is in properties
    if len(df.dropna()) == 0:
        raise ValueError(f'Specified value-change column {valuechange_col} not found in properties')

    if df.shape[0] <= 1:
        # Return the original trajectory
        df['seg_id'] = traj_id
        return df.to_dict(orient='records')

    # build the GeoDataFrame
    gdf = (
      gpd.GeoDataFrame(
        df[['t', 'properties', valuechange_col]],
        geometry=gpd.points_from_xy(df.lon, df.lat),
        crs=4326
      )
      .set_index('t')
    )

    # build the Trajectory object
    traj = mpd.Trajectory(gdf, traj_id)

    result = mpd.ValueChangeSplitter(traj).split(
        col_name=valuechange_col,
        min_length=min_length
    )

    if len(result) == 0:
        df['seg_id'] = traj_id
        return df.to_dict(orient='records')
    else:
        result = result.to_point_gdf().reset_index()
        result['lon'] = result.geometry.x.astype(np.float64)
        result['lat'] = result.geometry.y.astype(np.float64)
        result['seg_id'] = result.traj_id
        result = result.drop(columns=['traj_id', 'geometry'])
        return result.to_dict(orient='records')
""";

CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`TRAJECTORY_ANGLECHANGE_SPLITTER`
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    min_angle FLOAT64,
    min_speed FLOAT64,
    min_length FLOAT64
)
RETURNS ARRAY<STRUCT<seg_id STRING, lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>
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
import json

def main(traj_id, trajectory, min_angle, min_speed, min_length):
    # build the DataFrame
    df = pd.DataFrame.from_records(trajectory)
    if df.shape[0] <= 1:
        # Return the original trajectory
        df['seg_id'] = traj_id
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

    result = mpd.AngleChangeSplitter(traj).split(
        min_angle=min_angle,
        min_speed=min_speed,
        min_length=min_length
    )

    if len(result) == 0:
        df['seg_id'] = traj_id
        return df.to_dict(orient='records')
    else:
        result = result.to_point_gdf().reset_index()
        result['lon'] = result.geometry.x.astype(np.float64)
        result['lat'] = result.geometry.y.astype(np.float64)
        result['seg_id'] = result.traj_id
        result = result.drop(columns=['traj_id', 'geometry'])
        return result.to_dict(orient='records')
""";
