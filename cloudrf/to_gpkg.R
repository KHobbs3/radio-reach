library('sf')
library('here')
library('stringr')
library('dplyr')
library('mapview')
library('terra')

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
files = list.files(here("cloudrf", sprintf("output/raw/%s/", country)))
print(files)

# Iterate ----
for (file in files[1:length(files)]) {
  
  # Get file name
  fname <- str_extract(file, "[A-Za-z](.+)(?=\\.gpkg)")
  print(fname)

  # Read CloudRF output file
  # cloudrf_data <- st_read(here("cloudrf", "output", "raw", country, file), promote_to_multi = FALSE, quiet = TRUE)
  cloudrf_data <- rast(here("cloudrf", "output", "raw", country, file))

  # Save the polygons as a GeoPackage
  terra::writeRaster(cloudrf_data, here("cloudrf", sprintf("output/gpkg/%s/%s.gpkg", country, fname)),
              overwrite = TRUE)

}
