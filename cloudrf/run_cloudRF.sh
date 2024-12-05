#!/bin/bash

# Script to run CloudRF on specified radio stations.
# 
# 1. Designate input CSV file or select 'all'.
# 2. Read input CSV file with radio station specs.
# 3. Run CloudRF


# Prompt user for API key
# read -p "Enter the CloudRF API-KEY:" APIKEY

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
  
  echo "\tYou selected: $selected_file"
  python3 CloudRF.py area -i /$selected_file -t fem.json -k $APIKEY

# if 0 is selected, run all
elif [ $file_number -eq 0 ]; then
  echo "\t$file_number - Running CloudRF for all files..."
  for f in ${files[@]}; do
    echo "\t\t" $f
    python3 CloudRF.py area -i $f -t fem.json -k $APIKEY
  done

else
  echo "Invalid selection. Please run the script again."
  exit 1
fi

exit 0