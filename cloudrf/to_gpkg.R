library('sf')
library('here')
library('stringr')
library('dplyr')
library('mapview')

# Set-up ----
# # country to run analysis
# country_list <- list.dirs(path = 'reach/populations/', recursive = TRUE, full.names = TRUE) %>% basename()
# print(country_list[2:length(country_list)])
# 
# country <- readline(prompt = "Enter the country name or type 'all' for all: ")
# print(paste("Radio reach estimates for: ,", country))
# Get the command-line arguments
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

# Access the keyword argument
country <- arg_list[["country"]]

# cloudrf raw output files
files = list.files(sprintf("cloudrf/output/raw/%s/"), country)


# Test
file <- files[3]

# Iterate ----
for (file in files[8:length(files)]) {
  
  # Get file name
  fname <- str_extract(file, "[A-Za-z](.+)(?=\\.shp\\.zip)")
  print(fname)

  # Read CloudRF output file
  cloudrf_data <- st_read(here("cloudrf", "output", "raw", country, file), promote_to_multi = FALSE, quiet = TRUE)
  

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
  
  # Repeat as first pass returns geometry collection - # Check for invalid geometries
  invalid_geometries <- !st_is_valid(multipolygon)
  if (any(invalid_geometries)) {
    cat("Invalid geometries found. Applying st_make_valid() and snapping floating point differences.\n")
    # Make valid and eliminate floating point differences by snapping geometry
    multipolygon <- st_make_valid(multipolygon)
    multipolygon <- st_set_precision(multipolygon, 1e-7)
  }
  
  # Dissolve
  polygon <- st_union(multipolygon)
  
  # Check
  # mapview(polygon)
  
  # Export as gpkg
  st_write(polygon, sprintf("cloudrf/output/gpkg/%s/%s.gpkg", country, fname), layer = fname, append=FALSE)

}
