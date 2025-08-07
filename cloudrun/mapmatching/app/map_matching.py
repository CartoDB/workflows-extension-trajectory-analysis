from dataclasses import dataclass, field
from typing import Optional
from fsspec.implementations.http import HTTPFileSystem

import geopandas as gpd
import pandas as pd

from mappymatch.maps.nx.readers.osm_readers import NetworkType
from mappymatch.constructs.geofence import Geofence
from mappymatch.constructs.trace import Trace
from mappymatch.maps.nx.nx_map import NxMap
from mappymatch.matchers.lcss.lcss import LCSSMatcher
from networkx.readwrite import json_graph
import networkx as nx
from pyproj import CRS
from shapely.ops import unary_union

def load_network_from_gcs(url, filters, xmin, ymin, xmax, ymax):
    if filters:
        return gpd.read_parquet(url, filesystem=HTTPFileSystem(), filters=filters, bbox=(xmin, ymin, xmax, ymax))
    else:
        return gpd.read_parquet(url, filesystem=HTTPFileSystem(), bbox=(xmin, ymin, xmax, ymax))

def nx_graph_as_dict(
        gdf_road : gpd.GeoDataFrame, 
        id : Optional[str] = 'geoid',
        geometry : Optional[str] = 'geom',
        origin : Optional[str] = 'start_node',
        destination : Optional[str] = 'end_node' 
    ):

    gdf_road = gdf_road.to_crs('EPSG:3857').copy() # Same CRS as gps trace

    G = nx.MultiGraph() # TODO: review whether to allow MultiDiGraph
    for idx, row in gdf_road.iterrows():
        G.add_edge(row[origin], row[destination], key=row[id], geometry=row[geometry])

    crs = CRS.from_epsg(3857) 
    crs_wkt = crs.to_wkt()
    graph_metadata = {"geometry_key": "geometry", "crs_key": "crs", "crs": crs_wkt}

    d = json_graph.node_link_data(G)
    d["graph"] = graph_metadata
    for link in d["links"]:
        link["geometry"] = link["geometry"].wkt

    return d

def gcs_network_to_dict(
        url : str,
        geofence : Geofence,
        filters: Optional[list] = None,
        id : Optional[str] = 'geoid',
        geometry : Optional[str] = 'geom',
        origin : Optional[str] = 'start_node',
        destination : Optional[str] = 'end_node' 
    ):

    xmin, ymin, xmax, ymax = geofence.geometry.bounds
    gdf = load_network_from_gcs(url, filters, xmin, ymin, xmax, ymax)
    return nx_graph_as_dict(gdf, id, geometry, origin, destination)

@dataclass(repr = False)
class MappyMatch:
    gps_trace : pd.DataFrame
    road_nw : Optional[str] = field(default = "OSM")
    road_subtype : Optional[str] = field(default = None)
    padding : Optional[int] = field(default = None)
    _matcher : Optional[str] = field(default = "LCSS")
    config : Optional[dict] = field(default = None)
    verbose : bool = field(default = True)

    def __post_init__(self):
        self.gps_trace = self.gps_trace.sort_values("coordinate_id")
        self.nxmap = None
        self.grapgdict = None
        self.geofence = None
        self.filters = None

        self.osm_network_types = {
            'all' : NetworkType.ALL,
            'drive' : NetworkType.DRIVE,
            'bike' : NetworkType.BIKE,
            'walk' : NetworkType.WALK
        }
        
        if self.verbose:
            print("Network:", self.road_nw, "Subtype:", self.road_subtype)
            print("Data shape:", self.gps_trace.shape)
            print(self.gps_trace.head())
            print("Config: ", self.config)

    
    def solve(self):

        # Create the Trace
        if self.verbose:
            print('Building trace...')
        self.trace = Trace.from_dataframe(
            self.gps_trace,
            lat_column="latitude",    
            lon_column="longitude",   
            xy=True # Converts lat/lon to web mercator (EPSG:3857) as cartesian distance is used
        )

        # Create the Geofence
        if self.verbose:
            print('Building georeference...')
        self.geofence = Geofence.from_trace(self.trace, padding=self.padding)

        if self._matcher == 'LCSS':
            # Create the NxMap
            if self.verbose:
                print('Building nxmap...')
            if self.road_nw == 'OMF':
                if self.road_subtype != 'all':
                    self.filters = [[('subtype', '==', self.road_subtype)]] 
                url = "https://storage.googleapis.com/data_science_public/road_networks/overture_madrid_geo.parquet"
                self.nxmap = NxMap.from_dict(gcs_network_to_dict(url, self.geofence, self.filters))
            else:
                self.filters = self.osm_network_types[self.road_subtype]
                self.nxmap = NxMap.from_geofence(self.geofence, network_type = self.filters)

            if self.verbose:
                print('Running map marching...')
            self.matcher = LCSSMatcher(self.nxmap, **self.config)

        try:
            self.matches = self.matcher.match_trace(self.trace)
            res = self.matches.matches_to_geodataframe()
            res = res.to_crs('EPSG:4326')
            res.road_id = res.road_id.astype(str)
            res['geometry'] = res['geom'].astype(str)
            self.res = self.gps_trace.merge(res[['coordinate_id', 'road_id', 'distance_to_road', 'geometry']], on='coordinate_id').copy()

            if self.verbose:
                print('Done!')

            self.solution_found = True

        except nx.NetworkXNoPath:
            print("No solution found")
            self.res = self.gps_trace.copy()
            self.res['geometry'] = None
            self.res['geom'] = None
            self.res['road_id'] = None
            self.res['distance_to_road'] = None

            self.solution_found = False
        
        return self.solution_found
