//
//  LensStats.swift
//  LensStatsAnalyzer
//
//  Created by Tony DiPasquale on 12/10/25.
//

struct LensStats {
    let lensName: String
    let totalPhotos: Int
    let rating1: Int
    let rating2: Int
    let rating3: Int
    let rating4: Int
    let rating5: Int
    let picked: Int
    let totalKeepers: Int
    
    var keeperPercentage: Double {
        guard totalPhotos > 0 else { return 0 }
        return (Double(totalKeepers) / Double(totalPhotos)) * 100.0
    }
}
