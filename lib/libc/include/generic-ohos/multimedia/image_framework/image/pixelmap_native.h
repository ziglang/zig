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
 * @brief Provides APIs for obtaining pixel map data and information.
 *
 * @Syscap SystemCapability.Multimedia.Image.Core
 * @since 12
 */

/**
 * @file pixelmap_native.h
 *
 * @brief Declares the APIs that can access a pixel map.
 *
 * @library libpixelmap.so
 * @Syscap SystemCapability.Multimedia.Image.Core
 * @since 12
 */

#ifndef INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_PIXELMAP_NATIVE_H_
#define INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_PIXELMAP_NATIVE_H_
#include "image_common.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Define a Pixelmap struct type, used for pixelmap pointer controls.
 *
 * @since 12
 */
struct OH_PixelmapNative;
typedef struct OH_PixelmapNative OH_PixelmapNative;

/**
 * @brief Define a pixelmap alpha type.
 *
 * @since 12
 */
typedef enum {
    /*
    * Unknown format
    */
    PIXELMAP_ALPHA_TYPE_UNKNOWN = 0,
     /*
    * Opaque format
    */
    PIXELMAP_ALPHA_TYPE_OPAQUE = 1,
     /*
    * Premultiplied format
    */
    PIXELMAP_ALPHA_TYPE_PREMULTIPLIED = 2,
    /*
     * Unpremultiplied format
     */
    PIXELMAP_ALPHA_TYPE_UNPREMULTIPLIED = 3,
}PIXELMAP_ALPHA_TYPE;

typedef enum {
    /*
    * Unknown format
    */
    PIXEL_FORMAT_UNKNOWN = 0,
    /*
    * RGB_565 format
    */
    PIXEL_FORMAT_RGB_565 = 2,
    /*
    * RGBA_8888 format
    */
    PIXEL_FORMAT_RGBA_8888 = 3,
    /*
    * BGRA_8888 format
    */
    PIXEL_FORMAT_BGRA_8888 = 4,
    /*
    * RGB_888 format
    */
    PIXEL_FORMAT_RGB_888 = 5,
    /*
    * ALPHA_8 format
    */
    PIXEL_FORMAT_ALPHA_8 = 6,
    /*
    * RGBA_F16 format
    */
    PIXEL_FORMAT_RGBA_F16 = 7,
    /*
    * NV21 format
    */
    PIXEL_FORMAT_NV21 = 8,
    /*
    * NV12 format
    */
    PIXEL_FORMAT_NV12 = 9,
} PIXEL_FORMAT;

/**
 * @brief Defines the options used for creating a pixel map.
 *
 * @since 12
 */
struct OH_Pixelmap_InitializationOptions;
typedef struct OH_Pixelmap_InitializationOptions OH_Pixelmap_InitializationOptions;

/**
 * @brief Create a for InitializationOtions struct.
 *
 * @param options The InitializationOtions pointer will be operated.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapInitializationOptions_Create(OH_Pixelmap_InitializationOptions **options);

/**
 * @brief Get width number for InitializationOtions struct.
 *
 * @param options The InitializationOtions pointer will be operated.
 * @param width the number of image width.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapInitializationOptions_GetWidth(OH_Pixelmap_InitializationOptions *options,
    uint32_t *width);

/**
 * @brief Set width number for InitializationOtions struct.
 *
 * @param options The InitializationOtions pointer will be operated.
 * @param width the number of image width.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapInitializationOptions_SetWidth(OH_Pixelmap_InitializationOptions *options,
    uint32_t width);

/**
 * @brief Get height number for InitializationOtions struct.
 *
 * @param options The InitializationOtions pointer will be operated.
 * @param height the number of image height.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapInitializationOptions_GetHeight(OH_Pixelmap_InitializationOptions *options,
    uint32_t *height);

/**
 * @brief Set height number for InitializationOtions struct.
 *
 * @param options The InitializationOtions pointer will be operated.
 * @param height the number of image height.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapInitializationOptions_SetHeight(OH_Pixelmap_InitializationOptions *options,
    uint32_t height);

/**
 * @brief Get pixelFormat number for InitializationOtions struct.
 *
 * @param options The InitializationOtions pointer will be operated.
 * @param pixelFormat the number of image pixelFormat.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapInitializationOptions_GetPixelFormat(OH_Pixelmap_InitializationOptions *options,
    int32_t *pixelFormat);

/**
 * @brief Set pixelFormat number for InitializationOtions struct.
 *
 * @param options The InitializationOtions pointer will be operated.
 * @param pixelFormat the number of image pixelFormat.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapInitializationOptions_SetPixelFormat(OH_Pixelmap_InitializationOptions *options,
    int32_t pixelFormat);

/**
 * @brief Get pixelFormat number for InitializationOtions struct.
 *
 * @param options The InitializationOtions pointer will be operated.
 * @param srcpixelFormat the number of image srcpixelFormat.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapInitializationOptions_GetSrcPixelFormat(OH_Pixelmap_InitializationOptions *options,
    int32_t *srcpixelFormat);

/**
 * @brief Set pixelFormat number for InitializationOtions struct.
 *
 * @param options The InitializationOtions pointer will be operated.
 * @param srcpixelFormat the number of image srcpixelFormat.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapInitializationOptions_SetSrcPixelFormat(OH_Pixelmap_InitializationOptions *options,
    int32_t srcpixelFormat);

/**
 * @brief Get alphaType number for InitializationOtions struct.
 *
 * @param options The InitializationOtions pointer will be operated.
 * @param alphaType the number of image alphaType.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapInitializationOptions_GetAlphaType(OH_Pixelmap_InitializationOptions *options,
    int32_t *alphaType);

/**
 * @brief Set alphaType number for InitializationOtions struct.
 *
 * @param options The InitializationOtions pointer will be operated.
 * @param alphaType the number of image alphaType.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapInitializationOptions_SetAlphaType(OH_Pixelmap_InitializationOptions *options,
    int32_t alphaType);

/**
 * @brief delete InitializationOtions pointer.
 *
 * @param options The InitializationOtions pointer will be operated.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapInitializationOptions_Release(OH_Pixelmap_InitializationOptions *options);

/**
 * @brief Defines the pixel map information.
 *
 * @since 12
 */
struct OH_Pixelmap_ImageInfo;
typedef struct OH_Pixelmap_ImageInfo OH_Pixelmap_ImageInfo;

/**
 * @brief Create imageinfo struct  .
 *
 * @param info The imageinfo pointer will be operated.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapImageInfo_Create(OH_Pixelmap_ImageInfo **info);

/**
 * @brief Get width number for imageinfo struct.
 *
 * @param info The imageinfo pointer will be operated.
 * @param width The number of imageinfo width.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapImageInfo_GetWidth(OH_Pixelmap_ImageInfo *info, uint32_t *width);

/**
 * @brief Get height number for imageinfo struct.
 *
 * @param info The imageinfo pointer will be operated.
 * @param height The number of imageinfo height.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapImageInfo_GetHeight(OH_Pixelmap_ImageInfo *info, uint32_t *height);

/**
 * @brief Get rowStride number for imageinfo struct.
 *
 * @param info The imageinfo pointer will be operated.
 * @param rowStride The number of imageinfo rowStride.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapImageInfo_GetRowStride(OH_Pixelmap_ImageInfo *info, uint32_t *rowStride);

/**
 * @brief Get pixelFormat number for imageinfo struct.
 *
 * @param info The imageinfo pointer will be operated.
 * @param pixelFormat The number of imageinfo pixelFormat.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapImageInfo_GetPixelFormat(OH_Pixelmap_ImageInfo *info, int32_t *pixelFormat);

/**
 * @brief Get density number for imageinfo struct.
 *
 * @param info The imageinfo pointer will be operated.
 * @param density The number of imageinfo density.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapImageInfo_GetAlphaType(OH_Pixelmap_ImageInfo *info, int32_t *alphaType);

/**
 * @brief Get isHdr boolean for imageinfo struct.
 *
 * @param info The imageinfo pointer will be operated. Pointer connot be null.
 * @param isHdr Whether the image has a high dynamic range.
 * @return Returns {@link Image_ErrorCode} IMAGE_SUCCESS - The operation is successful.
 * returns {@link Image_ErrorCode} IMAGE_BAD_PARAMETER - Parameter error.Possible causes:Parameter verification failed.
 * @since 12
 */
Image_ErrorCode OH_PixelmapImageInfo_GetDynamicRange(OH_Pixelmap_ImageInfo *info, bool *isHdr);

/**
 * @brief Delete imageinfo struct pointer.
 *
 * @param info The imageinfo pointer will be operated.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapImageInfo_Release(OH_Pixelmap_ImageInfo *info);

/**
 * @brief Creates a <b>PixelMap</b> object.
 *
 * @param data Color buffer in BGRA_8888 format.
 * @param dataLength Color buffer size in BGRA_8888 format.
 * @param options IPixel properties, including the alpha type, size, pixel format, and editable.
 * @param pixelmap Pixelmap pointer for created.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapNative_CreatePixelmap(uint8_t *data, size_t dataLength,
    OH_Pixelmap_InitializationOptions *options, OH_PixelmapNative **pixelmap);

/**
 * @brief Reads data of this pixel map to an Buffer. If this pixel map is created in the BGRA_8888 format,
 * the data read is the same as the original data.
 *
 * @param pixelmap The Pixelmap pointer will be operated.
 * @param destination Buffer to which the image pixel map data will be written.
 * @param bufferSize Buffer size to which the image pixel map data will be written.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapNative_ReadPixels(OH_PixelmapNative *pixelmap, uint8_t *destination, size_t *bufferSize);

/**
 * @brief Reads image data in an Buffer and writes the data to a Pixelmap object.
 *
 * @param pixelmap The Pixelmap pointer will be operated.
 * @param source Buffer from which the image data will be read.
 * @param bufferSize Buffer size from which the image data will be read.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapNative_WritePixels(OH_PixelmapNative *pixelmap, uint8_t *source, size_t bufferSize);

/**
 * @brief Convert {@link OH_PixelmapNative} to standard dynamic range.
 *
 * @param pixelmap The Pixelmap pointer will be operated. Pointer connot be null.
 * @return Returns {@link Image_ErrorCode} IMAGE_SUCCESS - The operation is successful.
 * returns {@link Image_ErrorCode} IMAGE_BAD_PARAMETER - Parameter error.Possible causes:Parameter verification failed.
 * returns {@link Image_ErrorCode} IMAGE_UNSUPPORTED_OPERATION - Unsupported operation.Pixelmap can't be converted.
 * @since 12
 */
Image_ErrorCode OH_PixelmapNative_ToSdr(OH_PixelmapNative *pixelmap);

/**
 * @brief Obtains pixel map information of this image.
 *
 * @param pixelmap The Pixelmap pointer will be operated.
 * @param imageInfo Indicates the pointer to the image information.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapNative_GetImageInfo(OH_PixelmapNative *pixelmap, OH_Pixelmap_ImageInfo *imageInfo);

/**
 * @brief Sets an opacity rate for this image pixel map.
 *
 * @param pixelmap The Pixelmap pointer will be operated.
 * @param rate Opacity rate to set. The value ranges from 0 to 1.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapNative_Opacity(OH_PixelmapNative *pixelmap, float rate);

/**
 * @brief Scales this image based on the input width and height.
 *
 * @param pixelmap The Pixelmap pointer will be operated.
 * @param scaleX Scaling ratio of the width.
 * @param scaleY Scaling ratio of the height.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapNative_Scale(OH_PixelmapNative *pixelmap, float scaleX, float scaleY);

/**
 * @brief Translates this image based on the input coordinates.
 *
 * @param pixelmap The Pixelmap pointer will be operated.
 * @param x The distance to be translate in the X direction.
 * @param y The distance to be translate in the Y direction.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapNative_Translate(OH_PixelmapNative *pixelmap, float x, float y);

/**
 * @brief Rotates this image based on the input angle.
 *
 * @param pixelmap The Pixelmap pointer will be operated.
 * @param angle Angle to rotate.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapNative_Rotate(OH_PixelmapNative *pixelmap, float angle);

/**
 * @brief Flips this image horizontally or vertically, or both.
 *
 * @param pixelmap The Pixelmap pointer will be operated.
 * @param shouldFilpHorizontally Whether to flip the image horizontally.
 * @param shouldFilpVertically Whether to flip the image vertically.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapNative_Flip(OH_PixelmapNative *pixelmap, bool shouldFilpHorizontally, bool shouldFilpVertically);

/**
 * @brief Crops this image based on the input size.
 *
 * @param pixelmap The Pixelmap pointer will be operated.
 * @param region Area size, read according to area.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapNative_Crop(OH_PixelmapNative *pixelmap, Image_Region *region);

/**
 * @brief Releases an <b>OH_Pixelmap</b> object.
 *
 * @param pixelmap The Pixelmap pointer will be operated.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapNative_Release(OH_PixelmapNative *pixelmap);

/**
 * @brief Converting images to alpha format
 *
 * @param srcpixelmap The source pixel map pointer will be operated.
 * @param dstpixelmap The destination pixel map pointer will be operated.
 * @param isPremul Whether it is pre-multiplied, true for prediction, false for non-pre-multiplied.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapNative_ConvertAlphaFormat(OH_PixelmapNative* srcpixelmap,
    OH_PixelmapNative* dstpixelmap, const bool isPremul);

/**
 * @brief Create a empty <b>PixelMap</b> object.
 *
 * @param options IPixel properties, including the alpha type, size, pixel format, and editable.
 * @param pixelmap Pixelmap pointer for created.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_PixelmapNative_CreateEmptyPixelmap(
    OH_Pixelmap_InitializationOptions *options, OH_PixelmapNative **pixelmap);

#ifdef __cplusplus
};
#endif
/** @} */
#endif // INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_PIXELMAP_NATIVE_H_