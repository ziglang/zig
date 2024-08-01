/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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
 * @addtogroup OHAudio
 * @{
 *
 * @brief Provide the definition of the C interface for the audio module.
 *
 * @syscap SystemCapability.Multimedia.Audio.Core
 *
 * @since 10
 * @version 1.0
 */

/**
 * @file native_audiostream_base.h
 *
 * @brief Declare the underlying data structure.
 *
 * @syscap SystemCapability.Multimedia.Audio.Core
 * @since 10
 * @version 1.0
 */

#ifndef NATIVE_AUDIOSTREAM_BASE_H
#define NATIVE_AUDIOSTREAM_BASE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Define the result of the function execution.
 *
 * @since 10
 */
typedef enum {
    /**
     * @error The call was successful.
     *
     * @since 10
     */
    AUDIOSTREAM_SUCCESS = 0,

    /**
     * @error This means that the function was executed with an invalid input parameter.
     *
     * @since 10
     */
    AUDIOSTREAM_ERROR_INVALID_PARAM = 1,

    /**
     * @error Execution status exception.
     *
     * @since 10
     */
    AUDIOSTREAM_ERROR_ILLEGAL_STATE = 2,

    /**
     * @error An system error has occurred.
     *
     * @since 10
     */
    AUDIOSTREAM_ERROR_SYSTEM = 3
} OH_AudioStream_Result;

/**
 * @brief Define the audio stream type.
 *
 * @since 10
 */
typedef enum {
    /**
     * The type for audio stream is renderer.
     *
     * @since 10
     */
    AUDIOSTREAM_TYPE_RENDERER = 1,

    /**
     * The type for audio stream is capturer.
     *
     * @since 10
     */
    AUDIOSTREAM_TYPE_CAPTURER = 2
} OH_AudioStream_Type;

/**
 * @brief Define the audio stream sample format.
 *
 * @since 10
 */
typedef enum {
    /**
     * Unsigned 8 format.
     *
     * @since 10
     */
    AUDIOSTREAM_SAMPLE_U8 = 0,
    /**
     * Signed 16 bit integer, little endian.
     *
     * @since 10
     */
    AUDIOSTREAM_SAMPLE_S16LE = 1,
    /**
     * Signed 24 bit integer, little endian.
     *
     * @since 10
     */
    AUDIOSTREAM_SAMPLE_S24LE = 2,
    /**
     * Signed 32 bit integer, little endian.
     *
     * @since 10
     */
    AUDIOSTREAM_SAMPLE_S32LE = 3,
} OH_AudioStream_SampleFormat;

/**
 * @brief Define the audio encoding type.
 *
 * @since 10
 */
typedef enum {
    /**
     * PCM encoding type.
     *
     * @since 10
     */
    AUDIOSTREAM_ENCODING_TYPE_RAW = 0,
    /**
     * AudioVivid encoding type.
     *
     * @since 12
     */
    AUDIOSTREAM_ENCODING_TYPE_AUDIOVIVID = 1,
} OH_AudioStream_EncodingType;

/**
 * @brief Define the audio stream usage.
 * Audio stream usage is used to describe what work scenario
 * the current stream is used for.
 *
 * @since 10
 */
typedef enum {
    /**
     * Unknown usage.
     *
     * @since 10
     */
    AUDIOSTREAM_USAGE_UNKNOWN = 0,
    /**
     * Music usage.
     *
     * @since 10
     */
    AUDIOSTREAM_USAGE_MUSIC = 1,
    /**
     * Voice communication usage.
     *
     * @since 10
     */
    AUDIOSTREAM_USAGE_VOICE_COMMUNICATION = 2,
    /**
     * Voice assistant usage.
     *
     * @since 10
     */
    AUDIOSTREAM_USAGE_VOICE_ASSISTANT = 3,
    /**
     * Alarm usage.
     *
     * @since 10
     */
    AUDIOSTREAM_USAGE_ALARM = 4,
    /**
     * Voice message usage.
     *
     * @since 10
     */
    AUDIOSTREAM_USAGE_VOICE_MESSAGE = 5,
    /**
     * Ringtone usage.
     *
     * @since 10
     */
    AUDIOSTREAM_USAGE_RINGTONE = 6,
    /**
     * Notification usage.
     *
     * @since 10
     */
    AUDIOSTREAM_USAGE_NOTIFICATION = 7,
    /**
     * Accessibility usage, such as screen reader.
     *
     * @since 10
     */
    AUDIOSTREAM_USAGE_ACCESSIBILITY = 8,
    /**
     * Movie or video usage.
     *
     * @since 10
     */
    AUDIOSTREAM_USAGE_MOVIE = 10,
    /**
     * Game sound effect usage.
     *
     * @since 10
     */
    AUDIOSTREAM_USAGE_GAME = 11,
    /**
     * Audiobook usage.
     *
     * @since 10
     */
    AUDIOSTREAM_USAGE_AUDIOBOOK = 12,
    /**
     * Navigation usage.
     *
     * @since 10
     */
    AUDIOSTREAM_USAGE_NAVIGATION = 13,
     /**
     * Video call usage.
     *
     * @since 12
     */
    AUDIOSTREAM_USAGE_VIDEO_COMMUNICATION = 17,
} OH_AudioStream_Usage;

/**
 * @brief Define the audio latency mode.
 *
 * @since 10
 */
typedef enum {
    /**
     * This is a normal audio scene.
     *
     * @since 10
     */
    AUDIOSTREAM_LATENCY_MODE_NORMAL = 0,
    /**
     * This is a low latency audio scene.
     *
     * @since 10
     */
    AUDIOSTREAM_LATENCY_MODE_FAST = 1
} OH_AudioStream_LatencyMode;

/**
 * @brief Define the audio event.
 *
 * @since 10
 */
typedef enum {
    /**
     * The routing of the audio has changed.
     *
     * @since 10
     */
    AUDIOSTREAM_EVENT_ROUTING_CHANGED = 0
} OH_AudioStream_Event;

/**
 * @brief The audio stream states
 *
 * @since 10
 */
typedef enum {
    /**
     * The invalid state.
     *
     * @since 10
     */
    AUDIOSTREAM_STATE_INVALID = -1,
    /**
     * Create new instance state.
     *
     * @since 10
     */
    AUDIOSTREAM_STATE_NEW = 0,
    /**
     * The prepared state.
     *
     * @since 10
     */
    AUDIOSTREAM_STATE_PREPARED = 1,
    /**
     * The stream is running.
     *
     * @since 10
     */
    AUDIOSTREAM_STATE_RUNNING = 2,
    /**
     * The stream is stopped.
     *
     * @since 10
     */
    AUDIOSTREAM_STATE_STOPPED = 3,
    /**
     * The stream is released.
     *
     * @since 10
     */
    AUDIOSTREAM_STATE_RELEASED = 4,
    /**
     * The stream is paused.
     *
     * @since 10
     */
    AUDIOSTREAM_STATE_PAUSED = 5,
} OH_AudioStream_State;

/**
 * @brief Defines the audio interrupt type.
 *
 * @since 10
 */
typedef enum {
    /**
     * Force type, system change audio state.
     *
     * @since 10
     */
    AUDIOSTREAM_INTERRUPT_FORCE = 0,
    /**
     * Share type, application change audio state.
     *
     * @since 10
     */
    AUDIOSTREAM_INTERRUPT_SHARE = 1
} OH_AudioInterrupt_ForceType;

/**
 * @brief Defines the audio interrupt hint type.
 *
 * @since 10
 */
typedef enum {
    /**
     * None.
     *
     * @since 10
     */
    AUDIOSTREAM_INTERRUPT_HINT_NONE = 0,
    /**
     * Resume the stream.
     *
     * @since 10
     */
    AUDIOSTREAM_INTERRUPT_HINT_RESUME = 1,
    /**
     * Pause the stream.
     *
     * @since 10
     */
    AUDIOSTREAM_INTERRUPT_HINT_PAUSE = 2,
    /**
     * Stop the stream.
     *
     * @since 10
     */
    AUDIOSTREAM_INTERRUPT_HINT_STOP = 3,
    /**
     * Ducked the stream.
     *
     * @since 10
     */
    AUDIOSTREAM_INTERRUPT_HINT_DUCK = 4,
    /**
     * Unducked the stream.
     *
     * @since 10
     */
    AUDIOSTREAM_INTERRUPT_HINT_UNDUCK = 5
} OH_AudioInterrupt_Hint;

/**
 * @brief Defines the audio source type.
 *
 * @since 10
 */
typedef enum {
    /**
     * Invalid type.
     *
     * @since 10
     */
    AUDIOSTREAM_SOURCE_TYPE_INVALID = -1,
    /**
     * Mic source type.
     *
     * @since 10
     */
    AUDIOSTREAM_SOURCE_TYPE_MIC = 0,
    /**
     * Voice recognition source type.
     *
     * @since 10
     */
    AUDIOSTREAM_SOURCE_TYPE_VOICE_RECOGNITION = 1,
    /**
     * Playback capture source type.
     *
     * @deprecated since 12
     * @useinstead OH_AVScreenCapture in native interface.
     * @since 10
     */
    AUDIOSTREAM_SOURCE_TYPE_PLAYBACK_CAPTURE = 2,
    /**
     * Voice communication source type.
     *
     * @since 10
     */
    AUDIOSTREAM_SOURCE_TYPE_VOICE_COMMUNICATION = 7
} OH_AudioStream_SourceType;

/**
 * @brief Defines the audio interrupt mode.
 *
 * @since 12
 */
typedef enum {
    /**
     * Share mode
     */
    AUDIOSTREAM_INTERRUPT_MODE_SHARE = 0,
    /**
     * Independent mode
     */
    AUDIOSTREAM_INTERRUPT_MODE_INDEPENDENT = 1
} OH_AudioInterrupt_Mode;

/**
 * @brief Defines the audio effect mode.
 *
 * @since 12
 */
typedef enum {
    /**
     * Audio Effect Mode effect none.
     *
     * @since 12
     */
    EFFECT_NONE = 0,
    /**
     * Audio Effect Mode effect default.
     *
     * @since 12
     */
    EFFECT_DEFAULT = 1,
} OH_AudioStream_AudioEffectMode;

/**
 * @brief Declaring the audio stream builder.
 * The instance of builder is used for creating audio stream.
 *
 * @since 10
 */
typedef struct OH_AudioStreamBuilderStruct OH_AudioStreamBuilder;

/**
 * @brief Declaring the audio renderer stream.
 * The instance of renderer stream is used for playing audio data.
 *
 * @since 10
 */
typedef struct OH_AudioRendererStruct OH_AudioRenderer;

/**
 * @brief Declaring the audio capturer stream.
 * The instance of renderer stream is used for capturing audio data.
 *
 * @since 10
 */
typedef struct OH_AudioCapturerStruct OH_AudioCapturer;

/**
 * @brief Declaring the callback struct for renderer stream.
 *
 * @since 10
 */
typedef struct OH_AudioRenderer_Callbacks_Struct {
    /**
     * This function pointer will point to the callback function that
     * is used to write audio data
     *
     * @since 10
     */
    int32_t (*OH_AudioRenderer_OnWriteData)(
            OH_AudioRenderer* renderer,
            void* userData,
            void* buffer,
            int32_t length);

    /**
     * This function pointer will point to the callback function that
     * is used to handle audio renderer stream events.
     *
     * @since 10
     */
    int32_t (*OH_AudioRenderer_OnStreamEvent)(
            OH_AudioRenderer* renderer,
            void* userData,
            OH_AudioStream_Event event);

    /**
     * This function pointer will point to the callback function that
     * is used to handle audio interrupt events.
     *
     * @since 10
     */
    int32_t (*OH_AudioRenderer_OnInterruptEvent)(
            OH_AudioRenderer* renderer,
            void* userData,
            OH_AudioInterrupt_ForceType type,
            OH_AudioInterrupt_Hint hint);

    /**
     * This function pointer will point to the callback function that
     * is used to handle audio error result.
     *
     * @since 10
     */
    int32_t (*OH_AudioRenderer_OnError)(
            OH_AudioRenderer* renderer,
            void* userData,
            OH_AudioStream_Result error);
} OH_AudioRenderer_Callbacks;

/**
 * @brief Declaring the callback struct for capturer stream.
 *
 * @since 10
 */
typedef struct OH_AudioCapturer_Callbacks_Struct {
    /**
     * This function pointer will point to the callback function that
     * is used to read audio data.
     *
     * @since 10
     */
    int32_t (*OH_AudioCapturer_OnReadData)(
            OH_AudioCapturer* capturer,
            void* userData,
            void* buffer,
            int32_t length);

    /**
     * This function pointer will point to the callback function that
     * is used to handle audio capturer stream events.
     *
     * @since 10
     */
    int32_t (*OH_AudioCapturer_OnStreamEvent)(
            OH_AudioCapturer* capturer,
            void* userData,
            OH_AudioStream_Event event);

    /**
     * This function pointer will point to the callback function that
     * is used to handle audio interrupt events.
     *
     * @since 10
     */
    int32_t (*OH_AudioCapturer_OnInterruptEvent)(
            OH_AudioCapturer* capturer,
            void* userData,
            OH_AudioInterrupt_ForceType type,
            OH_AudioInterrupt_Hint hint);

    /**
     * This function pointer will point to the callback function that
     * is used to handle audio error result.
     *
     * @since 10
     */
    int32_t (*OH_AudioCapturer_OnError)(
            OH_AudioCapturer* capturer,
            void* userData,
            OH_AudioStream_Result error);
} OH_AudioCapturer_Callbacks;

/**
 * @brief Defines reason for device changes of one audio stream.
 *
 * @since 11
 */
typedef enum {
    /* Unknown. */
    REASON_UNKNOWN = 0,
    /* New Device available. */
    REASON_NEW_DEVICE_AVAILABLE = 1,
    /* Old Device unavailable. Applications should consider to pause the audio playback when this reason is
    reported. */
    REASON_OLD_DEVICE_UNAVAILABLE = 2,
    /* Device is overrode by user or system. */
    REASON_OVERRODE = 3,
} OH_AudioStream_DeviceChangeReason;

/**
 * @brief Callback when the output device of an audio renderer changed.
 *
 * @param renderer AudioRenderer where this event occurs.
 * @param userData User data which is passed by user.
 * @param reason Indicates that why does the output device changes.
 * @since 11
 */
typedef void (*OH_AudioRenderer_OutputDeviceChangeCallback)(OH_AudioRenderer* renderer, void* userData,
    OH_AudioStream_DeviceChangeReason reason);

/**
 * @brief Callback when the mark position reached.
 *
 * @param renderer AudioRenderer where this event occurs.
 * @param samplePos Mark position in samples.
 * @param userData User data which is passed by user.
 * @since 12
 */
typedef void (*OH_AudioRenderer_OnMarkReachedCallback)(OH_AudioRenderer* renderer, uint32_t samplePos, void* userData);

/**
 * @brief This function pointer will point to the callback function that
 * is used to write audio data with metadata
 *
 * @param renderer AudioRenderer where this event occurs.
 * @param userData User data which is passed by user.
 * @param audioData Audio data which is written by user.
 * @param audioDataSize Audio data size which is the size of audio data written by user.
 * @param metadata Metadata which is written by user.
 * @param metadataSize Metadata size which is the size of metadata written by user.
 * @return Error code of the callback function returned by user.
 * @since 12
 */
typedef int32_t (*OH_AudioRenderer_WriteDataWithMetadataCallback)(OH_AudioRenderer* renderer,
    void* userData, void* audioData, int32_t audioDataSize, void* metadata, int32_t metadataSize);

/**
 * @brief Defines Enumeration of audio stream privacy type for playback capture.
 *
 * @since 12
 */
typedef enum {
    /** Privacy type that stream can be captured by third party applications.
     * @since 12
     */
    AUDIO_STREAM_PRIVACY_TYPE_PUBLIC = 0,
    /** Privacy type that stream can not be captured.
     * @since 12
     */
    AUDIO_STREAM_PRIVACY_TYPE_PRIVATE = 1,
} OH_AudioStream_PrivacyType;

/**
 * @brief Defines enumeration of audio data callback result.
 *
 * @since 12
 */
typedef enum {
    /** Result of audio data callabck is invalid. */
    AUDIO_DATA_CALLBACK_RESULT_INVALID = -1,
    /** Result of audio data callabck is valid. */
    AUDIO_DATA_CALLBACK_RESULT_VALID = 0,
} OH_AudioData_Callback_Result;

/**
 * @brief Callback function of  write data.
 *
 * This function is similar with OH_AudioRenderer_Callbacks_Struct.OH_AudioRenderer_OnWriteData instead of the return
 * value. The return result of this function indicates whether the data filled in the buffer is valid or invalid. If
 * result is invalid, the data filled by user will not be played.
 *
 * @param renderer AudioRenderer where this callback occurs.
 * @param userData User data which is passed by user.
 * @param audioData Audio data pointer, where user should fill in audio data.
 * @param audioDataSize Size of audio data that user should fill in.
 * @return Audio Data callback result.
 * @see OH_AudioRenderer_Callbacks_Struct.OH_AudioRenderer_OnWriteData
 * @since 12
 */
typedef OH_AudioData_Callback_Result (*OH_AudioRenderer_OnWriteDataCallback)(OH_AudioRenderer* renderer, void* userData,
    void* audioData, int32_t audioDataSize);
#ifdef __cplusplus
}
#endif

#endif // NATIVE_AUDIOSTREAM_BASE_H