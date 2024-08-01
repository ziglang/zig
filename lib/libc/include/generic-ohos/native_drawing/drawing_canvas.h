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

#ifndef C_INCLUDE_DRAWING_H
#define C_INCLUDE_DRAWING_H

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
 * @file drawing_canvas.h
 *
 * @brief Declares functions related to the <b>canvas</b> object in the drawing module.
 *
 * @since 8
 * @version 1.0
 */

#include "drawing_error_code.h"
#include "drawing_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Enumeration defines the constraint type.
 *
 * @since 12
 * @version 1.0
 */
typedef enum {
    /**
     * Using sampling only inside bounds in a slower manner.
     */
    STRICT_SRC_RECT_CONSTRAINT,
    /**
     * Using sampling outside bounds in a faster manner.
     */
    FAST_SRC_RECT_CONSTRAINT,
} OH_Drawing_SrcRectConstraint;

/**
 * @brief Creates an <b>OH_Drawing_Canvas</b> object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @return Returns the pointer to the <b>OH_Drawing_Canvas</b> object created.
 * @since 8
 * @version 1.0
 */
OH_Drawing_Canvas* OH_Drawing_CanvasCreate(void);

/**
 * @brief Destroys an <b>OH_Drawing_Canvas</b> object and reclaims the memory occupied by the object.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_CanvasDestroy(OH_Drawing_Canvas*);

/**
 * @brief Binds a bitmap to a canvas so that the content drawn on the canvas
 * is output to the bitmap (this process is called CPU rendering).
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Bitmap Indicates the pointer to an <b>OH_Drawing_Bitmap</b> object.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_CanvasBind(OH_Drawing_Canvas*, OH_Drawing_Bitmap*);

/**
 * @brief Attaches a pen to a canvas so that the canvas will use the style and color of the pen to outline a shape.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Pen Indicates the pointer to an <b>OH_Drawing_Pen</b> object.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_CanvasAttachPen(OH_Drawing_Canvas*, const OH_Drawing_Pen*);

/**
 * @brief Detaches the pen from a canvas so that the canvas will not use the style
 * and color of the pen to outline a shape.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_CanvasDetachPen(OH_Drawing_Canvas*);

/**
 * @brief Attaches a brush to a canvas so that the canvas will use the style and color of the brush to fill in a shape.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_CanvasAttachBrush(OH_Drawing_Canvas*, const OH_Drawing_Brush*);

/**
 * @brief Detaches the brush from a canvas so that the canvas will not use the style
 * and color of the brush to fill in a shape.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_CanvasDetachBrush(OH_Drawing_Canvas*);

/**
 * @brief Saves the current canvas status (canvas matrix) to the top of the stack.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_CanvasSave(OH_Drawing_Canvas*);

/**
 * @brief Saves matrix and clip, and allocates a bitmap for subsequent drawing.
 * Calling restore discards changes to matrix and clip, and draws the bitmap.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasSaveLayer(OH_Drawing_Canvas*, const OH_Drawing_Rect*, const OH_Drawing_Brush*);

/**
 * @brief Restores the canvas status (canvas matrix) saved on the top of the stack.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_CanvasRestore(OH_Drawing_Canvas*);

/**
 * @brief Gets the number of the canvas status (canvas matrix) saved in the stack.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @return Returns a 32-bit variable that describes the number of canvas status.
 * @since 11
 * @version 1.0
 */
uint32_t OH_Drawing_CanvasGetSaveCount(OH_Drawing_Canvas*);

/**
 * @brief Restores the specific number of the canvas status (canvas matrix) saved in the stack.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param saveCount Indicates the specific number of canvas status.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_CanvasRestoreToCount(OH_Drawing_Canvas*, uint32_t saveCount);

/**
 * @brief Draws a line segment.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param x1 Indicates the x coordinate of the start point of the line segment.
 * @param y1 Indicates the y coordinate of the start point of the line segment.
 * @param x2 Indicates the x coordinate of the end point of the line segment.
 * @param y2 Indicates the y coordinate of the end point of the line segment.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_CanvasDrawLine(OH_Drawing_Canvas*, float x1, float y1, float x2, float y2);

/**
 * @brief Draws a path.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Path Indicates the pointer to an <b>OH_Drawing_Path</b> object.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_CanvasDrawPath(OH_Drawing_Canvas*, const OH_Drawing_Path*);

/**
 * @brief Draw the specified area of the Media::PixelMap to the specified area of the canvas.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_PixelMap Indicates the pointer to an <b>OH_Drawing_PixelMap</b> object.
 * @param src the area of source pixelmap.
 * @param dst the area of destination canvas.
 * @param OH_Drawing_SamplingOptions the sampling mode.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasDrawPixelMapRect(OH_Drawing_Canvas*, OH_Drawing_PixelMap*, const OH_Drawing_Rect* src,
    const OH_Drawing_Rect* dst, const OH_Drawing_SamplingOptions*);

/**
 * @brief Fills clipped canvas area with brush.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Brush Indicates the pointer to an <b>OH_Drawing_Brush</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasDrawBackground(OH_Drawing_Canvas*, const OH_Drawing_Brush*);

/**
 * @brief Draws region using clip, matrix and paint.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Region Indicates the pointer to an <b>OH_Drawing_Region</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasDrawRegion(OH_Drawing_Canvas*, const OH_Drawing_Region*);

/**
 * @brief Enumerates of scale to fit flags, selects if an array of points are drawn as discrete points, as lines,
 * or as an open polygon.
 *
 * @since 12
 * @version 1.0
 */
typedef enum {
    /**
     * Draw each point separately.
     */
    POINT_MODE_POINTS,
    /**
     * Draw each pair of points as a line segment.
     */
    POINT_MODE_LINES,
     /**
     * Draw the array of points as a open polygon.
     */
    POINT_MODE_POLYGON,
} OH_Drawing_PointMode;

/**
 * @brief Draws a point.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param point Indicates the pointer to an <b>OH_Drawing_Point</b> object.
 * @return Returns the error code.
 *         Returns {@link OH_DRAWING_SUCCESS} if the operation is successful.
 *         Returns {@link OH_DRAWING_ERROR_INVALID_PARAMETER} if canvas or point is nullptr.
 * @since 12
 * @version 1.0
 */
OH_Drawing_ErrorCode OH_Drawing_CanvasDrawPoint(OH_Drawing_Canvas* canvas, const OH_Drawing_Point2D* point);

/**
 * @brief Draws point array as separate point, line segment or open polygon according to given point mode.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param mode Draw points enum.
 * @param count The point count.
 * @param OH_Drawing_Point2D Point struct array.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasDrawPoints(OH_Drawing_Canvas*, OH_Drawing_PointMode mode,
    uint32_t count, const OH_Drawing_Point2D*);

/**
 * @brief Draws a bitmap.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Bitmap Indicates the pointer to an <b>OH_Drawing_Bitmap</b> object.
 * @param left Indicates the left position of the <b>OH_Drawing_Bitmap</b>.
 * @param top Indicates the top position of the <b>OH_Drawing_Bitmap</b>.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_CanvasDrawBitmap(OH_Drawing_Canvas*, const OH_Drawing_Bitmap*, float left, float top);

/**
 * @brief Draw the specified area of the bitmap to the specified area of the canvas.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Bitmap Indicates the pointer to an <b>OH_Drawing_Bitmap</b> object.
 * @param src the area of source bitmap, can be nullptr.
 * @param dst the area of destination canvas.
 * @param OH_Drawing_SamplingOptions the sampling mode.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasDrawBitmapRect(OH_Drawing_Canvas*, const OH_Drawing_Bitmap*, const OH_Drawing_Rect* src,
    const OH_Drawing_Rect* dst, const OH_Drawing_SamplingOptions*);

/**
 * @brief Draws a rect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_CanvasDrawRect(OH_Drawing_Canvas*, const OH_Drawing_Rect*);

/**
 * @brief Draws a circle.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Point Indicates the pointer to an <b>OH_Drawing_Point</b> object.
 * @param radius Indicates the radius of the circle.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_CanvasDrawCircle(OH_Drawing_Canvas*, const OH_Drawing_Point*, float radius);

/**
 * @brief Fills the entire canvas with the specified color and blend mode.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param color Indicates the color, which is a 32-bit variable.
 * @param blendMode Indicates the blend mode.
 * @return Returns the error code.
 *         Returns {@link OH_DRAWING_SUCCESS} if the operation is successful.
 *         Returns {@link OH_DRAWING_ERROR_INVALID_PARAMETER} if canvas is nullptr.
 * @since 12
 * @version 1.0
 */
OH_Drawing_ErrorCode OH_Drawing_CanvasDrawColor(OH_Drawing_Canvas* canvas, uint32_t color,
    OH_Drawing_BlendMode blendMode);

/**
 * @brief Draws an oval.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_CanvasDrawOval(OH_Drawing_Canvas*, const OH_Drawing_Rect*);

/**
 * @brief Draws an arc.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @param startAngle Indicates the startAngle of the arc.
 * @param sweepAngle Indicates the sweepAngle of the arc.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_CanvasDrawArc(OH_Drawing_Canvas*, const OH_Drawing_Rect*, float startAngle, float sweepAngle);

/**
 * @brief Draws a roundrect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_RoundRect Indicates the pointer to an <b>OH_Drawing_RoundRect</b> object.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_CanvasDrawRoundRect(OH_Drawing_Canvas*, const OH_Drawing_RoundRect*);

/**
 * @brief Draws a textblob.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_TextBlob Indicates the pointer to an <b>OH_Drawing_TextBlob</b> object.
 * @param x Indicates the horizontal offset applied to blob.
 * @param y Indicates the vertical offset applied to blob.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_CanvasDrawTextBlob(OH_Drawing_Canvas*, const OH_Drawing_TextBlob*, float x, float y);

/**
 * @brief Enumerates clip op.
 *
 * @since 11
 * @version 1.0
 */
typedef enum {
    /**
     * Clip with difference.
     */
    DIFFERENCE,
    /**
     * Clip with intersection.
     */
    INTERSECT,
} OH_Drawing_CanvasClipOp;

/**
 * @brief Clip a rect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @param clipOp Indicates the operation to apply to clip.
 * @param doAntiAlias Indicates whether clip operation requires anti-aliased.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_CanvasClipRect(OH_Drawing_Canvas*, const OH_Drawing_Rect*,
    OH_Drawing_CanvasClipOp clipOp, bool doAntiAlias);

/**
 * @brief Clip a round rect.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_RoundRect Indicates the pointer to an <b>OH_Drawing_RoundRect</b> object.
 * @param clipOp Indicates the operation to apply to clip.
 * @param doAntiAlias Indicates whether clip operation requires anti-aliased.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasClipRoundRect(OH_Drawing_Canvas*, const OH_Drawing_RoundRect*,
    OH_Drawing_CanvasClipOp clipOp, bool doAntiAlias);

/**
 * @brief Clip a path.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Path Indicates the pointer to an <b>OH_Drawing_Path</b> object.
 * @param clipOp Indicates the operation to apply to clip.
 * @param doAntiAlias Indicates whether clip operation requires anti-aliased.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_CanvasClipPath(OH_Drawing_Canvas*, const OH_Drawing_Path*,
    OH_Drawing_CanvasClipOp clipOp, bool doAntiAlias);

/**
 * @brief Clips a region.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param region Indicates the pointer to an <b>OH_Drawing_Region</b> object.
 * @param clipOp To apply to clip.
 * @return Returns the error code.
 *         Returns {@link OH_DRAWING_SUCCESS} if the operation is successful.
 *         Returns {@link OH_DRAWING_ERROR_INVALID_PARAMETER} if canvas or region is nullptr.
 * @since 12
 * @version 1.0
 */
OH_Drawing_ErrorCode OH_Drawing_CanvasClipRegion(OH_Drawing_Canvas* canvas, const OH_Drawing_Region* region,
    OH_Drawing_CanvasClipOp clipOp);

/**
 * @brief Rotates by degrees. Positive degrees rotates clockwise.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param degrees Indicates the amount to rotate, in degrees.
 * @param px Indicates the x-axis value of the point to rotate about.
 * @param py Indicates the y-axis value of the point to rotate about.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_CanvasRotate(OH_Drawing_Canvas*, float degrees, float px, float py);

/**
 * @brief Translates by dx along the x-axis and dy along the y-axis.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param dx Indicates the distance to translate on x-axis.
 * @param dy Indicates the distance to translate on y-axis.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_CanvasTranslate(OH_Drawing_Canvas*, float dx, float dy);

/**
 * @brief Scales by sx on the x-axis and sy on the y-axis.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param sx Indicates the amount to scale on x-axis.
 * @param sy Indicates the amount to scale on y-axis.
 * @since 11
 * @version 1.0
 */
void OH_Drawing_CanvasScale(OH_Drawing_Canvas*, float sx, float sy);

/**
 * @brief Skew by sx on the x-axis and sy on the y-axis.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param sx Indicates the amount to skew on x-axis.
 * @param sy Indicates the amount to skew on y-axis.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasSkew(OH_Drawing_Canvas*, float sx, float sy);

/**
 * @brief Clears a canvas by using a specified color.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param color Indicates the color, which is a 32-bit (ARGB) variable.
 * @since 8
 * @version 1.0
 */
void OH_Drawing_CanvasClear(OH_Drawing_Canvas*, uint32_t color);

/**
 * @brief Get the width of a canvas.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @since 12
 * @version 1.0
 */
int32_t OH_Drawing_CanvasGetWidth(OH_Drawing_Canvas*);

/**
 * @brief Get the height of a canvas.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @since 12
 * @version 1.0
 */
int32_t OH_Drawing_CanvasGetHeight(OH_Drawing_Canvas*);

/**
 * @brief Get the bounds of clip of a canvas.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasGetLocalClipBounds(OH_Drawing_Canvas*, OH_Drawing_Rect*);

/**
 * @brief Get a 3x3 matrix of the transform from local coordinates to 'device'.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Matrix Indicates the pointer to an <b>OH_Drawing_Matrix</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasGetTotalMatrix(OH_Drawing_Canvas*, OH_Drawing_Matrix*);

/**
 * @brief Use the passed matrix to transforming the geometry, then use existing matrix.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Matrix Indicates the pointer to an <b>OH_Drawing_Matrix</b> object,
 * represents the matrix which is passed.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasConcatMatrix(OH_Drawing_Canvas*, OH_Drawing_Matrix*);

/**
 * @brief Enumerates of shadow flags.
 *
 * @since 12
 * @version 1.0
 */
typedef enum {
    /**
     * Use no shadow flags.
     */
    SHADOW_FLAGS_NONE,
    /**
     * The occluding object is transparent.
     */
    SHADOW_FLAGS_TRANSPARENT_OCCLUDER,
    /**
     * No need to analyze shadows.
     */
    SHADOW_FLAGS_GEOMETRIC_ONLY,
    /**
     * Use all shadow flags.
     */
    SHADOW_FLAGS_ALL,
} OH_Drawing_CanvasShadowFlags;

/**
 * @brief Use circular light to draw an offset spot shadow and outlining ambient shadow for the given path.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Path Indicates the pointer to an <b>OH_Drawing_Path</b> object, use to generate shadows.
 * @param planeParams Represents the value of the function which returns Z offset of the occluder from the
 * canvas based on x and y.
 * @param devLightPos Represents the position of the light relative to the canvas.
 * @param lightRadius The radius of the circular light.
 * @param ambientColor Ambient shadow's color.
 * @param spotColor Spot shadow's color.
 * @param flag Indicates the flag to control opaque occluder, shadow, and light position.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasDrawShadow(OH_Drawing_Canvas*, OH_Drawing_Path*, OH_Drawing_Point3D planeParams,
    OH_Drawing_Point3D devLightPos, float lightRadius, uint32_t ambientColor, uint32_t spotColor,
    OH_Drawing_CanvasShadowFlags flag);

/**
 * @brief Sets matrix of canvas.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Matrix Indicates the pointer to an <b>OH_Drawing_Matrix</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasSetMatrix(OH_Drawing_Canvas*, OH_Drawing_Matrix*);

/**
 * @brief Reset matrix to the idenmtity matrix, any prior matrix state is overwritten.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasResetMatrix(OH_Drawing_Canvas*);

/**
 * @brief Draws the specified source rectangle of the image onto the canvas,
 * scaled and translated to the destination rectangle.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Image Indicates the pointer to an <b>OH_Drawing_Image</b> object.
 * @param src The area of source image.
 * @param dst The area of destination canvas.
 * @param OH_Drawing_SamplingOptions Indicates the pointer to an <b>OH_Drawing_SamplingOptions</b> object.
 * @param OH_Drawing_SrcRectConstraint Constraint type.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasDrawImageRectWithSrc(OH_Drawing_Canvas*, const OH_Drawing_Image*,
    const OH_Drawing_Rect* src, const OH_Drawing_Rect* dst, const OH_Drawing_SamplingOptions*,
    OH_Drawing_SrcRectConstraint);

/**
 * @brief Draws the specified source rectangle of the image onto the canvas,
 * scaled and translated to the destination rectangle.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Image Indicates the pointer to an <b>OH_Drawing_Image</b> object.
 * @param OH_Drawing_Rect Indicates the pointer to an <b>OH_Drawing_Rect</b> object.
 * @param OH_Drawing_SamplingOptions Indicates the pointer to an <b>OH_Drawing_SamplingOptions</b> object.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasDrawImageRect(OH_Drawing_Canvas*, OH_Drawing_Image*,
    OH_Drawing_Rect* dst, OH_Drawing_SamplingOptions*);

/**
 * @brief Enumerates of vertices flags.
 *
 * @since 12
 * @version 1.0
 */
typedef enum {
    /**
     * The vertices are a triangle list.
     */
    VERTEX_MODE_TRIANGLES,
    /**
     * The vertices are a triangle strip.
     */
    VERTEX_MODE_TRIANGLES_STRIP,
    /**
     * The vertices are a triangle fan.
     */
    VERTEX_MODE_TRIANGLE_FAN,
} OH_Drawing_VertexMode;

/**
 * @brief Draw a triangular mesh with vertex descriptions.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param vertexMmode Draw a set of vertices.
 * @param vertexCount Vertex count.
 * @param positions Positions data pointer.
 * @param texs Texture coordinate data pointer.
 * @param colors Color data pointer.
 * @param indexCount Index count.
 * @param indices Index data pointer.
 * @since 12
 * @version 1.0
 */
void OH_Drawing_CanvasDrawVertices(OH_Drawing_Canvas*, OH_Drawing_VertexMode vertexMmode,
    int32_t vertexCount, const OH_Drawing_Point2D* positions, const OH_Drawing_Point2D* texs,
    const uint32_t* colors, int32_t indexCount, const uint16_t* indices, OH_Drawing_BlendMode mode);

/**
 * @brief Read pixels data from canvas.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Image_Info width, height, colorType, and alphaType of dstPixels.
 * @param dstPixels destination pixel storage.
 * @param dstRowBytes size of one row of pixels.
 * @param srcX offset into canvas writable pixels on x-axis.
 * @param srcY offset into canvas writable pixels on y-axis.
 * @return true if pixels are copied to dstPixels.
 * @since 12
 * @version 1.0
 */
bool OH_Drawing_CanvasReadPixels(OH_Drawing_Canvas*, OH_Drawing_Image_Info*,
    void* dstPixels, uint32_t dstRowBytes, int32_t srcX, int32_t srcY);

/**
 * @brief Read pixels data to a bitmap from canvas.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param OH_Drawing_Canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param OH_Drawing_Bitmap Indicates the pointer to an <b>OH_Drawing_Bitmap</b> object.
 * @param srcX offset into canvas writable pixels on x-axis.
 * @param srcY offset into canvas writable pixels on y-axis.
 * @return true if pixels are copied to dstBitmap.
 * @since 12
 * @version 1.0
 */
bool OH_Drawing_CanvasReadPixelsToBitmap(OH_Drawing_Canvas*, OH_Drawing_Bitmap*, int32_t srcX, int32_t srcY);

/**
 * @brief Checks whether the drawable area is empty.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param isClipEmpty Indicates if drawable area is empty.
 * @return Returns the error code.
 *         Returns {@link OH_DRAWING_SUCCESS} if the operation is successful.
 *         Returns {@link OH_DRAWING_ERROR_INVALID_PARAMETER} if canvas or isClipEmpty is nullptr.
 * @since 12
 * @version 1.0
 */
OH_Drawing_ErrorCode OH_Drawing_CanvasIsClipEmpty(OH_Drawing_Canvas* canvas, bool* isClipEmpty);

/**
 * @brief Gets image info of canvas.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeDrawing
 * @param canvas Indicates the pointer to an <b>OH_Drawing_Canvas</b> object.
 * @param imageInfo Indicates the pointer to an <b>OH_Drawing_Image_Info</b> object.
 * @return Returns the error code.
 *         Returns {@link OH_DRAWING_SUCCESS} if the operation is successful.
 *         Returns {@link OH_DRAWING_ERROR_INVALID_PARAMETER} if canvas or imageInfo is nullptr.
 * @since 12
 * @version 1.0
 */
OH_Drawing_ErrorCode OH_Drawing_CanvasGetImageInfo(OH_Drawing_Canvas* canvas, OH_Drawing_Image_Info* imageInfo);

#ifdef __cplusplus
}
#endif
/** @} */
#endif