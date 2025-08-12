#----------------
# Visualise GPKG vector layers with hover labels
#----------------
library(sf)
library(mapview)
library(leaflet)
library(RColorBrewer)
library(leaflet.extras)
library(htmlwidgets)
library(stringr)
library(here)

# User input
country <- "niger"  # e.g. "benin"

# Set-up file path
filepath <- sprintf('/Users/kt/Documents/work/AIM Charities/FEM/Family Planning/Radio Reach/cloudrf/output/gpkg/%s/fem_%s', country, country)

# Get all .gpkg files
gpkg_files <- list.files(filepath, pattern = "\\.gpkg$", full.names = TRUE)

# Get boundaries
boundaries <- st_read("/Users/kt/Documents/work/AIM Charities/FEM/General Data/HDX Boundaries/benin/admin1/ben_admbnda_adm1_1m_salb_20190816.shp")

# Define color palette for fill
pal <- colorFactor(palette = "Reds", domain = NULL)

# Create a new leaflet map
map <- leaflet() %>%
  addProviderTiles("CartoDB.PositronOnlyLabels", group = "Labels") %>%
  addProviderTiles("CartoDB.Positron", group = "Positron")

# Prepare list to hold overlay group names
overlay_groups <- c("Labels")

# Loop through each GPKG file
for (f in gpkg_files) {
  # Try to read vector layer
  v <- tryCatch(st_read(f, quiet = TRUE), error = function(e) NULL)
  if (!is.null(v)) {
    
    # Extract a readable station name from the file name
    station_name <- tools::file_path_sans_ext(basename(f)) %>%
      str_replace_all("_GW$", "") %>%
      str_replace_all("^[0-9\\-]+_", "") %>%  # Remove timestamp
      str_replace_all("_", " ") %>% 
      str_to_title()
    
    # Add polygons to map
    map <- map %>%
      addPolygons(
        data = v,
        fillColor = ~pal(1),  # dummy single color
        fillOpacity = 0.5,
        color = "red",
        weight = 1,
        label = station_name,
        group = station_name,
        highlightOptions = highlightOptions(color = "#ffffcc", weight = 2)
      )
    
    # Compute centroid of polygon(s) for labeling
    centroids <- st_centroid(v) %>% st_transform(4326)  # ensure lat/lon
    
    # Add label at centroid(s)
    map <- map %>%
      addLabelOnlyMarkers(
        data = centroids,
        label = station_name,
        labelOptions = labelOptions(noHide = TRUE, direction = 'auto', textOnly = TRUE),
        group = station_name
      )
    
    # Add to overlay groups
    overlay_groups <- c(overlay_groups, station_name)
  }
}


# Compute centroid of boundaries for labeling
boundary_centroids <- st_centroid(boundaries) %>% st_transform(4326)  # ensure lat/lon


# Add layer controls
map <- map %>% addPolygons(
  data = boundaries,
  fill = FALSE,
  color = "green",
  weight = 0.6,
  group = "Boundaries",
  label = ~adm1_name, 
  highlightOptions = highlightOptions(color = "blue", weight = 2)
  ) %>%
  addLabelOnlyMarkers(
    data = boundary_centroids,
    label = ~adm1_name,
    labelOptions = labelOptions(noHide = TRUE, direction = 'auto', textOnly = TRUE),
    group = station_name
  ) %>%
    addLayersControl(
      baseGroups = c("Positron"),
      overlayGroups = overlay_groups,
      options = layersControlOptions(collapsed = FALSE)
    )

# Show map
map

