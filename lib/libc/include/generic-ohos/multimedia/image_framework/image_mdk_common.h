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
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 2.0
 */

/**
 * @file image_mdk_common.h
 *
 * @brief Declares the common enums and structs used by the image interface.
 *
 * @since 10
 * @version 2.0
 */

#ifndef INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_COMMON_H_
#define INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_COMMON_H_
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
#define IMAGE_RESULT_BASE 62980096
/**
 * @brief Enumerates the return values that may be used by the interface.
 *
 * @since 10
 * @version 2.0
 */
typedef enum {
    IMAGE_RESULT_SUCCESS = 0,                                      // Operation success
    IMAGE_RESULT_BAD_PARAMETER = -1,                               // Invalid parameter
    IMAGE_RESULT_IMAGE_RESULT_BASE = IMAGE_RESULT_BASE,            // Operation failed
    IMAGE_RESULT_ERR_IPC = IMAGE_RESULT_BASE + 1,                  // ipc error
    IMAGE_RESULT_ERR_SHAMEM_NOT_EXIST = IMAGE_RESULT_BASE + 2,     // sharememory error
    IMAGE_RESULT_ERR_SHAMEM_DATA_ABNORMAL = IMAGE_RESULT_BASE + 3, // sharememory data abnormal
    IMAGE_RESULT_DECODE_ABNORMAL = IMAGE_RESULT_BASE + 4,          // image decode error
    IMAGE_RESULT_DATA_ABNORMAL = IMAGE_RESULT_BASE + 5,            // image input data error
    IMAGE_RESULT_MALLOC_ABNORMAL = IMAGE_RESULT_BASE + 6,          // image malloc error
    IMAGE_RESULT_DATA_UNSUPPORT = IMAGE_RESULT_BASE + 7,           // image type unsupported
    IMAGE_RESULT_INIT_ABNORMAL = IMAGE_RESULT_BASE + 8,            // image init error
    IMAGE_RESULT_GET_DATA_ABNORMAL = IMAGE_RESULT_BASE + 9,        // image get data error
    IMAGE_RESULT_TOO_LARGE = IMAGE_RESULT_BASE + 10,               // image data too large
    IMAGE_RESULT_TRANSFORM = IMAGE_RESULT_BASE + 11,               // image transform error
    IMAGE_RESULT_COLOR_CONVERT = IMAGE_RESULT_BASE + 12,           // image color convert error
    IMAGE_RESULT_CROP = IMAGE_RESULT_BASE + 13,                    // crop error
    IMAGE_RESULT_SOURCE_DATA = IMAGE_RESULT_BASE + 14,             // image source data error
    IMAGE_RESULT_SOURCE_DATA_INCOMPLETE = IMAGE_RESULT_BASE + 15,  // image source data incomplete
    IMAGE_RESULT_MISMATCHED_FORMAT = IMAGE_RESULT_BASE + 16,       // image mismatched format
    IMAGE_RESULT_UNKNOWN_FORMAT = IMAGE_RESULT_BASE + 17,          // image unknown format
    IMAGE_RESULT_SOURCE_UNRESOLVED = IMAGE_RESULT_BASE + 18,       // image source unresolved
    IMAGE_RESULT_INVALID_PARAMETER = IMAGE_RESULT_BASE + 19,       // image invalid parameter
    IMAGE_RESULT_DECODE_FAILED = IMAGE_RESULT_BASE + 20,           // decode fail
    IMAGE_RESULT_PLUGIN_REGISTER_FAILED = IMAGE_RESULT_BASE + 21,  // register plugin fail
    IMAGE_RESULT_PLUGIN_CREATE_FAILED = IMAGE_RESULT_BASE + 22,    // create plugin fail
    IMAGE_RESULT_ENCODE_FAILED = IMAGE_RESULT_BASE + 23,           // image encode fail
    IMAGE_RESULT_ADD_PIXEL_MAP_FAILED = IMAGE_RESULT_BASE + 24,    // image add pixel map fail
    IMAGE_RESULT_HW_DECODE_UNSUPPORT = IMAGE_RESULT_BASE + 25,     // image hardware decode unsupported
    IMAGE_RESULT_DECODE_HEAD_ABNORMAL = IMAGE_RESULT_BASE + 26,    // image decode head error
    IMAGE_RESULT_DECODE_EXIF_UNSUPPORT = IMAGE_RESULT_BASE + 27,   // image decode exif unsupport
    IMAGE_RESULT_PROPERTY_NOT_EXIST = IMAGE_RESULT_BASE + 28,      // image property not exist

    IMAGE_RESULT_MEDIA_DATA_UNSUPPORT = IMAGE_RESULT_BASE + 30,               // media type unsupported
    IMAGE_RESULT_MEDIA_TOO_LARGE = IMAGE_RESULT_BASE + 31,                    // media data too large
    IMAGE_RESULT_MEDIA_MALLOC_FAILED = IMAGE_RESULT_BASE + 32,                // media malloc memory failed
    IMAGE_RESULT_MEDIA_END_OF_STREAM = IMAGE_RESULT_BASE + 33,                // media end of stream error
    IMAGE_RESULT_MEDIA_IO_ABNORMAL = IMAGE_RESULT_BASE + 34,                  // media io error
    IMAGE_RESULT_MEDIA_MALFORMED = IMAGE_RESULT_BASE + 35,                    // media malformed error
    IMAGE_RESULT_MEDIA_BUFFER_TOO_SMALL = IMAGE_RESULT_BASE + 36,             // media buffer too small error
    IMAGE_RESULT_MEDIA_OUT_OF_RANGE = IMAGE_RESULT_BASE + 37,                 // media out of range error
    IMAGE_RESULT_MEDIA_STATUS_ABNORMAL = IMAGE_RESULT_BASE + 38,              // media status abnormal error
    IMAGE_RESULT_MEDIA_VALUE_INVALID = IMAGE_RESULT_BASE + 39,                // media value invalid
    IMAGE_RESULT_MEDIA_NULL_POINTER = IMAGE_RESULT_BASE + 40,                 // media error operation
    IMAGE_RESULT_MEDIA_INVALID_OPERATION = IMAGE_RESULT_BASE + 41,            // media invalid operation
    IMAGE_RESULT_MEDIA_ERR_PLAYER_NOT_INIT = IMAGE_RESULT_BASE + 42,          // media init error
    IMAGE_RESULT_MEDIA_EARLY_PREPARE = IMAGE_RESULT_BASE + 43,                // media early prepare
    IMAGE_RESULT_MEDIA_SEEK_ERR = IMAGE_RESULT_BASE + 44,                     // media rewind error
    IMAGE_RESULT_MEDIA_PERMISSION_DENIED = IMAGE_RESULT_BASE + 45,            // media permission denied
    IMAGE_RESULT_MEDIA_DEAD_OBJECT = IMAGE_RESULT_BASE + 46,                  // media dead object
    IMAGE_RESULT_MEDIA_TIMED_OUT = IMAGE_RESULT_BASE + 47,                    // media time out
    IMAGE_RESULT_MEDIA_TRACK_NOT_ALL_SUPPORTED = IMAGE_RESULT_BASE + 48,      // media track subset support
    IMAGE_RESULT_MEDIA_ADAPTER_INIT_FAILED = IMAGE_RESULT_BASE + 49,          // media recorder adapter init failed
    IMAGE_RESULT_MEDIA_WRITE_PARCEL_FAIL = IMAGE_RESULT_BASE + 50,            // write parcel failed
    IMAGE_RESULT_MEDIA_READ_PARCEL_FAIL = IMAGE_RESULT_BASE + 51,             // read parcel failed
    IMAGE_RESULT_MEDIA_NO_AVAIL_BUFFER = IMAGE_RESULT_BASE + 52,              // read parcel failed
    IMAGE_RESULT_MEDIA_INVALID_PARAM = IMAGE_RESULT_BASE + 53,                // media function found invalid param
    IMAGE_RESULT_MEDIA_CODEC_ADAPTER_NOT_EXIST = IMAGE_RESULT_BASE + 54,      // media zcodec adapter not init
    IMAGE_RESULT_MEDIA_CREATE_CODEC_ADAPTER_FAILED = IMAGE_RESULT_BASE + 55,  // media create zcodec adapter failed
    IMAGE_RESULT_MEDIA_CODEC_ADAPTER_NOT_INIT = IMAGE_RESULT_BASE + 56,       // media adapter inner not init
    IMAGE_RESULT_MEDIA_ZCODEC_CREATE_FAILED = IMAGE_RESULT_BASE + 57,         // media adapter inner not init
    IMAGE_RESULT_MEDIA_ZCODEC_NOT_EXIST = IMAGE_RESULT_BASE + 58,             // media zcodec not exist
    IMAGE_RESULT_MEDIA_JNI_CLASS_NOT_EXIST = IMAGE_RESULT_BASE + 59,          // media jni class not found
    IMAGE_RESULT_MEDIA_JNI_METHOD_NOT_EXIST = IMAGE_RESULT_BASE + 60,         // media jni method not found
    IMAGE_RESULT_MEDIA_JNI_NEW_OBJ_FAILED = IMAGE_RESULT_BASE + 61,           // media jni obj new failed
    IMAGE_RESULT_MEDIA_JNI_COMMON_ERROR = IMAGE_RESULT_BASE + 62,             // media jni normal error
    IMAGE_RESULT_MEDIA_DISTRIBUTE_NOT_SUPPORT = IMAGE_RESULT_BASE + 63,       // media distribute not support
    IMAGE_RESULT_MEDIA_SOURCE_NOT_SET = IMAGE_RESULT_BASE + 64,               // media source not set
    IMAGE_RESULT_MEDIA_RTSP_ADAPTER_NOT_INIT = IMAGE_RESULT_BASE + 65,        // media rtsp adapter not init
    IMAGE_RESULT_MEDIA_RTSP_ADAPTER_NOT_EXIST = IMAGE_RESULT_BASE + 66,       // media rtsp adapter not exist
    IMAGE_RESULT_MEDIA_RTSP_SURFACE_UNSUPPORT = IMAGE_RESULT_BASE + 67,       // media rtsp surface not support
    IMAGE_RESULT_MEDIA_RTSP_CAPTURE_NOT_INIT = IMAGE_RESULT_BASE + 68,        // media rtsp capture init error
    IMAGE_RESULT_MEDIA_RTSP_SOURCE_URL_INVALID = IMAGE_RESULT_BASE + 69,      // media rtsp source url invalid
    IMAGE_RESULT_MEDIA_RTSP_VIDEO_TRACK_NOT_FOUND = IMAGE_RESULT_BASE + 70,   // media rtsp can't find video track
    IMAGE_RESULT_MEDIA_RTSP_CAMERA_NUM_REACH_MAX = IMAGE_RESULT_BASE + 71,    // rtsp camera num reach to max num
    IMAGE_RESULT_MEDIA_SET_VOLUME = IMAGE_RESULT_BASE + 72,                   // media set volume error
    IMAGE_RESULT_MEDIA_NUMBER_OVERFLOW = IMAGE_RESULT_BASE + 73,              // media number operation overflow
    IMAGE_RESULT_MEDIA_DIS_PLAYER_UNSUPPORTED = IMAGE_RESULT_BASE + 74,       // media distribute player unsupporteded
    IMAGE_RESULT_MEDIA_DENCODE_ICC_FAILED = IMAGE_RESULT_BASE + 75,           // image dencode ICC fail
    IMAGE_RESULT_MEDIA_ENCODE_ICC_FAILED = IMAGE_RESULT_BASE + 76,            // image encode ICC fail

    IMAGE_RESULT_MEDIA_READ_PIXELMAP_FAILED = IMAGE_RESULT_BASE + 150,        // read pixelmap failed
    IMAGE_RESULT_MEDIA_WRITE_PIXELMAP_FAILED = IMAGE_RESULT_BASE + 151,       // write pixelmap failed
    IMAGE_RESULT_MEDIA_PIXELMAP_NOT_ALLOW_MODIFY = IMAGE_RESULT_BASE + 152,   // pixelmap not allow modify
    IMAGE_RESULT_MEDIA_CONFIG_FAILED = IMAGE_RESULT_BASE + 153,               // config error
    IMAGE_RESULT_JNI_ENV_ABNORMAL = IMAGE_RESULT_BASE + 154,                  // Abnormal JNI environment
    IMAGE_RESULT_SURFACE_GRALLOC_BUFFER_FAILED = IMAGE_RESULT_BASE + 155,     // surface gralloc buffer failed
    IMAGE_RESULT_CREATE_SURFACE_FAILED = IMAGE_RESULT_BASE + 156,             // create surface failed
    IMAGE_RESULT_SURFACE_GET_PARAMETER_FAILED = IMAGE_RESULT_BASE + 157,      // Failed to obtain parameters for surface
    IMAGE_RESULT_GET_SURFACE_FAILED = IMAGE_RESULT_BASE + 158,                // get sufrace failed
    IMAGE_RESULT_SURFACE_ACQUIRE_BUFFER_FAILED = IMAGE_RESULT_BASE + 159,     // Acquire Buffer failed
    IMAGE_RESULT_SURFACE_REQUEST_BUFFER_FAILED = IMAGE_RESULT_BASE + 160,     // request Buffer failed
    IMAGE_RESULT_REGISTER_LISTENER_FAILED = IMAGE_RESULT_BASE + 161,          // Failed to register listener
    IMAGE_RESULT_REGISTER_BUFFER_FAILED = IMAGE_RESULT_BASE + 162,            // Failed to register buffer
    IMAGE_RESULT_FREAD_FAILED = IMAGE_RESULT_BASE + 163,                      // read file failed
    IMAGE_RESULT_PEEK_FAILED = IMAGE_RESULT_BASE + 164,                       // peek file failed
    IMAGE_RESULT_SEEK_FAILED = IMAGE_RESULT_BASE + 165,                       // seek file failed
    IMAGE_RESULT_STREAM_SIZE_ERROR = IMAGE_RESULT_BASE + 166,                 // stream bad
    IMAGE_RESULT_FILE_FD_ERROR = IMAGE_RESULT_BASE + 167,                     // file fd is bad
    IMAGE_RESULT_FILE_DAMAGED = IMAGE_RESULT_BASE + 168,                      // file damaged
    IMAGE_RESULT_CREATE_DECODER_FAILED = IMAGE_RESULT_BASE + 169,             // create decoder failed
    IMAGE_RESULT_CREATE_ENCODER_FAILED = IMAGE_RESULT_BASE + 170,             // create encoder failed
    IMAGE_RESULT_CHECK_FORMAT_ERROR = IMAGE_RESULT_BASE + 171,                // check format failed
    IMAGE_RESULT_THIRDPART_SKIA_ERROR = IMAGE_RESULT_BASE + 172,              // skia error
    IMAGE_RESULT_HW_DECODE_FAILED = IMAGE_RESULT_BASE + 173,                  // hard decode failed
    IMAGE_RESULT_ALLOCATER_TYPE_ERROR = IMAGE_RESULT_BASE + 174,              // hard decode failed
    IMAGE_RESULT_ALPHA_TYPE_ERROR = IMAGE_RESULT_BASE + 175,                  // hard decode failed
    IMAGE_RESULT_INDEX_INVALID = IMAGE_RESULT_BASE + 176,                     // invalid index

    IMAGE_RESULT_MEDIA_UNKNOWN = IMAGE_RESULT_BASE + 200,                     // media unknown error
} IRNdkErrCode;

/**
 * @brief Defines the image size.
 *
 * @since 10
 * @version 2.0
 */
struct OhosImageSize {
    /** Image width, in pixels. */
    int32_t width;
    /** Image height, in pixels. */
    int32_t height;
};

#ifdef __cplusplus
};
#endif
/** @} */

#endif // INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_COMMON_H_