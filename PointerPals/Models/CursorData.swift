import Foundation

struct CursorData: Codable {
    let userId: String
    let x: Double // Normalized X coordinate (0.0 to 1.0)
    let y: Double // Normalized Y coordinate (0.0 to 1.0)
    let timestamp: Date
    
    init(userId: String, x: Double, y: Double, timestamp: Date) {
        self.userId = userId
        self.x = max(0.0, min(1.0, x)) // Clamp to 0.0-1.0 range
        self.y = max(0.0, min(1.0, y)) // Clamp to 0.0-1.0 range
        self.timestamp = timestamp
    }
}
