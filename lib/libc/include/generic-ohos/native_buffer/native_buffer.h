/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
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

#ifndef NDK_INCLUDE_NATIVE_BUFFER_H_
#define NDK_INCLUDE_NATIVE_BUFFER_H_

/**
 * @addtogroup OH_NativeBuffer
 * @{
 *
 * @brief Provides the native buffer capability.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 9
 * @version 1.0
 */

/**
 * @file native_buffer.h
 *
 * @brief Defines the functions for obtaining and using a native buffer.
 *
 * @library libnative_buffer.so
 * @since 9
 * @version 1.0
 */

#include <stdint.h>
#include <native_window/external_window.h>

#ifdef __cplusplus
extern "C" {
#endif

struct OH_NativeBuffer;
typedef struct OH_NativeBuffer OH_NativeBuffer;

/**
 * @brief Indicates the usage of a native buffer.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 10
 * @version 1.0
 */
typedef enum OH_NativeBuffer_Usage {
    NATIVEBUFFER_USAGE_CPU_READ = (1ULL << 0),        /// < CPU read buffer */
    NATIVEBUFFER_USAGE_CPU_WRITE = (1ULL << 1),       /// < CPU write memory */
    NATIVEBUFFER_USAGE_MEM_DMA = (1ULL << 3),         /// < Direct memory access (DMA) buffer */
    NATIVEBUFFER_USAGE_HW_RENDER = (1ULL << 8),       /// < For GPU write case */
    NATIVEBUFFER_USAGE_HW_TEXTURE = (1ULL << 9),      /// < For GPU read case */
    NATIVEBUFFER_USAGE_CPU_READ_OFTEN = (1ULL << 16), /// < Often be mapped for direct CPU reads */
    NATIVEBUFFER_USAGE_ALIGNMENT_512 = (1ULL << 18),  /// < 512 bytes alignment */
} OH_NativeBuffer_Usage;

/**
 * @brief Indicates the format of a native buffer.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 10
 * @version 1.0
 */
typedef enum OH_NativeBuffer_Format {
    /**
     * CLUT8 format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_CLUT8 = 0,
    /**
     * CLUT1 format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_CLUT1,
    /**
     * CLUT4 format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_CLUT4,
    NATIVEBUFFER_PIXEL_FMT_RGB_565 = 3,               /// < RGB565 format */
    NATIVEBUFFER_PIXEL_FMT_RGBA_5658,                 /// < RGBA5658 format */
    NATIVEBUFFER_PIXEL_FMT_RGBX_4444,                 /// < RGBX4444 format */
    NATIVEBUFFER_PIXEL_FMT_RGBA_4444,                 /// < RGBA4444 format */
    NATIVEBUFFER_PIXEL_FMT_RGB_444,                   /// < RGB444 format */
    NATIVEBUFFER_PIXEL_FMT_RGBX_5551,                 /// < RGBX5551 format */
    NATIVEBUFFER_PIXEL_FMT_RGBA_5551,                 /// < RGBA5551 format */
    NATIVEBUFFER_PIXEL_FMT_RGB_555,                   /// < RGB555 format */
    NATIVEBUFFER_PIXEL_FMT_RGBX_8888,                 /// < RGBX8888 format */
    NATIVEBUFFER_PIXEL_FMT_RGBA_8888,                 /// < RGBA8888 format */
    NATIVEBUFFER_PIXEL_FMT_RGB_888,                   /// < RGB888 format */
    NATIVEBUFFER_PIXEL_FMT_BGR_565,                   /// < BGR565 format */
    NATIVEBUFFER_PIXEL_FMT_BGRX_4444,                 /// < BGRX4444 format */
    NATIVEBUFFER_PIXEL_FMT_BGRA_4444,                 /// < BGRA4444 format */
    NATIVEBUFFER_PIXEL_FMT_BGRX_5551,                 /// < BGRX5551 format */
    NATIVEBUFFER_PIXEL_FMT_BGRA_5551,                 /// < BGRA5551 format */
    NATIVEBUFFER_PIXEL_FMT_BGRX_8888,                 /// < BGRX8888 format */
    NATIVEBUFFER_PIXEL_FMT_BGRA_8888,                 /// < BGRA8888 format */
    /**
     * YUV422 interleaved format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_YUV_422_I,
    /**
     * YCBCR422 semi-plannar format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_YCBCR_422_SP,
    /**
     * YCRCB422 semi-plannar format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_YCRCB_422_SP,
    /**
     * YCBCR420 semi-plannar format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_YCBCR_420_SP,
    /**
     * YCRCB420 semi-plannar format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_YCRCB_420_SP,
    /**
     * YCBCR422 plannar format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_YCBCR_422_P,
    /**
     * YCRCB422 plannar format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_YCRCB_422_P,
    /**
     * YCBCR420 plannar format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_YCBCR_420_P,
    /**
     * YCRCB420 plannar format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_YCRCB_420_P,
    /**
     * YUYV422 packed format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_YUYV_422_PKG,
    /**
     * UYVY422 packed format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_UYVY_422_PKG,
    /**
     * YVYU422 packed format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_YVYU_422_PKG,
    /**
     * VYUY422 packed format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_VYUY_422_PKG,
    /**
     * RGBA_1010102 packed format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_RGBA_1010102,
    /**
     * YCBCR420 semi-planar 10bit packed format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_YCBCR_P010,
    /**
     * YCRCB420 semi-planar 10bit packed format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_YCRCB_P010,
    /**
     * Raw 10bit packed format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_RAW10,
    /**
     * vender mask format
     * @since 12
     */
    NATIVEBUFFER_PIXEL_FMT_VENDER_MASK = 0X7FFF0000,
    NATIVEBUFFER_PIXEL_FMT_BUTT = 0X7FFFFFFF          /// < Invalid pixel format */
} OH_NativeBuffer_Format;

/**
 * @brief Indicates the color space of a native buffer.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 11
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
 * @brief Indicates the transform type of a native buffer.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 12
 * @version 1.0
 */
typedef enum OH_NativeBuffer_TransformType {
    NATIVEBUFFER_ROTATE_NONE = 0,         /**< No rotation */
    NATIVEBUFFER_ROTATE_90,               /**< Rotation by 90 degrees */
    NATIVEBUFFER_ROTATE_180,              /**< Rotation by 180 degrees */
    NATIVEBUFFER_ROTATE_270,              /**< Rotation by 270 degrees */
    NATIVEBUFFER_FLIP_H,                  /**< Flip horizontally */
    NATIVEBUFFER_FLIP_V,                  /**< Flip vertically */
    NATIVEBUFFER_FLIP_H_ROT90,            /**< Flip horizontally and rotate 90 degrees */
    NATIVEBUFFER_FLIP_V_ROT90,            /**< Flip vertically and rotate 90 degrees */
    NATIVEBUFFER_FLIP_H_ROT180,           /**< Flip horizontally and rotate 180 degrees */
    NATIVEBUFFER_FLIP_V_ROT180,           /**< Flip vertically and rotate 180 degrees */
    NATIVEBUFFER_FLIP_H_ROT270,           /**< Flip horizontally and rotate 270 degrees */
    NATIVEBUFFER_FLIP_V_ROT270,           /**< Flip vertically and rotate 270 degrees */
} OH_NativeBuffer_TransformType;

/**
 * @brief Indicates the color gamut of a native buffer.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 12
 * @version 1.0
 */
typedef enum OH_NativeBuffer_ColorGamut {
    NATIVEBUFFER_COLOR_GAMUT_NATIVE = 0,            /**< Native or default */
    NATIVEBUFFER_COLOR_GAMUT_STANDARD_BT601 = 1,    /**< Standard BT601 */
    NATIVEBUFFER_COLOR_GAMUT_STANDARD_BT709 = 2,    /**< Standard BT709 */
    NATIVEBUFFER_COLOR_GAMUT_DCI_P3 = 3,            /**< DCI P3 */
    NATIVEBUFFER_COLOR_GAMUT_SRGB = 4,              /**< SRGB */
    NATIVEBUFFER_COLOR_GAMUT_ADOBE_RGB = 5,         /**< Adobe RGB */
    NATIVEBUFFER_COLOR_GAMUT_DISPLAY_P3 = 6,        /**< Display P3 */
    NATIVEBUFFER_COLOR_GAMUT_BT2020 = 7,            /**< BT2020 */
    NATIVEBUFFER_COLOR_GAMUT_BT2100_PQ = 8,         /**< BT2100 PQ */
    NATIVEBUFFER_COLOR_GAMUT_BT2100_HLG = 9,        /**< BT2100 HLG */
    NATIVEBUFFER_COLOR_GAMUT_DISPLAY_BT2020 = 10,   /**< Display BT2020 */
} OH_NativeBuffer_ColorGamut;

/**
 * @brief <b>OH_NativeBuffer</b> config. \n
 * Used to allocating new <b>OH_NativeBuffer</b> andquery parameters if existing ones.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 9
 * @version 1.0
 */
typedef struct {
    int32_t width;           ///< Width in pixels
    int32_t height;          ///< Height in pixels
    int32_t format;          ///< One of PixelFormat
    int32_t usage;           ///< Combination of buffer usage
    int32_t stride;          ///< the stride of memory
} OH_NativeBuffer_Config;

/**
 * @brief Holds info for a single image plane. \n
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 12
 * @version 1.0
 */
typedef struct {
    uint64_t offset;         ///< Offset in bytes of plane.
    uint32_t rowStride;      ///< Distance in bytes from the first value of one row of the image to the first value of the next row.
    uint32_t columnStride;   ///< Distance in bytes from the first value of one column of the image to the first value of the next column.
} OH_NativeBuffer_Plane;

/**
 * @brief Holds all image planes. \n
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @since 12
 * @version 1.0
 */
typedef struct {
    uint32_t planeCount;              ///< Number of distinct planes.
    OH_NativeBuffer_Plane planes[4];  ///< Array of image planes.
} OH_NativeBuffer_Planes;

/**
 * @brief Alloc a <b>OH_NativeBuffer</b> that matches the passed BufferRequestConfig. \n
 * A new <b>OH_NativeBuffer</b> instance is created each time this function is called.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @param config Indicates the pointer to a <b>BufferRequestConfig</b> instance.
 * @return Returns the pointer to the <b>OH_NativeBuffer</b> instance created if the operation is successful, \n
 * returns <b>NULL</b> otherwise.
 * @since 9
 * @version 1.0
 */
OH_NativeBuffer* OH_NativeBuffer_Alloc(const OH_NativeBuffer_Config* config);

/**
 * @brief Adds the reference count of a OH_NativeBuffer.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @param buffer Indicates the pointer to a <b>OH_NativeBuffer</b> instance.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 9
 * @version 1.0
 */
int32_t OH_NativeBuffer_Reference(OH_NativeBuffer *buffer);

/**
 * @brief Decreases the reference count of a OH_NativeBuffer and, when the reference count reaches 0, \n
 * destroys this OH_NativeBuffer.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @param buffer Indicates the pointer to a <b>OH_NativeBuffer</b> instance.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 9
 * @version 1.0
 */
int32_t OH_NativeBuffer_Unreference(OH_NativeBuffer *buffer);

/**
 * @brief Return a config of the OH_NativeBuffer in the passed OHNativeBufferConfig struct.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @param buffer Indicates the pointer to a <b>OH_NativeBuffer</b> instance.
 * @param config Indicates the pointer to the <b>NativeBufferConfig</b> of the buffer.
 * @return <b>void</b>
 * @since 9
 * @version 1.0
 */
void OH_NativeBuffer_GetConfig(OH_NativeBuffer *buffer, OH_NativeBuffer_Config* config);

/**
 * @brief Provide direct cpu access to the OH_NativeBuffer in the process's address space.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @param buffer Indicates the pointer to a <b>OH_NativeBuffer</b> instance.
 * @param virAddr Indicates the address of the <b>OH_NativeBuffer</b> in virtual memory.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 9
 * @version 1.0
 */

int32_t OH_NativeBuffer_Map(OH_NativeBuffer *buffer, void **virAddr);

/**
 * @brief Remove direct cpu access ability of the OH_NativeBuffer in the process's address space.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @param buffer Indicates the pointer to a <b>OH_NativeBuffer</b> instance.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 9
 * @version 1.0
 */
int32_t OH_NativeBuffer_Unmap(OH_NativeBuffer *buffer);

/**
 * @brief Get the systen wide unique sequence number of the OH_NativeBuffer.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @param buffer Indicates the pointer to a <b>OH_NativeBuffer</b> instance.
 * @return Returns the sequence number, which is unique for each OH_NativeBuffer.
 * @since 9
 * @version 1.0
 */
uint32_t OH_NativeBuffer_GetSeqNum(OH_NativeBuffer *buffer);

/**
 * @brief Set the color space of the OH_NativeBuffer.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @param buffer Indicates the pointer to a <b>OH_NativeBuffer</b> instance.
 * @param colorSpace Indicates the color space of native buffer, see <b>OH_NativeBuffer_ColorSpace</b>.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 11
 * @version 1.0
 */
int32_t OH_NativeBuffer_SetColorSpace(OH_NativeBuffer *buffer, OH_NativeBuffer_ColorSpace colorSpace);

/**
 * @brief Provide direct cpu access to the potentially multi-plannar OH_NativeBuffer in the process's address space.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @param buffer Indicates the pointer to a <b>OH_NativeBuffer</b> instance.
 * @param virAddr Indicates the address of the <b>OH_NativeBuffer</b> in virtual memory.
 * @param outPlanes Indicates all image planes that contain the pixel data.
 * @return Returns an error code, 0 is sucess, otherwise, failed.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeBuffer_MapPlanes(OH_NativeBuffer *buffer, void **virAddr, OH_NativeBuffer_Planes *outPlanes);

/**
 * @brief Converts an <b>OHNativeWindowBuffer</b> instance to an <b>OH_NativeBuffer</b>.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeBuffer
 * @param nativeWindowBuffer Indicates the pointer to a <b>OHNativeWindowBuffer</b> instance.
 * @param buffer Indicates the pointer to a <b>OH_NativeBuffer</b> pointer.
 * @return Returns an error code, 0 is sucess, otherwise, failed.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeBuffer_FromNativeWindowBuffer(OHNativeWindowBuffer *nativeWindowBuffer, OH_NativeBuffer **buffer);
#ifdef __cplusplus
}
#endif

/** @} */
#endif