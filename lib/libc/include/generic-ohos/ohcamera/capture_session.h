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
 * @file capture_session.h
 *
 * @brief Declare the capture Session concepts.
 *
 * @library libohcamera.so
 * @syscap SystemCapability.Multimedia.Camera.Core
 * @since 11
 * @version 1.0
 */

#ifndef NATIVE_INCLUDE_CAMERA_CAMERA_SESSION_H
#define NATIVE_INCLUDE_CAMERA_CAMERA_SESSION_H

#include <stdint.h>
#include <stdio.h>
#include "camera.h"
#include "camera_input.h"
#include "preview_output.h"
#include "photo_output.h"
#include "video_output.h"
#include "metadata_output.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Capture session object
 *
 * A pointer can be created using {@link Camera_CaptureSession} method.
 *
 * @since 11
 * @version 1.0
 */
typedef struct Camera_CaptureSession Camera_CaptureSession;

/**
 * @brief Capture session focus state callback to be called in {@link CaptureSession_Callbacks}.
 *
 * @param session the {@link Camera_CaptureSession} which deliver the callback.
 * @param focusState the {@link Camera_FocusState} which delivered by the callback.
 * @since 11
 */
typedef void (*OH_CaptureSession_OnFocusStateChange)(Camera_CaptureSession* session, Camera_FocusState focusState);

/**
 * @brief Capture session error callback to be called in {@link CaptureSession_Callbacks}.
 *
 * @param session the {@link Camera_CaptureSession} which deliver the callback.
 * @param errorCode the {@link Camera_ErrorCode} of the capture session.
 *
 * @see CAMERA_SERVICE_FATAL_ERROR
 * @since 11
 */
typedef void (*OH_CaptureSession_OnError)(Camera_CaptureSession* session, Camera_ErrorCode errorCode);

/**
 * @brief A listener for capture session.
 *
 * @see OH_CaptureSession_RegisterCallback
 * @since 11
 * @version 1.0
 */
typedef struct CaptureSession_Callbacks {
    /**
     * Capture session focus state change event.
     */
    OH_CaptureSession_OnFocusStateChange onFocusStateChange;

    /**
     * Capture session error event.
     */
    OH_CaptureSession_OnError onError;
} CaptureSession_Callbacks;

/**
 * @brief Register capture session event callback.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param callback the {@link CaptureSession_Callbacks} to be registered.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_RegisterCallback(Camera_CaptureSession* session,
    CaptureSession_Callbacks* callback);

/**
 * @brief Unregister capture session event callback.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param callback the {@link CaptureSession_Callbacks} to be unregistered.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_UnregisterCallback(Camera_CaptureSession* session,
    CaptureSession_Callbacks* callback);

/**
 * @brief Specifies the specific mode.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param sceneMode the {@link CaptureSession_SceneMode} instance.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #OPERATION_NOT_ALLOWED} if operation not allowed.
 *         {@link #CAMERA_SESSION_CONFIG_LOCKED} if session config locked.
 * @since 12
 */
Camera_ErrorCode OH_CaptureSession_SetSessionMode(Camera_CaptureSession* session, Camera_SceneMode sceneMode);
 
/**
 * @brief Specifies the specific mode. The default mode is the photomode.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param previewOutput the target {@link Camera_PreviewOutput} to Set as a secure flow.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #OPERATION_NOT_ALLOWED} if operation not allowed.
 *         {@link #CAMERA_SESSION_CONFIG_LOCKED} if session config locked.
 * @since 12
 */
Camera_ErrorCode OH_CaptureSession_AddSecureOutput(Camera_CaptureSession* session, Camera_PreviewOutput* previewOutput);

/**
 * @brief Begin capture session config.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_CONFIG_LOCKED} if session config locked.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_BeginConfig(Camera_CaptureSession* session);

/**
 * @brief Commit capture session config.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_OPERATION_NOT_ALLOWED} if operation not allowed.
 *         {@link #CAMERA_SERVICE_FATAL_ERROR} if camera service fatal error.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_CommitConfig(Camera_CaptureSession* session);

/**
 * @brief Add a camera input.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param cameraInput the target {@link Camera_Input} to add.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_OPERATION_NOT_ALLOWED} if operation not allowed.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_AddInput(Camera_CaptureSession* session, Camera_Input* cameraInput);

/**
 * @brief Remove a camera input.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param cameraInput the target {@link Camera_Input} to remove.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_OPERATION_NOT_ALLOWED} if operation not allowed.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_RemoveInput(Camera_CaptureSession* session, Camera_Input* cameraInput);

/**
 * @brief Add a preview output.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param previewOutput the target {@link Camera_PreviewOutput} to add.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_OPERATION_NOT_ALLOWED} if operation not allowed.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_AddPreviewOutput(Camera_CaptureSession* session,
    Camera_PreviewOutput* previewOutput);

/**
 * @brief Remove a preview output.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param previewOutput the target {@link Camera_PreviewOutput} to remove.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_OPERATION_NOT_ALLOWED} if operation not allowed.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_RemovePreviewOutput(Camera_CaptureSession* session,
    Camera_PreviewOutput* previewOutput);

/**
 * @brief Add a photo output.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param photoOutput the target {@link Camera_PhotoOutput} to add.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_OPERATION_NOT_ALLOWED} if operation not allowed.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_AddPhotoOutput(Camera_CaptureSession* session, Camera_PhotoOutput* photoOutput);

/**
 * @brief Remove a photo output.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param photoOutput the target {@link Camera_PhotoOutput} to remove.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_OPERATION_NOT_ALLOWED} if operation not allowed.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_RemovePhotoOutput(Camera_CaptureSession* session, Camera_PhotoOutput* photoOutput);

/**
 * @brief Add a video output.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param videoOutput the target {@link Camera_VideoOutput} to add.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_OPERATION_NOT_ALLOWED} if operation not allowed.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_AddVideoOutput(Camera_CaptureSession* session, Camera_VideoOutput* videoOutput);

/**
 * @brief Remove a video output.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param videoOutput the target {@link Camera_VideoOutput} to remove.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_OPERATION_NOT_ALLOWED} if operation not allowed.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_RemoveVideoOutput(Camera_CaptureSession* session, Camera_VideoOutput* videoOutput);

/**
 * @brief Add a metadata output.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param metadataOutput the target {@link Camera_MetadataOutput} to add.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_OPERATION_NOT_ALLOWED} if operation not allowed.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_AddMetadataOutput(Camera_CaptureSession* session,
    Camera_MetadataOutput* metadataOutput);

/**
 * @brief Remove a metadata output.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param metadataOutput the target {@link Camera_MetadataOutput} to remove.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_OPERATION_NOT_ALLOWED} if operation not allowed.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_RemoveMetadataOutput(Camera_CaptureSession* session,
    Camera_MetadataOutput* metadataOutput);

/**
 * @brief Start capture session.
 *
 * @param session the {@link Camera_CaptureSession} instance to be started.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 *         {@link #CAMERA_SERVICE_FATAL_ERROR} if camera service fatal error.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_Start(Camera_CaptureSession* session);

/**
 * @brief Stop capture session.
 *
 * @param session the {@link Camera_CaptureSession} instance to be stoped.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SERVICE_FATAL_ERROR} if camera service fatal error.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_Stop(Camera_CaptureSession* session);

/**
 * @brief Release capture session.
 *
 * @param session the {@link Camera_CaptureSession} instance to be release.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SERVICE_FATAL_ERROR} if camera service fatal error.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_Release(Camera_CaptureSession* session);

/**
 * @brief Check if device has flash light.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param hasFlash the result of whether flash supported.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_HasFlash(Camera_CaptureSession* session, bool* hasFlash);

/**
 * @brief Check whether a specified flash mode is supported.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param flashMode the {@link Camera_FlashMode} to be checked.
 * @param isSupported the result of whether flash mode supported.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_IsFlashModeSupported(Camera_CaptureSession* session,
    Camera_FlashMode flashMode, bool* isSupported);

/**
 * @brief Get current flash mode.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param flashMode the current {@link Camera_FlashMode}.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_GetFlashMode(Camera_CaptureSession* session, Camera_FlashMode* flashMode);

/**
 * @brief Set flash mode.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param flashMode the target {@link Camera_FlashMode} to set.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_SetFlashMode(Camera_CaptureSession* session, Camera_FlashMode flashMode);

/**
 * @brief Check whether a specified exposure mode is supported.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param exposureMode the {@link Camera_ExposureMode} to be checked.
 * @param isSupported the result of whether exposure mode supported.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_IsExposureModeSupported(Camera_CaptureSession* session,
    Camera_ExposureMode exposureMode, bool* isSupported);

/**
 * @brief Get current exposure mode.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param exposureMode the current {@link Camera_ExposureMode}.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_GetExposureMode(Camera_CaptureSession* session, Camera_ExposureMode* exposureMode);

/**
 * @brief Set exposure mode.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param exposureMode the target {@link Camera_ExposureMode} to set.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_SetExposureMode(Camera_CaptureSession* session, Camera_ExposureMode exposureMode);

/**
 * @brief Get current metering point.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param point the current {@link Camera_Point} metering point.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_GetMeteringPoint(Camera_CaptureSession* session, Camera_Point* point);

/**
 * @brief Set the center point of the metering area.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param point the target {@link Camera_Point} to set.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_SetMeteringPoint(Camera_CaptureSession* session, Camera_Point point);

/**
 * @brief Query the exposure compensation range.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param minExposureBias the minimum of exposure compensation.
 * @param maxExposureBias the Maximum of exposure compensation.
 * @param step the step of exposure compensation between each level.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_GetExposureBiasRange(Camera_CaptureSession* session, float* minExposureBias,
    float* maxExposureBias, float* step);

/**
 * @brief Set exposure compensation.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param exposureBias the target exposure compensation to set.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_SetExposureBias(Camera_CaptureSession* session, float exposureBias);

/**
 * @brief Get current exposure compensation.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param exposureBias the current exposure compensation.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_GetExposureBias(Camera_CaptureSession* session, float* exposureBias);

/**
 * @brief Check whether a specified focus mode is supported.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param focusMode the {@link Camera_FocusMode} to be checked.
 * @param isSupported the result of whether focus mode supported.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_IsFocusModeSupported(Camera_CaptureSession* session,
    Camera_FocusMode focusMode, bool* isSupported);

/**
 * @brief Get current focus mode.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param exposureBias the current {@link Camera_FocusMode}.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_GetFocusMode(Camera_CaptureSession* session, Camera_FocusMode* focusMode);

/**
 * @brief Set focus mode.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param focusMode the target {@link Camera_FocusMode} to set.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_SetFocusMode(Camera_CaptureSession* session, Camera_FocusMode focusMode);

/**
 * @brief Get current focus point.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param focusPoint the current {@link Camera_Point}.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_GetFocusPoint(Camera_CaptureSession* session, Camera_Point* focusPoint);

/**
 * @brief Set focus point.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param focusPoint the target {@link Camera_Point} to set.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_SetFocusPoint(Camera_CaptureSession* session, Camera_Point focusPoint);

/**
 * @brief Get all supported zoom ratio range.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param minZoom the minimum of zoom ratio range.
 * @param maxZoom the Maximum of zoom ratio range.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_GetZoomRatioRange(Camera_CaptureSession* session, float* minZoom, float* maxZoom);

/**
 * @brief Get current zoom ratio.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param zoom the current zoom ratio.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_GetZoomRatio(Camera_CaptureSession* session, float* zoom);

/**
 * @brief Set zoom ratio.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param zoom the target zoom ratio to set.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_SetZoomRatio(Camera_CaptureSession* session, float zoom);

/**
 * @brief Check whether a specified video stabilization mode is supported.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param mode the {@link Camera_VideoStabilizationMode} to be checked.
 * @param isSupported the result of whether video stabilization mode supported.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_IsVideoStabilizationModeSupported(Camera_CaptureSession* session,
    Camera_VideoStabilizationMode mode, bool* isSupported);

/**
 * @brief Get current video stabilization mode.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param mode the current {@link Camera_VideoStabilizationMode}.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_GetVideoStabilizationMode(Camera_CaptureSession* session,
    Camera_VideoStabilizationMode* mode);

/**
 * @brief Set video stabilization mode.
 *
 * @param session the {@link Camera_CaptureSession} instance.
 * @param mode the target {@link Camera_VideoStabilizationMode} to set.
 * @return {@link #CAMERA_OK} if the method call succeeds.
 *         {@link #INVALID_ARGUMENT} if parameter missing or parameter type incorrect.
 *         {@link #CAMERA_SESSION_NOT_CONFIG} if the capture session not config.
 * @since 11
 */
Camera_ErrorCode OH_CaptureSession_SetVideoStabilizationMode(Camera_CaptureSession* session,
    Camera_VideoStabilizationMode mode);

#ifdef __cplusplus
}
#endif

#endif // NATIVE_INCLUDE_CAMERA_CAMERA_SESSION_H
/** @} */