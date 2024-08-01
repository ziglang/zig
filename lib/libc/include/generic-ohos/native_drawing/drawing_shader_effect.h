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

#ifndef C_INCLUDE_DRAWING_SHADER_EFFECT_H
#define C_INCLUDE_DRAWING_SHADER_EFFECT_H

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
 * @file drawing_shader_effect.h
 *
 * @brief Declares functions related to the <b>shaderEffect</b> object in the drawing module.
 *
 * @since 11
 * @version 1.0
 */

#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Enumerates tile mode.
 *
 * @since 11
 * @version 1.0
 */
typedef enum {
    /**
     * Replicate the edge color if the shader effect draws outside of its original bounds.
     */
    CLAMP,
    /**
     * Repeat the shader effect image horizontally and vertically.
     */
    REPEAT,
    /**
     * Repeat the shader effect image horizontally and vertically, alternating mirror images
     * so that adjacent images always seam.
     */
    MIRROR,
    /**
     * Only draw within the original domain, return transparent-black everywhere else.
     */
    DECAL,
} OH_Drawing_TileMode;

/**
 * @brief Creates an <b>OH_Drawing_ShaderEffect</b> that generates a shader with single color.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param color Indicates the color used by the shader.
 * @return Returns the pointer to the <b>OH_Drawing_ShaderEffect</b> object created.
 *         If nullptr is returned, the creation fails.
 *         The possible cause of the failure is that the available memory is empty.
 * @since 12
 * @version 1.0
 */
OH_Drawing_ShaderEffect* OH_Drawing_ShaderEffectCreateColorShader(const uint32_t color);

/**
 * @brief Creates an <b>OH_Drawing_ShaderEffect</b> that generates a linear gradient between the two specified points.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param startPt Indicates the start point for the gradient.
 * @param endPt Indicates the end point for the gradient.
 * @param colors Indicates the colors to be distributed between the two points.
 * @param pos Indicates the relative position of each corresponding color in the colors array.
 * @param size Indicates the number of colors and pos.
 * @param OH_Drawing_TileMode Indicates the tile mode.
 * @return Returns the pointer to the <b>OH_Drawing_ShaderEffect</b> object created.
 * @since 11
 * @version 1.0
 */
OH_Drawing_ShaderEffect* OH_Drawing_ShaderEffectCreateLinearGradient(const OH_Drawing_Point* startPt,
    const OH_Drawing_Point* endPt, const uint32_t* colors, const float* pos, uint32_t size, OH_Drawing_TileMode);

/**
 * @brief Creates an <b>OH_Drawing_ShaderEffect</b> that generates a linear gradient between the two specified points.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param startPt Indicates the start point for the gradient.
 * @param endPt Indicates the end point for the gradient.
 * @param colors Indicates the colors to be distributed between the two points.
 * @param pos Indicates the relative position of each corresponding color in the colors array.
 *            If pos is nullptr, the colors are evenly distributed between the start and end point.
 * @param size Indicates the number of colors and pos(if pos is not nullptr).
 * @param OH_Drawing_TileMode Indicates the tile mode.
 * @param OH_Drawing_Matrix Indicates the pointer to an <b>OH_Drawing_Matrix</b> object,
                            which represents the local matrix of the created <b>OH_Drawing_ShaderEffect</b> object.
                            If matrix is nullptr, defaults to the identity matrix.
 * @return Returns the pointer to the <b>OH_Drawing_ShaderEffect</b> object created.
 *         If nullptr is returned, the creation fails.
 *         The possible cause of the failure is any of startPt, endPt, colors and pos is nullptr.
 * @since 12
 * @version 1.0
 */
OH_Drawing_ShaderEffect* OH_Drawing_ShaderEffectCreateLinearGradientWithLocalMatrix(
    const OH_Drawing_Point2D* startPt, const OH_Drawing_Point2D* endPt, const uint32_t* colors, const float* pos,
    uint32_t size, OH_Drawing_TileMode, const OH_Drawing_Matrix*);

/**
 * @brief Creates an <b>OH_Drawing_ShaderEffect</b> that generates a radial gradient given the center and radius.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param centerPt Indicates the center of the circle for the gradient.
 * @param radius Indicates the radius of the circle for this gradient.
 * @param colors Indicates the colors to be distributed between the two points.
 * @param pos Indicates the relative position of each corresponding color in the colors array.
 * @param size Indicates the number of colors and pos.
 * @param OH_Drawing_TileMode Indicates the tile mode.
 * @return Returns the pointer to the <b>OH_Drawing_ShaderEffect</b> object created.
 * @since 11
 * @version 1.0
 */
OH_Drawing_ShaderEffect* OH_Drawing_ShaderEffectCreateRadialGradient(const OH_Drawing_Point* centerPt, float radius,
    const uint32_t* colors, const float* pos, uint32_t size, OH_Drawing_TileMode);

/**
 * @brief Creates an <b>OH_Drawing_ShaderEffect</b> that generates a radial gradient given the center and radius.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param centerPt Indicates the center of the circle for the gradient.
 * @param radius Indicates the radius of the circle for this gradient.
 * @param colors Indicates the colors to be distributed between the two points.
 * @param pos Indicates the relative position of each corresponding color in the colors array.
 * @param size Indicates the number of colors and pos.
 * @param OH_Drawing_TileMode Indicates the tile mode.
 * @param OH_Drawing_Matrix Indicates the pointer to an <b>OH_Drawing_Matrix</b> object,
                            which represents the local matrix of the created <b>OH_Drawing_ShaderEffect</b> object.
                            If matrix is nullptr, defaults to the identity matrix.
 * @return Returns the pointer to the <b>OH_Drawing_ShaderEffect</b> object created.
 *         If nullptr is returned, the creation fails.
 *         The possible cause of the failure is any of centerPt, colors and pos is nullptr.
 * @since 12
 * @version 1.0
 */
OH_Drawing_ShaderEffect* OH_Drawing_ShaderEffectCreateRadialGradientWithLocalMatrix(
    const OH_Drawing_Point2D* centerPt, float radius, const uint32_t* colors, const float* pos, uint32_t size,
    OH_Drawing_TileMode, const OH_Drawing_Matrix*);

/**
 * @brief Creates an <b>OH_Drawing_ShaderEffect</b> that generates a sweep gradient given a center.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param centerPt Indicates the center of the circle for the gradient.
 * @param colors Indicates the colors to be distributed between the two points.
 * @param pos Indicates the relative position of each corresponding color in the colors array.
 * @param size Indicates the number of colors and pos.
 * @param OH_Drawing_TileMode Indicates the tile mode.
 * @return Returns the pointer to the <b>OH_Drawing_ShaderEffect</b> object created.
 * @since 11
 * @version 1.0
 */
OH_Drawing_ShaderEffect* OH_Drawing_ShaderEffectCreateSweepGradient(const OH_Drawing_Point* centerPt,
    const uint32_t* colors, const float* pos, uint32_t size, OH_Drawing_TileMode);

/**
 * @brief Creates an <b>OH_Drawing_ShaderEffect</b> that generates a image shader.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Image Indicates the pointer to an <b>OH_Drawing_Image</b> object.
 * @param tileX Indicates the tileX.
 * @param tileY Indicates the tileY.
 * @param OH_Drawing_SamplingOptions Indicates the pointer to an <b>OH_Drawing_SamplingOptions</b> object.
 * @param OH_Drawing_Matrix Indicates the pointer to an <b>OH_Drawing_Matrix</b> object.
 *                          If matrix is nullptr, defaults to the identity matrix.
 * @return Returns the pointer to the <b>OH_Drawing_ShaderEffect</b> object created.
 * @since 12
 * @version 1.0
 */
OH_Drawing_ShaderEffect* OH_Drawing_ShaderEffectCreateImageShader(OH_Drawing_Image*,
    OH_Drawing_TileMode tileX, OH_Drawing_TileMode tileY, const OH_Drawing_SamplingOptions*, const OH_Drawing_Matrix*);

/**
 * @brief Creates an <b>OH_Drawing_ShaderEffect</b> that generates a conical gradient given two circles.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param startPt Indicates the center of the start circle for the gradient.
 * @param startRadius Indicates the radius of the start circle for this gradient.
 * @param endPt Indicates the center of the start circle for the gradient.
 * @param endRadius Indicates the radius of the start circle for this gradient.
 * @param colors Indicates the colors to be distributed between the two points.
 * @param pos Indicates the relative position of each corresponding color in the colors array.
 * @param size Indicates the number of colors and pos.
 * @param OH_Drawing_TileMode Indicates the tile mode.
 * @param OH_Drawing_Matrix Indicates the pointer to an <b>OH_Drawing_Matrix</b> object,
                            which represents the local matrix of the created <b>OH_Drawing_ShaderEffect</b> object.
                            If matrix is nullptr, defaults to the identity matrix.
 * @return Returns the pointer to the <b>OH_Drawing_ShaderEffect</b> object created.
 *         If nullptr is returned, the creation fails.
 *         The possible cause of the failure is any of startPt, endPt, colors and pos is nullptr.
 * @since 12
 * @version 1.0
 */
OH_Drawing_ShaderEffect* OH_Drawing_ShaderEffectCreateTwoPointConicalGradient(const OH_Drawing_Point2D* startPt,
    float startRadius, const OH_Drawing_Point2D* endPt, float endRadius, const uint32_t* colors, const float* pos,
    uint32_t size, OH_Drawing_TileMode, const OH_Drawing_Matrix*);

/**
 * @brief Destroys an <b>OH_Drawing_ShaderEffect</b> object and reclaims the memory occupied by the object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_ShaderEffect Indicates the pointer to an <b>OH_Drawing_ShaderEffect</b> object.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_ShaderEffectDestroy(OH_Drawing_ShaderEffect*);

#ifdef __cplusplus
}
#endif
/** @} */
#endif