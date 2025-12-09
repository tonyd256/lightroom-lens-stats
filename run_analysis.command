#!/bin/bash
# Lightroom Lens Statistics Launcher for macOS
# Double-click this file to run the analysis

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change to the script directory
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Lightroom Lens Statistics Analyzer"
echo "=========================================="
echo ""

# Check if Python script exists
if [ ! -f "analyze_lenses.py" ]; then
    echo "ERROR: analyze_lenses.py not found in the same folder!"
    echo "Please make sure both files are in the same directory."
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi

# Prompt for catalog file
echo "Enter the path to your Lightroom catalog (.lrcat file):"
echo "(Drag and drop the file here, or type the path)"
read -e CATALOG_FILE

# Remove quotes if present (from drag-and-drop)
CATALOG_FILE="${CATALOG_FILE//\"/}"
CATALOG_FILE="${CATALOG_FILE//\'/}"

# Trim whitespace
CATALOG_FILE="$(echo -e "${CATALOG_FILE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

# Check if file exists
if [ ! -f "$CATALOG_FILE" ]; then
    echo ""
    echo "ERROR: File not found: $CATALOG_FILE"
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi

# Prompt for output file (with default)
echo ""
echo "Enter output filename (default: lens_stats.csv):"
read OUTPUT_FILE

# Use default if empty
if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="lens_stats.csv"
fi

# Add .csv extension if missing
if [[ ! "$OUTPUT_FILE" =~ \.csv$ ]]; then
    OUTPUT_FILE="${OUTPUT_FILE}.csv"
fi

# Prompt for time period
echo ""
echo "How many days back to analyze? (default: 365)"
read DAYS_BACK

# Use default if empty
if [ -z "$DAYS_BACK" ]; then
    DAYS_BACK="365"
fi

echo ""
echo "Starting analysis..."
echo "=========================================="
echo ""

# Run the Python script
python3 analyze_lenses.py "$CATALOG_FILE" "$OUTPUT_FILE" "$DAYS_BACK"

EXIT_CODE=$?

echo ""
echo "=========================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ Analysis complete!"
    echo ""
    echo "Output saved to: $OUTPUT_FILE"
    echo ""
    
    # Ask if user wants to open the CSV
    read -p "Open CSV file now? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "$OUTPUT_FILE"
    fi
else
    echo "✗ Analysis failed. See errors above."
fi

echo ""
read -p "Press Enter to exit..."
