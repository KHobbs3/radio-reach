#!/bin/bash

# Script to run CloudRF on specified radio stations.
# 
# 1. Designate input CSV file or select 'all'.
# 2. Read input CSV file with radio station specs.
# 3. Run CloudRF
# 4. Convert CloudRF output (SHP) to GPKG

# Prompt user for country
read -p "Enter the country to analysis:" COUNTRY

# Read API key
APIKEY=$(<"api-key.txt")

# List available files in the current directory
echo "Available files:"
files=(input/*)
for i in "${!files[@]}"; do
  echo $((i+1)). ${files[i]}
done

# Prompt user to select a file
read -p "Enter the number of the file you want to select or 0 for all: " file_number

# Validate input
if [[ $file_number -gt 0 && $file_number -le ${#files[@]} ]]; then
  selected_file=${files[$((file_number-1))]}
  
  echo "You selected: $selected_file"
  python3 CloudRF.py area -i $selected_file -t fem.json -k $APIKEY -s tiff -o "output/raw/${COUNTRY}"

# if 0 is selected, run all
elif [ $file_number -eq 0 ]; then
  echo "$file_number - Running CloudRF for all files..."
  for f in ${files[@]}; do
    echo $f
    python3 CloudRF.py area -i $f -t fem.json -k $APIKEY -s tiff -o "output/raw/${COUNTRY}"
  done

else
  echo "Invalid selection. Please run the script again."
  exit 1
fi

# Convert to GPKG
RScript to_gpkg.R --country=$COUNTRY

exit 0