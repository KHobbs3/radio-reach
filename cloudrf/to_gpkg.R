library('sf')
library('here')
library('stringr')
library('dplyr')
library('mapview')

files = list.files("cloudrf/output/")

file <- files[3]
for (file in files[4:length(files)]) {
  
  # Get file name
  fname <- str_extract(file, "[A-Za-z](.+)(?=\\.shp\\.zip)")
  print(fname)

  # Read CloudRF output file
  cloudrf_data <- st_read(here("cloudrf", "output", file), promote_to_multi = FALSE, quiet = TRUE)
  

  # simple_data <- st_simplify(valid_data, dTolerance = 0.01)
  
  # Deduplicate
  # TODO: add if-statement
  deduplicated <- cloudrf_data %>%
    distinct(geometry, .keep_all = TRUE)
  
  # Merge
  multipolygon <- st_combine(deduplicated)
  
  
  # Check for invalid geometries
  invalid_geometries <- !st_is_valid(multipolygon)
  if (any(invalid_geometries)) {
    cat("Invalid geometries found. Applying st_make_valid().\n")
    multipolygon <- st_make_valid(multipolygon)
  }
  
  # Repeat??  # Check for invalid geometries
  invalid_geometries <- !st_is_valid(multipolygon)
  if (any(invalid_geometries)) {
    cat("Invalid geometries found. Applying st_make_valid().\n")
    multipolygon <- st_make_valid(multipolygon)
  }
  
  # Dissolve
  polygon <- st_union(multipolygon)
  
  # Check
  # mapview(polygon)
  
  # Export as gpkg
  st_write(polygon, sprintf("cloudrf/output/gpkg/%s.gpkg", fname), layer = fname, append=FALSE)

}
