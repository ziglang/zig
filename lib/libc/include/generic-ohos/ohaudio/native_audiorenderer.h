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
 * @file native_audiorenderer.h
 *
 * @brief Declare audio stream related interfaces for output type.
 *
 * @syscap SystemCapability.Multimedia.Audio.Core
 * @since 10
 * @version 1.0
 */

#ifndef NATIVE_AUDIORENDERER_H
#define NATIVE_AUDIORENDERER_H

#include <time.h>
#include "native_audiostream_base.h"
#include "multimedia/native_audio_channel_layout.h"
#ifdef __cplusplus
extern "C" {
#endif
/*
 * Request to release the renderer stream.
 *
 * @since 10
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 */
OH_AudioStream_Result OH_AudioRenderer_Release(OH_AudioRenderer* renderer);

/*
 * Request to start the renderer stream.
 *
 * @since 10
 *
 * @param renderer reference created by OH_AudioStreamBuilder
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 */
OH_AudioStream_Result OH_AudioRenderer_Start(OH_AudioRenderer* renderer);

/*
 * Request to pause the renderer stream.
 *
 * @since 10
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 */
OH_AudioStream_Result OH_AudioRenderer_Pause(OH_AudioRenderer* renderer);

/*
 * Request to stop renderer stream.
 *
 * @since 10
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 */
OH_AudioStream_Result OH_AudioRenderer_Stop(OH_AudioRenderer* renderer);

/*
 * Request to flush the renderer stream.
 *
 * @since 10
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 */
OH_AudioStream_Result OH_AudioRenderer_Flush(OH_AudioRenderer* renderer);

/*
 * Query the current state of the renderer client.
 *
 * This function will return the renderer state without updating the state.
 *
 * @since 10
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param state Pointer to a variable that will be set for the state value.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetCurrentState(OH_AudioRenderer* renderer,
    OH_AudioStream_State* state);

/*
 * Query the sample rate value of the renderer client
 *
 * This function will return the renderer sample rate value without updating the state.
 *
 * @since 10
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param rate The state value to be updated
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetSamplingRate(OH_AudioRenderer* renderer, int32_t* rate);

/*
 * Query the stream id of the renderer client.
 *
 * @since 10
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param stramId Pointer to a variable that will be set for the stream id.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetStreamId(OH_AudioRenderer* renderer, uint32_t* streamId);

/*
 * Query the channel count of the renderer client.
 *
 * @since 10
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param channelCount Pointer to a variable that will be set for the channel count.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetChannelCount(OH_AudioRenderer* renderer, int32_t* channelCount);

/*
 * Query the sample format of the renderer client.
 *
 * @since 10
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param sampleFormat Pointer to a variable that will be set for the sample format.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetSampleFormat(OH_AudioRenderer* renderer,
    OH_AudioStream_SampleFormat* sampleFormat);

/*
 * Query the latency mode of the renderer client.
 *
 * @since 10
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param latencyMode Pointer to a variable that will be set for the latency mode.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetLatencyMode(OH_AudioRenderer* renderer,
    OH_AudioStream_LatencyMode* latencyMode);
/*
 * Query the renderer info of the renderer client.
 *
 * The rendere info includes {@link OH_AudioStream_Usage} value.
 *
 * @since 10
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param usage Pointer to a variable that will be set for the stream usage.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetRendererInfo(OH_AudioRenderer* renderer,
    OH_AudioStream_Usage* usage);

/*
 * Query the encoding type of the renderer client.
 *
 * @since 10
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param encodingType Pointer to a variable that will be set for the encoding type.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetEncodingType(OH_AudioRenderer* renderer,
    OH_AudioStream_EncodingType* encodingType);

/*
 * Query the the number of frames that have been written since the stream was created.
 *
 * @since 10
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param frames Pointer to a variable that will be set for the frame count number.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetFramesWritten(OH_AudioRenderer* renderer, int64_t* frames);

/*
 * Query the the time at which a particular frame was presented.
 *
 * @since 10
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param clockId {@link #CLOCK_MONOTONIC}
 * @param framePosition Pointer to a variable to receive the position
 * @param timestamp Pointer to a variable to receive the timestamp
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM}:
 *                                                 1.The param of renderer is nullptr;
 *                                                 2.The param of clockId invalid.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 */
OH_AudioStream_Result OH_AudioRenderer_GetTimestamp(OH_AudioRenderer* renderer,
    clockid_t clockId, int64_t* framePosition, int64_t* timestamp);

/*
 * Query the frame size in callback, it is a fixed length that the stream want to be filled for each callback.
 *
 * @since 10
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param frameSize Pointer to a variable that will be set for the frame size.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetFrameSizeInCallback(OH_AudioRenderer* renderer, int32_t* frameSize);

/*
 * Query the playback speed of the stream client
 *
 * @since 11
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param speed Pointer to a variable to receive the playback speed.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetSpeed(OH_AudioRenderer* renderer, float* speed);


/*
 * Set the playback speed of the stream client
 *
 * @since 11
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param speed The playback speed, form 0.25 to 4.0.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_SetSpeed(OH_AudioRenderer* renderer, float speed);

/**
 * Set volume of current renderer.
 *
 * @since 12
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param volume Volume to set which changes from 0.0 to 1.0.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM}:
 *                                                 1.The param of renderer is nullptr;
 *                                                 2.The param of volume invalid.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 *         {@link AUDIOSTREAM_ERROR_SYSTEM} An system error has occurred.
 */
OH_AudioStream_Result OH_AudioRenderer_SetVolume(OH_AudioRenderer* renderer, float volume);

/**
 * Changes the volume with ramp for a duration.
 *
 * @since 12
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param volume Volume to set which changes from 0.0 to 1.0.
 * @param durationMs Duration for volume ramp, in millisecond.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM}:
 *                                                 1.The param of renderer is nullptr;
 *                                                 2.The param of volume invalid.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 *         {@link AUDIOSTREAM_ERROR_SYSTEM} An system error has occurred.
 */
OH_AudioStream_Result OH_AudioRenderer_SetVolumeWithRamp(OH_AudioRenderer* renderer, float volume, int32_t durationMs);

/**
 * Get Volume of current renderer.
 *
 * @since 12
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param volume Pointer to a variable to receive the volume.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM}:
 *                                                 1.The param of renderer is nullptr;
 *                                                 2.The param of volume is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetVolume(OH_AudioRenderer* renderer, float* volume);

/**
 * @brief Set mark position on current renderer. Calling this function will overwrite the mark postion which has already
 * set.
 *
 * @since 12
 *
 * @param renderer Renderer generated by OH_AudioStreamBuilder_GenerateRenderer()
 * @param samplePos Mark position in samples.
 * @param callback Callback used when the samplePos has reached.
 * @param userData User data which is passed by user.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM}:
 *                                                 1.The param of renderer is nullptr;
 *                                                 2.The param of samplePos invalid.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 *         {@link AUDIOSTREAM_ERROR_SYSTEM} An system error has occurred.
 */
OH_AudioStream_Result OH_AudioRenderer_SetMarkPosition(OH_AudioRenderer* renderer, uint32_t samplePos,
    OH_AudioRenderer_OnMarkReachedCallback callback, void* userData);

/**
 * @brief Cancel mark which has set by {@link #OH_AudioRenderer_SetMarkPosition}.
 *
 * @since 12
 *
 * @param renderer Renderer generated by OH_AudioStreamBuilder_GenerateRenderer()
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_CancelMark(OH_AudioRenderer* renderer);

/**
 * @brief Gets the underflow count on this stream.
 *
 * @since 12
 *
 * @param renderer Renderer generated by OH_AudioStreamBuilder_GenerateRenderer()
 * @param count Pointer to a variable to receive the underflow count number.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM}:
 *                                                 1.The param of renderer is nullptr;
 *                                                 2.The param of count is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetUnderflowCount(OH_AudioRenderer* renderer, uint32_t* count);

/**
 * @brief Query the channel layout of the renderer client.
 *
 * @since 12
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param channelLayout Pointer to a variable to receive the channel layout
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetChannelLayout(OH_AudioRenderer* renderer,
    OH_AudioChannelLayout* channelLayout);

/**
 * @brief Query current audio effect mode.
 *
 * @since 12
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param effectMode Pointer to a variable to receive current audio effect mode
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetEffectMode(OH_AudioRenderer* renderer,
    OH_AudioStream_AudioEffectMode* effectMode);

/**
 * @brief Set current audio effect mode.
 *
 * @since 12
 *
 * @param renderer Reference created by OH_AudioStreamBuilder_GenerateRenderer()
 * @param effectMode Audio effect mode that will be set for the stream
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_SetEffectMode(OH_AudioRenderer* renderer,
    OH_AudioStream_AudioEffectMode effectMode);

/**
 * @brief Get the privacy of this stream.
 *
 * @since 12
 *
 * @param renderer Renderer generated by OH_AudioStreamBuilder_GenerateRenderer()
 * @param privacy Pointer to a variable which receives the results.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of renderer is nullptr.
 */
OH_AudioStream_Result OH_AudioRenderer_GetRendererPrivacy(OH_AudioRenderer* renderer,
    OH_AudioStream_PrivacyType* privacy);
#ifdef __cplusplus
}
#endif
#endif // NATIVE_AUDIORENDERER_H