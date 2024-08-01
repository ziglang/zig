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

#ifndef C_INCLUDE_DRAWING_ROUND_RECT_H
#define C_INCLUDE_DRAWING_ROUND_RECT_H

/**
 * @addtogroup Drawing
 * @{
 *
 * @brief Provides functions such as 2D graphics rendering, text drawing, and image display.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 *
 * @since 11
 * @version 1.0
 */

/**
 * @file drawing_round_rect.h
 *
 * @brief Declares functions related to the <b>roundRect</b> object in the drawing module.
 *
 * @since 11
 * @version 1.0
 */

#include "drawing_error_code.h"
#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Enumerates of corner radii position.
 *
 * @since 12
 * @version 1.0
 */
typedef enum {
    /**
     * Index of top-left corner radii.
     */
    CORNER_POS_TOP_LEFT,
    /**
     * Index of top-right corner radii.
     */
    CORNER_POS_TOP_RIGHT,
    /**
     * Index of bottom-right corner radii.
     */
    CORNER_POS_BOTTOM_RIGHT,
    /**
     * Index of bottom-left corner radii.
     */
    CORNER_POS_BOTTOM_LEFT,
} OH_Drawing_CornerPos;

/**
 * @brief Creates an <b>OH_Drawing_RoundRect</b> object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @param xRad Indicates the corner radii on x-axis.
 * @param yRad Indicates the corner radii on y-axis.
 * @return Returns the pointer to the <b>OH_Drawing_RoundRect</b> object created.
 * @since 11
 * @version 1.0
 */
OH_Drawing_RoundRect* OH_Drawing_RoundRectCreate(const OH_Drawing_Rect*, float xRad, float yRad);

/**
 * @brief Sets the radiusX and radiusY for a specific corner position.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_RoundRect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @param pos Indicates the corner radii position.
 * @param OH_Drawing_Corner_Radii Indicates the corner radii on x-axis and y-axis.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_RoundRectSetCorner(OH_Drawing_RoundRect*, OH_Drawing_CornerPos pos, OH_Drawing_Corner_Radii);

/**
 * @brief Gets an <b>OH_Drawing_Corner_Radii</b> struct, the point is round corner radiusX and radiusY.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_RoundRect Indicates the pointer to an <b>OH_Drawing_RoundRect</b> object.
 * @param pos Indicates the corner radii position.
 * @return Returns the corner radii of <b>OH_Drawing_Corner_Radii</b> struct.
 * @since 12
 * @version 1.0
 */
OH_Drawing_Corner_Radii OH_Drawing_RoundRectGetCorner(OH_Drawing_RoundRect*, OH_Drawing_CornerPos pos);

/**
 * @brief Destroys an <b>OH_Drawing_RoundRect</b> object and reclaims the memory occupied by the object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_RoundRect Indicates the pointer to an <b>OH_Drawing_RoundRect</b> object.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_RoundRectDestroy(OH_Drawing_RoundRect*);

/**
 * @brief Translates round rect by (dx, dy).
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param roundRect Indicates the pointer to an <b>OH_Drawing_RoundRect</b> object.
 * @param dx Indicates the offsets added to rect left and rect right.
 * @param dy Indicates the offsets added to rect top and rect bottom.
 * @return Returns the error code.
 *         Returns {@link OH_DRAWING_SUCCESS} if the operation is successful.
 *         Returns {@link OH_DRAWING_ERROR_INVALID_PARAMETER} if roundRect is nullptr.
 * @since 12
 * @version 1.0
 */
OH_Drawing_ErrorCode OH_Drawing_RoundRectOffset(OH_Drawing_RoundRect* roundRect, float dx, float dy);
#ifdef __cplusplus
}
#endif
/** @} */
#endif