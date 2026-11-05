import Foundation

public struct Materia: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID = UUID()
    public var nombre: String
    public var horario: Date
    public var colorHex: String
    public var diasSemana: [Int] = []
    public var asistencias: [String] = []
    public var duracionHoras: Int = 1      // 1-5 horas
    public var duracionMinutos: Int = 0    // 0, 10, 20, 30, 40, 50 min
    public var icono: String = "book.fill"
    // Horarios por día. Si está vacío, se usa el horario/duración global para todos
    // los días de `diasSemana` (materias creadas antes de esta función).
    public var horarios: [HorarioDia] = []
    // A qué curso pertenece (0 = principal, 1 = segundo). Materias viejas → 0.
    public var curso: Int = 0
    // Aula o salón. Vacío = "sin aula" (no se menciona en las notificaciones).
    public var aula: String = ""
    // Nota libre del usuario sobre la materia (tope de caracteres: maxNotas).
    public var notas: String = ""

    public static let maxNotas = 100

    public init(id: UUID = UUID(), nombre: String, horario: Date, colorHex: String,
                diasSemana: [Int] = [], asistencias: [String] = [],
                duracionHoras: Int = 1, duracionMinutos: Int = 0, icono: String = "book.fill",
                horarios: [HorarioDia] = [], curso: Int = 0,
                aula: String = "", notas: String = "") {
        self.id = id; self.nombre = nombre; self.horario = horario; self.colorHex = colorHex
        self.diasSemana = diasSemana; self.asistencias = asistencias
        self.duracionHoras = duracionHoras; self.duracionMinutos = duracionMinutos
        self.icono = icono; self.horarios = horarios; self.curso = curso
        self.aula = aula; self.notas = notas
    }

    /// Aula ya limpia, o nil si la materia no tiene aula asignada
    public var aulaValida: String? {
        let t = aula.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// Minuto del día en que arranca un bloque, para poder ordenarlos
    private func minutosDelDia(_ b: HorarioDia) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: b.horario)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Aula de una clase concreta: la suya propia y, si no tiene, la general.
    /// Con varias clases el mismo día hay que preguntar por el bloque y no por
    /// el día: si no, las dos enseñarían el aula de la primera.
    public func aula(de bloque: HorarioDia) -> String? {
        let propia = bloque.aula.trimmingCharacters(in: .whitespacesAndNewlines)
        return propia.isEmpty ? aulaValida : propia
    }

    /// Aula de un día concreto: primero la propia del día, si no la general.
    public func aula(dia: Int) -> String? {
        if let propia = bloque(dia: dia)?.aula.trimmingCharacters(in: .whitespacesAndNewlines),
           !propia.isEmpty { return propia }
        return aulaValida
    }

    /// ¿Los días tienen aulas distintas entre sí?
    public var variasAulas: Bool {
        let propias = horarios.map { $0.aula.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Set(propias).count > 1 || (!propias.isEmpty && propias.count != horarios.count)
    }

    // CodingKeys EXPLÍCITO. Swift lo sintetiza solo, pero el transpilador de
    // Skip no lo ve: falla con "unable to determine the owning type for member".
    // Solo las claves que el decodificador lee, que son exactamente las
    // propiedades guardadas; meter aquí una propiedad calculada rompería
    // Encodable. Comprobado en la prueba de humo del 26/09.
    private enum CodingKeys: String, CodingKey {
        case id, nombre, horario, colorHex, diasSemana, asistencias, duracionHoras, duracionMinutos, icono, horarios, curso, aula, notas
    }

    // Decodificación tolerante: datos guardados antes de "icono" no deben perderse
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        nombre = try c.decode(String.self, forKey: .nombre)
        horario = try c.decode(Date.self, forKey: .horario)
        colorHex = try c.decode(String.self, forKey: .colorHex)
        diasSemana = try c.decodeIfPresent([Int].self, forKey: .diasSemana) ?? []
        asistencias = try c.decodeIfPresent([String].self, forKey: .asistencias) ?? []
        duracionHoras = try c.decodeIfPresent(Int.self, forKey: .duracionHoras) ?? 1
        duracionMinutos = try c.decodeIfPresent(Int.self, forKey: .duracionMinutos) ?? 0
        icono = try c.decodeIfPresent(String.self, forKey: .icono) ?? "book.fill"
        horarios = try c.decodeIfPresent([HorarioDia].self, forKey: .horarios) ?? []
        curso = try c.decodeIfPresent(Int.self, forKey: .curso) ?? 0
        aula = try c.decodeIfPresent(String.self, forKey: .aula) ?? ""
        notas = try c.decodeIfPresent(String.self, forKey: .notas) ?? ""
    }

    // TODAS las clases de un día, en orden de reloj. Una materia puede darse
    // dos o tres veces el mismo día (teoría por la mañana, laboratorio por la
    // tarde), así que aquí puede venir más de un bloque.
    public func bloques(dia: Int) -> [HorarioDia] {
        if !horarios.isEmpty {
            return horarios.filter { $0.dia == dia }
                .sorted { minutosDelDia($0) < minutosDelDia($1) }
        }
        guard diasSemana.contains(dia) else { return [] }
        return [HorarioDia(dia: dia, horario: horario,
                           duracionHoras: duracionHoras, duracionMinutos: duracionMinutos)]
    }

    // Primera clase del día (1..7). nil si la materia no se imparte ese día.
    public func bloque(dia: Int) -> HorarioDia? { bloques(dia: dia).first }

    // Todos los bloques ordenados por día y, dentro del día, por hora
    // (deriva del global si `horarios` está vacío).
    public var bloquesOrdenados: [HorarioDia] {
        // Ni ternario con closure dentro ni `self` implícito: lo primero rompe
        // al transpilador de Skip ("Syntax error: Type expected") y lo segundo
        // no se captura en Kotlin como en Swift. Comprobado el 26/09.
        var base = horarios
        if horarios.isEmpty {
            base = diasSemana.sorted().map { dia in
                HorarioDia(dia: dia, horario: self.horario,
                           duracionHoras: self.duracionHoras,
                           duracionMinutos: self.duracionMinutos)
            }
        }
        return base.sorted {
            $0.dia != $1.dia ? $0.dia < $1.dia : minutosDelDia($0) < minutosDelDia($1)
        }
    }

    // ¿Los días tienen horarios (hora de inicio o duración) distintos entre sí?
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

    public var horarioFin: Date {
        let mins = duracionHoras * 60 + duracionMinutos
        return Calendar.current.date(byAdding: .minute, value: mins, to: horario) ?? horario
    }

    // Hora de fin para un bloque concreto.
    public static func fin(de bloque: HorarioDia) -> Date {
        Calendar.current.date(byAdding: .minute, value: bloque.duracionMin, to: bloque.horario) ?? bloque.horario
    }

    public static func == (l: Materia, r: Materia) -> Bool { l.id == r.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}
