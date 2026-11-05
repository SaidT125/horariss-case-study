import SwiftUI
import HorarissModel

// El color de una materia o de una hora propia es presentación, no dato: por eso
// `HorarissModel` guarda solo el hex y no sabe nada de SwiftUI. Derivar el Color
// es cosa de esta capa, y va aquí —y no en la app— porque es SwiftUI puro y
// portable tal cual.
//
// Las 57 llamadas a `.color` repartidas por las vistas no notan la diferencia:
// una extensión es transparente para quien la llama.
//
// No hace falta marcarlas `nonisolated`: dentro del paquete no rige el
// SWIFT_DEFAULT_ACTOR_ISOLATION del objetivo de la app, así que ya lo son. Eso
// importa porque el generador de PDF las usa fuera del hilo principal.

public extension Materia {
    var color: Color { Color.hex(colorHex) }
}

public extension CatalogoHoras {
    /// Color adaptativo del gris guardado (si no se reconoce, se usa tal cual).
    static func colorEstudio(_ hex: String) -> Color {
        // Minúsculas en vez de `caseInsensitiveCompare`, que el `String` de Skip
        // no tiene. Para un hex, que es ASCII, las dos comparaciones son la misma.
        if let par = grisesEstudio.first(where: { $0.claro.lowercased() == hex.lowercased() }) {
            return Color.adaptativo(par.colorSet)
        }
        return Color.hex(hex)
    }
}

public extension HoraPersonal {
    /// Color de la tarjeta. Las horas de estudio usan grises adaptativos
    /// (un hex fijo se vería mal en uno de los dos modos).
    var color: Color {
        tipo == .estudio ? CatalogoHoras.colorEstudio(colorHex) : Color.hex(colorHex)
    }
    /// Color para el PDF: SIEMPRE la variante clara. El PDF se imprime sobre
    /// blanco, así que no debe seguir la apariencia del sistema.
    var colorPDF: Color { Color.hex(colorHex) }
}

// `LocalizedStringKey` es de SwiftUI, así que el nombre visible del tipo de
// bloque no puede vivir en el modelo. Misma razón que los colores de arriba.
public extension TipoBloqueApunte {
    // Cada literal va envuelto: en Swift se convierte solo en
    // `LocalizedStringKey` por el tipo de retorno, pero en Kotlin se queda como
    // `String` y no compila.
    var nombre: LocalizedStringKey {
        switch self {
        case .parrafo:   LocalizedStringKey("Texto")
        case .titulo:    LocalizedStringKey("Título")
        case .vineta:    LocalizedStringKey("Lista")
        case .numerada:  LocalizedStringKey("Numerada")
        case .pendiente: LocalizedStringKey("Pendiente")
        case .imagen:    LocalizedStringKey("Foto")
        }
    }
}

public extension ClaseDeHoy {
    /// Color de la tarjeta: el de la materia o el de la hora propia, según toque.
    var color: Color {
        switch origen {
        case .materia(let m): m.color
        case .hora(let h):    h.color
        }
    }
}
