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

#ifndef NATIVE_AVCAPABILITY_H
#define NATIVE_AVCAPABILITY_H

#include <stdint.h>
#include "native_averrors.h"
#include "native_avformat.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OH_AVCapability OH_AVCapability;

/**
 * @brief The bitrate mode of encoder.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 10
 */
typedef enum OH_BitrateMode {
    /* Constant Bit rate mode. */
    BITRATE_MODE_CBR = 0,
    /* Variable Bit rate mode. */
    BITRATE_MODE_VBR = 1,
    /* Constant Quality mode. */
    BITRATE_MODE_CQ = 2
} OH_BitrateMode;

/**
 * @brief Range contain min and max value
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 10
 */
typedef struct OH_AVRange {
    int32_t minVal;
    int32_t maxVal;
} OH_AVRange;

/**
 * @brief The codec category
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 10
 */
typedef enum OH_AVCodecCategory {
    HARDWARE = 0,
    SOFTWARE
} OH_AVCodecCategory;

/**
 * @brief The enum of optional features that can be used in specific codec seenarios.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
typedef enum OH_AVCapabilityFeature {
    /** Feature for codec supports temporal scalability. It is only used in video encoder. */
    VIDEO_ENCODER_TEMPORAL_SCALABILITY = 0,
    /** Feature for codec supports long-term reference. It is only used in video encoder. */
    VIDEO_ENCODER_LONG_TERM_REFERENCE = 1,
    /** Feature for codec supports low latency. It is used in video encoder and video decoder. */
    VIDEO_LOW_LATENCY = 2,
} OH_AVCapabilityFeature;

/**
 * @brief Get a system-recommended codec's capability.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param mime Mime type
 * @param isEncoder True for encoder, false for decoder
 * @return Returns a capability instance if an existing codec matches,
 * if the specified mime type doesn't match any existing codec, returns NULL.
 * @since 10
 */
OH_AVCapability *OH_AVCodec_GetCapability(const char *mime, bool isEncoder);

/**
 * @brief Get a codec's capability within the specified category. By specifying the category,
 * the matched codec is limited to either hardware codecs or software codecs.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param mime Mime type
 * @param isEncoder True for encoder, false for decoder
 * @param category The codec category
 * @return Returns a capability instance if an existing codec matches,
 * if the specified mime type doesn't match any existing codec, returns NULL
 * @since 10
 */
OH_AVCapability *OH_AVCodec_GetCapabilityByCategory(const char *mime, bool isEncoder, OH_AVCodecCategory category);

/**
 * @brief Check if the capability instance is describing a hardware codec.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Codec capability pointer
 * @return Returns true if the capability instance is describing a hardware codec,
 * false if the capability instance is describing a software codec
 * @since 10
 */
bool OH_AVCapability_IsHardware(OH_AVCapability *capability);

/**
 * @brief Get the codec name.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Codec capability pointer
 * @return Returns codec name string
 * @since 10
 */
const char *OH_AVCapability_GetName(OH_AVCapability *capability);

/**
 * @brief Get the supported max instance number of the codec.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Codec capability pointer
 * @return Returns the max supported codec instance number
 * @since 10
 */
int32_t OH_AVCapability_GetMaxSupportedInstances(OH_AVCapability *capability);

/**
 * @brief Get the encoder's supported bitrate range.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Encoder capability pointer. Do not give a decoder capability pointer
 * @param bitrateRange Output parameter. Encoder bitrate range
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, or the bitrateRange is nullptr.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetEncoderBitrateRange(OH_AVCapability *capability, OH_AVRange *bitrateRange);

/**
 * @brief Check if the encoder supports the specific bitrate mode.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Encoder capability pointer. Do not give a decoder capability pointer
 * @param bitrateMode Bitrate mode
 * @return Returns true if the bitrate mode is supported, false if the bitrate mode is not supported
 * @since 10
 */
bool OH_AVCapability_IsEncoderBitrateModeSupported(OH_AVCapability *capability, OH_BitrateMode bitrateMode);

/**
 * @brief Get the encoder's supported quality range.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Encoder capability pointer. Do not give a decoder capability pointer
 * @param qualityRange Output parameter. Encoder quality range
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, or the qualityRange is nullptr.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetEncoderQualityRange(OH_AVCapability *capability, OH_AVRange *qualityRange);

/**
 * @brief Get the encoder's supported encoder complexity range.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Encoder capability pointer. Do not give a decoder capability pointer
 * @param complexityRange Output parameter. Encoder complexity range
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, or the complexityRange is nullptr.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetEncoderComplexityRange(OH_AVCapability *capability, OH_AVRange *complexityRange);

/**
 * @brief Get the audio codec's supported sample rates.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Audio codec capability pointer. Do not give a video codec capability pointer
 * @param sampleRates Output parameter. A pointer to the sample rates array
 * @param sampleRateNum Output parameter. The element number of the sample rates array
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, the sampleRates is nullptr, or sampleRateNum is nullptr.
 * {@link AV_ERR_UNKNOWN}, unknown error.
 * {@link AV_ERR_NO_MEMORY}, internal use memory malloc failed.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetAudioSupportedSampleRates(OH_AVCapability *capability, const int32_t **sampleRates,
                                                          uint32_t *sampleRateNum);

/**
 * @brief Get the audio codec's supported audio channel count range.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Audio codec capability pointer. Do not give a video codec capability pointer
 * @param channelCountRange Output parameter. Audio channel count range
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, or the channelCountRange is nullptr.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetAudioChannelCountRange(OH_AVCapability *capability, OH_AVRange *channelCountRange);

/**
 * @brief Get the video codec's supported video width alignment.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Video codec capability pointer. Do not give an audio codec capability pointer
 * @param widthAlignment Output parameter. Video width alignment
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, or the widthAlignment is nullptr.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetVideoWidthAlignment(OH_AVCapability *capability, int32_t *widthAlignment);

/**
 * @brief Get the video codec's supported video height alignment.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Video codec capability pointer. Do not give an audio codec capability pointer
 * @param heightAlignment Output parameter. Video height alignment
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, or the heightAlignment is nullptr.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetVideoHeightAlignment(OH_AVCapability *capability, int32_t *heightAlignment);

/**
 * @brief Get the video codec's supported video width range for a specific height.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability video codec capability pointer. Do not give an audio codec capability pointer
 * @param height Vertical pixel number of the video
 * @param widthRange Output parameter. Video width range
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, the height is not within the supported range
 * obtained through {@link OH_AVCapability_GetVideoHeightRange}, or the widthRange is nullptr.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetVideoWidthRangeForHeight(OH_AVCapability *capability, int32_t height,
                                                         OH_AVRange *widthRange);

/**
 * @brief Get the video codec's supported video height range for a specific width.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Video codec capability pointer. Do not give an audio codec capability pointer
 * @param width Horizontal pixel number of the video
 * @param heightRange Output parameter. Video height range
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, the width is not within the supported range
 * obtained through {@link OH_AVCapability_GetVideoWidthRange}, or the heightRange is nullptr.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetVideoHeightRangeForWidth(OH_AVCapability *capability, int32_t width,
                                                         OH_AVRange *heightRange);

/**
 * @brief Get the video codec's supported video width range.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Video codec capability pointer. DO not give an audio codec capability pointer
 * @param widthRange Output parameter. Video width range
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, or the widthRange is nullptr.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetVideoWidthRange(OH_AVCapability *capability, OH_AVRange *widthRange);

/**
 * @brief Get the video codec's supported video height range.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Video codec capability pointer. Do not give an audio codec capability pointer
 * @param heightRange Output parameter. Video height range
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, or the heightRange is nullptr.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetVideoHeightRange(OH_AVCapability *capability, OH_AVRange *heightRange);

/**
 * @brief Check if the video codec supports the specific video size.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Video codec capability pointer. Do not give an audio codec capability pointer
 * @param width Horizontal pixel number of the video
 * @param height Vertical pixel number of the video
 * @return Returns true if the video size is supported, false if the video size is not supported
 * @since 10
 */
bool OH_AVCapability_IsVideoSizeSupported(OH_AVCapability *capability, int32_t width, int32_t height);

/**
 * @brief Get the video codec's supported video frame rate range.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Video codec capability pointer. Do not give an audio codec capability pointer
 * @param frameRateRange Output parameter. Video frame rate range
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, or the frameRateRange is nullptr.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetVideoFrameRateRange(OH_AVCapability *capability, OH_AVRange *frameRateRange);

/**
 * @brief Get the Video codec's supported video frame rate range for a specified video size.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Video codec capability pointer. Do not give an audio codec capability pointer
 * @param width Horizontal pixel number of the video
 * @param height Vertical pixel number of the video
 * @param frameRateRange Output parameter. Frame rate range
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, the combination of width and height is
 * not supported, or the frameRateRange is nullptr.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetVideoFrameRateRangeForSize(OH_AVCapability *capability, int32_t width, int32_t height,
                                                           OH_AVRange *frameRateRange);

/**
 * @brief Check if the video codec supports the specific combination of video size and frame rate.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Video codec capability pointer. Do not give an audio codec capability pointer
 * @param width Horizontal pixel number of the video
 * @param height Vertical pixel number of the video
 * @param frameRate Frame number per second
 * @return Returns true if the combination of video size and frame rate is supported,
 * false if it is not supported
 * @since 10
 */
bool OH_AVCapability_AreVideoSizeAndFrameRateSupported(OH_AVCapability *capability, int32_t width, int32_t height,
                                                       int32_t frameRate);

/**
 * @brief Get the video codec's supported video pixel format.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Video codec capability pointer. Do not give an audio codec capability pointer
 * @param pixelFormats Output parameter. A pointer to the video pixel format array
 * @param pixelFormatNum Output parameter. The element number of the pixel format array
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, the pixelFormats is nullptr,
 * or the pixelFormatNum is nullptr.
 * {@link AV_ERR_UNKNOWN}, unknown error.
 * {@link AV_ERR_NO_MEMORY}, internal use memory malloc failed.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetVideoSupportedPixelFormats(OH_AVCapability *capability, const int32_t **pixelFormats,
                                                           uint32_t *pixelFormatNum);

/**
 * @brief Get the codec's supported profiles.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Codec capability pointer
 * @param profiles Output parameter. A pointer to the profile array
 * @param profileNum Output parameter. The element number of the profile array
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, the profiles is nullptr, or the profileNum is nullptr.
 * {@link AV_ERR_UNKNOWN}, unknown error.
 * {@link AV_ERR_NO_MEMORY}, internal use memory malloc failed.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetSupportedProfiles(OH_AVCapability *capability, const int32_t **profiles,
                                                  uint32_t *profileNum);

/**
 * @brief Get codec's supported levels for a specific profile.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Codec capability pointer
 * @param profile Codec profile
 * @param levels Output parameter. A pointer to the level array
 * @param levelNum Output parameter. The element number of the level array
 * @return Returns AV_ERR_OK if the execution is successful,
 * otherwise returns a specific error code, refer to {@link OH_AVErrCode}
 * {@link AV_ERR_INVALID_VAL}, the capability is invalid, the profile is not within the supported profile array
 * obtained through {@link OH_AVCapability_GetSupportedProfiles}, the levels is nullptr, or the levelNum is nullptr.
 * {@link AV_ERR_UNKNOWN}, unknown error.
 * {@link AV_ERR_NO_MEMORY}, internal use memory malloc failed.
 * @since 10
 */
OH_AVErrCode OH_AVCapability_GetSupportedLevelsForProfile(OH_AVCapability *capability, int32_t profile,
                                                          const int32_t **levels, uint32_t *levelNum);

/**
 * @brief Check if the codec supports the specific combination of the profile and level.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Codec capability pointer
 * @param profile Codec profile
 * @param level Codec level
 * @return Returns true if the combination of profile and level is supported,
 * false if it is not supported
 * @since 10
 */
bool OH_AVCapability_AreProfileAndLevelSupported(OH_AVCapability *capability, int32_t profile, int32_t level);

/**
 * @brief Check if the codec supports the specified feature.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Codec capability pointer
 * @param feature Feature enum, refer to {@link OH_AVCapabilityFeature} for details
 * @return Returns true if the feature is supported, false if it is not supported
 * @since 12
 */
bool OH_AVCapability_IsFeatureSupported(OH_AVCapability *capability, OH_AVCapabilityFeature feature);

/**
 * @brief Get the properties of the specified feature. It should be noted that the life cycle of the OH_AVFormat
 * instance pointed to by the return value * needs to be manually released by the caller.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param capability Codec capability pointer
 * @param feature Feature enum, refer to {@link OH_AVCapabilityFeature} for details
 * @return Returns a pointer to an OH_AVFormat instance
 * @since 12
 */
OH_AVFormat *OH_AVCapability_GetFeatureProperties(OH_AVCapability *capability, OH_AVCapabilityFeature feature);

#ifdef __cplusplus
}
#endif
#endif // NATIVE_AVCAPABILITY_H