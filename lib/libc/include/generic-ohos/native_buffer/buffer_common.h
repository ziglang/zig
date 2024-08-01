/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

#ifndef NDK_INCLUDE_BUFFER_COMMON_H_
#define NDK_INCLUDE_BUFFER_COMMON_H_

/**
 * @addtogroup OH_NativeBuffer
 * @{
 *
 * @brief Provides the common types for native buffer.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 12
 * @version 1.0
 */

/**
 * @file native_buffer.h
 *
 * @brief Defines the common types for native buffer.
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @library libnative_buffer.so
 * @since 12
 * @version 1.0
 */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Indicates the color space of a native buffer.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 11
 * @version 1.0
 */
/**
 * @brief Indicates the color space of a native buffer.
 * Move from native_buffer.h to native_common.h
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 12
 * @version 1.0
 */
typedef enum OH_NativeBuffer_ColorSpace {
    /** None color space */
    OH_COLORSPACE_NONE,
    /** COLORPRIMARIES_BT601_P | (TRANSFUNC_BT709 << 8) | (MATRIX_BT601_P << 16) | (RANGE_FULL << 21) */
    OH_COLORSPACE_BT601_EBU_FULL,
    /** COLORPRIMARIES_BT601_N | (TRANSFUNC_BT709 << 8) | (MATRIX_BT601_N << 16) | (RANGE_FULL << 21)*/
    OH_COLORSPACE_BT601_SMPTE_C_FULL,
    /** COLORPRIMARIES_BT709 | (TRANSFUNC_BT709 << 8) | (MATRIX_BT709 << 16) | (RANGE_FULL << 21) */
    OH_COLORSPACE_BT709_FULL,
    /** COLORPRIMARIES_BT2020 | (TRANSFUNC_HLG << 8) | (MATRIX_BT2020 << 16) | (RANGE_FULL << 21) */
    OH_COLORSPACE_BT2020_HLG_FULL,
    /** COLORPRIMARIES_BT2020 | (TRANSFUNC_PQ << 8) | (MATRIX_BT2020 << 16) | (RANGE_FULL << 21) */
    OH_COLORSPACE_BT2020_PQ_FULL,
    /** COLORPRIMARIES_BT601_P | (TRANSFUNC_BT709 << 8) | (MATRIX_BT601_P << 16) | (RANGE_LIMITED << 21) */
    OH_COLORSPACE_BT601_EBU_LIMIT,
    /** COLORPRIMARIES_BT601_N | (TRANSFUNC_BT709 << 8) | (MATRIX_BT601_N << 16) | (RANGE_LIMITED << 21) */
    OH_COLORSPACE_BT601_SMPTE_C_LIMIT,
    /** COLORPRIMARIES_BT709 | (TRANSFUNC_BT709 << 8) | (MATRIX_BT709 << 16) | (RANGE_LIMITED << 21) */
    OH_COLORSPACE_BT709_LIMIT,
    /** COLORPRIMARIES_BT2020 | (TRANSFUNC_HLG << 8) | (MATRIX_BT2020 << 16) | (RANGE_LIMITED << 21) */
    OH_COLORSPACE_BT2020_HLG_LIMIT,
    /** COLORPRIMARIES_BT2020 | (TRANSFUNC_PQ << 8) | (MATRIX_BT2020 << 16) | (RANGE_LIMITED << 21) */
    OH_COLORSPACE_BT2020_PQ_LIMIT,
    /** COLORPRIMARIES_SRGB | (TRANSFUNC_SRGB << 8) | (MATRIX_BT601_N << 16) | (RANGE_FULL << 21) */
    OH_COLORSPACE_SRGB_FULL,
    /** COLORPRIMARIES_P3_D65 | (TRANSFUNC_SRGB << 8) | (MATRIX_P3 << 16) | (RANGE_FULL << 21) */
    OH_COLORSPACE_P3_FULL,
    /** COLORPRIMARIES_P3_D65 | (TRANSFUNC_HLG << 8) | (MATRIX_P3 << 16) | (RANGE_FULL << 21) */
    OH_COLORSPACE_P3_HLG_FULL,
    /** COLORPRIMARIES_P3_D65 | (TRANSFUNC_PQ << 8) | (MATRIX_P3 << 16) | (RANGE_FULL << 21) */
    OH_COLORSPACE_P3_PQ_FULL,
    /** COLORPRIMARIES_ADOBERGB | (TRANSFUNC_ADOBERGB << 8) | (MATRIX_ADOBERGB << 16) | (RANGE_FULL << 21) */
    OH_COLORSPACE_ADOBERGB_FULL,
    /** COLORPRIMARIES_SRGB | (TRANSFUNC_SRGB << 8) | (MATRIX_BT601_N << 16) | (RANGE_LIMITED << 21) */
    OH_COLORSPACE_SRGB_LIMIT,
    /** COLORPRIMARIES_P3_D65 | (TRANSFUNC_SRGB << 8) | (MATRIX_P3 << 16) | (RANGE_LIMITED << 21) */
    OH_COLORSPACE_P3_LIMIT,
    /** COLORPRIMARIES_P3_D65 | (TRANSFUNC_HLG << 8) | (MATRIX_P3 << 16) | (RANGE_LIMITED << 21) */
    OH_COLORSPACE_P3_HLG_LIMIT,
    /** COLORPRIMARIES_P3_D65 | (TRANSFUNC_PQ << 8) | (MATRIX_P3 << 16) | (RANGE_LIMITED << 21) */
    OH_COLORSPACE_P3_PQ_LIMIT,
    /** COLORPRIMARIES_ADOBERGB | (TRANSFUNC_ADOBERGB << 8) | (MATRIX_ADOBERGB << 16) | (RANGE_LIMITED << 21) */
    OH_COLORSPACE_ADOBERGB_LIMIT,
    /** COLORPRIMARIES_SRGB | (TRANSFUNC_LINEAR << 8) */
    OH_COLORSPACE_LINEAR_SRGB,
    /** equal to OH_COLORSPACE_LINEAR_SRGB */
    OH_COLORSPACE_LINEAR_BT709,
    /** COLORPRIMARIES_P3_D65 | (TRANSFUNC_LINEAR << 8) */
    OH_COLORSPACE_LINEAR_P3,
    /** COLORPRIMARIES_BT2020 | (TRANSFUNC_LINEAR << 8) */
    OH_COLORSPACE_LINEAR_BT2020,
    /** equal to OH_COLORSPACE_SRGB_FULL */
    OH_COLORSPACE_DISPLAY_SRGB,
    /** equal to OH_COLORSPACE_P3_FULL */
    OH_COLORSPACE_DISPLAY_P3_SRGB,
    /** equal to OH_COLORSPACE_P3_HLG_FULL */
    OH_COLORSPACE_DISPLAY_P3_HLG,
    /** equal to OH_COLORSPACE_P3_PQ_FULL */
    OH_COLORSPACE_DISPLAY_P3_PQ,
    /** COLORPRIMARIES_BT2020 | (TRANSFUNC_SRGB << 8) | (MATRIX_BT2020 << 16) | (RANGE_FULL << 21) */
    OH_COLORSPACE_DISPLAY_BT2020_SRGB,
    /** equal to OH_COLORSPACE_BT2020_HLG_FULL */
    OH_COLORSPACE_DISPLAY_BT2020_HLG,
    /** equal to OH_COLORSPACE_BT2020_PQ_FULL */
    OH_COLORSPACE_DISPLAY_BT2020_PQ,
} OH_NativeBuffer_ColorSpace;

/**
 * @brief Indicates the HDR metadata type of a native buffer.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 12
 * @version 1.0
 */
typedef enum OH_NativeBuffer_MetadataType {
    /** HLG */
    OH_VIDEO_HDR_HLG,
    /** HDR10 */
    OH_VIDEO_HDR_HDR10,
    /** HDR VIVID */
    OH_VIDEO_HDR_VIVID
} OH_NativeBuffer_MetadataType;

/**
 * @brief Indicates the color x and y.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 12
 * @version 1.0
 */
typedef struct OH_NativeBuffer_ColorXY {
    /** color X */
    float x;
    /** color Y */
    float y;
} OH_NativeBuffer_ColorXY;

/**
 * @brief Indicates the smpte2086 metadata.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 12
 * @version 1.0
 */
typedef struct OH_NativeBuffer_Smpte2086 {
    /** primary red */
    OH_NativeBuffer_ColorXY displayPrimaryRed;
    /** primary green */
    OH_NativeBuffer_ColorXY displayPrimaryGreen;
    /** primary blue */
    OH_NativeBuffer_ColorXY displayPrimaryBlue;
    /** white point */
    OH_NativeBuffer_ColorXY whitePoint;
    /** max luminance */
    float maxLuminance;
    /** min luminance */
    float minLuminance;
} OH_NativeBuffer_Smpte2086;

/**
 * @brief Indicates the cta861.3 metadata.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 12
 * @version 1.0
 */
typedef struct OH_NativeBuffer_Cta861 {
    /** max content lightLevel */
    float maxContentLightLevel;
    /** max frame average light level */
    float maxFrameAverageLightLevel;
} OH_NativeBuffer_Cta861;

/**
 * @brief Indicates the HDR static metadata.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 12
 * @version 1.0
 */
typedef struct OH_NativeBuffer_StaticMetadata {
    /** smpte 2086 metadata*/
    OH_NativeBuffer_Smpte2086 smpte2086;
    /** CTA-861.3 metadata*/
    OH_NativeBuffer_Cta861 cta861;
} OH_NativeBuffer_StaticMetadata;

/**
 * @brief Indicates the HDR metadata key of a native buffer.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 12
 * @version 1.0
 */
typedef enum OH_NativeBuffer_MetadataKey {
    /** value: OH_NativeBuffer_MetadataType*/
    OH_HDR_METADATA_TYPE,
    /** value: OH_NativeBuffer_StaticMetadata*/
    OH_HDR_STATIC_METADATA,
    /** byte stream of SEI in video stream*/
    OH_HDR_DYNAMIC_METADATA
} OH_NativeBuffer_MetadataKey;

#ifdef __cplusplus
}
#endif

/** @} */
#endif