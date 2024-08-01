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
 * @file preview_output.h
 *
 * @brief Declare the preview output concepts.
 *
 * @library libohcamera.so
 * @syscap SystemCapability.Multimedia.Camera.Core
 * @since 11
 * @version 1.0
 */

#ifndef NATIVE_INCLUDE_CAMERA_PREVIEWOUTPUT_H
#define NATIVE_INCLUDE_CAMERA_PREVIEWOUTPUT_H

#include <stdint.h>
#include <stdio.h>
#include "camera.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Preview output object
 *
 * A pointer can be created using {@link Camera_PreviewOutput} method.
 *
 * @since 11
 * @version 1.0
 */
typedef struct Camera_PreviewOutput Camera_PreviewOutput;

/**
 * @brief Preview output frame start callback to be called in {@link PreviewOutput_Callbacks}.
 *
 * @param previewOutput the {@link Camera_PreviewOutput} which deliver the callback.
 * @since 11
 */
typedef void (*OH_PreviewOutput_OnFrameStart)(Camera_PreviewOutput* previewOutput);

/**
 * @brief Preview output frame end callback to be called in {@link PreviewOutput_Callbacks}.
 *
 * @param previewOutput the {@link Camera_PreviewOutput} which deliver the callback.
 * @param frameCount the frame count which delivered by the callback.
 * @since 11
 */
typedef void (*OH_PreviewOutput_OnFrameEnd)(Camera_PreviewOutput* previewOutput, int32_t frameCount);

/**
 * @brief Preview output error callback to be called in {@link PreviewOutput_Callbacks}.
 *
 * @param previewOutput the {@link Camera_PreviewOutput} which deliver the callback.
 * @param errorCode the {@link Camera_ErrorCode} of the preview output.
 *
 * @see CAMERA_SERVICE_FATAL_ERROR
 * @since 11
 */
typedef void (*OH_PreviewOutput_OnError)(Camera_PreviewOutput* previewOutput, Camera_ErrorCode errorCode);

/**
 * @brief A listener for preview output.
 *
 * @see OH_PreviewOutput_RegisterCallback
 * @since 11
 * @version 1.0
 */
typedef struct PreviewOutput_Callbacks {
    /**
     * Preview output frame start event.
     */
    OH_PreviewOutput_OnFrameStart onFrameStart;

    /**
     * Preview output frame end event.
     */
    OH_PreviewOutput_OnFrameEnd onFrameEnd;

    /**
     * Preview output error event.
     */
    OH_PreviewOutput_OnError onError;
} PreviewOutput_Callbacks;

/**
 * @brief Register preview output change event callback.
 *
 * @param previewOutput the {@link Camera_PreviewOutput} instance.
 * @param callback the {@link PreviewOutput_Callbacks} to be registered.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 * @since 11
 */
Camera_ErrorCode OH_PreviewOutput_RegisterCallback(Camera_PreviewOutput* previewOutput,
    PreviewOutput_Callbacks* callback);

/**
 * @brief Unregister preview output change event callback.
 *
 * @param previewOutput the {@link Camera_PreviewOutput} instance.
 * @param callback the {@link PreviewOutput_Callbacks} to be unregistered.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 * @since 11
 */
Camera_ErrorCode OH_PreviewOutput_UnregisterCallback(Camera_PreviewOutput* previewOutput,
    PreviewOutput_Callbacks* callback);

/**
 * @brief Start preview output.
 *
 * @param previewOutput the {@link Camera_PreviewOutput} instance to be started.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 *         {@link #CAMERA_SERVICE_FATAL_ERROR} if camera service fatal error.
 * @since 11
 */
Camera_ErrorCode OH_PreviewOutput_Start(Camera_PreviewOutput* previewOutput);

/**
 * @brief Stop preview output.
 *
 * @param previewOutput the {@link Camera_PreviewOutput} instance to be stoped.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SERVICE_FATAL_ERROR} if camera service fatal error.
 * @since 11
 */
Camera_ErrorCode OH_PreviewOutput_Stop(Camera_PreviewOutput* previewOutput);

/**
 * @brief Release preview output.
 *
 * @param previewOutput the {@link Camera_PreviewOutput} instance to be released.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SERVICE_FATAL_ERROR} if camera service fatal error.
 * @since 11
 */
Camera_ErrorCode OH_PreviewOutput_Release(Camera_PreviewOutput* previewOutput);

#ifdef __cplusplus
}
#endif

#endif // NATIVE_INCLUDE_CAMERA_PREVIEWOUTPUT_H
/** @} */