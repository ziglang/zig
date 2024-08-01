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

/**
 * @addtogroup image
 * @{
 *
 * @brief Provides APIs for access to the image interface.
 *
 * @since 12
 */

/**
 * @file image_packer_native.h
 *
 * @brief Declares APIs for encoding image into data or file.
 *
 * @library libimage_packer.so
 * @syscap SystemCapability.Multimedia.Image.ImagePacker
 * @since 12
 */

#ifndef INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_IMAGE_PACKER_NATIVE_H_
#define INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_IMAGE_PACKER_NATIVE_H_
#include "image_common.h"
#include "image_source_native.h"
#include "pixelmap_native.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Define a ImagePacker struct type, used for ImagePacker pointer controls.
 *
 * @since 12
 */
struct OH_ImagePackerNative;
typedef struct OH_ImagePackerNative OH_ImagePackerNative;

/**
 * @brief Defines the image packing options.
 *
 * @since 12
 */
struct OH_PackingOptions;
typedef struct OH_PackingOptions OH_PackingOptions;

/**
 * @brief Enumerates packing dynamic range.
 *
 * @since 12
 */
typedef enum {
    /*
    * Packing according to the content of the image.
    */
    IMAGE_PACKER_DYNAMIC_RANGE_AUTO = 0,
    /*
    * Packing to standard dynamic range.
    */
    IMAGE_PACKER_DYNAMIC_RANGE_SDR = 1,
} IMAGE_PACKER_DYNAMIC_RANGE;

/**
 * @brief Create a pointer for PackingOptions struct.
 *
 * @param options The PackingOptions pointer will be operated.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PackingOptions_Create(OH_PackingOptions **options);

/**
 * @brief Get mime type for OH_PackingOptions struct.
 *
 * @param options The OH_PackingOptions pointer will be operated.
 * @param format the number of image format.The user can pass in a null pointer and zero size, we will allocate memory,
 * but user must free memory after use.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PackingOptions_GetMimeType(OH_PackingOptions *options,
    Image_MimeType *format);

/**
 * @brief Set format number for OH_PackingOptions struct.
 *
 * @param options The OH_PackingOptions pointer will be operated.
 * @param format the number of image format.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PackingOptions_SetMimeType(OH_PackingOptions *options,
    Image_MimeType *format);

/**
 * @brief Get quality for OH_PackingOptions struct.
 *
 * @param options The OH_PackingOptions pointer will be operated.
 * @param quality The number of image quality.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PackingOptions_GetQuality(OH_PackingOptions *options,
    uint32_t *quality);

/**
 * @brief Set quality number for OH_PackingOptions struct.
 *
 * @param options The OH_PackingOptions pointer will be operated.
 * @param quality The number of image quality.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PackingOptions_SetQuality(OH_PackingOptions *options,
    uint32_t quality);

/**
 * @brief Get desiredDynamicRange for PackingOptions struct.
 *
 * @param options The PackingOptions pointer will be operated. Pointer connot be null.
 * @param desiredDynamicRange The number of dynamic range {@link IMAGE_PACKER_DYNAMIC_RANGE}. Pointer connot be null.
 * @return Returns {@link Image_ErrorCode} IMAGE_SUCCESS - The operation is successful.
 * returns {@link Image_ErrorCode} IMAGE_BAD_PARAMETER - Parameter error.Possible causes:Parameter verification failed.
 * @since 12
 */
Image_ErrorCode OH_PackingOptions_GetDesiredDynamicRange(OH_PackingOptions *options, int32_t* desiredDynamicRange);

/**
 * @brief Set desiredDynamicRange number for PackingOptions struct.
 *
 * @param options The PackingOptions pointer will be operated. Pointer connot be null.
 * @param desiredDynamicRange The number of dynamic range {@link IMAGE_PACKER_DYNAMIC_RANGE}.
 * @return Returns {@link Image_ErrorCode} IMAGE_SUCCESS - The operation is successful.
 * returns {@link Image_ErrorCode} IMAGE_BAD_PARAMETER - Parameter error.Possible causes:Parameter verification failed.
 * @since 12
 */
Image_ErrorCode OH_PackingOptions_SetDesiredDynamicRange(OH_PackingOptions *options, int32_t desiredDynamicRange);

/**
 * @brief delete OH_PackingOptions pointer.
 *
 * @param options The OH_PackingOptions pointer will be operated.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PackingOptions_Release(OH_PackingOptions *options);

/**
 * @brief Create a pointer for OH_ImagePackerNative struct.
 *
 * @param options The OH_ImagePackerNative pointer will be operated.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImagePackerNative_Create(OH_ImagePackerNative **imagePacker);

/**
 * @brief Encoding an <b>ImageSource</b> into the data with required format.
 *
 * @param imagePacker The imagePacker to use for packing.
 * @param options Indicates the encoding {@link OH_PackingOptions}.
 * @param imageSource The imageSource to be packed.
 * @param outData The output data buffer to store the packed image.
 * @param size A pointer to the size of the output data buffer.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImagePackerNative_PackToDataFromImageSource(OH_ImagePackerNative *imagePacker,
    OH_PackingOptions *options, OH_ImageSourceNative *imageSource, uint8_t *outData, size_t *size);

/**
 * @brief Encoding a <b>Pixelmap</b> into the data with required format.
 *
 * @param imagePacker The imagePacker to use for packing.
 * @param options Indicates the encoding {@link OH_PackingOptions}.
 * @param pixelmap The pixelmap to be packed.
 * @param outData The output data buffer to store the packed image.
 * @param size A pointer to the size of the output data buffer.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImagePackerNative_PackToDataFromPixelmap(OH_ImagePackerNative *imagePacker,
    OH_PackingOptions *options, OH_PixelmapNative *pixelmap, uint8_t *outData, size_t *size);

/**
 * @brief Encoding an <b>ImageSource</b> into the a file with fd with required format.
 *
 * @param imagePacker The image packer to use for packing.
 * @param options Indicates the encoding {@link OH_PackingOptions}.
 * @param imageSource The imageSource to be packed.
 * @param fd Indicates a writable file descriptor.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImagePackerNative_PackToFileFromImageSource(OH_ImagePackerNative *imagePacker,
    OH_PackingOptions *options, OH_ImageSourceNative *imageSource, int32_t fd);

/**
  * @brief Encoding a <b>Pixelmap</b> into the a file with fd with required format
  *
  * @param imagePacker The image packer to use for packing.
  * @param options Indicates the encoding {@link OH_PackingOptions}.
  * @param pixelmap The pixelmap to be packed.
  * @param fd Indicates a writable file descriptor.
  * @return Returns {@link Image_ErrorCode}
  * @since 12
 */
Image_ErrorCode OH_ImagePackerNative_PackToFileFromPixelmap(OH_ImagePackerNative *imagePacker,
    OH_PackingOptions *options, OH_PixelmapNative *pixelmap, int32_t fd);

/**
  * @brief Releases an imagePacker object.
  *
  * @param imagePacker A pointer to the image packer object to be released.
  * @return Returns {@link Image_ErrorCode}
  * @since 12
 */
Image_ErrorCode OH_ImagePackerNative_Release(OH_ImagePackerNative *imagePacker);

#ifdef __cplusplus
};
#endif
/* *@} */
#endif // INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_IMAGE_PACKER_NATIVE_H_