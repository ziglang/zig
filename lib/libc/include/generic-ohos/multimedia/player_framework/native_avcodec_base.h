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

#ifndef NATIVE_AVCODEC_BASE_H
#define NATIVE_AVCODEC_BASE_H

#include <stdint.h>
#include <stdio.h>
#include "native_avbuffer.h"
#include "native_avmemory.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NativeWindow OHNativeWindow;
typedef struct OH_AVCodec OH_AVCodec;

/**
 * @brief When an error occurs in the running of the OH_AVCodec instance, the function pointer will be called
 * to report specific error information.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param codec OH_AVCodec instance
 * @param errorCode specific error code
 * @param userData User specific data
 * @since 9
 * @version 1.0
 */
typedef void (*OH_AVCodecOnError)(OH_AVCodec *codec, int32_t errorCode, void *userData);

/**
 * @brief When the output stream changes, the function pointer will be called to report the new stream description
 * information. It should be noted that the life cycle of the OH_AVFormat pointer
 * is only valid when the function pointer is called, and it is forbidden to continue to access after the call ends.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param codec OH_AVCodec instance
 * @param format New output stream description information
 * @param userData User specific data
 * @since 9
 * @version 1.0
 */
typedef void (*OH_AVCodecOnStreamChanged)(OH_AVCodec *codec, OH_AVFormat *format, void *userData);

/**
 * @brief When OH_AVCodec needs new input data during the running process,
 * the function pointer will be called and carry an available Buffer to fill in the new input data.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param codec OH_AVCodec instance
 * @param index The index corresponding to the newly available input buffer.
 * @param data New available input buffer.
 * @param userData User specific data
 * @deprecated since 11
 * @useinstead OH_AVCodecOnNeedInputBuffer
 * @since 9
 * @version 1.0
 */
typedef void (*OH_AVCodecOnNeedInputData)(OH_AVCodec *codec, uint32_t index, OH_AVMemory *data, void *userData);

/**
 * @brief When new output data is generated during the operation of OH_AVCodec, the function pointer will be
 * called and carry a Buffer containing the new output data. It should be noted that the life cycle of the
 * OH_AVCodecBufferAttr pointer is only valid when the function pointer is called. , which prohibits continued
 * access after the call ends.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param codec OH_AVCodec instance
 * @param index The index corresponding to the new output Buffer.
 * @param data Buffer containing the new output data
 * @param attr The description of the new output Buffer, please refer to {@link OH_AVCodecBufferAttr}
 * @param userData specified data
 * @deprecated since 11
 * @useinstead OH_AVCodecOnNewOutputBuffer
 * @since 9
 * @version 1.0
 */
typedef void (*OH_AVCodecOnNewOutputData)(OH_AVCodec *codec, uint32_t index, OH_AVMemory *data,
                                          OH_AVCodecBufferAttr *attr, void *userData);

/**
 * @brief When OH_AVCodec needs new input data during the running process,
 * the function pointer will be called and carry an available Buffer to fill in the new input data.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param codec OH_AVCodec instance
 * @param index The index corresponding to the newly available input buffer.
 * @param buffer New available input buffer.
 * @param userData User specific data
 * @since 11
 */
typedef void (*OH_AVCodecOnNeedInputBuffer)(OH_AVCodec *codec, uint32_t index, OH_AVBuffer *buffer, void *userData);

/**
 * @brief When new output data is generated during the operation of OH_AVCodec, the function pointer will be
 * called and carry a Buffer containing the new output data.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param codec OH_AVCodec instance
 * @param index The index corresponding to the new output Buffer.
 * @param buffer Buffer containing the new output buffer.
 * @param userData specified data
 * @since 11
 */
typedef void (*OH_AVCodecOnNewOutputBuffer)(OH_AVCodec *codec, uint32_t index, OH_AVBuffer *buffer, void *userData);

/**
 * @brief A collection of all asynchronous callback function pointers in OH_AVCodec. Register an instance of this
 * structure to the OH_AVCodec instance, and process the information reported through the callback to ensure the
 * normal operation of OH_AVCodec.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param onError Monitor OH_AVCodec operation errors, refer to {@link OH_AVCodecOnError}
 * @param onStreamChanged Monitor codec stream information, refer to {@link OH_AVCodecOnStreamChanged}
 * @param onNeedInputData Monitoring codec requires input data, refer to {@link OH_AVCodecOnNeedInputData}
 * @param onNeedOutputData Monitor codec to generate output data, refer to {@link OH_AVCodecOnNewOutputData}
 * @deprecated since 11
 * @useinstead OH_AVCodecCallback
 * @since 9
 * @version 1.0
 */
typedef struct OH_AVCodecAsyncCallback {
    OH_AVCodecOnError onError;
    OH_AVCodecOnStreamChanged onStreamChanged;
    OH_AVCodecOnNeedInputData onNeedInputData;
    OH_AVCodecOnNewOutputData onNeedOutputData;
} OH_AVCodecAsyncCallback;

/**
 * @brief A collection of all asynchronous callback function pointers in OH_AVCodec. Register an instance of this
 * structure to the OH_AVCodec instance, and process the information reported through the callback to ensure the
 * normal operation of OH_AVCodec.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param onError Monitor OH_AVCodec operation errors, refer to {@link OH_AVCodecOnError}
 * @param onStreamChanged Monitor codec stream information, refer to {@link OH_AVCodecOnStreamChanged}
 * @param onNeedInputBuffer Monitoring codec requires input buffer, refer to {@link OH_AVCodecOnNeedInputBuffer}
 * @param onNewOutputBuffer Monitor codec to generate output buffer, refer to {@link OH_AVCodecOnNewOutputBuffer}
 * @since 11
 */
typedef struct OH_AVCodecCallback {
    OH_AVCodecOnError onError;
    OH_AVCodecOnStreamChanged onStreamChanged;
    OH_AVCodecOnNeedInputBuffer onNeedInputBuffer;
    OH_AVCodecOnNewOutputBuffer onNewOutputBuffer;
} OH_AVCodecCallback;

/**
 * @brief the function pointer will be called to get sequence media data
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @param data    OH_AVBuffer buffer to fill
 * @param length   expected to read size;
 * @param pos    current read offset
 * @return  Actual size of data read to the buffer.
 * @since 12
 */
typedef int32_t (*OH_AVDataSourceReadAt)(OH_AVBuffer *data, int32_t length, int64_t pos);

/**
 * @brief User customized data source.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
typedef struct OH_AVDataSource {
    int64_t size;
    OH_AVDataSourceReadAt readAt;
} OH_AVDataSource;

/**
 * @brief Enumerates the MIME types of audio and video codecs
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 9
 * @version 1.0
 */
extern const char *OH_AVCODEC_MIMETYPE_VIDEO_AVC;
extern const char *OH_AVCODEC_MIMETYPE_AUDIO_AAC;

/**
 * @brief Enumerates the MIME types of audio and video codecs
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 10
 */
extern const char *OH_AVCODEC_MIMETYPE_AUDIO_FLAC;
extern const char *OH_AVCODEC_MIMETYPE_AUDIO_VORBIS;
extern const char *OH_AVCODEC_MIMETYPE_AUDIO_MPEG;
extern const char *OH_AVCODEC_MIMETYPE_VIDEO_HEVC;

/**
 * @brief Enumerates the types of audio and video muxer
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @deprecated since 11
 * @since 10
 */
extern const char *OH_AVCODEC_MIMETYPE_VIDEO_MPEG4;

/**
 * @brief Enumerates the types of audio and video muxer
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 10
 */
extern const char *OH_AVCODEC_MIMETYPE_IMAGE_JPG;
extern const char *OH_AVCODEC_MIMETYPE_IMAGE_PNG;
extern const char *OH_AVCODEC_MIMETYPE_IMAGE_BMP;

/**
 * @brief Enumerates the MIME types of audio codecs
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 11
 */
extern const char *OH_AVCODEC_MIMETYPE_AUDIO_VIVID;
extern const char *OH_AVCODEC_MIMETYPE_AUDIO_AMR_NB;
extern const char *OH_AVCODEC_MIMETYPE_AUDIO_AMR_WB;
extern const char *OH_AVCODEC_MIMETYPE_AUDIO_OPUS;
extern const char *OH_AVCODEC_MIMETYPE_AUDIO_G711MU;

/**
 * @brief Enumerates the MIME type of audio low bitrate voice codec.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_AVCODEC_MIMETYPE_AUDIO_LBVC;

/**
 * @brief Enumerates the MIME type of audio ape codec.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_AVCODEC_MIMETYPE_AUDIO_APE;

/**
 * @brief Enumerates the MIME type of subtitle.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_AVCODEC_MIMETYPE_SUBTITLE_SRT;

/**
 * @brief The extra data's key of surface Buffer
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 9
 * @version 1.0
 */
/* Key for timeStamp in surface's extraData, value type is int64 */
extern const char *OH_ED_KEY_TIME_STAMP;
/* Key for endOfStream in surface's extraData, value type is bool */
extern const char *OH_ED_KEY_EOS;

/**
 * @brief Provides the uniform key for storing the media description.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 9
 * @version 1.0
 */
/* Key for track type, value type is int32_t, see @OH_MediaType. */
extern const char *OH_MD_KEY_TRACK_TYPE;
/* Key for codec mime type, value type is string. */
extern const char *OH_MD_KEY_CODEC_MIME;
/* Key for duration, value type is int64_t. */
extern const char *OH_MD_KEY_DURATION;
/* Key for bitrate, value type is int64_t. */
extern const char *OH_MD_KEY_BITRATE;
/* Key for max input size, value type is int32_t */
extern const char *OH_MD_KEY_MAX_INPUT_SIZE;
/* Key for video width, value type is int32_t */
extern const char *OH_MD_KEY_WIDTH;
/* Key for video height, value type is int32_t */
extern const char *OH_MD_KEY_HEIGHT;
/* Key for video pixel format, value type is int32_t, see @OH_AVPixelFormat */
extern const char *OH_MD_KEY_PIXEL_FORMAT;
/* key for audio raw format, value type is int32_t , see @AudioSampleFormat */
extern const char *OH_MD_KEY_AUDIO_SAMPLE_FORMAT;
/* Key for video frame rate, value type is double. */
extern const char *OH_MD_KEY_FRAME_RATE;
/* video encode bitrate mode, the value type is int32_t, see @OH_VideoEncodeBitrateMode */
extern const char *OH_MD_KEY_VIDEO_ENCODE_BITRATE_MODE;
/* encode profile, the value type is int32_t. see @OH_AVCProfile, OH_HEVCProfile, OH_AACProfile. */
extern const char *OH_MD_KEY_PROFILE;
/* Key for audio channel count, value type is int32_t */
extern const char *OH_MD_KEY_AUD_CHANNEL_COUNT;
/* Key for audio sample rate, value type is int32_t */
extern const char *OH_MD_KEY_AUD_SAMPLE_RATE;
/**
 * @brief Key for the interval of key frame. value type is int32_t, the unit is milliseconds. A negative value means no
 * key frames are requested after the first frame. A zero value means a stream containing all key frames is requested.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 9
 */
extern const char *OH_MD_KEY_I_FRAME_INTERVAL;
/* Key of the surface rotation angle. value type is int32_t: should be {0, 90, 180, 270}, default is 0. */
extern const char *OH_MD_KEY_ROTATION;

/**
 * @brief Provides the uniform key for storing the media description.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 10
 */
/* Key for video YUV value range flag, value type is bool, true for full range, false for limited range */
extern const char *OH_MD_KEY_RANGE_FLAG;
/* Key for video color primaries, value type is int32_t, see @OH_ColorPrimary */
extern const char *OH_MD_KEY_COLOR_PRIMARIES;
/* Key for video transfer characteristics, value type is int32_t, see @OH_TransferCharacteristic */
extern const char *OH_MD_KEY_TRANSFER_CHARACTERISTICS;
/* Key for video matrix coefficients, value type is int32_t, see @OH_MatrixCoefficient */
extern const char *OH_MD_KEY_MATRIX_COEFFICIENTS;
/* Key for the request an I-Frame immediately, value type is bool */
extern const char *OH_MD_KEY_REQUEST_I_FRAME;
/* Key for the desired encoding quality, value type is int32_t, this key is only
 * supported for encoders that are configured in constant quality mode */
extern const char *OH_MD_KEY_QUALITY;
/* Key of the codec specific data. value type is a uint8_t pointer */
extern const char *OH_MD_KEY_CODEC_CONFIG;
/* source format Key for title, value type is string */
extern const char *OH_MD_KEY_TITLE;
/* source format Key for artist, value type is string */
extern const char *OH_MD_KEY_ARTIST;
/* source format Key for album, value type is string */
extern const char *OH_MD_KEY_ALBUM;
/* source format Key for album artist, value type is string */
extern const char *OH_MD_KEY_ALBUM_ARTIST;
/* source format Key for date, value type is string */
extern const char *OH_MD_KEY_DATE;
/* source format Key for comment, value type is string */
extern const char *OH_MD_KEY_COMMENT;
/* source format Key for genre, value type is string */
extern const char *OH_MD_KEY_GENRE;
/* source format Key for copyright, value type is string */
extern const char *OH_MD_KEY_COPYRIGHT;
/* source format Key for language, value type is string */
extern const char *OH_MD_KEY_LANGUAGE;
/* source format Key for description, value type is string */
extern const char *OH_MD_KEY_DESCRIPTION;
/* source format Key for lyrics, value type is string */
extern const char *OH_MD_KEY_LYRICS;
/* source format Key for track count, value type is int32_t */
extern const char *OH_MD_KEY_TRACK_COUNT;
/* Key for the desired encoding channel layout, value type is int64_t, this key is only supported for encoders */
extern const char *OH_MD_KEY_CHANNEL_LAYOUT;
/* Key for bits per coded sample, value type is int32_t, supported for flac encoder, see @OH_BitsPerSample */
extern const char *OH_MD_KEY_BITS_PER_CODED_SAMPLE;
/* Key for the aac format, value type is int32_t, supported for aac decoder */
extern const char *OH_MD_KEY_AAC_IS_ADTS;
/* Key for aac sbr mode, value type is int32_t, supported for aac encoder */
extern const char *OH_MD_KEY_SBR;
/* Key for flac compliance level, value type is int32_t */
extern const char *OH_MD_KEY_COMPLIANCE_LEVEL;
/* Key for vorbis identification header, value type is a uint8_t pointer, supported only for vorbis decoder */
extern const char *OH_MD_KEY_IDENTIFICATION_HEADER;
/* Key for vorbis setup header, value type is a uint8_t pointer, supported only for vorbis decoder */
extern const char *OH_MD_KEY_SETUP_HEADER;
/* Key for video scale type, value type is int32_t, see @OH_ScalingMode */
extern const char *OH_MD_KEY_SCALING_MODE;
/* Key for max input buffer count, value type is int32_t */
extern const char *OH_MD_MAX_INPUT_BUFFER_COUNT;
/* Key for max output buffer count, value type is int32_t */
extern const char *OH_MD_MAX_OUTPUT_BUFFER_COUNT;

/**
 * @brief Provides the uniform key for storing the media description.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 11
 */
/* Key for audio codec compression level, value type is int32_t */
extern const char *OH_MD_KEY_AUDIO_COMPRESSION_LEVEL;
/* Key of the video is hdr vivid. value type is bool */
extern const char *OH_MD_KEY_VIDEO_IS_HDR_VIVID;
/* Key for number of audio objects. value type is int32_t */
extern const char *OH_MD_KEY_AUDIO_OBJECT_NUMBER;
/* Key for meta data of audio vivid. value type is a uint8_t pointer */
extern const char *OH_MD_KEY_AUDIO_VIVID_METADATA;

/**
 * @brief Key for querying the maximum long-term reference count of video encoder, value type is int32_t.
 * You should query the count through interface {@link OH_AVCapability_GetFeatureProperties}
 * with enum {@link VIDEO_ENCODER_LONG_TERM_REFERENCE}.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_FEATURE_PROPERTY_KEY_VIDEO_ENCODER_MAX_LTR_FRAME_COUNT;
/**
 * @brief Key for enable the temporal scalability mode, value type is int32_t (0 or 1): 1 is enabled, 0 otherwise.
 * The default value is 0. To query supported, you should use the interface {@link OH_AVCapability_IsFeatureSupported}
 * with enum {@link VIDEO_ENCODER_TEMPORAL_SCALABILITY}. This is an optional key that applies only to video encoder.
 * It is used in configure.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_ENCODER_ENABLE_TEMPORAL_SCALABILITY;
/**
 * @brief Key for describing the temporal group of picture size, value type is int32_t. It takes effect only when
 * temporal level scale is enable. This is an optional key that applies only to video encoder. It is used in configure.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_ENCODER_TEMPORAL_GOP_SIZE;
/**
 * @brief Key for describing the reference mode in temporal group of picture, value type is int32_t, see enum
 * {@link OH_TemporalGopReferenceMode}. It takes effect only when temporal level sacle is enabled.
 * This is an optional key that applies only to video encoder. It is used in configure.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_ENCODER_TEMPORAL_GOP_REFERENCE_MODE;
/**
 * @brief Key for describing the count of used long-term reference frames, value type is int32_t, must be within the
 * supported range. To get supported range, you should query wthether the capability is supported through the interface
 * {@link OH_AVCapability_GetFeatureProperties} with enum {@link VIDEO_ENCODER_LONG_TERM_REFERENCE}, otherwise, not set
 * the key. This is an optional key that applies only to video encoder. It is used in configure.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_ENCODER_LTR_FRAME_COUNT;
/**
 * @brief Key for describing mark this frame as a long term reference frame, value type is int32_t (0 or 1): 1 is mark,
 * 0 otherwise. It takes effect only when the number of used long term reference frames is configured. This is an
 * optional key that applies only to video encoder input loop. It takes effect immediately.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_ENCODER_PER_FRAME_MARK_LTR;
/**
 * @brief Key for describing the long term reference frame poc referenced by this frame, value type is int32_t. This is
 * an optional key that applies only to video encoder input loop. It takes effect immediately.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_ENCODER_PER_FRAME_USE_LTR;
/**
 * @brief Key for indicating this frame is a long-term reference frame, value type is int32_t (0 or 1): 1 is LTR,
 * 0 otherwise. This is an optional key that applies only to video encoder output loop.
 * It indicates the attribute of the frame.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_PER_FRAME_IS_LTR;
/**
 * @brief Key for describing the frame poc, value type is int32_t. This is an optional key that applies only to video
 * encoder output loop. It indicates the attribute of the frame.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_PER_FRAME_POC;
/**
 * @brief Key for describing the top-coordinate (y) of the crop rectangle, value type is int32_t. This is the top-most
 * row included in the crop frame, where row indices start at 0.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_CROP_TOP;
/**
 * @brief Key for describing the bottom-coordinate (y) of the crop rectangle, value type is int32_t. This is the
 * bottom-most row included in the crop frame, where row indices start at 0.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_CROP_BOTTOM;
/**
 * @brief Key for describing the left-coordinate (x) of the crop rectangle, value type is int32_t.
 * This is the left-most column included in the crop frame, where column indices start at 0.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_CROP_LEFT;
/**
 * @brief Key for describing the right-coordinate (x) of the crop rectangle, value type is int32_t. This is the
 * right-most column included in the crop frame, where column indices start at 0.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_CROP_RIGHT;
/**
 * @brief Key for describing the stride of the video buffer layout, value type is int32_t. Stride (or row increment) is
 * the difference between the index of a pixel and that of the pixel directly underneath. For YUV 420 formats, the
 * stride corresponds to the Y plane; the stride of the U and V planes can be calculated based on the color format,
 * though it is generally undefined and depends on the device and release.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_STRIDE;
/**
 * @brief Key for describing the plane height of a multi-planar (YUV) video buffer layout, value type is int32_t.
 * Slice height (or plane height/vertical stride) is the number of rows that must be skipped to get from
 * the top of the Y plane to the top of the U plane in the buffer. In essence the offset of the U plane
 * is sliceHeight * stride. The height of the U/V planes can be calculated based on the color format,
 * though it is generally undefined and depends on the device and release.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_SLICE_HEIGHT;
/**
 * @brief Key for describing the valid picture width of the video, value type is int32_t.
 * Get the value from an OH_AVFormat instance, which obtained by calling {@link OH_VideoDecoder_GetOutputDescription}
 * or {@link OH_AVCodecOnStreamChanged}.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_PIC_WIDTH;
/**
 * @brief Key for describing the valid picture height of the video, value type is int32_t.
 * Get the value from an OH_AVFormat instance, which obtained by calling {@link OH_VideoDecoder_GetOutputDescription}
 * or {@link OH_AVCodecOnStreamChanged}.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_PIC_HEIGHT;
/**
 * @brief Key to enable the low latency mode, value type is int32_t (0 or 1):1 is enabled, 0 otherwise.
 * If enabled, the video encoder or video decoder doesn't hold input and output data more than required by
 * the codec standards. This is an optional key that applies only to video encoder or video decoder.
 * It is used in configure.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_ENABLE_LOW_LATENCY;
/**
 * @brief Key for describing the maximum quantization parameter allowed for video encoder, value type is int32_t.
 * It is used in configure/setparameter or takes effect immediately with the frame.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_ENCODER_QP_MAX;
/**
 * @brief Key for describing the minimum quantization parameter allowed for video encoder, value type is int32_t.
 * It is used in configure/setparameter or takes effect immediately with the frame.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_ENCODER_QP_MIN;
/**
 * @brief Key for describing the video frame averge quantization parameter, value type is int32_t.
 * This is a part of a video encoder statistics export feature. This value is emitted from video encoder for a video
 * frame.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_ENCODER_QP_AVERAGE;
/**
 * @brief Key for describing video frame mean squared error, value type is double.
 * This is a part of a video encoder statistics export feature. This value is emitted from video encoder for a video
 * frame.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_ENCODER_MSE;
/**
 * @brief Key for decoding timestamp of the buffer in microseconds, value type is int64_t.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_DECODING_TIMESTAMP;
/**
 * @brief Key for duration of the buffer in microseconds, value type is int64_t.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_BUFFER_DURATION;
/**
 * @brief Key for sample aspect ratio, value type is double.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_VIDEO_SAR;
/**
 * @brief Key for start time of file, value type is int64_t.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
extern const char *OH_MD_KEY_START_TIME;

/**
 * @brief Media type.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 9
 * @version 1.0
 */
typedef enum OH_MediaType {
    /* track is audio. */
    MEDIA_TYPE_AUD = 0,
    /* track is video. */
    MEDIA_TYPE_VID = 1,
} OH_MediaType;

/**
 * @brief AAC Profile
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 9
 * @version 1.0
 */
typedef enum OH_AACProfile {
    AAC_PROFILE_LC = 0,
} OH_AACProfile;

/**
 * @brief AVC Profile
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 9
 * @version 1.0
 */
typedef enum OH_AVCProfile {
    AVC_PROFILE_BASELINE = 0,
    AVC_PROFILE_HIGH = 4,
    AVC_PROFILE_MAIN = 8,
} OH_AVCProfile;

/**
 * @brief HEVC Profile
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 10
 */
typedef enum OH_HEVCProfile {
    HEVC_PROFILE_MAIN = 0,
    HEVC_PROFILE_MAIN_10 = 1,
    HEVC_PROFILE_MAIN_STILL = 2,
    HEVC_PROFILE_MAIN_10_HDR10 = 3,
    HEVC_PROFILE_MAIN_10_HDR10_PLUS = 4,
} OH_HEVCProfile;

/**
 * @brief Enumerates the muxer output file format
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 10
 */
typedef enum OH_AVOutputFormat {
    AV_OUTPUT_FORMAT_DEFAULT = 0,
    AV_OUTPUT_FORMAT_MPEG_4 = 2,
    AV_OUTPUT_FORMAT_M4A = 6,
    /**
     * The muxer output amr file format.
     * @since 12
     */
    AV_OUTPUT_FORMAT_AMR = 8,
    /**
     * The muxer output mp3 file format.
     * @since 12
     */
    AV_OUTPUT_FORMAT_MP3 = 9,
} OH_AVOutputFormat;

/**
 * @brief Seek Mode
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 10
 */
typedef enum OH_AVSeekMode {
    /* seek to sync sample after the time */
    SEEK_MODE_NEXT_SYNC = 0,
    /* seek to sync sample before the time */
    SEEK_MODE_PREVIOUS_SYNC,
    /* seek to sync sample closest to time */
    SEEK_MODE_CLOSEST_SYNC,
} OH_AVSeekMode;

/**
 * @brief Scaling Mode
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 10
 */
typedef enum OH_ScalingMode {
    SCALING_MODE_SCALE_TO_WINDOW = 1,
    SCALING_MODE_SCALE_CROP = 2,
} OH_ScalingMode;

/**
 * @brief enum Audio Bits Per Coded Sample
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 10
 */
typedef enum OH_BitsPerSample {
    SAMPLE_U8 = 0,
    SAMPLE_S16LE = 1,
    SAMPLE_S24LE = 2,
    SAMPLE_S32LE = 3,
    SAMPLE_F32LE = 4,
    SAMPLE_U8P = 5,
    SAMPLE_S16P = 6,
    SAMPLE_S24P = 7,
    SAMPLE_S32P = 8,
    SAMPLE_F32P = 9,
    INVALID_WIDTH = -1
} OH_BitsPerSample;

/**
 * @brief Color Primary
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 10
 */
typedef enum OH_ColorPrimary {
    COLOR_PRIMARY_BT709 = 1,
    COLOR_PRIMARY_UNSPECIFIED = 2,
    COLOR_PRIMARY_BT470_M = 4,
    COLOR_PRIMARY_BT601_625 = 5,
    COLOR_PRIMARY_BT601_525 = 6,
    COLOR_PRIMARY_SMPTE_ST240 = 7,
    COLOR_PRIMARY_GENERIC_FILM = 8,
    COLOR_PRIMARY_BT2020 = 9,
    COLOR_PRIMARY_SMPTE_ST428 = 10,
    COLOR_PRIMARY_P3DCI = 11,
    COLOR_PRIMARY_P3D65 = 12,
} OH_ColorPrimary;

/**
 * @brief Transfer Characteristic
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 10
 */
typedef enum OH_TransferCharacteristic {
    TRANSFER_CHARACTERISTIC_BT709 = 1,
    TRANSFER_CHARACTERISTIC_UNSPECIFIED = 2,
    TRANSFER_CHARACTERISTIC_GAMMA_2_2 = 4,
    TRANSFER_CHARACTERISTIC_GAMMA_2_8 = 5,
    TRANSFER_CHARACTERISTIC_BT601 = 6,
    TRANSFER_CHARACTERISTIC_SMPTE_ST240 = 7,
    TRANSFER_CHARACTERISTIC_LINEAR = 8,
    TRANSFER_CHARACTERISTIC_LOG = 9,
    TRANSFER_CHARACTERISTIC_LOG_SQRT = 10,
    TRANSFER_CHARACTERISTIC_IEC_61966_2_4 = 11,
    TRANSFER_CHARACTERISTIC_BT1361 = 12,
    TRANSFER_CHARACTERISTIC_IEC_61966_2_1 = 13,
    TRANSFER_CHARACTERISTIC_BT2020_10BIT = 14,
    TRANSFER_CHARACTERISTIC_BT2020_12BIT = 15,
    TRANSFER_CHARACTERISTIC_PQ = 16,
    TRANSFER_CHARACTERISTIC_SMPTE_ST428 = 17,
    TRANSFER_CHARACTERISTIC_HLG = 18,
} OH_TransferCharacteristic;

/**
 * @brief Matrix Coefficient
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 10
 */
typedef enum OH_MatrixCoefficient {
    MATRIX_COEFFICIENT_IDENTITY = 0,
    MATRIX_COEFFICIENT_BT709 = 1,
    MATRIX_COEFFICIENT_UNSPECIFIED = 2,
    MATRIX_COEFFICIENT_FCC = 4,
    MATRIX_COEFFICIENT_BT601_625 = 5,
    MATRIX_COEFFICIENT_BT601_525 = 6,
    MATRIX_COEFFICIENT_SMPTE_ST240 = 7,
    MATRIX_COEFFICIENT_YCGCO = 8,
    MATRIX_COEFFICIENT_BT2020_NCL = 9,
    MATRIX_COEFFICIENT_BT2020_CL = 10,
    MATRIX_COEFFICIENT_SMPTE_ST2085 = 11,
    MATRIX_COEFFICIENT_CHROMATICITY_NCL = 12,
    MATRIX_COEFFICIENT_CHROMATICITY_CL = 13,
    MATRIX_COEFFICIENT_ICTCP = 14,
} OH_MatrixCoefficient;

/**
 * @brief AVC Level.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
typedef enum OH_AVCLevel {
    AVC_LEVEL_1 = 0,
    AVC_LEVEL_1b = 1,
    AVC_LEVEL_11 = 2,
    AVC_LEVEL_12 = 3,
    AVC_LEVEL_13 = 4,
    AVC_LEVEL_2 = 5,
    AVC_LEVEL_21 = 6,
    AVC_LEVEL_22 = 7,
    AVC_LEVEL_3 = 8,
    AVC_LEVEL_31 = 9,
    AVC_LEVEL_32 = 10,
    AVC_LEVEL_4 = 11,
    AVC_LEVEL_41 = 12,
    AVC_LEVEL_42 = 13,
    AVC_LEVEL_5 = 14,
    AVC_LEVEL_51 = 15,
    AVC_LEVEL_52 = 16,
    AVC_LEVEL_6 = 17,
    AVC_LEVEL_61 = 18,
    AVC_LEVEL_62 = 19,
} OH_AVCLevel;

/**
 * @brief HEVC Level.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
typedef enum OH_HEVCLevel {
    HEVC_LEVEL_1 = 0,
    HEVC_LEVEL_2 = 1,
    HEVC_LEVEL_21 = 2,
    HEVC_LEVEL_3 = 3,
    HEVC_LEVEL_31 = 4,
    HEVC_LEVEL_4 = 5,
    HEVC_LEVEL_41 = 6,
    HEVC_LEVEL_5 = 7,
    HEVC_LEVEL_51 = 8,
    HEVC_LEVEL_52 = 9,
    HEVC_LEVEL_6 = 10,
    HEVC_LEVEL_61 = 11,
    HEVC_LEVEL_62 = 12,
} OH_HEVCLevel;

/**
 * @brief The reference mode in temporal group of picture.
 *
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @since 12
 */
typedef enum OH_TemporalGopReferenceMode {
    /** Refer to latest short-term reference frame. */
    ADJACENT_REFERENCE = 0,
    /** Refer to latest long-term reference frame. */
    JUMP_REFERENCE = 1,
} OH_TemporalGopReferenceMode;

#ifdef __cplusplus
}
#endif

#endif // NATIVE_AVCODEC_BASE_H