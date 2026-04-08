import os
import geopandas as gpd
import pandas as pd
from shapely.ops import unary_union
from campaigns_config import campaign_config

# set up main path to gpkgs
PATH = "/Users/kt/Documents/work/AIM Charities/FEM/Family Planning/2. Everything Radio/Radio Reach/cloudrf/output/gpkg"

# user inputs
country = 'benin'
campaign = 'poc'

# read files in configuration
gdf_files = campaign_config[country]['campaigns'][campaign]['gdf_files']
subfolder = campaign_config[country]['subfolder']

# initialize empty list
gdfs = []

# read in the GeoDataFrames
for file in gdf_files:
    gdf = gpd.read_file(f"{PATH}/{country}/{subfolder}/{file}").to_crs("epsg:4326")
    gdfs.append(gdf)

# combine the list of GeoDataFrames into a single GeoDataFrame
print('Combining layers...')
combined = gpd.GeoDataFrame(pd.concat(gdfs, ignore_index=True))

# dissolve using shapely's unary_union
print("Dissolving layers...")
merged_geom = combined.geometry.union_all()
dissolved = gpd.GeoDataFrame(geometry=[merged_geom], crs=combined.crs)

# export
os.makedirs(f"{PATH}/{country}/fem_{country}_projects/", exist_ok=True)
export_file = f"{PATH}/{country}/fem_{country}_projects/{country}_{campaign}_dissolved.gpkg"
print("Exporting dissolved GeoDataFrame...")
dissolved.to_file(export_file)
