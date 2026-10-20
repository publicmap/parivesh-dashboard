#!/bin/bash

STATE=${1:-""}

# Create output directory with state suffix if filtering by state
if [ -n "$STATE" ]; then
  OUTPUT_DIR="raw/search_${STATE}"
  echo "Fetching data for state: $STATE"
else
  OUTPUT_DIR="raw/search"
  echo "Fetching data for all states"
fi

mkdir -p "$OUTPUT_DIR"

for clearance in {1..4};
do
  OUTPUT_FILE="$OUTPUT_DIR/${clearance}.json"
  API_URL="https://parivesh.nic.in/parivesh_api/trackYourProposal/advanceSearchData?majorClearanceType=${clearance}&state=${STATE}&sector=&proposalStatus=&proposalType=&issuingAuthority=&activityId=&category=&startDate=&endDate=&areaMin=&areaMax=&text="
  
  echo "Fetching clearance type $clearance for state '$STATE'..."
  ok=0
  for attempt in 1 2 3 4 5; do
    if curl -fsS --max-time 900 "$API_URL" > "$OUTPUT_FILE.tmp" && [ -s "$OUTPUT_FILE.tmp" ]; then
      mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
      ok=1
      break
    fi
    wait=$((15 * 2 ** (attempt - 1)))
    echo "Attempt $attempt failed for clearance type $clearance; retrying in ${wait}s..." >&2
    sleep "$wait"
  done
  rm -f "$OUTPUT_FILE.tmp"

  if [ "$ok" = 1 ]; then
    echo "Successfully fetched data for clearance type $clearance"
  elif [ -s "$OUTPUT_FILE" ]; then
    echo "::warning::Parivesh search failed for state '$STATE' clearance type $clearance; using the previous list"
  else
    echo "Error: failed to fetch clearance type $clearance" >&2
    exit 1
  fi

done

echo "Data fetching completed. Files saved to: $OUTPUT_DIR"
