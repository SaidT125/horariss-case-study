import SwiftUI

// Ayudantes puros de color: no tocan la interfaz, así que pueden usarse también
// fuera del hilo principal (p. ej. al generar el PDF o sincronizar).
public extension Color {
    /// Color a partir de un hex de 6 dígitos.
    ///
    /// Función estática y NO inicializador: Skip no deja añadir constructores a
    /// un tipo definido en otro módulo, y `Color` es de SwiftUI. Tampoco usa
    /// `Scanner` ni `Int(_:radix:)` ni tipos sin signo, que tampoco cruzan.
    /// Todo comprobado en la prueba de humo del 26/09.
    static func hex(_ hexString: String) -> Color {
        let limpio = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        let digitos = "0123456789ABCDEF"
        var v = 0
        for c in limpio.uppercased() {
            guard let i = digitos.firstIndex(of: c) else { continue }
            v = v * 16 + digitos.distance(from: digitos.startIndex, to: i)
        }
        return Color(red: Double((v >> 16) & 0xFF) / 255,
                     green: Double((v >> 8) & 0xFF) / 255,
                     blue:  Double(v & 0xFF) / 255)
    }

    /// Color adaptativo, definido como color set en `Colores.xcassets`.
    ///
    /// Antes esto se construía con `UIColor { trait in … }`, que es la única
    /// forma de tener un UIColor dinámico. Se cambió porque ese inicializador no
    /// existe fuera de Apple: el shim de UIColor de SkipUI solo trae
    /// `init(red:green:blue:alpha:)`. El catálogo de recursos sí funciona en las
    /// dos plataformas —SkipUI decodifica las apariencias `luminosity`/`dark` y
    /// elige según el colorScheme— y además es lo idiomático en SwiftUI.
    static func adaptativo(_ nombre: String) -> Color {
        // `bundle:` es obligatorio: el catálogo vive en este módulo, no en el
        // bundle principal. Skip además lo exige siempre, porque usa recursos
        // por módulo en vez de Bundle.main.
        Color(nombre, bundle: .module)
    }
}

/// Acceso al bundle del módulo desde fuera (las pruebas lo necesitan para
/// buscar los color sets, que ya no están en el bundle principal).
public enum RecursosUI {
    public static let bundle = Bundle.module
}
