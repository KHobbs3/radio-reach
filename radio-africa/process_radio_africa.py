# Reads samples from Radio-Africa.org and converts to csv file for CloudRF
import pandas as pd
import json
import warnings

# Read data - currently assumed to be nested dictionaries of stations and tower information
# for one country/region
with open('json/radio-africa-sample.json', 'r') as file:
    json_string = file.read()
    data = json.loads(json_string)

outer_dict = pd.DataFrame(data['stations'])
inner_dict = pd.DataFrame(data['stations'][0]['txs'])

# Keep selected columns
outer_cols = ['stationId', 'stationName', 'alternateStationName',
                'format', 'language', 'countryCode', 'stationCity',
                'stationCompany', 'bands']
inner_cols = [
    
        # overview
        'tsId', 'status',

        # RDS related columns - https://en.wikipedia.org/wiki/Radio_Data_System
       'hasRds', 'ecc', 'serviceIdentifierRegA',
       'serviceIdentifierRegB', 'ensembleIdentifier', 'subChannelIdentifier',
       'scids', 'callSign',

       # Specs
       'band', 'frequency', 'frequencyUnits', 'erp', 'erpUnits', 'haat', 'haatUnits',
        
        # Geo
       'latitude', 'longitude', 'directionality',

       # radio-africa contour
       'contour'
       ]


# Concatenate nested dicts with selected columns only
df = pd.concat([outer_dict[outer_cols], inner_dict[inner_cols]], axis=1)

# Separate non-operational from operational transmitters
op = df.loc[df.status == ""]
nonop = df.loc[df.status != ""]

print(f"CHECK:\n\toperational statuses: {op.status.unique()},\n\tNon-op statuses: {nonop.status.unique()})")

# Export
if len(op) > 0:
    op.to_csv('outputs/operational_sample.csv', index=False)
else:
    print("\tNo operational stations found.")

if len(nonop) > 0:
    nonop.to_csv('outputs/non_operational_sample.csv', index=False)
else:
    print("\tNo inactive stations found.")

print('\ndone.')
