import Foundation

public enum Novedades {
    /// Etiqueta de la tanda actual. **Cambiarla es lo que hace que la pantalla
    /// de novedades vuelva a aparecer**: si se publica una corrección menor y no
    /// hay nada que contar, se deja igual y nadie ve el aviso.
    ///
    /// Solo la etiqueta vive aquí. La lista de novedades lleva iconos y colores,
    /// o sea presentación, y está en la app como extensión.
    public static let version = "1.5"
}
