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

#ifndef NATIVE_AVSCREEN_CAPTURE_H
#define NATIVE_AVSCREEN_CAPTURE_H

#include <stdint.h>
#include <stdio.h>
#include "native_avscreen_capture_errors.h"
#include "native_avscreen_capture_base.h"
#include "native_window/external_window.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Create a screen capture
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @return Returns a pointer to an OH_AVScreenCapture instance
 * @since 10
 * @version 1.0
 */
struct OH_AVScreenCapture *OH_AVScreenCapture_Create(void);

/**
 * @brief To init the screen capture, typically, you need to configure the description information of the audio
 * and video, which can be extracted from the container. This interface must be called before StartAVScreenCapture
 * called.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param config Information describing the audio and video config
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, init config failed.
 * @since 10
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_Init(struct OH_AVScreenCapture *capture,
    OH_AVScreenCaptureConfig config);

/**
 * @brief Start the av screen capture
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param type Information describing the data type of the capture
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, set privacy authority enabled
 *         failed or start ScreenCapture failed.
 * @since 10
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_StartScreenCapture(struct OH_AVScreenCapture *capture);

/**
 * @brief Stop the av screen capture
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, stop ScreenCapture failed.
 * @since 10
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_StopScreenCapture(struct OH_AVScreenCapture *capture);

/**
 * @brief Start av screen record use to start save screen record file.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, set privacy authority enabled
 *         failed or start ScreenRecording failed.
 * @since 10
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_StartScreenRecording(struct OH_AVScreenCapture *capture);

/**
 * @brief Start av screen record use to stop save screen record file.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, stop ScreenRecording failed.
 * @since 10
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_StopScreenRecording(struct OH_AVScreenCapture *capture);

/**
 * @brief Acquire the audio buffer for the av screen capture
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param audiobuffer Information describing the audio buffer of the capture
 * @param type Information describing the audio source type
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr or input **audiobuffer is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_NO_MEMORY} no memory, audiobuffer allocate failed.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, not permit for has set
 *         DataCallback or acquire AudioBuffer failed.
 * @since 10
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_AcquireAudioBuffer(struct OH_AVScreenCapture *capture,
    OH_AudioBuffer **audiobuffer, OH_AudioCaptureSourceType type);

/**
 * @brief Acquire the video buffer for the av screen capture
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param fence A processing state of display buffer
 * @param timestamp Information about the video buffer
 * @param region Information about the video buffer
 * @return Returns a pointer to an OH_NativeBuffer instance
 * @since 10
 * @version 1.0
 */
OH_NativeBuffer* OH_AVScreenCapture_AcquireVideoBuffer(struct OH_AVScreenCapture *capture,
    int32_t *fence, int64_t *timestamp, struct OH_Rect *region);

/**
 * @brief Release the audio buffer for the av screen capture
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param type Information describing the audio source type
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, not permit for has set
 *         DataCallback or Release AudioBuffer failed.
 * @since 10
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_ReleaseAudioBuffer(struct OH_AVScreenCapture *capture,
    OH_AudioCaptureSourceType type);

/**
 * @brief Release the video buffer for the av screen capture
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, not permit for has set
 *         DataCallback or Release VideoBuffer failed.
 * @since 10
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_ReleaseVideoBuffer(struct OH_AVScreenCapture *capture);

/**
 * @brief Set the callback function so that your application
 * can respond to the events generated by the av screen capture. This interface must be called before Init is called.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param callback A collection of all callback functions, see {@link OH_AVScreenCaptureCallback}
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr or input callback is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, set callback failed.
 * @since 10
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_SetCallback(struct OH_AVScreenCapture *capture,
    struct OH_AVScreenCaptureCallback callback);

/**
 * @brief Release the av screen capture
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, screen capture release failed.
 * @since 10
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_Release(struct OH_AVScreenCapture *capture);

/**
 * @brief Controls the switch of the microphone, which is turned on by default
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param isMicrophone The switch of the microphone
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, set microphone enable failed.
 * @since 10
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_SetMicrophoneEnabled(struct OH_AVScreenCapture *capture,
    bool isMicrophone);

/**
 * @brief Set the state callback function so that your application can respond to the
 * state change events generated by the av screen capture. This interface must be called before Start is called.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param callback State callback function, see {@link OH_AVScreenCapture_OnStateChange}
 * @param userData Pointer to user specific data
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr or input callback is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_NO_MEMORY} no memory, mem allocate failed.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, set StateCallback failed.
 * @since 12
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_SetStateCallback(struct OH_AVScreenCapture *capture,
    OH_AVScreenCapture_OnStateChange callback, void *userData);

/**
 * @brief Set the data callback function so that your application can respond to the
 * data available events generated by the av screen capture. This interface must be called before Start is called.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param callback Data callback function, see {@link OH_AVScreenCapture_OnBufferAvailable}
 * @param userData Pointer to user specific data
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr or input callback is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_NO_MEMORY} no memory, mem allocate failed.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, set DataCallback failed.
 * @since 12
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_SetDataCallback(struct OH_AVScreenCapture *capture,
    OH_AVScreenCapture_OnBufferAvailable callback, void *userData);

/**
 * @brief Set the error callback function so that your application can respond to the
 * error events generated by the av screen capture. This interface must be called before Start is called.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param callback Error callback function, see {@link OH_AVScreenCapture_OnError}
 * @param userData Pointer to user specific data
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr or input callback is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_NO_MEMORY} no memory, mem allocate failed.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, set ErrorCallback failed.
 * @since 12
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_SetErrorCallback(struct OH_AVScreenCapture *capture,
    OH_AVScreenCapture_OnError callback, void *userData);

/**
 * @brief Start the av screen capture, video data provided by OHNativeWindow
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param window Pointer to an OHNativeWindow instance
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr or input window is nullptr or
 *         input windowSurface is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, set privacy authority enabled
 *         failed or start ScreenCaptureWithSurface failed.
 * @since 12
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_StartScreenCaptureWithSurface(struct OH_AVScreenCapture *capture,
    OHNativeWindow *window);

/**
 * @brief Set canvas rotation when capturing screen
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param canvasRotation whether to rotate the canvas
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT} opertation not be permitted, set CanvasRotation failed.
 * @since 12
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_SetCanvasRotation(struct OH_AVScreenCapture *capture,
    bool canvasRotation);

/**
 * @brief Create a screen capture content filter
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @return Returns a pointer to an OH_AVScreenCapture_ContentFilter instance
 * @since 12
 * @version 1.0
 */
struct OH_AVScreenCapture_ContentFilter *OH_AVScreenCapture_CreateContentFilter(void);

/**
 * @brief Release the screen capture content filter
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param filter Pointer to an OH_AVScreenCapture_ContentFilter instance
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input filter is nullptr.
 * @since 12
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_ReleaseContentFilter(struct OH_AVScreenCapture_ContentFilter *filter);

/**
 * @brief Add content to the screen capture content filter
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param filter Pointer to an OH_AVScreenCapture_ContentFilter instance
 * @param content content to be added
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input filter is nullptr or input content invalid.
 * @since 12
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_ContentFilter_AddAudioContent(
    struct OH_AVScreenCapture_ContentFilter *filter, OH_AVScreenCaptureFilterableAudioContent content);

/**
 * @brief Set content filter to screen capture
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param filter Pointer to an OH_AVScreenCapture_ContentFilter instance
 * @return Function result code.
 *         {@link AV_SCREEN_CAPTURE_ERR_OK} if the execution is successful.
 *         {@link AV_SCREEN_CAPTURE_ERR_INVALID_VAL} input capture is nullptr or input filter is nullptr.
 *         {@link AV_SCREEN_CAPTURE_ERR_UNSUPPORT} not support, for STREAM, should call AudioCapturer interface to make
 *         effect when start, for CAPTURE FILE, should call Recorder interface to make effect when start.
 * @since 12
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_ExcludeContent(struct OH_AVScreenCapture *capture,
    struct OH_AVScreenCapture_ContentFilter *filter);

/**
 * @brief Add Window content to the screen capture content filter
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param filter Pointer to an OH_AVScreenCapture_ContentFilter instance
 * @param Pointer to windowIDs to be added
 * @param windowCount to be added
 * @return Returns AV_SCREEN_CAPTURE_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVSCREEN_CAPTURE_ErrCode}
 * @since 12
 * @version 1.0
 */
OH_AVSCREEN_CAPTURE_ErrCode OH_AVScreenCapture_ContentFilter_AddWindowContent(
    struct OH_AVScreenCapture_ContentFilter *filter, int32_t *windowIDs, int32_t windowCount);
#ifdef __cplusplus
}
#endif

#endif // NATIVE_AVSCREEN_CAPTURE_H