CREATE OR REPLACE FUNCTION 
    @@workflows_temp@@.`TRAJECTORY_SIMPLIFIER`
(
    traj_id STRING, 
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    rounding_precision FLOAT64
)
RETURNS ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>
LANGUAGE python
OPTIONS (
    entry_point='main',	
    runtime_version='python-3.11',
    packages=['pymeos','pandas','datetime','shapely']
)AS r"""
from pymeos import pymeos_initialize, pymeos_finalize, TGeogPointInst, TGeogPointSeq
import pandas as pd
import datetime
import shapely.wkt
pymeos_initialize()

def main(traj_id, trajectory, rounding_precision):

    if len(trajectory) <= 1:
        return trajectory

    rounding_precision = int(rounding_precision)
    df = pd.DataFrame.from_records(trajectory)
    df['geom'] = df.apply(lambda row: f"POINT ({row['lon']} {row['lat']})", axis=1)
    df['t'] = df['t'].dt.tz_localize(None)
    df['lon_rounded'] = df['lon'].round(rounding_precision)
    df['lat_rounded'] = df['lat'].round(rounding_precision)

    gpd = pd.DataFrame(df.geom, columns=['geom'])
    gpd['t'] = df.t
    gpd['t'] = pd.to_datetime(gpd['t'], errors='coerce')
    if gpd['t'].dt.tz is None:
        gpd['t'] = gpd['t'].dt.tz_localize('UTC')
    gpd['t'] = gpd['t'].dt.tz_convert('UTC')
    gpd = gpd.sort_values(by='t')
 
    gpd['instant'] = gpd.apply(
        lambda row: TGeogPointInst(string=f'{row["geom"]}@{row["t"]}'),
        axis=1,
    )
    
    trajectories = (
        gpd.groupby(lambda x: True)
        .aggregate(
            {
                "instant": lambda x: TGeogPointSeq.from_instants(x, upper_inc=True)
            }
        )
        .rename({"instant": "trajectory"}, axis=1)
    )
    trajectory = trajectories["trajectory"].values[0]
    geom = [shapely.wkt.dumps(point) for point in trajectory.values()]
    t = [time.strftime("%Y%m%d%H%M%S") for time in trajectory.timestamps()]
    
    result = pd.DataFrame({
        'geom': geom,
        't': pd.to_datetime(t, format='%Y%m%d%H%M%S')

    })
    result['t'] = result['t'].dt.tz_localize(None)
    result[['lon', 'lat']] = result['geom'].str.extract(r'POINT \(([-\d\.]+) ([-\d\.]+)\)').astype(float)
    result['lon_rounded'] = result['lon'].round(rounding_precision)
    result['lat_rounded'] = result['lat'].round(rounding_precision)
    result = pd.merge(result, df[['t','lon_rounded','lat_rounded','properties']], on=['t','lon_rounded','lat_rounded'], how = 'left')
    result = result.drop(columns=['geom', 'lon_rounded','lat_rounded'])
    return result.to_dict(orient='records')
""";
