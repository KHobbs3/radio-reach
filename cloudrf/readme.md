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

-   `fem.json` sets the parameters according to the [CloudRF area schema](https://cloudrf.com/documentation/developer/swagger-ui/#/Create/area)
-   `fem_am.json` is updated for AM (low frequency radio waves) stations

**Key Changes for AM Radio:**

  * Frequency (frq): AM radio stations typically operate between 530 kHz and 1700 kHz. Choose a frequency within this range (e.g., 1000 kHz or 1 MHz → 1000 in MHz).
  * Transmission Power (txw): AM stations generally have much higher power than LoRa (often in kilowatts). Set it to a reasonable value like 10,000 W (10 kW) for a regional station.
  * Bandwidth (bwi): AM stations typically have a bandwidth of 10 kHz (standard for AM).
  * Antenna Polarity (pol): AM broadcast stations use vertical polarization ("v").
  * Antenna Gain (txg): AM stations use lower-gain antennas compared to directional ones.
  * Propagation Model (pm): 1 - Irregular Terrain Model (ITM) (Longley-Rice)


## Steps

1.  Create [countryname].csv using information received from radio partners or a database

    -   `transmitter.alt`: Altitude of transmitter above ground level in metric or imperial. Distance unit set in output object.
    -   `transmitter.lon`: transmitter longitude
    -   `transmitter.lat`: transmitter latitude
    -   `transmitter.txw`: Transmitter power in watts before the antenna
    -   `transmitter.frq`: Center frequency in megahertz
    -   `antenna.azi`: azimuth of antenna (direction of highest frequency)
    -   `antenna.hbw`: horizontal beamwidth

2.  Run CloudRF

3.  Convert KMZ output to GPKG. This step requires [GDAL](https://gdal.org/en/stable/download.html).

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
