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

#ifndef C_INCLUDE_DRAWING_REGION_H
#define C_INCLUDE_DRAWING_REGION_H

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
 * @file drawing_region.h
 *
 * @brief Declares functions related to the <b>region</b> object in the drawing module.
 *
 * @since 12
 * @version 1.0
 */

#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Operations when two regions are combined.
 *
 * @since 12
 * @version 1.0
 */
typedef enum {
    /**
     * Difference operation.
     */
    REGION_OP_MODE_DIFFERENCE,
    /**
     * Intersect operation.
     */
    REGION_OP_MODE_INTERSECT,
    /**
     * Union operation.
     */
    REGION_OP_MODE_UNION,
    /**
     * Xor operation.
     */
    REGION_OP_MODE_XOR,
    /**
     * Reverse difference operation.
     */
    REGION_OP_MODE_REVERSE_DIFFERENCE,
    /**
     * Replace operation.
     */
    REGION_OP_MODE_REPLACE,
} OH_Drawing_RegionOpMode;

/**
 * @brief Creates an <b>OH_Drawing_Region</b> object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @return Returns the pointer to the <b>OH_Drawing_Region</b> object created.
 * @since 12
 * @version 1.0
 */
OH_Drawing_Region* OH_Drawing_RegionCreate(void);

/**
 * @brief Determines whether the region contains the specified coordinates.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param region Indicates the pointer to an <b>OH_Drawing_Region</b> object.
 * @param int32_t x-coordinate.
 * @param int32_t y-coordinate.
 * @return Returns <b>true</b> if (x, y) is inside region; returns <b>false</b> otherwise.
 * @since 12
 * @version 1.0
 */
bool OH_Drawing_RegionContains(OH_Drawing_Region* region, int32_t x, int32_t y);

/**
 * @brief Combines two regions.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param region Indicates the pointer to an <b>OH_Drawing_Region</b> object.
 * @param dst Indicates the pointer to an <b>OH_Drawing_Region</b> object.
 * @param op Indicates the operation to apply to combine.
 * @return Returns <b>true</b> if constructed Region is not empty; returns <b>false</b> otherwise.
 * @since 12
 * @version 1.0
 */
bool OH_Drawing_RegionOp(OH_Drawing_Region* region, const OH_Drawing_Region* dst, OH_Drawing_RegionOpMode op);

/**
 * @brief Sets the region to the specified rect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Region Indicates the pointer to an <b>OH_Drawing_Region</b> object.
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @return Return true if constructed Region is not empty.
 * @since 12
 * @version 1.0
 */
bool OH_Drawing_RegionSetRect(OH_Drawing_Region* region, const OH_Drawing_Rect* rect);

/**
 * @brief Constructs region that matchs outline of path within clip.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param region Indicates the pointer to an <b>OH_Drawing_Region</b> object.
 * @param path Indicates the pointer to an <b>OH_Drawing_Path</b> object.
 * @param clip Indicates the pointer to an <b>OH_Drawing_Region</b> object.
 * @return Returns <b>true</b> if constructed Region is not empty; returns <b>false</b> otherwise.
 * @since 12
 * @version 1.0
 */
bool OH_Drawing_RegionSetPath(OH_Drawing_Region* region, const OH_Drawing_Path* path, const OH_Drawing_Region* clip);

/**
 * @brief Destroys an <b>OH_Drawing_Region</b> object and reclaims the memory occupied by the object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Region Indicates the pointer to an <b>OH_Drawing_Region</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_RegionDestroy(OH_Drawing_Region*);

#ifdef __cplusplus
}
#endif
/** @} */
#endif