import Foundation

// Los pasos del tutorial de primer uso. `objetivo` nombra el elemento que
// hay que resaltar; el foco en sí lo hace la vista.
public enum PasoTutorial: Int, Sendable {
    case materias, tabTareas, anadirTarea, tabPerfil, notificaciones

    public var objetivo: String {
        switch self {
        case .materias:       "fabMaterias"
        case .tabTareas:      "tabTareas"
        case .anadirTarea:    "fabTareas"
        case .tabPerfil:      "tabPerfil"
        case .notificaciones: "filaNotificaciones"
        }
    }
    public var texto: String {
        switch self {
        case .materias:       String(localized: "Con este botón agregas tus materias y armas tu horario")
        case .tabTareas:      String(localized: "Toca aquí para ir a tus tareas")
        case .anadirTarea:    String(localized: "Con este botón agregas tareas con fecha de entrega")
        case .tabPerfil:      String(localized: "Ahora ve a tu perfil")
        case .notificaciones: String(localized: "Toca aquí para activar los avisos de tus clases y tareas")
        }
    }
}
