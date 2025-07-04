from dataclasses import dataclass, field
from typing import Union, Optional

import geopandas as gpd
import pandas as pd
import numpy as np
import random

from mappymatch.constructs.geofence import Geofence
from mappymatch.constructs.trace import Trace
from mappymatch.maps.nx.nx_map import NxMap
from mappymatch.matchers.lcss.lcss import LCSSMatcher
from networkx.readwrite import json_graph
import networkx as nx
from pyproj import CRS

@dataclass(repr = False)
class MappyMatch:
    gps_trace: pd.DataFrame
    road_nw: Optional[gpd.GeoDataFrame] = field(default = None)
    _matcher : Optional[str] = field(default = "LCSS")
    config : Optional[dict] = field(default = None)
    verbose : bool = field(default = True)

    def __post_init__(self):
        self.gps_trace = self.gps_trace.sort_values("coordinate_id")
        if self.road_nw:
            self.road_nw = self.road_nw.sort_values("road_id")
        
        if self.verbose:
            print("Data shape:", self.gps_trace.shape)
            print(self.gps_trace.head())
            print("Network map:", self.road_nw.shape if self.road_nw else 'None')
            print("Config: ", self.config)

    def _create_graph_dict(self):
        G = nx.MultiDiGraph()  
        for idx, row in self.road_nw.iterrows():
            G.add_edge(
                (row['geom'].coords[0]),   # TODO: allow user to input node names?
                (row['geom'].coords[1]),
                id=row['road_id'],
                geometry=row['geom']  
            )

        crs = CRS.from_epsg(4326) 
        crs_wkt = crs.to_wkt()
        graph_metadata = {
            "geometry_key": "geometry",
            "crs_key": "crs",
            "crs": crs_wkt
        }

        d = json_graph.node_link_data(G)
        d["graph"] = graph_metadata
        for link in d["links"]:
            link["geometry"] = link["geometry"].wkt

        return d

    
    def solve(self):

        if self.verbose:
            print('Building trace...')

        self.trace = Trace.from_dataframe(
            self.gps_trace,
            lat_column="latitude",    
            lon_column="longitude",   
            xy=True                     # converts lat/lon to web mercator (EPSG:3857) as cartesian distance is used
        )

        if self._matcher == 'LCSS':
            if not self.road_nw:
                if self.verbose:
                    print('Building georeference...')
                self.geofence = Geofence.from_trace(self.trace, padding=1e3)
                if self.verbose:
                    print('Building nxmap...')
                self.nxmap = NxMap.from_geofence(self.geofence)
            else:
                self.nxmap = NxMap.from_dict(self._create_graph_dict())

            if self.verbose:
                print('Running map marching...')
            self.matcher = LCSSMatcher(self.nxmap, **self.config)

        self.matches = self.matcher.match_trace(self.trace)
        res = self.matches.matches_to_dataframe()
        res = gpd.GeoDataFrame(res, geometry='geom', crs='EPSG:3857')
        res = res.to_crs('EPSG:4326')
        res.road_id = res.road_id.astype(str)
        res['geometry'] = res['geom'].astype(str)
        res = res.drop(columns='geom').copy()
        self.res = res

        if self.verbose:
            print('Done!')

        self.solution_found = True
        
        return self.solution_found