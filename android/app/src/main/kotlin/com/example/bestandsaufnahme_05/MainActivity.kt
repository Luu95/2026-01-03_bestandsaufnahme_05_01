package com.example.bestandsaufnahme_05

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.DocumentsContract
import androidx.activity.result.contract.ActivityResultContracts
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.bestandsaufnahme_05/backup_storage"
    private var pendingPickResult: MethodChannel.Result? = null
    private lateinit var directoryPickerLauncher: androidx.activity.result.ActivityResultLauncher<Intent>

    override fun onCreate(savedInstanceState: Bundle?) {
        directoryPickerLauncher = registerForActivityResult(
            ActivityResultContracts.StartActivityForResult(),
        ) { activityResult ->
            val callback = pendingPickResult
            pendingPickResult = null
            if (callback == null) return@registerForActivityResult

            if (activityResult.resultCode != RESULT_OK || activityResult.data?.data == null) {
                callback.success(null)
                return@registerForActivityResult
            }

            val uri = activityResult.data!!.data!!
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                )
            } catch (_: SecurityException) {
                // Schreibversuch folgt beim Backup.
            }

            callback.success(
                mapOf(
                    "uri" to uri.toString(),
                    "displayPath" to getTreeDisplayName(uri),
                ),
            )
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickDirectory" -> {
                        pendingPickResult?.success(null)
                        pendingPickResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
                            )
                        }
                        try {
                            directoryPickerLauncher.launch(intent)
                        } catch (e: Exception) {
                            pendingPickResult = null
                            result.error("PICK_FAILED", e.message, null)
                        }
                    }

                    "writeFile" -> {
                        val treeUriRaw = call.argument<String>("treeUri")
                        val fileName = call.argument<String>("fileName")
                        val bytes = call.argument<ByteArray>("bytes")
                        if (treeUriRaw.isNullOrBlank() || fileName.isNullOrBlank() || bytes == null) {
                            result.error("INVALID_ARGS", "Missing arguments", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val treeUri = Uri.parse(treeUriRaw)
                            val savedPath = writeFileToTree(treeUri, fileName, bytes)
                            result.success(savedPath)
                        } catch (e: Exception) {
                            result.error("WRITE_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun getTreeDisplayName(treeUri: Uri): String {
        val docId = DocumentsContract.getTreeDocumentId(treeUri)
        if (docId.isNotBlank()) {
            val parts = docId.split(':')
            if (parts.size > 1 && parts.last().isNotBlank()) {
                return parts.last()
            }
        }
        return treeUri.lastPathSegment ?: treeUri.toString()
    }

    private fun writeFileToTree(treeUri: Uri, fileName: String, bytes: ByteArray): String {
        val docTree = DocumentFile.fromTreeUri(this, treeUri)
            ?: throw Exception("Backup-Ordner nicht zugänglich")

        docTree.findFile(fileName)?.delete()

        val mimeType = if (fileName.endsWith(".zip", ignoreCase = true)) {
            "application/zip"
        } else {
            "application/octet-stream"
        }

        val created = docTree.createFile(mimeType, fileName)
            ?: throw Exception("Datei konnte im Ordner nicht erstellt werden")

        contentResolver.openOutputStream(created.uri)?.use { stream ->
            stream.write(bytes)
            stream.flush()
        } ?: throw Exception("Schreiben in den Ordner fehlgeschlagen")

        return "${getTreeDisplayName(treeUri)}/$fileName"
    }
}
