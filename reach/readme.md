---
editor_options: 
  markdown: 
    wrap: 72
---

# Radio Reach – Population Coverage Analysis

This folder contains scripts and data used to estimate population
coverage of radio station broadcast areas, with optional restriction to
areas near health facilities. The core workflow uses spatial operations
on raster population grids and station broadcast polygons. The primary
script in this folder is: `radio_populations_polygons_sf_package.R`

This script calculates:

-   Total population reached by each radio station
-   Population within X km of health facilities and inside each
    broadcast polygon
-   The proportion of a station’s total coverage that falls within these
    buffered facility areas

## Overview of Workflow

The script performs the following steps:

1\. Set global parameters

You define:

-   country (e.g., "cameroon")

<!-- -->

-   station_source : folder name for radio station GPKGs

-   facility_source : health facility dataset source

-   x-km : buffer radius around health facilities (in kilometers)

Ensure that the following output folders are created:

-   `output/<country>/`

-   `intermediates/<country>/`

The proceed to run the script in full, which will:

2.  Load required packages.

3.  Load country projection reach/country_projections.csv stores
    equal-area CRS strings used for buffering operations.

4.  Load and prepare population rasters.

-   Reads the population raster for the selected country
-   Reprojects it as needed

5.  Load and prepare radio station polygons

-   Reads all .gpkg files from:
    `cloudrf/output/gpkg/<country>/<station_source>/`
-   Reprojects each polygon to match the raster CRS
-   Stores each station in a list

6.  Load and buffer health facilities

-   Reads the health facility GeoJSON
-   Reprojects to an equal-area CRS
-   Buffers each facility by km × 1000 meters
-   Merges into a single buffer polygon
-   Reprojects back to match the population raster CRS

7.  Population coverage calculations For each station:

-   Clip station to the facility buffer
-   Calculate:
    -   population_coverage — population inside both station area and
        facility buffer
    -   radio_coverage — population inside entire station broadcast
        polygon
    -   population_proportion = population_coverage / radio_coverage
    -   Append results to a summary table
    -   Track stations containing no population for debugging

8.  Export Outputs are saved to: reach/output/<country>/ Files include:
    <country>\_<station_source>*summary_reach*<km>km.csv
    error_no_population.txt
9.  Optional map checks Quick visualization using mapview.

## How to Run the Script in R

Install required packages if needed:

```         
install.packages(c(
  "sf", "terra", "dplyr", "here", "mapview",
  "openxlsx", "stringr", "raster"
))
```

------------------------------------------------------------------------

### 2. Set Your Working Directory

Ensure your R session is pointed to the root of the repository:

```         
setwd("<path-to-radio-reach-repo>")
```

------------------------------------------------------------------------

### 3. Configure Script Parameters

Edit the parameters at the top
of `radio_populations_polygons_sf_package.R`:

```         
country <- "cameroon"
station_source <- "kh_cameroon"
facility_source <- "HDX"
km <- 5
```

------------------------------------------------------------------------

### 4. Run the Script

You can run the script in RStudio or using:

```         
source("reach/radio_populations_polygons_sf_package.R")
```

------------------------------------------------------------------------

### 5. Retrieve Outputs

Processed results will be saved to:

```         
reach/output/<country>/
```

------------------------------------------------------------------------

## Methods Summary

### Population Extraction

Population is estimated using:

```         
exactextractr::exact_extract(population_raster, polygon)
```

This method provides:

-   Correct weighting for partially intersecting raster cells

-   Accurate population totals for irregular polygon geometries
