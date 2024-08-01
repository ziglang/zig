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

#ifndef C_INCLUDE_DRAWING_PATH_EFFECT_H
#define C_INCLUDE_DRAWING_PATH_EFFECT_H

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
 * @file drawing_path_effect.h
 *
 * @brief Declares functions related to the <b>pathEffect</b> object in the drawing module.
 *
 * @since 12
 * @version 1.0
 */

#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Creates an <b>OH_Drawing_PathEffect</b> object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param intervals Indicates a array which contain an even number of entries.
 * @param count Indicates the number of elements of the intervals array.
 * @param phase Indicates the offset into intervals array.
 * @return Returns the pointer to the <b>OH_Drawing_PathEffect</b> object created.
 * @since 12
 * @version 1.0
 */
OH_Drawing_PathEffect* OH_Drawing_CreateDashPathEffect(float* intervals, int count, float phase);

/**
 * @brief Destroys an <b>OH_Drawing_PathEffect</b> object and reclaims the memory occupied by the object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_PathEffect Indicates the pointer to an <b>OH_Drawing_PathEffect</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_PathEffectDestroy(OH_Drawing_PathEffect*);

#ifdef __cplusplus
}
#endif
/** @} */
#endif