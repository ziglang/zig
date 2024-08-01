/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

#ifndef C_INCLUDE_DRAWING_POINT_H
#define C_INCLUDE_DRAWING_POINT_H

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
 * @file drawing_point.h
 *
 * @brief Declares functions related to the <b>point</b> object in the drawing module.
 *
 * @since 11
 * @version 1.0
 */

#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Creates an <b>OH_Drawing_Point</b> object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param x Indicates the x-axis coordinates of the point.
 * @param y Indicates the y-axis coordinates of the point.
 * @return Returns the pointer to the <b>OH_Drawing_Point</b> object created.
 * @since 11
 * @version 1.0
 */
OH_Drawing_Point* OH_Drawing_PointCreate(float x, float y);

/**
 * @brief Destroys an <b>OH_Drawing_Point</b> object and reclaims the memory occupied by the object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Point Indicates the pointer to an <b>OH_Drawing_Point</b> object.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_PointDestroy(OH_Drawing_Point*);

#ifdef __cplusplus
}
#endif
/** @} */
#endif