library('sf')
library('here')
library('stringr')
library('dplyr')
library('mapview')
library('terra')

# Set-up ----
# Get the command-line arguments to identify country for analysis
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
files = list.files(here("cloudrf", sprintf("output/raw/%s/", country)), pattern = '.tiff$')
print(files)

# Iterate ----
for (file in files[1:length(files)]) {
  
  # Get file name
  fname <- str_extract(file, "[A-Za-z](.+)(?=\\.4326)")
  print(fname)

  # Read CloudRF output file
  cloudrf_data <- rast(here("cloudrf", "output", "raw", country, file))

  # Save the polygons as a GeoPackage
  terra::writeRaster(cloudrf_data, here("cloudrf", sprintf("output/gpkg/%s/%s.gpkg", country, fname)),
              overwrite = TRUE)

}
