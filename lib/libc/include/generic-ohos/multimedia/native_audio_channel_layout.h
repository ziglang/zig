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

/**
 * @addtogroup MediaFoundation
 * @{
 *
 * @brief Provides APIs for media foundation.
 *
 * @since 11
 */

/**
 * @file native_audio_channel_layout.h
 *
 * @brief The channel layout indicates the appearance and order of the speakers for recording or playback.
 *
 * @library NA
 * @syscap SystemCapability.Multimedia.Media.Core
 * @since 11
 */

#ifndef NATIVE_AUDIO_CHANNEL_LAYOUT_H
#define NATIVE_AUDIO_CHANNEL_LAYOUT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Audio Channel Set
 *
 * A 64-bit integer with bits set for each channel.
 * @syscap SystemCapability.Multimedia.Media.Core
 * @since 11
 */
typedef enum OH_AudioChannelSet {
    /** Channel set For FRONT-LEFT position */
    CH_SET_FRONT_LEFT = 1ULL << 0U,

    /** Channel set For FRONT_RIGHT position */
    CH_SET_FRONT_RIGHT = 1ULL << 1U,

    /** Channel set For FRONT_CENTER position */
    CH_SET_FRONT_CENTER = 1ULL << 2U,

    /** Channel set For LOW_FREQUENCY position */
    CH_SET_LOW_FREQUENCY = 1ULL << 3U,

    /** Channel set For BACK_LEFT position */
    CH_SET_BACK_LEFT = 1ULL << 4U,

    /** Channel set For BACK_RIGHT position */
    CH_SET_BACK_RIGHT = 1ULL << 5U,

    /** Channel set For FRONT_LEFT_OF_CENTER position */
    CH_SET_FRONT_LEFT_OF_CENTER = 1ULL << 6U,

    /** Channel set For FRONT_RIGHT_OF_CENTER position */
    CH_SET_FRONT_RIGHT_OF_CENTER = 1ULL << 7U,

    /** Channel set For BACK_CENTER position */
    CH_SET_BACK_CENTER = 1ULL << 8U,

    /** Channel set For SIDE_LEFT position */
    CH_SET_SIDE_LEFT = 1ULL << 9U,

    /** Channel set For SIDE_RIGHT position */
    CH_SET_SIDE_RIGHT = 1ULL << 10U,

    /** Channel set For TOP_CENTER position */
    CH_SET_TOP_CENTER = 1ULL << 11U,

    /** Channel set For TOP_FRONT_LEFT position */
    CH_SET_TOP_FRONT_LEFT = 1ULL << 12U,

    /** Channel set For TOP_FRONT_CENTER position */
    CH_SET_TOP_FRONT_CENTER = 1ULL << 13U,

    /** Channel set For TOP_FRONT_RIGHT position */
    CH_SET_TOP_FRONT_RIGHT = 1ULL << 14U,

    /** Channel set For TOP_BACK_LEFT position */
    CH_SET_TOP_BACK_LEFT = 1ULL << 15U,

    /** Channel set For TOP_BACK_CENTER position */
    CH_SET_TOP_BACK_CENTER = 1ULL << 16U,

    /** Channel set For TOP_BACK_RIGHT position */
    CH_SET_TOP_BACK_RIGHT = 1ULL << 17U,

    /** Channel set For STEREO_LEFT position */
    CH_SET_STEREO_LEFT = 1ULL << 29U,

    /** Channel set For STEREO_RIGHT position */
    CH_SET_STEREO_RIGHT = 1ULL << 30U,

    /** Channel set For WIDE_LEFT position */
    CH_SET_WIDE_LEFT = 1ULL << 31U,

    /** Channel set For WIDE_RIGHT position */
    CH_SET_WIDE_RIGHT = 1ULL << 32U,

    /** Channel set For SURROUND_DIRECT_LEFT position */
    CH_SET_SURROUND_DIRECT_LEFT = 1ULL << 33U,

    /** Channel set For SURROUND_DIRECT_RIGHT position */
    CH_SET_SURROUND_DIRECT_RIGHT = 1ULL << 34U,

    /** Channel set For LOW_FREQUENCY_2 position */
    CH_SET_LOW_FREQUENCY_2 = 1ULL << 35U,

    /** Channel set For TOP_SIDE_LEFT position */
    CH_SET_TOP_SIDE_LEFT = 1ULL << 36U,

    /** Channel set For TOP_SIDE_RIGHT position */
    CH_SET_TOP_SIDE_RIGHT = 1ULL << 37U,

    /** Channel set For BOTTOM_FRONT_CENTER position */
    CH_SET_BOTTOM_FRONT_CENTER = 1ULL << 38U,

    /** Channel set For BOTTOM_FRONT_LEFT position */
    CH_SET_BOTTOM_FRONT_LEFT = 1ULL << 39U,

    /** Channel set For BOTTOM_FRONT_RIGHT position */
    CH_SET_BOTTOM_FRONT_RIGHT = 1ULL << 40U
} OH_AudioChannelSet;

/**
 * @brief Ambisonic attribute set.
 *
 * A set of 64-bit integers indicate the ambisonic attributes.
 * @syscap SystemCapability.Multimedia.Media.Core
 * @since 11
 */
typedef enum OH_AmbAttributeSet {
    /** Ambisonic attribute: order 1 */
    AMB_ORD_1 = 1ULL << 0U,

    /** Ambisonic attribute: order 2 */
    AMB_ORD_2 = 2ULL << 0U,

    /** Ambisonic attribute: order 3 */
    AMB_ORD_3 = 3ULL << 0U,

    /** Ambisonic attribute: ACN Component Ordering */
    AMB_COM_ACN = 0ULL << 8U,

    /** Ambisonic attribute: FUMA Component Ordering */
    AMB_COM_FUMA = 1ULL << 8U,

    /** Ambisonic attribute: N3D Normalization */
    AMB_NOR_N3D = 0ULL << 12U,

    /** Ambisonic attribute: SN3D Normalization */
    AMB_NOR_SN3D = 1ULL << 12U,

    /** Channel layout: Ambisonic mode */
    AMB_MODE = 1ULL << 44U
} OH_AmbAttributeSet;

/**
 * @brief Audio Channel Layout
 *
 * A 64-bit integer indicates that the appearance and order of the speakers for recording or playback.
 * @syscap SystemCapability.Multimedia.Media.Core
 * @since 11
 */
typedef enum OH_AudioChannelLayout {
    /** Unknown Channel Layout */
    CH_LAYOUT_UNKNOWN = 0ULL,

    /** Channel Layout For Mono, 1 channel in total */
    CH_LAYOUT_MONO = CH_SET_FRONT_CENTER,

    /** Channel Layout For Stereo, 2 channels in total */
    CH_LAYOUT_STEREO = CH_SET_FRONT_LEFT | CH_SET_FRONT_RIGHT,

    /** Channel Layout For Stereo-Downmix, 2 channels in total */
    CH_LAYOUT_STEREO_DOWNMIX = CH_SET_STEREO_LEFT | CH_SET_STEREO_RIGHT,

    /** Channel Layout For 2.1, 3 channels in total */
    CH_LAYOUT_2POINT1 = CH_LAYOUT_STEREO | CH_SET_LOW_FREQUENCY,

    /** Channel Layout For 3.0, 3 channels in total */
    CH_LAYOUT_3POINT0 = CH_LAYOUT_STEREO | CH_SET_BACK_CENTER,

    /** Channel Layout For Surround, 3 channels in total */
    CH_LAYOUT_SURROUND = CH_LAYOUT_STEREO | CH_SET_FRONT_CENTER,

    /** Channel Layout For 3.1, 4 channels in total */
    CH_LAYOUT_3POINT1 = CH_LAYOUT_SURROUND | CH_SET_LOW_FREQUENCY,

    /** Channel Layout For 4.0, 4 channels in total */
    CH_LAYOUT_4POINT0 = CH_LAYOUT_SURROUND | CH_SET_BACK_CENTER,

    /** Channel Layout For Quad-Side, 4 channels in total */
    CH_LAYOUT_QUAD_SIDE = CH_LAYOUT_STEREO | CH_SET_SIDE_LEFT | CH_SET_SIDE_RIGHT,

    /** Channel Layout For Quad, 4 channels in total */
    CH_LAYOUT_QUAD = CH_LAYOUT_STEREO | CH_SET_BACK_LEFT | CH_SET_BACK_RIGHT,

    /** Channel Layout For 2.0.2, 4 channels in total */
    CH_LAYOUT_2POINT0POINT2 = CH_LAYOUT_STEREO | CH_SET_TOP_SIDE_LEFT | CH_SET_TOP_SIDE_RIGHT,

    /** Channel Layout For ORDER1-ACN-N3D First Order Ambisonic(FOA), 4 channels in total */
    CH_LAYOUT_AMB_ORDER1_ACN_N3D = AMB_MODE | AMB_ORD_1 | AMB_COM_ACN | AMB_NOR_N3D,

    /** Channel Layout For ORDER1-ACN-SN3D FOA, 4 channels in total */
    CH_LAYOUT_AMB_ORDER1_ACN_SN3D = AMB_MODE | AMB_ORD_1 | AMB_COM_ACN | AMB_NOR_SN3D,

    /** Channel Layout For ORDER1-FUMA FOA, 4 channels in total */
    CH_LAYOUT_AMB_ORDER1_FUMA = AMB_MODE | AMB_ORD_1 | AMB_COM_FUMA,

    /** Channel Layout For 4.1, 5 channels in total */
    CH_LAYOUT_4POINT1 = CH_LAYOUT_4POINT0 | CH_SET_LOW_FREQUENCY,

    /** Channel Layout For 5.0, 5 channels in total */
    CH_LAYOUT_5POINT0 = CH_LAYOUT_SURROUND | CH_SET_SIDE_LEFT | CH_SET_SIDE_RIGHT,

    /** Channel Layout For 5.0-Back, 5 channels in total */
    CH_LAYOUT_5POINT0_BACK = CH_LAYOUT_SURROUND | CH_SET_BACK_LEFT | CH_SET_BACK_RIGHT,

    /** Channel Layout For 2.1.2, 5 channels in total */
    CH_LAYOUT_2POINT1POINT2 = CH_LAYOUT_2POINT0POINT2 | CH_SET_LOW_FREQUENCY,

    /** Channel Layout For 3.0.2, 5 channels in total */
    CH_LAYOUT_3POINT0POINT2 = CH_LAYOUT_2POINT0POINT2 | CH_SET_FRONT_CENTER,

    /** Channel Layout For 5.1, 6 channels in total */
    CH_LAYOUT_5POINT1 = CH_LAYOUT_5POINT0 | CH_SET_LOW_FREQUENCY,

    /** Channel Layout For 5.1-Back, 6 channels in total */
    CH_LAYOUT_5POINT1_BACK = CH_LAYOUT_5POINT0_BACK | CH_SET_LOW_FREQUENCY,

    /** Channel Layout For 6.0, 6 channels in total */
    CH_LAYOUT_6POINT0 = CH_LAYOUT_5POINT0 | CH_SET_BACK_CENTER,

    /** Channel Layout For 3.1.2, 6 channels in total */
    CH_LAYOUT_3POINT1POINT2 = CH_LAYOUT_3POINT1 | CH_SET_TOP_FRONT_LEFT | CH_SET_TOP_FRONT_RIGHT,

    /** Channel Layout For 6.0-Front, 6 channels in total */
    CH_LAYOUT_6POINT0_FRONT = CH_LAYOUT_QUAD_SIDE | CH_SET_FRONT_LEFT_OF_CENTER | CH_SET_FRONT_RIGHT_OF_CENTER,

    /** Channel Layout For Hexagonal, 6 channels in total */
    CH_LAYOUT_HEXAGONAL = CH_LAYOUT_5POINT0_BACK | CH_SET_BACK_CENTER,

    /** Channel Layout For 6.1, 7 channels in total */
    CH_LAYOUT_6POINT1 = CH_LAYOUT_5POINT1 | CH_SET_BACK_CENTER,

    /** Channel Layout For 6.1-Back, 7 channels in total */
    CH_LAYOUT_6POINT1_BACK = CH_LAYOUT_5POINT1_BACK | CH_SET_BACK_CENTER,

    /** Channel Layout For 6.1-Front, 7 channels in total */
    CH_LAYOUT_6POINT1_FRONT = CH_LAYOUT_6POINT0_FRONT | CH_SET_LOW_FREQUENCY,

    /** Channel Layout For 7.0, 7 channels in total */
    CH_LAYOUT_7POINT0 = CH_LAYOUT_5POINT0 | CH_SET_BACK_LEFT | CH_SET_BACK_RIGHT,

    /** Channel Layout For 7.0-Front, 7 channels in total */
    CH_LAYOUT_7POINT0_FRONT = CH_LAYOUT_5POINT0 | CH_SET_FRONT_LEFT_OF_CENTER | CH_SET_FRONT_RIGHT_OF_CENTER,

    /** Channel Layout For 7.1, 8 channels in total */
    CH_LAYOUT_7POINT1 = CH_LAYOUT_5POINT1 | CH_SET_BACK_LEFT | CH_SET_BACK_RIGHT,

    /** Channel Layout For Octagonal, 8 channels in total */
    CH_LAYOUT_OCTAGONAL = CH_LAYOUT_5POINT0 | CH_SET_BACK_LEFT | CH_SET_BACK_CENTER | CH_SET_BACK_RIGHT,

    /** Channel Layout For 5.1.2, 8 channels in total */
    CH_LAYOUT_5POINT1POINT2 = CH_LAYOUT_5POINT1 | CH_SET_TOP_SIDE_LEFT | CH_SET_TOP_SIDE_RIGHT,

    /** Channel Layout For 7.1-Wide, 8 channels in total */
    CH_LAYOUT_7POINT1_WIDE = CH_LAYOUT_5POINT1 | CH_SET_FRONT_LEFT_OF_CENTER | CH_SET_FRONT_RIGHT_OF_CENTER,

    /** Channel Layout For 7.1-Wide-Back, 8 channels in total */
    CH_LAYOUT_7POINT1_WIDE_BACK = CH_LAYOUT_5POINT1_BACK | CH_SET_FRONT_LEFT_OF_CENTER | CH_SET_FRONT_RIGHT_OF_CENTER,

    /** Channel Layout For ORDER2-ACN-N3D Higher Order Ambisonics(HOA), 9 channels in total */
    CH_LAYOUT_AMB_ORDER2_ACN_N3D = AMB_MODE | AMB_ORD_2 | AMB_COM_ACN | AMB_NOR_N3D,

    /** Channel Layout For ORDER2-ACN-SN3D HOA, 9 channels in total */
    CH_LAYOUT_AMB_ORDER2_ACN_SN3D = AMB_MODE | AMB_ORD_2 | AMB_COM_ACN | AMB_NOR_SN3D,

    /** Channel Layout For ORDER2-FUMA HOA, 9 channels in total */
    CH_LAYOUT_AMB_ORDER2_FUMA = AMB_MODE | AMB_ORD_2 | AMB_COM_FUMA,

    /** Channel Layout For 5.1.4, 10 channels in total */
    CH_LAYOUT_5POINT1POINT4 = CH_LAYOUT_5POINT1 | CH_SET_TOP_FRONT_LEFT | CH_SET_TOP_FRONT_RIGHT |
                              CH_SET_TOP_BACK_LEFT | CH_SET_TOP_BACK_RIGHT,

    /** Channel Layout For 7.1.2, 10 channels in total */
    CH_LAYOUT_7POINT1POINT2 = CH_LAYOUT_7POINT1 | CH_SET_TOP_SIDE_LEFT | CH_SET_TOP_SIDE_RIGHT,

    /** Channel Layout For 7.1.4, 12 channels in total */
    CH_LAYOUT_7POINT1POINT4 = CH_LAYOUT_7POINT1 | CH_SET_TOP_FRONT_LEFT | CH_SET_TOP_FRONT_RIGHT |
                              CH_SET_TOP_BACK_LEFT | CH_SET_TOP_BACK_RIGHT,

    /** Channel Layout For 10.2, 12 channels in total */
    CH_LAYOUT_10POINT2 = CH_SET_FRONT_LEFT | CH_SET_FRONT_RIGHT | CH_SET_FRONT_CENTER | CH_SET_TOP_FRONT_LEFT |
                         CH_SET_TOP_FRONT_RIGHT | CH_SET_BACK_LEFT | CH_SET_BACK_RIGHT | CH_SET_BACK_CENTER |
                         CH_SET_SIDE_LEFT | CH_SET_SIDE_RIGHT | CH_SET_WIDE_LEFT | CH_SET_WIDE_RIGHT,

    /** Channel Layout For 9.1.4, 14 channels in total */
    CH_LAYOUT_9POINT1POINT4 = CH_LAYOUT_7POINT1POINT4 | CH_SET_WIDE_LEFT | CH_SET_WIDE_RIGHT,

    /** Channel Layout For 9.1.6, 16 channels in total */
    CH_LAYOUT_9POINT1POINT6 = CH_LAYOUT_9POINT1POINT4 | CH_SET_TOP_SIDE_LEFT | CH_SET_TOP_SIDE_RIGHT,

    /** Channel Layout For Hexadecagonal, 16 channels in total */
    CH_LAYOUT_HEXADECAGONAL = CH_LAYOUT_OCTAGONAL | CH_SET_WIDE_LEFT | CH_SET_WIDE_RIGHT | CH_SET_TOP_BACK_LEFT |
                              CH_SET_TOP_BACK_RIGHT | CH_SET_TOP_BACK_CENTER | CH_SET_TOP_FRONT_CENTER |
                              CH_SET_TOP_FRONT_LEFT | CH_SET_TOP_FRONT_RIGHT,

    /** Channel Layout For ORDER3-ACN-N3D HOA, 16 channels in total */
    CH_LAYOUT_AMB_ORDER3_ACN_N3D = AMB_MODE | AMB_ORD_3 | AMB_COM_ACN | AMB_NOR_N3D,

    /** Channel Layout For ORDER3-ACN-SN3D HOA, 16 channels in total */
    CH_LAYOUT_AMB_ORDER3_ACN_SN3D = AMB_MODE | AMB_ORD_3 | AMB_COM_ACN | AMB_NOR_SN3D,

    /** Channel Layout For ORDER3-FUMA HOA, 16 channels in total */
    CH_LAYOUT_AMB_ORDER3_FUMA = AMB_MODE | AMB_ORD_3 | AMB_COM_FUMA,

    /** Channel Layout For 22.2, 24 channels in total */
    CH_LAYOUT_22POINT2 = CH_LAYOUT_7POINT1POINT4 | CH_SET_FRONT_LEFT_OF_CENTER | CH_SET_FRONT_RIGHT_OF_CENTER |
                         CH_SET_BACK_CENTER | CH_SET_TOP_CENTER | CH_SET_TOP_FRONT_CENTER | CH_SET_TOP_BACK_CENTER |
                         CH_SET_TOP_SIDE_LEFT | CH_SET_TOP_SIDE_RIGHT | CH_SET_BOTTOM_FRONT_LEFT |
                         CH_SET_BOTTOM_FRONT_RIGHT | CH_SET_BOTTOM_FRONT_CENTER | CH_SET_LOW_FREQUENCY_2
} OH_AudioChannelLayout;

#ifdef __cplusplus
}
#endif

#endif // NATIVE_AUDIO_CHANNEL_LAYOUT_H

/** @} */