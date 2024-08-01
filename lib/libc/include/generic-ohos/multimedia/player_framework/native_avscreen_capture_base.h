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

#ifndef NATIVE_AVSCREEN_CAPTURE_BASE_H
#define NATIVE_AVSCREEN_CAPTURE_BASE_H

#include <stdint.h>
#include "native_avbuffer.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Nativebuffer of avscreeencapture that from graphics.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef struct OH_NativeBuffer OH_NativeBuffer;

/**
 * @brief Initialization of avscreeencapture
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef struct OH_AVScreenCapture OH_AVScreenCapture;

/**
 * @brief Initialization of OH_AVScreenCapture_ContentFilter
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_AVScreenCapture_ContentFilter OH_AVScreenCapture_ContentFilter;

/**
 * @brief Enumerates screen capture mode.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef enum OH_CaptureMode {
    /* capture home screen */
    OH_CAPTURE_HOME_SCREEN = 0,
    /* capture a specified screen */
    OH_CAPTURE_SPECIFIED_SCREEN = 1,
    /* capture a specified window */
    OH_CAPTURE_SPECIFIED_WINDOW = 2,
    OH_CAPTURE_INVAILD = -1
} OH_CaptureMode;

/**
 * @brief Enumerates audio cap source type.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef enum OH_AudioCaptureSourceType {
    /* Invalid audio source */
    OH_SOURCE_INVALID = -1,
    /* Default audio source */
    OH_SOURCE_DEFAULT = 0,
    /* Microphone */
    OH_MIC = 1,
    /* inner all PlayBack */
    OH_ALL_PLAYBACK = 2,
    /* inner app PlayBack */
    OH_APP_PLAYBACK = 3,
} OH_AudioCaptureSourceType;

/**
 * @brief Enumerates audio codec formats.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef enum OH_AudioCodecFormat {
    /* Default format */
    OH_AUDIO_DEFAULT = 0,
    /* Advanced Audio Coding Low Complexity (AAC-LC) */
    OH_AAC_LC = 3,
    /* Invalid value */
    OH_AUDIO_CODEC_FORMAT_BUTT,
} OH_AudioCodecFormat;

/**
 * @brief Enumerates video codec formats.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef enum OH_VideoCodecFormat {
    /* Default format */
    OH_VIDEO_DEFAULT = 0,
    /* H.264 */
    OH_H264 = 2,
    /* H.265/HEVC */
    OH_H265 = 4,
    /* MPEG4 */
    OH_MPEG4 = 6,
    /* VP8 */
    OH_VP8 = 8,
    /* VP9 */
    OH_VP9 = 10,
    /* Invalid format */
    OH_VIDEO_CODEC_FORMAT_BUTT,
} OH_VideoCodecFormat;

/**
 * @brief Enumerates screen capture data type.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef enum OH_DataType {
    /* YUV/RGBA/PCM, etc. original stream */
    OH_ORIGINAL_STREAM = 0,
    /* h264/AAC, etc. encoded stream */
    OH_ENCODED_STREAM = 1,
    /* mp4 file */
    OH_CAPTURE_FILE = 2,
    OH_INVAILD = -1
} OH_DataType;

/**
 * @brief Enumerates video source types.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef enum OH_VideoSourceType {
    /* Unsupported App Usage. */
    /* YUV video data provided through graphic */
    OH_VIDEO_SOURCE_SURFACE_YUV = 0,
    /* Raw encoded data provided through graphic */
    OH_VIDEO_SOURCE_SURFACE_ES,
    /* RGBA video data provided through graphic */
    OH_VIDEO_SOURCE_SURFACE_RGBA,
    /* Invalid value */
    OH_VIDEO_SOURCE_BUTT
} OH_VideoSourceType;

/**
 * @brief Enumerates the container format types.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef enum OH_ContainerFormatType {
    /* Audio format type -- m4a */
    CFT_MPEG_4A = 0,
    /* Video format type -- mp4 */
    CFT_MPEG_4 = 1
} OH_ContainerFormatType;

/**
 * @brief Audio capture info struct
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef struct OH_AudioCaptureInfo {
    /* Audio capture sample rate info */
    int32_t audioSampleRate;
    /* Audio capture channel info */
    int32_t audioChannels;
    /* Audio capture source type */
    OH_AudioCaptureSourceType audioSource;
} OH_AudioCaptureInfo;

/**
 * @brief Audio encoder info
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef struct OH_AudioEncInfo {
    /* Audio encoder bitrate */
    int32_t audioBitrate;
    /* Audio codec format */
    OH_AudioCodecFormat audioCodecformat;
} OH_AudioEncInfo;

/**
 * @brief The audio info of avscreeencapture
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef struct OH_AudioInfo {
    /* Audio capture info of microphone */
    OH_AudioCaptureInfo micCapInfo;
    /* Audio capture info of inner */
    OH_AudioCaptureInfo innerCapInfo;
    /* Audio encoder info, no need to set, while dataType = OH_ORIGINAL_STREAM */
    OH_AudioEncInfo audioEncInfo;
} OH_AudioInfo;

/**
 * @brief Video capture info
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef struct OH_VideoCaptureInfo {
    /* Display id, should be set while captureMode = CAPTURE_SPECIFIED_SCREEN */
    uint64_t displayId;
    /* The  ids of mission, should be set while captureMode = CAPTURE_SPECIFIED_WINDOW */
    int32_t *missionIDs;
    /* Mission ids length, should be set while captureMode = CAPTURE_SPECIFIED_WINDOW */
    int32_t missionIDsLen;
    /* Video frame width of avscreeencapture */
    int32_t videoFrameWidth;
    /* Video frame height of avscreeencapture */
    int32_t videoFrameHeight;
    /* Video source type of avscreeencapture */
    OH_VideoSourceType videoSource;
} OH_VideoCaptureInfo;

/**
 * @brief Videoc encoder info
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef struct OH_VideoEncInfo {
    /* Video encoder format */
    OH_VideoCodecFormat videoCodec;
    /* Video encoder bitrate */
    int32_t videoBitrate;
    /* Video encoder frame rate */
    int32_t videoFrameRate;
} OH_VideoEncInfo;

/**
 * @brief Video info
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef struct OH_VideoInfo {
    /* Video capture info */
    OH_VideoCaptureInfo videoCapInfo;
    /* Video encoder info */
    OH_VideoEncInfo videoEncInfo;
} OH_VideoInfo;

/**
 * @brief Recorder file info
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef struct OH_RecorderInfo {
    /* Recorder file url */
    char *url;
    /* Recorder file url length */
    uint32_t urlLen;
    /* Recorder file format */
    OH_ContainerFormatType fileFormat;
} OH_RecorderInfo;

/**
 * @brief AV screeen capture config info
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef struct OH_AVScreenCaptureConfig {
    OH_CaptureMode captureMode;
    OH_DataType dataType;
    OH_AudioInfo audioInfo;
    OH_VideoInfo videoInfo;
    /* should be set, while dataType = OH_CAPTURE_FILE */
    OH_RecorderInfo recorderInfo;
} OH_AVScreenCaptureConfig;

/**
 * @brief When an error occurs in the running of the OH_AVScreenCapture instance, the function pointer will be called
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param errorCode specific error code
 *
 * @since 10
 * @version 1.0
 */
typedef void (*OH_AVScreenCaptureOnError)(OH_AVScreenCapture *capture, int32_t errorCode);

/**
 * @brief When audio buffer is available during the operation of OH_AVScreenCapture, the function pointer will
 * be called.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param isReady Information describing whether audio buffer is available
 * @param type Information describing the audio source type
 *
 * @since 10
 * @version 1.0
 */
typedef void (*OH_AVScreenCaptureOnAudioBufferAvailable)(OH_AVScreenCapture *capture, bool isReady,
    OH_AudioCaptureSourceType type);

/**
 * @brief When video buffer is available during the operation of OH_AVScreenCapture, the function pointer will
 * be called.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param isReady Information describing whether video buffer is available
 *
 * @since 10
 * @version 1.0
 */
typedef void (*OH_AVScreenCaptureOnVideoBufferAvailable)(OH_AVScreenCapture *capture, bool isReady);

/**
 * @brief A collection of all callback function pointers in OH_AVScreenCapture. Register an instance of this
 * structure to the OH_AVScreenCapture instance, and process the information reported through the callback to ensure the
 * normal operation of OH_AVScreenCapture.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param onError Monitor OH_AVScreenCapture operation errors, refer to {@link OH_AVScreenCaptureOnError}
 * @param onAudioBufferAvailable Monitor audio buffer, refer to {@link OH_AVScreenCaptureOnAudioBufferAvailable}
 * @param onVideoBufferAvailable Monitor video buffer, refer to {@link OH_AVScreenCaptureOnVideoBufferAvailable}
 *
 * @since 10
 * @version 1.0
 */
typedef struct OH_AVScreenCaptureCallback {
    OH_AVScreenCaptureOnError onError;
    OH_AVScreenCaptureOnAudioBufferAvailable onAudioBufferAvailable;
    OH_AVScreenCaptureOnVideoBufferAvailable onVideoBufferAvailable;
} OH_AVScreenCaptureCallback;

/**
 * @brief avscreeencapture rect info
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef struct OH_Rect {
    /* X-coordinate of screen recording */
    int32_t x;
    /* y-coordinate of screen recording */
    int32_t y;
    /* Width of screen recording */
    int32_t width;
    /* Height of screen recording */
    int32_t height;
} OH_Rect;


/**
 * @brief Audiobuffer struct info
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 10
 * @version 1.0
 */
typedef struct OH_AudioBuffer {
    /* Audio buffer memory block  */
    uint8_t *buf;
    /* Audio buffer memory block size */
    int32_t size;
    /* Audio buffer timestamp info */
    int64_t timestamp;
    /* Audio capture source type */
    OH_AudioCaptureSourceType type;
} OH_AudioBuffer;

/**
 * @brief Enumerates screen capture state code.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 12
 * @version 1.0
 */
typedef enum OH_AVScreenCaptureStateCode {
    /* Screen capture started by user */
    OH_SCREEN_CAPTURE_STATE_STARTED = 0,
    /* Screen capture canceled by user */
    OH_SCREEN_CAPTURE_STATE_CANCELED = 1,
    /* ScreenCapture stopped by user */
    OH_SCREEN_CAPTURE_STATE_STOPPED_BY_USER = 2,
    /* ScreenCapture interrupted by other screen capture */
    OH_SCREEN_CAPTURE_STATE_INTERRUPTED_BY_OTHER = 3,
    /* ScreenCapture stopped by SIM call */
    OH_SCREEN_CAPTURE_STATE_STOPPED_BY_CALL = 4,
    /* Microphone is temporarily unavailable */
    OH_SCREEN_CAPTURE_STATE_MIC_UNAVAILABLE = 5,
    /* Microphone is muted by user */
    OH_SCREEN_CAPTURE_STATE_MIC_MUTED_BY_USER = 6,
    /* Microphone is unmuted by user */
    OH_SCREEN_CAPTURE_STATE_MIC_UNMUTED_BY_USER = 7,
    /* Current captured screen has private window */
    OH_SCREEN_CAPTURE_STATE_ENTER_PRIVATE_SCENE = 8,
    /* Private window disappeared on current captured screen*/
    OH_SCREEN_CAPTURE_STATE_EXIT_PRIVATE_SCENE = 9,
} OH_AVScreenCaptureStateCode;

/**
 * @brief Enumerates screen capture buffer type.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 12
 * @version 1.0
 */
typedef enum OH_AVScreenCaptureBufferType {
    /* Buffer of video data from screen */
    OH_SCREEN_CAPTURE_BUFFERTYPE_VIDEO = 0,
    /* Buffer of audio data from inner capture */
    OH_SCREEN_CAPTURE_BUFFERTYPE_AUDIO_INNER = 1,
    /* Buffer of audio data from microphone */
    OH_SCREEN_CAPTURE_BUFFERTYPE_AUDIO_MIC = 2,
} OH_AVScreenCaptureBufferType;

/**
 * @brief Enumerates screen capture buffer type.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 *
 * @since 12
 * @version 1.0
 */
typedef enum OH_AVScreenCaptureFilterableAudioContent {
    /* Audio content of notification sound */
    OH_SCREEN_CAPTURE_NOTIFICATION_AUDIO = 0,
    /* Audio content of the sound of the app itself */
    OH_SCREEN_CAPTURE_CURRENT_APP_AUDIO = 1,
} OH_AVScreenCaptureFilterableAudioContent;

/**
 * @brief When state of OH_AVScreenCapture is changed, the function pointer will be called.
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param stateCode Information describing current state, see {@link OH_AVScreenCaptureStateCode}
 * @param userData Pointer to user specific data
 *
 * @since 12
 * @version 1.0
 */
typedef void (*OH_AVScreenCapture_OnStateChange)(struct OH_AVScreenCapture *capture,
    OH_AVScreenCaptureStateCode stateCode, void *userData);

/**
 * @brief When an error occurs in the running of the OH_AVScreenCapture instance, the function pointer will be called
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param errorCode specific error code
 * @param userData Pointer to user specific data
 *
 * @since 12
 * @version 1.0
 */
typedef void (*OH_AVScreenCapture_OnError)(OH_AVScreenCapture *capture, int32_t errorCode, void *userData);

/**
 * @brief When data is ready from the OH_AVScreenCapture instance, the function pointer will be called
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @param capture Pointer to an OH_AVScreenCapture instance
 * @param buffer Pointer to a buffer containing media data
 * @param bufferType Data type of the buffer, see {@link OH_AVScreenCaptureBufferType}
 * @param timestamp Timestamp of the buffer
 * @param userData Pointer to user specific data
 *
 * @since 12
 * @version 1.0
 */
typedef void (*OH_AVScreenCapture_OnBufferAvailable)(OH_AVScreenCapture *capture, OH_AVBuffer *buffer,
    OH_AVScreenCaptureBufferType bufferType, int64_t timestamp, void *userData);

#ifdef __cplusplus
}
#endif

#endif // NATIVE_AVSCREEN_CAPTURE_BASE_H