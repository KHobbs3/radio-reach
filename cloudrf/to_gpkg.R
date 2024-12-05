library('sf')
library('here')
library('stringr')
library('dplyr')
library('mapview')

files = list.files("cloudrf/output/")

file <- files[1]

for (file in files) {
  
  # Get file name
  fname <- str_extract(file, "[A-Za-z](.+)(?=\\.shp\\.zip)")

  # Read CloudRF output file
  cloudrf_data <- st_read(here("cloudrf", "output", file), promote_to_multi = FALSE, quiet = TRUE)
  
  # # Correct data
  # TODO: add if-statement
  # valid_data <- st_make_valid(cloudrf_data)
  # 
  # simple_data <- st_simplify(valid_data, dTolerance = 0.01)
  
  # Deduplicate
  # TODO: add if-statement
  deduplicated <- cloudrf_data %>%
    distinct(geometry, .keep_all = TRUE)
  
  # Merge
  multipolygon <- st_combine(deduplicated)
  
  polygon <- st_union(multipolygon)
  
  # Check
  mapview(polygon)
  
  # Export as gpkg
  st_write(polygon, sprintf("cloudrf/output/gpkg/%s.gpkg", fname), layer = fname, append=FALSE)

}
