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
 * @file metadata_output.h
 *
 * @brief Declare the metadata output concepts.
 *
 * @library libohcamera.so
 * @syscap SystemCapability.Multimedia.Camera.Core
 * @since 11
 * @version 1.0
 */

#ifndef NATIVE_INCLUDE_CAMERA_METADATAOUTPUT_H
#define NATIVE_INCLUDE_CAMERA_METADATAOUTPUT_H

#include <stdint.h>
#include <stdio.h>
#include "camera.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Metadata output object
 *
 * A pointer can be created using {@link Camera_MetadataOutput} method.
 *
 * @since 11
 * @version 1.0
 */
typedef struct Camera_MetadataOutput Camera_MetadataOutput;

/**
 * @brief Metadata output metadata object available callback to be called in {@link MetadataOutput_Callbacks}.
 *
 * @param metadataOutput the {@link Camera_MetadataOutput} which deliver the callback.
 * @param metadataObject the {@link Camera_MetadataObject} will be delivered by the callback.
 * @param size the size of the metadataObject.
 * @since 11
 */
typedef void (*OH_MetadataOutput_OnMetadataObjectAvailable)(Camera_MetadataOutput* metadataOutput,
    Camera_MetadataObject* metadataObject, uint32_t size);

/**
 * @brief Metadata output error callback to be called in {@link MetadataOutput_Callbacks}.
 *
 * @param metadataOutput the {@link Camera_MetadataOutput} which deliver the callback.
 * @param errorCode the {@link Camera_ErrorCode} of the metadata output.
 *
 * @see CAMERA_SERVICE_FATAL_ERROR
 * @since 11
 */
typedef void (*OH_MetadataOutput_OnError)(Camera_MetadataOutput* metadataOutput, Camera_ErrorCode errorCode);

/**
 * @brief A listener for metadata output.
 *
 * @see OH_MetadataOutput_RegisterCallback
 * @since 11
 * @version 1.0
 */
typedef struct MetadataOutput_Callbacks {
    /**
     * Metadata output result data will be called by this callback.
     */
    OH_MetadataOutput_OnMetadataObjectAvailable onMetadataObjectAvailable;

    /**
     * Metadata output error event.
     */
    OH_MetadataOutput_OnError onError;
} MetadataOutput_Callbacks;

/**
 * @brief Register metadata output change event callback.
 *
 * @param metadataOutput the {@link Camera_MetadataOutput} instance.
 * @param callback the {@link MetadataOutput_Callbacks} to be registered.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 * @since 11
 */
Camera_ErrorCode OH_MetadataOutput_RegisterCallback(Camera_MetadataOutput* metadataOutput,
    MetadataOutput_Callbacks* callback);

/**
 * @brief Unregister metadata output change event callback.
 *
 * @param metadataOutput the {@link Camera_MetadataOutput} instance.
 * @param callback the {@link MetadataOutput_Callbacks} to be unregistered.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 * @since 11
 */
Camera_ErrorCode OH_MetadataOutput_UnregisterCallback(Camera_MetadataOutput* metadataOutput,
    MetadataOutput_Callbacks* callback);

/**
 * @brief Start metadata output.
 *
 * @param metadataOutput the {@link Camera_MetadataOutput} instance to be started.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 *         {@link #CAMERA_SERVICE_FATAL_ERROR} if camera service fatal error.
 * @since 11
 */
Camera_ErrorCode OH_MetadataOutput_Start(Camera_MetadataOutput* metadataOutput);

/**
 * @brief Stop metadata output.
 *
 * @param metadataOutput the {@link Camera_MetadataOutput} instance to be stoped.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SERVICE_FATAL_ERROR} if camera service fatal error.
 * @since 11
 */
Camera_ErrorCode OH_MetadataOutput_Stop(Camera_MetadataOutput* metadataOutput);

/**
 * @brief Release metadata output.
 *
 * @param metadataOutput the {@link Camera_MetadataOutput} instance to be released.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SERVICE_FATAL_ERROR} if camera service fatal error.
 * @since 11
 */
Camera_ErrorCode OH_MetadataOutput_Release(Camera_MetadataOutput* metadataOutput);

#ifdef __cplusplus
}
#endif

#endif // NATIVE_INCLUDE_CAMERA_METADATAOUTPUT_H
/** @} */