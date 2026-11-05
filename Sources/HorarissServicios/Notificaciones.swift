import Foundation
#if SKIP
import SwiftUI
#else
import UserNotifications
#endif
import HorarissModel

// Avisos locales.
//
// En Android el servicio NO se traduce, se sustituye: allí no existe
// UNCalendarNotificationTrigger. Lo que sí es común vive arriba y se usa en las
// dos plataformas: cuándo suena cada aviso y qué dice. Así un cambio de texto
// o del cálculo de la anticipación no puede dejar a una plataforma atrás.
//
// En iOS no toca UIKit, SwiftUI, Firebase ni AppState: solo Foundation, los
// modelos y UserNotifications. En Android usa SkipUI solo para llegar a la
// actividad al pedir el permiso.

// Opciones de anticipación (minutos) y su texto legible
public let opcionesAnticipacion = [0, 5, 10, 15, 20]

public func textoAnticipacion(_ min: Int) -> String {
    min == 0 ? String(localized: "Justo cuando inicie") : String(localized: "\(min) minutos antes")
}

// Avisos disponibles para tareas, en minutos antes de la entrega (se pueden elegir varios).
public let opcionesRecordatorioTarea = [10, 30, 60, 120, 240, 360, 1440, 2880, 4320, 5760, 10080, 20160]

public func textoRecordatorioTarea(_ min: Int) -> String {
    switch min {
    case 10:    return String(localized: "10 minutos antes")
    case 30:    return String(localized: "30 minutos antes")
    case 60:    return String(localized: "1 hora antes")
    case 120:   return String(localized: "2 horas antes")
    case 240:   return String(localized: "4 horas antes")
    case 360:   return String(localized: "6 horas antes")
    case 1440:  return String(localized: "1 día antes")
    case 2880:  return String(localized: "2 días antes")
    case 4320:  return String(localized: "3 días antes")
    case 5760:  return String(localized: "4 días antes")
    case 10080: return String(localized: "1 semana antes")
    case 20160: return String(localized: "2 semanas antes")
    default:    return ""
    }
}

// ============================================================
// MARK: - COMÚN: CUÁNDO SUENA Y QUÉ DICE
// ============================================================

/// Cuándo suena un aviso semanal. `diaSemana` es el de `Calendar`
/// (1 = domingo … 7 = sábado); hora y minuto ya llevan restada la anticipación.
public struct DisparoSemanal: Equatable, Sendable {
    public let diaSemana: Int
    public let hora: Int
    public let minuto: Int
}

/// El disparo de un bloque del horario. `dia` es el de la app (1 = lunes …
/// 7 = domingo). Si al restar la anticipación se cruza la medianoche, suena el
/// día anterior: una clase del martes a las 0:05 con 10 minutos de aviso
/// suena el lunes a las 23:55.
public func disparoSemanal(dia: Int, horario: Date, anticipacion: Int) -> DisparoSemanal? {
    guard (1...7).contains(dia) else { return nil }
    let comps = Calendar.current.dateComponents([.hour, .minute], from: horario)
    guard let h = comps.hour, let m = comps.minute else { return nil }
    var diaSemana = (dia % 7) + 1
    var total = h * 60 + m - anticipacion
    if total < 0 {
        total += 24 * 60
        diaSemana -= 1
        if diaSemana < 1 { diaSemana = 7 }
    }
    return DisparoSemanal(diaSemana: diaSemana, hora: total / 60, minuto: total % 60)
}

/// La próxima vez que toca un disparo semanal, estrictamente después de
/// `desde`. En iOS lo resuelve el sistema; en Android hay que armar cada
/// alarma a mano, y al sonar, la de la semana siguiente.
public func proximoDisparo(_ d: DisparoSemanal, desde: Date) -> Date? {
    let cal = Calendar.current
    guard let hoy = cal.date(bySettingHour: d.hora, minute: d.minuto, second: 0, of: desde) else { return nil }
    var dias = (d.diaSemana - cal.component(.weekday, from: desde) + 7) % 7
    if dias == 0 && hoy <= desde { dias = 7 }
    return cal.date(byAdding: .day, value: dias, to: hoy)
}

/// Lo que dice un aviso. El subtítulo es opcional: solo lo llevan las horas libres.
public struct ContenidoAviso: Equatable, Sendable {
    public let titulo: String
    public let subtitulo: String?
    public let cuerpo: String
}

public func contenidoClase(_ materia: Materia, bloque: HorarioDia, anticipacion: Int) -> ContenidoAviso {
    var cuerpo = anticipacion == 0
        ? String(localized: "Tu clase acaba de comenzar")
        : String(localized: "La clase comenzará en \(anticipacion) minutos")
    // Aula de ESTA clase; si no hay, no se menciona
    if let aula = materia.aula(de: bloque) {
        cuerpo += " · " + String(localized: "Tu aula es \(aula)")
    }
    return ContenidoAviso(titulo: materia.nombre, subtitulo: nil, cuerpo: cuerpo)
}

public func contenidoHora(_ hora: HoraPersonal, anticipacion: Int) -> ContenidoAviso {
    // Las horas libres llevan el nombre que puso el usuario ("Tiempo para
    // comer"), que a secas podría confundirse con una materia. El subtítulo
    // deja claro qué es. Las de estudio no lo necesitan: su título ya es
    // literalmente "Hora de estudio".
    let subtitulo: String? = hora.tipo == .libre ? String(localized: "Tiempo libre") : nil
    let cuerpo: String
    if anticipacion == 0 {
        cuerpo = hora.tipo == .libre
            ? String(localized: "Tu tiempo libre empieza ahora")
            : String(localized: "Tu hora de estudio empieza ahora")
    } else {
        cuerpo = hora.tipo == .libre
            ? String(localized: "Tu tiempo libre empieza en \(anticipacion) minutos")
            : String(localized: "Tu hora de estudio empieza en \(anticipacion) minutos")
    }
    return ContenidoAviso(titulo: hora.titulo, subtitulo: subtitulo, cuerpo: cuerpo)
}

public func contenidoTarea(_ tarea: Tarea, materia: Materia?, cuando: String) -> ContenidoAviso {
    let cuerpo = materia != nil
        ? String(localized: "\(materia!.nombre) · entrega \(cuando)")
        : String(localized: "Entrega \(cuando)")
    return ContenidoAviso(titulo: tarea.nombre, subtitulo: nil, cuerpo: cuerpo)
}

// ============================================================
// MARK: - iOS: USERNOTIFICATIONS
// ============================================================

#if !SKIP
public enum NotificacionesManager {
    // Los dos avisos de permiso devuelven por closure, y ese closure se marca
    // @MainActor, no @Sendable. Quien los llama son vistas que mutan su propio
    // estado: con @Sendable el compilador lo prohíbe, con @MainActor lo describe
    // bien, porque el salto al hilo principal ya lo hace esta capa.

    /// Solicita permiso al usuario para enviar notificaciones.
    public static func solicitarPermiso(_ completion: @escaping @MainActor (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { concedido, _ in
                Task { @MainActor in completion(concedido) }
            }
    }

    /// Devuelve el estado actual del permiso de notificaciones.
    public static func estadoPermiso(_ completion: @escaping @MainActor (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { ajustes in
            // UNNotificationSettings no es Sendable: se extrae el valor antes de
            // cruzar al hilo principal en vez de llevarse el objeto entero.
            let estado = ajustes.authorizationStatus
            Task { @MainActor in completion(estado) }
        }
    }

    public static func cancelarTodo() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Reprograma TODOS los avisos (clases + horas propias + tareas) de una sola
    /// pasada. Se limpia todo y se vuelve a agendar según lo que esté activo.
    public static func reprogramarTodo(materias: [Materia], clasesActivas: Bool, anticipacionClases: Int,
                                       tareas: [Tarea], offsetsTareas: Set<Int>,
                                       horasLibres: [HoraPersonal], libresActivas: Bool, anticipacionLibres: Int,
                                       horasEstudio: [HoraPersonal], estudioActivas: Bool, anticipacionEstudio: Int) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        // ORDEN IMPORTANTE: iOS solo admite 64 avisos pendientes por app y descarta
        // en silencio los que sobren. Primero lo que no se puede perder (clases y
        // entregas) y al final las horas propias, que se repiten cada semana.
        if clasesActivas { programarClases(materias: materias, anticipacion: anticipacionClases, center: center) }
        if !offsetsTareas.isEmpty { programarTareas(tareas: tareas, materias: materias, offsets: offsetsTareas, center: center) }
        if libresActivas  { programarHoras(horas: horasLibres,  anticipacion: anticipacionLibres,  center: center) }
        if estudioActivas { programarHoras(horas: horasEstudio, anticipacion: anticipacionEstudio, center: center) }
    }

    /// Avisos semanales de las horas libres y de estudio. Misma mecánica que las
    /// clases: un aviso repetido por cada día, con la anticipación de su tipo.
    private static func programarHoras(horas: [HoraPersonal], anticipacion: Int,
                                       center: UNUserNotificationCenter) {
        for hora in horas {
            for bloque in hora.bloquesOrdenados {
                guard let d = disparoSemanal(dia: bloque.dia, horario: bloque.horario, anticipacion: anticipacion)
                else { continue }
                agendar(contenidoHora(hora, anticipacion: anticipacion), semanal: d,
                        id: "hora-\(hora.id.uuidString)-\(bloque.dia)", center: center)
            }
        }
    }

    /// Avisos semanales repetidos de cada clase (según la anticipación en minutos).
    private static func programarClases(materias: [Materia], anticipacion: Int, center: UNUserNotificationCenter) {
        for materia in materias {
            // Cada día usa su propio bloque (hora de inicio puede variar por día)
            // Con índice: dos clases el mismo día compartían identificador y la
            // segunda sustituía a la primera, así que solo sonaba un aviso.
            for (i, bloque) in materia.bloquesOrdenados.enumerated() {
                guard let d = disparoSemanal(dia: bloque.dia, horario: bloque.horario, anticipacion: anticipacion)
                else { continue }
                agendar(contenidoClase(materia, bloque: bloque, anticipacion: anticipacion), semanal: d,
                        id: "clase-\(materia.id.uuidString)-\(bloque.dia)-\(i)", center: center)
            }
        }
    }

    private static func agendar(_ c: ContenidoAviso, semanal d: DisparoSemanal, id: String,
                                center: UNUserNotificationCenter) {
        var disparo = DateComponents()
        disparo.weekday = d.diaSemana
        disparo.hour = d.hora
        disparo.minute = d.minuto
        let trigger = UNCalendarNotificationTrigger(dateMatching: disparo, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: contenidoUN(c), trigger: trigger))
    }

    private static func contenidoUN(_ c: ContenidoAviso) -> UNMutableNotificationContent {
        let contenido = UNMutableNotificationContent()
        contenido.title = c.titulo
        if let s = c.subtitulo { contenido.subtitle = s }
        contenido.body = c.cuerpo
        contenido.sound = .default
        return contenido
    }

    /// Avisos puntuales de cada tarea pendiente: uno por cada offset elegido (10 min antes, 1 día antes, …).
    private static func programarTareas(tareas: [Tarea], materias: [Materia], offsets: Set<Int>, center: UNUserNotificationCenter) {
        let cal = Calendar.current
        let ahora = Date()
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        for tarea in tareas where !tarea.completada {
            let mat = materias.first { $0.id == tarea.materiaId }
            let cuando = f.string(from: tarea.fechaEntrega)
            for off in offsets {
                // La fecha de disparo = entrega menos el offset; solo si aún está en el futuro
                guard let fire = cal.date(byAdding: .minute, value: -off, to: tarea.fechaEntrega),
                      fire > ahora else { continue }
                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let req = UNNotificationRequest(identifier: "tarea-\(tarea.id.uuidString)-\(off)",
                                                content: contenidoUN(contenidoTarea(tarea, materia: mat, cuando: cuando)),
                                                trigger: trigger)
                center.add(req)
            }
        }
    }
}
#endif

// ============================================================
// MARK: - ANDROID: AGENDA Y ALARMAS
// ============================================================

// En Android no existe «avisa cada martes a las 7:50»: solo alarmas que suenan
// una vez, y que además se borran al reiniciar el teléfono. Así que:
//   1. Cada aviso se guarda en una agenda (JSON en las preferencias): qué dice
//      y cuándo toca.
//   2. Por cada uno se arma una alarma de AlarmManager.
//   3. Al sonar, `ReceptorAvisos` publica la notificación y, si el aviso es
//      semanal, arma la de la semana siguiente.
//   4. Al reiniciar el teléfono, al actualizar la app o al cambiar la hora o
//      la zona horaria, el mismo receptor vuelve a armar toda la agenda.
//
// Exactitud: con el permiso de alarmas exactas suenan al minuto. Android 14 ya
// no lo concede por omisión, y sin él Android entrega la alarma al FINAL de una
// ventana de tolerancia que crece con la distancia: comprobado en el emulador,
// 1,5 minutos para una alarma a 2 minutos y una hora para la de la semana
// siguiente. Por eso la pantalla de notificaciones ofrece el permiso, y sin
// él la ventana es de 10 minutos (el mínimo de Android) y termina justo en la
// hora del aviso: llega a tiempo o unos minutos antes, nunca una hora tarde.
#if SKIP
struct AvisoAndroid: Codable {
    var id: String
    var titulo: String
    var subtitulo: String?
    var cuerpo: String
    /// Semanal: día de `Calendar` (1 = domingo), hora y minuto
    var diaSemana: Int?
    var hora: Int?
    var minuto: Int?
    /// Único (las entregas): el momento, en segundos desde 1970
    var momento: Double?

    /// La próxima vez que toca, estrictamente después de `desde`
    func proximaVez(desde: Date) -> Date? {
        if let m = momento {
            let d = Date(timeIntervalSince1970: m)
            return d > desde ? d : nil
        }
        guard let dia = diaSemana, let h = hora, let min = minuto else { return nil }
        return proximoDisparo(DisparoSemanal(diaSemana: dia, hora: h, minuto: min), desde: desde)
    }
}

public enum NotificacionesManager {
    static let canal = "horariss_avisos"
    static let accionAviso = "horariss.AVISO"
    private static let claveAgenda = "agendaAvisosAndroid"

    // MARK: Permiso

    /// Desde Android 13 hay que pedir permiso para mostrar notificaciones.
    /// Se pide con el registro de resultados de la actividad, que se puede usar
    /// en cualquier momento; `registerForActivityResult` solo antes de que la
    /// actividad arranque.
    public static func solicitarPermiso(_ completion: @escaping @MainActor (Bool) -> Void) {
        let contexto = ProcessInfo.processInfo.androidContext
        if android.os.Build.VERSION.SDK_INT < 33 {
            completion(notificacionesActivas(contexto))
            return
        }
        if contexto.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)
            == android.content.pm.PackageManager.PERMISSION_GRANTED {
            completion(true)
            return
        }
        guard let actividad = UIApplication.shared.androidActivity as? androidx.activity.ComponentActivity else {
            completion(false)
            return
        }
        var lanzador: androidx.activity.result.ActivityResultLauncher<String>? = nil
        lanzador = actividad.activityResultRegistry.register("horariss_permiso_avisos",
            androidx.activity.result.contract.ActivityResultContracts.RequestPermission()) { concedido in
            lanzador?.unregister()
            completion(concedido == true)
        }
        lanzador?.launch(android.Manifest.permission.POST_NOTIFICATIONS)
    }

    /// Los ajustes de notificaciones de la app, para quien negó el permiso
    public static func abrirAjustes() {
        let contexto = ProcessInfo.processInfo.androidContext
        let intent = android.content.Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
        intent.putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, contexto.packageName)
        intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        contexto.startActivity(intent)
    }

    /// Si Android deja armar alarmas exactas (siempre, antes de Android 12)
    public static var alarmasExactasPermitidas: Bool {
        if android.os.Build.VERSION.SDK_INT < 31 { return true }
        let contexto = ProcessInfo.processInfo.androidContext
        let am = contexto.getSystemService(android.content.Context.ALARM_SERVICE) as! android.app.AlarmManager
        return am.canScheduleExactAlarms()
    }

    /// Abre «Alarmas y recordatorios» para Horariss. Si el usuario lo concede,
    /// Android avisa al receptor y este vuelve a armar todo, ya exacto.
    public static func pedirAlarmasExactas() {
        guard android.os.Build.VERSION.SDK_INT >= 31 else { return }
        let contexto = ProcessInfo.processInfo.androidContext
        let intent = android.content.Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
        intent.setData(android.net.Uri.parse("package:" + contexto.packageName))
        intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        contexto.startActivity(intent)
    }

    static func notificacionesActivas(_ contexto: android.content.Context) -> Bool {
        let nm = contexto.getSystemService(android.content.Context.NOTIFICATION_SERVICE) as! android.app.NotificationManager
        return nm.areNotificationsEnabled()
    }

    // MARK: Programar

    public static func cancelarTodo() {
        let contexto = ProcessInfo.processInfo.androidContext
        desarmar(leerAgenda(), contexto)
        guardarAgenda([])
    }

    public static func reprogramarTodo(materias: [Materia], clasesActivas: Bool, anticipacionClases: Int,
                                       tareas: [Tarea], offsetsTareas: Set<Int>,
                                       horasLibres: [HoraPersonal], libresActivas: Bool, anticipacionLibres: Int,
                                       horasEstudio: [HoraPersonal], estudioActivas: Bool, anticipacionEstudio: Int) {
        var avisos: [AvisoAndroid] = []
        if clasesActivas {
            for materia in materias {
                for (i, bloque) in materia.bloquesOrdenados.enumerated() {
                    guard let d = disparoSemanal(dia: bloque.dia, horario: bloque.horario, anticipacion: anticipacionClases)
                    else { continue }
                    avisos.append(semanal(contenidoClase(materia, bloque: bloque, anticipacion: anticipacionClases), d,
                                          id: "clase-\(materia.id.uuidString)-\(bloque.dia)-\(i)"))
                }
            }
        }
        if !offsetsTareas.isEmpty {
            let ahora = Date()
            let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
            for tarea in tareas where !tarea.completada {
                let mat = materias.first { $0.id == tarea.materiaId }
                let c = contenidoTarea(tarea, materia: mat, cuando: f.string(from: tarea.fechaEntrega))
                for off in offsetsTareas {
                    guard let fire = Calendar.current.date(byAdding: .minute, value: -off, to: tarea.fechaEntrega),
                          fire > ahora else { continue }
                    avisos.append(AvisoAndroid(id: "tarea-\(tarea.id.uuidString)-\(off)", titulo: c.titulo,
                                               subtitulo: c.subtitulo, cuerpo: c.cuerpo, diaSemana: nil, hora: nil,
                                               minuto: nil, momento: fire.timeIntervalSince1970))
                }
            }
        }
        if libresActivas { avisos += avisosDeHoras(horasLibres, anticipacion: anticipacionLibres) }
        if estudioActivas { avisos += avisosDeHoras(horasEstudio, anticipacion: anticipacionEstudio) }
        let contexto = ProcessInfo.processInfo.androidContext
        desarmar(leerAgenda(), contexto)
        guardarAgenda(avisos)
        let ahora = Date()
        for a in avisos { armar(a, desde: ahora, contexto) }
    }

    private static func avisosDeHoras(_ horas: [HoraPersonal], anticipacion: Int) -> [AvisoAndroid] {
        var avisos: [AvisoAndroid] = []
        for hora in horas {
            for bloque in hora.bloquesOrdenados {
                guard let d = disparoSemanal(dia: bloque.dia, horario: bloque.horario, anticipacion: anticipacion)
                else { continue }
                avisos.append(semanal(contenidoHora(hora, anticipacion: anticipacion), d,
                                      id: "hora-\(hora.id.uuidString)-\(bloque.dia)"))
            }
        }
        return avisos
    }

    private static func semanal(_ c: ContenidoAviso, _ d: DisparoSemanal, id: String) -> AvisoAndroid {
        AvisoAndroid(id: id, titulo: c.titulo, subtitulo: c.subtitulo, cuerpo: c.cuerpo,
                     diaSemana: d.diaSemana, hora: d.hora, minuto: d.minuto, momento: nil)
    }

    // MARK: Lo que hace el receptor

    /// Sonó una alarma: se publica su aviso y, si es semanal, se arma la de la
    /// semana siguiente.
    static func alSonar(id: String, _ contexto: android.content.Context) {
        guard let aviso = leerAgenda().first(where: { $0.id == id }) else { return }
        publicar(aviso, contexto)
        if aviso.diaSemana != nil { armar(aviso, desde: Date(), contexto) }
    }

    /// Reinicio, actualización o cambio de hora: se vuelve a armar todo
    static func rearmarTodo(_ contexto: android.content.Context) {
        let ahora = Date()
        for a in leerAgenda() { armar(a, desde: ahora, contexto) }
    }

    // MARK: Alarmas

    private static func armar(_ aviso: AvisoAndroid, desde: Date, _ contexto: android.content.Context) {
        guard let cuando = aviso.proximaVez(desde: desde) else { return }
        let am = contexto.getSystemService(android.content.Context.ALARM_SERVICE) as! android.app.AlarmManager
        let ms = Int64(cuando.timeIntervalSince1970 * 1000.0)
        var exacta = true
        if android.os.Build.VERSION.SDK_INT >= 31 { exacta = am.canScheduleExactAlarms() }
        if exacta {
            am.setExactAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, ms, intencion(aviso.id, contexto))
        } else {
            // Ventana de 10 minutos que TERMINA en la hora del aviso
            let ventana: Int64 = 10 * 60 * 1000
            let ahora = Int64(Date().timeIntervalSince1970 * 1000.0)
            let inicio = max(ahora, ms - ventana)
            am.setWindow(android.app.AlarmManager.RTC_WAKEUP, inicio, ms - inicio, intencion(aviso.id, contexto))
        }
    }

    private static func desarmar(_ avisos: [AvisoAndroid], _ contexto: android.content.Context) {
        let am = contexto.getSystemService(android.content.Context.ALARM_SERVICE) as! android.app.AlarmManager
        for a in avisos { am.cancel(intencion(a.id, contexto)) }
    }

    /// La alarma de un aviso. El identificador va en la URI: así cada aviso
    /// tiene su propia alarma y se puede cancelar sin conocer nada más.
    private static func intencion(_ id: String, _ contexto: android.content.Context) -> android.app.PendingIntent {
        let intent = android.content.Intent(accionAviso)
        intent.setClassName(contexto, "horariss.servicios.ReceptorAvisos")
        intent.setData(android.net.Uri.parse("horariss://aviso/" + id))
        return android.app.PendingIntent.getBroadcast(contexto, 0, intent,
            android.app.PendingIntent.FLAG_IMMUTABLE | android.app.PendingIntent.FLAG_UPDATE_CURRENT)
    }

    // MARK: La notificación

    private static func publicar(_ aviso: AvisoAndroid, _ contexto: android.content.Context) {
        let nm = contexto.getSystemService(android.content.Context.NOTIFICATION_SERVICE) as! android.app.NotificationManager
        let c = android.app.NotificationChannel(canal, String(localized: "Recordatorios"),
                                                android.app.NotificationManager.IMPORTANCE_HIGH)
        c.setDescription(String(localized: "Avisos de tus clases, horas y entregas"))
        nm.createNotificationChannel(c)

        // El icono pequeño es el logo en silueta (res/drawable); Android solo
        // usa su canal alfa.
        let icono = contexto.resources.getIdentifier("ic_notificacion", "drawable", contexto.packageName)
        let b = android.app.Notification.Builder(contexto, canal)
            .setSmallIcon(icono != 0 ? icono : android.R.drawable.ic_popup_reminder)
            .setContentTitle(aviso.titulo)
            .setContentText(aviso.cuerpo)
            .setStyle(android.app.Notification.BigTextStyle().bigText(aviso.cuerpo))
            .setAutoCancel(true)
        if let s = aviso.subtitulo { b.setSubText(s) }
        if let abrir = contexto.packageManager.getLaunchIntentForPackage(contexto.packageName) {
            b.setContentIntent(android.app.PendingIntent.getActivity(contexto, 0, abrir,
                android.app.PendingIntent.FLAG_IMMUTABLE | android.app.PendingIntent.FLAG_UPDATE_CURRENT))
        }
        nm.notify(aviso.id.hashCode(), b.build())
    }

    // MARK: La agenda

    private static func leerAgenda() -> [AvisoAndroid] {
        guard let d = UserDefaults.standard.data(forKey: claveAgenda) else { return [] }
        return (try? JSONDecoder().decode([AvisoAndroid].self, from: d)) ?? []
    }

    private static func guardarAgenda(_ avisos: [AvisoAndroid]) {
        if let d = try? JSONEncoder().encode(avisos) { UserDefaults.standard.set(d, forKey: claveAgenda) }
    }
}

/// Recibe las alarmas de los avisos y los avisos del sistema tras reiniciar,
/// actualizar la app o cambiar la hora. Está declarado en el AndroidManifest de
/// la app con este nombre completo: horariss.servicios.ReceptorAvisos.
public final class ReceptorAvisos: android.content.BroadcastReceiver {
    public init() {
    }

    public override func onReceive(context: android.content.Context, intent: android.content.Intent) {
        if intent.action == NotificacionesManager.accionAviso {
            guard let id = intent.data?.lastPathSegment else { return }
            NotificacionesManager.alSonar(id: id, context)
        } else {
            NotificacionesManager.rearmarTodo(context)
        }
    }
}
#endif
