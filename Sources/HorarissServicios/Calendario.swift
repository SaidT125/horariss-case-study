import Foundation
#if !SKIP
import EventKit
import CoreGraphics
#endif
import HorarissModel

// Sincronización con el Calendario de Apple.
//
// No se escribe una clase por semana: cada bloque se guarda como UN evento con
// regla de repetición semanal y fecha de fin. Una materia de lunes, miércoles y
// viernes durante un año son 1 evento, no 156. Por eso el plazo que elige el
// usuario no cuesta nada y resincronizar es instantáneo.
//
// Todo va a un calendario propio llamado "Horariss": así el usuario lo apaga o
// lo borra de un toque desde la app Calendario, y quitar la sincronización no
// deja eventos sueltos entre los suyos.
//
// El color del calendario se recibe como `CGColor` y no como `UIColor`: UIKit no
// existe fuera de iOS, y aquí solo hacía falta para sacar el `.cgColor` que pide
// EKCalendar. Un puente menos.
//
// TERCER servicio que en Android NO se traduce sino que se sustituye, junto con
// la tienda y las notificaciones. Allí lo cubre skip-calendar, que envuelve
// EventKit en iOS y CalendarContract en Android. Dos avisos de su documentación:
// los asistentes son de solo lectura, y las alarmas con fecha absoluta son
// exclusivas de iOS.

// ============================================================
// MARK: - QUÉ SE LLEVA AL CALENDARIO
// ============================================================

public struct ContenidoCalendario: OptionSet, Equatable, Sendable {
    public let rawValue: Int
    // El init memberwise que sintetiza Swift es internal, y OptionSet lo exige
    // público en un tipo público.
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let clases  = ContenidoCalendario(rawValue: 1)
    public static let libres  = ContenidoCalendario(rawValue: 2)
    public static let estudio = ContenidoCalendario(rawValue: 4)
    public static let todo: ContenidoCalendario = [.clases, .libres, .estudio]
}

public enum FalloCalendario: LocalizedError {
    case sinPermiso
    case sinCuenta
    case guardar(String)

    public var errorDescription: String? {
        switch self {
        case .sinPermiso:
            String(localized: "Horariss no tiene permiso para usar tu calendario")
        case .sinCuenta:
            String(localized: "Tu dispositivo no tiene una cuenta de calendario donde crear el de Horariss")
        case .guardar(let d):
            d
        }
    }
}

// ============================================================
// MARK: - SINCRONIZACIÓN
// ============================================================

// `nonisolated`: este código NO toca la interfaz, solo habla con EventKit.
// Sin esta marca el proyecto lo da por código del hilo principal
// (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor) y llamarlo desde el Task.detached
// de AppState.sincronizarCalendario da error en Swift 6. Debe seguir fuera del
// hilo principal: volcar cientos de eventos ahí congelaría la app.
public enum SincroCalendario {
    public static let nombre = "Horariss"
    private static let claveId = "calendarioHorarissId"
    /// Cuántos meses hacia delante puede pedir el usuario
    public static let plazos = Array(1...12)
    public static let plazoPorOmision = 6

    public static func fin(meses: Int, desde: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .month, value: max(1, meses), to: desde) ?? desde
    }

    public struct Resultado: Sendable {
        public var eventos: Int
        public var hasta: Date
    }
}

// ============================================================
// MARK: - iOS: EVENTKIT
// ============================================================

#if !SKIP
extension SincroCalendario {
    nonisolated(unsafe) private static let almacen = EKEventStore()

    // MARK: Permiso

    public static var autorizado: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }
    public static var denegado: Bool {
        let e = EKEventStore.authorizationStatus(for: .event)
        return e == .denied || e == .restricted || e == .writeOnly
    }

    /// Solo sirve el acceso completo. Con "solo escritura" iOS entrega una
    /// cuenta ficticia donde crear un calendario propio falla —"esa cuenta no
    /// permite añadir ni eliminar calendarios"— y, al no poder leer nada, cada
    /// sincronización duplicaría el horario entero en vez de actualizarlo.
    public static func pedirAcceso() async -> Bool {
        (try? await almacen.requestFullAccessToEvents()) ?? false
    }

    // MARK: Calendario propio

    private static func calendarioExistente() -> EKCalendar? {
        guard let id = UserDefaults.standard.string(forKey: claveId) else { return nil }
        // Si el usuario lo borró a mano desde Calendario, esto devuelve nil y
        // más abajo se vuelve a crear en vez de fallar.
        return almacen.calendar(withIdentifier: id)
    }

    private static func crearCalendario(color: CGColor) throws -> EKCalendar {
        // Se prueban las cuentas en orden: la del calendario por omisión (que
        // suele ser iCloud y sincroniza con los demás dispositivos), luego
        // cualquier iCloud, y por último la local. Las cuentas suscritas o de
        // cumpleaños rechazan crear calendarios, de ahí el bucle.
        var candidatas: [EKSource] = []
        if let s = almacen.defaultCalendarForNewEvents?.source { candidatas.append(s) }
        candidatas += almacen.sources.filter { $0.sourceType == .calDAV }
        candidatas += almacen.sources.filter { $0.sourceType == .local }
        candidatas += almacen.sources

        var ultimo: String?
        for fuente in candidatas {
            let cal = EKCalendar(for: .event, eventStore: almacen)
            cal.title = nombre
            cal.cgColor = color
            cal.source = fuente
            do {
                try almacen.saveCalendar(cal, commit: true)
                UserDefaults.standard.set(cal.calendarIdentifier, forKey: claveId)
                return cal
            } catch { ultimo = error.localizedDescription }
        }
        throw ultimo.map { FalloCalendario.guardar($0) } ?? FalloCalendario.sinCuenta
    }

    private static func calendario(color: CGColor) throws -> EKCalendar {
        if let c = calendarioExistente() { return c }
        return try crearCalendario(color: color)
    }

    /// Vacía nuestro calendario. Se barre una ventana amplia y se borra cada
    /// serie entera: es más fiable que ir guardando identificadores, que se
    /// pierden si el usuario reinstala o edita algo desde Calendario.
    private static func vaciar(_ cal: EKCalendar) {
        let ahora = Date()
        let c = Calendar.current
        guard let desde = c.date(byAdding: .year, value: -2, to: ahora),
              let hasta = c.date(byAdding: .year, value: 2, to: ahora) else { return }
        let encontrados = almacen.events(matching:
            almacen.predicateForEvents(withStart: desde, end: hasta, calendars: [cal]))
        var vistos = Set<String>()
        for ev in encontrados {
            let id = ev.eventIdentifier ?? UUID().uuidString
            guard vistos.insert(id).inserted else { continue }   // una vez por serie
            try? almacen.remove(ev, span: .futureEvents, commit: false)
        }
        try? almacen.commit()
    }

    // MARK: Construcción de los eventos

    /// Un evento a crear: varios días que comparten hora, duración y aula.
    private struct Grupo {
        var titulo: String
        var dias: Set<Int>
        var hora: Int
        var minuto: Int
        var duracionMin: Int
        var aula: String
        var notas: String
    }

    private static func agrupar(titulo: String, notas: String, bloques: [HorarioDia],
                                aula: (HorarioDia) -> String) -> [Grupo] {
        let cal = Calendar.current
        var mapa: [String: Grupo] = [:]
        for b in bloques where (1...7).contains(b.dia) {
            let c = cal.dateComponents([.hour, .minute], from: b.horario)
            let h = c.hour ?? 0, m = c.minute ?? 0
            let sala = aula(b)
            // Solo se agrupan los días idénticos en todo: si el miércoles es en
            // otra aula, va en su propio evento o mostraría la sala equivocada.
            let clave = "\(h)|\(m)|\(b.duracionMin)|\(sala)"
            if mapa[clave] != nil {
                mapa[clave]?.dias.insert(b.dia)
            } else {
                mapa[clave] = Grupo(titulo: titulo, dias: [b.dia], hora: h, minuto: m,
                                    duracionMin: max(b.duracionMin, 5), aula: sala, notas: notas)
            }
        }
        return Array(mapa.values)
    }

    /// Primera aparición de la serie: el día que toque de ESTA semana, para que
    /// la semana en curso quede completa en el calendario.
    private static func primeraFecha(_ g: Grupo) -> Date? {
        var cal = Calendar.current
        cal.firstWeekday = 2        // la app numera 1 = lunes
        guard let dia = g.dias.min(),
              let semana = cal.dateInterval(of: .weekOfYear, for: Date())?.start,
              let base = cal.date(byAdding: .day, value: dia - 1, to: semana) else { return nil }
        return cal.date(bySettingHour: g.hora, minute: g.minuto, second: 0, of: base)
    }

    private static func evento(_ g: Grupo, en cal: EKCalendar, hasta: Date) -> EKEvent? {
        guard let inicio = primeraFecha(g),
              let fin = Calendar.current.date(byAdding: .minute, value: g.duracionMin, to: inicio)
        else { return nil }

        let ev = EKEvent(eventStore: almacen)
        ev.calendar = cal
        ev.title = g.titulo
        ev.timeZone = TimeZone.current
        ev.startDate = inicio
        ev.endDate = fin
        if !g.aula.isEmpty { ev.location = g.aula }
        if !g.notas.isEmpty { ev.notes = g.notas }
        // Sin alertas a propósito: Horariss ya manda las suyas y, con aviso en
        // el evento, el alumno recibiría dos por cada clase.
        ev.alarms = []

        // EKWeekday empieza en domingo (1); la app empieza en lunes (1).
        let dias = g.dias.sorted().compactMap { d in
            EKWeekday(rawValue: (d % 7) + 1).map { EKRecurrenceDayOfWeek($0) }
        }
        guard !dias.isEmpty else { return nil }
        ev.recurrenceRules = [EKRecurrenceRule(
            recurrenceWith: .weekly, interval: 1, daysOfTheWeek: dias,
            daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil,
            daysOfTheYear: nil, setPositions: nil,
            end: EKRecurrenceEnd(end: hasta))]
        return ev
    }

    // MARK: Entrada principal


    @discardableResult
    public static func sincronizar(materias: [Materia], libres: [HoraPersonal],
                            estudio: [HoraPersonal], contenido: ContenidoCalendario,
                            meses: Int, colorHex: String) throws -> Resultado {
        guard autorizado else { throw FalloCalendario.sinPermiso }
        let cal = try calendario(color: cgColor(hex: colorHex))
        vaciar(cal)

        let hasta = fin(meses: meses)
        var grupos: [Grupo] = []
        if contenido.contains(.clases) {
            for m in materias {
                grupos += agrupar(titulo: m.nombre, notas: m.notas,
                                  bloques: m.bloquesOrdenados) { m.aula(de: $0) ?? "" }
            }
        }
        if contenido.contains(.libres) {
            for h in libres {
                grupos += agrupar(titulo: h.titulo, notas: h.notas,
                                  bloques: h.bloquesOrdenados) { _ in "" }
            }
        }
        if contenido.contains(.estudio) {
            for h in estudio {
                grupos += agrupar(titulo: h.titulo, notas: h.notas,
                                  bloques: h.bloquesOrdenados) { _ in "" }
            }
        }

        var creados = 0
        for g in grupos {
            guard let ev = evento(g, en: cal, hasta: hasta) else { continue }
            do { try almacen.save(ev, span: .futureEvents, commit: false); creados += 1 }
            catch { continue }
        }
        do { try almacen.commit() }
        catch { throw FalloCalendario.guardar(error.localizedDescription) }
        return Resultado(eventos: creados, hasta: hasta)
    }

    /// Quita el calendario entero. Es lo que hace "dejar de sincronizar": un
    /// solo borrado y no queda rastro entre los eventos personales.
    public static func borrar() {
        if let c = calendarioExistente() {
            try? almacen.removeCalendar(c, commit: true)
        }
        UserDefaults.standard.removeObject(forKey: claveId)
    }

    /// El color llega como hex y se convierte aquí, del lado de Apple: así ni
    /// el modelo ni la capa de datos dependen de CoreGraphics, que no existe
    /// en Android. Antes el modelo exponía un `CGColor` solo para esto.
    private static func cgColor(hex: String) -> CGColor {
        let v = UInt64(hex, radix: 16) ?? 0
        return CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                       green:   CGFloat((v >> 8)  & 0xFF) / 255,
                       blue:    CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}
#endif

// ============================================================
// MARK: - ANDROID: TODAVÍA SIN CALENDARIO
// ============================================================

// El calendario queda fuera de la primera versión de Android (decidido con el
// usuario). Esta extensión existe para que la capa de datos compile allí con
// la misma API: nunca hay permiso, así que AppState no intenta sincronizar.
// Cuando llegue, lo cubre skip-calendar (CalendarContract por debajo).
#if SKIP
extension SincroCalendario {
    public static var autorizado: Bool { false }
    public static var denegado: Bool { false }
    public static func pedirAcceso() async -> Bool { false }

    @discardableResult
    public static func sincronizar(materias: [Materia], libres: [HoraPersonal],
                                   estudio: [HoraPersonal], contenido: ContenidoCalendario,
                                   meses: Int, colorHex: String) throws -> Resultado {
        throw FalloCalendario.sinPermiso
    }

    public static func borrar() {}
}
#endif
