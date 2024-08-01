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
 * @brief Provides native APIs for image sources.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */

/**
 * @file image_source_mdk.h
 *
 * @brief Declares APIs for decoding an image source into a pixel map.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */

#ifndef INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_SOURCE_MDK_H_
#define INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_SOURCE_MDK_H_
#include <cstdint>
#include "napi/native_api.h"
#include "image_mdk_common.h"
#include "rawfile/raw_file.h"
#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines a native image source object for the image source APIs.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
struct ImageSourceNative_;

/**
 * @brief Defines a native image source object for the image source APIs.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
typedef struct ImageSourceNative_ ImageSourceNative;

/**
 * @brief Defines a pointer to bits per sample, one of the image properties.
 * It is used in {@link OH_ImageSource_GetImageProperty} and {@link OH_ImageSource_ModifyImageProperty}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
const char* OHOS_IMAGE_PROPERTY_BITS_PER_SAMPLE = "BitsPerSample";

/**
 * @brief Defines a pointer to the orientation, one of the image properties.
 * It is used in {@link OH_ImageSource_GetImageProperty} and {@link OH_ImageSource_ModifyImageProperty}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
const char* OHOS_IMAGE_PROPERTY_ORIENTATION = "Orientation";

/**
 * @brief Defines a pointer to the image length, one of the image properties.
 * It is used in {@link OH_ImageSource_GetImageProperty} and {@link OH_ImageSource_ModifyImageProperty}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
const char* OHOS_IMAGE_PROPERTY_IMAGE_LENGTH = "ImageLength";

/**
 * @brief Defines a pointer to the image width, one of the image properties.
 * It is used in {@link OH_ImageSource_GetImageProperty} and {@link OH_ImageSource_ModifyImageProperty}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
const char* OHOS_IMAGE_PROPERTY_IMAGE_WIDTH = "ImageWidth";

/**
 * @brief Defines a pointer to the GPS latitude, one of the image properties.
 * It is used in {@link OH_ImageSource_GetImageProperty} and {@link OH_ImageSource_ModifyImageProperty}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
const char* OHOS_IMAGE_PROPERTY_GPS_LATITUDE = "GPSLatitude";

/**
 * @brief Defines a pointer to the GPS longitude, one of the image properties.
 * It is used in {@link OH_ImageSource_GetImageProperty} and {@link OH_ImageSource_ModifyImageProperty}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
const char* OHOS_IMAGE_PROPERTY_GPS_LONGITUDE = "GPSLongitude";

/**
 * @brief Defines a pointer to the GPS latitude reference information, one of the image properties.
 * It is used in {@link OH_ImageSource_GetImageProperty} and {@link OH_ImageSource_ModifyImageProperty}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
const char* OHOS_IMAGE_PROPERTY_GPS_LATITUDE_REF = "GPSLatitudeRef";

/**
 * @brief Defines a pointer to the GPS longitude reference information, one of the image properties.
 * It is used in {@link OH_ImageSource_GetImageProperty} and {@link OH_ImageSource_ModifyImageProperty}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
const char* OHOS_IMAGE_PROPERTY_GPS_LONGITUDE_REF = "GPSLongitudeRef";

/**
 * @brief Defines a pointer to the created date and time, one of the image properties.
 * It is used in {@link OH_ImageSource_GetImageProperty} and {@link OH_ImageSource_ModifyImageProperty}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
const char* OHOS_IMAGE_PROPERTY_DATE_TIME_ORIGINAL = "DateTimeOriginal";

/**
 * @brief Defines a pointer to the exposure time, one of the image properties.
 * It is used in {@link OH_ImageSource_GetImageProperty} and {@link OH_ImageSource_ModifyImageProperty}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
const char* OHOS_IMAGE_PROPERTY_EXPOSURE_TIME = "ExposureTime";

/**
 * @brief Defines a pointer to the scene type, one of the image properties.
 * It is used in {@link OH_ImageSource_GetImageProperty} and {@link OH_ImageSource_ModifyImageProperty}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
const char* OHOS_IMAGE_PROPERTY_SCENE_TYPE = "SceneType";

/**
 * @brief Defines a pointer to the ISO speed ratings, one of the image properties.
 * It is used in {@link OH_ImageSource_GetImageProperty} and {@link OH_ImageSource_ModifyImageProperty}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
const char* OHOS_IMAGE_PROPERTY_ISO_SPEED_RATINGS = "ISOSpeedRatings";

/**
 * @brief Defines a pointer to the f-number of the image, one of the image properties.
 * It is used in {@link OH_ImageSource_GetImageProperty} and {@link OH_ImageSource_ModifyImageProperty}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
const char* OHOS_IMAGE_PROPERTY_F_NUMBER = "FNumber";

/**
 * @brief Defines a pointer to the compressed bits per pixel, one of the image properties.
 * It is used in {@link OH_ImageSource_GetImageProperty} and {@link OH_ImageSource_ModifyImageProperty}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
const char* OHOS_IMAGE_PROPERTY_COMPRESSED_BITS_PER_PIXEL = "CompressedBitsPerPixel";

/**
 * @brief Defines the region of the image source to decode.
 * It is used in {@link OhosImageDecodingOps}, {@link OH_ImageSource_CreatePixelMap}, and
 * {@link OH_ImageSource_CreatePixelMapList}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
struct OhosImageRegion {
    /** X coordinate of the start point, in pixels. */
    int32_t x;
    /** Y coordinate of the start point, in pixels. */
    int32_t y;
    /** Width of the region, in pixels. */
    int32_t width;
    /** Height of the region, in pixels. */
    int32_t height;
};

/**
 * @brief Defines image source options infomation
 * {@link OH_ImageSource_Create} and {@link OH_ImageSource_CreateIncremental}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
struct OhosImageSourceOps {
    /** Pixel density of the image source. */
    int32_t density;
    /** Image source pixel format, used to describe YUV buffer usually. */
    int32_t pixelFormat;
    /** Image source pixel size of width and height. */
    struct OhosImageSize size;
};

/**
 * @brief Defines the options for decoding the image source.
 * It is used in {@link OH_ImageSource_CreatePixelMap} and {@link OH_ImageSource_CreatePixelMapList}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
struct OhosImageDecodingOps {
    /** Defines output pixel map editable. */
    int8_t editable;
    /** Defines output pixel format. */
    int32_t pixelFormat;
    /** Defines decoding target pixel density. */
    int32_t fitDensity;
    /** Defines decoding index of image source. */
    uint32_t index;
    /** Defines decoding sample size option. */
    uint32_t sampleSize;
    /** Defines decoding rotate option. */
    uint32_t rotate;
    /** Defines decoding target pixel size of width and height. */
    struct OhosImageSize size;
    /** Defines image source pixel region for decoding. */
    struct OhosImageRegion region;
};

/**
 * @brief Defines the image source information, which is obtained by calling {@link OH_ImageSource_GetImageInfo}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
struct OhosImageSourceInfo {
    /** Pixel format of the image source. It is set in {@link OH_ImageSource_Create}. */
    int32_t pixelFormat;
    /** Color space of the image source. */
    int32_t colorSpace;
    /** Alpha type of the image source. */
    int32_t alphaType;
    /** Image density of the image source. It is set in {@link OH_ImageSource_Create}. */
    int32_t density;
    /** Pixel width and height of the image source. */
    struct OhosImageSize size;
};

/**
 * @brief Defines the input resource of the image source. It is obtained by calling {@link OH_ImageSource_Create}.
 * Only one type of resource is accepted at a time.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 * @deprecated since 11
 */
struct OhosImageSource {
    /** Pointer to the image source URI. Only a file URI or Base64 URI is accepted. */
    char* uri = nullptr;
    /** Length of the image source URI. */
    size_t uriSize = 0;
    /** Descriptor of the image source. */
    int32_t fd = -1;
    /** Pointer to the image source buffer. Only a formatted packet buffer or Base64 buffer is accepted. */
    uint8_t* buffer = nullptr;
    /** Size of the image source buffer. */
    size_t bufferSize = 0;
};

/**
 * @brief Defines the delay time list of the image source. It is obtained by calling
 * {@link OH_ImageSource_GetDelayTime}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
struct OhosImageSourceDelayTimeList {
    /** Pointer to the head of the image source delay time list. */
    int32_t* delayTimeList;
    /** Size of the image source delay time list. */
    size_t size = 0;
};

/**
 * @brief Defines image source supported format string.
 * {@link OhosImageSourceSupportedFormatList} and {@link OH_ImageSource_GetSupportedFormats}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
struct OhosImageSourceSupportedFormat {
    /** Image source supported format string head.*/
    char* format = nullptr;
    /** Image source supported format string size.*/
    size_t size = 0;
};

/**
 * @brief Defines the format string list supported by the image source.
 * It is obtained by calling {@link OH_ImageSource_GetSupportedFormats}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
struct OhosImageSourceSupportedFormatList {
    /** Image source supported format string list head.*/
    struct OhosImageSourceSupportedFormat** supportedFormatList = nullptr;
    /** Image source supported format string list size.*/
    size_t size = 0;
};

/**
 * @brief Defines the property string (in key-value format) of the image source.
 * It is used in {@link OH_ImageSource_GetImageProperty} and {@link OH_ImageSource_ModifyImageProperty}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
struct OhosImageSourceProperty {
    /** Image source property key and value string head.*/
    char* value = nullptr;
    /** Image source property key and value string size.*/
    size_t size = 0;
};

/**
 * @brief Defines the update data of the image source. It is obtained by calling {@link OH_ImageSource_UpdateData}.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
struct OhosImageSourceUpdateData {
    /** Image source update data buffer.*/
    uint8_t* buffer = nullptr;
    /** Image source update data buffer size.*/
    size_t bufferSize = 0;
    /** Image source offset of update data buffer.*/
    uint32_t offset = 0;
    /** Image source update data length in update data buffer.*/
    uint32_t updateLength = 0;
    /** Image source update data is completed in this session.*/
    int8_t isCompleted = 0;
};

/**
 * @brief Creates an <b>ImageSource</b> object at the JavaScript native layer based on the specified
 * {@link OhosImageSource} and {@link OhosImageSourceOps} structs.
 *
 * @param env Indicates a pointer to the Java Native Interface (JNI) environment.
 * @param src Indicates a pointer to the input resource of the image source. For details, see {@link OhosImageSource}.
 * @param ops Indicates a pointer to the options for creating the image source.
 * For details, see {@link OhosImageSourceOps}.
 * @param res Indicates a pointer to the <b>ImageSource</b> object created at the JavaScript native layer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_SOURCE_DATA_INCOMPLETE - if image source data incomplete.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_SOURCE_DATA - if image source data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_TOO_LARGE - if image data too large.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_HEAD_ABNORMAL - if image decode head error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_EXIF_UNSUPPORT - if image decode exif unsupport.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PROPERTY_NOT_EXIST - if image property not exist.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_FILE_DAMAGED - if file damaged.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_FILE_FD_ERROR - if file fd is bad.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_STREAM_SIZE_ERROR - if stream bad.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_SEEK_FAILED - if seek file failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PEEK_FAILED - if peek file failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_FREAD_FAILED - if read file failed.
 * @see {@link OhosImageSource}, {@link OhosImageSourceOps}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 * @deprecated since 11
 * @useinstead image#OH_ImageSource_CreateFromUri
 * @useinstead image#OH_ImageSource_CreateFromFd
 * @useinstead image#OH_ImageSource_CreateFromData
 */
int32_t OH_ImageSource_Create(napi_env env, struct OhosImageSource* src,
    struct OhosImageSourceOps* ops, napi_value *res);

/**
 * @brief Creates an <b>ImageSource</b> object at the JavaScript native layer based on the specified
 * image source URI and {@link OhosImageSourceOps} structs.
 *
 * @param env Indicates a pointer to the Java Native Interface (JNI) environment.
 * @param uri Indicates a pointer to the image source URI. Only a file URI or Base64 URI is accepted.
 * @param size Indicates the length of the image source URI.
 * @param ops Indicates a pointer to the options for creating the image source.
 * For details, see {@link OhosImageSourceOps}.
 * @param res Indicates a pointer to the <b>ImageSource</b> object created at the JavaScript native layer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * @see {@link OhosImageSourceOps}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 11
 * @version 4.1
 */
int32_t OH_ImageSource_CreateFromUri(napi_env env, char* uri, size_t size,
    struct OhosImageSourceOps* ops, napi_value *res);

/**
 * @brief Creates an <b>ImageSource</b> object at the JavaScript native layer based on the specified
 * image source file descriptor and {@link OhosImageSourceOps} structs.
 *
 * @param env Indicates a pointer to the Java Native Interface (JNI) environment.
 * @param fd Indicates the image source file descriptor.
 * @param ops Indicates a pointer to the options for creating the image source.
 * For details, see {@link OhosImageSourceOps}.
 * @param res Indicates a pointer to the <b>ImageSource</b> object created at the JavaScript native layer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * @see {@link OhosImageSourceOps}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 11
 * @version 4.1
 */
int32_t OH_ImageSource_CreateFromFd(napi_env env, int32_t fd,
    struct OhosImageSourceOps* ops, napi_value *res);

/**
 * @brief Creates an <b>ImageSource</b> object at the JavaScript native layer based on the specified
 * image source data and {@link OhosImageSourceOps} structs.
 *
 * @param env Indicates a pointer to the Java Native Interface (JNI) environment.
 * @param data Indicates a pointer to the image source data. Only a formatted packet data or Base64 data is accepted.
 * @param dataSize Indicates the size of the image source data.
 * @param ops Indicates a pointer to the options for creating the image source.
 * For details, see {@link OhosImageSourceOps}.
 * @param res Indicates a pointer to the <b>ImageSource</b> object created at the JavaScript native layer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * @see {@link OhosImageSourceOps}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 11
 * @version 4.1
 */
int32_t OH_ImageSource_CreateFromData(napi_env env, uint8_t* data, size_t dataSize,
    struct OhosImageSourceOps* ops, napi_value *res);

/**
 * @brief Creates an <b>ImageSource</b> object at the JavaScript native layer based on the specified
 * raw file's file descriptor and {@link OhosImageSourceOps} structs.
 *
 * @param env Indicates a pointer to the Java Native Interface (JNI) environment.
 * @param rawFile Indicates the raw file's file descriptor.
 * @param ops Indicates a pointer to the options for creating the image source.
 * For details, see {@link OhosImageSourceOps}.
 * @param res Indicates a pointer to the <b>ImageSource</b> object created at the JavaScript native layer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * @see {@link OhosImageSourceOps}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 11
 * @version 4.1
 */
int32_t OH_ImageSource_CreateFromRawFile(napi_env env, RawFileDescriptor rawFile,
    struct OhosImageSourceOps* ops, napi_value *res);

/**
 * @brief Creates an incremental <b>ImageSource</b> object at the JavaScript native layer based on the specified
 * {@link OhosImageSource} and {@link OhosImageSourceOps} structs.
 * The image source data will be updated through {@link OH_ImageSource_UpdateData}.
 *
 * @param env Indicates a pointer to the JNI environment.
 * @param src Indicates a pointer to the input resource of the image source. Only the buffer type is accepted.
 * For details, see {@link OhosImageSource}.
 * @param ops Indicates a pointer to the options for creating the image source.
 * For details, see {@link OhosImageSourceOps}.
 * @param res Indicates a pointer to the <b>ImageSource</b> object created at the JavaScript native layer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_SOURCE_DATA_INCOMPLETE - if image source data incomplete.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_SOURCE_DATA - if image source data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_TOO_LARGE - if image data too large.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_HEAD_ABNORMAL - if image decode head error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_EXIF_UNSUPPORT - if image decode exif unsupport.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PROPERTY_NOT_EXIST - if image property not exist.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_FILE_DAMAGED - if file damaged.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_FILE_FD_ERROR - if file fd is bad.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_STREAM_SIZE_ERROR - if stream bad.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_SEEK_FAILED - if seek file failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PEEK_FAILED - if peek file failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_FREAD_FAILED - if read file failed.
 * @see {@link OhosImageSource}, {@link OhosImageSourceOps}, {@link OH_ImageSource_UpdateData}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 * @deprecated since 11
 * @useinstead image#OH_ImageSource_CreateIncrementalFromData
 */
int32_t OH_ImageSource_CreateIncremental(napi_env env, struct OhosImageSource* source,
    struct OhosImageSourceOps* ops, napi_value *res);

/**
 * @brief Creates an incremental <b>ImageSource</b> object at the JavaScript native layer based on the specified
 * image source data and {@link OhosImageSourceOps} structs.
 * The image source data will be updated through {@link OH_ImageSource_UpdateData}.
 *
 * @param env Indicates a pointer to the JNI environment.
 * @param data Indicates a pointer to the image source data. Only a formatted packet data or Base64 data is accepted.
 * @param dataSize Indicates the size of the image source data.
 * @param ops Indicates a pointer to the options for creating the image source.
 * For details, see {@link OhosImageSourceOps}.
 * @param res Indicates a pointer to the <b>ImageSource</b> object created at the JavaScript native layer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * @see {@link OhosImageSourceOps}, {@link OH_ImageSource_UpdateData}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 11
 * @version 4.1
 */
int32_t OH_ImageSource_CreateIncrementalFromData(napi_env env, uint8_t* data, size_t dataSize,
    struct OhosImageSourceOps* ops, napi_value *res);

/**
 * @brief Obtains all supported decoding formats.
 *
 * @param res Indicates a pointer to the <b>OhosImageSourceSupportedFormatList</b> struct.
 * When the input <b>supportedFormatList</b> is a null pointer and <b>size</b> is 0, the size of the supported formats
 * is returned through <b>size</b> in <b>res</b>.
 * To obtain all formats, a space larger than <b>size</b> is required.
 * In addition, sufficient space must be reserved for each format supported.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CHECK_FORMAT_ERROR - if decode fail.
 * @see {@link OhosImageSourceSupportedFormatList}, {@link OhosImageSourceSupportedFormat}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
int32_t OH_ImageSource_GetSupportedFormats(struct OhosImageSourceSupportedFormatList* res);

/**
 * @brief Converts an {@link ImageSource} object at the JavaScript native layer to an <b>ImageSourceNative</b> object
 * at the C++ native layer.
 *
 * @param env Indicates a pointer to the JNI environment.
 * @param source Indicates a pointer to the <b>ImageSource</b> object at the JavaScript native layer.
 * @return Returns a pointer to the {@link ImageSourceNative} object if the operation is successful;
 * returns a null pointer otherwise.
 * @see {@link ImageSourceNative}, {@link OH_ImageSource_Release}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
ImageSourceNative* OH_ImageSource_InitNative(napi_env env, napi_value source);

/**
 * @brief Decodes an <b>ImageSource</b> object to obtain a <b>PixelMap</b> object at the JavaScript native layer
 * based on the specified {@link OhosImageDecodingOps} struct.
 *
 * @param native Indicates a pointer to the {@link ImageSourceNative} object at the C++ native layer.
 * @param ops Indicates a pointer to the options for decoding the image source.
 * For details, see {@link OhosImageDecodingOps}.
 * @param res Indicates a pointer to the <b>PixelMap</b> object obtained at the JavaScript native layer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_HEAD_ABNORMAL - if image decode head error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CREATE_DECODER_FAILED - if create decoder failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CREATE_ENCODER_FAILED - if create encoder failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CHECK_FORMAT_ERROR - if check format failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_NOT_EXIST - if sharememory error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_DATA_ABNORMAL - if sharememory data abnormal.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_ABNORMAL - if image decode error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MALLOC_ABNORMAL - if image malloc error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INIT_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CROP - if crop error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ENCODE_FAILED - if image add pixel map fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_HW_DECODE_UNSUPPORT - if image hardware decode unsupported.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_HW_DECODE_FAILED - if hard decode failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_IPC - if ipc error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALPHA_TYPE_ERROR - if hard decode failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALLOCATER_TYPE_ERROR - if hard decode failed.
 * @see {@link ImageSourceNative}, {@link OhosImageDecodingOps}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
int32_t OH_ImageSource_CreatePixelMap(const ImageSourceNative* native,
    struct OhosImageDecodingOps* ops, napi_value *res);

/**
 * @brief Decodes an <b>ImageSource</b> to obtain all the <b>PixelMap</b> objects at the JavaScript native layer
 * based on the specified {@link OhosImageDecodingOps} struct.
 *
 * @param native Indicates a pointer to the {@link ImageSourceNative} object at the C++ native layer.
 * @param ops Indicates a pointer to the options for decoding the image source.
 * For details, see {@link OhosImageDecodingOps}.
 * @param res Indicates a pointer to the <b>PixelMap</b> objects obtained at the JavaScript native layer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_HEAD_ABNORMAL - if image decode head error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CREATE_DECODER_FAILED - if create decoder failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CREATE_ENCODER_FAILED - if create encoder failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CHECK_FORMAT_ERROR - if check format failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_NOT_EXIST - if sharememory error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_DATA_ABNORMAL - if sharememory data abnormal.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_ABNORMAL - if image decode error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MALLOC_ABNORMAL - if image malloc error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INIT_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CROP - if crop error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ENCODE_FAILED - if image add pixel map fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_HW_DECODE_UNSUPPORT - if image hardware decode unsupported.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_HW_DECODE_FAILED - if hard decode failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_IPC - if ipc error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALPHA_TYPE_ERROR - if hard decode failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALLOCATER_TYPE_ERROR - if hard decode failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_EXIF_UNSUPPORT - if image decode exif unsupport.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PROPERTY_NOT_EXIST - if image property not exist.
 * @see {@link ImageSourceNative}, {@link OhosImageDecodingOps}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
int32_t OH_ImageSource_CreatePixelMapList(const ImageSourceNative* native,
    struct OhosImageDecodingOps* ops, napi_value *res);

/**
 * @brief Obtains the delay time list from some <b>ImageSource</b> objects (such as GIF image sources).
 *
 * @param native Indicates a pointer to the {@link ImageSourceNative} object at the C++ native layer.
 * @param res Indicates a pointer to the delay time list obtained.
 * For details, see {@link OhosImageSourceDelayTimeList}. When the input <b>delayTimeList</b> is a null pointer and
 * <b>size</b> is <b>0</b>, the size of the delay time list is returned through <b>size</b> in <b>res</b>.
 * To obtain the complete delay time list, a space greater than <b>size</b> is required.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_HEAD_ABNORMAL - if image decode head error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CREATE_DECODER_FAILED - if create decoder failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_ABNORMAL - if image decode error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_EXIF_UNSUPPORT - if image decode exif unsupport.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PROPERTY_NOT_EXIST - if image property not exist.
 * @see {@link ImageSourceNative}, {@link OhosImageSourceDelayTimeList}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
int32_t OH_ImageSource_GetDelayTime(const ImageSourceNative* native,
    struct OhosImageSourceDelayTimeList* res);

/**
 * @brief Obtains the number of frames from an <b>ImageSource</b> object.
 *
 * @param native Indicates a pointer to the {@link ImageSourceNative} object at the C++ native layer.
 * @param res Indicates a pointer to the number of frames obtained.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_HEAD_ABNORMAL - if image decode head error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CREATE_DECODER_FAILED - if create decoder failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_ABNORMAL - if image decode error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_EXIF_UNSUPPORT - if image decode exif unsupport.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PROPERTY_NOT_EXIST - if image property not exist.
 * @see {@link ImageSourceNative}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
int32_t OH_ImageSource_GetFrameCount(const ImageSourceNative* native, uint32_t *res);

/**
 * @brief Obtains image source information from an <b>ImageSource</b> object by index.
 *
 * @param native Indicates a pointer to the {@link ImageSourceNative} object at the C++ native layer.
 * @param index Indicates the index of the frame.
 * @param info Indicates a pointer to the image source information obtained.
 * For details, see {@link OhosImageSourceInfo}.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_HEAD_ABNORMAL - if image decode head error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CREATE_DECODER_FAILED - if create decoder failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_ABNORMAL - if image decode error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_EXIF_UNSUPPORT - if image decode exif unsupport.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PROPERTY_NOT_EXIST - if image property not exist.
 * @see {@link ImageSourceNative}, {@link OhosImageSourceInfo}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
int32_t OH_ImageSource_GetImageInfo(const ImageSourceNative* native, int32_t index,
    struct OhosImageSourceInfo* info);

/**
 * @brief Obtains the value of an image property from an <b>ImageSource</b> object.
 *
 * @param native Indicates a pointer to the {@link ImageSourceNative} object at the C++ native layer.
 * @param key Indicates a pointer to the property. For details, see {@link OhosImageSourceProperty}.
 * @param value Indicates a pointer to the property value obtained.
 * If the input <b>value</b> is a null pointer and <b>size</b> is <b>0</b>, the size of the property value is returned
 * through <b>size</b> in <b>value</b>.
 * To obtain the complete property value, a space greater than <b>size</b> is required.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_HEAD_ABNORMAL - if image decode head error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CREATE_DECODER_FAILED - if create decoder failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_ABNORMAL - if image decode error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_EXIF_UNSUPPORT - if image decode exif unsupport.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PROPERTY_NOT_EXIST - if image property not exist.
 * @see {@link ImageSourceNative}, {@link OhosImageSourceProperty}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
int32_t OH_ImageSource_GetImageProperty(const ImageSourceNative* native,
    struct OhosImageSourceProperty* key, struct OhosImageSourceProperty* value);

/**
 * @brief Modifies the value of an image property of an <b>ImageSource</b> object.
 *
 * @param native Indicates a pointer to the {@link ImageSourceNative} object at the C++ native layer.
 * @param key Indicates a pointer to the property. For details, see {@link OhosImageSourceProperty}.
 * @param value Indicates a pointer to the new value of the property.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_HEAD_ABNORMAL - if image decode head error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CREATE_DECODER_FAILED - if create decoder failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_ABNORMAL - if image decode error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_EXIF_UNSUPPORT - if image decode exif unsupport.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PROPERTY_NOT_EXIST - if image property not exist.
 * @see {@link ImageSourceNative}, {@link OhosImageSourceProperty}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
int32_t OH_ImageSource_ModifyImageProperty(const ImageSourceNative* native,
    struct OhosImageSourceProperty* key, struct OhosImageSourceProperty* value);

/**
 * @brief Updates the data of an <b>ImageSource</b> object.
 *
 * @param native Indicates a pointer to the {@link ImageSourceNative} object at the C++ native layer.
 * @param data Indicates a pointer to the update data. For details, see {@link OhosImageSourceUpdateData}.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_HEAD_ABNORMAL - if image decode head error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CREATE_DECODER_FAILED - if create decoder failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CREATE_ENCODER_FAILED - if create encoder failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CHECK_FORMAT_ERROR - if check format failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_NOT_EXIST - if sharememory error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_DATA_ABNORMAL - if sharememory data abnormal.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_ABNORMAL - if image decode error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MALLOC_ABNORMAL - if image malloc error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INIT_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CROP - if crop error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ENCODE_FAILED - image add pixel map fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_HW_DECODE_UNSUPPORT - if image hardware decode unsupported.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_HW_DECODE_FAILED - if hard decode failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_IPC - if ipc error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALPHA_TYPE_ERROR - if hard decode failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALLOCATER_TYPE_ERROR - if hard decode failed.
 * @see {@link ImageSourceNative}, {@link OhosImageSourceUpdateData}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
int32_t OH_ImageSource_UpdateData(const ImageSourceNative* native, struct OhosImageSourceUpdateData* data);


/**
 * @brief Releases an <b>ImageSourceNative</b> object.
 *
 * @param native Indicates a pointer to the {@link ImageSourceNative} object at the C++ native layer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * @see {@link ImageSourceNative}, {@link OH_ImageSource_Create}, {@link OH_ImageSource_CreateIncremental}
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 4.0
 */
int32_t OH_ImageSource_Release(ImageSourceNative* native);
#ifdef __cplusplus
};
#endif
#endif // INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_SOURCE_MDK_H_