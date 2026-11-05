import Foundation

// ============================================================
// MARK: - UN PLAN DE PREMIUM, VENGA DE LA TIENDA QUE VENGA
// ============================================================

// El paywall no sabe de StoreKit ni de Google Play: pinta planes. Cada tienda
// traduce sus productos a esto (StoreKit en iOS, RevenueCat en Android) y el
// paywall es el mismo en las dos plataformas.
//
// Los importes van en millonésimas (`micros`), como los da Google Play, para
// hacer las cuentas con enteros: ni el Decimal de StoreKit ni un Double. Así
// no reaparece el viejo «Ahorra 0%», que salió de convertir a entero un
// Decimal de 38 dígitos.
public struct PlanPremium: Identifiable, Equatable, Sendable {
    public enum Periodo: Sendable, Equatable { case dia, semana, mes, anio }

    public struct Prueba: Sendable, Equatable {
        public let valor: Int
        public let unidad: Periodo
        public init(valor: Int, unidad: Periodo) { self.valor = valor; self.unidad = unidad }
    }

    /// El producto de la tienda (`ProductosHorariss.mensual` o `.anual`)
    public let id: String
    public let nombre: String
    /// El precio tal como lo formatea la tienda, en la moneda del usuario
    public let precio: String
    public let micros: Int64
    public let periodo: Periodo?
    /// Prueba gratis, solo si el usuario todavía puede usarla
    public let prueba: Prueba?
    /// «$33.25»: el anual dividido entre doce, formateado por la tienda
    public let equivalenteMensual: String?

    public init(id: String, nombre: String, precio: String, micros: Int64,
                periodo: Periodo?, prueba: Prueba?, equivalenteMensual: String?) {
        self.id = id; self.nombre = nombre; self.precio = precio; self.micros = micros
        self.periodo = periodo; self.prueba = prueba; self.equivalenteMensual = equivalenteMensual
    }

    public var esAnual: Bool { id == ProductosHorariss.anual }

    /// Lo que ahorra el anual frente a doce meses del mensual, en % entero y
    /// redondeado hacia abajo (nunca prometer de más). Nil si no ahorra nada.
    public static func ahorroAnual(mensual: PlanPremium?, anual: PlanPremium?) -> Int? {
        guard let m = mensual, let a = anual, m.micros > 0 else { return nil }
        let doceMeses = m.micros * 12
        guard doceMeses > a.micros else { return nil }
        let porcentaje = Int((doceMeses - a.micros) * 100 / doceMeses)
        return porcentaje > 0 ? porcentaje : nil
    }

    /// El importe mensual del anual, redondeado a centavos (la mitad hacia
    /// arriba, como `NSDecimalRound(.plain)`), en millonésimas
    public static func microsMensuales(anual micros: Int64) -> Int64 {
        let centavos = (micros * 100 + 6_000_000) / 12_000_000
        return centavos * 10_000
    }
}
