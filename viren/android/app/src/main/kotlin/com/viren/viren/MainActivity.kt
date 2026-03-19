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
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.tasks.await
import org.json.JSONObject
import java.io.File


class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.viren.viren/pdf_crypto"

    private var llmInference: LlmInference? = null
    private var llmModelPath: String? = null
    private val llmMutex = Mutex()

    // Timestamp of last completed inference — used for cooldown
    private var lastInferenceEndMs: Long = 0L

    // Minimum gap between inferences to let the CPU breathe
    private val INFERENCE_COOLDOWN_MS = 1500L

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
                                val stripper = PDFTextStripper().apply { sortByPosition = true }
                                extractedText = stripper.getText(document)
                            } catch (e: Exception) {
                                val msg = e.message ?: ""
                                if (msg.contains("password", ignoreCase = true) ||
                                    msg.contains("decryption", ignoreCase = true)
                                ) {
                                    CoroutineScope(Dispatchers.Main).launch {
                                        result.error("INCORRECT_PASSWORD", "The PAN provided was incorrect.", msg)
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
                            CoroutineScope(Dispatchers.Main).launch { result.success(jsonResponse) }
                        } catch (e: Exception) {
                            CoroutineScope(Dispatchers.Main).launch {
                                result.error("EXTRACTION_ERROR", "Pipeline failed.", e.message)
                            }
                        }
                    }
                }

                "getModelPath" -> {
                    result.success(applicationContext.filesDir.absolutePath)
                }

                "extractAiTrades" -> {
                    val promptText = call.argument<String>("promptText")
                    val modelPath = call.argument<String>("modelPath")
                    if (promptText == null || modelPath == null) {
                        result.error("INVALID_ARGS", "Missing promptText or modelPath.", null)
                        return@setMethodCallHandler
                    }
                    if (!File(modelPath).exists()) {
                        result.error("MODEL_MISSING", "AI model not downloaded yet.", null)
                        return@setMethodCallHandler
                    }
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val inference = getOrCreateLlmInference(modelPath)
                            val response = inference.generateResponse(promptText)
                            lastInferenceEndMs = System.currentTimeMillis()
                            CoroutineScope(Dispatchers.Main).launch { result.success(response) }
                        } catch (e: Exception) {
                            android.util.Log.e("VirenLLM", "extractAiTrades error — resetting instance", e)
                            resetLlmInstance()
                            CoroutineScope(Dispatchers.Main).launch {
                                result.error("AI_ERROR", "MediaPipe inference failed.", e.message)
                            }
                        }
                    }
                }

                "chat" -> {
                    val prompt = call.argument<String>("prompt")
                    val modelPath = call.argument<String>("modelPath")
                    android.util.Log.d("VirenLLM", "Received modelPath: $modelPath")

                    if (prompt == null || modelPath == null) {
                        result.error("INVALID_ARGS", "Missing prompt or modelPath.", null)
                        return@setMethodCallHandler
                    }
                    val llmFile = File(modelPath)
                    android.util.Log.d("VirenLLM", "File exists: ${llmFile.exists()}, size: ${llmFile.length()}")
                    if (!llmFile.exists()) {
                        result.error("MODEL_MISSING", "AI model not downloaded yet.", null)
                        return@setMethodCallHandler
                    }

                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            // Enforce cooldown to prevent thermal crash buildup
                            val msSinceLast = System.currentTimeMillis() - lastInferenceEndMs
                            if (lastInferenceEndMs > 0 && msSinceLast < INFERENCE_COOLDOWN_MS) {
                                val waitMs = INFERENCE_COOLDOWN_MS - msSinceLast
                                android.util.Log.d("VirenLLM", "Thermal cooldown: waiting ${waitMs}ms")
                                delay(waitMs)
                            }

                            val inference = getOrCreateLlmInference(modelPath)
                            val response = inference.generateResponse(prompt) ?: "I could not process that."
                            lastInferenceEndMs = System.currentTimeMillis()

                            CoroutineScope(Dispatchers.Main).launch { result.success(response) }
                        } catch (e: Exception) {
                            android.util.Log.e("VirenLLM", "Chat error — resetting LLM instance", e)
                            resetLlmInstance()
                            CoroutineScope(Dispatchers.Main).launch {
                                result.error(
                                    "CHAT_ERROR",
                                    "The model hit a limit and has been reset. Please try again.",
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

    private suspend fun getOrCreateLlmInference(modelPath: String): LlmInference {
        return llmMutex.withLock {
            if (llmInference != null && llmModelPath == modelPath) {
                android.util.Log.d("VirenLLM", "Reusing existing LlmInference.")
                llmInference!!
            } else {
                if (llmInference != null) {
                    android.util.Log.d("VirenLLM", "Rebuilding LlmInference.")
                    try { llmInference!!.close() } catch (_: Exception) {}
                    llmInference = null
                    llmModelPath = null
                }

                android.util.Log.d("VirenLLM", "Loading model from: $modelPath")

                val options = LlmInference.LlmInferenceOptions.builder()
                    .setModelPath(modelPath)
                    // 512 tokens: enough for all Viren responses (system prompt caps at ~150 words),
                    // halves the native KV cache vs 1024, significantly cuts thermal + memory load.
                    // reverted back to 1024 as 512 was not enough
                    .setMaxTokens(1024)
                    .setPreferredBackend(LlmInference.Backend.CPU)
                    .build()

                val instance = LlmInference.createFromOptions(applicationContext, options)
                llmInference = instance
                llmModelPath = modelPath
                android.util.Log.d("VirenLLM", "Model loaded. CPU, maxTokens=512.")
                instance
            }
        }
    }

    /**
     * Destroys the current LlmInference instance so the next
     * request gets a clean rebuild. Called after any inference crash.
     */
    private fun resetLlmInstance() {
        CoroutineScope(Dispatchers.IO).launch {
            llmMutex.withLock {
                try { llmInference?.close() } catch (_: Exception) {}
                llmInference = null
                llmModelPath = null
                android.util.Log.d("VirenLLM", "LlmInference instance reset after crash.")
            }
        }
    }

    private suspend fun performOcrOnPdf(pdfFile: File, password: String): String {
        val tempFile = File(applicationContext.cacheDir, "temp_decrypted_${System.currentTimeMillis()}.pdf")
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
            fd = ParcelFileDescriptor.open(tempFile, ParcelFileDescriptor.MODE_READ_ONLY)
            renderer = PdfRenderer(fd)
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            val scale = 300f / 72f

            for (i in 0 until renderer.pageCount) {
                var page: PdfRenderer.Page? = null
                try {
                    page = renderer.openPage(i)
                    val w = (page.width * scale).toInt()
                    val h = (page.height * scale).toInt()
                    val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                    val canvas = android.graphics.Canvas(bitmap)
                    canvas.drawColor(android.graphics.Color.WHITE)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
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