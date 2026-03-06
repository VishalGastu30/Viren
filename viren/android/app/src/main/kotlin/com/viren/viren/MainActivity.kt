package com.viren.viren

import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
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

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.viren.viren/pdf_crypto"
    private var llmInference: LlmInference? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize PDFBox
        PDFBoxResourceLoader.init(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
                                    sortByPosition = true // Crucial for NSE Direct table structures
                                }
                                
                                extractedText = stripper.getText(document)
                            } catch (e: Exception) {
                                val msg = e.message ?: ""
                                if (msg.contains("password", ignoreCase = true) || msg.contains("decryption", ignoreCase = true)) {
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
                            
                            // Fallback to OCR if PDFBox yields < 50 chars
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
                                result.error("EXTRACTION_ERROR", "Pipeline failed during PDF extraction.", e.message)
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
                                val assetManager = context.assets
                                val llmFile = File(context.cacheDir, "llm_model.bin")
                                if (!llmFile.exists()) {
                                    try {
                                        assetManager.open("llm/model.bin").use { inputStream ->
                                            llmFile.outputStream().use { outputStream ->
                                                inputStream.copyTo(outputStream)
                                            }
                                        }
                                    } catch (e: Exception) {
                                         CoroutineScope(Dispatchers.Main).launch {
                                            result.error("MODEL_MISSING", "MediaPipe model not found in assets/llm/model.bin", e.message)
                                        }
                                        return@launch
                                    }
                                }
                                
                                val options = LlmInference.LlmInferenceOptions.builder()
                                    .setModelPath(llmFile.absolutePath)
                                    .setMaxTokens(2048)
                                    .setTemperature(0.0f)
                                    .build()
                                    
                                llmInference = LlmInference.createFromOptions(context, options)
                            }
                            
                            // Generate response
                            val response = llmInference?.generateResponse(promptText) ?: ""
                            
                            CoroutineScope(Dispatchers.Main).launch {
                                result.success(response)
                            }
                        } catch (e: Exception) {
                            CoroutineScope(Dispatchers.Main).launch {
                                result.error("AI_ERROR", "MediaPipe inference failed.", e.message)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private suspend fun performOcrOnPdf(pdfFile: File, password: String): String {
        val tempDecryptedFile = File(context.cacheDir, "temp_decrypted_${System.currentTimeMillis()}.pdf")
        var document: PDDocument? = null
        try {
            document = PDDocument.load(pdfFile, password)
            document.setAllSecurityToBeRemoved(true)
            document.save(tempDecryptedFile)
        } finally {
            document?.close()
        }
        
        val extractedTextBuilder = StringBuilder()
        var fileDescriptor: ParcelFileDescriptor? = null
        var pdfRenderer: PdfRenderer? = null
        
        try {
            fileDescriptor = ParcelFileDescriptor.open(tempDecryptedFile, ParcelFileDescriptor.MODE_READ_ONLY)
            pdfRenderer = PdfRenderer(fileDescriptor)
            
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            
            val scale = 300f / 72f 
            
            for (i in 0 until pdfRenderer.pageCount) {
                var page: PdfRenderer.Page? = null
                try {
                    page = pdfRenderer.openPage(i)
                    val width = (page.width * scale).toInt()
                    val height = (page.height * scale).toInt()
                    
                    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    val canvas = android.graphics.Canvas(bitmap)
                    canvas.drawColor(android.graphics.Color.WHITE)
                    canvas.drawBitmap(bitmap, 0f, 0f, null)
                    
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    
                    val image = InputImage.fromBitmap(bitmap, 0)
                    val visionText = recognizer.process(image).await()
                    
                    extractedTextBuilder.append(visionText.text).append("\n")
                    
                    bitmap.recycle()
                } finally {
                    page?.close()
                }
            }
        } catch (e: Exception) {
            extractedTextBuilder.append("[OCR Failed: ${e.message}]")
        } finally {
            pdfRenderer?.close()
            fileDescriptor?.close()
            if (tempDecryptedFile.exists()) {
                tempDecryptedFile.delete()
            }
        }
        
        return extractedTextBuilder.toString()
    }
}
