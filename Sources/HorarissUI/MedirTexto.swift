import SwiftUI
#if canImport(UIKit) && !SKIP
import UIKit
#endif

// Medir un texto con la tipografía de la app, para las vistas cuyo diseño
// depende de si un texto cabe: el renglón de las clases de hoy desvanece el
// nombre solo cuando se sale.
//
// En iOS mide UIFont, que es lo que dibuja SwiftUI. En Android mide `Paint`
// con el mismo archivo de Inter que carga SkipUI (res/font), y el tamaño va
// multiplicado por la escala de letra del sistema porque SkipUI dibuja en sp.
// Las dos dan puntos (dp en Android), la unidad del GeometryReader.
public enum MedirTexto {

    public static func ancho(_ texto: String, tamano: CGFloat, peso: Font.Weight) -> CGFloat {
        #if SKIP
        return Double(pintura(tamano, peso).measureText(texto))
        #elseif canImport(UIKit)
        return (texto as NSString).size(withAttributes: [.font: fuente(tamano, peso)]).width
        #else
        return 0
        #endif
    }

    public static func altoLinea(tamano: CGFloat, peso: Font.Weight) -> CGFloat {
        #if SKIP
        return Double(pintura(tamano, peso).fontSpacing)
        #elseif canImport(UIKit)
        return fuente(tamano, peso).lineHeight
        #else
        return tamano
        #endif
    }

    #if SKIP
    /// Las fuentes ya cargadas, por archivo: leerlas de los recursos en cada
    /// medida sería leer un archivo por renglón y por fotograma.
    private static var cargadas: [String: android.graphics.Typeface] = [:]

    private static func pintura(_ tamano: CGFloat, _ peso: Font.Weight) -> android.graphics.Paint {
        let contexto = ProcessInfo.processInfo.androidContext
        // Mismo nombre que busca SkipUI: en minúsculas y con guion bajo
        let archivo = DS.nombreInter(peso).lowercased().replacingOccurrences(of: "-", with: "_")
        var tipo = cargadas[archivo]
        if tipo == nil {
            let id = contexto.resources.getIdentifier(archivo, "font", contexto.packageName)
            tipo = id != 0 ? contexto.resources.getFont(id) : android.graphics.Typeface.DEFAULT
            cargadas[archivo] = tipo
        }
        let p = android.graphics.Paint()
        p.typeface = tipo
        p.textSize = Float(tamano * Double(contexto.resources.configuration.fontScale))
        return p
    }
    #elseif canImport(UIKit)
    private static func fuente(_ tamano: CGFloat, _ peso: Font.Weight) -> UIFont {
        UIFont(name: DS.nombreInter(peso), size: tamano) ?? .systemFont(ofSize: tamano)
    }
    #endif
}
