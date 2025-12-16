# Install dependencies ----
install.packages(c("here", "terra", "sf", "mapview",
                   "openxlsx", "stringr", "raster",
                   "RColorBrewer", "htmlwidgets", "leaflet.extras",
                   "leaflet", "dplyr", "purrr"))




# File to setup output directories for a new country ----
library(here)

# USER INPUT ----
country <- "nigeria"
input_folder <- "fem_nigeria"

# Folders for cloudrf outputs
dir.create(file.path(here("cloudrf", "output", "raw", 
                          input_folder, country)),
           recursive = TRUE)
dir.create(file.path(here("cloudrf", "output", "overlaps", 
                          input_folder, country)),
           recursive = TRUE)
dir.create(file.path(here("cloudrf", "output", "gpkg", 
                          input_folder, country)),
           recursive = TRUE)


# Folders for reach outputs
dir.create(file.path(here("reach", "intermediates", 
                          country)),
           recursive = TRUE)
dir.create(file.path(here("reach", "output", "overlaps", 
                          country)),
           recursive = TRUE)
