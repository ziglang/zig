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
 * @file data_type.h
 *
 * @brief 声明了张量的数据的类型。
 *
 * @library libmindspore_lite_ndk.so
 * @since 9
 */
#ifndef MINDSPORE_INCLUDE_C_API_DATA_TYPE_C_H
#define MINDSPORE_INCLUDE_C_API_DATA_TYPE_C_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum OH_AI_DataType {
  OH_AI_DATATYPE_UNKNOWN = 0,
  OH_AI_DATATYPE_OBJECTTYPE_STRING = 12,
  OH_AI_DATATYPE_OBJECTTYPE_LIST = 13,
  OH_AI_DATATYPE_OBJECTTYPE_TUPLE = 14,
  OH_AI_DATATYPE_OBJECTTYPE_TENSOR = 17,
  OH_AI_DATATYPE_NUMBERTYPE_BEGIN = 29,
  OH_AI_DATATYPE_NUMBERTYPE_BOOL = 30,
  OH_AI_DATATYPE_NUMBERTYPE_INT8 = 32,
  OH_AI_DATATYPE_NUMBERTYPE_INT16 = 33,
  OH_AI_DATATYPE_NUMBERTYPE_INT32 = 34,
  OH_AI_DATATYPE_NUMBERTYPE_INT64 = 35,
  OH_AI_DATATYPE_NUMBERTYPE_UINT8 = 37,
  OH_AI_DATATYPE_NUMBERTYPE_UINT16 = 38,
  OH_AI_DATATYPE_NUMBERTYPE_UINT32 = 39,
  OH_AI_DATATYPE_NUMBERTYPE_UINT64 = 40,
  OH_AI_DATATYPE_NUMBERTYPE_FLOAT16 = 42,
  OH_AI_DATATYPE_NUMBERTYPE_FLOAT32 = 43,
  OH_AI_DATATYPE_NUMBERTYPE_FLOAT64 = 44,
  OH_AI_DATATYPE_NUMBERTYPE_END = 46,
  // add new enum here
  OH_AI_DataTypeInvalid = INT32_MAX,
} OH_AI_DataType;

#ifdef __cplusplus
}
#endif
#endif  // MINDSPORE_INCLUDE_C_API_DATA_TYPE_C_H