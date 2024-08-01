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
 * @brief 提供MindSpore Lite的模型推理相关接口。
 *
 * @Syscap SystemCapability.Ai.MindSpore
 * @since 9
 */

/**
 * @file status.h
 *
 * @brief 提供了Mindspore Lite运行时的状态码。
 *
 * @library libmindspore_lite_ndk.so
 * @since 9
 */
#ifndef MINDSPORE_INCLUDE_C_API_STATUS_C_H
#define MINDSPORE_INCLUDE_C_API_STATUS_C_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum OH_AI_CompCode {
  OH_AI_COMPCODE_CORE = 0x00000000u,
  OH_AI_COMPCODE_MD = 0x10000000u,
  OH_AI_COMPCODE_ME = 0x20000000u,
  OH_AI_COMPCODE_MC = 0x30000000u,
  OH_AI_COMPCODE_LITE = 0xF0000000u,
};

typedef enum OH_AI_Status {
  OH_AI_STATUS_SUCCESS = 0,
  // Core
  OH_AI_STATUS_CORE_FAILED = OH_AI_COMPCODE_CORE | 0x1,

  // Lite  // Common error code, range: [-1, -100）
  OH_AI_STATUS_LITE_ERROR = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -1),             /**< Common error code. */
  OH_AI_STATUS_LITE_NULLPTR = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -2),           /**< NULL pointer returned.*/
  OH_AI_STATUS_LITE_PARAM_INVALID = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -3),     /**< Invalid parameter.*/
  OH_AI_STATUS_LITE_NO_CHANGE = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -4),         /**< No change. */
  OH_AI_STATUS_LITE_SUCCESS_EXIT = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -5),      /**< No error but exit. */
  OH_AI_STATUS_LITE_MEMORY_FAILED = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -6),     /**< Fail to create memory. */
  OH_AI_STATUS_LITE_NOT_SUPPORT = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -7),       /**< Fail to support. */
  OH_AI_STATUS_LITE_THREADPOOL_ERROR = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -8),  /**< Error occur in thread pool. */
  OH_AI_STATUS_LITE_UNINITIALIZED_OBJ = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -9), /**< Object is not initialized. */

  // Executor error code, range: [-100,-200)
  OH_AI_STATUS_LITE_OUT_OF_TENSOR_RANGE = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -100), /**< Failed to check range. */
  OH_AI_STATUS_LITE_INPUT_TENSOR_ERROR =
    OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -101),                                   /**< Failed to check input tensor. */
  OH_AI_STATUS_LITE_REENTRANT_ERROR = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -102), /**< Exist executor running. */

  // Graph error code, range: [-200,-300)
  OH_AI_STATUS_LITE_GRAPH_FILE_ERROR = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -200), /**< Failed to verify graph file. */

  // Node error code, range: [-300,-400)
  OH_AI_STATUS_LITE_NOT_FIND_OP = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -300),     /**< Failed to find operator. */
  OH_AI_STATUS_LITE_INVALID_OP_NAME = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -301), /**< Invalid operator name. */
  OH_AI_STATUS_LITE_INVALID_OP_ATTR = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -302), /**< Invalid operator attr. */
  OH_AI_STATUS_LITE_OP_EXECUTE_FAILURE =
    OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -303), /**< Failed to execution operator. */

  // Tensor error code, range: [-400,-500)
  OH_AI_STATUS_LITE_FORMAT_ERROR = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -400), /**< Failed to checking tensor format. */

  // InferShape error code, range: [-500,-600)
  OH_AI_STATUS_LITE_INFER_ERROR = OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -500), /**< Failed to infer shape. */
  OH_AI_STATUS_LITE_INFER_INVALID =
    OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -501), /**< Invalid infer shape before runtime. */

  // User input param error code, range: [-600, 700)
  OH_AI_STATUS_LITE_INPUT_PARAM_INVALID =
    OH_AI_COMPCODE_LITE | (0x0FFFFFFF & -600), /**< Invalid input param by user. */
} OH_AI_Status;
#ifdef __cplusplus
}
#endif
#endif  // MINDSPORE_INCLUDE_C_API_STATUS_C_H