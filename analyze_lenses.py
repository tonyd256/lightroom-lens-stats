#!/usr/bin/env python3
"""
Analyzes a Lightroom catalog and generates lens usage statistics.
"""

import sqlite3
import sys
from pathlib import Path
import csv

def get_lens_stats(catalog_path, days_back=365):
    """Extract lens statistics from a Lightroom catalog."""
    try:
        conn = sqlite3.connect(f"file:{catalog_path}?mode=ro", uri=True)
        cursor = conn.cursor()
        
        query = f"""
        SELECT 
            lens.value AS lens_name,
            COUNT(DISTINCT img.id_local) AS photo_count,
            COUNT(DISTINCT CASE 
                WHEN (img.rating >= 1 OR img.pick = 1) 
                THEN img.id_local 
            END) AS rated_or_picked_count
        FROM Adobe_images img
        INNER JOIN AgHarvestedExifMetadata exif 
            ON img.id_local = exif.image
        INNER JOIN AgInternedExifLens lens 
            ON exif.lensRef = lens.id_local
        WHERE lens.value IS NOT NULL
            AND img.captureTime >= datetime('now', '-{days_back} days')
        GROUP BY lens.value
        ORDER BY photo_count DESC
        """
        
        cursor.execute(query)
        results = cursor.fetchall()
        conn.close()
        
        return results
    except sqlite3.Error as e:
        print(f"Error reading catalog: {e}", file=sys.stderr)
        sys.exit(1)

def write_csv(stats, output_file):
    """Write statistics to CSV file."""
    with open(output_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow([
            'lens_name', 
            'total_photos', 
            'rated_or_picked', 
            'keeper_percentage'
        ])
        
        for lens_name, photo_count, rated_or_picked in stats:
            keeper_pct = round(100.0 * rated_or_picked / photo_count, 1) if photo_count > 0 else 0
            
            writer.writerow([
                lens_name,
                photo_count,
                rated_or_picked,
                keeper_pct
            ])

def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze_lenses.py <catalog.lrcat> [output.csv] [days_back]")
        print("\nExamples:")
        print("  python analyze_lenses.py /path/to/Catalog.lrcat")
        print("  python analyze_lenses.py /path/to/Catalog.lrcat my_stats.csv")
        print("  python analyze_lenses.py /path/to/Catalog.lrcat my_stats.csv 180")
        print("\nArguments:")
        print("  catalog.lrcat  - Path to your Lightroom catalog file")
        print("  output.csv     - Output filename (default: lens_stats.csv)")
        print("  days_back      - Number of days to look back (default: 365)")
        sys.exit(1)
    
    catalog_path = Path(sys.argv[1])
    output_file = sys.argv[2] if len(sys.argv) > 2 else "lens_stats.csv"
    days_back = int(sys.argv[3]) if len(sys.argv) > 3 else 365
    
    if not catalog_path.exists():
        print(f"Error: Catalog file not found: {catalog_path}")
        sys.exit(1)
    
    if not catalog_path.suffix == '.lrcat':
        print(f"Warning: File doesn't have .lrcat extension: {catalog_path}")
        response = input("Continue anyway? (y/n): ")
        if response.lower() != 'y':
            sys.exit(0)
    
    print(f"Analyzing catalog: {catalog_path.name}")
    print(f"Looking back: {days_back} days")
    print("=" * 60)
    
    stats = get_lens_stats(catalog_path, days_back)
    
    if not stats:
        print("\nNo lens data found in catalog.")
        print("This could mean:")
        print("  - No photos in the specified time range")
        print("  - Photos don't have lens EXIF data")
        print("  - Catalog metadata hasn't been harvested yet")
        sys.exit(1)
    
    print(f"\nFound statistics for {len(stats)} lenses")
    print(f"Writing results to: {output_file}")
    
    write_csv(stats, output_file)
    
    print("\n" + "=" * 60)
    print("✓ Done!")
    print(f"\nTop 5 most-used lenses:")
    for i, (lens_name, photo_count, rated_or_picked) in enumerate(stats[:5], 1):
        keeper_pct = round(100.0 * rated_or_picked / photo_count, 1) if photo_count > 0 else 0
        print(f"  {i}. {lens_name}: {photo_count} photos ({keeper_pct}% keepers)")

if __name__ == "__main__":
    main()
