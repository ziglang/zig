/*
 * Copyright (C) 2024 Huawei Device Co., Ltd.
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

/**
 * @addtogroup image
 * @{
 *
 * @brief Provides APIs for access to the image interface.
 *
 * @since 12
 */

/**
 * @file image_native.h
 *
 * @brief Declares functions that access the image rectangle, size, format, and component data.
 *
 * @library libohimage.so
 * @syscap SystemCapability.Multimedia.Image.Core
 * @since 12
 */

#ifndef INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_H
#define INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_H

#include "image_common.h"
#include "native_buffer/native_buffer.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines an <b>OH_ImageNative</b> object.
 *
 * @since 12
 */
struct OH_ImageNative;

/**
 * @brief Defines the data type name of a native image.
 *
 * @since 12
 */
typedef struct OH_ImageNative OH_ImageNative;

/**
 * @brief Obtains {@link Image_Size} of an {@link OH_ImageNative} object.
 *
 * @param image Indicates the pointer to an {@link OH_ImageNative} object.
 * @param size Indicates the pointer to the {@link Image_Size} object obtained.
 * @return Returns {@link Image_ErrorCode} IMAGE_SUCCESS - if the operation is successful.
 * returns {@link Image_ErrorCode} IMAGE_BAD_PARAMETER - if invalid parameter.
 * returns {@link Image_ErrorCode} IMAGE_UNKNOWN_ERROR - inner unknown error.
 * @since 12
 */
Image_ErrorCode OH_ImageNative_GetImageSize(OH_ImageNative *image, Image_Size *size);

/**
 * @brief Get type arry from an {@link OH_ImageNative} object.
 *
 * @param image Indicates the pointer to an {@link OH_ImageNative} object.
 * @param types Indicates the pointer to an {@link OH_ImageNative} component arry obtained.
 * @param typeSize Indicates the pointer to the {@link OH_ImageNative} component arry size obtained.
 * @return Returns {@link Image_ErrorCode} IMAGE_SUCCESS - if the operation is successful.
 * returns {@link Image_ErrorCode} IMAGE_BAD_PARAMETER - if bad parameter.
 * @since 12
 */
Image_ErrorCode OH_ImageNative_GetComponentTypes(OH_ImageNative *image,
    uint32_t **types, size_t *typeSize);

/**
 * @brief Get byte buffer from an {@link OH_ImageNative} object by the component type.
 *
 * @param image Indicates the pointer to an {@link OH_ImageNative} object.
 * @param componentType Indicates the type of component.
 * @param nativeBuffer Indicates the pointer to the component buffer obtained.
 * @return Returns {@link Image_ErrorCode} IMAGE_SUCCESS - if the operation is successful.
 * returns {@link Image_ErrorCode} IMAGE_BAD_PARAMETER - if bad parameter.
 * @since 12
 */
Image_ErrorCode OH_ImageNative_GetByteBuffer(OH_ImageNative *image,
    uint32_t componentType, OH_NativeBuffer **nativeBuffer);

/**
 * @brief Get size of buffer from an {@link OH_ImageNative} object by the component type.
 *
 * @param image Indicates the pointer to an {@link OH_ImageNative} object.
 * @param componentType Indicates the type of component.
 * @param size Indicates the pointer to the size of buffer obtained.
 * @return Returns {@link Image_ErrorCode} IMAGE_SUCCESS - if the operation is successful.
 * returns {@link Image_ErrorCode} IMAGE_BAD_PARAMETER - if bad parameter.
 * @since 12
 */
Image_ErrorCode OH_ImageNative_GetBufferSize(OH_ImageNative *image,
    uint32_t componentType, size_t *size);

/**
 * @brief Get row stride from an {@link OH_ImageNative} object by the component type.
 *
 * @param image Indicates the pointer to an {@link OH_ImageNative} object.
 * @param componentType Indicates the type of component.
 * @param rowStride Indicates the pointer to the row stride obtained.
 * @return Returns {@link Image_ErrorCode} IMAGE_SUCCESS - if the operation is successful.
 * returns {@link Image_ErrorCode} IMAGE_BAD_PARAMETER - if bad parameter.
 * @since 12
 */
Image_ErrorCode OH_ImageNative_GetRowStride(OH_ImageNative *image,
    uint32_t componentType, int32_t *rowStride);

/**
 * @brief Get pixel stride from an {@link OH_ImageNative} object by the component type.
 *
 * @param image Indicates the pointer to an {@link OH_ImageNative} object.
 * @param componentType Indicates the type of component.
 * @param pixelStride Indicates the pointer to the pixel stride obtained.
 * @return Returns {@link Image_ErrorCode} IMAGE_SUCCESS - if the operation is successful.
 * returns {@link Image_ErrorCode} IMAGE_BAD_PARAMETER - if bad parameter.
 * @since 12
 */
Image_ErrorCode OH_ImageNative_GetPixelStride(OH_ImageNative *image,
    uint32_t componentType, int32_t *pixelStride);

/**
 * @brief Releases an {@link OH_ImageNative} object.
 * It is used to release the object {@link OH_ImageNative}.
 *
 * @param image Indicates the pointer to an {@link OH_ImageNative} object.
 * @return Returns {@link Image_ErrorCode} IMAGE_SUCCESS - if the operation is successful.
 * returns {@link Image_ErrorCode} IMAGE_BAD_PARAMETER - if bad parameter.
 * @since 12
 */
Image_ErrorCode OH_ImageNative_Release(OH_ImageNative *image);

#ifdef __cplusplus
};
#endif
/** @} */
#endif // INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_H