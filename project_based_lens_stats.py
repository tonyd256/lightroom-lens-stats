#!/usr/bin/env python3
"""
Recursively scans for Lightroom catalogs and aggregates lens usage statistics.
Looks for catalogs matching the pattern: */2_RESOURCES/Catalog/Catalog.lrcat
"""

import sqlite3
import os
import sys
from pathlib import Path
from collections import defaultdict
import csv

def find_lightroom_catalogs(root_path):
    """Find all Lightroom catalogs matching the expected structure."""
    catalogs = []
    root = Path(root_path)
    
    # Look for the specific pattern: */2_RESOURCES/Catalog/Catalog.lrcat
    for catalog_path in root.rglob("2_RESOURCES/Catalog/Catalog.lrcat"):
        if catalog_path.is_file():
            # Get the project name (parent of 2_RESOURCES)
            project_name = catalog_path.parent.parent.parent.name
            catalogs.append((project_name, catalog_path))
            print(f"Found catalog: {project_name}")
    
    return catalogs

def get_lens_stats(catalog_path):
    """Extract lens statistics from a single Lightroom catalog."""
    try:
        conn = sqlite3.connect(f"file:{catalog_path}?mode=ro", uri=True)
        cursor = conn.cursor()
        
        query = """
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
            AND img.captureTime >= datetime('now', '-1 year')
        GROUP BY lens.value
        """
        
        cursor.execute(query)
        results = cursor.fetchall()
        conn.close()
        
        return results
    except sqlite3.Error as e:
        print(f"Error reading {catalog_path}: {e}", file=sys.stderr)
        return []

def aggregate_stats(catalogs):
    """Aggregate lens statistics from all catalogs."""
    # Dictionary to store aggregated data: lens_name -> [total_photos, rated_or_picked]
    aggregated = defaultdict(lambda: {"photo_count": 0, "rated_or_picked": 0, "projects": []})
    
    for project_name, catalog_path in catalogs:
        print(f"\nProcessing: {project_name}")
        stats = get_lens_stats(catalog_path)
        
        for lens_name, photo_count, rated_or_picked in stats:
            aggregated[lens_name]["photo_count"] += photo_count
            aggregated[lens_name]["rated_or_picked"] += rated_or_picked
            if photo_count > 0:
                aggregated[lens_name]["projects"].append(project_name)
    
    return aggregated

def write_csv(aggregated, output_file):
    """Write aggregated statistics to CSV file."""
    with open(output_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow([
            'lens_name', 
            'total_photos', 
            'rated_or_picked', 
            'keeper_percentage',
            'project_count',
            'projects'
        ])
        
        # Sort by total photos descending
        sorted_lenses = sorted(
            aggregated.items(), 
            key=lambda x: x[1]["photo_count"], 
            reverse=True
        )
        
        for lens_name, data in sorted_lenses:
            photo_count = data["photo_count"]
            rated_or_picked = data["rated_or_picked"]
            keeper_pct = round(100.0 * rated_or_picked / photo_count, 1) if photo_count > 0 else 0
            project_count = len(data["projects"])
            projects = ", ".join(data["projects"])
            
            writer.writerow([
                lens_name,
                photo_count,
                rated_or_picked,
                keeper_pct,
                project_count,
                projects
            ])

def main():
    if len(sys.argv) < 2:
        print("Usage: python script.py <root_folder> [output.csv]")
        print("Example: python script.py /Users/username/Projects lens_stats.csv")
        sys.exit(1)
    
    root_folder = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else "lens_stats_aggregated.csv"
    
    if not os.path.isdir(root_folder):
        print(f"Error: {root_folder} is not a valid directory")
        sys.exit(1)
    
    print(f"Scanning for Lightroom catalogs in: {root_folder}")
    print("=" * 60)
    
    catalogs = find_lightroom_catalogs(root_folder)
    
    if not catalogs:
        print("\nNo Lightroom catalogs found matching the pattern:")
        print("  */2_RESOURCES/Catalog/Catalog.lrcat")
        sys.exit(1)
    
    print(f"\nFound {len(catalogs)} catalog(s)")
    print("=" * 60)
    
    aggregated = aggregate_stats(catalogs)
    
    print("\n" + "=" * 60)
    print(f"Writing results to: {output_file}")
    write_csv(aggregated, output_file)
    
    print(f"\nDone! Processed {len(catalogs)} catalogs")
    print(f"Found statistics for {len(aggregated)} lenses")

if __name__ == "__main__":
    main()
