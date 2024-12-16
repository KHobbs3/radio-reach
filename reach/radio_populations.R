# Script to select facilities within radio bounds
# Load required libraries
library(sf)
library(dbscan)
library(dplyr)
library(raster)
library(geosphere)
library(here)
library(mapview)
library(data.table)
library(openxlsx)
library(stringr)
library(terra)

# DEFINE VARIABLES ------
# projection for epsg:102022
proj <- "+proj=aea +lat_0=0 +lon_0=25 +lat_1=20 +lat_2=-23 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +type=crs"
kilometres <- c(1,2,3,4,5)

# country for analysis
country_list <- list.dirs(path = 'reach/populations/', recursive = TRUE, full.names = TRUE) %>% basename()
print(country_list[2:length(country_list)])

country <- readline(prompt = "Enter the country name or type 'all' for all: ")
print(paste("Radio reach estimates for:", country))

if (country == 'all'){
  # TODO: add option to iterate through all
  country <- country_list[2:length(country_list)]
}

# prompt user which data source to use for health centres
hf_source <- readline(prompt = "HDX or DHIS2:")


# READ DATA ----
# Read in all possible stations
filepath = sprintf('cloudrf/output/gpkg/%s', country)
gpkg_files <- list.files(path = filepath, pattern = "\\.gpkg$", full.names = TRUE, recursive = TRUE)

# Read all .gpkg files into a list of sf objects
sf_list <- lapply(gpkg_files, function(file) {
  sf_object <- st_read(file)
  sf_object$source_file <- basename(file)
  return(sf_object)
})

# Read in the population raster
population_raster <- rast(list.files(sprintf("reach/populations/%s", country),
                                       pattern = "\\.tif$", 
                                       full.names = TRUE))

# Set CRS 
population_raster <- project(population_raster, crs = proj)


# Read in health facilities points
hf_files <- list.files(here("reach", "health-centres", hf_source, country),
                       full.names=T)
hf <- st_read(hf_files[1])


# DEFINE FUNCTIONS ----
# Population coverage function
pop_coverage <- function(polygon) {
  
  # Crop the raster to the polygon to speed up processing
  cropped_raster <- crop(population_raster, polygon)
  
  # Mask the raster to only include values within the polygon
  masked_raster <- mask(cropped_raster, polygon)
  
  # Calculate the total population within the polygon (sum non-NA values)
  total_population <- global(masked_raster, fun = "sum", na.rm = TRUE)[1, 1]
  
  return(total_population)
}


# ITERATOR ----
for (km in kilometres){
  print(km)
  
  # Reproject hf's
  hf_proj <- st_transform(hf, proj)
  
  # Buffer points ----
  print(paste("Adding dissolved buffer:", km))
  hf_buffer <- hf_proj %>%
                  st_buffer(dist = km*1000) %>%
                  st_union() %>%
                  st_sf()
  

  table_list <- list() 
  
  # Iterate through all radio stations and create a list of 
  # facilities *within*
  
  for (i in seq(length(sf_list))) {
    
    station_name <-  str_sub(gsub('\\.gpkg$',"", 
                                basename(gpkg_files[i])),1,31)
    
    # Verbosity
    print(paste(sprintf("%s of %s", i, length(sf_list)), 
                station_name))
    
    # read station
    station <- sf_list[[i]]
    
    # Reproject the station to match the facility polygon layer
    station <- st_transform(station, proj)
    
    # Using intersects because people slightly outside radio bounds likely move in bounds
    # !!! N.B. differs from python script
    intersect_polygons <- st_intersection(hf_buffer, station)
    print(paste("Number of facility clusters within radio bounds:", nrow(intersect_polygons)))
    

    if (length(unlist(intersect_polygons)) > 0) {
      # Get station name and append as new column
      intersect_polygons$source_file <- gsub('\\.gpkg$',"", basename(gpkg_files[i]))
      intersect_polygons <- intersect_polygons %>%
                                              mutate(
                                                     population_coverage = pop_coverage(intersect_polygons),
                                                     radio_coverage = pop_coverage(station), # Calculate population coverage of station and add it to the buffer population dataframe
                                                     kilometre = km,
                                                     population_prop = population_coverage/station_population_R,
                                                     station_name = station_name)
                                          }
    
    # Append to table
    table_list[[station_name]] <- intersect_polygons

    # Export for each radio station
    st_write(intersect_polygons, dsn = sprintf("reach/intermediates/%s/%s_%gkm.gpkg", country, station_name, km),
             layer = sprintf("%s", station_name), driver = "GPKG", delete_dsn = TRUE)
    
  }
  
}

# Remove geometry for table export
table_list_flat <- lapply(table_list, st_drop_geometry)

# Export radio station summary for x-KM
write.xlsx(table_list_flat, file = sprintf("reach/output/%s/buffer_populations_%s.xlsx", country, country))

# check
mapview::mapview( list(intersect_polygons, station),
                  col.regions = list("blue", "red", "yellow"))

