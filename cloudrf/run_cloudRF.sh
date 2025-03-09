#!/bin/bash

# Script to run CloudRF on specified radio stations.
# 0. Set-up/read API key
# 1. Designate country
# 2. Select folder (ie. table) for input  CSV file
# 3. Select CSV file or select 'all'.
# 4. Read input CSV file with radio station specs.
# 5. Run CloudRF
# 6. Convert CloudRF output to GPKG

# 0. Set-up -----
# Read API key
APIKEY=$(<"api-key.txt")

# 1. Prompt user for country ----
read -p "Enter the country to analysis:" COUNTRY


# 2. List available files in the current directory ----
echo "Available folders:"
folders=(input/*)
for i in "${!folders[@]}"; do
  echo $((i+1)). ${folders[i]}
done

# Select folder for input files
read -p "Select the folder you want to read files" foldername

# Save table name for export
TABLE=$(basename ${folders[foldername-1]})

# Make output directory
mkdir output/raw/${COUNTRY}/${TABLE}/


# 3. List available files in the current directory ----
echo "Available files:"
files=(${folders[foldername-1]}/*)
for i in "${!files[@]}"; do
  echo $((i+1)). ${files[i]}
done

# Prompt user to select a file
read -p "Enter the number of the file you want to select or 0 for all: " file_number


# 4. Validate input and read file ----
if [[ $file_number -gt 0 && $file_number -le ${#files[@]} ]]; then
  selected_file=${files[$((file_number-1))]}
  
  echo "You selected: $selected_file"

  # 5. Run cloudRF ----
  # python3 CloudRF.py area -i $selected_file -t fem.json -k $APIKEY -s tiff -o $OUTDIR

# if 0 is selected, run all
elif [ $file_number -eq 0 ]; then
  echo "$file_number - Running CloudRF for all files..."
  for f in ${files[@]}; do
    echo $f

     # 5. Run cloudRF ----
    # python3 CloudRF.py area -i $f -t fem.json -k $APIKEY -s tiff -o $OUTDIR
  done

else
  echo "Invalid selection. Please run the script again."
  exit 1
fi


# 6. Convert to GPKG ----
RScript to_gpkg.R --country=$COUNTRY --table=$TABLE

exit 0