# Radio Station Population Reach

This RProject was developed to streamline assessments of population reached by the CloudRF modelled geographic of potential radio stations. It is intended to support decision-making for Family Empowerment Media during the 2024-2025 Joint Scoping Project.

## Requirements

The following requirements can be downloaded

```         
python3 -m pip install -r requirements.txt
```

## Folder Structure & Scripts

**0. Set-Up:**

-   *Radio Specifcations:* create new file: `cloudrf/input/fem.[country].csv` . See README.md in cloudrf/ for details.

-   *Health facility points:*

    -   `reach/health-centres/DHIS2/`: perform any pre-processing required.

    -   `reach/health-centres/HDX/`: download from Humanitarian Data Exchange and upload as geospatial file.

    -   `reach/populations/`: download form WorldPop and upload to a folder with lowercase name of country. Update the [summary of data sources](https://docs.google.com/spreadsheets/d/1JQ4SYUPJLtK0k5GBS1jr8VbtQvMe2G1_4ubfXNBsUjU/edit?gid=0#gid=0) for comparison.

**1. Pre-processing:**

-   `radio-africa/`: directory for processing radio station specs provided in JSON format for various countries by [radio-africa.org](radio-africa.org).

**2. CloudRF Radio Propagation:**

-   `run_cloudRF.sh`: run selected or all CSV files detailing radio station specs through CloudRF API to generate KMZ files.

**3. Population Coverage:**

-   `radio_populations_polygons.R`: (FAST) estimates radio station coverage and population living within 5-km of health facilities within radio bounds. This script converts the radio raster to a polygon to perform these calculations.
-   `radio_populations.R`: (SLOW) estimates radio station coverage and population living within 1,2,3,4,5-km of health facilities within radio bounds. This script uses the radio raster and involves pixel re-sampling and resizing rasters to match the resolution of the population grid and extent of the station propagation. As a result, the script is incredibly slow, although may be more precise in terms of population grid inclusions.

## Usage

1.  `./run_cloudRF.sh`
2.  `RScript radio_populations_polygons.R`

## Roadmap
