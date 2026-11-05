import Foundation
#if SKIP
import SwiftUI
#endif

// ============================================================
// MARK: - ANDROID: ELEGIR UNA FOTO O UN ARCHIVO
// ============================================================

// SkipUI no tiene PhotosPicker ni fileImporter. En Android se usan los
// selectores del sistema a través del registro de resultados de la actividad
// (el mismo mecanismo que el permiso de notificaciones): el selector de fotos,
// que no pide permisos, y el de documentos para los PDF. Lo usan la foto de
// perfil y la importación del horario.
#if SKIP
public enum ElegirArchivo {

    /// Una foto de la galería con el selector de fotos del sistema
    public static func imagen(_ alTerminar: @escaping (Data?) -> Void) {
        guard let registro = registro() else { alTerminar(nil); return }
        var lanzador: androidx.activity.result.ActivityResultLauncher<androidx.activity.result.PickVisualMediaRequest>? = nil
        lanzador = registro.register("horariss_elegir_imagen",
            androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia()) { uri in
            lanzador?.unregister()
            alTerminar(leer(uri))
        }
        let pedido = androidx.activity.result.PickVisualMediaRequest.Builder()
            .setMediaType(androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia.ImageOnly)
            .build()
        lanzador?.launch(pedido)
    }

    /// Un PDF con el selector de documentos del sistema
    public static func pdf(_ alTerminar: @escaping (Data?) -> Void) {
        guard let registro = registro() else { alTerminar(nil); return }
        var lanzador: androidx.activity.result.ActivityResultLauncher<kotlin.Array<String>>? = nil
        lanzador = registro.register("horariss_elegir_pdf",
            androidx.activity.result.contract.ActivityResultContracts.OpenDocument()) { uri in
            lanzador?.unregister()
            alTerminar(leer(uri))
        }
        lanzador?.launch(kotlin.arrayOf("application/pdf"))
    }

    /// Una foto con la cámara. La app de cámara del sistema la escribe en un
    /// archivo de la caché que se le presta por el FileProvider: así no hace
    /// falta pedir el permiso de la cámara ni dejar la foto en la galería.
    public static func foto(_ alTerminar: @escaping (Data?) -> Void) {
        guard let registro = registro() else { alTerminar(nil); return }
        let contexto = ProcessInfo.processInfo.androidContext
        let carpeta = java.io.File(contexto.cacheDir, "fotos")
        carpeta.mkdirs()
        let archivo = java.io.File(carpeta, "camara.jpg")
        archivo.delete()
        let uri = androidx.core.content.FileProvider.getUriForFile(contexto, contexto.packageName + ".archivos", archivo)
        var lanzador: androidx.activity.result.ActivityResultLauncher<android.net.Uri>? = nil
        lanzador = registro.register("horariss_tomar_foto",
            androidx.activity.result.contract.ActivityResultContracts.TakePicture()) { tomada in
            lanzador?.unregister()
            guard tomada == true, archivo.exists() else { alTerminar(nil); return }
            let bytes = archivo.readBytes()
            archivo.delete()
            alTerminar(Data(platformValue: bytes))
        }
        lanzador?.launch(uri)
    }

    /// Si el teléfono tiene cámara (un emulador o una tableta pueden no tenerla)
    public static var hayCamara: Bool {
        ProcessInfo.processInfo.androidContext.packageManager
            .hasSystemFeature(android.content.pm.PackageManager.FEATURE_CAMERA_ANY)
    }

    /// La imagen reducida a `ladoMaximo` píxeles por su lado mayor, en JPEG.
    /// Una foto del teléfono pesa varios MB: para guardarla en las preferencias
    /// o mandarla a la nube basta con mucho menos.
    public static func reducir(_ data: Data, ladoMaximo: Int, calidad: Int = 85) -> Data? {
        guard let bitmap = decodificar(data, ladoMaximo: ladoMaximo) else { return nil }
        return jpeg(bitmap, calidad: calidad)
    }

    /// Decodifica la imagen ya reducida y DERECHA. ImageDecoder aplica la
    /// orientación EXIF; BitmapFactory la ignora, y una foto tomada en vertical
    /// salía de lado. Reducir al decodificar además evita cargar los 12 MP.
    public static func decodificar(_ data: Data, ladoMaximo: Int) -> android.graphics.Bitmap? {
        do {
            let fuente = android.graphics.ImageDecoder.createSource(java.nio.ByteBuffer.wrap(data.platformValue))
            return android.graphics.ImageDecoder.decodeBitmap(fuente) { decoder, info, _ in
                let ancho = info.size.width
                let alto = info.size.height
                let mayor = max(ancho, alto)
                if mayor > ladoMaximo {
                    decoder.setTargetSize(ancho * ladoMaximo / mayor, alto * ladoMaximo / mayor)
                }
                // Un mapa de bits en memoria de gráficos no se puede girar ni
                // volver a comprimir
                decoder.setAllocator(android.graphics.ImageDecoder.ALLOCATOR_SOFTWARE)
            }
        } catch {
            return nil
        }
    }

    public static func jpeg(_ bitmap: android.graphics.Bitmap, calidad: Int) -> Data {
        let salida = java.io.ByteArrayOutputStream()
        bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, calidad, salida)
        return Data(platformValue: salida.toByteArray())
    }

    private static func registro() -> androidx.activity.result.ActivityResultRegistry? {
        (UIApplication.shared.androidActivity as? androidx.activity.ComponentActivity)?.activityResultRegistry
    }

    private static func leer(_ uri: android.net.Uri?) -> Data? {
        guard let uri else { return nil }
        let flujo = ProcessInfo.processInfo.androidContext.contentResolver.openInputStream(uri)
        guard let bytes = flujo?.readBytes() else { return nil }
        flujo?.close()
        return Data(platformValue: bytes)
    }
}
#endif
