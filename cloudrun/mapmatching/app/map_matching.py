from dataclasses import dataclass, field
from typing import Optional

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
from shapely.ops import unary_union


@dataclass(repr = False)
class MappyMatch:
    gps_trace: pd.DataFrame
    road_nw: Optional[gpd.GeoDataFrame] = field(default = gpd.GeoDataFrame)
    padding: Optional[int] = field(default = None)
    _matcher : Optional[str] = field(default = "LCSS")
    config : Optional[dict] = field(default = None)
    verbose : bool = field(default = True)

    def __post_init__(self):
        self.gps_trace = self.gps_trace.sort_values("coordinate_id")
        if not self.road_nw.empty:
            self.road_nw = self.road_nw.sort_values("road_id")
        
        if self.verbose:
            print("Data shape:", self.gps_trace.shape)
            print(self.gps_trace.head())
            print("Network map:", 'None' if self.road_nw.empty else self.road_nw.shape)
            print("Config: ", self.config)

    def _create_graph_dict(self):
        """
        Creates a graph dictionary from the road network, optionally intersected with a buffer 
        around points to limit spatial extent and improve performance.
        
        Parameters:
        - padding: Buffer radius in the units of the GeoDataFrame's CRS (default is meters).
        """

        # TODO: should we always apply padding? Or should we skip it when network is small?
        # This needs to be done in SQL to reduce the size of the network and avoid limit errors
        """
        if self.padding:
            gps = gpd.GeoDataFrame(
                self.gps_trace,
                geometry=gpd.points_from_xy(self.gps_trace['longitude'], self.gps_trace['latitude']),
                crs="EPSG:4326"
            )
            buffer_geom = unary_union(gps.to_crs('EPSG:3857').buffer(self.padding).to_crs('EPSG:4326'))
            filtered_roads = self.road_nw[self.road_nw.intersects(buffer_geom)]
        else:
            filtered_roads = self.road_nw
        """
        filtered_roads = self.road_nw.to_crs('EPSG:3857') # same crs as gps trace

        # TODO: review is allow MultiDiGraph too, though fails if no path is found...
        G = nx.MultiGraph()
        for idx, row in filtered_roads.iterrows():
            G.add_edge(
                row['start_node'],
                row['end_node'],
                id=row['road_id'],
                geometry=row['geom']
            )

        crs = CRS.from_epsg(3857) 
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
            xy=True                     # Converts lat/lon to web mercator (EPSG:3857) as cartesian distance is used
        )

        if self._matcher == 'LCSS':
            if self.road_nw.empty:
                if self.verbose:
                    print('Building georeference...')
                self.geofence = Geofence.from_trace(self.trace, padding=self.padding)
                if self.verbose:
                    print('Building nxmap...')
                self.nxmap = NxMap.from_geofence(self.geofence)
            else:
                if self.verbose:
                    print('Building nxmap...')
                self.nxmap = NxMap.from_dict(self._create_graph_dict())

            if self.verbose:
                print('Running map marching...')
            self.matcher = LCSSMatcher(self.nxmap, **self.config)

        self.matches = self.matcher.match_trace(self.trace)
        res = self.matches.matches_to_geodataframe()
        res = res.to_crs('EPSG:4326')
        res.road_id = res.road_id.astype(str)
        res['geometry'] = res['geom'].astype(str)
        self.res = self.gps_trace.merge(res[['coordinate_id', 'road_id', 'distance_to_road', 'geometry']], on='coordinate_id').copy()

        if self.verbose:
            print('Done!')

        self.solution_found = True
        
        return self.solution_found