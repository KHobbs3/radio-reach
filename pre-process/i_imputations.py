import pandas as pd
import warnings
import glob
import os
import re

warnings.filterwarnings("ignore")

# Calculating overall mode for transmitter height
df1 = pd.read_csv('0. itu_queries/output/mauritania.csv')
df2 = pd.read_csv('0. itu_queries/output/senegal.csv')
df = pd.concat([df1, df2])

# Define imputation values
print('Summary of height imputation values: ')
total = df['transmitter.alt'].mode()[0]
ll = 3
ul = 190
print(f'Overall mode: {total}\nLower limit: {ll}\nUpper limit: {ul}')

# read all process itu queries
for file in glob.glob('0. itu_queries/output/*'):
    print(file)
    country = os.path.basename(file).split('.')[0]
    print(country)

    # read CSV as dataframe
    df = pd.read_csv(file)


    # impute default antenna azi and hbw from fem.json (cloudrf template)
    df.fillna({'antenna.azi': 0}, inplace =True)
    df.fillna({'antenna.hbw': 120}, inplace =True)

    # if heights are not null, export file as-is
    if len(df.loc[df['transmitter.alt'].isnull()]) == 0:
        print('exporting as-is...')
        df.to_csv(f'../cloudrf/input/fem.{country}.csv', index=False)

    # otherwise, impute the variable
    else:
        print("imputing heights...")
        # impute lower limit height
        df.fillna({'transmitter.alt': ll})\
            .to_csv(f'../cloudrf/input/fem.{country}.ll_height.csv', index=False)

        # impute upper limit height
        df.fillna({'transmitter.alt': ul})\
            .to_csv(f'../cloudrf/input/fem.{country}.ul_height.csv', index=False)

        # impute mode
        df.fillna({'transmitter.alt': total})\
            .to_csv(f'../cloudrf/input/fem.{country}.mode_height.csv', index=False)
    