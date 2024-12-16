# CloudRF

To build raster files of radio station broadcast reach.

## Documentation

[CloudRF create area](https://cloudrf.com/documentation/developer/swagger-ui/#/Create/area)

[Cloud RF User Manual](https://cloudrf.com/documentation/Cloud-RF_user_manual.pdf)

## Set-up
### Requirements

Fetch the requirements from [requirements.txt](requirements.txt) with `pip`:

```         
python3 -m pip install -r requirements.txt
```

### CloudRF Settings
* `fem.json` sets the parameters according to the [CloudRF area schema](https://cloudrf.com/documentation/developer/swagger-ui/#/Create/area)

## Steps
1.  Update fem_master.csv using information received from radio partners
    -   `transmitter.alt`: antennae height (from the ground) in metres
    -   `transmitter.lon`: transmitter longitude
    -   `transmitter.lat`: transmitter latitude
    -   `transmitter.txw`: power in watts
    -   `transmitter.frq`: frequency of radio station

2. Run CloudRF

3. Convert KMZ output to GPKG. This step requires [GDAL](https://gdal.org/en/stable/download.html).

## Environment Variables

To run this project, you will need to add the following environment variables to your .env file

`API_KEY`

`ANOTHER_API_KEY`

## Usage/Examples

``` python
python3 CloudRF.py area -i fem.new.csv -t fem-kh.json -k [API-KEY]

python3 area.py -i towercoverage.csv -t custom.json -k [API-KEY]
py area.py -i dwg.csv -t dwg.json
py area.py -i fem.csv -t fem.json
```
