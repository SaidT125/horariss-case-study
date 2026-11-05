import Foundation

/// Los apuntes pueden pesar bastante más que las materias, y UserDefaults no
/// está pensado para eso (se carga entero en memoria al arrancar). Van a un
/// archivo JSON en Documentos.
public enum ArchivoLocal {
    /// `URL.documentsDirectory` y no `FileManager.urls(for:in:)`: en Skip ese
    /// método está marcado `unavailable`. En iOS las dos dan la MISMA carpeta,
    /// así que los apuntes que ya están guardados no se mueven; en Android es
    /// la carpeta privada de la app (`getFilesDir()`).
    public static func url(_ nombre: String) -> URL {
        URL.documentsDirectory.appendingPathComponent(nombre)
    }
    /// Recibe los bytes ya codificados, igual que `datos(de:)` los devuelve. Un
    /// `guardar<T: Encodable>` genérico no cruza a Kotlin: allí un arreglo no
    /// entra por un parámetro `T: Encodable`.
    public static func guardar(_ datos: Data, en nombre: String) {
        // El tipo va escrito: el transpilador no deduce el dueño de `.atomic`.
        try? datos.write(to: url(nombre), options: Data.WritingOptions.atomic)
    }
    /// Devuelve los bytes y deja que quien llama decodifique con su tipo
    /// concreto. Un `leer<T: Decodable>` genérico no cruza a Kotlin: allí
    /// `decode` necesita el tipo en tiempo de ejecución (`reified`), y dentro
    /// de una función genérica ese tipo ya se ha borrado.
    public static func datos(de nombre: String) -> Data? {
        try? Data(contentsOf: url(nombre))
    }
}
