/*
 * Copyright (C) 2022 Huawei Device Co., Ltd.
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
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 1.0
 */

/**
 * @file image_pixel_map_mdk.h
 *
 * @brief Declares the APIs that can lock, access, and unlock a pixel map.
 * Need link <b>libpixelmapndk.z.so</b>
 *
 * @since 10
 * @version 1.0
 */

#ifndef INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_PIXEL_MAP_MDK_H_
#define INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_PIXEL_MAP_MDK_H_
#include <stdint.h>
#include "napi/native_api.h"
#include "image_mdk_common.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines the native pixel map information.
 * @since 10
 * @version 1.0
 */
struct NativePixelMap_;

/**
 * @brief Defines the data type name of the native pixel map.
 * @since 10
 * @version 1.0
 */
typedef struct NativePixelMap_ NativePixelMap;

/**
 * @brief Defines the pixel map information.
 *
 * @since 10
 * @version 1.0
 */
typedef struct OhosPixelMapInfos {
    /** Image width, in pixels. */
    uint32_t width;
    /** Image height, in pixels. */
    uint32_t height;
    /** Number of bytes per row. */
    uint32_t rowSize;
    /** Pixel format. */
    int32_t pixelFormat;
} OhosPixelMapInfos;

/**
 * @brief Enumerates the pixel map alpha types.
 *
 * @since 10
 * @version 1.0
 */
enum {
    /**
     * Unknown format.
     */
    OHOS_PIXEL_MAP_ALPHA_TYPE_UNKNOWN = 0,
    /**
     * Opaque format.
     */
    OHOS_PIXEL_MAP_ALPHA_TYPE_OPAQUE = 1,
    /**
     * Premultiplied format.
     */
    OHOS_PIXEL_MAP_ALPHA_TYPE_PREMUL = 2,
    /**
     * Unpremultiplied format.
     */
    OHOS_PIXEL_MAP_ALPHA_TYPE_UNPREMUL = 3
};

/**
 * @brief Enumerates the pixel map editing types.
 *
 * @since 10
 * @version 1.0
 */
enum {
    /**
     * Read-only.
     */
    OHOS_PIXEL_MAP_READ_ONLY = 0,
    /**
     * Editable.
     */
    OHOS_PIXEL_MAP_EDITABLE = 1,
};

/**
 * @brief Defines the options used for creating a pixel map.
 *
 * @since 10
 * @version 1.0
 */
struct OhosPixelMapCreateOps {
    /** Image width, in pixels. */
    uint32_t width;
    /** Image height, in pixels. */
    uint32_t height;
    /** Image format. */
    int32_t pixelFormat;
    /** Editing type of the image. */
    uint32_t editable;
    /** Alpha type of the image. */
    uint32_t alphaType;
    /** Scale mode of the image. */
    uint32_t scaleMode;
};

/**
 * @brief Creates a <b>PixelMap</b> object.
 *
 * @param env Indicates the NAPI environment pointer.
 * @param info Indicates the options for setting the <b>PixelMap</b> object.
 * @param buf Indicates the pointer to the buffer of the image.
 * @param len Indicates the image size.
 * @param res Indicates the pointer to the <b>PixelMap</b> object at the application layer.
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
 * @see CreatePixelMap
 * @since 10
 * @version 1.0
 */
int32_t OH_PixelMap_CreatePixelMap(napi_env env, OhosPixelMapCreateOps info,
    void* buf, size_t len, napi_value* res);

/**
 * @brief Creates a <b>PixelMap</b> object that contains only alpha channel information.
 *
 * @param env Indicates the NAPI environment pointer.
 * @param source Indicates the options for setting the <b>PixelMap</b> object.
 * @param alpha Indicates the pointer to the alpha channel.
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
 * @see CreateAlphaPixelMap
 * @since 10
 * @version 1.0
 */
int32_t OH_PixelMap_CreateAlphaPixelMap(napi_env env, napi_value source, napi_value* alpha);

/**
 * @brief Initializes a <b>PixelMap</b> object.
 *
 * @param env Indicates the NAPI environment pointer.
 * @param source Indicates the options for setting the <b>PixelMap</b> object.
 * @return Returns a pointer to the <b>NativePixelMap</b> object
 * if the operation is successful; returns nullptr otherwise.
 * @see InitNativePixelMap
 * @since 10
 * @version 1.0
 */
NativePixelMap* OH_PixelMap_InitNativePixelMap(napi_env env, napi_value source);

/**
 * @brief Obtains the number of bytes per row of a <b>PixelMap</b> object.
 *
 * @param native Indicates the pointer to a <b>NativePixelMap</b> object.
 * @param num Indicates the pointer to the number of bytes per row of the <b>PixelMap</b> object.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * @see GetBytesNumberPerRow
 * @since 10
 * @version 1.0
 */
int32_t OH_PixelMap_GetBytesNumberPerRow(const NativePixelMap* native, int32_t* num);

/**
 * @brief Checks whether a <b>PixelMap</b> object is editable.
 *
 * @param native Indicates the pointer to a <b>NativePixelMap</b> object.
 * @param editable Indicates the pointer to the editing type of the <b>PixelMap</b> object.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * @see GetIsEditable
 * @since 10
 * @version 1.0
 */
int32_t OH_PixelMap_GetIsEditable(const NativePixelMap* native, int32_t* editable);

/**
 * @brief Checks whether a <b>PixelMap</b> object supports alpha channels.
 *
 * @param native Indicates the pointer to a <b>NativePixelMap</b> object.
 * @param alpha Indicates the pointer to the support for alpha channels.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * @see IsSupportAlpha
 * @since 10
 * @version 1.0
 */
int32_t OH_PixelMap_IsSupportAlpha(const NativePixelMap* native, int32_t* alpha);

/**
 * @brief Sets an alpha channel for a <b>PixelMap</b> object.
 *
 * @param native Indicates the pointer to a <b>NativePixelMap</b> object.
 * @param alpha Indicates the alpha channel to set.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * @see SetAlphaAble
 * @since 10
 * @version 1.0
 */
int32_t OH_PixelMap_SetAlphaAble(const NativePixelMap* native, int32_t alpha);

/**
 * @brief Obtains the pixel density of a <b>PixelMap</b> object.
 *
 * @param native Indicates the pointer to a <b>NativePixelMap</b> object.
 * @param density Indicates the pointer to the pixel density.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * @see GetDensity
 * @since 10
 * @version 1.0
 */
int32_t OH_PixelMap_GetDensity(const NativePixelMap* native, int32_t* density);

/**
 * @brief Sets the pixel density for a <b>PixelMap</b> object.
 *
 * @param native Indicates the pointer to a <b>NativePixelMap</b> object.
 * @param density Indicates the pixel density to set.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * @see GetDensity
 * @since 10
 * @version 1.0
 */
int32_t OH_PixelMap_SetDensity(const NativePixelMap* native, int32_t density);

/**
 * @brief Sets the opacity for a <b>PixelMap</b> object.
 *
 * @param native Indicates the pointer to a <b>NativePixelMap</b> object.
 * @param opacity Indicates the opacity to set.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * @see SetOpacity
 * @since 10
 * @version 1.0
 */
int32_t OH_PixelMap_SetOpacity(const NativePixelMap* native, float opacity);

/**
 * @brief Scales a <b>PixelMap</b> object.
 *
 * @param native Indicates the pointer to a <b>NativePixelMap</b> object.
 * @param x Indicates the scaling ratio of the width.
 * @param y Indicates the scaling ratio of the height.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CHECK_FORMAT_ERROR - if check format failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_NOT_EXIST - if sharememory error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_DATA_ABNORMAL - if sharememory data abnormal.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MALLOC_ABNORMAL - if image malloc error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CROP - if crop error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALPHA_TYPE_ERROR - if hard decode failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALLOCATER_TYPE_ERROR - if hard decode failed.
 * @see Scale
 * @since 10
 * @version 1.0
 */
int32_t OH_PixelMap_Scale(const NativePixelMap* native, float x, float y);

/**
 * @brief Translates a <b>PixelMap</b> object.
 *
 * @param native Indicates the pointer to a <b>NativePixelMap</b> object.
 * @param x Indicates the horizontal distance to translate.
 * @param y Indicates the vertical distance to translate.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CHECK_FORMAT_ERROR - if check format failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_NOT_EXIST - if sharememory error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_DATA_ABNORMAL - if sharememory data abnormal.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MALLOC_ABNORMAL - if image malloc error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CROP - if crop error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALPHA_TYPE_ERROR - if hard decode failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALLOCATER_TYPE_ERROR - if hard decode failed.
 * @see Translate
 * @since 10
 * @version 1.0
 */
int32_t OH_PixelMap_Translate(const NativePixelMap* native, float x, float y);

/**
 * @brief Rotates a <b>PixelMap</b> object.
 *
 * @param native Indicates the pointer to a <b>NativePixelMap</b> object.
 * @param angle Indicates the angle to rotate.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CHECK_FORMAT_ERROR - if check format failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_NOT_EXIST - if sharememory error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_DATA_ABNORMAL - if sharememory data abnormal.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MALLOC_ABNORMAL - if image malloc error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CROP - if crop error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALPHA_TYPE_ERROR - if hard decode failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALLOCATER_TYPE_ERROR - if hard decode failed.
 * @see Rotate
 * @since 10
 * @version 1.0
 */
int32_t OH_PixelMap_Rotate(const NativePixelMap* native, float angle);

/**
 * @brief Flips a <b>PixelMap</b> object.
 *
 * @param native Indicates the pointer to a <b>NativePixelMap</b> object.
 * @param x Specifies whether to flip around the x axis.
 * @param y Specifies whether to flip around the y axis.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CHECK_FORMAT_ERROR - if check format failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_NOT_EXIST - if sharememory error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_DATA_ABNORMAL - if sharememory data abnormal.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MALLOC_ABNORMAL - if image malloc error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CROP - if crop error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALPHA_TYPE_ERROR - if hard decode failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALLOCATER_TYPE_ERROR - if hard decode failed.
 * @see Flip
 * @since 10
 * @version 1.0
 */
int32_t OH_PixelMap_Flip(const NativePixelMap* native, int32_t x, int32_t y);

/**
 * @brief Crops a <b>PixelMap</b> object.
 *
 * @param native Indicates the pointer to a <b>NativePixelMap</b> object.
 * @param x Indicates the x-coordinate of the upper left corner of the target image.
 * @param y Indicates the y-coordinate of the upper left corner of the target image.
 * @param width Indicates the width of the cropped region.
 * @param height Indicates the height of the cropped region.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CHECK_FORMAT_ERROR - if check format failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_NOT_EXIST - if sharememory error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_DATA_ABNORMAL - if sharememory data abnormal.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MALLOC_ABNORMAL - if image malloc error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CROP - if crop error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALPHA_TYPE_ERROR - if hard decode failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALLOCATER_TYPE_ERROR - if hard decode failed.
 * @see Crop
 * @since 10
 * @version 1.0
 */
int32_t OH_PixelMap_Crop(const NativePixelMap* native, int32_t x, int32_t y, int32_t width, int32_t height);

/**
 * @brief Obtains the image information of a <b>PixelMap</b> object.
 *
 * @param native Indicates the pointer to a <b>NativePixelMap</b> object.
 * @param info Indicates the pointer to the image information.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CHECK_FORMAT_ERROR - if check format failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_NOT_EXIST - if sharememory error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_DATA_ABNORMAL - if sharememory data abnormal.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MALLOC_ABNORMAL - if image malloc error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CROP - if crop error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALPHA_TYPE_ERROR - if hard decode failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALLOCATER_TYPE_ERROR - if hard decode failed.
 * @see OhosPixelMapInfos
 * @since 10
 * @version 2.0
 */
int32_t OH_PixelMap_GetImageInfo(const NativePixelMap* native, OhosPixelMapInfos *info);

/**
 * @brief Obtains the memory address of a <b>NativePixelMap</b> object and locks the memory.
 *
 * @param native Indicates the pointer to a <b>NativePixelMap</b> object.
 * @param addr Indicates the double pointer to the memory address.
 * @see UnAccessPixels
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CHECK_FORMAT_ERROR - if check format failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_NOT_EXIST - if sharememory error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_DATA_ABNORMAL - if sharememory data abnormal.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MALLOC_ABNORMAL - if image malloc error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CROP - if crop error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALPHA_TYPE_ERROR - if hard decode failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALLOCATER_TYPE_ERROR - if hard decode failed.
 * @since 10
 * @version 2.0
 */
int32_t OH_PixelMap_AccessPixels(const NativePixelMap* native, void** addr);

/**
 * @brief Unlocks the memory of the <b>NativePixelMap</b> object data.
 * This function is used with {@link OH_PixelMap_AccessPixels} in pairs.
 *
 * @param native Indicates the pointer to a <b>NativePixelMap</b> object.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_DATA_ABNORMAL - if image get data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DECODE_FAILED - if decode fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CHECK_FORMAT_ERROR - if check format failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_THIRDPART_SKIA_ERROR - if skia error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_ABNORMAL - if image input data error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_NOT_EXIST - if sharememory error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ERR_SHAMEM_DATA_ABNORMAL - if sharememory data abnormal.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MALLOC_ABNORMAL - if image malloc error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image init error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CROP - if crop error.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_UNKNOWN_FORMAT - if image unknown format.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_REGISTER_FAILED - if register plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_PLUGIN_CREATE_FAILED - if create plugin fail.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INDEX_INVALID - if invalid index.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALPHA_TYPE_ERROR - if hard decode failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_ALLOCATER_TYPE_ERROR - if hard decode failed.
 * @see AccessPixels
 * @since 10
 * @version 2.0
 */
int32_t OH_PixelMap_UnAccessPixels(const NativePixelMap* native);

#ifdef __cplusplus
};
#endif
/** @} */

#endif // INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_PIXEL_MAP_NAPI_H_