import Testing
import Foundation
@testable import HorarissModel

// Lo que llega de Firestore en iOS: números envueltos en NSNumber dentro de
// arreglos y mapas de `Any`. La rama de Android (Long de Java) no corre aquí;
// estas pruebas fijan que en iOS `Nube` da lo mismo que los casts de siempre.
@Suite("Números de la nube")
struct NubeTests {

    @Test("Un entero de Firestore se lee igual que con as? Int")
    func entero() {
        #expect(Nube.entero(NSNumber(value: 3)) == 3)
        #expect(Nube.entero(5) == 5)
        #expect(Nube.entero("5") == nil)
        #expect(Nube.entero(nil) == nil)
    }

    @Test("Una fecha guardada en segundos se lee como decimal")
    func decimal() {
        #expect(Nube.decimal(NSNumber(value: 1_727_700_000.5)) == 1_727_700_000.5)
        #expect(Nube.decimal("x") == nil)
    }

    @Test("Los días de una materia llegan completos")
    func enteros() {
        let dias: [Any] = [NSNumber(value: 1), NSNumber(value: 3), NSNumber(value: 5)]
        #expect(Nube.enteros(dias) == [1, 3, 5])
        #expect(Nube.enteros(nil) == nil)
    }

    @Test("Un elemento que no es número no tira el arreglo entero")
    func enterosMixtos() {
        let mezcla: [Any] = [NSNumber(value: 2), "martes", NSNumber(value: 4)]
        #expect(Nube.enteros(mezcla) == [2, 4])
    }

    @Test("Los contadores por mes se leen con sus claves")
    func contadores() {
        let uso: [String: Any] = ["2026-09": NSNumber(value: 4), "2026-10": NSNumber(value: 1)]
        #expect(Nube.contadores(uso) == ["2026-09": 4, "2026-10": 1])
        #expect(Nube.contadores("nada") == nil)
    }
}
