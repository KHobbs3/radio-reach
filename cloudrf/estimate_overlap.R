library(sf)
library(argparse)
library(dplyr)
library(purrr)

# Set projection
proj <- "+proj=sinu +lat_0=0 +lon_0=25 +lat_1=20 +lat_2=-23 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +type=crs"

# Set country
country <- 'nigeria'
subfolder <- 'fem_nigeria/qgis_polygonization'


# Read population raster and reproject it
print("Reprojecting population raster...")
population_raster <- raster(list.files(here("reach", "populations", country), full.names = T, pattern = "*.tif$")[1])
population_raster <- projectRaster(population_raster, crs= proj)

# Get file path
filepath = file.path("cloudrf", "output/gpkg", country, subfolder)
# filepath <- readline("Enter path to folder with gpkg files: ")
print(filepath)

# Get available files
file_list <-list.files(path = filepath, pattern = "\\.gpkg$", full.names = TRUE)


# ------------------------
# For selected files ----
# ------------------------
# Prompt user for polygons to compare
cat("Select file #1:")
print(file_list)
index1 <- readline("Enter the # for file #1: ")
file1 <- file_list[as.numeric(index1)]

cat("Select file #2:")
print(file_list)
index2 <- readline("Enter the # for file #2: ")
file2 <- file_list[as.numeric(index2)]
  
# Read geodataframes
gdf1 <- st_read(file1) %>% st_transform(proj)
gdf2 <- st_read(file2) %>% st_transform(proj)

# Compute overlap
overlap <- st_intersection(gdf1, gdf2)

# Export for validation
out_name <- readline("Enter the output file name: ")
st_write(overlap, file.path('cloudrf', "output", "overlaps", sprintf("%s_%s_overlap.gpkg", country, out_name)))

# Calculate population coverage
overlap_pop <- exactextractr::exact_extract(population_raster, overlap, 
                             fun = function(values, coverage_fractions) {
                               sum(values * coverage_fractions, na.rm = TRUE)
                             })
print(overlap_pop)

# ------------------------
# For the whole list ----
# ------------------------
# Function to estimate population overlap between two polygons
estimate_overlap <- function(file1, file2) {
  f1 <- st_read(file1)
  f2 <- st_read(file2)
  
  # Ensure matching crs
  f1 <- f1 %>% st_transform(proj)
  f2 <- f2 %>% st_transform(proj)
  
  # Identify overlapping areas 
  overlap <- st_intersection(f1, f2)
  
  # If no overlap exists, return an empty result
  if (nrow(overlap) == 0) {
    
    return(data.frame(file1 = basename(file1), file2 = basename(file2), overlap_population = 0))
    
  } else {
  
  st_write(overlap, sprintf("cloudrf/output/overlaps/gpkg/%s_%s_overlap.gpkg", basename(file1), basename(file2)),
           append=F)
  
  # Compute population for overlap
  overlap_population <- exactextractr::exact_extract(population_raster, overlap, 
                               fun = function(values, coverage_fractions) {
                                 sum(values * coverage_fractions, na.rm = TRUE)
                               })
  
  return(data.frame(file1 = basename(file1), file2 = basename(file2), overlap_population = overlap_population))
  }
}

# Generate all unique file pairs
file_pairs <- combn(file_list, 2, simplify = FALSE)

# Apply function to all pairs and bind results
overlap_df <- bind_rows(map(file_pairs, ~ estimate_overlap(.x[1], .x[2])))

# Print results
print(overlap_df)
write.csv(overlap_df, sprintf("cloudrf/output/overlaps/%s_%s_overlap.csv", country, subfolder))   

# -------------------------------------------------------------------------------------
### Estimate population for all *dissolved* stations
# this tells us the total population, removing redundancies due to overlapping extents
# abandoned code!
#---------------------------------------------------------------------------------------
# all_polygons <- lapply(file_list, st_read)
# dissolved <- Reduce(st_union, all_polygons)
# 
# total_pop <- exactextractr::exact_extract(population_raster, dissolved, 
#                                           fun = function(values, coverage_fractions) {
#                                             sum(values * coverage_fractions, na.rm = TRUE)
#                                           })
