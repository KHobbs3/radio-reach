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
table <- arg_list[["table"]]
file_format <- arg_list[["format"]]

# Define output directory
outpath = sprintf("output/gpkg/%s/%s/", country, table)

# Create output directory
if (dir.exists(outpath) == F){
  dir.create(outpath)
}


# Read files ----
# cloudrf raw output files
files = list.files(here("cloudrf", sprintf("output/raw/%s/%s/", country, table)),
                   pattern = sprintf('.%s$',file_format))
print(files)


# Iterate ----
for (file in files[1:length(files)]) {
  
  # Get file name
  fname <- file
  print(fname)

  # Read CloudRF output file
  cloudrf_data <- rast(here("cloudrf", "output", "raw", country, table, file),
                       lyrs = 1)

  # Save the polygons as a GeoPackage
  terra::writeRaster(cloudrf_data, here("cloudrf", outpath, sprintf("%s.gpkg", fname)),
              overwrite = TRUE)

}

