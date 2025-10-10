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
country <- "cameroon" # main folder where radio gpkgs are stored
station_source <- "fem_cameroon" # subfolder

facility_source <- "HDX" # folder name = data source for health facilities
km <- 5 # km buffer around health facilities
stock_freq <- 0.74 # % of facilities that are expected to have sufficient stock (decimal)
N <- 100 # how many simulations to run

region_dict <- read.csv("reach/fem_regions.csv")
fem_regions <- region_dict %>% filter(country_name == country) %>% pull(regions)
print(paste("REGIONS: ", fem_regions))

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
  
  # assign crs
  radio_polygon <- st_set_crs(radio_polygon, "EPSG:4326")
  
  # reproject
  radio_polygon <- st_transform(radio_polygon, crs(population_raster))
  
  # return
  return(radio_polygon)
})


# Read health facilities (ensure CRS matches)
print(sprintf("Reading health facilities data from %s...", facility_source))
hf <- st_read(list.files(here("reach", "health-centres", facility_source, country), pattern = '*hdx.geojson$', full.names = T)[1])

# start of optional code block -------------
# OPTIONAL: Isolate where FEM is working within country ---
fem_state_bounds <- st_read(list.files(sprintf('../../../General Data/HDX Boundaries/%s/', country), pattern = "\\.shp$", full.names=T)[1])

hf_states <- st_join(hf, fem_state_bounds)


hf_fem_states <- hf_states %>%
  filter(str_detect(region, fem_regions))

# Reproject from degrees to area projection
hf_proj <- st_transform(hf_fem_states, area_proj)
unique(hf_proj$ADM1_EN)


# end of optional ---------------------------

# IF OPTIONAL BLOCK IS NOT USED: Reproject original hf file from degrees to area projection
# hf_proj <- st_transform(hf, area_proj)

# Randomly select x% of points --------
# Count the number of facilities that would be in stock. Round up for conservancy
n <- ceiling(stock_freq*nrow(hf_proj))
print(sprintf("%s of %s (%s percent) facilities will be retained for analysis.", n, 
                                                                        nrow(hf_proj),
                                                                        stock_freq*100))

simulate_bootstrap_once <- function(hf_proj, n, km, station_list, population_raster, i) {
  print(sprintf("----Iteration: %s of %s -----", i, N))
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
    sname <- str_sub(basename(gpkg_files[j]), 11, 41)
    
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

# Run N bootstrap iterations
bootstrap_results <- purrr::map_dfr(1:N, ~ simulate_bootstrap_once(hf_proj, n, km, station_list, population_raster, .x))

write.csv(bootstrap_results, file = sprintf("reach/output/%s/simulated_stockouts/%s_%g_bootstrap_results_fem_states_only.csv", country, country, stock_freq))

# Summarize the bootstrap estimates
summary_results <- bootstrap_results %>%
  group_by(station_name) %>%
  summarise(
    mean_pop = mean(population_coverage, na.rm = TRUE),
    median_pop = median(population_coverage, na.rm = TRUE),
    lower_95 = quantile(population_coverage, 0.025, na.rm = TRUE),
    upper_95 = quantile(population_coverage, 0.975, na.rm = TRUE)
  )

write.csv(summary_results, file = sprintf("reach/output/%s/simulated_stockouts/%s_%g_bootstrap_summary_fem_states_only.csv", country, country, stock_freq))


# Checks

# mapview(hf_buffer, col.regions = "blue") +
mapview(population_raster, col.regions = "green",
na.color = NA) +
  mapview(hf_buffer, col.regions = 'blue') +
  mapview(station_list[[2]], col.regions = "red") +
  mapview(station_list[[2]], col.regions = "red") +
  mapview(station_list[[3]], col.regions = "red") +
  mapview(station_list[[4]], col.regions = "red") +
  mapview(station_list[[5]], col.regions = "red") +
  mapview(station_list[[6]],H0 col.regions = "red") +
  mapview(station_list[[7]], col.regions = "red") +
  mapview(station_list[[8]], col.regions = "red") +
  mapview(station_list[[9]], col.regions = "red") +
  mapview(station_list[[10]], col.regions = "red") +
  mapview(station_list[[11]], col.regions = "red") +
  mapview(station_list[[12]], col.regions = "red") +
  mapview(station_list[[13]], col.regions = "red") +
  mapview(station_list[[14]], col.regions = "red") +
  mapview(station_list[[15]], col.regions = "red") +
  mapview(station_list[[16]], col.regions = "red") +
  mapview(station_list[[17]], col.regions = "red") +
  mapview(station_list[[18]], col.regions = "red") +
  mapview(station_list[[19]], col.regions = "red") +
  mapview(station_list[[20]], col.regions = "red") 
