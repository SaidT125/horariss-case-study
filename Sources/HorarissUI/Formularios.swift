import SwiftUI

// Piezas de los flujos paso a paso: la barra con el progreso, la cabecera de
// cada paso y el campo con la línea que se colorea al enfocar. Las usan el
// flujo de materias (HorarissHorario) y el de tareas (HorarissVistas), así que
// viven aquí, donde los dos las ven.

public func barraFlujo(total: Int, actual: Int, onBack: @escaping () -> Void) -> some View {
    HStack(spacing: 12) {
        Button(action: onBack) {
            Image(systemName: actual == 0 ? "xmark" : "chevron.left")
                .font(.system(size: 15, weight: .medium)).foregroundColor(DS.textoPrimario)
                .frame(width: 36, height: 36).background(DS.fondoTarjeta).clipShape(Circle())
        }
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(DS.separador).frame(height: 3)
                Capsule().fill(DS.azulCielo)
                    .frame(width: g.size.width * CGFloat(actual + 1) / CGFloat(total), height: 3)
                    .animation(.spring(response: 0.4), value: actual)
            }
        }.frame(height: 3)
        Text("\(actual + 1)/\(total)").font(DS.etiqueta(12)).foregroundColor(DS.textoSecundario)
    }
    .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 28)
}

public func cabeceraPaso(icono: String, color: Color, titulo: LocalizedStringKey) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        ZStack {
            Circle().fill(color.opacity(0.18)).frame(width: 56, height: 56)
            Image(systemName: icono).font(.system(size: 24)).foregroundColor(color)
        }
        Text(titulo).font(DS.titulo(26)).foregroundColor(DS.textoPrimario)
            .fixedSize(horizontal: false, vertical: true)
            .minimumScaleFactor(0.8)
    }
}

// El `$foco` de un @FocusState es un FocusState<Bool>.Binding en iOS y un
// Binding<Bool> corriente en SkipUI, que no conoce el primero.
#if SKIP
public typealias EnlaceFoco = Binding<Bool>
#else
public typealias EnlaceFoco = FocusState<Bool>.Binding
#endif

public func campoSubrayado(placeholder: LocalizedStringKey, texto: Binding<String>,
                           foco: EnlaceFoco, acento: Color) -> some View {
    VStack(spacing: 0) {
        TextField(placeholder, text: texto)
            .font(DS.inter(22, .regular))
            .focused(foco).padding(.bottom, 10)
        Rectangle().fill(foco.wrappedValue ? acento : DS.separador).frame(height: 2)
            .animation(.easeInOut(duration: 0.2), value: foco.wrappedValue)
    }
}

// Las ruedas de iOS y el campo que crece por rangos no existen en SkipUI. En
// Android cada uno usa lo propio de allí, así que el código de las vistas es
// el mismo en las dos plataformas.
public extension View {
    /// La rueda para elegir una hora. En Android el selector abre el reloj de
    /// Material, que es el estilo por omisión de SkipUI.
    func horaEnRueda() -> some View {
        // La rueda tampoco existe en macOS, donde corren las pruebas rápidas
        #if SKIP || !os(iOS)
        return self
        #else
        return datePickerStyle(.wheel)
        #endif
    }

    /// El calendario de mes completo. En Android el selector abre el calendario
    /// de Material, el estilo por omisión de SkipUI.
    func calendarioEnGrafico() -> some View {
        #if SKIP
        return self
        #else
        return datePickerStyle(.graphical)
        #endif
    }

    /// La rueda para una lista corta de opciones, con su alto. En Android, un
    /// menú desplegable.
    func opcionesEnRueda(alto: CGFloat) -> some View {
        #if SKIP || !os(iOS)
        return pickerStyle(.menu)
        #else
        return pickerStyle(.wheel).frame(height: alto)
        #endif
    }

    /// Un campo que ocupa al menos `minimo` líneas y crece hasta `maximo`. En
    /// Android crece desde una línea hasta el máximo.
    func lineas(_ minimo: Int, _ maximo: Int) -> some View {
        #if SKIP
        return lineLimit(maximo)
        #else
        return lineLimit(minimo...maximo)
        #endif
    }
}

/// Que el cambio de un enlace (un interruptor, por ejemplo) anime la vista.
/// `Binding.animation` no existe en SkipUI: en Android el cambio es inmediato.
/// Función y no método de `Binding` porque Skip lee `$valor.metodo(…)` como
/// un campo del valor enlazado.
public func animado<V>(_ enlace: Binding<V>, _ animacion: Animation) -> Binding<V> {
    #if SKIP
    return enlace
    #else
    return enlace.animation(animacion)
    #endif
}

/// Una cuadrícula sin desplazamiento propio, para listas cortas dentro de un
/// ScrollView. En SkipUI `LazyVGrid` se desplaza sola, y dentro de un
/// ScrollView le quita el desplazamiento al contenedor para no anidar dos: la
/// página dejaba de moverse y la cuadrícula se movía por dentro, con lo que
/// quedaba debajo no se podía alcanzar. Las listas de la app son cortas
/// (materias, iconos, colores): la pereza no hace falta.
///
/// En iOS se sigue usando `LazyVGrid`, que ahí no tiene ese problema.
public struct CuadriculaFija<Elemento, Celda: View>: View {
    private let elementos: [Elemento]
    private let columnas: Int
    private let espacioFilas: CGFloat
    private let espacioColumnas: CGFloat
    private let celda: (Elemento) -> Celda

    public init(_ elementos: [Elemento], columnas: Int, espacioFilas: CGFloat,
                espacioColumnas: CGFloat = 8.0, @ViewBuilder celda: @escaping (Elemento) -> Celda) {
        self.elementos = elementos
        self.columnas = columnas
        self.espacioFilas = espacioFilas
        self.espacioColumnas = espacioColumnas
        self.celda = celda
    }

    private var filas: Int { (elementos.count + columnas - 1) / columnas }

    public var body: some View {
        VStack(spacing: espacioFilas) {
            ForEach(0..<filas, id: \.self) { f in
                HStack(spacing: espacioColumnas) {
                    ForEach(0..<columnas, id: \.self) { c in
                        if f * columnas + c < elementos.count {
                            celda(elementos[f * columnas + c]).frame(maxWidth: .infinity)
                        } else {
                            // El hueco de una fila incompleta, para que las
                            // celdas no se estiren
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                        }
                    }
                }
            }
        }
    }
}

/// La pila de una lista dentro de un ScrollView: perezosa en iOS, normal en
/// Android. En SkipUI `LazyVStack` es una LazyColumn con desplazamiento propio
/// que además centra el contenido cuando no llena la pantalla: con una sola
/// tarea, la tarjeta quedaba a media pantalla. Las listas de la app son cortas.
public struct PilaDeLista<Contenido: View>: View {
    private let alineacion: HorizontalAlignment
    private let espacio: CGFloat?
    private let contenido: Contenido

    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil,
                @ViewBuilder content: () -> Contenido) {
        self.alineacion = alignment
        self.espacio = spacing
        self.contenido = content()
    }

    public var body: some View {
        #if SKIP
        VStack(alignment: alineacion, spacing: espacio) { contenido }
        #else
        LazyVStack(alignment: alineacion, spacing: espacio) { contenido }
        #endif
    }
}

public extension View {
    /// `.focused` para un campo que ya trae texto (editar el nombre, el curso,
    /// una tarea). En Android, dentro de una hoja, escribir en un campo así con
    /// el foco controlado cerraba la app: SkipUI vuelve a pedir el foco en cada
    /// redibujado y Compose calcula el cursor con la medida del texto viejo
    /// («offset(3) is out of bounds [0, 3)»). Con el campo vacío no pasa. En
    /// Android el foco no se controla: el usuario toca el campo, como en
    /// cualquier app de allí.
    func focoConTexto(_ foco: EnlaceFoco) -> some View {
        #if SKIP
        return self
        #else
        return focused(foco)
        #endif
    }
}
