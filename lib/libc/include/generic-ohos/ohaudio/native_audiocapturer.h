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
 * @file native_audiocapturer.h
 *
 * @brief Declare audio stream related interfaces for input type.
 *
 * @syscap SystemCapability.Multimedia.Audio.Core
 * @since 10
 * @version 1.0
 */

#ifndef NATIVE_AUDIOCAPTURER_H
#define NATIVE_AUDIOCAPTURER_H

#include <time.h>
#include "native_audiostream_base.h"
#ifdef __cplusplus
extern "C" {
#endif
/*
 * Request to release the capturer stream.
 *
 * @since 10
 * @permission ohos.permission.MICROPHONE
 *
 * @param capturer reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 */
OH_AudioStream_Result OH_AudioCapturer_Release(OH_AudioCapturer* capturer);

/*
 * Request to start the capturer stream.
 *
 * @since 10
 * @permission ohos.permission.MICROPHONE
 *
 * @param capturer reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 */
OH_AudioStream_Result OH_AudioCapturer_Start(OH_AudioCapturer* capturer);

/*
 * Request to pause the capturer stream.
 *
 * @since 10
 * @permission ohos.permission.MICROPHONE
 *
 * @param capturer reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 */
OH_AudioStream_Result OH_AudioCapturer_Pause(OH_AudioCapturer* capturer);

/*
 * Request to stop the capturer stream.
 *
 * @since 10
 * @permission ohos.permission.MICROPHONE
 *
 * @param capturer reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 */
OH_AudioStream_Result OH_AudioCapturer_Stop(OH_AudioCapturer* capturer);

/*
 * Request to flush the capturer stream.
 *
 * @since 10
 *
 * @param capturer reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 */
OH_AudioStream_Result OH_AudioCapturer_Flush(OH_AudioCapturer* capturer);

/*
 * Query the current state of the capturer client.
 *
 * This function will return the capturer state without updating the state.
 *
 * @since 10
 *
 * @param capturer Reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @param state Pointer to a variable that will be set for the state value.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 */
OH_AudioStream_Result OH_AudioCapturer_GetCurrentState(OH_AudioCapturer* capturer, OH_AudioStream_State* state);

/*
 * Query the latency mode of the capturer client.
 *
 * @since 10
 *
 * @param capturer Reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @param latencyMode Pointer to a variable that will be set for the latency mode.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 */
OH_AudioStream_Result OH_AudioCapturer_GetLatencyMode(OH_AudioCapturer* capturer,
    OH_AudioStream_LatencyMode* latencyMode);

/*
 * Query the stream id of the capturer client.
 *
 * @since 10
 *
 * @param capturer Reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @param stramId Pointer to a variable that will be set for the stream id.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 */
OH_AudioStream_Result OH_AudioCapturer_GetStreamId(OH_AudioCapturer* capturer, uint32_t* streamId);

/*
 * Query the sample rate value of the capturer client.
 *
 * This function will return the capturer sample rate value without updating the state.
 *
 * @since 10
 *
 * @param capturer Reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @param rate The state value to be updated
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 */
OH_AudioStream_Result OH_AudioCapturer_GetSamplingRate(OH_AudioCapturer* capturer, int32_t* rate);

/*
 * Query the channel count of the capturer client.
 *
 * @since 10
 *
 * @param capturer Reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @param channelCount Pointer to a variable that will be set for the channel count.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 */
OH_AudioStream_Result OH_AudioCapturer_GetChannelCount(OH_AudioCapturer* capturer, int32_t* channelCount);

/*
 * Query the sample format of the capturer client.
 *
 * @since 10
 *
 * @param capturer Reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @param sampleFormat Pointer to a variable that will be set for the sample format.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 */
OH_AudioStream_Result OH_AudioCapturer_GetSampleFormat(OH_AudioCapturer* capturer,
    OH_AudioStream_SampleFormat* sampleFormat);

/*
 * Query the encoding type of the capturer client.
 *
 * @since 10
 *
 * @param capturer Reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @param encodingType Pointer to a variable that will be set for the encoding type.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 */
OH_AudioStream_Result OH_AudioCapturer_GetEncodingType(OH_AudioCapturer* capturer,
    OH_AudioStream_EncodingType* encodingType);

/*
 * Query the capturer info of the capturer client.
 *
 * @since 10
 *
 * @param capturer Reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @param sourceType Pointer to a variable that will be set for the stream sourceType.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 */
OH_AudioStream_Result OH_AudioCapturer_GetCapturerInfo(OH_AudioCapturer* capturer,
    OH_AudioStream_SourceType* sourceType);

/*
 * Query the frame size in callback, it is a fixed length of the buffer returned by each callback.
 *
 * @since 10
 *
 * @param capturer Reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @param frameSize Pointer to a variable that will be set for the frame size.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 */
OH_AudioStream_Result OH_AudioCapturer_GetFrameSizeInCallback(OH_AudioCapturer* capturer, int32_t* frameSize);

/*
 * Query the the time at which a particular frame was presented
 *
 * @since 10
 *
 * @param capturer Reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @param clockId {@link #CLOCK_MONOTONIC}
 * @param framePosition Pointer to a variable to receive the position
 * @param timestamp Pointer to a variable to receive the timestamp
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM}:
 *                                                 1.The param of capturer is nullptr;
 *                                                 2.The param of clockId invalid.
 *         {@link AUDIOSTREAM_ERROR_ILLEGAL_STATE} Execution status exception.
 */
OH_AudioStream_Result OH_AudioCapturer_GetTimestamp(OH_AudioCapturer* capturer,
    clockid_t clockId, int64_t* framePosition, int64_t* timestamp);

/*
 * Query the the number of frames that have been read since the stream was created.
 *
 * @since 10
 *
 * @param capturer Reference created by OH_AudioStreamBuilder_GenerateCapturer()
 * @param frames Pointer to a variable that will be set for the frame count number.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 */
OH_AudioStream_Result OH_AudioCapturer_GetFramesRead(OH_AudioCapturer* capturer, int64_t* frames);

/**
 * @brief Gets the overflow count on this stream.
 *
 * @since 12
 *
 * @param capturer Capturer generated by OH_AudioStreamBuilder_GenerateCapturer()
 * @param count Pointer to a variable that will be set for the overflow count number.
 * @return Function result code:
 *         {@link AUDIOSTREAM_SUCCESS} If the execution is successful.
 *         {@link AUDIOSTREAM_ERROR_INVALID_PARAM} The param of capturer is nullptr.
 */
OH_AudioStream_Result OH_AudioCapturer_GetOverflowCount(OH_AudioCapturer* capturer, uint32_t* count);

#ifdef __cplusplus
}
#endif
#endif // NATIVE_AUDIOCAPTURER_H