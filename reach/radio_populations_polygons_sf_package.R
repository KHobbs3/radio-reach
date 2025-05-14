library(sf)
library(terra)
library(dplyr)
library(here)
library(mapview)
library(openxlsx)
library(stringr)
library(raster)


# Set-up ----
options(warn = -1)  # Suppress warnings


# Set-up function for calculating population coverage
pop_coverage <- function (population_raster, polygon){
  exactextractr::exact_extract(population_raster, polygon,
                               fun = function(values, coverage_fractions) {
                                 sum(values * coverage_fractions, na.rm = TRUE)
                               })
}

country <- "nigeria"
station_source <- "fem_nigeria/qgis_polygonization/"
facility_source <- "HDX"

# Read population raster and reproject it
print("Reprojecting population raster...")
population_raster <- raster(list.files(here("reach", "populations", country), full.names = T, pattern = "*.tif$")[1])
# population_raster <- projectRaster(population_raster, crs= proj)
# Set projection
proj <- crs(population_raster)#"+proj=sinu +lat_0=0 +lon_0=25 +lat_1=20 +lat_2=-23 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +type=crs"


# Read in all possible stations
print("Reading radio GPKGs...")
filepath = sprintf(here('cloudrf/output/gpkg/%s/%s/'), country, station_source)
gpkg_files <- list.files(path = filepath, pattern = "\\.gpkg$", full.names = TRUE, recursive = F)

# Read all .gpkg files into a list of sf objects
station_list <- lapply(gpkg_files, function(file) {
  print(file)
  
  # read raster, replace 0s with NA, dissolve/unionize/aggregate
  radio_polygon <- st_read(file)
  
  # add column
  radio_polygon$source_file <- basename(file)
  
  # reproject
  radio_polygon <- st_transform(radio_polygon, crs(population_raster))
  
  # return
  return(radio_polygon)
})


# Read health facilities (ensure CRS matches)
print(sprintf("Reading health facilities data from %s...", facility_source))
hf <- st_read(list.files(here("reach", "health-centres", facility_source, country), pattern = '*.geojson$', full.names = T)[1])
hf_proj <- st_transform(hf, proj)


# Set-up table for export ----
population_data <- tibble(source_file = character(),
                          population_coverage = numeric(),
                          radio_coverage = numeric(),
                          population_proportion = numeric(),
                          kilometre = integer(),
                          station_name = character()
                          )

# Iterator ----
errors = list()

# Loop for each distance in km
for (km in c(5)) {
  print(sprintf("----- KM: %s -----", km))
  
  hf_buffer <- hf_proj %>% 
    st_buffer(dist = km * 1000) %>% 
    st_union()

  for (i in seq_along(station_list)) {
    station <- station_list[[i]]
    
    # Verbosity: get station name
    sname = str_sub(basename(gpkg_files[i]), 1, 31)
    print(sprintf("Station %s of %s: %s", i, length(station_list), sname))
    
    # # Reproject station
    # station <- st_transform(station, proj)
    
    # Clip station bounds to the buffered facility locations
    cropped_polygons <- st_intersection(station, hf_buffer)
    
    if (!is.null(cropped_polygons)) {
      # Population coverage calculations ----
      print("Calculating X-km population coverage..")
      population_coverage <- pop_coverage(population_raster, cropped_polygons)

      print("Calculating radio station population coverage..")
      radio_coverage <- pop_coverage(population_raster, station)
      
      # Ensure polygon covers a population
      if (length(population_coverage) == 0){
        len <- length(errors)
        
        #append value to end of list
        errors[[len+1]] <- sname
      } else {
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
      }
      
      # Export as GeoPackage
      print("Exporting intermediate output..")
      dir.create(file.path(here(sprintf("reach/intermediates/%s/", country))))
      st_write(cropped_polygons, dsn = here(sprintf("reach/intermediates/%s/polygons_%s_%gkm.gpkg", country, sname, km)),
               append = F)
    }
  }
}

# Export summary output ----
print("Exporting summary output...")
dir.create(file.path(here("reach", "output", country)))
write.csv(population_data, here("reach", "output", country, sprintf("%s_summary_reach_sf.csv", country)), row.names = F)
capture.output(summary(errors), file = here("reach", "output", country, "error_no_populaiton.txt"))
print("Fin.")

# Checks
library(mapview)

# mapview(hf_buffer, col.regions = "blue") +
  mapview(population_raster, col.regions = "green",
          na.color = NA) +
    mapview(station_list[[1]], col.regions = "red") +
    mapview(station_list[[2]], col.regions = "red") 

  