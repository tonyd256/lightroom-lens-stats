# Lightroom Lens Statistics Analyzer

A simple tool to analyze which lenses you use most in Lightroom, and which ones produce your best "keeper" photos.

## Requirements
- macOS (comes with Python 3 pre-installed)
- A Lightroom Classic catalog file (.lrcat)

## Installation

1. **Download both files:**
   - `analyze_lenses.py` (the main script)
   - `run_analysis.command` (the launcher - makes it easy to use)

2. **Put them in the same folder** (like your Desktop or Documents)

3. **Make the launcher executable** (one-time setup):
   - Open Terminal (Applications → Utilities → Terminal)
   - Type: `chmod +x ` (note the space after +x)
   - Drag `run_analysis.command` into the Terminal window
   - Press Enter

4. **Done!** Now you can double-click `run_analysis.command` anytime

## How to Use

### Easy Way (Double-click launcher):
1. Double-click `run_analysis.command`
2. Drag and drop your Lightroom catalog file when prompted
3. Press Enter to accept defaults, or customize the output filename and time period
4. Your results will be saved as a CSV file

### Command Line Way:
```bash
python3 analyze_lenses.py /path/to/Catalog.lrcat
```

Or with custom options:
```bash
python3 analyze_lenses.py /path/to/Catalog.lrcat my_stats.csv 180
```

## Finding Your Lightroom Catalog

Your Lightroom catalog is typically located at:
- `~/Pictures/Lightroom/Catalog.lrcat`
- Or wherever you saved it when creating your catalog

To find it in Lightroom:
1. Open Lightroom Classic
2. Go to **Lightroom > Catalog Settings** (Mac) or **Edit > Catalog Settings** (Windows)
3. The location is shown at the top

## What It Analyzes

- **Time Period**: Last 365 days by default (customizable)
- **Photos Per Lens**: How many photos you took with each lens
- **Keeper Rate**: Photos that are either:
  - Rated 1 star or higher, OR
  - Flagged as "picked"

## Output Columns

The CSV file includes:
- **lens_name**: Name of the lens
- **total_photos**: Total photos taken with this lens
- **rated_or_picked**: Number of "keeper" photos
- **keeper_percentage**: What percentage of your photos with this lens are keepers

## Examples

**Analyze last year:**
```bash
python3 analyze_lenses.py ~/Pictures/Lightroom/Catalog.lrcat
```

**Analyze last 6 months:**
```bash
python3 analyze_lenses.py ~/Pictures/Lightroom/Catalog.lrcat stats.csv 180
```

**Analyze last 30 days:**
```bash
python3 analyze_lenses.py ~/Pictures/Lightroom/Catalog.lrcat recent.csv 30
```

## Troubleshooting

### "Permission denied" error:
Run this command to make the launcher executable:
```bash
chmod +x run_analysis.command
```

### "No lens data found":
This usually means:
- No photos in the time period you specified
- Your photos don't have lens information in their EXIF data
- Try increasing the time period (e.g., 730 for 2 years)

### Can't find Python:
macOS should have Python 3 built-in. If you get an error, you may need to install it from https://www.python.org/downloads/

## Safety

- The catalog is opened in **read-only mode** - no changes are made
- Your original Lightroom catalog is never modified
- Safe to run while Lightroom is open

## Tips

- Export the CSV and open it in Excel, Numbers, or Google Sheets
- Sort by keeper_percentage to see which lenses produce your best work
- Sort by total_photos to see which lenses you use most
- Compare different time periods to see how your lens usage changes
