package com.viren.viren

import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONObject
import java.io.File

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.viren.viren/pdf_crypto"
    private var llmInference: LlmInference? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        PDFBoxResourceLoader.init(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "decryptAndExtract" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val password = call.argument<String>("password")
                    if (inputPath == null || password == null) {
                        result.error("INVALID_ARGS", "Missing required arguments.", null)
                        return@setMethodCallHandler
                    }
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            var extractedText = ""
                            var methodUsed = "PDFBox"
                            val file = File(inputPath)
                            var document: PDDocument? = null
                            try {
                                document = PDDocument.load(file, password)
                                val stripper = PDFTextStripper().apply {
                                    sortByPosition = true
                                }
                                extractedText = stripper.getText(document)
                            } catch (e: Exception) {
                                val msg = e.message ?: ""
                                if (msg.contains("password", ignoreCase = true) ||
                                    msg.contains("decryption", ignoreCase = true)
                                ) {
                                    CoroutineScope(Dispatchers.Main).launch {
                                        result.error(
                                            "INCORRECT_PASSWORD",
                                            "The PAN provided was incorrect.",
                                            msg
                                        )
                                    }
                                    document?.close()
                                    return@launch
                                }
                                throw e
                            } finally {
                                document?.close()
                            }
                            if (extractedText.trim().length < 50) {
                                methodUsed = "OCR"
                                extractedText = performOcrOnPdf(file, password)
                            }
                            val jsonResponse = JSONObject().apply {
                                put("text", extractedText)
                                put("method", methodUsed)
                            }.toString()
                            CoroutineScope(Dispatchers.Main).launch {
                                result.success(jsonResponse)
                            }
                        } catch (e: Exception) {
                            CoroutineScope(Dispatchers.Main).launch {
                                result.error(
                                    "EXTRACTION_ERROR",
                                    "Pipeline failed during PDF extraction.",
                                    e.message
                                )
                            }
                        }
                    }
                }

                "extractAiTrades" -> {
                    val promptText = call.argument<String>("promptText")
                    if (promptText == null) {
                        result.error("INVALID_ARGS", "Missing promptText.", null)
                        return@setMethodCallHandler
                    }
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            if (llmInference == null) {
                                val llmFile = File(
                                    applicationContext.cacheDir,
                                    "llm_model.bin"
                                )
                                if (!llmFile.exists()) {
                                    try {
                                        applicationContext.assets
                                            .open("llm/model.bin")
                                            .use { input ->
                                                llmFile.outputStream()
                                                    .use { output ->
                                                        input.copyTo(output)
                                                    }
                                            }
                                    } catch (e: Exception) {
                                        CoroutineScope(Dispatchers.Main).launch {
                                            result.error(
                                                "MODEL_MISSING",
                                                "MediaPipe model not found in assets/llm/model.bin",
                                                e.message
                                            )
                                        }
                                        return@launch
                                    }
                                }
                                val options = LlmInference.LlmInferenceOptions
                                    .builder()
                                    .setModelPath(llmFile.absolutePath)
                                    .setMaxTokens(2048)
                                    .setTemperature(0.0f)
                                    .build()
                                llmInference = LlmInference.createFromOptions(
                                    applicationContext,
                                    options
                                )
                            }
                            val response =
                                llmInference?.generateResponse(promptText) ?: ""
                            CoroutineScope(Dispatchers.Main).launch {
                                result.success(response)
                            }
                        } catch (e: Exception) {
                            CoroutineScope(Dispatchers.Main).launch {
                                result.error(
                                    "AI_ERROR",
                                    "MediaPipe inference failed.",
                                    e.message
                                )
                            }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private suspend fun performOcrOnPdf(
        pdfFile: File,
        password: String
    ): String {
        val tempFile = File(
            applicationContext.cacheDir,
            "temp_decrypted_${System.currentTimeMillis()}.pdf"
        )
        var document: PDDocument? = null
        try {
            document = PDDocument.load(pdfFile, password)
            document.setAllSecurityToBeRemoved(true)
            document.save(tempFile)
        } finally {
            document?.close()
        }

        val sb = StringBuilder()
        var fd: ParcelFileDescriptor? = null
        var renderer: PdfRenderer? = null

        try {
            fd = ParcelFileDescriptor.open(
                tempFile,
                ParcelFileDescriptor.MODE_READ_ONLY
            )
            renderer = PdfRenderer(fd)
            val recognizer = TextRecognition.getClient(
                TextRecognizerOptions.DEFAULT_OPTIONS
            )
            val scale = 300f / 72f

            for (i in 0 until renderer.pageCount) {
                var page: PdfRenderer.Page? = null
                try {
                    page = renderer.openPage(i)
                    val w = (page.width * scale).toInt()
                    val h = (page.height * scale).toInt()
                    val bitmap = Bitmap.createBitmap(
                        w, h, Bitmap.Config.ARGB_8888
                    )
                    val canvas = android.graphics.Canvas(bitmap)
                    canvas.drawColor(android.graphics.Color.WHITE)
                    page.render(
                        bitmap, null, null,
                        PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY
                    )
                    val image = InputImage.fromBitmap(bitmap, 0)
                    val text = recognizer.process(image).await()
                    sb.append(text.text).append("\n")
                    bitmap.recycle()
                } finally {
                    page?.close()
                }
            }
        } catch (e: Exception) {
            sb.append("[OCR Failed: ${e.message}]")
        } finally {
            renderer?.close()
            fd?.close()
            if (tempFile.exists()) tempFile.delete()
        }

        return sb.toString()
    }
}
