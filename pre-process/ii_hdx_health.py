import pandas as pd
import geopandas as gpd
import warnings
import glob
import os
import re

warnings.filterwarnings("ignore")

# Pre-set exclusionary descriptions for out of scope facilities
exclusion = ['dentist', 'blood_donation', 'laboratory', 'paediatrics',
'ophthalmology', 'optometrist', 'neurologie', 'neurology', 'Neurologie Pédiatrie',
'neurologie;gynaecology;paediatrics;cardiology;biology;radiology',
            'general;gynaecology', 'cardiology', 'Infirmerie'
            
# other guesses
'endoscopy', 'radiology', 'radiologie', 'xray'
            ]

# read all humanitarian data exchange (HDX) health facilities (hfs)
for file in glob.glob('ii. health-facilities/HDX/*/*.geojson'):
    print(file)
    country = os.path.dirname(file).split('/')[-1]
    print(country)

    # read CSV as dataframe
    gdf = gpd.read_file(file)

    # get unique columns in dataframe
    hdx_columns = [col for col in ['healthcare', 'healthcare:specialty', '#meta+healthcare', 'fac_type_orig',
                                    'group_fac_type'] if col in gdf.columns]
    
    if len(hdx_columns) > 0:
        print(f'Found columns: ', hdx_columns)

        # remove dentists, specialists...etc.
        start = len(gdf)
        for col in hdx_columns:
            gdf = gdf.loc[~gdf[col].isin(exclusion)]

        # print summary
        print (f'{start - len(gdf)} records removed.')

    # if the columns were not found in the dataframe, do nothing
    else:
        print("No columns found: ", gdf.columns)

    # export
    gdf.to_file(f'../reach/health-centres/HDX/{country}/{country}_hdx.geojson')
