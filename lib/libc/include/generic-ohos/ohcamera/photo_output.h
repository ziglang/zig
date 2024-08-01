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
 * @addtogroup OH_Camera
 * @{
 *
 * @brief Provide the definition of the C interface for the camera module.
 *
 * @syscap SystemCapability.Multimedia.Camera.Core
 *
 * @since 11
 * @version 1.0
 */

/**
 * @file photo_output.h
 *
 * @brief Declare the photo output concepts.
 *
 * @library libohcamera.so
 * @syscap SystemCapability.Multimedia.Camera.Core
 * @since 11
 * @version 1.0
 */

#ifndef NATIVE_INCLUDE_CAMERA_PHOTOOUTPUT_H
#define NATIVE_INCLUDE_CAMERA_PHOTOOUTPUT_H

#include <stdint.h>
#include <stdio.h>
#include "camera.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Photo output object
 *
 * A pointer can be created using {@link Camera_PhotoOutput} method.
 *
 * @since 11
 * @version 1.0
 */
typedef struct Camera_PhotoOutput Camera_PhotoOutput;

/**
 * @brief Photo output frame start callback to be called in {@link PhotoOutput_Callbacks}.
 *
 * @param photoOutput the {@link Camera_PhotoOutput} which deliver the callback.
 * @since 11
 */
typedef void (*OH_PhotoOutput_OnFrameStart)(Camera_PhotoOutput* photoOutput);

/**
 * @brief Photo output frame shutter callback to be called in {@link PhotoOutput_Callbacks}.
 *
 * @param photoOutput the {@link Camera_PhotoOutput} which deliver the callback.
 * @param info the {@link Camera_FrameShutterInfo} which delivered by the callback.
 * @since 11
 */
typedef void (*OH_PhotoOutput_OnFrameShutter)(Camera_PhotoOutput* photoOutput, Camera_FrameShutterInfo* info);

/**
 * @brief Photo output frame end callback to be called in {@link PhotoOutput_Callbacks}.
 *
 * @param photoOutput the {@link Camera_PhotoOutput} which deliver the callback.
 * @param frameCount the frame count which delivered by the callback.
 * @since 11
 */
typedef void (*OH_PhotoOutput_OnFrameEnd)(Camera_PhotoOutput* photoOutput, int32_t frameCount);

/**
 * @brief Photo output error callback to be called in {@link PhotoOutput_Callbacks}.
 *
 * @param photoOutput the {@link Camera_PhotoOutput} which deliver the callback.
 * @param errorCode the {@link Camera_ErrorCode} of the photo output.
 *
 * @see CAMERA_SERVICE_FATAL_ERROR
 * @since 11
 */
typedef void (*OH_PhotoOutput_OnError)(Camera_PhotoOutput* photoOutput, Camera_ErrorCode errorCode);

/**
 * @brief A listener for photo output.
 *
 * @see OH_PhotoOutput_RegisterCallback
 * @since 11
 * @version 1.0
 */
typedef struct PhotoOutput_Callbacks {
    /**
     * Photo output frame start event.
     */
    OH_PhotoOutput_OnFrameStart onFrameStart;

    /**
     * Photo output frame shutter event.
     */
    OH_PhotoOutput_OnFrameShutter onFrameShutter;

    /**
     * Photo output frame end event.
     */
    OH_PhotoOutput_OnFrameEnd onFrameEnd;

    /**
     * Photo output error event.
     */
    OH_PhotoOutput_OnError onError;
} PhotoOutput_Callbacks;

/**
 * @brief Register photo output change event callback.
 *
 * @param photoOutput the {@link Camera_PhotoOutput} instance.
 * @param callback the {@link PhotoOutput_Callbacks} to be registered.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 * @since 11
 */
Camera_ErrorCode OH_PhotoOutput_RegisterCallback(Camera_PhotoOutput* photoOutput, PhotoOutput_Callbacks* callback);

/**
 * @brief Unregister photo output change event callback.
 *
 * @param photoOutput the {@link Camera_PhotoOutput} instance.
 * @param callback the {@link PhotoOutput_Callbacks} to be unregistered.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 * @since 11
 */
Camera_ErrorCode OH_PhotoOutput_UnregisterCallback(Camera_PhotoOutput* photoOutput, PhotoOutput_Callbacks* callback);

/**
 * @brief Capture photo.
 *
 * @param photoOutput the {@link Camera_PhotoOutput} instance which used to capture photo.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_RUNNING} if the capture session not running.
 *         {@link #CAMERA_SERVICE_FATAL_ERROR} if camera service fatal error.
 * @since 11
 */
Camera_ErrorCode OH_PhotoOutput_Capture(Camera_PhotoOutput* photoOutput);

/**
 * @brief Capture photo with capture setting.
 *
 * @param photoOutput the {@link Camera_PhotoOutput} instance which used to capture photo.
 * @param setting the {@link Camera_PhotoCaptureSetting} to used to capture photo.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_RUNNING} if the capture session not running.
 *         {@link #CAMERA_SERVICE_FATAL_ERROR} if camera service fatal error.
 * @since 11
 */
Camera_ErrorCode OH_PhotoOutput_Capture_WithCaptureSetting(Camera_PhotoOutput* photoOutput,
    Camera_PhotoCaptureSetting setting);

/**
 * @brief Release photo output.
 *
 * @param photoOutput the {@link Camera_PhotoOutput} instance to released.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SERVICE_FATAL_ERROR} if camera service fatal error.
 * @since 11
 */
Camera_ErrorCode OH_PhotoOutput_Release(Camera_PhotoOutput* photoOutput);

/**
 * @brief Check whether to support mirror photo.
 *
 * @param photoOutput the {@link Camera_PhotoOutput} instance which used to check whether mirror supported.
 * @param isSupported the result of whether mirror supported.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SERVICE_FATAL_ERROR} if camera service fatal error.
 * @since 11
 */
Camera_ErrorCode OH_PhotoOutput_IsMirrorSupported(Camera_PhotoOutput* photoOutput, bool* isSupported);

#ifdef __cplusplus
}
#endif

#endif // NATIVE_INCLUDE_CAMERA_PHOTOOUTPUT_H
/** @} */