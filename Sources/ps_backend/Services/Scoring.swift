import Foundation

enum Scoring {
    static func distanceMeters(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(a.squareRoot(), (1 - a).squareRoot())
        return r * c
    }

    /// 0–10 Punkte je nach Distanz: 50m-Schritte bis 200m, danach 100m-Schritte bis 800m.
    static func points(distanceMeters: Double) -> Int {
        switch distanceMeters {
        case ..<50: return 10
        case ..<100: return 9
        case ..<150: return 8
        case ..<200: return 7
        case ..<300: return 6
        case ..<400: return 5
        case ..<500: return 4
        case ..<600: return 3
        case ..<700: return 2
        case ..<800: return 1
        default: return 0
        }
    }
}
