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
 * @since 8
 * @version 1.0
 */

/**
 * @file image_pixel_map_napi.h
 *
 * @brief Declares the APIs that can lock, access, and unlock a pixel map.
 *
 * @since 8
 * @version 1.0
 */

#ifndef INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_PIXEL_MAP_NAPI_H_
#define INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_PIXEL_MAP_NAPI_H_
#include <cstdint>
#include "napi/native_api.h"
namespace OHOS {
namespace Media {
#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Enumerates the error codes returned by the functions.
 *
 * @deprecated since 10
 * @since 8
 * @version 1.0
 */
enum {
    /** Operation success. */
    OHOS_IMAGE_RESULT_SUCCESS = 0,
    /** Invalid value. */
    OHOS_IMAGE_RESULT_BAD_PARAMETER = -1,
};

/**
 * @brief Enumerates the pixel formats.
 *
 * @deprecated since 10
 * @since 8
 * @version 1.0
 */
enum {
    /**
     * Unknown format.
     */
    OHOS_PIXEL_MAP_FORMAT_NONE = 0,
    /**
     * 32-bit RGBA, with 8 bits each for R (red), G (green), B (blue), and A (alpha).
     * The data is stored from the most significant bit to the least significant bit.
     */
    OHOS_PIXEL_MAP_FORMAT_RGBA_8888 = 3,
    /**
     * 16-bit RGB, with 5, 6, and 5 bits for R, G, and B, respectively.
     * The data is stored from the most significant bit to the least significant bit.
     */
    OHOS_PIXEL_MAP_FORMAT_RGB_565 = 2,
};

/**
 * @brief Defines the pixel map information.
 *
 * @deprecated since 10
 * @since 8
 * @version 1.0
 */
struct OhosPixelMapInfo {
    /** Image width, in pixels. */
    uint32_t width;
    /** Image height, in pixels. */
    uint32_t height;
    /** Number of bytes per row. */
    uint32_t rowSize;
    /** Pixel format. */
    int32_t pixelFormat;
};

/**
 * @brief Enumerates the pixel map scale modes.
 *
 * @since 10
 * @version 2.0
 */
enum {
    /**
     * Adaptation to the target image size.
     */
    OHOS_PIXEL_MAP_SCALE_MODE_FIT_TARGET_SIZE = 0,
    /**
     * Cropping the center portion of an image to the target size.
     */
    OHOS_PIXEL_MAP_SCALE_MODE_CENTER_CROP = 1,
};

/**
 * @brief Obtains the information about a <b>PixelMap</b> object
 * and stores the information to the {@link OhosPixelMapInfo} struct.
 *
 * @deprecated since 10
 * @param env Indicates the NAPI environment pointer.
 * @param value Indicates the <b>PixelMap</b> object at the application layer.
 * @param info Indicates the pointer to the object that stores the information obtained.
 * For details, see {@link OhosPixelMapInfo}.
 * @return Returns <b>0</b> if the information is obtained and stored successfully; returns an error code otherwise.
 * @see OhosPixelMapInfo
 * @since 8
 * @version 1.0
 */
int32_t OH_GetImageInfo(napi_env env, napi_value value, OhosPixelMapInfo *info);

/**
 * @brief Obtains the memory address of a <b>PixelMap</b> object and locks the memory.
 *
 * After the function is executed successfully, <b>*addrPtr</b> is the memory address to be accessed.
 * After the access operation is complete, you must use {@link OH_UnAccessPixels} to unlock the memory.
 * Otherwise, the resources in the memory cannot be released.
 * After the memory is unlocked, its address cannot be accessed or operated.
 *
 * @deprecated since 10
 * @param env Indicates the NAPI environment pointer.
 * @param value Indicates the <b>PixelMap</b> object at the application layer.
 * @param addrPtr Indicates the double pointer to the memory address.
 * @see UnAccessPixels
 * @return Returns {@link OHOS_IMAGE_RESULT_SUCCESS} if the operation is successful; returns an error code otherwise.
 * @since 8
 * @version 1.0
 */
int32_t OH_AccessPixels(napi_env env, napi_value value, void** addrPtr);

/**
 * @brief Unlocks the memory of a <b>PixelMap</b> object. This function is used with {@link OH_AccessPixels} in pairs.
 *
 * @deprecated since 10
 * @param env Indicates the NAPI environment pointer.
 * @param value Indicates the <b>PixelMap</b> object at the application layer.
 * @return Returns {@link OHOS_IMAGE_RESULT_SUCCESS} if the operation is successful; returns an error code otherwise.
 * @see AccessPixels
 * @since 8
 * @version 1.0
 */
int32_t OH_UnAccessPixels(napi_env env, napi_value value);

#ifdef __cplusplus
};
#endif
/** @} */
} // namespace Media
} // namespace OHOS
#endif // INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_PIXEL_MAP_NAPI_H_