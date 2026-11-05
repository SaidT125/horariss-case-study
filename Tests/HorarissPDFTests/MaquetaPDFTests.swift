import Testing
import Foundation
@testable import HorarissPDF
import HorarissModel

// El reparto en carriles es lo más delicado del PDF y hasta ahora no tenía
// ninguna prueba: vivía dentro de una función de 361 líneas mezclado con el
// dibujo, así que no había forma de ejercitarlo sin generar un PDF entero.
@Suite("Maqueta del PDF")
struct MaquetaPDFTests {

    static func hora(_ h: Int, _ m: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 2,
                                                   hour: h, minute: m))!
    }

    static func materia(_ nombre: String, dia: Int, _ h: Int, _ m: Int = 0,
                        horas: Int = 1, minutos: Int = 0, aula: String = "") -> Materia {
        Materia(nombre: nombre, horario: hora(h, m), colorHex: "7DA2FF",
                horarios: [HorarioDia(dia: dia, horario: hora(h, m),
                                      duracionHoras: horas, duracionMinutos: minutos)],
                aula: aula)
    }

    @Test("Sin traslapes, todos van en el carril 0 y a lo ancho")
    func sinTraslapes() {
        let m = MaquetaPDF(materias: [
            Self.materia("A", dia: 1, 8),
            Self.materia("B", dia: 1, 10),   // empieza después de que acabe A
            Self.materia("C", dia: 2, 8),    // otro día
        ])
        #expect(m.bloques.count == 3)
        #expect(m.bloques.allSatisfy { $0.carril == 0 })
        #expect(m.bloques.allSatisfy { $0.carriles == 1 })
    }

    @Test("Dos clases a la misma hora se parten el ancho")
    func dosTraslapadas() {
        let m = MaquetaPDF(materias: [
            Self.materia("A", dia: 1, 8),
            Self.materia("B", dia: 1, 8),
        ])
        #expect(Set(m.bloques.map(\.carril)) == [0, 1])
        #expect(m.bloques.allSatisfy { $0.carriles == 2 })
    }

    @Test("El traslape encadenado mete a los tres en el mismo grupo")
    func encadenado() {
        // A 8:00-10:00 · B 9:00-10:00 · C 9:30-10:30
        // C no pisa a B en su arranque pero sí a A: los tres van juntos.
        let m = MaquetaPDF(materias: [
            Self.materia("A", dia: 1, 8, horas: 2),
            Self.materia("B", dia: 1, 9),
            Self.materia("C", dia: 1, 9, 30),
        ])
        #expect(m.bloques.allSatisfy { $0.carriles == 3 },
                "si el grupo se cortara, alguno tendría menos carriles")
        #expect(Set(m.bloques.map(\.carril)) == [0, 1, 2])
    }

    @Test("Un carril se reutiliza cuando queda libre")
    func carrilSeReutiliza() {
        // A 8:00-11:00 (largo) · B 8:00-9:00 · C 9:00-10:00
        // C cabe donde estaba B: debe reusar su carril, no abrir un tercero.
        let m = MaquetaPDF(materias: [
            Self.materia("A", dia: 1, 8, horas: 3),
            Self.materia("B", dia: 1, 8),
            Self.materia("C", dia: 1, 9),
        ])
        #expect(m.bloques.allSatisfy { $0.carriles == 2 },
                "C debería reutilizar el carril de B en vez de abrir uno nuevo")
    }

    @Test("Pegadas pero sin pisarse: cada una a lo ancho")
    func pegadasNoSeTraslapan() {
        // A 8:00-9:00 y B 9:00-10:00. El corte es `inicio >= finActual`, así que
        // tocarse en el borde NO cuenta como traslape.
        let m = MaquetaPDF(materias: [
            Self.materia("A", dia: 1, 8),
            Self.materia("B", dia: 1, 9),
        ])
        #expect(m.bloques.allSatisfy { $0.carriles == 1 })
    }

    @Test("Minutos desde medianoche, no horas")
    func minutos() {
        let m = MaquetaPDF(materias: [Self.materia("A", dia: 1, 8, 30, minutos: 45)])
        let b = m.bloques[0]
        #expect(b.inicio == 8 * 60 + 30)
        #expect(b.fin == 8 * 60 + 30 + 60 + 45)
    }

    @Test("El rango horario se ajusta al contenido, acotado entre 6 y 24")
    func rangoDinamico() {
        let ajustado = MaquetaPDF(materias: [
            Self.materia("A", dia: 1, 9),
            Self.materia("B", dia: 2, 16),
        ])
        #expect(ajustado.horaInicio == 9)
        #expect(ajustado.horaFin == 17)
        #expect(ajustado.franjas == 16)

        // El tope inferior: las 5:00 no bajan de 6.
        let temprano = MaquetaPDF(materias: [
            Self.materia("Temprano", dia: 1, 5),
            Self.materia("Normal", dia: 1, 12),
        ])
        #expect(temprano.horaInicio == 6)
    }

    @Test("Una clase que cruza medianoche ya no deja la rejilla sin filas")
    func cruzarMedianoche() {
        // ESTE ERA EL FALLO. Una clase de 22:30 que dura 2h30 termina a la 1:00
        // del día siguiente. Sacando la hora final con `component(.hour)` salía
        // 1 en vez de 25, el máximo se desplomaba y la rejilla se quedaba con
        // cero filas: PDF en blanco, en una función de pago.
        let m = MaquetaPDF(materias: [
            Self.materia("Temprano", dia: 1, 8),
            Self.materia("Nocturna", dia: 1, 22, 30, horas: 2, minutos: 30),
        ])
        #expect(m.horaFin == 24, "1:00 del día siguiente son 25 h, recortadas al tope de 24")
        #expect(m.horaInicio == 8)
        #expect(m.franjas == 32)
    }

    @Test("Una clase que acaba justo a medianoche se ve entera")
    func acabaEnMedianoche() {
        // 23:00–00:00 es normal en turno nocturno. Con el tope antiguo de 23 se
        // recortaba la última hora en silencio.
        let m = MaquetaPDF(materias: [
            Self.materia("Vespertina", dia: 3, 19),
            Self.materia("Nocturna", dia: 3, 23),
        ])
        #expect(m.horaFin == 24)
        #expect(m.bloques.first { $0.titulo == "Nocturna" }?.fin == 24 * 60)
    }

    @Test("El tope inferior sigue en 6 y el superior nunca pasa de 24")
    func topes() {
        let m = MaquetaPDF(materias: [
            Self.materia("Madrugada", dia: 1, 4),
            Self.materia("Larguísima", dia: 2, 20, horas: 5),   // acaba a la 1:00
        ])
        #expect(m.horaInicio == 6)
        #expect(m.horaFin == 24)
        #expect(m.franjas > 0)
    }

    @Test("La rejilla nunca se queda sin filas, pase lo que pase")
    func siempreHayFilas() {
        // Barrido: cualquier hora de inicio con cualquier duración tiene que dar
        // un rango utilizable. Es la propiedad que el fallo rompía.
        for h in 0...23 {
            for horas in 1...5 {
                let m = MaquetaPDF(materias: [Self.materia("X", dia: 1, h, horas: horas)])
                #expect(m.franjas > 0, "sin filas con inicio \(h):00 y \(horas) h")
                #expect(m.horaFin > m.horaInicio, "rango invertido con \(h):00 y \(horas) h")
            }
        }
    }
}
