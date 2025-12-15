library(sf)
library(dplyr)
library(purrr)
library(here)


# Set country
country <- 'togo'
subfolder <- 'fem_togo'
pop_year <- 2026 # population grid year


# Read population raster and reproject it
print("Reading population raster...")
population_raster <- rast(list.files(here("reach", "populations", country),
                                     full.names = T,
                                     pattern = sprintf(".*%s.*.tif$", pop_year))[1])

# Get file path
filepath = file.path("cloudrf", "output/gpkg", country, subfolder)
print(filepath)

# Get available files
file_list <-list.files(path = filepath, pattern = "\\.gpkg$", full.names = TRUE)


# # ------------------------
# # For selected files ----
# # ------------------------
# # Prompt user for polygons to compare
# cat("Select file #1:")
# print(file_list)
# index1 <- readline("Enter the # for file #1: ")
# file1 <- file_list[as.numeric(index1)]
# 
# cat("Select file #2:")
# print(file_list)
# index2 <- readline("Enter the # for file #2: ")
# file2 <- file_list[as.numeric(index2)]
#   
# # Read geodataframes
# gdf1 <- st_read(file1) %>% st_transform(proj)
# gdf2 <- st_read(file2) %>% st_transform(proj)
# 
# # Compute overlap
# overlap <- st_intersection(gdf1, gdf2)
# 
# # Export for validation
# out_name <- readline("Enter the output file name: ")
# st_write(overlap, file.path('cloudrf', "output", "overlaps", sprintf("%s_%s_overlap.gpkg", country, out_name)))
# 
# # Calculate population coverage
# overlap_pop <- exactextractr::exact_extract(population_raster, overlap, 
#                              fun = function(values, coverage_fractions) {
#                                sum(values * coverage_fractions, na.rm = TRUE)
#                              })
# print(overlap_pop)

# ------------------------
# For the whole list ----
# ------------------------
# Function to estimate population overlap between two polygons
estimate_overlap <- function(file1, file2) {
  
  f1 <- st_read(file1)
  f2 <- st_read(file2)
  
  # CRS are made to match in the .ipynb notebook that generates the GPKG files
  f1 <- st_transform(f1, "epsg:4326")
  f2 <- st_transform(f2, "epsg:4326")
  
  # Identify overlapping areas 
  tryCatch({
      overlap <- st_intersection(f1, f2)
  
    
      # If no overlap exists, return an empty result
      if (nrow(overlap) == 0) {
        
          return(data.frame(file1 = basename(file1), file2 = basename(file2), overlap_population = 0))
        
      } else {
    
        # Attempt to write the overlap file
        st_write(overlap, sprintf("cloudrf/output/overlaps/gpkg/overlap_%s_%s", basename(file1), basename(file2)),
                 append = FALSE)
        
        # Attempt to compute population for the overlap
        overlap_population <- exactextractr::exact_extract(population_raster, overlap, 
                                                           fun = function(values, coverage_fractions) {
                                                             sum(values * coverage_fractions, na.rm = TRUE)
                                                           })
        
        return(data.frame(file1 = basename(file1), file2 = basename(file2), overlap_population = overlap_population))
      }
    }, error = function(e) {
      message(sprintf("Error processing %s and %s: %s", basename(file1), basename(file2), e$message))
      return(data.frame(file1 = basename(file1), file2 = basename(file2), overlap_population = NA))
  })
    
}

# Generate all unique file pairs
file_pairs <- combn(file_list, 2, simplify = FALSE)

# Apply function to all pairs and bind results
overlap_df <- bind_rows(map(file_pairs, ~ estimate_overlap(.x[1], .x[2])))

# Print results
print(overlap_df)
write.csv(overlap_df, sprintf("cloudrf/output/overlaps/%s_%s_overlap_constrained_%s.csv", country, subfolder, pop_year))   

