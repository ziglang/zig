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

#ifndef NATIVE_AVMUXER_H
#define NATIVE_AVMUXER_H

#include <stdint.h>
#include <stdio.h>
#include "native_avcodec_base.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OH_AVMuxer OH_AVMuxer;

/**
 * @brief Create an OH_AVMuxer instance by output file description and format.
 * @syscap SystemCapability.Multimedia.Media.Muxer
 * @param fd Must be opened with read and write permission. Caller is responsible for closing fd.
 * @param format The output format is {@link OH_AVOutputFormat} .
 * @return Returns a pointer to an OH_AVMuxer instance, needs to be freed by OH_AVMuxer_Destroy.
 * @since 10
 */
OH_AVMuxer *OH_AVMuxer_Create(int32_t fd, OH_AVOutputFormat format);

/**
 * @brief Set the rotation for output video playback.
 * Note: This interface can only be called before OH_AVMuxer_Start.
 * @syscap SystemCapability.Multimedia.Media.Muxer
 * @param muxer Pointer to an OH_AVMuxer instance.
 * @param rotation The supported angles are 0, 90, 180, and 270 degrees.
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the muxer or rotation invalid.
 * {@link AV_ERR_OPERATE_NOT_PERMIT}, not permit to call the interface, it was called in invalid state.
 * @since 10
 */
OH_AVErrCode OH_AVMuxer_SetRotation(OH_AVMuxer *muxer, int32_t rotation);

/**
 * @brief Add track format to the muxer.
 * Note: This interface can only be called before OH_AVMuxer_Start.
 * @syscap SystemCapability.Multimedia.Media.Muxer
 * @param muxer Pointer to an OH_AVMuxer instance
 * @param trackIndex The int32_t handle pointer used to get the track index for this newly added track,
 * and it should be used in the OH_AVMuxer_WriteSample. The track index is greater than or equal to 0,
 * others is error index.
 * @param trackFormat OH_AVFormat handle pointer contain track format
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the muxer or trackIndex or trackFormat invalid.
 * {@link AV_ERR_OPERATE_NOT_PERMIT}, not permit to call the interface, it was called in invalid state.
 * {@link AV_ERR_UNSUPPORT}, the mime type is not supported.
 * {@link AV_ERR_NO_MEMORY}, failed to malloc memory.
 * {@link AV_ERR_UNKNOWN}, unknown error.
 * @since 10
 */
OH_AVErrCode OH_AVMuxer_AddTrack(OH_AVMuxer *muxer, int32_t *trackIndex, OH_AVFormat *trackFormat);

/**
 * @brief Start the muxer.
 * Note: This interface is called after OH_AVMuxer_AddTrack and before OH_AVMuxer_WriteSample.
 * @syscap SystemCapability.Multimedia.Media.Muxer
 * @param muxer Pointer to an OH_AVMuxer instance
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the muxer invalid.
 * {@link AV_ERR_OPERATE_NOT_PERMIT}, not permit to call the interface, it was called in invalid state.
 * {@link AV_ERR_UNKNOWN}, unknown error.
 * @since 10
 */
OH_AVErrCode OH_AVMuxer_Start(OH_AVMuxer *muxer);

/**
 * @brief Write an encoded sample to the muxer.
 * Note: This interface can only be called after OH_AVMuxer_Start and before OH_AVMuxer_Stop. The application needs to
 * make sure that the samples are written to the right tacks. Also, it needs to make sure the samples for each track are
 * written in chronological order.
 * @syscap SystemCapability.Multimedia.Media.Muxer
 * @param muxer Pointer to an OH_AVMuxer instance
 * @param trackIndex The track index for this sample
 * @param sample The encoded or demuxer sample
 * @param info The buffer information related to this sample {@link OH_AVCodecBufferAttr}
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the muxer or trackIndex or sample or info invalid.
 * {@link AV_ERR_OPERATE_NOT_PERMIT}, not permit to call the interface, it was called in invalid state.
 * {@link AV_ERR_NO_MEMORY}, failed to request memory.
 * {@link AV_ERR_UNKNOWN}, unknown error.
 * @deprecated since 11
 * @useinstead OH_AVMuxer_WriteSampleBuffer
 * @since 10
 */
OH_AVErrCode OH_AVMuxer_WriteSample(OH_AVMuxer *muxer, uint32_t trackIndex,
    OH_AVMemory *sample, OH_AVCodecBufferAttr info);

/**
 * @brief Write an encoded sample to the muxer.
 * Note: This interface can only be called after OH_AVMuxer_Start and before OH_AVMuxer_Stop. The application needs to
 * make sure that the samples are written to the right tracks. Also, it needs to make sure the samples for each track
 * are written in chronological order.
 * @syscap SystemCapability.Multimedia.Media.Muxer
 * @param muxer Pointer to an OH_AVMuxer instance
 * @param trackIndex The track index for this sample
 * @param sample The encoded or demuxer sample, which including data and buffer information
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the muxer or trackIndex or sample invalid.
 * {@link AV_ERR_OPERATE_NOT_PERMIT}, not permit to call the interface, it was called in invalid state.
 * {@link AV_ERR_NO_MEMORY}, failed to request memory.
 * {@link AV_ERR_UNKNOWN}, unknown error.
 * @since 11
 */
OH_AVErrCode OH_AVMuxer_WriteSampleBuffer(OH_AVMuxer *muxer, uint32_t trackIndex,
    const OH_AVBuffer *sample);

/**
 * @brief Stop the muxer.
 * Note: Once the muxer stops, it can not be restarted.
 * @syscap SystemCapability.Multimedia.Media.Muxer
 * @param muxer Pointer to an OH_AVMuxer instance
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the muxer invalid.
 * {@link AV_ERR_OPERATE_NOT_PERMIT}, not permit to call the interface, it was called in invalid state.
 * @since 10
 */
OH_AVErrCode OH_AVMuxer_Stop(OH_AVMuxer *muxer);

/**
 * @brief Clear the internal resources of the muxer and destroy the muxer instance
 * @syscap SystemCapability.Multimedia.Media.Muxer
 * @param muxer Pointer to an OH_AVMuxer instance
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the muxer invalid.
 * @since 10
 */
OH_AVErrCode OH_AVMuxer_Destroy(OH_AVMuxer *muxer);

#ifdef __cplusplus
}
#endif

#endif // NATIVE_AVMUXER_H