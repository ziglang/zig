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
 * @file image_source_native.h
 *
 * @brief Declares APIs for decoding an image source into a pixel map.
 *
 * @library libimage_source.so
 * @syscap SystemCapability.Multimedia.Image.ImageSource
 * @since 12
 */

#ifndef INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_IMAGE_SOURCE_NATIVE_H_
#define INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_IMAGE_SOURCE_NATIVE_H_
#include "image_common.h"

#include "pixelmap_native.h"
#include "rawfile/raw_file.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines an image source object for the image interface.
 *
 * @since 12
 */
struct OH_ImageSourceNative;
typedef struct OH_ImageSourceNative OH_ImageSourceNative;

/**
 * @brief Defines image source infomation
 * {@link OH_ImageSourceInfo_Create}.
 *
 * @since 12
 */
struct OH_ImageSource_Info;
typedef struct OH_ImageSource_Info OH_ImageSource_Info;

/**
 * @brief Enumerates decoding dynamic range..
 *
 * @since 12
 */
typedef enum {
    /*
    * Dynamic range depends on the image.
    */
    IMAGE_DYNAMIC_RANGE_AUTO = 0,
    /*
    * Standard dynamic range.
    */
    IMAGE_DYNAMIC_RANGE_SDR = 1,
    /*
    * High dynamic range.
    */
    IMAGE_DYNAMIC_RANGE_HDR = 2,
} IMAGE_DYNAMIC_RANGE;

/**
 * @brief Create a pointer for OH_ImageSource_Info struct.
 *
 * @param info The OH_ImageSource_Info pointer will be operated.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceInfo_Create(OH_ImageSource_Info **info);

/**
 * @brief Get width number for OH_ImageSource_Info struct.
 *
 * @param info The OH_ImageSource_Info pointer will be operated.
 * @param width the number of image width.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceInfo_GetWidth(OH_ImageSource_Info *info, uint32_t *width);

/**
 * @brief Get height number for OH_ImageSource_Info struct.
 *
 * @param info The OH_ImageSource_Info pointer will be operated.
 * @param height the number of image height.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceInfo_GetHeight(OH_ImageSource_Info *info, uint32_t *height);

/**
 * @brief Get isHdr for OH_ImageSource_Info struct.
 *
 * @param info The OH_ImageSource_Info pointer will be operated. Pointer connot be null.
 * @param isHdr Whether the image has a high dynamic range.
 * @return Returns {@link Image_ErrorCode} IMAGE_SUCCESS - The operation is successful.
 * returns {@link Image_ErrorCode} IMAGE_BAD_PARAMETER - Parameter error.Possible causes:Parameter verification failed.
 * @since 12
 */
Image_ErrorCode OH_ImageSourceInfo_GetDynamicRange(OH_ImageSource_Info *info, bool *isHdr);

/**
 * @brief delete OH_ImageSource_Info pointer.
 *
 * @param info The OH_ImageSource_Info pointer will be operated.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceInfo_Release(OH_ImageSource_Info *info);

/**
 * @brief Defines the options for decoding the image source.
 * It is used in {@link OH_ImageSourceNative_CreatePixelmap}.
 *
 * @since 12
 */
struct OH_DecodingOptions;
typedef struct OH_DecodingOptions OH_DecodingOptions;

/**
 * @brief Create a pointer for OH_DecodingOptions struct.
 *
 * @param  options The OH_DecodingOptions pointer will be operated.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_DecodingOptions_Create(OH_DecodingOptions **options);

/**
 * @brief Get pixelFormat number for OH_DecodingOptions struct.
 *
 * @param  options The OH_DecodingOptions pointer will be operated.
 * @param pixelFormat the number of image pixelFormat.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_DecodingOptions_GetPixelFormat(OH_DecodingOptions *options,
    int32_t *pixelFormat);

/**
 * @brief Set pixelFormat number for OH_DecodingOptions struct.
 *
 * @param  options The OH_DecodingOptions pointer will be operated.
 * @param pixelFormat the number of image pixelFormat.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_DecodingOptions_SetPixelFormat(OH_DecodingOptions *options,
    int32_t pixelFormat);

/**
 * @brief Get index number for OH_DecodingOptions struct.
 *
 * @param  options The OH_DecodingOptions pointer will be operated.
 * @param index the number of image index.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_DecodingOptions_GetIndex(OH_DecodingOptions *options, uint32_t *index);

/**
 * @brief Set index number for OH_DecodingOptions struct.
 *
 * @param  options The OH_DecodingOptions pointer will be operated.
 * @param index the number of image index.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_DecodingOptions_SetIndex(OH_DecodingOptions *options, uint32_t index);

/**
 * @brief Get rotate number for OH_DecodingOptions struct.
 *
 * @param  options The OH_DecodingOptions pointer will be operated.
 * @param rotate the number of image rotate.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_DecodingOptions_GetRotate(OH_DecodingOptions *options, float *rotate);

/**
 * @brief Set rotate number for OH_DecodingOptions struct.
 *
 * @param  options The OH_DecodingOptions pointer will be operated.
 * @param rotate the number of image rotate.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_DecodingOptions_SetRotate(OH_DecodingOptions *options, float rotate);

/**
 * @brief Get desiredSize number for OH_DecodingOptions struct.
 *
 * @param  options The OH_DecodingOptions pointer will be operated.
 * @param desiredSize the number of image desiredSize.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_DecodingOptions_GetDesiredSize(OH_DecodingOptions *options,
    Image_Size *desiredSize);

/**
 * @brief Set desiredSize number for OH_DecodingOptions struct.
 *
 * @param  options The OH_DecodingOptions pointer will be operated.
 * @param desiredSize the number of image desiredSize.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_DecodingOptions_SetDesiredSize(OH_DecodingOptions *options,
    Image_Size *desiredSize);

/**
 * @brief Set desiredRegion number for OH_DecodingOptions struct.
 *
 * @param  options The OH_DecodingOptions pointer will be operated.
 * @param desiredRegion the number of image desiredRegion.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_DecodingOptions_GetDesiredRegion(OH_DecodingOptions *options,
    Image_Region *desiredRegion);

/**
 * @brief Set desiredRegion number for OH_DecodingOptions struct.
 *
 * @param  options The OH_DecodingOptions pointer will be operated.
 * @param desiredRegion the number of image desiredRegion.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_DecodingOptions_SetDesiredRegion(OH_DecodingOptions *options,
    Image_Region *desiredRegion);

/**
 * @brief Set desiredDynamicRange number for OH_DecodingOptions struct.
 *
 * @param options The OH_DecodingOptions pointer will be operated. Pointer connot be null.
 * @param desiredDynamicRange the number of desired dynamic range {@link IMAGE_DYNAMIC_RANGE}. Pointer connot be null.
 * @return Returns {@link Image_ErrorCode} IMAGE_SUCCESS - The operation is successful.
 * returns {@link Image_ErrorCode} IMAGE_BAD_PARAMETER - Parameter error.Possible causes:Parameter verification failed.
 * @since 12
 */
Image_ErrorCode OH_DecodingOptions_GetDesiredDynamicRange(OH_DecodingOptions *options,
    int32_t *desiredDynamicRange);

/**
 * @brief Set desiredDynamicRange number for OH_DecodingOptions struct.
 *
 * @param options The OH_DecodingOptions pointer will be operated. Pointer connot be null.
 * @param desiredDynamicRange the number of desired dynamic range {@link IMAGE_DYNAMIC_RANGE}.
 * @return Returns {@link Image_ErrorCode} IMAGE_SUCCESS - The operation is successful.
 * returns {@link Image_ErrorCode} IMAGE_BAD_PARAMETER - Parameter error.Possible causes:Parameter verification failed.
 * @since 12
 */
Image_ErrorCode OH_DecodingOptions_SetDesiredDynamicRange(OH_DecodingOptions *options,
    int32_t desiredDynamicRange);

/**
 * @brief delete OH_DecodingOptions pointer.
 *
 * @param  options The OH_DecodingOptions pointer will be operated.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_DecodingOptions_Release(OH_DecodingOptions *options);

/**
 * @brief Creates an ImageSource pointer.
 *
 * @param uri Indicates a pointer to the image source URI. Only a file URI or Base64 URI is accepted.
 * @param uriSize Indicates the length of the image source URI.
 * @param res Indicates a pointer to the <b>ImageSource</b> object created at the C++ native layer.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceNative_CreateFromUri(char *uri, size_t uriSize, OH_ImageSourceNative **res);

/**
 * @brief Creates an void pointer
 *
 * @param fd Indicates the image source file descriptor.
 * @param res Indicates a void pointer to the <b>ImageSource</b> object created at the C++ native layer.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceNative_CreateFromFd(int32_t fd, OH_ImageSourceNative **res);

/**
 * @brief Creates an void pointer
 *
 * @param data Indicates a pointer to the image source data. Only a formatted packet data or Base64 data is accepted.
 * @param dataSize Indicates the size of the image source data.
 * @param res Indicates a void pointer to the <b>ImageSource</b> object created at the C++ native layer.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceNative_CreateFromData(uint8_t *data, size_t dataSize, OH_ImageSourceNative **res);

/**
 * @brief Creates an void pointer
 *
 * @param rawFile Indicates the raw file's file descriptor.
 * @param res Indicates a void pointer to the <b>ImageSource</b> object created at the C++ native layer.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceNative_CreateFromRawFile(RawFileDescriptor *rawFile, OH_ImageSourceNative **res);

/**
 * @brief Decodes an void pointer
 * based on the specified {@link OH_DecodingOptions} struct.
 *
 * @param source Indicates a void pointer(from ImageSource pointer convert).
 * @param  options Indicates a pointer to the options for decoding the image source.
 * For details, see {@link OH_DecodingOptions}.
 * @param resPixMap Indicates a void pointer to the <b>Pixelmap</b> object obtained at the C++ native layer.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceNative_CreatePixelmap(OH_ImageSourceNative *source, OH_DecodingOptions *options,
    OH_PixelmapNative **pixelmap);

/**
 * @brief Decodes an void pointer
 * the <b>Pixelmap</b> objects at the C++ native layer
 * based on the specified {@link OH_DecodingOptions} struct.
 *
 * @param source Indicates a void pointer(from ImageSource pointer convert).
 * @param  options Indicates a pointer to the options for decoding the image source.
 * For details, see {@link OH_DecodingOptions}.
 * @param resVecPixMap Indicates a pointer array to the <b>Pixelmap</b> objects obtained at the C++ native layer.
 * It cannot be a null pointer.
 * @param size Indicates a size of resVecPixMap. User can get size from {@link OH_ImageSourceNative_GetFrameCount}.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceNative_CreatePixelmapList(OH_ImageSourceNative *source, OH_DecodingOptions *options,
    OH_PixelmapNative *resVecPixMap[], size_t size);

/**
 * @brief Obtains the delay time list from some <b>ImageSource</b> objects (such as GIF image sources).
 *
 * @param source Indicates a void pointer(from ImageSource pointer convert).
 * @param delayTimeList Indicates a pointer to the delay time list obtained. It cannot be a null pointer.
 * @param size Indicates a size of delayTimeList. User can get size from {@link OH_ImageSourceNative_GetFrameCount}.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceNative_GetDelayTimeList(OH_ImageSourceNative *source, int32_t *delayTimeList, size_t size);

/**
 * @brief Obtains image source information from an <b>ImageSource</b> object by index.
 *
 * @param source Indicates a void pointer(from ImageSource pointer convert).
 * @param index Indicates the index of the frame.
 * @param info Indicates a pointer to the image source information obtained.
 * For details, see {@link OH_ImageSource_Info}.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceNative_GetImageInfo(OH_ImageSourceNative *source, int32_t index,
    OH_ImageSource_Info *info);

/**
 * @brief Obtains the value of an image property from an <b>ImageSource</b> object.
 *
 * @param source Indicates a void pointer(from ImageSource pointer convert).
 * @param key Indicates a pointer to the property. For details, see {@link Image_String}., key is an exif constant.
 * Release after use ImageSource, see {@link OH_ImageSourceNative_Release}.
 * @param value Indicates a pointer to the value obtained.The user can pass in a null pointer and zero size,
 * we will allocate memory, but user must free memory after use.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceNative_GetImageProperty(OH_ImageSourceNative *source, Image_String *key,
    Image_String *value);

/**
 * @brief Modifies the value of an image property of an <b>ImageSource</b> object.
 * @param source Indicates a void pointer(from ImageSource pointer convert).
 * @param key Indicates a pointer to the property. For details, see {@link Image_String}., key is an exif constant.
 * Release after use ImageSource, see {@link OH_ImageSourceNative_Release}.
 * @param value Indicates a pointer to the new value of the property.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceNative_ModifyImageProperty(OH_ImageSourceNative *source, Image_String *key,
    Image_String *value);

/**
 * @brief Obtains the number of frames from an <b>ImageSource</b> object.
 *
 * @param source Indicates a pointer to the {@link OH_ImageSource} object at the C++ native layer.
 * @param res Indicates a pointer to the number of frames obtained.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceNative_GetFrameCount(OH_ImageSourceNative *source, uint32_t *frameCount);

/**
 * @brief Releases an <b>ImageSourc</b> object.
 *
 * @param source Indicates a ImageSource pointer.
 * @return Returns {@link Image_ErrorCode}
 * @since 12
 */
Image_ErrorCode OH_ImageSourceNative_Release(OH_ImageSourceNative *source);

#ifdef __cplusplus
};
#endif
/** @} */
#endif // INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_IMAGE_SOURCE_NATIVE_H_