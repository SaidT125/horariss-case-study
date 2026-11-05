import Foundation

/// Una cosa que toca hoy: una clase, una hora libre o una de estudio, con
/// el bloque concreto que le corresponde. Una materia que se imparte dos
/// veces el mismo día aparece dos veces, cada una con su hora y su aula.
public struct ClaseDeHoy: Identifiable, Sendable {
    public enum Origen: Sendable { case materia(Materia), hora(HoraPersonal) }
    public let origen: Origen
    public let bloque: HorarioDia
    public let indice: Int

    public init(origen: Origen, bloque: HorarioDia, indice: Int) {
        self.origen = origen; self.bloque = bloque; self.indice = indice
    }

    /// Solo las materias tienen asistencia; una hora libre no se "completa".
    public var materia: Materia? {
        if case .materia(let m) = origen { return m }
        return nil
    }
    public var titulo: String {
        switch origen {
        case .materia(let m): m.nombre
        case .hora(let h):    h.titulo
        }
    }
    // `color` es presentación y vive en HorarissUI.
    public var icono: String {
        switch origen {
        case .materia(let m): m.icono
        case .hora(let h):    h.icono
        }
    }
    public var id: String {
        switch origen {
        case .materia(let m): "m-\(m.id.uuidString)-\(indice)"
        case .hora(let h):    "h-\(h.id.uuidString)-\(indice)"
        }
    }
}
