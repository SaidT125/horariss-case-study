import Foundation

// Nombres de días localizados (evitan repetir los arreglos en cada vista)
public func diasLetrasLoc() -> [String] {
    [String(localized: "Lu"), String(localized: "Ma"), String(localized: "Mi"),
     String(localized: "Ju"), String(localized: "Vi"), String(localized: "Sa"), String(localized: "Do")]
}
public func diasNombresLoc() -> [String] {
    ["", String(localized: "Lunes"), String(localized: "Martes"), String(localized: "Miércoles"),
     String(localized: "Jueves"), String(localized: "Viernes"), String(localized: "Sábado"), String(localized: "Domingo")]
}
