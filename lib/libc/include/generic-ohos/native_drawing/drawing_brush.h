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

#ifndef C_INCLUDE_DRAWING_BRUSH_H
#define C_INCLUDE_DRAWING_BRUSH_H

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
 * @file drawing_brush.h
 *
 * @brief Declares functions related to the <b>brush</b> object in the drawing module.
 *
 * @since 8
 * @version 1.0
 */

#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Creates an <b>OH_Drawing_Brush</b> object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @return Returns the pointer to the <b>OH_Drawing_Brush</b> object created.
 * @since 8
 * @version 1.0
 */
OH_Drawing_Brush* OH_Drawing_BrushCreate(void);

/**
 * @brief Creates an <b>OH_Drawing_Brush</b> copy object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @return Returns the pointer to the <b>OH_Drawing_Brush</b> object created.
 *         If nullptr is returned, the creation fails.
 *         The possible cause of the failure is that the available memory is empty or a nullptr is passed.
 * @since 12
 * @version 1.0
 */
OH_Drawing_Brush* OH_Drawing_BrushCopy(OH_Drawing_Brush*);

/**
 * @brief Destroys an <b>OH_Drawing_Brush</b> object and reclaims the memory occupied by the object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_BrushDestroy(OH_Drawing_Brush*);

/**
 * @brief Checks whether anti-aliasing is enabled for a brush. If anti-aliasing is enabled,
 * edges will be drawn with partial transparency.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @return Returns <b>true</b> if anti-aliasing is enabled; returns <b>false</b> otherwise.
 * @since 8
 * @version 1.0
 */
bool OH_Drawing_BrushIsAntiAlias(const OH_Drawing_Brush*);

/**
 * @brief Enables or disables anti-aliasing for a brush. If anti-aliasing is enabled,
 * edges will be drawn with partial transparency.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @param bool Specifies whether to enable anti-aliasing. The value <b>true</b> means
 *             to enable anti-aliasing, and <b>false</b> means the opposite.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_BrushSetAntiAlias(OH_Drawing_Brush*, bool);

/**
 * @brief Obtains the color of a brush. The color is used by the brush to fill in a shape.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @return Returns a 32-bit (ARGB) variable that describes the color.
 * @since 8
 * @version 1.0
 */
uint32_t OH_Drawing_BrushGetColor(const OH_Drawing_Brush*);

/**
 * @brief Sets the color for a brush. The color will be used by the brush to fill in a shape.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @param color Indicates the color to set, which is a 32-bit (ARGB) variable.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_BrushSetColor(OH_Drawing_Brush*, uint32_t color);

/**
 * @brief Obtains the alpha of a brush. The alpha is used by the brush to fill in a shape.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @return Returns a 8-bit variable that describes the alpha.
 * @since 11
 * @version 1.0
 */
uint8_t OH_Drawing_BrushGetAlpha(const OH_Drawing_Brush*);

/**
 * @brief Sets the alpha for a brush. The alpha will be used by the brush to fill in a shape.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @param alpha Indicates the alpha to set, which is a 8-bit variable.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_BrushSetAlpha(OH_Drawing_Brush*, uint8_t alpha);

/**
 * @brief Sets the shaderEffect for a brush.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @param OH_Drawing_ShaderEffect Indicates the pointer to an <b>OH_Drawing_ShaderEffect</b> object.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_BrushSetShaderEffect(OH_Drawing_Brush*, OH_Drawing_ShaderEffect*);

/**
 * @brief Sets the shadowLayer for a brush.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @param OH_Drawing_ShadowLayer Indicates the pointer to an <b>OH_Drawing_ShadowLayer</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_BrushSetShadowLayer(OH_Drawing_Brush*, OH_Drawing_ShadowLayer*);

/**
 * @brief Sets the filter for a brush.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @param OH_Drawing_Filter Indicates the pointer to an <b>OH_Drawing_Filter</b> object.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_BrushSetFilter(OH_Drawing_Brush*, OH_Drawing_Filter*);

/**
 * @brief Gets the filter from a brush.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @param OH_Drawing_Filter Indicates the pointer to an <b>OH_Drawing_Filter</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_BrushGetFilter(OH_Drawing_Brush*, OH_Drawing_Filter*);

/**
 * @brief Sets a blender that implements the specified blendmode enum for a brush.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Pen Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @param OH_Drawing_BlendMode Indicates the blend mode.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_BrushSetBlendMode(OH_Drawing_Brush*, OH_Drawing_BlendMode);

/**
 * @brief Resets all brush contents to their initial values.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_BrushReset(OH_Drawing_Brush*);

#ifdef __cplusplus
}
#endif
/** @} */
#endif