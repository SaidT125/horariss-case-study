import Testing
import Foundation
@testable import HorarissServicios

// Cuándo suena un aviso semanal. Lo usan las dos plataformas: iOS se lo pasa al
// sistema y Android arma con él cada alarma. Un error aquí es un aviso que
// suena el día equivocado, y nadie lo nota hasta que falta a clase.
@Suite("Disparos de los avisos")
struct DisparosTests {

    /// Una hora de hoy, en el calendario local (las pruebas no fijan zona)
    private func hora(_ h: Int, _ m: Int) -> Date {
        Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date())!
    }

    /// Una fecha concreta en el calendario local
    private func fecha(_ a: Int, _ mes: Int, _ d: Int, _ h: Int, _ m: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: a, month: mes, day: d, hour: h, minute: m))!
    }

    @Test("Resta la anticipación y pasa al día de la semana de Calendar")
    func anticipacionNormal() {
        // Martes (2 en la app) a las 8:00 con 10 minutos → martes (3 en Calendar) 7:50
        #expect(disparoSemanal(dia: 2, horario: hora(8, 0), anticipacion: 10)
                == DisparoSemanal(diaSemana: 3, hora: 7, minuto: 50))
    }

    @Test("Si la anticipación cruza la medianoche, suena el día anterior")
    func cruzaMedianoche() {
        // Martes 0:05 → lunes 23:55
        #expect(disparoSemanal(dia: 2, horario: hora(0, 5), anticipacion: 10)
                == DisparoSemanal(diaSemana: 2, hora: 23, minuto: 55))
        // Lunes 0:05 → domingo 23:55
        #expect(disparoSemanal(dia: 1, horario: hora(0, 5), anticipacion: 10)
                == DisparoSemanal(diaSemana: 1, hora: 23, minuto: 55))
        // Domingo (7 en la app, 1 en Calendar) 0:05 → sábado (7) 23:55
        #expect(disparoSemanal(dia: 7, horario: hora(0, 5), anticipacion: 10)
                == DisparoSemanal(diaSemana: 7, hora: 23, minuto: 55))
    }

    @Test("Un día fuera de 1…7 no programa nada")
    func diaInvalido() {
        #expect(disparoSemanal(dia: 0, horario: hora(8, 0), anticipacion: 0) == nil)
        #expect(disparoSemanal(dia: 8, horario: hora(8, 0), anticipacion: 0) == nil)
    }

    @Test("El próximo disparo es hoy si aún no pasa, y si no, la semana que viene")
    func proximo() {
        let martes15 = fecha(2026, 9, 29, 15, 0)   // martes 29/09/2026
        // Hoy más tarde
        #expect(proximoDisparo(DisparoSemanal(diaSemana: 3, hora: 16, minuto: 0), desde: martes15)
                == fecha(2026, 9, 29, 16, 0))
        // Hoy, pero ya pasó: el martes siguiente
        #expect(proximoDisparo(DisparoSemanal(diaSemana: 3, hora: 14, minuto: 0), desde: martes15)
                == fecha(2026, 10, 6, 14, 0))
        // Justo ahora cuenta como pasado: nunca se arma una alarma en el instante actual
        #expect(proximoDisparo(DisparoSemanal(diaSemana: 3, hora: 15, minuto: 0), desde: martes15)
                == fecha(2026, 10, 6, 15, 0))
        // Mañana miércoles
        #expect(proximoDisparo(DisparoSemanal(diaSemana: 4, hora: 7, minuto: 30), desde: martes15)
                == fecha(2026, 9, 30, 7, 30))
        // El lunes siguiente
        #expect(proximoDisparo(DisparoSemanal(diaSemana: 2, hora: 9, minuto: 0), desde: martes15)
                == fecha(2026, 10, 5, 9, 0))
    }
}
