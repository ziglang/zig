/*
 * Copyright (c) 2021-2024 Huawei Device Co., Ltd.
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

#ifndef C_INCLUDE_DRAWING_BITMAP_H
#define C_INCLUDE_DRAWING_BITMAP_H

/**
 * @addtogroup Drawing
 * @{
 *
 * @brief Provides functions such as 2D graphics rendering, text drawing, and image display.
 * 
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 *
 * @since 8
 * @version 1.0
 */

/**
 * @file drawing_bitmap.h
 *
 * @brief Declares functions related to the <b>bitmap</b> object in the drawing module.
 *
 * @since 8
 * @version 1.0
 */

#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines the pixel format of a bitmap, including the color type and alpha type.
 * 
 * @since 8
 * @version 1.0
 */
typedef struct {
    /** Storage format of bitmap pixels */
    OH_Drawing_ColorFormat colorFormat;
    /** Alpha format of bitmap pixels */
    OH_Drawing_AlphaFormat alphaFormat;
} OH_Drawing_BitmapFormat;

/**
 * @brief Creates an <b>OH_Drawing_Bitmap</b> object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @return Returns the pointer to the <b>OH_Drawing_Bitmap</b> object created.
 * @since 8
 * @version 1.0
 */
OH_Drawing_Bitmap* OH_Drawing_BitmapCreate(void);

/**
 * @brief Destroys an <b>OH_Drawing_Bitmap</b> object and reclaims the memory occupied by the object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Bitmap Indicates the pointer to an <b>OH_Drawing_Bitmap</b> object.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_BitmapDestroy(OH_Drawing_Bitmap*);

/**
 * @brief Creates an <b>OH_Drawing_Bitmap</b> object with <b>OH_Drawing_Image_Info</b> object
 * and sets the mem address or pixel storage.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Image_Info Indicates the pointer to an <b>OH_Drawing_Image_Info</b> object.
 * @param pixels the pointer to memory address or pixel storage.
 * @param rowBytes size of pixel row or larger.
 * @return Returns the pointer to the <b>OH_Drawing_Bitmap</b> object created.
 * @since 12
 * @version 1.0
 */
OH_Drawing_Bitmap* OH_Drawing_BitmapCreateFromPixels(OH_Drawing_Image_Info*, void* pixels, uint32_t rowBytes);

/**
 * @brief Initializes the width and height of an <b>OH_Drawing_Bitmap</b> object
 * and sets the pixel format for the bitmap.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Bitmap Indicates the pointer to an <b>OH_Drawing_Bitmap</b> object.
 * @param width Indicates the width of the bitmap to be initialized.
 * @param height Indicates the height of the bitmap to be initialized.
 * @param OH_Drawing_BitmapFormat Indicates the pixel format of the bitmap to be initialized,
 *                                including the pixel color type and alpha type.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_BitmapBuild(
    OH_Drawing_Bitmap*, const uint32_t width, const uint32_t height, const OH_Drawing_BitmapFormat*);

/**
 * @brief Obtains the width of a bitmap.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Bitmap Indicates the pointer to an <b>OH_Drawing_Bitmap</b> object.
 * @return Returns the width.
 * @since 8
 * @version 1.0
 */
uint32_t OH_Drawing_BitmapGetWidth(OH_Drawing_Bitmap*);

/**
 * @brief Obtains the height of a bitmap.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Bitmap Indicates the pointer to an <b>OH_Drawing_Bitmap</b> object.
 * @return Returns the height.
 * @since 8
 * @version 1.0
 */
uint32_t OH_Drawing_BitmapGetHeight(OH_Drawing_Bitmap*);

/**
 * @brief Obtains the color format of a bitmap.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Bitmap Indicates the pointer to an <b>OH_Drawing_Bitmap</b> object.
 * @return Returns the bitmap color format.
 * @since 12
 * @version 1.0
 */
OH_Drawing_ColorFormat OH_Drawing_BitmapGetColorFormat(OH_Drawing_Bitmap*);

/**
 * @brief Obtains the alpha format of a bitmap.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Bitmap Indicates the pointer to an <b>OH_Drawing_Bitmap</b> object.
 * @return Returns the bitmap alpha format.
 * @since 12
 * @version 1.0
 */
OH_Drawing_AlphaFormat OH_Drawing_BitmapGetAlphaFormat(OH_Drawing_Bitmap*);

/**
 * @brief Obtains the pixel address of a bitmap. You can use this address to obtain the pixel data of the bitmap.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Bitmap Indicates the pointer to an <b>OH_Drawing_Bitmap</b> object.
 * @return Returns the pixel address.
 * @since 8
 * @version 1.0
 */
void* OH_Drawing_BitmapGetPixels(OH_Drawing_Bitmap*);

/**
 * @brief Gets the image info.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Bitmap Indicates the pointer to an <b>OH_Drawing_Bitmap</b> object.
 * @param OH_Drawing_Image_Info Indicates the pointer to an <b>OH_Drawing_Image_Info</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_BitmapGetImageInfo(OH_Drawing_Bitmap*, OH_Drawing_Image_Info*);

/**
 * @brief Copies a rect of pixels from bitmap to dstPixels. Copy starts at (srcX, srcY),
 * and does not exceed bitmap width and height.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Bitmap Indicates the pointer to an <b>OH_Drawing_Bitmap</b> object.
 * @param dstInfo Indicates the pointer to an <b>OH_Drawing_Image_Info</b> object.
 * @param dstPixels Destination pixel storage.
 * @param dstRowBytes Destination row length.
 * @param srcX Column index whose absolute value is less than width.
 * @param srcY Row index whose absolute value is less than height.
 * @return Returns true if pixels are copied to dstPixels.
 * @since 12
 * @version 1.0
 */
bool OH_Drawing_BitmapReadPixels(OH_Drawing_Bitmap*, const OH_Drawing_Image_Info* dstInfo,
    void* dstPixels, size_t dstRowBytes, int32_t srcX, int32_t srcY);
#ifdef __cplusplus
}
#endif
/** @} */
#endif