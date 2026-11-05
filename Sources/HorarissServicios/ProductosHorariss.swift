import Foundation

// ⚠️ Deben coincidir EXACTAMENTE con los productos creados en App Store Connect.
//
// Viven en el módulo de servicios y no en el de modelos porque son la frontera
// con la tienda, no datos del usuario. En Android estos identificadores se
// reemplazan por los de Google Play, que no tienen por qué llamarse igual.
public enum ProductosHorariss {
    public static let mensual = "com.yuna.horariss.premium.mensual"
    public static let anual   = "com.yuna.horariss.premium.anual"
    public static let todos   = [mensual, anual]
}
