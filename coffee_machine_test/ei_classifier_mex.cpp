/*
 * MATLAB MEX Interface for Edge Impulse Coffee Machine Vibration Classifier
 * 
 * Model: Vibration Classification - Coffee machine stages
 * Inputs: 600 raw values (200 time steps x 3 axes: accZ, accY, accX at 100 Hz)
 * Outputs: MATLAB Struct containing classification probabilities and execution timings.
 */

#include "mex.h"
#if defined(_MSC_VER) && !defined(__attribute__)
#define __attribute__(x)
#endif
#include <chrono>
#include <thread>
#include <vector>
#include <string>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

// --------------------------------------------------------------------------
// 1. Edge Impulse Porting Layer Implementations for Windows / MATLAB
// --------------------------------------------------------------------------
#include "edge-impulse-sdk/porting/ei_classifier_porting.h"

EI_IMPULSE_ERROR ei_run_impulse_check_canceled() {
    return EI_IMPULSE_OK;
}

EI_IMPULSE_ERROR ei_sleep(int32_t time_ms) {
    std::this_thread::sleep_for(std::chrono::milliseconds(time_ms));
    return EI_IMPULSE_OK;
}

uint64_t ei_read_timer_ms() {
    auto now = std::chrono::system_clock::now();
    return std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count();
}

uint64_t ei_read_timer_us() {
    auto now = std::chrono::system_clock::now();
    return std::chrono::duration_cast<std::chrono::microseconds>(now.time_since_epoch()).count();
}

void ei_printf(const char *format, ...) {
    va_list myargs;
    va_start(myargs, format);
    // Print directly into MATLAB's Command Window
    mexPrintf(format, myargs);
    va_end(myargs);
}

void ei_printf_float(float f) {
    mexPrintf("%f", f);
}

void *ei_malloc(size_t size) {
    return malloc(size);
}

void *ei_calloc(size_t nitems, size_t size) {
    return calloc(nitems, size);
}

void ei_free(void *ptr) {
    free(ptr);
}

void ei_serial_set_baudrate(int baudrate) {
    (void)baudrate;
}

extern "C" void DebugLog(const char* s) {
    mexPrintf("%s", s);
}

// --------------------------------------------------------------------------
// 2. MicroContext stubs for Edge Impulse EON compiler runtime
// --------------------------------------------------------------------------
#include "edge-impulse-sdk/tensorflow/lite/micro/micro_log.h"
#include "edge-impulse-sdk/tensorflow/lite/micro/micro_context.h"

namespace tflite {
MicroContext::MicroContext(MicroAllocator* allocator, const Model* model, MicroGraph* graph)
    : allocator_(*allocator), graph_(*graph), model_(model) {}
MicroContext::~MicroContext() {}
void* MicroContext::AllocatePersistentBuffer(size_t bytes) { return nullptr; }
TfLiteStatus MicroContext::RequestScratchBufferInArena(size_t bytes, int* buffer_idx) { return kTfLiteOk; }
void* MicroContext::GetScratchBuffer(int buffer_idx) { return nullptr; }
TfLiteTensor* MicroContext::AllocateTempTfLiteTensor(int tensor_idx) { return nullptr; }
void MicroContext::DeallocateTempTfLiteTensor(TfLiteTensor* tensor) {}
TfLiteEvalTensor* MicroContext::GetEvalTensor(int tensor_idx) { return nullptr; }
int MicroContext::GetTensorIndex(int index, int max_size, const int* tensor_indices) { return -1; }
TfLiteTensor* MicroContext::AllocateTempInputTensor(const TfLiteNode* node, int index) {
  if (!node || !node->inputs || index < 0 || index >= node->inputs->size) return nullptr;
  int tensor_index = node->inputs->data[index];
  if (tensor_index < 0) return nullptr;
  return AllocateTempTfLiteTensor(tensor_index);
}
TfLiteTensor* MicroContext::AllocateTempOutputTensor(const TfLiteNode* node, int index) {
  if (!node || !node->outputs || index < 0 || index >= node->outputs->size) return nullptr;
  int tensor_index = node->outputs->data[index];
  if (tensor_index < 0) return nullptr;
  return AllocateTempTfLiteTensor(tensor_index);
}
TfLiteTensor* MicroContext::AllocateTempIntermediateTensor(const TfLiteNode* node, int index) {
  if (!node || !node->intermediates || index < 0 || index >= node->intermediates->size) return nullptr;
  int tensor_index = node->intermediates->data[index];
  if (tensor_index < 0) return nullptr;
  return AllocateTempTfLiteTensor(tensor_index);
}
void MicroContext::SetScratchBufferHandles(ScratchBufferHandle* scratch_buffer_handles) {}
TfLiteStatus MicroContext::set_external_context(void* external_context_payload) { return kTfLiteOk; }
void MicroContextReportOpError(struct TfLiteContext* context, const char* format, ...) {
    va_list args;
    va_start(args, format);
    Log(format, args);
    va_end(args);
}

TfLiteStatus TfLiteTypeSizeOf(TfLiteType type, size_t* size) {
  switch (type) {
    case kTfLiteFloat32: *size = sizeof(float); break;
    case kTfLiteInt16:   *size = sizeof(int16_t); break;
    case kTfLiteInt32:   *size = sizeof(int32_t); break;
    case kTfLiteUInt32:  *size = sizeof(uint32_t); break;
    case kTfLiteUInt8:   *size = sizeof(uint8_t); break;
    case kTfLiteInt8:    *size = sizeof(int8_t); break;
    case kTfLiteInt64:   *size = sizeof(int64_t); break;
    case kTfLiteUInt64:  *size = sizeof(uint64_t); break;
    case kTfLiteBool:    *size = sizeof(bool); break;
    default: return kTfLiteError;
  }
  return kTfLiteOk;
}

TfLiteStatus TfLiteEvalTensorByteLength(const TfLiteEvalTensor* eval_tensor, size_t* out_bytes) {
  if (!out_bytes) return kTfLiteError;
  int element_count = 1;
  if (eval_tensor->dims != nullptr) {
    for (int n = 0; n < eval_tensor->dims->size; ++n) {
      element_count *= eval_tensor->dims->data[n];
    }
  }
  size_t type_size = 0;
  if (TfLiteTypeSizeOf(eval_tensor->type, &type_size) != kTfLiteOk) return kTfLiteError;
  *out_bytes = element_count * type_size;
  return kTfLiteOk;
}
}

// --------------------------------------------------------------------------
// 3. Include Edge Impulse inferencing engine
// --------------------------------------------------------------------------
#include "edge-impulse-sdk/classifier/ei_run_classifier.h"

// Callback context to pass MATLAB buffer to Edge Impulse signal_t
struct SignalContext {
    const float *data;
    size_t total_length;
};

static int get_signal_data(size_t offset, size_t length, float *out_ptr) {
    // In our context, this gets called by Edge Impulse's DSP block
    // to read slices of the raw sensor data
    extern SignalContext g_sig_ctx;
    if (offset + length > g_sig_ctx.total_length) {
        return EIDSP_OUT_OF_BOUNDS;
    }
    for (size_t i = 0; i < length; i++) {
        out_ptr[i] = g_sig_ctx.data[offset + i];
    }
    return EIDSP_OK;
}

SignalContext g_sig_ctx = { nullptr, 0 };

// --------------------------------------------------------------------------
// 3. MATLAB MEX Gateway function
// --------------------------------------------------------------------------
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // Check inputs
    if (nrhs < 1) {
        mexErrMsgIdAndTxt("EdgeImpulse:MEX:InvalidInput",
            "Usage: result = ei_classifier_mex(signal_matrix)\n"
            "Input must be a 200x3 matrix or a 1x600 vector of vibration data.");
    }

    const mxArray *input_mat = prhs[0];
    if (!mxIsDouble(input_mat) && !mxIsSingle(input_mat)) {
        mexErrMsgIdAndTxt("EdgeImpulse:MEX:TypeError", "Input signal must be double or single precision.");
    }

    size_t num_elements = mxGetNumberOfElements(input_mat);
    if (num_elements != EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE) {
        mexErrMsgIdAndTxt("EdgeImpulse:MEX:SizeMismatch",
            "Expected exactly %d values (200 time steps x 3 axes: accZ, accY, accX). Received %d values.",
            EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE, (int)num_elements);
    }

    // Convert input data to contiguous float buffer (handling MATLAB's column-major ordering)
    std::vector<float> float_buffer(num_elements);
    size_t rows = mxGetM(input_mat);
    size_t cols = mxGetN(input_mat);

    if (mxIsDouble(input_mat)) {
        double *d_ptr = mxGetPr(input_mat);
        if (rows == EI_CLASSIFIER_RAW_SAMPLE_COUNT && cols == EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME) {
            // MATLAB matrix [200 x 3] is column-major:
            // d_ptr has all 200 accZ, then all 200 accY, then all 200 accX.
            // Edge Impulse expects interleaved samples: [Z0, Y0, X0, Z1, Y1, X1, ...]
            for (size_t t = 0; t < rows; t++) {
                for (size_t axis = 0; axis < cols; axis++) {
                    float_buffer[t * cols + axis] = static_cast<float>(d_ptr[axis * rows + t]);
                }
            }
        } else {
            // 1x600 or 600x1 pre-interleaved vector
            for (size_t i = 0; i < num_elements; i++) {
                float_buffer[i] = static_cast<float>(d_ptr[i]);
            }
        }
    } else {
        float *f_ptr = (float*)mxGetData(input_mat);
        if (rows == EI_CLASSIFIER_RAW_SAMPLE_COUNT && cols == EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME) {
            for (size_t t = 0; t < rows; t++) {
                for (size_t axis = 0; axis < cols; axis++) {
                    float_buffer[t * cols + axis] = f_ptr[axis * rows + t];
                }
            }
        } else {
            for (size_t i = 0; i < num_elements; i++) {
                float_buffer[i] = f_ptr[i];
            }
        }
    }

    // Setup Edge Impulse signal_t
    g_sig_ctx.data = float_buffer.data();
    g_sig_ctx.total_length = num_elements;

    signal_t signal;
    signal.total_length = num_elements;
    signal.get_data = &get_signal_data;

    // Run inference
    ei_impulse_result_t result = { 0 };
    EI_IMPULSE_ERROR ei_err = run_classifier(&signal, &result, false);

    if (ei_err != EI_IMPULSE_OK) {
        mexErrMsgIdAndTxt("EdgeImpulse:MEX:InferenceError",
            "Edge Impulse inference failed with error code: %d", (int)ei_err);
    }

    // Build MATLAB return struct
    // Fields: labels, scores, predicted_label, timing
    const char *field_names[] = { "labels", "scores", "predicted_label", "timing_dsp_ms", "timing_infer_ms" };
    plhs[0] = mxCreateStructMatrix(1, 1, 5, field_names);

    // Labels cell array
    mxArray *labels_cell = mxCreateCellMatrix(1, (mwSize)EI_CLASSIFIER_LABEL_COUNT);
    for (size_t i = 0; i < EI_CLASSIFIER_LABEL_COUNT; i++) {
        mxSetCell(labels_cell, i, mxCreateString(ei_classifier_inferencing_categories[i]));
    }
    mxSetField(plhs[0], 0, "labels", labels_cell);

    // Scores vector
    mxArray *scores_mat = mxCreateDoubleMatrix(1, (mwSize)EI_CLASSIFIER_LABEL_COUNT, mxREAL);
    double *scores_ptr = mxGetPr(scores_mat);
    size_t best_idx = 0;
    float best_score = -1.0f;

    for (size_t i = 0; i < EI_CLASSIFIER_LABEL_COUNT; i++) {
        scores_ptr[i] = static_cast<double>(result.classification[i].value);
        if (result.classification[i].value > best_score) {
            best_score = result.classification[i].value;
            best_idx = i;
        }
    }
    mxSetField(plhs[0], 0, "scores", scores_mat);

    // Predicted label
    mxSetField(plhs[0], 0, "predicted_label", mxCreateString(ei_classifier_inferencing_categories[best_idx]));

    // Timings
    mxSetField(plhs[0], 0, "timing_dsp_ms", mxCreateDoubleScalar(result.timing.dsp));
    mxSetField(plhs[0], 0, "timing_infer_ms", mxCreateDoubleScalar(result.timing.classification));
}
