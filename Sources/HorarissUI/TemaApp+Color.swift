import SwiftUI
import HorarissModel

// Los colores del tema del usuario. El enum vive en HorarissModel; esto es
// lo que lo pinta.
//
// Al ponerlos en botones de acción principal, usa `estado.tema.gradiente` y
// `estado.tema.colorShadowFAB` en vez de un color fijo: es lo que hace que el
// tema elegido se note.
public extension TemaApp {

    var fondoBase: Color {
        switch self {
        case .rosa:   return Color.hex("FFD9E8")
        case .azul:   return Color.hex("D9ECFF")
        case .verde:  return Color.hex("D9F5E8")
        case .morado: return Color.hex("EDD9FF")
        }
    }
    var blob1: Color {
        switch self {
        case .rosa:   return Color.hex("FF8FB8")
        case .azul:   return Color.hex("8FC4FF")
        case .verde:  return Color.hex("6FCFA0")
        case .morado: return Color.hex("B88FFF")
        }
    }
    var blob2: Color {
        switch self {
        case .rosa:   return Color.hex("FF6FA0")
        case .azul:   return Color.hex("6FAAFF")
        case .verde:  return Color.hex("50B882")
        case .morado: return Color.hex("9B6FFF")
        }
    }
    var blob3: Color {
        switch self {
        case .rosa:   return Color.hex("FFB3CC")
        case .azul:   return Color.hex("B3D4FF")
        case .verde:  return Color.hex("A0DEBB")
        case .morado: return Color.hex("CCB3FF")
        }
    }
    var gradiente: LinearGradient {
        switch self {
        case .morado: return LinearGradient(colors: [Color.hex("672EFF"), Color.hex("A294F9")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rosa:   return LinearGradient(colors: [Color.hex("DE58C7"), Color.hex("F9ACD8")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .azul:   return LinearGradient(colors: [Color.hex("3390D7"), Color.hex("9CDCF9")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .verde:  return LinearGradient(colors: [Color.hex("6DC130"), Color.hex("C1F995")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    /// Deriva del hex que guarda el modelo, para no repetir el valor.
    var colorShadowFAB: Color { Color.hex(hexAcento) }
}
