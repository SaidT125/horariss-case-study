import Foundation

public struct Tarea: Identifiable, Codable, Sendable {
    public var id: UUID = UUID()
    public var nombre: String
    public var descripcion: String = ""
    public var materiaId: UUID
    public var fechaEntrega: Date
    public var completada: Bool = false

    public init(id: UUID = UUID(), nombre: String, descripcion: String = "",
                materiaId: UUID, fechaEntrega: Date, completada: Bool = false) {
        self.id = id; self.nombre = nombre; self.descripcion = descripcion
        self.materiaId = materiaId; self.fechaEntrega = fechaEntrega
        self.completada = completada
    }
}
