import Foundation

// ============================================================
// MARK: - NÚMEROS QUE LLEGAN DE LA NUBE
// ============================================================

// Firestore entrega los campos de un documento como `Any`. En iOS los números
// llegan como NSNumber, y `as? Int` o `as? [Int]` los convierten. En Android
// llegan como `Long` de Java, y ahí esos mismos casts fallan de dos maneras:
//  - `as? Int` da nil sin avisar, y se usa el valor por omisión (una materia
//    de dos horas volvía como de una, y sus bloques se perdían);
//  - `as? [Int]` o `as? [String: Int]` «pasan» sin revisar los elementos, y la
//    app se cierra al usar el primero (ClassCastException). Pasó con los días
//    de las materias la primera vez que bajaron de Firestore en Android.
// Todo número leído de un documento pasa por aquí. En iOS hacen lo mismo que
// el cast de siempre.
public enum Nube {
    public static func entero(_ valor: Any?) -> Int? {
        #if SKIP
        return (valor as? kotlin.Number)?.toInt()
        #else
        return valor as? Int
        #endif
    }

    public static func decimal(_ valor: Any?) -> Double? {
        #if SKIP
        return (valor as? kotlin.Number)?.toDouble()
        #else
        return valor as? Double
        #endif
    }

    /// Un arreglo de enteros, convertido uno a uno
    public static func enteros(_ valor: Any?) -> [Int]? {
        guard let lista = valor as? [Any] else { return nil }
        return lista.compactMap { entero($0) }
    }

    /// Un mapa de contadores, como el uso de apuntes por mes
    public static func contadores(_ valor: Any?) -> [String: Int]? {
        guard let mapa = valor as? [String: Any] else { return nil }
        var resultado: [String: Int] = [:]
        for (clave, v) in mapa {
            if let n = entero(v) { resultado[clave] = n }
        }
        return resultado
    }
}
