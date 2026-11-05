import Foundation

// Horario de un día concreto: hora de inicio + duración propias.
// Permite que una misma materia tenga días distintos con horas/duraciones distintas.
public struct HorarioDia: Codable, Equatable, Hashable, Sendable {
    public var dia: Int                 // 1 = Lunes … 7 = Domingo
    public var horario: Date            // solo importan hora y minuto
    public var duracionHoras: Int = 1
    public var duracionMinutos: Int = 0
    // Aula propia de ESTE día. Vacía = se usa la de la materia (Materia.aula).
    public var aula: String = ""
    public var duracionMin: Int { duracionHoras * 60 + duracionMinutos }

    // Decodificación tolerante: los bloques guardados antes de esta función
    // no traen "aula" y no deben perderse.
    public init(dia: Int, horario: Date, duracionHoras: Int = 1, duracionMinutos: Int = 0, aula: String = "") {
        self.dia = dia; self.horario = horario
        self.duracionHoras = duracionHoras; self.duracionMinutos = duracionMinutos
        self.aula = aula
    }
    // CodingKeys EXPLÍCITO. Swift lo sintetiza solo, pero el transpilador de
    // Skip no lo ve: falla con "unable to determine the owning type for member".
    // Solo las claves que el decodificador lee, que son exactamente las
    // propiedades guardadas; meter aquí una propiedad calculada rompería
    // Encodable. Comprobado en la prueba de humo del 26/09.
    private enum CodingKeys: String, CodingKey {
        case dia, horario, duracionHoras, duracionMinutos, aula
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dia = try c.decode(Int.self, forKey: .dia)
        horario = try c.decode(Date.self, forKey: .horario)
        duracionHoras = try c.decodeIfPresent(Int.self, forKey: .duracionHoras) ?? 1
        duracionMinutos = try c.decodeIfPresent(Int.self, forKey: .duracionMinutos) ?? 0
        aula = try c.decodeIfPresent(String.self, forKey: .aula) ?? ""
    }
}
