#----------------
# Visualise rasters with hover labels
#----------------
library(sf)
library(mapview)
library(raster)
library(RColorBrewer)
library(leaflet)
library(leaflet.extras)
library(htmlwidgets)
library(stringr)
library(here)

# User input
country <- "nigeria"  # e.g. "benin"

# Set-up file path
filepath <- sprintf('cloudrf/output/raw/%s/fem_%s', country, country)

# Get all .kmz files
raster_files <- list.files(filepath, pattern = "\\.kmz$", full.names = TRUE)

# Define color palette (red gradient)
pal <- colorNumeric(palette = "Reds", domain = c(50,250), na.color = "transparent")

# Create a new leaflet map
map <- leaflet() %>%
  addProviderTiles("CartoDB.PositronOnlyLabels", group = "Labels") %>%
  addProviderTiles("CartoDB.Positron", group = "Positron")

# Prepare list to hold overlay group names
overlay_groups <- c("Labels")

# Loop through each raster file
for (f in raster_files) {
  # Try to read raster
  r <- tryCatch(raster(f), error = function(e) NULL)
  if (!is.null(r)) {
    # Replace 0s with NAs
    r[r == 0] <- 0
    
    # Extract a readable station name from the file
    station_name <- tools::file_path_sans_ext(basename(f)) %>%
      str_replace_all("_GW$", "") %>%
      str_replace_all("^[0-9\\-]+_", "") %>%  # Remove timestamp
      str_replace_all("_", " ") %>% 
      str_to_title()
    
    # Add raster to map
    map <- map %>%
      addRasterImage(r, colors = pal, opacity = 0.5, project = TRUE, group = station_name)
    
    # Create an extent polygon for label hover
    extent_poly <- as(extent(r), "SpatialPolygons")
    crs(extent_poly) <- crs(r)
    extent_poly_sf <- st_as_sf(extent_poly)
    extent_poly_sf$label <- station_name
    
    # Add transparent polygon with label on hover
    map <- map %>%
      addPolygons(
        data = extent_poly_sf,
        fillOpacity = 0,
        color = "transparent",
        label = ~label,
        group = station_name,
        highlightOptions = highlightOptions(color = "#ffffcc", weight = 2)
      )
    
    # Add to overlay groups
    overlay_groups <- c(overlay_groups, station_name)
  }
}

# Add layer controls
map <- map %>%
  addLayersControl(
    baseGroups = c("Satellite"),
    overlayGroups = overlay_groups,
    options = layersControlOptions(collapsed = FALSE)
  )

# Show map
map

