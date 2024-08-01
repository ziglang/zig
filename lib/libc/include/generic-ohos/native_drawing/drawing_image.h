/*
 * Copyright (c) 2023-2024 Huawei Device Co., Ltd.
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

#ifndef C_INCLUDE_DRAWING_IMAGE_H
#define C_INCLUDE_DRAWING_IMAGE_H

/**
 * @addtogroup Drawing
 * @{
 *
 * @brief Provides functions such as 2D graphics rendering, text drawing, and image display.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 *
 * @since 12
 * @version 1.0
 */

/**
 * @file drawing_image.h
 *
 * @brief Declares functions related to the <b>image</b> object in the drawing module.
 *
 * @since 12
 * @version 1.0
 */

#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Creates an <b>OH_Drawing_Image</b> object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @return Returns the pointer to the <b>OH_Drawing_Image</b> object created.
 * @since 12
 * @version 1.0
 */
OH_Drawing_Image* OH_Drawing_ImageCreate(void);

/**
 * @brief Destroys an <b>OH_Drawing_Image</b> object and reclaims the memory occupied by the object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Image Indicates the pointer to an <b>OH_Drawing_Image</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_ImageDestroy(OH_Drawing_Image*);

/**
 * @brief Rebuilds an <b>OH_Drawing_Image</b> object, sharing or copying bitmap pixels.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Image Indicates the pointer to an <b>OH_Drawing_Image</b> object.
 * @param OH_Drawing_Bitmap Indicates the pointer to an <b>OH_Drawing_Bitmap</b> object.
 * @return Returns true if successed.
 * @since 12
 * @version 1.0
 */
bool OH_Drawing_ImageBuildFromBitmap(OH_Drawing_Image*, OH_Drawing_Bitmap*);

/**
 * @brief Gets pixel count in each row of image.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Image Indicates the pointer to an <b>OH_Drawing_Image</b> object.
 * @return Returns the width.
 * @since 12
 * @version 1.0
 */
int32_t OH_Drawing_ImageGetWidth(OH_Drawing_Image*);

/**
 * @brief Gets pixel row count of image.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Image Indicates the pointer to an <b>OH_Drawing_Image</b> object.
 * @return Returns the height.
 * @since 12
 * @version 1.0
 */
int32_t OH_Drawing_ImageGetHeight(OH_Drawing_Image*);

/**
 * @brief Gets the image info.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Image Indicates the pointer to an <b>OH_Drawing_Image</b> object.
 * @param OH_Drawing_Image_Info Indicates the pointer to an <b>OH_Drawing_Image_Info</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_ImageGetImageInfo(OH_Drawing_Image*, OH_Drawing_Image_Info*);

#ifdef __cplusplus
}
#endif
/** @} */
#endif