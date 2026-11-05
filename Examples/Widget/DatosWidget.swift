import Foundation

// ============================================================
// MARK: - DATOS COMPARTIDOS APP ↔ WIDGET
// ============================================================
// Este archivo pertenece a LOS DOS targets (app y extensión de widget).
//
// Decisión de diseño: la app no vuelca sus modelos completos en el App Group,
// sino una "instantánea" ya resuelta. Así el widget no tiene que replicar
// `Materia`, `HoraPersonal`, sus decodificadores tolerantes ni la lógica de
// negocio, y quedan resueltos de una vez tres problemas:
//
//   1. Materias antiguas con `horarios` vacío, que heredan el horario global.
//   2. El filtrado por curso activo (la app maneja dos cursos).
//   3. La cascada del aula: aula propia del día → aula general → ninguna.
//
// Además se publica la SEMANA COMPLETA, no solo el día de hoy: el widget debe
// seguir siendo correcto pasada la medianoche aunque el usuario no abra la app.
// ============================================================

enum GrupoApp {
    /// Debe coincidir EXACTAMENTE con el App Group de los entitlements
    /// de ambos targets y con el registrado en el portal de Apple Developer.
    static let id = "group.com.yu-na.Horariss"
    static let claveInstantanea = "instantaneaWidget"
}

enum TipoBloqueWidget: String, Codable {
    case materia, libre, estudio
}

/// Un bloque de la semana, ya listo para pintarse.
struct BloqueWidget: Codable, Identifiable, Hashable {
    var id: String
    var titulo: String
    /// Color en modo claro. Para las horas de estudio difiere del oscuro.
    var colorHex: String
    var colorHexOscuro: String
    var icono: String            // nombre de SF Symbol
    var dia: Int                 // 1 = lunes … 7 = domingo
    /// Hora y minuto sueltos, no un Date: evita cualquier ambigüedad al
    /// proyectar el bloque sobre la fecha que el widget esté pintando.
    var hora: Int
    var minuto: Int
    var duracionMin: Int
    var aula: String             // vacía = sin aula
    var tipo: TipoBloqueWidget

    var minutoInicio: Int { hora * 60 + minuto }
    var minutoFin: Int { minutoInicio + duracionMin }
}

struct InstantaneaWidget: Codable {
    var bloques: [BloqueWidget]
    var esPremium: Bool
    var nombreCurso: String
    var generado: Date

    static let vacia = InstantaneaWidget(bloques: [], esPremium: false,
                                         nombreCurso: "", generado: .distantPast)
}

enum DatosWidget {
    private static var defaults: UserDefaults? { UserDefaults(suiteName: GrupoApp.id) }

    static func guardar(_ instantanea: InstantaneaWidget) {
        guard let d = defaults,
              let data = try? JSONEncoder().encode(instantanea) else { return }
        d.set(data, forKey: GrupoApp.claveInstantanea)
    }

    static func leer() -> InstantaneaWidget {
        guard let d = defaults,
              let data = d.data(forKey: GrupoApp.claveInstantanea),
              let i = try? JSONDecoder().decode(InstantaneaWidget.self, from: data)
        else { return .vacia }
        return i
    }

    /// Bloques de un día concreto (1…7), ordenados por hora de inicio.
    static func bloques(de instantanea: InstantaneaWidget, dia: Int) -> [BloqueWidget] {
        instantanea.bloques
            .filter { $0.dia == dia }
            .sorted { $0.minutoInicio < $1.minutoInicio }
    }

    /// Día propio de la semana (1 = lunes … 7 = domingo) para una fecha.
    static func diaSemana(_ fecha: Date, calendario: Calendar = .current) -> Int {
        let wd = calendario.component(.weekday, from: fecha) - 1
        return wd == 0 ? 7 : wd
    }
}
