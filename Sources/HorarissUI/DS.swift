import SwiftUI

/// Los tokens de diseño de Horariss.
///
/// Regla de oro del proyecto: casi nada se inventa. Antes de crear un color, una
/// fuente o un radio, hay que buscar si ya está aquí.
///
/// **Qué NO está aquí:** las versiones `UIFont` (`DS.interUI`). Son de UIKit y
/// las usa únicamente el generador de PDF, así que viven con él en la app. Ese
/// es el corte que deja este módulo compilable para Android: todo lo de aquí es
/// SwiftUI puro.
public enum DS {
    // Tokens adaptativos: claro / oscuro. En oscuro el fondo es negro con
    // tarjetas en gris (petición del usuario: "fondo negro, con matices en gris").
    public static let fondo           = Color.adaptativo("fondo")
    public static let fondoTarjeta    = Color.adaptativo("fondoTarjeta")
    public static let azulCielo       = Color.hex("88BAE8")
    public static let rosaPolvo       = Color.hex("EFC3CB")
    public static let textoPrimario   = Color.adaptativo("textoPrimario")
    public static let textoSecundario = Color.adaptativo("textoSecundario")
    public static let separador       = Color.adaptativo("separador")
    // Texto que va ENCIMA de un fondo textoPrimario (botones y chips
    // seleccionados): como ese fondo se invierte con el modo, este también.
    public static let textoInvertido  = Color.adaptativo("textoInvertido")

    // Degradado IA naranja
    public static let gradienteIA = LinearGradient(
        colors: [Color.hex("FF9A44"), Color.hex("FF5619")],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // Degradado morado — FAB y botón añadir tarea
    public static let gradientePurpura = LinearGradient(
        colors: [Color.hex("672EFF"), Color.hex("A294F9")],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // Color Premium: el naranja EXACTO del logo (LogoNaranja.png), para que el
    // muro de pago sea del mismo color que la marca que lo encabeza.
    public static let colorPremium = Color.hex("FFAF55")
    // Naranja más oscuro para los botones de acción "Suscribirme" (mejor contraste con texto blanco)
    public static let naranjaBoton = Color.hex("E8850C")

    public static let pasteles: [(Color, String)] = [
        (Color.hex("7DA2FF"), "7DA2FF"),
        (Color.hex("63D2B1"), "63D2B1"),
        (Color.hex("FFD23F"), "FFD23F"),
        (Color.hex("FF8A8A"), "FF8A8A"),
        (Color.hex("7B61FF"), "7B61FF"),
        (Color.hex("B69CFF"), "B69CFF"),
        (Color.hex("FF9FCB"), "FF9FCB"),
        (Color.hex("8FD6A3"), "8FD6A3"),
        (Color.hex("7CC7FF"), "7CC7FF"),
        (Color.hex("FFB36B"), "FFB36B"),
        (Color.hex("5EDCE2"), "5EDCE2"),
        (Color.hex("AFA7E8"), "AFA7E8"),
        (Color.hex("FF6B73"), "FF6B73"),
        (Color.hex("42C98F"), "42C98F"),
        (Color.hex("5B7CFA"), "5B7CFA"),
        (Color.hex("F6C453"), "F6C453"),
    ]

    // Nombres de SF Symbol. En Android no existen: hay que exportar cada uno
    // como SVG al formato .symbolset (lo cubre la skill skip-icons).
    public static let iconosMateria: [String] = [
        "book.fill", "books.vertical.fill", "function", "atom",
        "compass.drawing", "cube.fill", "paintpalette.fill", "music.note",
        "globe.americas.fill", "desktopcomputer", "pencil.and.ruler.fill", "leaf.fill",
        "building.columns.fill", "person.2.fill", "scalemass.fill", "theatermasks.fill",
        "chart.bar.fill", "stethoscope", "hammer.fill", "gamecontroller.fill"
    ]

    public static let radio: CGFloat = 18
    public static let radioMini: CGFloat = 12

    // Tipografía Inter — nombres PostScript de las fuentes estáticas incluidas.
    // El registro de las fuentes se queda en la app: se hace con
    // CTFontManagerRegisterFontsForURL en ámbito .process, así que vale para
    // todo el proceso y `Font.custom` resuelve igual desde aquí.
    public static func inter(_ s: CGFloat, _ w: Font.Weight = .regular) -> Font {
        .custom(nombreInter(w), size: s)
    }

    /// El archivo de Inter de cada peso. Aparte de `inter` porque medir un
    /// texto (MedirTexto) necesita la misma fuente que dibuja SwiftUI.
    public static func nombreInter(_ w: Font.Weight) -> String {
        switch w {
        case .bold, .heavy, .black:  return "Inter18pt-Bold"
        case .semibold:              return "Inter18pt-SemiBold"
        case .medium:                return "Inter18pt-Medium"
        default:                     return "Inter18pt-Regular"
        }
    }

    public static func titulo(_ s: CGFloat = 28) -> Font { inter(s, .bold) }
    public static func cuerpo(_ s: CGFloat = 15) -> Font { inter(s, .regular) }
    public static func etiqueta(_ s: CGFloat = 12) -> Font { inter(s, .medium) }
    public static func semibold(_ s: CGFloat = 15) -> Font { inter(s, .semibold) }

    // El markdown de AttributedString (MarkdownParsingOptions,
    // inlinePresentationIntent) no existe en Skip, y AttributedString tampoco
    // tiene `.font` allí. En Android el texto sale sin negritas: se pierde el
    // resalte, no el contenido. Comprobado en la prueba de humo del 26/09.
#if !SKIP && !os(Android)
    // Convierte markdown de negritas (**texto**) a AttributedString con Inter.
    // Lo que va entre ** ** se muestra en Inter Bold; el resto en Inter Regular.
    public static func conNegritas(_ texto: String, tam: CGFloat = 15) -> AttributedString {
        let opciones = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard var attr = try? AttributedString(markdown: texto, options: opciones) else {
            var plano = AttributedString(texto)
            plano.font = inter(tam, .regular)
            return plano
        }
        // Se calculan los rangos primero para no invalidar la colección al mutar.
        let rangos = attr.runs.map {
            ($0.range, $0.inlinePresentationIntent?.contains(.stronglyEmphasized) ?? false)
        }
        for (rango, esNegrita) in rangos {
            attr[rango].font = inter(tam, esNegrita ? .bold : .regular)
        }
        return attr
    }#else
    public static func conNegritas(_ texto: String, tam: CGFloat = 15) -> AttributedString {
        AttributedString(texto.replacingOccurrences(of: "**", with: ""))
    }
#endif

}
