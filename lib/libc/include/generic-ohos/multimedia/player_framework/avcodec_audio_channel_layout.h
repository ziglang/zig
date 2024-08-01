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

#ifndef AVCODEC_AUDIO_CHANNEL_LAYOUT_H
#define AVCODEC_AUDIO_CHANNEL_LAYOUT_H
#include <cstdint>
#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Audio Channel Set
 * A 64-bit integer with bits set for each channel.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @deprecated since 11
 * @useinstead OH_AudioChannelSet
 * @since 10
 */
enum AudioChannelSet : uint64_t {
    FRONT_LEFT = 1ULL << 0U,
    FRONT_RIGHT = 1ULL << 1U,
    FRONT_CENTER = 1ULL << 2U,
    LOW_FREQUENCY = 1ULL << 3U,
    BACK_LEFT = 1ULL << 4U,
    BACK_RIGHT = 1ULL << 5U,
    FRONT_LEFT_OF_CENTER = 1ULL << 6U,
    FRONT_RIGHT_OF_CENTER = 1ULL << 7U,
    BACK_CENTER = 1ULL << 8U,
    SIDE_LEFT = 1ULL << 9U,
    SIDE_RIGHT = 1ULL << 10U,
    TOP_CENTER = 1ULL << 11U,
    TOP_FRONT_LEFT = 1ULL << 12U,
    TOP_FRONT_CENTER = 1ULL << 13U,
    TOP_FRONT_RIGHT = 1ULL << 14U,
    TOP_BACK_LEFT = 1ULL << 15U,
    TOP_BACK_CENTER = 1ULL << 16U,
    TOP_BACK_RIGHT = 1ULL << 17U,
    STEREO_LEFT = 1ULL << 29U,
    STEREO_RIGHT = 1ULL << 30U,
    WIDE_LEFT = 1ULL << 31U,
    WIDE_RIGHT = 1ULL << 32U,
    SURROUND_DIRECT_LEFT = 1ULL << 33U,
    SURROUND_DIRECT_RIGHT = 1ULL << 34U,
    LOW_FREQUENCY_2 = 1ULL << 35U,
    TOP_SIDE_LEFT = 1ULL << 36U,
    TOP_SIDE_RIGHT = 1ULL << 37U,
    BOTTOM_FRONT_CENTER = 1ULL << 38U,
    BOTTOM_FRONT_LEFT = 1ULL << 39U,
    BOTTOM_FRONT_RIGHT = 1ULL << 40U,

    // Ambisonics ACN formats
    // 0th and first order ambisonics ACN
    AMBISONICS_ACN0 = 1ULL << 41U,  /** 0th ambisonics channel number 0. */
    AMBISONICS_ACN1 = 1ULL << 42U,  /** first-order ambisonics channel number 1. */
    AMBISONICS_ACN2 = 1ULL << 43U,  /** first-order ambisonics channel number 2. */
    AMBISONICS_ACN3 = 1ULL << 44U,  /** first-order ambisonics channel number 3. */
    AMBISONICS_W = AMBISONICS_ACN0, /** same as 0th ambisonics channel number 0. */
    AMBISONICS_Y = AMBISONICS_ACN1, /** same as first-order ambisonics channel number 1. */
    AMBISONICS_Z = AMBISONICS_ACN2, /** same as first-order ambisonics channel number 2. */
    AMBISONICS_X = AMBISONICS_ACN3, /** same as first-order ambisonics channel number 3. */

    // second order ambisonics ACN
    AMBISONICS_ACN4 = 1ULL << 45U, /** second-order ambisonics channel number 4. */
    AMBISONICS_ACN5 = 1ULL << 46U, /** second-order ambisonics channel number 5. */
    AMBISONICS_ACN6 = 1ULL << 47U, /** second-order ambisonics channel number 6. */
    AMBISONICS_ACN7 = 1ULL << 48U, /** second-order ambisonics channel number 7. */
    AMBISONICS_ACN8 = 1ULL << 49U, /** second-order ambisonics channel number 8. */

    // third order ambisonics ACN
    AMBISONICS_ACN9 = 1ULL << 50U,  /** third-order ambisonics channel number 9. */
    AMBISONICS_ACN10 = 1ULL << 51U, /** third-order ambisonics channel number 10. */
    AMBISONICS_ACN11 = 1ULL << 52U, /** third-order ambisonics channel number 11. */
    AMBISONICS_ACN12 = 1ULL << 53U, /** third-order ambisonics channel number 12. */
    AMBISONICS_ACN13 = 1ULL << 54U, /** third-order ambisonics channel number 13. */
    AMBISONICS_ACN14 = 1ULL << 55U, /** third-order ambisonics channel number 14. */
    AMBISONICS_ACN15 = 1ULL << 56U, /** third-order ambisonics channel number 15. */
};

/**
 * @brief Audio AudioChannel Layout
 * Indicates that the channel order in which the user requests decoder output
 * is the native codec channel order.
 * @syscap SystemCapability.Multimedia.Media.CodecBase
 * @deprecated since 11
 * @useinstead OH_AudioChannelLayout
 * @since 10
 */
enum AudioChannelLayout : uint64_t {
    UNKNOWN_CHANNEL_LAYOUT = 0,
    MONO = (AudioChannelSet::FRONT_CENTER),
    STEREO = (AudioChannelSet::FRONT_LEFT | AudioChannelSet::FRONT_RIGHT),
    CH_2POINT1 = (STEREO | AudioChannelSet::LOW_FREQUENCY),
    CH_2_1 = (STEREO | AudioChannelSet::BACK_CENTER),
    SURROUND = (STEREO | AudioChannelSet::FRONT_CENTER),
    CH_3POINT1 = (SURROUND | AudioChannelSet::LOW_FREQUENCY),
    CH_4POINT0 = (SURROUND | AudioChannelSet::BACK_CENTER),
    CH_4POINT1 = (CH_4POINT0 | AudioChannelSet::LOW_FREQUENCY),
    CH_2_2 = (STEREO | AudioChannelSet::SIDE_LEFT | AudioChannelSet::SIDE_RIGHT),
    QUAD = (STEREO | AudioChannelSet::BACK_LEFT | AudioChannelSet::BACK_RIGHT),
    CH_5POINT0 = (SURROUND | AudioChannelSet::SIDE_LEFT | AudioChannelSet::SIDE_RIGHT),
    CH_5POINT1 = (CH_5POINT0 | AudioChannelSet::LOW_FREQUENCY),
    CH_5POINT0_BACK = (SURROUND | AudioChannelSet::BACK_LEFT | AudioChannelSet::BACK_RIGHT),
    CH_5POINT1_BACK = (CH_5POINT0_BACK | AudioChannelSet::LOW_FREQUENCY),
    CH_6POINT0 = (CH_5POINT0 | AudioChannelSet::BACK_CENTER),
    CH_6POINT0_FRONT = (CH_2_2 | AudioChannelSet::FRONT_LEFT_OF_CENTER | AudioChannelSet::FRONT_RIGHT_OF_CENTER),
    HEXAGONAL = (CH_5POINT0_BACK | AudioChannelSet::BACK_CENTER),
    CH_6POINT1 = (CH_5POINT1 | AudioChannelSet::BACK_CENTER),
    CH_6POINT1_BACK = (CH_5POINT1_BACK | AudioChannelSet::BACK_CENTER),
    CH_6POINT1_FRONT = (CH_6POINT0_FRONT | AudioChannelSet::LOW_FREQUENCY),
    CH_7POINT0 = (CH_5POINT0 | AudioChannelSet::BACK_LEFT | AudioChannelSet::BACK_RIGHT),
    CH_7POINT0_FRONT = (CH_5POINT0 | AudioChannelSet::FRONT_LEFT_OF_CENTER | AudioChannelSet::FRONT_RIGHT_OF_CENTER),
    CH_7POINT1 = (CH_5POINT1 | AudioChannelSet::BACK_LEFT | AudioChannelSet::BACK_RIGHT),
    CH_7POINT1_WIDE = (CH_5POINT1 | AudioChannelSet::FRONT_LEFT_OF_CENTER | AudioChannelSet::FRONT_RIGHT_OF_CENTER),
    CH_7POINT1_WIDE_BACK =
        (CH_5POINT1_BACK | AudioChannelSet::FRONT_LEFT_OF_CENTER | AudioChannelSet::FRONT_RIGHT_OF_CENTER),
    CH_3POINT1POINT2 = (CH_3POINT1 | AudioChannelSet::TOP_FRONT_LEFT | AudioChannelSet::TOP_FRONT_RIGHT),
    CH_5POINT1POINT2 = (CH_5POINT1 | AudioChannelSet::TOP_SIDE_LEFT | AudioChannelSet::TOP_SIDE_RIGHT),
    CH_5POINT1POINT4 = (CH_5POINT1 | AudioChannelSet::TOP_FRONT_LEFT | AudioChannelSet::TOP_FRONT_RIGHT |
                        AudioChannelSet::TOP_BACK_LEFT | AudioChannelSet::TOP_BACK_RIGHT),
    CH_7POINT1POINT2 = (CH_7POINT1 | AudioChannelSet::TOP_SIDE_LEFT | AudioChannelSet::TOP_SIDE_RIGHT),
    CH_7POINT1POINT4 = (CH_7POINT1 | AudioChannelSet::TOP_FRONT_LEFT | AudioChannelSet::TOP_FRONT_RIGHT |
                        AudioChannelSet::TOP_BACK_LEFT | AudioChannelSet::TOP_BACK_RIGHT),
    CH_9POINT1POINT4 = (CH_7POINT1POINT4 | AudioChannelSet::WIDE_LEFT | AudioChannelSet::WIDE_RIGHT),
    CH_9POINT1POINT6 = (CH_9POINT1POINT4 | AudioChannelSet::TOP_SIDE_LEFT | AudioChannelSet::TOP_SIDE_RIGHT),
    CH_10POINT2 = (AudioChannelSet::FRONT_LEFT | AudioChannelSet::FRONT_RIGHT | AudioChannelSet::FRONT_CENTER |
                   AudioChannelSet::TOP_FRONT_LEFT | AudioChannelSet::TOP_FRONT_RIGHT | AudioChannelSet::BACK_LEFT |
                   AudioChannelSet::BACK_RIGHT | AudioChannelSet::BACK_CENTER | AudioChannelSet::SIDE_LEFT |
                   AudioChannelSet::SIDE_RIGHT | AudioChannelSet::WIDE_LEFT | AudioChannelSet::WIDE_RIGHT),
    CH_22POINT2 = (CH_7POINT1POINT4 | AudioChannelSet::FRONT_LEFT_OF_CENTER | AudioChannelSet::FRONT_RIGHT_OF_CENTER |
                   AudioChannelSet::BACK_CENTER | AudioChannelSet::TOP_CENTER | AudioChannelSet::TOP_FRONT_CENTER |
                   AudioChannelSet::TOP_BACK_CENTER | AudioChannelSet::TOP_SIDE_LEFT | AudioChannelSet::TOP_SIDE_RIGHT |
                   AudioChannelSet::BOTTOM_FRONT_LEFT | AudioChannelSet::BOTTOM_FRONT_RIGHT |
                   AudioChannelSet::BOTTOM_FRONT_CENTER | AudioChannelSet::LOW_FREQUENCY_2),
    OCTAGONAL = (CH_5POINT0 | AudioChannelSet::BACK_LEFT | AudioChannelSet::BACK_CENTER | AudioChannelSet::BACK_RIGHT),
    HEXADECAGONAL =
        (OCTAGONAL | AudioChannelSet::WIDE_LEFT | AudioChannelSet::WIDE_RIGHT | AudioChannelSet::TOP_BACK_LEFT |
         AudioChannelSet::TOP_BACK_RIGHT | AudioChannelSet::TOP_BACK_CENTER | AudioChannelSet::TOP_FRONT_CENTER |
         AudioChannelSet::TOP_FRONT_LEFT | AudioChannelSet::TOP_FRONT_RIGHT),
    STEREO_DOWNMIX = (AudioChannelSet::STEREO_LEFT | AudioChannelSet::STEREO_RIGHT),

    HOA_FIRST = AudioChannelSet::AMBISONICS_ACN0 | AudioChannelSet::AMBISONICS_ACN1 | AudioChannelSet::AMBISONICS_ACN2 |
                AudioChannelSet::AMBISONICS_ACN3,
    HOA_SECOND = HOA_FIRST | AudioChannelSet::AMBISONICS_ACN4 | AudioChannelSet::AMBISONICS_ACN5 |
                 AudioChannelSet::AMBISONICS_ACN6 | AudioChannelSet::AMBISONICS_ACN7 | AudioChannelSet::AMBISONICS_ACN8,
    HOA_THIRD = HOA_SECOND | AudioChannelSet::AMBISONICS_ACN9 | AudioChannelSet::AMBISONICS_ACN10 |
                AudioChannelSet::AMBISONICS_ACN11 | AudioChannelSet::AMBISONICS_ACN12 |
                AudioChannelSet::AMBISONICS_ACN13 | AudioChannelSet::AMBISONICS_ACN14 |
                AudioChannelSet::AMBISONICS_ACN15,
};
#ifdef __cplusplus
}
#endif
#endif