/**
 * Copyright 2021 Huawei Technologies Co., Ltd
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @addtogroup MindSpore
 * @{
 *
 * @brief provide the model reasoning related interfaces of MindSpore Lite.
 *
 * @Syscap SystemCapability.Ai.MindSpore
 * @since 9
 */

/**
 * @file types.h
 *
 * @brief provides the model file types and device types supported by MindSpore Lite.
 *
 * @library libmindspore_lite_ndk.so
 * @since 9
 */
#ifndef MINDSPORE_INCLUDE_C_API_TYPES_C_H
#define MINDSPORE_INCLUDE_C_API_TYPES_C_H

#ifdef __cplusplus
extern "C" {
#endif

#ifndef OH_AI_API
#ifdef _WIN32
#define OH_AI_API __declspec(dllexport)
#else
#define OH_AI_API __attribute__((visibility("default")))
#endif
#endif

/**
 * @brief model file type.
 *
 * @since 9
 */
typedef enum OH_AI_ModelType {
    /** the model type is MindIR, and the corresponding model file extension is .ms. */
    OH_AI_MODELTYPE_MINDIR = 0,
    /** invaild model type */
    OH_AI_MODELTYPE_INVALID = 0xFFFFFFFF
} OH_AI_ModelType;

/**
 * @brief device type information.
 *
 * @since 9
 */
typedef enum OH_AI_DeviceType {
    /** cpu */
    OH_AI_DEVICETYPE_CPU = 0,
    /** gpu */
    OH_AI_DEVICETYPE_GPU,
    /** kirin npu */
    OH_AI_DEVICETYPE_KIRIN_NPU,
    /** nnrt device, ohos-only device range: [60, 80) */
    OH_AI_DEVICETYPE_NNRT = 60,
    /** invalid device type */
    OH_AI_DEVICETYPE_INVALID = 100,
} OH_AI_DeviceType;

/**
 * @brief the hard deivce type managed by NNRT.
 *
 * @since 10
 */
typedef enum OH_AI_NNRTDeviceType {
    /** Devices that are not CPU, GPU, or dedicated accelerator */
    OH_AI_NNRTDEVICE_OTHERS = 0,
    /** CPU device */
    OH_AI_NNRTDEVICE_CPU = 1,
    /** GPU device */
    OH_AI_NNRTDEVICE_GPU = 2,
    /** Dedicated hardware accelerator */
    OH_AI_NNRTDEVICE_ACCELERATOR = 3,
} OH_AI_NNRTDeviceType;

/**
 * @brief performance mode of the NNRT hard deivce.
 *
 * @since 10
 */
typedef enum OH_AI_PerformanceMode {
    /** No performance mode preference */
    OH_AI_PERFORMANCE_NONE = 0,
    /** Low power consumption mode*/
    OH_AI_PERFORMANCE_LOW = 1,
    /** Medium performance mode */
    OH_AI_PERFORMANCE_MEDIUM = 2,
    /** High performance mode */
    OH_AI_PERFORMANCE_HIGH = 3,
    /** Ultimate performance mode */
    OH_AI_PERFORMANCE_EXTREME = 4
} OH_AI_PerformanceMode;

/**
 * @brief NNRT reasoning task priority.
 *
 * @since 10
 */
typedef enum OH_AI_Priority {
    /** No priority preference */
    OH_AI_PRIORITY_NONE = 0,
    /** Low priority */
    OH_AI_PRIORITY_LOW = 1,
    /** Medium priority */
    OH_AI_PRIORITY_MEDIUM = 2,
    /** High priority */
    OH_AI_PRIORITY_HIGH = 3
} OH_AI_Priority;

/**
 * @brief optimization level for train model.
 *
 * @since 11
 */
typedef enum OH_AI_OptimizationLevel {
    /** Do not change */
    OH_AI_KO0 = 0,
    /** Cast network to float16, keep batchnorm and loss in float32 */
    OH_AI_KO2 = 2,
    /** Cast network to float16, including bacthnorm */
    OH_AI_KO3 = 3,
    /** Choose optimization based on device */
    OH_AI_KAUTO = 4,
    /** Invalid optimizatin level */
    OH_AI_KOPTIMIZATIONTYPE = 0xFFFFFFFF
} OH_AI_OptimizationLevel;

/**
 * @brief quantization type
 *
 * @since 11
 */
typedef enum OH_AI_QuantizationType {
    /** Do not change */
    OH_AI_NO_QUANT = 0,
    /** weight quantization */
    OH_AI_WEIGHT_QUANT = 1,
    /** full quantization */
    OH_AI_FULL_QUANT = 2,
    /** invalid quantization type */
    OH_AI_UNKNOWN_QUANT_TYPE = 0xFFFFFFFF
} OH_AI_QuantizationType;

typedef struct NNRTDeviceDesc NNRTDeviceDesc;
#ifdef __cplusplus
}
#endif
#endif  // MINDSPORE_INCLUDE_C_API_TYPES_C_H