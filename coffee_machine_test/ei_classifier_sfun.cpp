/*
 * Simulink C-MEX S-Function for Edge Impulse Coffee Machine Vibration Classifier
 * 
 * S-Function Name: ei_classifier_sfun
 * 
 * Ports:
 *   Input Port 0:  [accZ, accY, accX] (Vector of 3 continuous vibration signals)
 *   Output Port 0: Predicted Stage ID (1 = extract, 2 = grind, 3 = idle, 4 = pump)
 *   Output Port 1: Class Probabilities (Vector of 4 doubles: [extract, grind, idle, pump])
 *   Output Port 2: Best Confidence Score (Scalar double: 0.0 to 1.0)
 * 
 * Parameters:
 *   Param 0: Sample Time (e.g., 0.01 s = 100 Hz)
 *   Param 1: Inference Step Interval (e.g., 10 samples = classify every 100 ms)
 */

#define S_FUNCTION_NAME  ei_classifier_sfun
#define S_FUNCTION_LEVEL 2

#include "simstruc.h"

// Undefine conflicting Simulink macros before including standard C++ & Edge Impulse
#ifdef MAX
#undef MAX
#endif
#ifdef MIN
#undef MIN
#endif

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
#include <algorithm>

// --------------------------------------------------------------------------
// 1. Edge Impulse Porting Layer for Simulink
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
    vprintf(format, myargs);
    va_end(myargs);
}

void ei_printf_float(float f) {
    printf("%f", f);
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
    printf("%s", s);
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
} // namespace tflite

// --------------------------------------------------------------------------
// 3. Include Edge Impulse inferencing engine
// --------------------------------------------------------------------------
#include "edge-impulse-sdk/classifier/ei_run_classifier.h"

// Static inference buffer for S-Function execution
static float g_sfun_linear_buffer[EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE];

static int sfun_get_signal_data(size_t offset, size_t length, float *out_ptr) {
    if (offset + length > EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE) {
        return EIDSP_OUT_OF_BOUNDS;
    }
    for (size_t i = 0; i < length; i++) {
        out_ptr[i] = g_sfun_linear_buffer[offset + i];
    }
    return EIDSP_OK;
}

// --------------------------------------------------------------------------
// 4. Simulink S-Function Core Methods
// --------------------------------------------------------------------------

#define DWORK_RING_BUFFER 0  // 600 floats (200 time steps x 3 axes)
#define DWORK_WRITE_POS   1  // int32 current sample index (0..199)
#define DWORK_SAMPLE_CNT  2  // int32 total samples received

static void mdlInitializeSizes(SimStruct *S) {
    // 2 Parameters: [sample_time, inference_interval]
    ssSetNumSFcnParams(S, 2);
    if (ssGetNumSFcnParams(S) != ssGetSFcnParamsCount(S)) {
        return; // Parameter mismatch error handled by Simulink
    }

    // Input Port: 3-axis continuous vibration [accZ, accY, accX]
    ssSetNumInputPorts(S, 1);
    ssSetInputPortWidth(S, 0, EI_CLASSIFIER_RAW_SAMPLES_PER_FRAME); // 3
    ssSetInputPortDirectFeedThrough(S, 0, 1);

    // Output Ports:
    // Port 0: Predicted Stage ID (1 = extract, 2 = grind, 3 = idle, 4 = pump)
    // Port 1: Class Probabilities (Vector of 4)
    // Port 2: Best Confidence Score (Scalar)
    ssSetNumOutputPorts(S, 3);
    ssSetOutputPortWidth(S, 0, 1);
    ssSetOutputPortWidth(S, 1, EI_CLASSIFIER_LABEL_COUNT); // 4
    ssSetOutputPortWidth(S, 2, 1);

    ssSetNumSampleTimes(S, 1);

    // Setup Internal State (DWork vectors)
    ssSetNumDWork(S, 3);
    
    // DWork 0: Ring Buffer (600 floats)
    ssSetDWorkWidth(S, DWORK_RING_BUFFER, EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE);
    ssSetDWorkDataType(S, DWORK_RING_BUFFER, SS_SINGLE);

    // DWork 1: Write Position (int32)
    ssSetDWorkWidth(S, DWORK_WRITE_POS, 1);
    ssSetDWorkDataType(S, DWORK_WRITE_POS, SS_INT32);

    // DWork 2: Total Samples Count (int32)
    ssSetDWorkWidth(S, DWORK_SAMPLE_CNT, 1);
    ssSetDWorkDataType(S, DWORK_SAMPLE_CNT, SS_INT32);

    ssSetOptions(S, SS_OPTION_EXCEPTION_FREE_CODE);
}

static void mdlInitializeSampleTimes(SimStruct *S) {
    real_T ts = 0.01; // default 100 Hz
    if (mxGetNumberOfElements(ssGetSFcnParam(S, 0)) > 0) {
        ts = mxGetScalar(ssGetSFcnParam(S, 0));
    }
    ssSetSampleTime(S, 0, ts);
    ssSetOffsetTime(S, 0, 0.0);
}

#define MDL_START
static void mdlStart(SimStruct *S) {
    float *ring_buf = (float*)ssGetDWork(S, DWORK_RING_BUFFER);
    int32_T *write_pos = (int32_T*)ssGetDWork(S, DWORK_WRITE_POS);
    int32_T *sample_cnt = (int32_T*)ssGetDWork(S, DWORK_SAMPLE_CNT);

    // Initialize ring buffer with resting gravity state (9.8 on Z, 0 on Y/X)
    for (int t = 0; t < EI_CLASSIFIER_RAW_SAMPLE_COUNT; t++) {
        ring_buf[t * 3 + 0] = 9.8f; // accZ
        ring_buf[t * 3 + 1] = 0.0f; // accY
        ring_buf[t * 3 + 2] = 0.0f; // accX
    }

    *write_pos = 0;
    *sample_cnt = 0;
}

static void mdlOutputs(SimStruct *S, int_T tid) {
    InputRealPtrsType uPtrs = ssGetInputPortRealSignalPtrs(S, 0);
    real_T *y_id     = ssGetOutputPortRealSignal(S, 0);
    real_T *y_scores = ssGetOutputPortRealSignal(S, 1);
    real_T *y_conf   = ssGetOutputPortRealSignal(S, 2);

    float *ring_buf    = (float*)ssGetDWork(S, DWORK_RING_BUFFER);
    int32_T *write_pos = (int32_T*)ssGetDWork(S, DWORK_WRITE_POS);
    int32_T *sample_cnt = (int32_T*)ssGetDWork(S, DWORK_SAMPLE_CNT);

    // Read inference interval parameter (default: classify every 10 samples = 100 ms)
    int32_T interval = 10;
    if (mxGetNumberOfElements(ssGetSFcnParam(S, 1)) > 0) {
        interval = (int32_T)mxGetScalar(ssGetSFcnParam(S, 1));
        if (interval < 1) interval = 1;
    }

    // 1. Store incoming sample [accZ, accY, accX] into circular buffer
    int idx = *write_pos;
    ring_buf[idx * 3 + 0] = (float)(*uPtrs[0]);
    ring_buf[idx * 3 + 1] = (float)(*uPtrs[1]);
    ring_buf[idx * 3 + 2] = (float)(*uPtrs[2]);

    *write_pos = (idx + 1) % EI_CLASSIFIER_RAW_SAMPLE_COUNT;
    (*sample_cnt)++;

    // 2. Determine if it is time to run inference
    if (*sample_cnt >= EI_CLASSIFIER_RAW_SAMPLE_COUNT && ((*sample_cnt) % interval == 0)) {
        // Unroll circular buffer into contiguous chronological order
        // Oldest sample starts at current write_pos
        int start_idx = *write_pos;
        for (int i = 0; i < EI_CLASSIFIER_RAW_SAMPLE_COUNT; i++) {
            int src_idx = (start_idx + i) % EI_CLASSIFIER_RAW_SAMPLE_COUNT;
            g_sfun_linear_buffer[i * 3 + 0] = ring_buf[src_idx * 3 + 0];
            g_sfun_linear_buffer[i * 3 + 1] = ring_buf[src_idx * 3 + 1];
            g_sfun_linear_buffer[i * 3 + 2] = ring_buf[src_idx * 3 + 2];
        }

        signal_t signal;
        signal.total_length = EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE;
        signal.get_data = &sfun_get_signal_data;

        ei_impulse_result_t result = { 0 };
        EI_IMPULSE_ERROR ei_err = run_classifier(&signal, &result, false);

        if (ei_err == EI_IMPULSE_OK) {
            int best_class = 0;
            float max_val = -1.0f;
            for (size_t c = 0; c < EI_CLASSIFIER_LABEL_COUNT; c++) {
                y_scores[c] = (real_T)result.classification[c].value;
                if (result.classification[c].value > max_val) {
                    max_val = result.classification[c].value;
                    best_class = (int)c;
                }
            }
            // 1-based indexing for Simulink (1: extract, 2: grind, 3: idle, 4: pump)
            *y_id   = (real_T)(best_class + 1);
            *y_conf = (real_T)max_val;
        }
    } else if (*sample_cnt < EI_CLASSIFIER_RAW_SAMPLE_COUNT) {
        // Buffer warmup period: default to IDLE (Class 3)
        *y_id = 3.0; // idle
        for (size_t c = 0; c < EI_CLASSIFIER_LABEL_COUNT; c++) {
            y_scores[c] = (c == 2) ? 1.0 : 0.0;
        }
        *y_conf = 1.0;
    }
}

static void mdlTerminate(SimStruct *S) {
    // No dynamic heap allocations to free
}

#ifdef MATLAB_MEX_FILE
#include "simulink.c"
#else
#include "cg_sfun.h"
#endif
