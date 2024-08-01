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
 * @file format.h
 * @kit MindSporeLiteKit
 * @brief 提供张量数据的排列格式。
 *
 * @library libmindspore_lite_ndk.so
 * @since 9
 */
#ifndef MINDSPORE_INCLUDE_C_API_FORMAT_C_H
#define MINDSPORE_INCLUDE_C_API_FORMAT_C_H

#ifdef __cplusplus
extern "C" {
#endif

typedef enum OH_AI_Format {
  OH_AI_FORMAT_NCHW = 0,
  OH_AI_FORMAT_NHWC = 1,
  OH_AI_FORMAT_NHWC4 = 2,
  OH_AI_FORMAT_HWKC = 3,
  OH_AI_FORMAT_HWCK = 4,
  OH_AI_FORMAT_KCHW = 5,
  OH_AI_FORMAT_CKHW = 6,
  OH_AI_FORMAT_KHWC = 7,
  OH_AI_FORMAT_CHWK = 8,
  OH_AI_FORMAT_HW = 9,
  OH_AI_FORMAT_HW4 = 10,
  OH_AI_FORMAT_NC = 11,
  OH_AI_FORMAT_NC4 = 12,
  OH_AI_FORMAT_NC4HW4 = 13,
  OH_AI_FORMAT_NCDHW = 15,
  OH_AI_FORMAT_NWC = 16,
  OH_AI_FORMAT_NCW = 17
} OH_AI_Format;

#ifdef __cplusplus
}
#endif
#endif  // MINDSPORE_INCLUDE_C_API_FORMAT_C_H