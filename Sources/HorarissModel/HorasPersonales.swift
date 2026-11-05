import Foundation

// ------------------------------------------------------------
// HORAS LIBRES Y HORAS DE ESTUDIO
// Comparten la estructura de días + bloques con Materia, pero no tienen aula,
// asistencia ni tareas: son bloques de tiempo propios del usuario.
// ------------------------------------------------------------

// Identifiable lo pide `.fullScreenCover(item:)` en la app. La conformidad va
// aquí, junto al tipo: declararla desde fuera del módulo compila, pero Swift
// avisa de que se rompería si algún día el módulo la añadiera por su cuenta.
public enum TipoHora: String, Codable, CaseIterable, Identifiable, Sendable {
    case libre, estudio
    public var id: String { rawValue }
}

/// Título predefinido de una hora libre. El color y el ícono van atados al
/// título: aquí el usuario no los elige (a diferencia de las materias).
public struct PresetHoraLibre: Identifiable, Hashable, Sendable {
    public let id: String
    public let titulo: String
    public let icono: String
    public let colorHex: String

    public init(id: String, titulo: String, icono: String, colorHex: String) {
        self.id = id; self.titulo = titulo; self.icono = icono; self.colorHex = colorHex
    }
}

public enum CatalogoHoras {
    public static let presetsLibres: [PresetHoraLibre] = [
        PresetHoraLibre(id: "ocio", titulo: String(localized: "Tiempo de ocio"),
                        icono: "gamecontroller.fill", colorHex: "7CC7FF"),   // azul cielo
        PresetHoraLibre(id: "comer", titulo: String(localized: "Tiempo para comer"),
                        icono: "fork.knife", colorHex: "FF9F45"),            // naranja
        PresetHoraLibre(id: "meditacion", titulo: String(localized: "Tiempo de meditación"),
                        icono: "leaf.fill", colorHex: "7BC950")              // verde pasto
    ]
    /// Título propio del usuario: mismo trato, con color e ícono neutros.
    public static let colorLibrePropia = "5EDCE2"
    public static let iconoLibrePropia = "sparkles"
    public static let iconoEstudio     = "book.closed.fill"

    /// Grises de las horas de estudio: resaltan sobre el fondo sin competir con
    /// los colores de las materias.
    ///
    /// Los tres campos tienen dueños distintos y ninguno es redundante:
    ///
    /// - `claro` es el valor que SE GUARDA en `HoraPersonal.colorHex` y el que
    ///   usa el PDF, que se imprime sobre blanco y no sigue la apariencia.
    /// - `oscuro` alimenta la instantánea del widget. El widget es otro objetivo
    ///   con su propio bundle, así que no alcanza el catálogo de la app y
    ///   necesita el hex literal.
    /// - `colorSet` es el nombre del color en `Colores.xcassets`, de donde sale
    ///   el color adaptativo de la app. Va aquí, y no en la app con una búsqueda
    ///   por índice, para que la correspondencia sea total: cada gris carga su
    ///   propio nombre y no se pueden desincronizar dos arreglos paralelos.
    ///   Es un identificador de presentación, igual que los `icono` de arriba.
    public static let grisesEstudio: [(claro: String, oscuro: String, colorSet: String)] = [
        ("6E6E78", "B4B4BE", "grisEstudio1"),
        ("585862", "9E9EAA", "grisEstudio2"),
        ("7E7E8A", "C6C6D0", "grisEstudio3"),
        ("4C4C56", "8C8C98", "grisEstudio4")
    ]
    /// Gris siguiente de la rotación, para que dos horas seguidas no salgan iguales.
    public static func grisPara(indice: Int) -> String { grisesEstudio[abs(indice) % grisesEstudio.count].claro }
}

public struct HoraPersonal: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID = UUID()
    public var tipo: TipoHora
    public var titulo: String
    public var colorHex: String
    public var icono: String
    public var diasSemana: [Int] = []
    public var horarios: [HorarioDia] = []
    public var notas: String = ""
    /// A qué curso pertenece (0 = principal, 1 = segundo), igual que las materias.
    public var curso: Int = 0

    public static let maxNotas = 100

    public init(id: UUID = UUID(), tipo: TipoHora, titulo: String, colorHex: String, icono: String,
                diasSemana: [Int] = [], horarios: [HorarioDia] = [], notas: String = "", curso: Int = 0) {
        self.id = id; self.tipo = tipo; self.titulo = titulo
        self.colorHex = colorHex; self.icono = icono
        self.diasSemana = diasSemana; self.horarios = horarios
        self.notas = notas; self.curso = curso
    }

    // CodingKeys EXPLÍCITO. Swift lo sintetiza solo, pero el transpilador de
    // Skip no lo ve: falla con "unable to determine the owning type for member".
    // Solo las claves que el decodificador lee, que son exactamente las
    // propiedades guardadas; meter aquí una propiedad calculada rompería
    // Encodable. Comprobado en la prueba de humo del 26/09.
    private enum CodingKeys: String, CodingKey {
        case id, tipo, titulo, colorHex, icono, diasSemana, horarios, notas, curso
    }

    // Decodificación tolerante: nunca perder una hora ya guardada por un campo nuevo
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        // `TipoHora.libre` escrito entero: tras un `decodeIfPresent` de un enum
        // de String, el transpilador toma el tipo crudo y sale `String.libre`.
        tipo = try c.decodeIfPresent(TipoHora.self, forKey: .tipo) ?? TipoHora.libre
        titulo = try c.decodeIfPresent(String.self, forKey: .titulo) ?? ""
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? CatalogoHoras.colorLibrePropia
        icono = try c.decodeIfPresent(String.self, forKey: .icono) ?? CatalogoHoras.iconoLibrePropia
        diasSemana = try c.decodeIfPresent([Int].self, forKey: .diasSemana) ?? []
        horarios = try c.decodeIfPresent([HorarioDia].self, forKey: .horarios) ?? []
        notas = try c.decodeIfPresent(String.self, forKey: .notas) ?? ""
        curso = try c.decodeIfPresent(Int.self, forKey: .curso) ?? 0
    }

    public func bloque(dia: Int) -> HorarioDia? { horarios.first { $0.dia == dia } }
    public var bloquesOrdenados: [HorarioDia] { horarios.sorted { $0.dia < $1.dia } }

    /// Primer bloque de la semana (el que se muestra en la tarjeta resumen)
    public var primerBloque: HorarioDia? { bloquesOrdenados.first }

    /// ¿Los días tienen horas de inicio o duraciones distintas entre sí?
    public var variosHorarios: Bool {
        let bloques = bloquesOrdenados
        guard bloques.count > 1 else { return false }
        let cal = Calendar.current
        let firmas = Set(bloques.map { b in
            let c = cal.dateComponents([.hour, .minute], from: b.horario)
            return "\(c.hour ?? 0):\(c.minute ?? 0)|\(b.duracionHoras):\(b.duracionMinutos)"
        })
        return firmas.count > 1
    }

    /// Minuto de inicio del primer día, para ordenar la lista del inicio
    public var minutoInicio: Int {
        guard let b = primerBloque else { return 0 }
        let c = Calendar.current.dateComponents([.hour, .minute], from: b.horario)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    public static func == (l: HoraPersonal, r: HoraPersonal) -> Bool { l.id == r.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}
