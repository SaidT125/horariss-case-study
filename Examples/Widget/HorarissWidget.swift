import WidgetKit
import SwiftUI

// ============================================================
// MARK: - HORARISS · WIDGET DE PANTALLA DE INICIO
// ============================================================
// Muestra las clases y bloques de hoy. El tamaño pequeño es gratis;
// el mediano y el grande son Premium (sin él tapan los nombres).
// Los datos vienen del App Group, ya resueltos por la app (ver DatosWidget.swift):
// la extensión no replica modelos ni lógica de negocio.
// ============================================================

// MARK: - Tipografía y color

/// Inter, con caída elegante a la fuente del sistema si el .ttf no está en el
/// bundle de la extensión. Ojo: la app registra las fuentes en tiempo de
/// ejecución desde su AppDelegate, y el widget es OTRO proceso: aquí solo
/// funcionan si están incluidas en el target y declaradas en su Info.plist.
private func fuente(_ tam: CGFloat, _ peso: Font.Weight = .regular) -> Font {
    let nombre: String
    switch peso {
    case .bold, .heavy, .black: nombre = "Inter18pt-Bold"
    case .semibold:             nombre = "Inter18pt-SemiBold"
    case .medium:               nombre = "Inter18pt-Medium"
    default:                    nombre = "Inter18pt-Regular"
    }
    return .custom(nombre, size: tam)
}

private extension Color {
    init(hexWidget: String) {
        let hex = hexWidget.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(red: Double((rgb & 0xFF0000) >> 16) / 255,
                  green: Double((rgb & 0x00FF00) >> 8) / 255,
                  blue: Double(rgb & 0x0000FF) / 255)
    }

    init(light: String, dark: String) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color(hexWidget: dark)) : UIColor(Color(hexWidget: light))
        })
    }

    /// Adaptativos, para que el widget se vea bien en claro y en oscuro.
    static let wTextoPrimario   = Color(light: "1A1A24", dark: "F5F5F7")
    static let wTextoSecundario = Color(light: "8A8A96", dark: "9C9CA4")
    static let wFondo           = Color(light: "FFFFFF", dark: "1C1C1E")
    static let wSeparador       = Color(light: "EBEBF0", dark: "2C2C2E")
}

private let enlaceApp = URL(string: "horariss://inicio")

private func formatoHora(_ minutos: Int) -> String {
    String(format: "%02d:%02d", minutos / 60, minutos % 60)
}

// MARK: - Timeline

struct EntradaHorario: TimelineEntry {
    let date: Date
    let bloques: [BloqueWidget]     // los de hoy, ordenados
    let esPremium: Bool
    let nombreCurso: String
}

struct ProveedorHorario: TimelineProvider {

    private func entrada(en fecha: Date, desde inst: InstantaneaWidget) -> EntradaHorario {
        EntradaHorario(date: fecha,
                       bloques: DatosWidget.bloques(de: inst, dia: DatosWidget.diaSemana(fecha)),
                       esPremium: inst.esPremium,
                       nombreCurso: inst.nombreCurso)
    }

    func placeholder(in context: Context) -> EntradaHorario {
        EntradaHorario(date: Date(), bloques: BloqueWidget.ejemplo,
                       esPremium: true, nombreCurso: "Mi Curso")
    }

    func getSnapshot(in context: Context, completion: @escaping (EntradaHorario) -> Void) {
        // En la galería de widgets se enseña contenido de ejemplo desbloqueado:
        // es donde el usuario decide si lo instala.
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(entrada(en: Date(), desde: DatosWidget.leer()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EntradaHorario>) -> Void) {
        let inst = DatosWidget.leer()
        let cal = Calendar.current
        let ahora = Date()
        let inicioDia = cal.startOfDay(for: ahora)
        let bloquesHoy = DatosWidget.bloques(de: inst, dia: DatosWidget.diaSemana(ahora, calendario: cal))

        // Una entrada ahora y otra en cada inicio y fin de bloque: así "la
        // próxima clase" avanza sola sin depender de que se abra la app.
        var momentos: Set<Date> = [ahora]
        for b in bloquesHoy {
            for min in [b.minutoInicio, b.minutoFin] {
                if let f = cal.date(byAdding: .minute, value: min, to: inicioDia), f > ahora {
                    momentos.insert(f)
                }
            }
        }
        let entradas = momentos.sorted().map { entrada(en: $0, desde: inst) }

        // A medianoche se recarga para pasar al día siguiente
        let manana = cal.date(byAdding: .day, value: 1, to: inicioDia) ?? ahora.addingTimeInterval(86_400)
        completion(Timeline(entries: entradas, policy: .after(manana)))
    }
}

// MARK: - Piezas de interfaz

/// Ícono circular tintado, al estilo del widget de Recordatorios de Apple.
private struct IconoBloque: View {
    let bloque: BloqueWidget
    var lado: CGFloat = 30
    @Environment(\.colorScheme) private var esquema

    private var color: Color {
        Color(hexWidget: esquema == .dark ? bloque.colorHexOscuro : bloque.colorHex)
    }
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.20)).frame(width: lado, height: lado)
            Image(systemName: bloque.icono)
                .font(.system(size: lado * 0.44, weight: .medium))
                .foregroundStyle(color)
        }
    }
}

/// Una fila de la lista. Con `bloqueado` conserva el horario pero tapa el nombre.
private struct FilaBloque: View {
    let bloque: BloqueWidget
    var bloqueado: Bool = false
    var compacta: Bool = false

    var body: some View {
        HStack(spacing: 9) {
            if bloqueado {
                ZStack {
                    Circle().fill(Color.wSeparador)
                        .frame(width: compacta ? 26 : 30, height: compacta ? 26 : 30)
                    Image(systemName: "lock.fill")
                        .font(.system(size: compacta ? 11 : 12, weight: .semibold))
                        .foregroundStyle(Color.wTextoSecundario)
                }
            } else {
                IconoBloque(bloque: bloque, lado: compacta ? 26 : 30)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(bloqueado ? "Contenido bloqueado" : bloque.titulo)
                    .font(fuente(compacta ? 12 : 13, .semibold))
                    .foregroundStyle(bloqueado ? Color.wTextoSecundario : Color.wTextoPrimario)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(verbatim: "\(formatoHora(bloque.minutoInicio))–\(formatoHora(bloque.minutoFin))")
                    if !bloqueado, !bloque.aula.isEmpty {
                        Text(verbatim: "·")
                        Text(verbatim: bloque.aula).lineLimit(1)
                    }
                }
                .font(fuente(compacta ? 10 : 11))
                .foregroundStyle(Color.wTextoSecundario)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Estado vacío: no hay nada agendado hoy.
private struct SinClases: View {
    var compacto: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: compacto ? 20 : 24))
                .foregroundStyle(Color(hexWidget: "FFB36B"))
            Text("Sin clases hoy")
                .font(fuente(compacto ? 13 : 15, .semibold))
                .foregroundStyle(Color.wTextoPrimario)
            if !compacto {
                Text("Disfruta el día")
                    .font(fuente(11)).foregroundStyle(Color.wTextoSecundario)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Pie que aparece en mediano y grande cuando el usuario no es Premium.
private struct PieBloqueo: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.fill").font(.system(size: 9, weight: .semibold))
            Text("Desbloquea tu horario con Premium").font(fuente(10, .medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(hexWidget: "E8850C"))
    }
}

// MARK: - Cabecera

private struct Cabecera: View {
    let entrada: EntradaHorario
    var mostrarCurso: Bool = false

    private var fechaTexto: String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEE d")
        return f.string(from: entrada.date).capitalized
    }
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text("HOY")
                    .font(fuente(10, .bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.wTextoSecundario)
                if mostrarCurso, !entrada.nombreCurso.isEmpty {
                    Text(verbatim: entrada.nombreCurso)
                        .font(fuente(13, .semibold))
                        .foregroundStyle(Color.wTextoPrimario)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Text(verbatim: fechaTexto)
                .font(fuente(10, .medium))
                .foregroundStyle(Color.wTextoSecundario)
                .lineLimit(1)
        }
    }
}

// MARK: - Tamaño pequeño

private struct VistaPequena: View {
    let entrada: EntradaHorario

    /// El bloque en curso, o el siguiente que quede por delante.
    private var proximo: BloqueWidget? {
        let c = Calendar.current.dateComponents([.hour, .minute], from: entrada.date)
        let ahora = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return entrada.bloques.first { $0.minutoFin > ahora } ?? entrada.bloques.last
    }

    var body: some View {
        // El tamaño pequeño es GRATIS: enseña la clase en curso o la siguiente.
        // Sirve de aperitivo — quien lo usa a diario acaba queriendo ver el día
        // entero, que es lo que dan el mediano y el grande (Premium).
        if let b = proximo {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    IconoBloque(bloque: b, lado: 32)
                    Spacer(minLength: 0)
                    Text("HOY")
                        .font(fuente(9, .bold)).tracking(1)
                        .foregroundStyle(Color.wTextoSecundario)
                }
                Spacer(minLength: 0)
                Text(verbatim: b.titulo)
                    .font(fuente(15, .semibold))
                    .foregroundStyle(Color.wTextoPrimario)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: "\(formatoHora(b.minutoInicio))–\(formatoHora(b.minutoFin))")
                        .font(fuente(12, .medium))
                        .foregroundStyle(Color.wTextoPrimario)
                    if !b.aula.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin").font(.system(size: 8))
                            Text(verbatim: b.aula).lineLimit(1)
                        }
                        .font(fuente(10))
                        .foregroundStyle(Color.wTextoSecundario)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            SinClases(compacto: true)
        }
    }
}

// MARK: - Tamaño mediano

private struct VistaMediana: View {
    let entrada: EntradaHorario

    private var restantes: [BloqueWidget] {
        let c = Calendar.current.dateComponents([.hour, .minute], from: entrada.date)
        let ahora = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let pendientes = entrada.bloques.filter { $0.minutoFin > ahora }
        // Si el día ya terminó se muestran los últimos, no una tarjeta vacía
        return Array((pendientes.isEmpty ? entrada.bloques : pendientes).prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Cabecera(entrada: entrada)
            if entrada.bloques.isEmpty {
                SinClases()
            } else {
                // Sin Premium se conservan los horarios y se tapan los nombres:
                // deja ver que el widget sirve, sin regalar el contenido.
                ForEach(restantes) { b in
                    FilaBloque(bloque: b, bloqueado: !entrada.esPremium, compacta: true)
                }
                Spacer(minLength: 0)
                if !entrada.esPremium { PieBloqueo() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Tamaño grande

private struct VistaGrande: View {
    let entrada: EntradaHorario

    private var ahoraMin: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: entrada.date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Cabecera(entrada: entrada, mostrarCurso: true)

            if entrada.bloques.isEmpty {
                SinClases()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entrada.bloques.prefix(6).enumerated()), id: \.element.id) { i, b in
                        if i > 0 {
                            Rectangle().fill(Color.wSeparador)
                                .frame(height: 0.7)
                                .padding(.leading, 39)
                                .padding(.vertical, 5)
                        }
                        HStack(spacing: 0) {
                            FilaBloque(bloque: b, bloqueado: !entrada.esPremium)
                            // Marca discreta del bloque que está ocurriendo
                            if entrada.esPremium,
                               b.minutoInicio <= ahoraMin, ahoraMin < b.minutoFin {
                                Text("AHORA")
                                    .font(fuente(8, .bold)).tracking(0.6)
                                    .foregroundStyle(Color.wFondo)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Capsule().fill(Color.wTextoPrimario))
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                if entrada.esPremium {
                    if entrada.bloques.count > 6 {
                        Text("y \(entrada.bloques.count - 6) más")
                            .font(fuente(10)).foregroundStyle(Color.wTextoSecundario)
                    }
                } else {
                    PieBloqueo()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Ensamblado

struct VistaHorarissWidget: View {
    @Environment(\.widgetFamily) private var familia
    let entrada: EntradaHorario

    var body: some View {
        Group {
            switch familia {
            case .systemSmall:  VistaPequena(entrada: entrada)
            case .systemLarge:  VistaGrande(entrada: entrada)
            default:            VistaMediana(entrada: entrada)
            }
        }
        .widgetURL(enlaceApp)
        .containerBackground(Color.wFondo, for: .widget)
    }
}

struct HorarissWidget: Widget {
    let kind = "HorarissWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProveedorHorario()) { entrada in
            VistaHorarissWidget(entrada: entrada)
        }
        .configurationDisplayName("Mi horario")
        .description("Tus clases y bloques de hoy, de un vistazo.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct HorarissWidgetBundle: WidgetBundle {
    var body: some Widget { HorarissWidget() }
}

// MARK: - Datos de ejemplo (galería de widgets y vistas previas)

extension BloqueWidget {
    static let ejemplo: [BloqueWidget] = [
        BloqueWidget(id: "e1", titulo: "Taller de Proyectos IV",
                     colorHex: "7B61FF", colorHexOscuro: "7B61FF", icono: "cube.fill",
                     dia: 1, hora: 7, minuto: 0, duracionMin: 120,
                     aula: "Aula 203", tipo: .materia),
        BloqueWidget(id: "e2", titulo: "Tiempo para comer",
                     colorHex: "FF9F45", colorHexOscuro: "FF9F45", icono: "fork.knife",
                     dia: 1, hora: 9, minuto: 30, duracionMin: 60,
                     aula: "", tipo: .libre),
        BloqueWidget(id: "e3", titulo: "Teoría de la arquitectura II",
                     colorHex: "7CC7FF", colorHexOscuro: "7CC7FF", icono: "compass.drawing",
                     dia: 1, hora: 11, minuto: 0, duracionMin: 120,
                     aula: "Lab. 2", tipo: .materia),
        BloqueWidget(id: "e4", titulo: "Hora de estudio",
                     colorHex: "6E6E78", colorHexOscuro: "B4B4BE", icono: "book.closed.fill",
                     dia: 1, hora: 14, minuto: 0, duracionMin: 90,
                     aula: "", tipo: .estudio)
    ]
}
