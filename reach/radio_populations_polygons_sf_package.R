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

# Variable selection
country <- "cameroon"
station_source <- "kh_cameroon"
facility_source <- "HDX"
km <- 5

# Set-up function for calculating population coverage
pop_coverage <- function (population_raster, polygon){
  exactextractr::exact_extract(population_raster, polygon,
                               fun = function(values, coverage_fractions) {
                                 sum(values * coverage_fractions, na.rm = TRUE)
                               })
}

# Set projection to equal area projection for country
proj_df <- read.csv('reach/country_projections.csv')
area_proj <- proj_df %>% filter(country_name == country) %>% pull(proj)
print(area_proj)

# Read population raster and reproject it
print("Reading population raster...")
population_raster <- rast(list.files(here("reach", "populations", country), full.names = T, pattern = "*.tif$")[1])


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
  
  # reproject station to match population grid
  radio_polygon <- st_transform(radio_polygon, crs(population_raster))
  
  # return
  return(radio_polygon)
})


# Read health facilities (ensure CRS matches)
print(sprintf("Reading health facilities data from %s...", facility_source))
hf <- st_read(list.files(here("reach", "health-centres", facility_source, country), pattern = '*.geojson$', full.names = T)[1])

# Reproject from degrees to area projection
hf_proj <- st_transform(hf, crs=area_proj)

# Add x-KM buffer in an areal projection
print(sprintf("----- KM: %s -----", km))

hf_buffer <- hf_proj %>% 
  st_buffer(dist = km * 1000) %>% 
  st_union() %>%
  st_sf()

# Reproject health facilities to the popgrid degrees proj
hf_buffer_deg <- st_transform(hf_buffer, crs(population_raster))

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
for (i in seq_along(station_list)) {
    station <- station_list[[i]]
    
    # Verbosity: get station name
    sname = str_sub(basename(gpkg_files[i]), 11, 41)
    print(sprintf("Station %s of %s: %s", i, length(station_list), sname))

    # Clip station bounds to the buffered facility locations
    cropped_polygons <- st_intersection(station, hf_buffer_deg)

    if (!nrow(cropped_polygons) == 0) {
      # Population coverage calculations ----
      print("Calculating X-km population coverage..")
      population_coverage <- pop_coverage(population_raster, cropped_polygons)
    } else {
      population_coverage <- 0
    }
    
    print("Calculating radio station population coverage..")
    radio_coverage <- pop_coverage(population_raster, station)
    
    # Ensure polygon covers a population
    if (length(radio_coverage) == 0){
      len <- length(errors)
      
      # append value to end of list
      errors[[len+1]] <- sname
      
    } else {
      
      # Collect data for each radio station
      population_data <- population_data %>%
        add_row(
          source_file = sname,
          population_coverage = population_coverage,
          radio_coverage = radio_coverage,
          population_proportion = population_coverage / radio_coverage,
          kilometre = km,
          station_name = sname
        )
      }
      
      # Export
      # print("Exporting intermediate output..")
      # dir.create(file.path(here(sprintf("reach/intermediates/%s/", country))))
      # st_write(cropped_polygons, dsn = here(sprintf("reach/intermediates/%s/polygons_%s_%gkm.gpkg", country, sname, km)),
      #          append = F)
    }


# Export summary output ----
print("Exporting summary output...")
dir.create(file.path(here("reach", "output", country)))
write.csv(population_data, here("reach", "output", country, sprintf("%s_%s_summary_reach_%skm.csv", country, station_source, km)), row.names = F)
capture.output(summary(errors), file = here("reach", "output", country, "error_no_populaiton.txt"))
print("Fin.")

# Checks
mapview(population_raster, col.regions = "green",
          na.color = NA)
  mapview(station_list[[1]], col.regions = "red") +
    mapview(cropped_polygons, col.regions = "blue") 
    
  