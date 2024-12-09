# Data processing from [radio-africa.org](radio-africa.org)

## Requirements

Dependencies: `pip install json pandas`

## Folders
* json > json files received from radio-africa.org
* outputs > CSV of operational and CSV of non-operational station transmitters. 

## Scripts
1. `process_radio_africa.py`: reads inputs from radio-africa and creates one CSV database per country of all radio stations (outputs/stations_[country_name].csv).