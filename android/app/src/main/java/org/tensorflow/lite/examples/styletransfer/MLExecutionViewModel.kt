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

import androidx.lifecycle.ViewModel
import android.content.Context
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExecutorCoroutineDispatcher
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

class MLExecutionViewModel : ViewModel() {

  private val _styledBitmap = MutableLiveData<ModelExecutionResult>()

  val styledBitmap: LiveData<ModelExecutionResult>
    get() = _styledBitmap

  private val viewModelJob = Job()
  private val viewModelScope = CoroutineScope(viewModelJob)

/*  
  Older version of onApplyStyle; static , fixed paths and a few other older approaches
fun onApplyStyle(
    context: Context,
    contentFileStaticPath: String,
    styleFileStaticPath: String,
    styleTransferModelExecutor: StyleTransferModelExecutor,
    inferenceThread: ExecutorCoroutineDispatcher
  ) {
    viewModelScope.launch(inferenceThread) {
      val result = styleTransferStaticModelExecutor.execute(contentFilePath, styleFilePath, context)
      _styledBitmap.postValue(result)
    }
  }*/
  
  fun onApplyStyle(
    context: Context,
    contentFilePath: String,
    styleFilePath: String,
    styleTransferModelExecutor: StyleTransferModelExecutor,
    inferenceThread: ExecutorCoroutineDispatcher
  ) {
    viewModelScope.launch(inferenceThread) {
      val result = styleTransferModelExecutor.execute(contentFilePath, styleFilePath, context)
      _styledBitmap.postValue(result)
    }
  }  
}
