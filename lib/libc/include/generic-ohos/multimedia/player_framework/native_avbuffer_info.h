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

#ifndef NATIVE_AVBUFFER_INFO_H
#define NATIVE_AVBUFFER_INFO_H

#include <stdint.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif
/**
 * @brief Enumerate the categories of OH_AVCodec's Buffer tags.
 * @syscap SystemCapability.Multimedia.Media.Core
 * @since 9
 */
typedef enum OH_AVCodecBufferFlags {
    AVCODEC_BUFFER_FLAGS_NONE = 0,
    /** Indicates that the Buffer is an End-of-Stream frame. */
    AVCODEC_BUFFER_FLAGS_EOS = 1 << 0,
    /** Indicates that the Buffer contains keyframes. */
    AVCODEC_BUFFER_FLAGS_SYNC_FRAME = 1 << 1,
    /** Indicates that the data contained in the Buffer is only part of a frame. */
    AVCODEC_BUFFER_FLAGS_INCOMPLETE_FRAME = 1 << 2,
    /** Indicates that the Buffer contains Codec-Specific-Data. */
    AVCODEC_BUFFER_FLAGS_CODEC_DATA = 1 << 3,
    /** Flag is used to discard packets which are required to maintain valid decoder state but are not required
     *  for output and should be dropped after decoding.
     * @since 12
     */
    AVCODEC_BUFFER_FLAGS_DISCARD = 1 << 4,
    /** Flag is used to indicate packets that contain frames that can be discarded by the decoder,
     *  I.e. Non-reference frames.
     * @since 12
     */
    AVCODEC_BUFFER_FLAGS_DISPOSABLE = 1 << 5,
} OH_AVCodecBufferFlags;

/**
 * @brief Define the Buffer description information of OH_AVCodec
 * @syscap SystemCapability.Multimedia.Media.Core
 * @since 9
 */
typedef struct OH_AVCodecBufferAttr {
    /* Presentation timestamp of this Buffer in microseconds */
    int64_t pts;
    /* The size of the data contained in the Buffer in bytes */
    int32_t size;
    /* The starting offset of valid data in this Buffer */
    int32_t offset;
    /* The flags this Buffer has, which is also a combination of multiple {@link OH_AVCodecBufferFlags}. */
    uint32_t flags;
} OH_AVCodecBufferAttr;

#ifdef __cplusplus
}
#endif

#endif // NATIVE_AVBUFFER_INFO_H