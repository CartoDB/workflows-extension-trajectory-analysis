CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`TRAJECTORY_INTERSECTION`
(
    traj_id STRING,
    trajectory ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>,
    polygon STRING,
    polygon_properties STRING,
    return_polygon_features BOOL,
    intersection_method STRING
)
RETURNS ARRAY<STRUCT<lon FLOAT64, lat FLOAT64, t TIMESTAMP, properties STRING>>
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
from shapely.wkt import loads

def main(
  traj_id, 
  trajectory, 
  polygon,
  polygon_properties,
  return_polygon_features,
  intersection_method
):

    if intersection_method == 'Segments':
        point_based = False
    else:
        point_based = True

    polygon = loads(polygon)
    polygon_properties = json.loads(polygon_properties)
    polygon_feature = {
        "geometry": polygon,
        "properties": polygon_properties
    }

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

    if return_polygon_features:
        if point_based:
            result = traj.intersection(polygon_feature, point_based = True)
            if len(result) == 0:
                return []
            result = result.to_point_gdf()
            result = result.reset_index(drop=True)
        else:
            result = traj.intersection(polygon_feature, point_based = False)
            if len(result) == 0:
                return []
            
            result = result.to_point_gdf().reset_index()
        def update_properties(properties, dict_obj):
            properties = eval(properties)
            return {**properties, **dict_obj}

        result['properties'] = result['properties'].apply(
            lambda p: json.dumps(update_properties(p, polygon_properties))
        )
        result['lon'] = result.geometry.x.astype(np.float64)
        result['lat'] = result.geometry.y.astype(np.float64)
        result = result[['lon','lat','t','properties']]
    else:
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