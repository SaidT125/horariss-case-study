import Foundation

// Modelo de los apuntes. Un apunte es una lista de bloques de texto —párrafos,
// títulos, viñetas, pendientes, imágenes— al estilo de las notas de Apple.
//
// Es Foundation puro: la conversión a Firestore vive en HorarissDatos y el
// editor, que sí es UIKit, se queda en la app.

public enum TipoBloqueApunte: String, Codable, CaseIterable, Sendable {
    case parrafo, titulo, vineta, numerada, pendiente, imagen

    public var icono: String {
        switch self {
        case .parrafo:   "text.alignleft"
        case .titulo:    "textformat.size"
        case .vineta:    "list.bullet"
        case .numerada:  "list.number"
        case .pendiente: "checklist"
        case .imagen:    "photo"
        }
    }
    // `nombre` devuelve LocalizedStringKey, que es de SwiftUI: está en HorarissUI.
    /// Tipos que continúan solos al dar Enter, como en cualquier editor
    public var esLista: Bool { self == .vineta || self == .numerada || self == .pendiente }
}

public struct BloqueApunte: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID = UUID()
    public var tipo: TipoBloqueApunte = .parrafo
    public var texto: String = ""
    /// Solo para `.pendiente`
    public var marcado: Bool = false
    /// Solo para `.imagen`: nombre del archivo dentro de la carpeta de fotos
    public var foto: String = ""
    /// Estilos de carácter, aplanados de tres en tres: inicio, largo, máscara.
    /// Los desplazamientos van en UTF-16 porque es lo que usa `NSRange`, que es
    /// con lo que trabaja el editor; contarlos a la manera de Swift desfasaría
    /// el formato en cuanto apareciera un emoji.
    /// Un bloque sin formato guarda un arreglo vacío y ni siquiera viaja a
    /// Firestore, así que los apuntes escritos en la 1.4 no crecen ni un byte.
    public var formato: [Int] = []

    public init(id: UUID = UUID(), tipo: TipoBloqueApunte = .parrafo,
         texto: String = "", marcado: Bool = false, foto: String = "",
         formato: [Int] = []) {
        self.id = id; self.tipo = tipo; self.texto = texto
        self.marcado = marcado; self.foto = foto; self.formato = formato
    }

    // Decodificación tolerante: un tipo de bloque desconocido (por ejemplo uno
    // añadido en una versión futura) se degrada a párrafo en vez de tirar todo
    // el apunte.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        tipo = TipoBloqueApunte(rawValue: try c.decodeIfPresent(String.self, forKey: .tipo) ?? "") ?? .parrafo
        texto = try c.decodeIfPresent(String.self, forKey: .texto) ?? ""
        marcado = try c.decodeIfPresent(Bool.self, forKey: .marcado) ?? false
        foto = try c.decodeIfPresent(String.self, forKey: .foto) ?? ""
        formato = try c.decodeIfPresent([Int].self, forKey: .formato) ?? []
    }
    enum CodingKeys: String, CodingKey { case id, tipo, texto, marcado, foto, formato }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(tipo.rawValue, forKey: .tipo)
        try c.encode(texto, forKey: .texto)
        try c.encode(marcado, forKey: .marcado)
        try c.encode(foto, forKey: .foto)
        if !formato.isEmpty { try c.encode(formato, forKey: .formato) }
    }

    public var diccionario: [String: Any] {
        var d: [String: Any] = ["id": id.uuidString, "tipo": tipo.rawValue,
                                "texto": texto, "marcado": marcado, "foto": foto]
        if !formato.isEmpty { d["formato"] = formato }
        return d
    }
    // Asigna cada propiedad en vez de delegar en `self.init(...)`: un
    // constructor secundario de Kotlin no puede usar variables locales en la
    // llamada delegada, y aquí `id` sale de un `guard`.
    public init?(diccionario d: [String: Any]) {
        guard let s = d["id"] as? String, let id = UUID(uuidString: s) else { return nil }
        self.id = id
        tipo = TipoBloqueApunte(rawValue: d["tipo"] as? String ?? "") ?? .parrafo
        texto = d["texto"] as? String ?? ""
        marcado = d["marcado"] as? Bool ?? false
        foto = d["foto"] as? String ?? ""
        // Uno a uno y con `Nube`: en iOS llegan como NSNumber y en Android
        // como Long de Java; con un cast directo el arreglo se perdía.
        formato = Nube.enteros(d["formato"]) ?? []
    }
}

public struct Apunte: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var materiaId: UUID
    public var titulo: String = ""
    public var bloques: [BloqueApunte] = []
    public var creado: Date = Date()
    public var editado: Date = Date()
    public var curso: Int = 0

    /// Topes. 5.000 caracteres son unas 800 palabras (una clase entera) y dejan
    /// cada documento de Firestore por debajo de ~8 KB, que es lo que mantiene
    /// baratas las lecturas.
    public static let maxCaracteres = 5_000
    public static let maxPorMateria = 200
    /// Apuntes nuevos al mes sin Premium
    public static let gratisPorMes  = 5

    public init(id: UUID = UUID(), materiaId: UUID, titulo: String = "",
         bloques: [BloqueApunte] = [], creado: Date = Date(),
         editado: Date = Date(), curso: Int = 0) {
        self.id = id; self.materiaId = materiaId; self.titulo = titulo
        self.bloques = bloques; self.creado = creado; self.editado = editado
        self.curso = curso
    }

    /// En unidades UTF-16, las mismas que usa el editor. Con `String.count` un
    /// emoji contaba 1 aquí y 11 en `NSRange`, y el tope se desfasaba.
    public var caracteres: Int { bloques.reduce(0) { $0 + $1.texto.utf16.count } }
    public var fotos: [String] { bloques.filter { $0.tipo == .imagen && !$0.foto.isEmpty }.map(\.foto) }
    /// Un apunte que es solo una foto: se dibuja como la burbuja de imagen de
    /// WhatsApp, sin cuerpo de texto.
    public var esSoloFoto: Bool { bloques.count == 1 && bloques[0].tipo == .imagen }
    /// Vista previa que se enseña en la burbuja de la conversación
    public var resumen: String {
        bloques
            .filter { $0.tipo != .imagen }
            .map { $0.texto.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
    public var vacio: Bool { resumen.isEmpty && fotos.isEmpty }

    /// Título por defecto: "Apunte 5 de septiembre de 2026". Sigue el idioma y
    /// la región del dispositivo (nada de locales fijos).
    public static func tituloPorFecha(_ f: Date = Date()) -> String {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .none
        return String(localized: "Apunte \(df.string(from: f))")
    }
}
