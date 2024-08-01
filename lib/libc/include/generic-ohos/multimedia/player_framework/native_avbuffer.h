/*
 * Copyright (C) 2023 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef NATIVE_AVBUFFER_H
#define NATIVE_AVBUFFER_H

#include <stdint.h>
#include <stdio.h>
#include "native_averrors.h"
#include "native_avformat.h"
#include "native_avbuffer_info.h"

#ifdef __cplusplus
extern "C" {
#endif
typedef struct OH_AVBuffer OH_AVBuffer;
typedef struct OH_NativeBuffer OH_NativeBuffer;

/**
 * @brief Create an OH_AVBuffer instance, It should be noted that the life cycle of the OH_AVBuffer instance pointed
 * to by the return value * needs to be manually released by {@link OH_AVBuffer_Destroy}.
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param capacity the buffer's capacity, bytes
 * @return Returns a pointer to an OH_AVBuffer instance if the execution is successful, otherwise returns nullptr.
 * Possible failure causes: 1. capacity <= 0. 2. create allocator failed. 3. create OH_AVBuffer failed.
 * 4. created buffer memory is nullptr. 5. created buffer memory's addr is nullptr. 6. failed to new OH_AVBuffer.
 * @since 11
 */
OH_AVBuffer *OH_AVBuffer_Create(int32_t capacity);

/**
 * @brief Clear the internal resources of the buffer and destroy the buffer instance.
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param buffer Encapsulate OH_AVBuffer structure instance pointer
 * @return Function result code.
 *         {@link AV_ERR_OK} if the execution is successful.
 *         {@link AV_ERR_INVALID_VAL} if input buffer is nullptr or buffer's magic error.
 *         {@link AV_ERR_OPERATE_NOT_PERMIT} if input buffer is not user created.
 * @since 11
 */
OH_AVErrCode OH_AVBuffer_Destroy(OH_AVBuffer *buffer);

/**
 * @brief Get the buffer's attribute.
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param buffer Encapsulate OH_AVBuffer structure instance pointer
 * @param attr Encapsulate OH_AVCodecBufferAttr structure instance pointer, please refer to
 * {@link OH_AVCodecBufferAttr}
 * @return Function result code.
 *         {@link AV_ERR_OK} if the execution is successful.
 *         {@link AV_ERR_INVALID_VAL} if input buffer is nullptr, buffer's magic error,
 *         input buffer's buffer is nulllptr or attr is nullptr.
 * @since 11
 */
OH_AVErrCode OH_AVBuffer_GetBufferAttr(OH_AVBuffer *buffer, OH_AVCodecBufferAttr *attr);

/**
 * @brief Set the buffer's attribute.
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param buffer Encapsulate OH_AVBuffer structure instance pointer
 * @param attr Encapsulate OH_AVCodecBufferAttr structure instance pointer, please refer to
 * {@link OH_AVCodecBufferAttr}
 * @return Function result code.
 *         {@link AV_ERR_OK} if the execution is successful.
 *         {@link AV_ERR_INVALID_VAL} if input buffer is nullptr, buffer's magic error,
 *         input buffer's buffer is nulllptr, attr is nullptr, the size or offset of input buffer's memory is invalid.
 * @since 11
 */
OH_AVErrCode OH_AVBuffer_SetBufferAttr(OH_AVBuffer *buffer, const OH_AVCodecBufferAttr *attr);

/**
 * @brief Get the buffer's parameter. It should be noted that the life cycle of the OH_AVFormat instance pointed to
 * by the return value * needs to be manually released by {@link OH_AVFormat_Destroy}.
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param buffer Encapsulate OH_AVBuffer structure instance pointer
 * @return Returns Encapsulate OH_AVFormat structure instance pointer if the execution is successful,
 * otherwise returns nullptr. Possible failure causes: 1. input buffer is nullptr. 2. buffer's magic error.
 * 3. input buffer's buffer is nulllptr. 4. buffer's meta is nullptr.
 * @since 11
 */
OH_AVFormat *OH_AVBuffer_GetParameter(OH_AVBuffer *buffer);

/**
 * @brief Set the buffer's parameter.
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param buffer Encapsulate OH_AVBuffer structure instance pointer
 * @param format Encapsulate OH_AVFormat structure instance pointer
 * @return Function result code.
 *         {@link AV_ERR_OK} if the execution is successful.
 *         {@link AV_ERR_INVALID_VAL} if input buffer is nullptr, buffer's magic error,
 *         input buffer's buffer is nulllptr, input format is nullptr or input meta is nullptr.
 * @since 11
 */
OH_AVErrCode OH_AVBuffer_SetParameter(OH_AVBuffer *buffer, const OH_AVFormat *format);

/**
 * @brief Get the buffer's virtual address.
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param buffer Encapsulate OH_AVBuffer structure instance pointer
 * @return the buffer's virtual address if the buffer is valid, otherwise nullptr
 * Possible failure causes: 1. input buffer is nullptr. 2. buffer's magic error.
 * 3. input buffer's buffer is nulllptr. 4. buffer's memory is nullptr.
 * @since 11
 */
uint8_t *OH_AVBuffer_GetAddr(OH_AVBuffer *buffer);

/**
 * @brief Get the buffer's capacity
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param buffer Encapsulate OH_AVBuffer structure instance pointer
 * @return the buffer's capacity if the buffer is valid, otherwise -1
 * Possible failure causes: 1. input buffer is nullptr. 2. buffer's magic error.
 * 3. input buffer's buffer is nulllptr. 4. buffer's memory is nullptr.
 * @since 11
 */
int32_t OH_AVBuffer_GetCapacity(OH_AVBuffer *buffer);

/**
 * @brief Get the OH_NativeBuffer instance pointer,It should be noted that the life cycle of the OH_AVBuffer
 * instance pointed to by the return value * needs to be manually released by {@link OH_NativeBuffer_Unreference}.
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param buffer Encapsulate OH_AVBuffer structure instance pointer
 * @return Returns Encapsulate OH_NativeBuffer structure instance pointer is successful, otherwise returns nullptr
 * Possible failure causes: 1. input buffer is nullptr. 2. buffer's magic error.
 * 3. input buffer's buffer is nulllptr. 4. buffer's memory is nullptr. 5. surfaceBuffer is nullptr.
 * @since 11
 */
OH_NativeBuffer *OH_AVBuffer_GetNativeBuffer(OH_AVBuffer *buffer);

#ifdef __cplusplus
}
#endif

#endif // NATIVE_AVBUFFER_H