import SwiftUI

// Los componentes que se reutilizan por toda la app. Antes de escribir un
// botón o una tarjeta nueva, mira si ya está aquí: es la regla de oro del
// proyecto.
//
// Todos llevan init escrito a mano. El memberwise que sintetiza Swift es
// internal, así que al cruzar módulo dejaría de verse desde la app.

public struct Tarjeta<C: View>: View {
    public let content: C
    public init(@ViewBuilder _ c: () -> C) { content = c() }
    public var body: some View {
        content
            .background(DS.fondoTarjeta)
            .clipShape(RoundedRectangle(cornerRadius: DS.radio))
            .shadow(color: .black.opacity(0.09), radius: 16, x: 0, y: 6)
    }
}

public struct BtnPrincipal: View {
    public let titulo: LocalizedStringKey
    public var color: Color = DS.textoPrimario
    public var degradado: LinearGradient? = nil
    public var degradadoPurpura: Bool = false
    public var disabled: Bool = false
    public let accion: () -> Void

    /// El init va escrito a mano porque el memberwise que sintetiza Swift es
    /// internal. El ORDEN y los valores por omisión se conservan tal cual: hay
    /// decenas de llamadas que dependen de poder omitir casi todo.
    public init(titulo: LocalizedStringKey,
                color: Color = DS.textoPrimario,
                degradado: LinearGradient? = nil,
                degradadoPurpura: Bool = false,
                disabled: Bool = false,
                accion: @escaping () -> Void) {
        self.titulo = titulo; self.color = color
        self.degradado = degradado; self.degradadoPurpura = degradadoPurpura
        self.disabled = disabled; self.accion = accion
    }

    public var body: some View {
        Button(action: accion) {
            Text(titulo)
                .font(DS.semibold(16))
                // Sobre degradados o gris el blanco funciona en ambos modos;
                // sobre el fondo sólido (textoPrimario) hay que invertir.
                .foregroundColor(degradado != nil || degradadoPurpura || disabled
                                 ? .white : DS.textoInvertido)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if disabled {
                            AnyView(Color.gray.opacity(0.3))
                        } else if degradadoPurpura {
                            AnyView(DS.gradientePurpura)
                        } else if let g = degradado {
                            AnyView(g)
                        } else {
                            AnyView(color)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.radio))
        }
        .disabled(disabled)
        .animation(.easeInOut(duration: 0.15), value: disabled)
    }
}

public struct PuntosAnimados: View {
    @State private var salta = false

    public init() {}
    public var body: some View {
        HStack(spacing: 5) {
            Text("Pensando").font(DS.etiqueta(13)).foregroundColor(DS.textoSecundario)
            ForEach(0..<3) { i in
                Circle().fill(Color.hex("A294F9")).frame(width: 5, height: 5)
                    // -5.0 y no -5: Kotlin no convierte Int a Double por su cuenta.
                    .offset(y: salta ? -5.0 : 0.0)
                    .animation(.easeInOut(duration: 0.38).repeatForever().delay(Double(i) * 0.14), value: salta)
            }
        }
        .onAppear { salta = true }
    }
}

public struct VacioView: View {
    public let sf: String
    public let titulo: LocalizedStringKey
    public let sub: LocalizedStringKey

    public init(sf: String, titulo: LocalizedStringKey, sub: LocalizedStringKey) {
        self.sf = sf; self.titulo = titulo; self.sub = sub
    }
    public var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(DS.azulCielo.opacity(0.22)).frame(width: 60, height: 60)
                Image(systemName: sf).font(.system(size: 24)).foregroundColor(DS.azulCielo)
            }
            VStack(spacing: 4) {
                Text(titulo).font(DS.semibold(15)).foregroundColor(DS.textoPrimario)
                Text(sub).font(DS.cuerpo(12)).foregroundColor(DS.textoSecundario)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.vertical, 26)
        .padding(.horizontal, 28)
    }
}

public struct Linea: View {
    public var color: Color = DS.azulCielo
    /// Si el campo está enfocado. Antes era un `@FocusState.Binding`, que Skip
    /// no soporta; quien llama pasa ahora el valor y no el binding. El efecto
    /// es el mismo y el componente queda más simple.
    public var focus: Bool

    public init(color: Color = DS.azulCielo, focus: Bool) {
        self.color = color
        self.focus = focus
    }
    public var body: some View {
        Rectangle()
            .fill(focus ? color : DS.separador)
            .frame(height: 2)
            .animation(.easeInOut(duration: 0.2), value: focus)
    }
}

public extension View {
    /// Qué parte de la vista responde al toque. `contentShape` no existe en
    /// SkipUI, y en Android no hace falta: allí un toque cuenta en todo el
    /// recuadro de la vista, también en sus huecos transparentes.
    func zonaDeToque<S: Shape>(_ forma: S) -> some View {
        #if SKIP
        return self
        #else
        return contentShape(forma)
        #endif
    }
}

public extension View {
    /// Que una capa decorativa (un degradado encima de la lista, por ejemplo)
    /// no intercepte los toques. En Android `allowsHitTesting(false)` de SkipUI
    /// hacía lo contrario: con el difuminado del final de Tareas encima, no
    /// llegaba ningún toque a las tarjetas de debajo. Allí no hace falta nada:
    /// una vista sin acciones ya deja pasar el toque.
    func sinToques() -> some View {
        #if SKIP
        return self
        #else
        return allowsHitTesting(false)
        #endif
    }
}

public extension AnyTransition {
    static var asimetrico: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity))
    }
}

public extension Array {
    /// Acceso que devuelve nil en vez de reventar si el índice se sale.
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

public extension View {
    /// Pone contenido como pastilla flotante abajo, con lo demás pasando por
    /// detrás al desplazarse. Es el patrón de botón principal del proyecto, y
    /// **no lleva fondo detrás**: se quitó porque recortaba las tarjetas con un
    /// borde duro.
    ///
    /// Existe como envoltorio porque **`.safeAreaInset` no está en SkipUI**,
    /// comprobado en la prueba de humo del 26/09.
    ///
    /// En Android el botón va DEBAJO del contenido, no encima: así reserva su
    /// hueco igual que `safeAreaInset`. Antes era un `overlay`, que lo tapaba,
    /// y cada lista necesitaba su propio relleno inferior o las últimas filas
    /// quedaban debajo del botón. Lo que se pierde en Android es que el
    /// contenido pase por detrás al desplazarse.
    func botonFlotanteAbajo<C: View>(@ViewBuilder _ contenido: () -> C) -> some View {
        // `SKIP` solo se define en modo transpilado y `os(Android)` solo es cierto en
        // modo nativo, así que el guarda nombra los dos. Comprobado el 26/09 con las dos
        // pruebas de humo.
#if SKIP || os(Android)
        return VStack(spacing: 0) {
            self.frame(maxHeight: .infinity)
            contenido()
        }
#else
        return safeAreaInset(edge: .bottom) { contenido() }
#endif
    }

    /// La pastilla de cristal de la barra de pestañas.
    ///
    /// **SkipUI no tiene `Material`**: `Graphics/Material.swift` está entero
    /// dentro de un comentario de bloque en el paquete, así que
    /// `.ultraThinMaterial` ni siquiera compila en Android. Un difuminado de
    /// verdad pediría bajar al `Modifier.blur` de Compose y capturar lo que
    /// hay detrás, que es justo el trabajo que la v1 de Android no hace.
    ///
    /// Se queda en un relleno traslúcido, que es lo que el usuario aceptó
    /// cuando se recortó el alcance: «tendrá que ser un difuminado común».
    /// Encima de una lista que se desplaza se lee bien, y a cambio no arrastra
    /// ninguna dependencia de Compose.
    @ViewBuilder
    func pastillaDeCristal() -> some View {
#if SKIP || os(Android)
        background(DS.fondoTarjeta.opacity(0.92), in: Capsule())
#else
        // El `macOS 26` no sobra: `HorarissUI` también compila para el host, que
        // es lo que mantiene `swift test` en un segundo. Mientras esto vivía en
        // HorarissVistas —solo iOS— bastaba con la comprobación de iOS.
        if #available(iOS 26, macOS 26, *) {
            // .interactive() da la respuesta táctil característica de Liquid Glass
            glassEffect(.regular.interactive(), in: Capsule())
        } else {
            background(.ultraThinMaterial, in: Capsule())
        }
#endif
    }
}
