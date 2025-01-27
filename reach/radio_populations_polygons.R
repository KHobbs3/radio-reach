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
filepath = sprintf('cloudrf/output/gpkg/%s/', country)
gpkg_files <- list.files(path = here(filepath), pattern = "\\.gpkg$", full.names = TRUE, recursive = TRUE)

# Read all .gpkg files into a list of sf objects
station_list <- lapply(gpkg_files, function(file) {

  # read raster, replace 0s with NA, dissolve/unionize/aggregate
  radio_raster <- rast(file) %>% subst(from=0, to=NA) %>% aggregate()
  
  # convert raster to polygon
  radio_polygon <- as.polygons(radio_raster, na.rm=T)
  
  # add column
  radio_polygon$source_file <- basename(file)
  
  # return
  return(radio_polygon)
})

# Read population raster and reproject it
print("Reprojecting population raster...")
population_raster <- rast(list.files(here("reach", "populations", country), full.names = T)[1])
population_raster <- project(population_raster, proj)

# Read health facilities (ensure CRS matches)
print(sprintf("Reading health facilities data from %s...", facility_source))
hf <- vect(list.files(here("reach", "health-centres", facility_source, country), full.names = T)[1])
hf_proj <- project(hf, proj)

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
for (km in c(5)) {
  print(sprintf("----- KM: %s -----", km))
  
  hf_buffer <- hf_proj %>% 
    buffer(width = km * 1000) %>% 
    terra::aggregate()

  for (i in seq_along(station_list)) {
    station <- station_list[[i]]
    
    # Verbosity: get station name
    sname = str_sub(basename(gpkg_files[i]), 1, 31)
    print(sprintf("Station %s of %s: %s", i, length(station_list), sname))
    
    # Reproject station
    station <- project(station, proj)
    
    # Clip station bounds to the buffered facility locations
    cropped_polygons <- terra::intersect(station, hf_buffer)
    
    if (!is.null(cropped_polygons)) {
      # Population coverage calculations ----
      print("Calculating X-km population coverage..")
      population_coverage <- pop_coverage(population_raster, cropped_polygons)

      print("Calculating radio station population coverage..")
      radio_coverage <- pop_coverage(population_raster, station)
      
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
      # polygons <- as.polygons(masked_polygons_aligned)  # Convert SpatRaster to polygons
      writeVector(cropped_polygons, filename = here(sprintf("reach/intermediates/%s/polygons_%s_%gkm.gpkg", country, sname, km)),
               overwrite = TRUE)
    }
  }
}

# Export summary output ----
print("Exporting summary output...")
write.csv(population_data, here("reach", "output", country, sprintf("%s_summary_reach_polygons.csv", country)), row.names = F)
print("Fin.")

# Checks
library(mapview)

# Add custom colors for each layer
mapview(hf_buffer, col.regions = "blue") +
  mapview(station_list[[3]], col.regions = "red") +
  mapview(cropped_polygons, col.regions = "green")  


