library(sf)
library(terra)
library(dplyr)
library(here)
library(mapview)
library(openxlsx)
library(stringr)

# Set-up ----
options(warn = -1)  # Suppress warnings

# Set projection
proj <- "+proj=aea +lat_0=0 +lon_0=25 +lat_1=20 +lat_2=-23 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +type=crs"

# Get the command-line arguments to identify country for analysis
args <- commandArgs(trailingOnly = TRUE)

# Parse the keyword arguments
arg_list <- list()
for (arg in args) {
  if (grepl("--", arg)) {
    key_value <- strsplit(arg, "=")[[1]]
    if (length(key_value) == 2) {
      arg_list[[sub("--", "", key_value[1])]] <- key_value[2]
    }
  }
}

# Access the keyword arguments ----
country <- arg_list[["country"]]
facility_source <- arg_list[['fs']]

# Read in all possible stations
filepath = sprintf('cloudrf/output/gpkg/%s', country)
gpkg_files <- list.files(path = filepath, pattern = "\\.gpkg$", full.names = TRUE, recursive = TRUE)

# Read all .gpkg files into a list of sf objects
station_list <- lapply(gpkg_files, function(file) {
  radio <- rast(file)
  radio$source_file <- basename(file)
  return(radio)
})

# Read population raster and reproject it
print("Reprojecting population raster...")
population_raster <- rast(list.files(here("reach", "populations", country), full.names = T)[1])
population_raster <- project(population_raster, proj)

# Read health facilities (ensure CRS matches)
print(sprintf("Reading health facilities data from %s...", facility_source))
hf <- st_read(list.files(here("reach", "health-centres", facility_source, country), full.names = T)[1])
hf_proj <- st_transform(hf, proj)

# Function to calculate population coverage ----
pop_coverage <- function(raster, polygon) {
  raster <- terra::mask(raster, polygon)
  total_population <- terra::global(raster, "sum", na.rm = TRUE)[1, 1]
  return(total_population)
}

# Set-up table for export ----
population_data <- tibble(source_file = character(),
                          population_coverage = numeric(),
                          radio_coverage = numeric(),
                          population_proportion = numeric(),
                          kilometre = integer(),
                          station_name = character()
                          )

# Iterator ----
# Loop for each distance in km
for (km in c(1, 2, 3, 4, 5)) {
  print(sprintf("----- KM: %s -----", km))
  hf_buffer <- hf_proj %>% 
    st_buffer(dist = km * 1000) %>% 
    st_union() %>%
    st_sf()

  for (i in seq_along(station_list)) {
    station <- station_list[[i]]
    
    # Verbosity: get station name
    sname = str_sub(basename(gpkg_files[i]), 1, 31)
    print(sprintf("Station %s of %s: %s", i, length(station_list), sname))
    
    # Reproject station
    station <- project(station, proj)
    
    # Clip station bounds to the buffered facility locations
    cropped_polygons <- terra::crop(station, terra::ext(hf_buffer))
    
    # Fill NA's that are out of the facility buffer bounds
    masked_polygons <- terra::mask(cropped_polygons, hf_buffer)
    
    
    if (!is.null(masked_polygons)) {
      # Force align extent of masked_polygons to population_raster's extent
      print("Extending masked facilities to population raster...")
      masked_polygons_aligned <- extend(masked_polygons, ext(population_raster))
      
      print("Extending radio station to population raster...")
      station_raster_aligned <- extend(station, ext(population_raster))
      
      # Resample masked_polygons to match population_raster
      print("Resampling masked facilities to population raster...")
      masked_polygons_aligned <- resample(masked_polygons_aligned, population_raster, method = "bilinear")

      print("Resampling radio stations to population raster...")
      station_raster_aligned <- resample(station_raster_aligned, population_raster, method = "bilinear")
      
      # Population coverage calculations ----
      print("Calculating X-km population coverage..")
      population_coverage <- pop_coverage(population_raster, masked_polygons_aligned)

      print("Calculating radio station population coverage..")
      radio_coverage <- pop_coverage(population_raster, station_raster_aligned)
      
      # Collect data for each radio station
      population_data <- population_data %>%
        add_row(
          source_file = basename(gpkg_files[i]),
          population_coverage = population_coverage,
          radio_coverage = radio_coverage,
          population_proportion = population_coverage / radio_coverage,
          kilometre = km,
          station_name = sname
        )
      
      # Export as GeoPackage
      print("Exporting intermediate output..")
      polygons <- as.polygons(masked_polygons_aligned)  # Convert SpatRaster to polygons
      writeVector(polygons, filename = sprintf("reach/intermediates/%s/%s_%gkm.gpkg", country, sname, km),
               overwrite = TRUE)
    }
  }
}

# Export summary output ----
print("Exporting summary output...")
write.csv(population_data, here("reach", "output", country, sprintf("%s_summary_reach.csv", country)), row.names = F)
print("Fin.")

# Check
mapview(polygons)

