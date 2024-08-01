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

#ifndef NATIVE_AVDEMUXER_H
#define NATIVE_AVDEMUXER_H

#include <stdint.h>
#include "native_avcodec_base.h"
#include "native_avsource.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OH_AVDemuxer OH_AVDemuxer;
typedef struct DRM_MediaKeySystemInfo DRM_MediaKeySystemInfo;
typedef void (*DRM_MediaKeySystemInfoCallback)(DRM_MediaKeySystemInfo* mediaKeySystemInfo);

/**
 * @brief Call back will be invoked when updating DRM information.
 * @param demuxer Player OH_AVDemuxer.
 * @param mediaKeySystemInfo DRM information.
 * @return DRM_ERR_INVALID_VAL when the params checked failure, return DRM_ERR_OK when function called successfully.
 * @since 12
 * @version 1.0
 */
typedef void (*Demuxer_MediaKeySystemInfoCallback)(OH_AVDemuxer *demuxer, DRM_MediaKeySystemInfo *mediaKeySystemInfo);

/**
 * @brief Creates an OH_AVDemuxer instance for getting samples from source.
 * Free the resources of the instance by calling OH_AVDemuxer_Destroy.
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param source Pointer to an OH_AVSource instance.
 * @return Returns a pointer to an OH_AVDemuxer instance if the execution is successful, otherwise returns nullptr.
 * Possible failure causes:
 *  1. source is invalid.
 * @since 10
*/
OH_AVDemuxer *OH_AVDemuxer_CreateWithSource(OH_AVSource *source);

/**
 * @brief Destroy the OH_AVDemuxer instance and free the internal resources.
 * The same instance can only be destroyed once. The destroyed instance
 * should not be used before it is created again. It is recommended setting
 * the instance pointer to NULL right after the instance is destroyed successfully.
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param demuxer Pointer to an OH_AVDemuxer instance.
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 *          {@link AV_ERR_INVALID_VAL} demuxer is invalid.
 * @since 10
*/
OH_AVErrCode OH_AVDemuxer_Destroy(OH_AVDemuxer *demuxer);

/**
 * @brief The specified track is selected and the demuxer will read samples from
 * this track. Multiple tracks are selected by calling this interface multiple times
 * with different track indexes. Only the selected tracks are valid when calling
 * OH_AVDemuxer_ReadSample to read samples. The interface returns AV_ERR_OK and the
 * track is selected only once if the same track is selected multiple times.
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param demuxer Pointer to an OH_AVDemuxer instance.
 * @param trackIndex The index of the selected track.
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 *          {@link AV_ERR_INVALID_VAL} demuxer is invalid, demuxer is not properly initialized,
 *                                     trackIndex is out of range, track is not supported to be read.
 * @since 10
*/
OH_AVErrCode OH_AVDemuxer_SelectTrackByID(OH_AVDemuxer *demuxer, uint32_t trackIndex);

/**
 * @brief The specified selected track is unselected. The unselected track's sample
 * can not be read from demuxer. Multiple selected tracks are unselected by calling
 * this interface multiple times with different track indexes. The interface returns
 * AV_ERR_OK and the track is unselected only once if the same track is unselected
 * multiple times.
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param demuxer Pointer to an OH_AVDemuxer instance.
 * @param trackIndex The index of the unselected track.
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 *          {@link AV_ERR_INVALID_VAL} demuxer is invalid, demuxer is not properly initialized.
 * @since 10
*/
OH_AVErrCode OH_AVDemuxer_UnselectTrackByID(OH_AVDemuxer *demuxer, uint32_t trackIndex);

/**
 * @brief Get the current encoded sample and sample-related information from the specified
 * track. The track index must be selected before reading sample. The demuxer will advance
 * automatically after calling this interface.
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param demuxer Pointer to an OH_AVDemuxer instance.
 * @param trackIndex The index of the track from which read an encoded sample.
 * @param sample The OH_AVMemory handle pointer to the buffer storing the sample data.
 * @param info The OH_AVCodecBufferAttr handle pointer to the buffer storing sample information.
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 *          {@link AV_ERR_INVALID_VAL} demuxer is invalid, demuxer is not properly initialized, sample is invalid,
 *                                     trackIndex is out of range.
 *          {@link AV_ERR_OPERATE_NOT_PERMIT} trackIndex has not been selected.
 *          {@link AV_ERR_NO_MEMORY} capability of sample is not enough to store all frame data.
 *          {@link AV_ERR_UNKNOWN} failed to read or parse frame from file.
 * @deprecated since 11
 * @useinstead OH_AVDemuxer_ReadSampleBuffer
 * @since 10
*/
OH_AVErrCode OH_AVDemuxer_ReadSample(OH_AVDemuxer *demuxer, uint32_t trackIndex,
    OH_AVMemory *sample, OH_AVCodecBufferAttr *info);

/**
 * @brief Get the current encoded sample and sample-related information from the specified
 * track. The track index must be selected before reading sample. The demuxer will advance
 * automatically after calling this interface.
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param demuxer Pointer to an OH_AVDemuxer instance.
 * @param trackIndex The index of the track from which read an encoded sample.
 * @param sample The OH_AVBuffer handle pointer to the buffer storing the sample data and corresponding attribute.
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 *          {@link AV_ERR_INVALID_VAL} demuxer is invalid, demuxer is not properly initialized, sample is invalid,
 *                                     trackIndex is out of range.
 *          {@link AV_ERR_OPERATE_NOT_PERMIT} trackIndex has not been selected.
 *          {@link AV_ERR_NO_MEMORY} capability of sample is not enough to store frame data.
 *          {@link AV_ERR_UNKNOWN} failed to read or parse frame from file.
 * @since 11
*/
OH_AVErrCode OH_AVDemuxer_ReadSampleBuffer(OH_AVDemuxer *demuxer, uint32_t trackIndex,
    OH_AVBuffer *sample);

/**
 * @brief All selected tracks seek near to the requested time according to the seek mode.
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param demuxer Pointer to an OH_AVDemuxer instance.
 * @param millisecond The millisecond for seeking, the timestamp is the position of
 * the file relative to the start of the file.
 * @param mode The mode for seeking. See {@link OH_AVSeekMode}.
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 *          {@link AV_ERR_INVALID_VAL} demuxer is invalid, demuxer is not properly initialized,
 *                                     millisecond is out of range.
 *          {@link AV_ERR_OPERATE_NOT_PERMIT} trackIndex has not been selected, resource is unseekable.
 *          {@link AV_ERR_UNKNOWN} failed to seek.
 * @since 10
*/
OH_AVErrCode OH_AVDemuxer_SeekToTime(OH_AVDemuxer *demuxer, int64_t millisecond, OH_AVSeekMode mode);

/**
 * @brief Method to set player media key system info callback.
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param demuxer Pointer to an OH_AVDemuxer instance
 * @param callback object pointer.
 * @return {@link AV_ERR_OK} 0 - Success
 *         {@link AV_ERR_OPERATE_NOT_PERMIT} 2 - If the demuxer engine is not inited or init failed.
 *         {@link AV_ERR_INVALID_VAL} 3 - If the demuxer instance is nullptr or invalid.
 * @since 11
 * @version 1.0
 */
OH_AVErrCode OH_AVDemuxer_SetMediaKeySystemInfoCallback(OH_AVDemuxer *demuxer,
    DRM_MediaKeySystemInfoCallback callback);

/**
 * @brief Method to set player media key system info callback.
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param demuxer Pointer to an OH_AVDemuxer instance
 * @param callback object pointer.
 * @return {@link AV_ERR_OK} 0 - Success
 *         {@link AV_ERR_OPERATE_NOT_PERMIT} 2 - If the demuxer engine is not inited or init failed.
 *         {@link AV_ERR_INVALID_VAL} 3 - If the demuxer instance is nullptr or invalid.
 * @since 12
 * @version 1.0
 */
OH_AVErrCode OH_AVDemuxer_SetDemuxerMediaKeySystemInfoCallback(OH_AVDemuxer *demuxer,
    Demuxer_MediaKeySystemInfoCallback callback);

/**
 * @brief Obtains media key system info to create media key session.
 * @syscap SystemCapability.Multimedia.Media.Spliter
 * @param demuxer Pointer to an OH_AVDemuxer instance
 * @param mediaKeySystemInfo Indicates the media key system info which ram space allocated by callee and
 * released by caller.
 * @return {@link AV_ERR_OK} 0 - Success
 *         {@link AV_ERR_INVALID_VAL} 3 - If the demuxer instance is nullptr or invalid
 *          or the mediaKeySystemInfo is nullptr.
 * @since 11
 * @version 1.0
 */
OH_AVErrCode OH_AVDemuxer_GetMediaKeySystemInfo(OH_AVDemuxer *demuxer, DRM_MediaKeySystemInfo *mediaKeySystemInfo);

#ifdef __cplusplus
}
#endif

#endif // NATIVE_AVDEMUXER_H