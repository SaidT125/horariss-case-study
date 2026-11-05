import Testing
import Foundation
@testable import HorarissServicios

// Las cuentas del paywall. Las dos tiendas las hacen con estas funciones, así
// que un error aquí es un «Ahorra 0%» o un precio mensual equivocado en las
// dos plataformas a la vez, justo en el momento de pagar.
@Suite("Cuentas del paywall")
struct PlanPremiumTests {

    private func plan(_ id: String, _ pesos: Double) -> PlanPremium {
        PlanPremium(id: id, nombre: "", precio: "", micros: Int64(pesos * 1_000_000),
                    periodo: nil, prueba: nil, equivalenteMensual: nil)
    }

    @Test("Con los precios reales (49 al mes, 399 al año) el anual ahorra 32%")
    func ahorroReal() {
        let m = plan(ProductosHorariss.mensual, 49)
        let a = plan(ProductosHorariss.anual, 399)
        #expect(PlanPremium.ahorroAnual(mensual: m, anual: a) == 32)
    }

    @Test("El ahorro se redondea hacia abajo: nunca promete de más")
    func ahorroHaciaAbajo() {
        // 12 × 10 = 120; 120 − 80 = 40; 40/120 = 33.33…% → 33
        #expect(PlanPremium.ahorroAnual(mensual: plan(ProductosHorariss.mensual, 10),
                                        anual: plan(ProductosHorariss.anual, 80)) == 33)
    }

    @Test("Si el anual no ahorra nada, no se anuncia ahorro")
    func sinAhorro() {
        #expect(PlanPremium.ahorroAnual(mensual: plan(ProductosHorariss.mensual, 10),
                                        anual: plan(ProductosHorariss.anual, 120)) == nil)
        #expect(PlanPremium.ahorroAnual(mensual: plan(ProductosHorariss.mensual, 10),
                                        anual: plan(ProductosHorariss.anual, 119.5)) == nil)
        #expect(PlanPremium.ahorroAnual(mensual: nil, anual: plan(ProductosHorariss.anual, 1)) == nil)
    }

    @Test("Precios con centavos no dan un ahorro absurdo")
    func ahorroConCentavos() {
        // 12 × 4.99 = 59.88; (59.88 − 39.99)/59.88 = 33.21…% → 33
        #expect(PlanPremium.ahorroAnual(mensual: plan(ProductosHorariss.mensual, 4.99),
                                        anual: plan(ProductosHorariss.anual, 39.99)) == 33)
    }

    @Test("El anual entre doce se redondea a centavos, la mitad hacia arriba")
    func mensualizado() {
        #expect(PlanPremium.microsMensuales(anual: 399_000_000) == 33_250_000)   // 33.25
        #expect(PlanPremium.microsMensuales(anual: 39_990_000) == 3_330_000)     // 3.3325 → 3.33
        #expect(PlanPremium.microsMensuales(anual: 100_000_000) == 8_330_000)    // 8.333… → 8.33
        #expect(PlanPremium.microsMensuales(anual: 1_000_000) == 80_000)         // 0.08333… → 0.08
        #expect(PlanPremium.microsMensuales(anual: 1_020_000) == 90_000)         // 0.085 → 0.09
    }
}
