import Foundation
import SwiftData

@Model
final class Character {
    @Attribute(.unique) var id: UUID
    var name: String
    var aliases: String
    var gender: String
    var age: String
    var appearance: String
    var personality: String
    var background: String
    var goals: String
    var relationships: String
    var notes: String
    var avatarData: Data?
    var createdAt: Date
    var updatedAt: Date
    var order: Int
    
    @Relationship(deleteRule: .nullify)
    var project: Project?
    
    init(
        name: String = "",
        aliases: String = "",
        gender: String = "",
        age: String = "",
        appearance: String = "",
        personality: String = "",
        background: String = "",
        goals: String = "",
        relationships: String = "",
        notes: String = "",
        order: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.aliases = aliases
        self.gender = gender
        self.age = age
        self.appearance = appearance
        self.personality = personality
        self.background = background
        self.goals = goals
        self.relationships = relationships
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.order = order
    }
}
