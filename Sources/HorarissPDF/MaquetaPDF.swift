import Foundation
import HorarissModel

/// Un bloque ya colocado: qué es, qué día, en qué minutos y en qué carril.
///
/// No lleva colores de plataforma ni medidas de texto, solo el hex guardado y
/// números. Por eso vale igual para dibujar con `UIGraphicsPDFRenderer` en iOS
/// que con `PdfDocument` y `Canvas` en Android.
public struct BloqueSituado: Sendable, Equatable {
    public let titulo: String
    public let colorHex: String
    /// Las horas de estudio van más claras: deben leerse sin competir con las materias.
    public let alfa: Double
    public let aula: String?
    public let dia: Int          // 1 = lunes … 7 = domingo
    public let inicio: Int       // minutos desde medianoche
    public let fin: Int
    /// Carril dentro de su grupo de traslapes, empezando en 0.
    public let carril: Int
    /// Cuántos carriles se reparten el ancho del día en ese grupo.
    public let carriles: Int
}

/// La maqueta del horario semanal en PDF.
///
/// **Por qué existe este tipo.** El generador de PDF eran 361 líneas donde el
/// cálculo y el dibujo iban mezclados. Para Android hay que reescribir el
/// dibujo —allí no existen `UIGraphicsPDFRenderer` ni `NSAttributedString`
/// dibujable—, pero el reparto en carriles y el rango horario son aritmética
/// que no depende de la plataforma. Escribirlos dos veces significaría que un
/// arreglo en iOS no llega nunca a Android.
///
/// Lo que sí se queda en cada plataforma es medir texto: las métricas de fuente
/// no coinciden entre sistemas. Por eso la maqueta no mide nada; solo reparte
/// espacio, y cada lado decide cómo mete el texto dentro.
public struct MaquetaPDF: Sendable {
    public let bloques: [BloqueSituado]
    /// Primera hora en pintarse (rango dinámico, acotado entre 6 y 23).
    public let horaInicio: Int
    public let horaFin: Int
    /// Franjas de 30 minutos que ocupa la rejilla.
    public var franjas: Int { (horaFin - horaInicio) * 2 }

    public init(materias: [Materia], horas: [HoraPersonal] = [],
                calendario: Calendar = .current) {
        let cal = calendario

        // Materias + horas libres + horas de estudio en una sola lista
        var partes: [Parte] = []
        for m in materias {
            for b in m.bloquesOrdenados where (1...7).contains(b.dia) {
                partes.append(Parte(titulo: m.nombre, colorHex: m.colorHex, alfa: 0.72,
                                    aula: m.aula(de: b), bloque: b))
            }
        }
        for h in horas {
            for b in h.bloquesOrdenados where (1...7).contains(b.dia) {
                partes.append(Parte(titulo: h.titulo, colorHex: h.colorHex,
                                    alfa: h.tipo == .estudio ? 0.38 : 0.72,
                                    aula: nil, bloque: b))
            }
        }

        // ── Reparto en carriles ────────────────────────────────────────────
        // Dentro de cada día se buscan grupos de bloques que se traslapan (de
        // forma encadenada: si A pisa a B y B pisa a C, los tres van al mismo
        // grupo). A cada bloque del grupo se le asigna el primer carril que ya
        // esté libre a esa hora, y todos los del grupo se reparten el ancho a
        // partes iguales. Es el mismo algoritmo que usa cualquier vista de
        // calendario.
        var inicios: [Int] = []
        var fines: [Int] = []
        for p in partes {
            let ini = cal.component(.hour, from: p.bloque.horario) * 60
                    + cal.component(.minute, from: p.bloque.horario)
            inicios.append(ini)
            fines.append(ini + p.bloque.duracionMin)
        }
        var carriles = [Int](repeating: 0, count: partes.count)
        var totales  = [Int](repeating: 1, count: partes.count)

        for dia in 1...7 {
            let delDia = partes.indices
                .filter { partes[$0].bloque.dia == dia }
                .sorted { inicios[$0] < inicios[$1] }

            // Cortar en grupos: empieza uno nuevo en cuanto un bloque arranca
            // después de que terminó todo el grupo anterior.
            var grupos: [[Int]] = []
            var actual: [Int] = []
            var finActual = Int.min
            for i in delDia {
                if !actual.isEmpty, inicios[i] >= finActual {
                    grupos.append(actual); actual = []; finActual = Int.min
                }
                actual.append(i)
                finActual = max(finActual, fines[i])
            }
            if !actual.isEmpty { grupos.append(actual) }

            for grupo in grupos {
                var finPorCarril: [Int] = []
                for i in grupo {
                    if let libre = finPorCarril.firstIndex(where: { $0 <= inicios[i] }) {
                        finPorCarril[libre] = fines[i]
                        carriles[i] = libre
                    } else {
                        finPorCarril.append(fines[i])
                        carriles[i] = finPorCarril.count - 1
                    }
                }
                for i in grupo { totales[i] = max(1, finPorCarril.count) }
            }
        }

        self.bloques = partes.indices.map { i in
            BloqueSituado(titulo: partes[i].titulo, colorHex: partes[i].colorHex,
                          alfa: partes[i].alfa, aula: partes[i].aula,
                          dia: partes[i].bloque.dia,
                          inicio: inicios[i], fin: fines[i],
                          carril: carriles[i], carriles: totales[i])
        }

        // Rango horario dinámico basado en todos los bloques (cada día su hora).
        //
        // La hora final SE DERIVA DE LOS MINUTOS, no del reloj de pared. Antes se
        // sacaba con `component(.hour, from: Materia.fin(de:))`, y ahí estaba el
        // fallo: una clase de 22:30 que dura 2h30 termina a la 1:00 del día
        // siguiente, y `component(.hour)` devuelve 1, no 25. El máximo se
        // desplomaba, el rango salía invertido y la rejilla se quedaba con CERO
        // filas: un PDF roto, en una función de pago.
        //
        // Con `fines` en minutos desde la medianoche del día del bloque, esa
        // misma clase da 1500 minutos = hora 25, que el tope recorta a 24. El
        // bloque se dibuja hasta medianoche y lo que pase de ahí no se pinta;
        // repartir una clase entre dos columnas de día es otra función, no un
        // arreglo.
        var minHora = 7, maxHora = 21
        if !partes.isEmpty {
            // El tope superior es 24 y no 23: una clase que acaba justo a
            // medianoche (23:00–00:00, nada raro en turno nocturno) antes se
            // recortaba media hora en silencio.
            minHora = max(6,  (inicios.map { $0 / 60 }.min() ?? 7))
            maxHora = min(24, (fines.map { ($0 + 59) / 60 }.max() ?? 21))
        }
        // Red de seguridad: pase lo que pase, la rejilla tiene que tener filas.
        // Si esto llegara a saltar sería otro fallo de cálculo, pero es preferible
        // un PDF con una hora de más que uno en blanco.
        self.horaInicio = minHora
        self.horaFin = max(maxHora, minHora + 1)
    }
}

/// Un bloque del horario antes de repartirlo en carriles. Antes era una tupla
/// de cinco campos con etiqueta, y en Kotlin el acceso por etiqueta (`.bloque`,
/// `.alfa`) no resolvía: una tupla así pedía un tipo con nombre de todos modos.
private struct Parte {
    let titulo: String
    let colorHex: String
    let alfa: Double
    let aula: String?
    let bloque: HorarioDia
}
