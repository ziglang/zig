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

#ifndef C_INCLUDE_DRAWING_TYPES_H
#define C_INCLUDE_DRAWING_TYPES_H

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
 * @file drawing_types.h
 *
 * @brief Declares the data types for drawing 2D graphics, including the canvas, brush, pen, bitmap, and path.
 *
 * @since 8
 * @version 1.0
 */

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines a rectangular canvas on which various shapes, images,
 * and texts can be drawn by using the brush and pen.
 *
 * @since 8
 * @version 1.0
 */
typedef struct OH_Drawing_Canvas OH_Drawing_Canvas;

/**
 * @brief Defines a pen, which is used to describe the style and color to outline a shape.
 *
 * @since 8
 * @version 1.0
 */
typedef struct OH_Drawing_Pen OH_Drawing_Pen;

/**
 * @brief Defines a region, which is used to represent an enclosed area on the canvas layer.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_Drawing_Region OH_Drawing_Region;

/**
 * @brief Defines as a brush, which is used to describe the style and color to fill in a shape.
 *
 * @since 8
 * @version 1.0
 */
typedef struct OH_Drawing_Brush OH_Drawing_Brush;

/**
 * @brief Defines a path, which is used to customize various shapes.
 *
 * @since 8
 * @version 1.0
 */
typedef struct OH_Drawing_Path OH_Drawing_Path;

/**
 * @brief Defines a bitmap, which is a memory that contains the pixel data of a shape.
 *
 * @since 8
 * @version 1.0
 */
typedef struct OH_Drawing_Bitmap OH_Drawing_Bitmap;

/**
 * @brief Defines a point, which is used to describe the coordinate point.
 *
 * @since 11
 * @version 1.0
 */
typedef struct OH_Drawing_Point OH_Drawing_Point;

/**
 * @brief Defines a pixelmap, which is used to wrap real pixelmap supported by image framework.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_Drawing_PixelMap OH_Drawing_PixelMap;

/**
 * @brief Define color space to determine color information.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_Drawing_ColorSpace OH_Drawing_ColorSpace;

/**
 * @brief Defines a point of 2d.
 *
 * @since 12
 * @version 1.0
 */
typedef struct {
    float x;
    float y;
} OH_Drawing_Point2D;

/**
 * @brief Defines a corner radii, which is on x-axis and y-axis.
 *
 * @since 12
 * @version 1.0
 */
typedef OH_Drawing_Point2D OH_Drawing_Corner_Radii;

/**
 * @brief Defines a point of 3d, which is used to describe the coordinate point.
 *
 * @since 12
 * @version 1.0
 */
typedef struct {
    float x;
    float y;
    float z;
} OH_Drawing_Point3D;

/**
 * @brief Defines a pathEffect, which is used to affects stroked paths.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_Drawing_PathEffect OH_Drawing_PathEffect;

/**
 * @brief Defines a rect, which is used to describe the rectangle.
 *
 * @since 11
 * @version 1.0
 */
typedef struct OH_Drawing_Rect OH_Drawing_Rect;

/**
 * @brief Defines a roundRect, which is used to describe the round rectangle.
 *
 * @since 11
 * @version 1.0
 */
typedef struct OH_Drawing_RoundRect OH_Drawing_RoundRect;

/**
 * @brief Defines a matrix, which is used to describe the transforming coordinates.
 *
 * @since 11
 * @version 1.0
 */
typedef struct OH_Drawing_Matrix OH_Drawing_Matrix;

/**
 * @brief Defines a shaderEffect, which is used to describe the source color(s) for what is being drawn.
 *
 * @since 11
 * @version 1.0
 */
typedef struct OH_Drawing_ShaderEffect OH_Drawing_ShaderEffect;

/**
 * @brief Defines a shadowLayer, which is used to draw shaded parts.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_Drawing_ShadowLayer OH_Drawing_ShadowLayer;

/**
 * @brief Defines a filter, which is used to store maskFilter, colorFilter and imageFilter.
 *
 * @since 11
 * @version 1.0
 */
typedef struct OH_Drawing_Filter OH_Drawing_Filter;

/**
 * @brief Defines a maskFilter, which is used to perform transformations on the mask before drawing it.
 *
 * @since 11
 * @version 1.0
 */
typedef struct OH_Drawing_MaskFilter OH_Drawing_MaskFilter;

/**
 * @brief Defines a colorFilter, which is called a color and returns a new color.
 *
 * @since 11
 * @version 1.0
 */
typedef struct OH_Drawing_ColorFilter OH_Drawing_ColorFilter;

/**
 * @brief Defines a font, which is used to describe the font.
 *
 * @since 11
 * @version 1.0
 */
typedef struct OH_Drawing_Font OH_Drawing_Font;

/**
 * @brief Defines a memoryStream, which is used to describe the memory stream.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_Drawing_MemoryStream OH_Drawing_MemoryStream;

/**
 * @brief Defines a typeface, which is used to describe the typeface.
 *
 * @since 11
 * @version 1.0
 */
typedef struct OH_Drawing_Typeface OH_Drawing_Typeface;

/**
 * @brief Defines a textBlob, which combines multiple text runs into an immutable container.
 * Each text run consists of glyphs and positions.
 *
 * @since 11
 * @version 1.0
 */
typedef struct OH_Drawing_TextBlob OH_Drawing_TextBlob;

/**
 * @brief Defines a image, which is used to describe a two dimensional array of pixels to draw.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_Drawing_Image OH_Drawing_Image;

/**
 * @brief Defines a image filter, which is used to operate on all the color bits of pixels that make up an image.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_Drawing_ImageFilter OH_Drawing_ImageFilter;

/**
 * @brief Defines a sampling options, which is used to describe the sampling mode.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_Drawing_SamplingOptions OH_Drawing_SamplingOptions;

/**
 * @brief Defines a textBlobBuilder, which is used to build the textBlob.
 *
 * @since 11
 * @version 1.0
 */
typedef struct OH_Drawing_TextBlobBuilder OH_Drawing_TextBlobBuilder;

/**
 * @brief Defines a GPU context, which is used to describe the GPU backend context.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_Drawing_GpuContext OH_Drawing_GpuContext;

/**
 * @brief Defines a surface, which is used to manage the pixels that a canvas draws into.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_Drawing_Surface OH_Drawing_Surface;

/**
 * @brief Enumerates storage formats of bitmap pixels.
 *
 * @since 8
 * @version 1.0
 */
typedef enum {
    /** Unknown format. */
    COLOR_FORMAT_UNKNOWN,
    /** Each pixel is represented by 8 bits, which together indicate alpha. */
    COLOR_FORMAT_ALPHA_8,
    /**
     * Each pixel is represented by 16 bits. From the most significant bit to the least significant bit,
     * the first 5 bits indicate red, the subsequent 6 bits indicate green, and the last 5 bits indicate blue.
     */
    COLOR_FORMAT_RGB_565,
    /**
     * Each pixel is represented by 16 bits. From the most significant bit to the least significant bit,
     * every 4 bits indicate alpha, red, green, and blue, respectively.
     */
    COLOR_FORMAT_ARGB_4444,
    /**
     * Each pixel is represented by 32 bits. From the most significant bit to the least significant bit,
     * every 8 bits indicate alpha, red, green, and blue, respectively.
     */
    COLOR_FORMAT_RGBA_8888,
    /**
     * Each pixel is represented by 32 bits. From the most significant bit to the least significant bit,
     * every 8 bits indicate blue, green, red, and alpha, respectively.
     */
    COLOR_FORMAT_BGRA_8888
} OH_Drawing_ColorFormat;

/**
 * @brief Enumerates alpha formats of bitmap pixels.
 *
 * @since 8
 * @version 1.0
 */
typedef enum {
    /** Unknown format. */
    ALPHA_FORMAT_UNKNOWN,
    /** The bitmap does not have the alpha component. */
    ALPHA_FORMAT_OPAQUE,
    /** The color component of each pixel is premultiplied by the alpha component. */
    ALPHA_FORMAT_PREMUL,
    /** The color component of each pixel is not premultiplied by the alpha component. */
    ALPHA_FORMAT_UNPREMUL
} OH_Drawing_AlphaFormat;

/**
 * @brief The blending operation generates a new color for the two colors (source, destination).
 * These operations are the same on the 4 color channels: red, green, blue, alpha.
 * For these, we use alpha channel as an example, rather than naming each channel individually.
 *
 * For brevity, we use the following abbreviations.
 * s  : source
 * d  : destination
 * sa : source alpha
 * da : destination alpha
 *
 * Results are abbreviated
 * r  : if all 4 channels are computed in the same manner
 * ra : result alpha channel
 * rc : result "color": red, green, blue channels
 *
 * @since 11
 * @version 1.0
 */
typedef enum {
    /** r = 0. */
    BLEND_MODE_CLEAR,
    /** r = s. */
    BLEND_MODE_SRC,
    /** r = d. */
    BLEND_MODE_DST,
    /** r = s + (1-sa)*d. */
    BLEND_MODE_SRC_OVER,
    /** r = d + (1-da)*s. */
    BLEND_MODE_DST_OVER,
    /** r = s * da. */
    BLEND_MODE_SRC_IN,
    /** r = d * sa. */
    BLEND_MODE_DST_IN,
    /** r = s * (1-da). */
    BLEND_MODE_SRC_OUT,
    /** r = d * (1-sa). */
    BLEND_MODE_DST_OUT,
    /** r = s*da + d*(1-sa). */
    BLEND_MODE_SRC_ATOP,
    /** r = d*sa + s*(1-da). */
    BLEND_MODE_DST_ATOP,
    /** r = s*(1-da) + d*(1-sa). */
    BLEND_MODE_XOR,
    /** r = min(s + d, 1). */
    BLEND_MODE_PLUS,
    /** r = s*d. */
    BLEND_MODE_MODULATE,
    /** r = s + d - s*d. */
    BLEND_MODE_SCREEN,
    /** multiply or screen, depending on destination. */
    BLEND_MODE_OVERLAY,
    /** rc = s + d - max(s*da, d*sa), ra = s + (1-sa)*d. */
    BLEND_MODE_DARKEN,
    /** rc = s + d - min(s*da, d*sa), ra = s + (1-sa)*d. */
    BLEND_MODE_LIGHTEN,
    /** brighten destination to reflect source. */
    BLEND_MODE_COLOR_DODGE,
    /** darken destination to reflect source. */
    BLEND_MODE_COLOR_BURN,
    /** multiply or screen, depending on source. */
    BLEND_MODE_HARD_LIGHT,
    /** lighten or darken, depending on source. */
    BLEND_MODE_SOFT_LIGHT,
    /** rc = s + d - 2*(min(s*da, d*sa)), ra = s + (1-sa)*d. */
    BLEND_MODE_DIFFERENCE,
    /** rc = s + d - two(s*d), ra = s + (1-sa)*d. */
    BLEND_MODE_EXCLUSION,
    /** r = s*(1-da) + d*(1-sa) + s*d. */
    BLEND_MODE_MULTIPLY,
    /** hue of source with saturation and luminosity of destination. */
    BLEND_MODE_HUE,
    /** saturation of source with hue and luminosity of destination. */
    BLEND_MODE_SATURATION,
    /** hue and saturation of source with luminosity of destination. */
    BLEND_MODE_COLOR,
    /** luminosity of source with hue and saturation of destination. */
    BLEND_MODE_LUMINOSITY,
} OH_Drawing_BlendMode;

/**
 * @brief Defines image info struct.
 *
 * @since 12
 * @version 1.0
 */
typedef struct {
    /** storage for width of image */
    int32_t width;
    /** storage for height of image */
    int32_t height;
    /** storage for color formats */
    OH_Drawing_ColorFormat colorType;
    /** storage for alpha formats */
    OH_Drawing_AlphaFormat alphaType;
} OH_Drawing_Image_Info;

/**
 * @brief Defines rectstyle info struct.
 *
 * @since 12
 * @version 1.0
 */
typedef struct {
    /** color of rectstyle */
    uint32_t color;
    /** radius in left top of rectstyle */
    double leftTopRadius;
    /** radius in right top of rectstyle */
    double rightTopRadius;
    /** radius in right bottom of rectstyle */
    double rightBottomRadius;
    /** radius in left bottom of rectstyle */
    double leftBottomRadius;
} OH_Drawing_RectStyle_Info;

/**
 * @brief Enumerates text encoding types.
 * @since 12
 * @version 1.0
 */
typedef enum {
    /** uses bytes to represent UTF-8 or ASCII */
    TEXT_ENCODING_UTF8,
    /** uses two byte words to represent most of Unicode */
    TEXT_ENCODING_UTF16,
    /** uses four byte words to represent all of Unicode */
    TEXT_ENCODING_UTF32,
    /** uses two byte words to represent glyph indices */
    TEXT_ENCODING_GLYPH_ID,
} OH_Drawing_TextEncoding;

/**
 * @brief Defines a OH_Drawing_FontMgr, which is used to manage font family.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_Drawing_FontMgr OH_Drawing_FontMgr;

/**
 * @brief Defines a OH_Drawing_FontStyleSet, which is used to manage font style.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_Drawing_FontStyleSet OH_Drawing_FontStyleSet;

#ifdef __cplusplus
}
#endif
/** @} */
#endif