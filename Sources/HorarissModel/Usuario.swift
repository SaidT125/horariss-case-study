import Foundation

// Cómo referirse a la persona (para el saludo: Bienvenido / Bienvenida / Bienvenide)
public enum GeneroSaludo: String, Codable, CaseIterable, Sendable {
    case el, ella, nb
    public var etiqueta: String {
        switch self {
        case .el: String(localized: "Él")
        case .ella: String(localized: "Ella")
        case .nb: String(localized: "No binario")
        }
    }
    public var bienvenido: String {
        switch self {
        case .el: String(localized: "Bienvenido")
        case .ella: String(localized: "Bienvenida")
        case .nb: String(localized: "Bienvenide")
        }
    }
}

public struct Usuario: Codable, Sendable {
    public var nombre: String
    public var correo: String
    public var curso: String
    public var esPremium: Bool = false
    public var fechaFinSuscripcion: Date?
    public var fotoPerfil: Data? = nil
    public var genero: String? = nil    // "el" | "ella" | "nb" (opcional: datos viejos no lo traen)
    // Segundo curso (Premium). Opcionales para que los datos guardados antes
    // de esta función sigan decodificando sin problema.
    public var curso2: String? = nil
    public var cursoActivo: Int? = nil  // 0 = curso principal, 1 = segundo curso

    public var saludo: GeneroSaludo { GeneroSaludo(rawValue: genero ?? "") ?? .nb }
    /// Nombre del curso actualmente seleccionado
    public var nombreCursoActivo: String { (cursoActivo ?? 0) == 1 ? (curso2 ?? curso) : curso }

    public init(nombre: String, correo: String, curso: String, esPremium: Bool = false,
                fechaFinSuscripcion: Date? = nil, fotoPerfil: Data? = nil, genero: String? = nil,
                curso2: String? = nil, cursoActivo: Int? = nil) {
        self.nombre = nombre; self.correo = correo; self.curso = curso
        self.esPremium = esPremium; self.fechaFinSuscripcion = fechaFinSuscripcion
        self.fotoPerfil = fotoPerfil; self.genero = genero
        self.curso2 = curso2; self.cursoActivo = cursoActivo
    }

    // CodingKeys EXPLÍCITO. Swift lo sintetiza solo, pero el transpilador de
    // Skip no lo ve: falla con "unable to determine the owning type for member".
    // Solo las claves que el decodificador lee, que son exactamente las
    // propiedades guardadas; meter aquí una propiedad calculada rompería
    // Encodable. Comprobado en la prueba de humo del 26/09.
    private enum CodingKeys: String, CodingKey {
        case nombre, correo, curso, esPremium, fechaFinSuscripcion, fotoPerfil, genero, curso2, cursoActivo
    }

    // Decodificación tolerante, como el resto de los modelos. El decodificador
    // que sintetiza Swift NO usa los valores por omisión: si mañana se añade
    // aquí un campo no opcional, el perfil de todos los usuarios ya guardados
    // dejaría de leerse y aparecerían sin nombre ni curso.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
        correo = try c.decodeIfPresent(String.self, forKey: .correo) ?? ""
        curso = try c.decodeIfPresent(String.self, forKey: .curso) ?? ""
        esPremium = try c.decodeIfPresent(Bool.self, forKey: .esPremium) ?? false
        fechaFinSuscripcion = try c.decodeIfPresent(Date.self, forKey: .fechaFinSuscripcion)
        fotoPerfil = try c.decodeIfPresent(Data.self, forKey: .fotoPerfil)
        genero = try c.decodeIfPresent(String.self, forKey: .genero)
        curso2 = try c.decodeIfPresent(String.self, forKey: .curso2)
        cursoActivo = try c.decodeIfPresent(Int.self, forKey: .cursoActivo)
    }
}
