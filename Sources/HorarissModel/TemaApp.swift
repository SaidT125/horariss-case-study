import Foundation

/// El tema de color que eligió el usuario en Perfil.
///
/// Aquí solo está el dato, que es lo que se guarda y se sincroniza. Los colores
/// que salen de él viven en `HorarissUI`, por la misma razón que el color de una
/// materia: derivar un `Color` es presentación, no dato.
public enum TemaApp: String, CaseIterable, Codable, Sendable {
    case morado, rosa, azul, verde

    /// El acento del tema, en hex. Está aquí y no en `HorarissUI` porque no solo
    /// lo pinta la interfaz: es también el color del calendario que se crea en
    /// el Calendario de Apple, y esa parte vive en la capa de datos, que no debe
    /// depender de la de interfaz.
    public var hexAcento: String {
        switch self {
        case .morado: "672EFF"
        case .rosa:   "DE58C7"
        case .azul:   "3390D7"
        case .verde:  "6DC130"
        }
    }

}
