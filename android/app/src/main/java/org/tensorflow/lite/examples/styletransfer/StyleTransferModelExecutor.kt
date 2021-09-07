/*
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.tensorflow.lite.examples.styletransfer

import android.content.Context
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import kotlin.collections.set
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.gpu.GpuDelegate

@SuppressWarnings("GoodTime")
class StyleTransferModelExecutor(
  context: Context,
  private var useGPU: Boolean = false
) {
  private var gpuDelegate: GpuDelegate? = null
  private var numberThreads = 4

  private val interpreterPredict: Interpreter
  private val interpreterTransform: Interpreter

  private var fullExecutionTime = 0L
  private var preProcessTime = 0L
  private var stylePredictTime = 0L
  private var styleTransferTime = 0L
  private var postProcessTime = 0L

  init {
    if (useGPU) {
      interpreterPredict = getInterpreter(context, STYLE_PREDICT_FLOAT16_MODEL, true)
      interpreterTransform = getInterpreter(context, STYLE_TRANSFER_FLOAT16_MODEL, true)
    } else {
      interpreterPredict = getInterpreter(context, STYLE_PREDICT_INT8_MODEL, false)
      interpreterTransform = getInterpreter(context, STYLE_TRANSFER_INT8_MODEL, false)
    }
  }

  companion object {
    private const val TAG = "StyleTransferMExec"
    private const val STYLE_IMAGE_SIZE = 256
    private const val CONTENT_IMAGE_SIZE = 384
    private const val BOTTLENECK_SIZE = 100
    private const val STYLE_PREDICT_INT8_MODEL = "style_predict_quantized_256.tflite"
    private const val STYLE_TRANSFER_INT8_MODEL = "style_transfer_quantized_384.tflite"
    private const val STYLE_PREDICT_FLOAT16_MODEL = "style_predict_f16_256.tflite"
    private const val STYLE_TRANSFER_FLOAT16_MODEL = "style_transfer_f16_384.tflite"
  }

  fun execute(
    contentImagePath: String,
    styleImageName: String,
    context: Context
  ): ModelExecutionResult {
    try {
      Log.i(TAG, "running models")

      fullExecutionTime = SystemClock.uptimeMillis()
      preProcessTime = SystemClock.uptimeMillis()

      val contentImage = ImageUtils.decodeBitmap(File(contentImagePath))
      val contentArray =
        ImageUtils.bitmapToByteBuffer(contentImage, CONTENT_IMAGE_SIZE, CONTENT_IMAGE_SIZE)
      val styleBitmap =
        ImageUtils.loadBitmapFromResources(context, "thumbnails/$styleImageName")
      val input = ImageUtils.bitmapToByteBuffer(styleBitmap, STYLE_IMAGE_SIZE, STYLE_IMAGE_SIZE)

      val inputsForPredict = arrayOf<Any>(input)
      val outputsForPredict = HashMap<Int, Any>()
      val styleBottleneck = Array(1) { Array(1) { Array(1) { FloatArray(BOTTLENECK_SIZE) } } }
      outputsForPredict[0] = styleBottleneck
      preProcessTime = SystemClock.uptimeMillis() - preProcessTime

      stylePredictTime = SystemClock.uptimeMillis()
      // The results of this inference could be reused given the style does not change
      // That would be a good practice in case this was applied to a video stream.
      interpreterPredict.runForMultipleInputsOutputs(inputsForPredict, outputsForPredict)
      stylePredictTime = SystemClock.uptimeMillis() - stylePredictTime
      Log.d(TAG, "Style Predict Time to run: $stylePredictTime")

      val inputsForStyleTransfer = arrayOf(contentArray, styleBottleneck)
      val outputsForStyleTransfer = HashMap<Int, Any>()
      val outputImage =
        Array(1) { Array(CONTENT_IMAGE_SIZE) { Array(CONTENT_IMAGE_SIZE) { FloatArray(3) } } }
      outputsForStyleTransfer[0] = outputImage

      styleTransferTime = SystemClock.uptimeMillis()
      interpreterTransform.runForMultipleInputsOutputs(
        inputsForStyleTransfer,
        outputsForStyleTransfer
      )
      styleTransferTime = SystemClock.uptimeMillis() - styleTransferTime
      Log.d(TAG, "Style apply Time to run: $styleTransferTime")

      postProcessTime = SystemClock.uptimeMillis()
      var styledImage =
        ImageUtils.convertArrayToBitmap(outputImage, CONTENT_IMAGE_SIZE, CONTENT_IMAGE_SIZE)
      postProcessTime = SystemClock.uptimeMillis() - postProcessTime

      fullExecutionTime = SystemClock.uptimeMillis() - fullExecutionTime
      Log.d(TAG, "Time to run everything: $fullExecutionTime")

      return ModelExecutionResult(
        styledImage,
        preProcessTime,
        stylePredictTime,
        styleTransferTime,
        postProcessTime,
        fullExecutionTime,
        formatExecutionLog()
      )
    } catch (e: Exception) {
      val exceptionLog = "something went wrong: ${e.message}"
      Log.d(TAG, exceptionLog)

      val emptyBitmap =
        ImageUtils.createEmptyBitmap(
          CONTENT_IMAGE_SIZE,
          CONTENT_IMAGE_SIZE
        )
      return ModelExecutionResult(
        emptyBitmap, errorMessage = e.message!!
      )
    }
  }

  @Throws(IOException::class)
  private fun loadModelFile(context: Context, modelFile: String): MappedByteBuffer {
    val fileDescriptor = context.assets.openFd(modelFile)
    val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
    val fileChannel = inputStream.channel
    val startOffset = fileDescriptor.startOffset
    val declaredLength = fileDescriptor.declaredLength
    val retFile = fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
    fileDescriptor.close()
    return retFile
  }

  @Throws(IOException::class)
  private fun getInterpreter(
    context: Context,
    modelName: String,
    useGpu: Boolean = false
  ): Interpreter {
    val tfliteOptions = Interpreter.Options()
    tfliteOptions.setNumThreads(numberThreads)

    gpuDelegate = null
    if (useGpu) {
      gpuDelegate = GpuDelegate()
      tfliteOptions.addDelegate(gpuDelegate)
    }

    tfliteOptions.setNumThreads(numberThreads)
    return Interpreter(loadModelFile(context, modelName), tfliteOptions)
  }

  private fun formatExecutionLog(): String {
    val sb = StringBuilder()
    sb.append("Input Image Size: $CONTENT_IMAGE_SIZE x $CONTENT_IMAGE_SIZE\n")
    sb.append("GPU enabled: $useGPU\n")
    sb.append("Number of threads: $numberThreads\n")
    sb.append("Pre-process execution time: $preProcessTime ms\n")
    sb.append("Predicting style execution time: $stylePredictTime ms\n")
    sb.append("Transferring style execution time: $styleTransferTime ms\n")
    sb.append("Post-process execution time: $postProcessTime ms\n")
    sb.append("Full execution time: $fullExecutionTime ms\n")
    return sb.toString()
  }

  fun close() {
    interpreterPredict.close()
    interpreterTransform.close()
    if (gpuDelegate != null) {
      gpuDelegate!!.close()
    }
  }
}
