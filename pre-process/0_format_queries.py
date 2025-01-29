import pandas as pd
import sys
import warnings

warnings.filterwarnings("ignore")

# read country to process from system command argument
country = sys.argv[1]

# read file
df = pd.read_excel(f"0. itu_queries/input/{country}.xlsx")

# rename columns
df.rename(columns = {
    'site_name': 'site',
    'terrakey': 'network', #TODO: UPDATE to use something more identifying
    'pwr_ant' : 'transmitter.txw',
    'freq_assgn': 'transmitter.frq',
    'hgt_agl' : 'transmitter.alt',
    'long_dec': 'transmitter.lon',
    'lat_dec': 'transmitter.lat',
    'azm_max_e': 'antenna.azi', # azimorth
    'bmwdth':  'antenna.hbw' # horizontal beamwidth
},
    inplace = True)

# update power to antennae from kW to watts
df['transmitter.txw'] = df['transmitter.txw'] * 1000

# drop records where power is zero or negative
# negative transmitters are likely:
# * receivers
# * Directional antennaes: have a mismatch between electric and magnetic wave polarization for transmitters and receivers (ie. horizontal and vertical)
# * error points
# * Power loss in the transmission system (e.g., due to cables, filters, or propagation through the air) can result in negative power values relative to the reference level.
# * other indicators of unsuitable transmission

# power
negatives = df.loc[df['transmitter.txw'] <= 0]
print(f'dropping {len(negatives)} records with transmitter power at or below 0')
df = df.loc[df['transmitter.txw'] > 0]
print(f'{len(df)} remaining records.')

# frequency
negatives = df.loc[df['transmitter.frq'] <= 1]
print(f'dropping {len(negatives)} records with transmitter frequency is at or below 1')
df = df.loc[df['transmitter.frq'] > 1]
print(f'{len(df)} remaining records.')

# re-order columns & export
print(f'Exporting formattedCSV file: 0. itu_queries/output/fem.{country}.csv')
df[['site', 'network',
    'transmitter.lat', 'transmitter.lon',
    'transmitter.alt', 'transmitter.txw', 'transmitter.frq']]\
        .to_csv(f'0. itu_queries/output/{country}.csv', index=False)
print('Fin.')
