//
//  LensAnalyzer.swift
//  LensStatsAnalyzer
//
//  Created by Tony DiPasquale on 12/10/25.
//

import UniformTypeIdentifiers
import SQLite3

class LensAnalyzer {
    func analyze(catalogPath: String, daysBack: Int) throws -> [LensStats] {
        var db: OpaquePointer?
        
        guard sqlite3_open_v2(catalogPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw NSError(domain: "SQLite", code: Int(sqlite3_errcode(db)),
                         userInfo: [NSLocalizedDescriptionKey: "Failed to open database: \(errMsg)"])
        }
        
        defer {
            sqlite3_close(db)
        }
        
        let query = """
        SELECT 
            lens.value AS lens_name,
            COUNT(DISTINCT img.id_local) AS photo_count,
            COUNT(DISTINCT CASE WHEN img.rating = 1 THEN img.id_local END) AS rating_1,
            COUNT(DISTINCT CASE WHEN img.rating = 2 THEN img.id_local END) AS rating_2,
            COUNT(DISTINCT CASE WHEN img.rating = 3 THEN img.id_local END) AS rating_3,
            COUNT(DISTINCT CASE WHEN img.rating = 4 THEN img.id_local END) AS rating_4,
            COUNT(DISTINCT CASE WHEN img.rating = 5 THEN img.id_local END) AS rating_5,
            COUNT(DISTINCT CASE WHEN img.pick = 1 THEN img.id_local END) AS picked,
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
            AND img.captureTime >= datetime('now', '-\(daysBack) days')
        GROUP BY lens.value
        ORDER BY photo_count DESC
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: Int(sqlite3_errcode(db)),
                         userInfo: [NSLocalizedDescriptionKey: "Failed to prepare statement: \(errMsg)"])
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        var results: [LensStats] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let lensName = String(cString: sqlite3_column_text(statement, 0))
            let totalPhotos = Int(sqlite3_column_int(statement, 1))
            let rating1 = Int(sqlite3_column_int(statement, 2))
            let rating2 = Int(sqlite3_column_int(statement, 3))
            let rating3 = Int(sqlite3_column_int(statement, 4))
            let rating4 = Int(sqlite3_column_int(statement, 5))
            let rating5 = Int(sqlite3_column_int(statement, 6))
            let picked = Int(sqlite3_column_int(statement, 7))
            let totalKeepers = Int(sqlite3_column_int(statement, 8))
            
            let stats = LensStats(
                lensName: lensName,
                totalPhotos: totalPhotos,
                rating1: rating1,
                rating2: rating2,
                rating3: rating3,
                rating4: rating4,
                rating5: rating5,
                picked: picked,
                totalKeepers: totalKeepers
            )
            
            results.append(stats)
        }
        
        return results
    }
    
    func writeCSV(stats: [LensStats], to url: URL) throws {
        var csvText = "lens_name,total_photos,1_star,2_star,3_star,4_star,5_star,picked,total_keepers,keeper_percentage\n"
        
        for stat in stats {
            let row = [
                stat.lensName.replacingOccurrences(of: ",", with: ";"),
                "\(stat.totalPhotos)",
                "\(stat.rating1)",
                "\(stat.rating2)",
                "\(stat.rating3)",
                "\(stat.rating4)",
                "\(stat.rating5)",
                "\(stat.picked)",
                "\(stat.totalKeepers)",
                String(format: "%.1f", stat.keeperPercentage)
            ].joined(separator: ",")
            
            csvText += row + "\n"
        }
        
        try csvText.write(to: url, atomically: true, encoding: .utf8)
    }
}
