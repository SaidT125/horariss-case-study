import SwiftUI
#if canImport(UIKit) && !SKIP
import UIKit
#endif

// ============================================================
// MARK: - TECLADO
// ============================================================

// Vive en HorarissUI porque lo usan los formularios de todos los módulos: el
// login, Inicio y lo que queda en HorarissVistas. Este módulo también se
// compila para macOS (las pruebas rápidas), donde no hay UIKit ni teclado.

// Cierra cualquier teclado activo. En Android no hace falta: el teclado trae su
// propio botón para cerrarse, y UIApplication no existe.
@MainActor
public func ocultarTeclado() {
    #if canImport(UIKit) && !SKIP
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #endif
}

// Agrega una barra con botón "Listo" encima del teclado y permite cerrarlo tocando fuera
private struct TecladoDescartable: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS) && !SKIP
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") { ocultarTeclado() }
                        .font(DS.semibold(17))
                        .foregroundColor(DS.azulCielo)
                        // Separación para que no se empalme con el teclado
                        .padding(.trailing, 6)
                        .padding(.vertical, 6)
                }
            }
        #else
        // En Android la barra «Listo» sobra: el teclado ya lo trae
        content
        #endif
    }
}

public extension View {
    func tecladoConListo() -> some View { modifier(TecladoDescartable()) }
}
