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
country <- "niger" # main folder where radio gpkgs are stored
station_source <- "marion_partners" # subfolder "
facility_source <- "HDX" # folder name = data source for health facilities
km <- 5 # km buffer around health facilities
stock_freq <- 1 - 0.118 # % of facilities that are expected to have sufficient (decimal)

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
population_raster <- raster(list.files(here("reach", "populations", country), full.names = T, pattern = "*.tif$")[1])


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
  
  # assign crs
  # radio_polygon <- st_set_crs(radio_polygon, "EPSG:4326")
  
  # reproject
  radio_polygon <- st_transform(radio_polygon, crs(population_raster))
  
  # return
  return(radio_polygon)
})


# Read health facilities (ensure CRS matches)
print(sprintf("Reading health facilities data from %s...", facility_source))
hf <- st_read(list.files(here("reach", "health-centres", facility_source, country), pattern = '*.geojson$', full.names = T)[1])

# Reproject from degrees to area projection
hf_proj <- st_transform(hf, area_proj)

# Randomly select x% of points --------
# Count the number of facilities that would be in stock. Round up for conservancy
n <- ceiling(stock_freq*nrow(hf_proj))
print(sprintf("%s of %s (%s percent) facilities will be retained for analysis.", n, 
                                                                        nrow(hf_proj),
                                                                        stock_freq*100))

simulate_bootstrap_once <- function(hf_proj, n, km, station_list, population_raster, i) {
  print(sprintf("----Iteration: %s of 1000 -----", i))
  hf_sample <- hf_proj %>% slice_sample(n = n)
  
  # export intermediates for review
  st_write(hf_sample, sprintf("reach/intermediates/%s/bootstrap_sim/hf_sample_%s.gpkg", country, i),
           append=FALSE)
  
  hf_buffer <- hf_sample %>% 
    st_buffer(dist = km * 1000) %>% 
    st_union() %>% 
    st_sf() %>% 
    st_transform(crs(population_raster))
  
  # export intermediates for review
  st_write(hf_sample, sprintf("reach/intermediates/%s/bootstrap_sim/hf_sample_dissolved_%s.gpkg", country, i),
           append=FALSE)
  
  print("Calculating population within bounds...")
  population_data <- purrr::map_dfr(seq_along(station_list), function(j) {
    station <- station_list[[j]]
    sname <- str_sub(basename(gpkg_files[j]), 1, 31)
    
    cropped <- st_intersection(station, hf_buffer)
    pop_cov <- if (nrow(cropped) > 0) pop_coverage(population_raster, cropped) else 0
    radio_cov <- pop_coverage(population_raster, station)
    
    tibble(
      iteration = i,
      source_file = sname,
      population_coverage = pop_cov,
      radio_coverage = radio_cov,
      population_proportion = ifelse(radio_cov > 0, pop_cov / radio_cov, NA),
      kilometre = km,
      station_name = sname
    )
  })
  
  return(population_data)
}

# Run 1000 bootstrap iterations
bootstrap_results <- purrr::map_dfr(1:1000, ~ simulate_bootstrap_once(hf_proj, n, km, station_list, population_raster, .x))

# Summarize the bootstrap estimates
summary_results <- bootstrap_results %>%
  group_by(station_name) %>%
  summarise(
    mean_prop = mean(population_proportion, na.rm = TRUE),
    median_prop = median(population_proportion, na.rm = TRUE),
    lower_95 = quantile(population_proportion, 0.025, na.rm = TRUE),
    upper_95 = quantile(population_proportion, 0.975, na.rm = TRUE)
  )
# # Randomly select clinics
# hf_stockouts <- hf_proj %>%
#   slice_sample(n = n)
# 
# # Check
# nrow(hf_stockouts) == n
# 
# # Add x-KM buffer in an areal projection
# print(sprintf("Adding %s buffer...", km))
# 
# hf_buffer <- hf_proj %>% 
#   st_buffer(dist = km * 1000) %>% 
#   st_union() %>%
#   st_sf()
# 
# # Reproject health facilities to the popgrid degrees proj
# hf_buffer_deg <- st_transform(hf_buffer, crs(population_raster))
# 
# # Set-up table for export ----
# population_data <- tibble(source_file = character(),
#                           population_coverage = numeric(),
#                           radio_coverage = numeric(),
#                           population_proportion = numeric(),
#                           kilometre = integer(),
#                           station_name = character()
# )
# 
# # Iterator ----
# errors = list()
# 
# # Loop for each distance in km
# for (i in seq_along(station_list)) {
#   station <- station_list[[i]]
#   
#   # Verbosity: get station name
#   sname = str_sub(basename(gpkg_files[i]), 1, 31)
#   print(sprintf("Station %s of %s: %s", i, length(station_list), sname))
#   
#   # Clip station bounds to the buffered facility locations
#   cropped_polygons <- st_intersection(station, hf_buffer_deg)
#   
#   if (!nrow(cropped_polygons) == 0) {
#     # Population coverage calculations ----
#     print("Calculating X-km population coverage..")
#     population_coverage <- pop_coverage(population_raster, cropped_polygons)
#   } else {
#     population_coverage <- 0
#   }
#   
#   print("Calculating radio station population coverage..")
#   radio_coverage <- pop_coverage(population_raster, station)
#   
#   # Ensure polygon covers a population
#   if (length(radio_coverage) == 0){
#     len <- length(errors)
#     
#     # append value to end of list
#     errors[[len+1]] <- sname
#     
#   } else {
#     
#     # Collect data for each radio station
#     population_data <- population_data %>%
#       add_row(
#         source_file = sname,
#         population_coverage = population_coverage,
#         radio_coverage = radio_coverage,
#         population_proportion = population_coverage / radio_coverage,
#         kilometre = km,
#         station_name = sname
#       )
#   }
# }
# 
# 
# # Export summary output ----
# print("Exporting summary output...")
# dir.create(file.path(here("reach", "output", country)))
# write.csv(population_data, here("reach", "output", country, sprintf("%s_%s_summary_reach_sf_orig_proj.csv", country, station_source)), row.names = F)
# capture.output(summary(errors), file = here("reach", "output", country, "error_no_population.txt"))
# print("Fin.")

# Checks

# mapview(hf_buffer, col.regions = "blue") +
mapview(population_raster, col.regions = "green",
        na.color = NA) +
  # mapview(cropped_polygons, col.regions = 'blue') +
  mapview(station_list[[1]], col.regions = "red") +
  mapview(hf_buffer_deg, col.regions = "red") 
