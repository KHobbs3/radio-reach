import pandas as pd
import sys
import warnings

warnings.filterwarnings("ignore")

# read country to process from system command argument
country = sys.argv[1]

# read file
df = pd.read_excel(f"itu_queries/{country}.xlsx")

# rename columns
df.rename(columns = {
    'site_name': 'site',
    'terrakey': 'network', #TODO: UPDATE to use something more identifying
    'pwr_ant' : 'transmitter.txw',
    'freq_assgn': 'transmitter.frq',
    'hgt_agl' : 'transmitter.alt',
    'long_dec': 'transmitter.lon',
    'lat_dec': 'transmitter.lat'
},
    inplace = True)

# update power to antennae from kW to watts
df['transmitter.txw'] = df['transmitter.txw'] * 1000

# drop records where power is zero
zeros = df.loc[df['transmitter.txw'] == 0]
print(f'dropping {len(zeros)} records with transmitter power = 0')

df = df.loc[df['transmitter.txw'] != 0]

# re-order columns & export
print(f'Exporting formatted CSV file: ../cloudrf/input/fem.{country}.csv')
df[['site', 'network',
    'transmitter.lat', 'transmitter.lon',
    'transmitter.alt', 'transmitter.txw', 'transmitter.frq']]\
        .to_csv(f'../cloudrf/input/fem.{country}.csv', index=False)
print('Fin.')
