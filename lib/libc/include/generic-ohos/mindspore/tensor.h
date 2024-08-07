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
 * @file tensor.h
 *
 * @brief 提供了张量相关的接口，可用于创建和修改张量信息。
 *
 * @library libmindspore_lite_ndk.so
 * @since 9
 */
#ifndef MINDSPORE_INCLUDE_C_API_TENSOE_C_H
#define MINDSPORE_INCLUDE_C_API_TENSOE_C_H

#include <stddef.h>
#include "mindspore/status.h"
#include "mindspore/types.h"
#include "mindspore/data_type.h"
#include "mindspore/format.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef void *OH_AI_TensorHandle;

/**
 * @brief tensor allocator handle.
 *
 * @since 12
 */
typedef void *OH_AI_AllocatorHandle;

/**
 * @brief Create a tensor object.
 * @param name The name of the tensor.
 * @param type The data type of the tensor.
 * @param shape The shape of the tensor.
 * @param shape_num The num of the shape.
 * @param data The data pointer that points to allocated memory.
 * @param data_len The length of the memory, in bytes.
 * @return Tensor object handle.
 * @since 9
 */
OH_AI_API OH_AI_TensorHandle OH_AI_TensorCreate(const char *name, OH_AI_DataType type, const int64_t *shape,
                                                size_t shape_num, const void *data, size_t data_len);

/**
 * @brief Destroy the tensor object.
 * @param tensor Tensor object handle address.
 * @since 9
 */
OH_AI_API void OH_AI_TensorDestroy(OH_AI_TensorHandle *tensor);

/**
 * @brief Obtain a deep copy of the tensor.
 * @param tensor Tensor object handle.
 * @return Tensor object handle.
 * @since 9
 */
OH_AI_API OH_AI_TensorHandle OH_AI_TensorClone(OH_AI_TensorHandle tensor);

/**
 * @brief Set the name for the tensor.
 * @param tensor Tensor object handle.
 * @param name The name of the tensor.
 * @since 9
 */
OH_AI_API void OH_AI_TensorSetName(OH_AI_TensorHandle tensor, const char *name);

/**
 * @brief Obtain the name of the tensor.
 * @param tensor Tensor object handle.
 * @return The name of the tensor.
 * @since 9
 */
OH_AI_API const char *OH_AI_TensorGetName(const OH_AI_TensorHandle tensor);

/**
 * @brief Set the data type for the tensor.
 * @param tensor Tensor object handle.
 * @param type The data type of the tensor.
 * @since 9
 */
OH_AI_API void OH_AI_TensorSetDataType(OH_AI_TensorHandle tensor, OH_AI_DataType type);

/**
 * @brief Obtain the data type of the tensor.
 * @param tensor Tensor object handle.
 * @return The date type of the tensor.
 * @since 9
 */
OH_AI_API OH_AI_DataType OH_AI_TensorGetDataType(const OH_AI_TensorHandle tensor);

/**
 * @brief Set the shape for the tensor.
 * @param tensor Tensor object handle.
 * @param shape The shape array.
 * @param shape_num Dimension of shape.
 * @since 9
 */
OH_AI_API void OH_AI_TensorSetShape(OH_AI_TensorHandle tensor, const int64_t *shape, size_t shape_num);

/**
 * @brief Obtain the shape of the tensor.
 * @param tensor Tensor object handle.
 * @param shape_num Dimension of shape.
 * @return The shape array of the tensor.
 * @since 9
 */
OH_AI_API const int64_t *OH_AI_TensorGetShape(const OH_AI_TensorHandle tensor, size_t *shape_num);

/**
 * @brief Set the format for the tensor.
 * @param tensor Tensor object handle.
 * @param format The format of the tensor.
 * @since 9
 */
OH_AI_API void OH_AI_TensorSetFormat(OH_AI_TensorHandle tensor, OH_AI_Format format);

/**
 * @brief Obtain the format of the tensor.
 * @param tensor Tensor object handle.
 * @return The format of the tensor.
 * @since 9
 */
OH_AI_API OH_AI_Format OH_AI_TensorGetFormat(const OH_AI_TensorHandle tensor);

/**
 * @brief Obtain the data for the tensor.
 * @param tensor Tensor object handle.
 * @param data A pointer to the data of the tensor.
 * @since 9
 */
OH_AI_API void OH_AI_TensorSetData(OH_AI_TensorHandle tensor, void *data);

/**
 * @brief Obtain the data pointer of the tensor.
 * @param tensor Tensor object handle.
 * @return The data pointer of the tensor.
 * @since 9
 */
OH_AI_API const void *OH_AI_TensorGetData(const OH_AI_TensorHandle tensor);

/**
 * @brief Obtain the mutable data pointer of the tensor. If the internal data is empty, it will allocate memory.
 * @param tensor Tensor object handle.
 * @return The data pointer of the tensor.
 * @since 9
 */
OH_AI_API void *OH_AI_TensorGetMutableData(const OH_AI_TensorHandle tensor);

/**
 * @brief Obtain the element number of the tensor.
 * @param tensor Tensor object handle.
 * @return The element number of the tensor.
 * @since 9
 */
OH_AI_API int64_t OH_AI_TensorGetElementNum(const OH_AI_TensorHandle tensor);

/**
 * @brief Obtain the data size fo the tensor.
 * @param tensor Tensor object handle.
 * @return The data size of the tensor.
 * @since 9
 */
OH_AI_API size_t OH_AI_TensorGetDataSize(const OH_AI_TensorHandle tensor);

/**
 * @brief Set the data for the tensor with user-allocated data buffer.
 *
 * The main purpose of this interface is providing a way of using memory already allocated by user as the Model's
 * input, but not which allocated inside the Model object. It can reduce one copy. \n
 * Note: The tensor won't free the data provided by invoker. Invoker has the responsibility to free it. And this
 * free action should not be preformed before destruction of the tensor. \n
 *
 * @param tensor Tensor object handle.
 * @param data A pointer to the user data buffer.
 * @param data the byte size of the user data buffer.
 * @return OH_AI_STATUS_SUCCESS if success, or detail error code if failed.
 * @since 10
 */
OH_AI_API OH_AI_Status OH_AI_TensorSetUserData(OH_AI_TensorHandle tensor, void *data, size_t data_size);

/**
 * @brief Get allocator for the tensor.
 *
 * The main purpose of this interface is providing a way of getting memory allocator of the tensor.
 *
 * @param tensor Tensor object handle.
 * @return handle of the tensor's allocator.
 * @since 12
 */
OH_AI_API OH_AI_AllocatorHandle OH_AI_TensorGetAllocator(OH_AI_TensorHandle tensor);

/**
 * @brief Set allocator to the tensor.
 *
 * The main purpose of this interface is providing a way of setting memory allocator, so tensor's memory will be
 * allocated by this allocator.
 *
 * @param tensor Tensor object handle.
 * @param allocator A allocator handle.
 * @return OH_AI_STATUS_SUCCESS if success, or detail error code if failed.
 * @since 12
 */
OH_AI_API OH_AI_Status OH_AI_TensorSetAllocator(OH_AI_TensorHandle tensor, OH_AI_AllocatorHandle allocator);

#ifdef __cplusplus
}
#endif
#endif  // MINDSPORE_INCLUDE_C_API_TENSOE_C_H