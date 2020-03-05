/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.

 * d2d1.h - Header file for the Direct2D API
 * No original Microsoft headers were used in the creation of this
 * file.
 *API docs available at: http://msdn.microsoft.com/en-us/library/dd372349%28v=VS.85%29.aspx
 */

#ifndef _D2D1_H
#define _D2D1_H

#include <unknwn.h>
#include <dcommon.h>

#ifdef __MINGW_HAS_DXSDK
#include <dxgiformat.h>
#include <d3d10_1.h>
#endif

#include <d2dbasetypes.h>
#include <d2derr.h>

#ifndef _COM_interface
#define _COM_interface struct
#endif

typedef UINT64 D2D1_TAG;

#if !defined(D2D_USE_C_DEFINITIONS) && !defined(__cplusplus)
#define D2D_USE_C_DEFINITIONS
#endif

#ifndef __IWICBitmapSource_FWD_DEFINED__
#define __IWICBitmapSource_FWD_DEFINED__
typedef interface IWICBitmapSource IWICBitmapSource;
#endif

#ifndef __IWICBitmap_FWD_DEFINED__
#define __IWICBitmap_FWD_DEFINED__
typedef interface IWICBitmap IWICBitmap;
#endif

typedef struct DWRITE_GLYPH_RUN DWRITE_GLYPH_RUN;

#define D2D1_INVALID_TAG ULONGLONG_MAX
#define D2D1_DEFAULT_FLATTENING_TOLERANCE (0.25f)

/* enumerations */

#ifndef __MINGW_HAS_DXSDK
typedef enum D3D10_FEATURE_LEVEL1 {
  D3D10_FEATURE_LEVEL_10_0   = 0xa000,
  D3D10_FEATURE_LEVEL_10_1   = 0xa100,
  D3D10_FEATURE_LEVEL_9_1    = 0x9100,
  D3D10_FEATURE_LEVEL_9_2    = 0x9200,
  D3D10_FEATURE_LEVEL_9_3    = 0x9300 
} D3D10_FEATURE_LEVEL1;

typedef enum DXGI_FORMAT {
  DXGI_FORMAT_UNKNOWN                      = 0,
  DXGI_FORMAT_R32G32B32A32_TYPELESS        = 1,
  DXGI_FORMAT_R32G32B32A32_FLOAT           = 2,
  DXGI_FORMAT_R32G32B32A32_UINT            = 3,
  DXGI_FORMAT_R32G32B32A32_SINT            = 4,
  DXGI_FORMAT_R32G32B32_TYPELESS           = 5,
  DXGI_FORMAT_R32G32B32_FLOAT              = 6,
  DXGI_FORMAT_R32G32B32_UINT               = 7,
  DXGI_FORMAT_R32G32B32_SINT               = 8,
  DXGI_FORMAT_R16G16B16A16_TYPELESS        = 9,
  DXGI_FORMAT_R16G16B16A16_FLOAT           = 10,
  DXGI_FORMAT_R16G16B16A16_UNORM           = 11,
  DXGI_FORMAT_R16G16B16A16_UINT            = 12,
  DXGI_FORMAT_R16G16B16A16_SNORM           = 13,
  DXGI_FORMAT_R16G16B16A16_SINT            = 14,
  DXGI_FORMAT_R32G32_TYPELESS              = 15,
  DXGI_FORMAT_R32G32_FLOAT                 = 16,
  DXGI_FORMAT_R32G32_UINT                  = 17,
  DXGI_FORMAT_R32G32_SINT                  = 18,
  DXGI_FORMAT_R32G8X24_TYPELESS            = 19,
  DXGI_FORMAT_D32_FLOAT_S8X24_UINT         = 20,
  DXGI_FORMAT_R32_FLOAT_X8X24_TYPELESS     = 21,
  DXGI_FORMAT_X32_TYPELESS_G8X24_UINT      = 22,
  DXGI_FORMAT_R10G10B10A2_TYPELESS         = 23,
  DXGI_FORMAT_R10G10B10A2_UNORM            = 24,
  DXGI_FORMAT_R10G10B10A2_UINT             = 25,
  DXGI_FORMAT_R11G11B10_FLOAT              = 26,
  DXGI_FORMAT_R8G8B8A8_TYPELESS            = 27,
  DXGI_FORMAT_R8G8B8A8_UNORM               = 28,
  DXGI_FORMAT_R8G8B8A8_UNORM_SRGB          = 29,
  DXGI_FORMAT_R8G8B8A8_UINT                = 30,
  DXGI_FORMAT_R8G8B8A8_SNORM               = 31,
  DXGI_FORMAT_R8G8B8A8_SINT                = 32,
  DXGI_FORMAT_R16G16_TYPELESS              = 33,
  DXGI_FORMAT_R16G16_FLOAT                 = 34,
  DXGI_FORMAT_R16G16_UNORM                 = 35,
  DXGI_FORMAT_R16G16_UINT                  = 36,
  DXGI_FORMAT_R16G16_SNORM                 = 37,
  DXGI_FORMAT_R16G16_SINT                  = 38,
  DXGI_FORMAT_R32_TYPELESS                 = 39,
  DXGI_FORMAT_D32_FLOAT                    = 40,
  DXGI_FORMAT_R32_FLOAT                    = 41,
  DXGI_FORMAT_R32_UINT                     = 42,
  DXGI_FORMAT_R32_SINT                     = 43,
  DXGI_FORMAT_R24G8_TYPELESS               = 44,
  DXGI_FORMAT_D24_UNORM_S8_UINT            = 45,
  DXGI_FORMAT_R24_UNORM_X8_TYPELESS        = 46,
  DXGI_FORMAT_X24_TYPELESS_G8_UINT         = 47,
  DXGI_FORMAT_R8G8_TYPELESS                = 48,
  DXGI_FORMAT_R8G8_UNORM                   = 49,
  DXGI_FORMAT_R8G8_UINT                    = 50,
  DXGI_FORMAT_R8G8_SNORM                   = 51,
  DXGI_FORMAT_R8G8_SINT                    = 52,
  DXGI_FORMAT_R16_TYPELESS                 = 53,
  DXGI_FORMAT_R16_FLOAT                    = 54,
  DXGI_FORMAT_D16_UNORM                    = 55,
  DXGI_FORMAT_R16_UNORM                    = 56,
  DXGI_FORMAT_R16_UINT                     = 57,
  DXGI_FORMAT_R16_SNORM                    = 58,
  DXGI_FORMAT_R16_SINT                     = 59,
  DXGI_FORMAT_R8_TYPELESS                  = 60,
  DXGI_FORMAT_R8_UNORM                     = 61,
  DXGI_FORMAT_R8_UINT                      = 62,
  DXGI_FORMAT_R8_SNORM                     = 63,
  DXGI_FORMAT_R8_SINT                      = 64,
  DXGI_FORMAT_A8_UNORM                     = 65,
  DXGI_FORMAT_R1_UNORM                     = 66,
  DXGI_FORMAT_R9G9B9E5_SHAREDEXP           = 67,
  DXGI_FORMAT_R8G8_B8G8_UNORM              = 68,
  DXGI_FORMAT_G8R8_G8B8_UNORM              = 69,
  DXGI_FORMAT_BC1_TYPELESS                 = 70,
  DXGI_FORMAT_BC1_UNORM                    = 71,
  DXGI_FORMAT_BC1_UNORM_SRGB               = 72,
  DXGI_FORMAT_BC2_TYPELESS                 = 73,
  DXGI_FORMAT_BC2_UNORM                    = 74,
  DXGI_FORMAT_BC2_UNORM_SRGB               = 75,
  DXGI_FORMAT_BC3_TYPELESS                 = 76,
  DXGI_FORMAT_BC3_UNORM                    = 77,
  DXGI_FORMAT_BC3_UNORM_SRGB               = 78,
  DXGI_FORMAT_BC4_TYPELESS                 = 79,
  DXGI_FORMAT_BC4_UNORM                    = 80,
  DXGI_FORMAT_BC4_SNORM                    = 81,
  DXGI_FORMAT_BC5_TYPELESS                 = 82,
  DXGI_FORMAT_BC5_UNORM                    = 83,
  DXGI_FORMAT_BC5_SNORM                    = 84,
  DXGI_FORMAT_B5G6R5_UNORM                 = 85,
  DXGI_FORMAT_B5G5R5A1_UNORM               = 86,
  DXGI_FORMAT_B8G8R8A8_UNORM               = 87,
  DXGI_FORMAT_B8G8R8X8_UNORM               = 88,
  DXGI_FORMAT_R10G10B10_XR_BIAS_A2_UNORM   = 89,
  DXGI_FORMAT_B8G8R8A8_TYPELESS            = 90,
  DXGI_FORMAT_B8G8R8A8_UNORM_SRGB          = 91,
  DXGI_FORMAT_B8G8R8X8_TYPELESS            = 92,
  DXGI_FORMAT_B8G8R8X8_UNORM_SRGB          = 93,
  DXGI_FORMAT_BC6H_TYPELESS                = 94,
  DXGI_FORMAT_BC6H_UF16                    = 95,
  DXGI_FORMAT_BC6H_SF16                    = 96,
  DXGI_FORMAT_BC7_TYPELESS                 = 97,
  DXGI_FORMAT_BC7_UNORM                    = 98,
  DXGI_FORMAT_BC7_UNORM_SRGB               = 99,
  DXGI_FORMAT_FORCE_UINT                   = 0xffffffff
} DXGI_FORMAT, *LPDXGI_FORMAT;

#endif /*__MINGW_HAS_DXSDK*/

#ifndef __IDWriteRenderingParams_FWD_DEFINED__
#define __IDWriteRenderingParams_FWD_DEFINED__
typedef struct IDWriteRenderingParams IDWriteRenderingParams;
#endif

#ifndef __IDXGISurface_FWD_DEFINED__
#define __IDXGISurface_FWD_DEFINED__
typedef struct IDXGISurface IDXGISurface;
#endif

#ifndef __IDWriteTextFormat_FWD_DEFINED__
#define __IDWriteTextFormat_FWD_DEFINED__
typedef struct IDWriteTextFormat IDWriteTextFormat;
#endif

#ifndef __IDWriteTextLayout_FWD_DEFINED__
#define __IDWriteTextLayout_FWD_DEFINED__
typedef struct IDWriteTextLayout IDWriteTextLayout;
#endif

#ifndef __IDWriteFontFace_FWD_DEFINED__
#define __IDWriteFontFace_FWD_DEFINED__
typedef struct IDWriteFontFace IDWriteFontFace;
#endif

typedef enum D2D1_ALPHA_MODE {
  D2D1_ALPHA_MODE_UNKNOWN         = 0,
  D2D1_ALPHA_MODE_PREMULTIPLIED   = 1,
  D2D1_ALPHA_MODE_STRAIGHT        = 2,
  D2D1_ALPHA_MODE_IGNORE          = 3,
  D2D1_ALPHA_MODE_FORCE_DWORD     = 0xffffffff
} D2D1_ALPHA_MODE;

typedef enum D2D1_ANTIALIAS_MODE {
  D2D1_ANTIALIAS_MODE_PER_PRIMITIVE   = 0,
  D2D1_ANTIALIAS_MODE_ALIASED         = 1,
  D2D1_ANTIALIAS_MODE_FORCE_DWORD     = 0xffffffff
} D2D1_ANTIALIAS_MODE;

typedef enum D2D1_ARC_SIZE {
  D2D1_ARC_SIZE_SMALL       = 0,
  D2D1_ARC_SIZE_LARGE       = 1,
  D2D1_ARC_SIZE_FORCE_DWORD = 0xffffffff
} D2D1_ARC_SIZE;

enum {
    D2D1_INTERPOLATION_MODE_DEFINITION_NEAREST_NEIGHBOR    = 0,
    D2D1_INTERPOLATION_MODE_DEFINITION_LINEAR              = 1,
    D2D1_INTERPOLATION_MODE_DEFINITION_CUBIC               = 2,
    D2D1_INTERPOLATION_MODE_DEFINITION_MULTI_SAMPLE_LINEAR = 3,
    D2D1_INTERPOLATION_MODE_DEFINITION_ANISOTROPIC         = 4,
    D2D1_INTERPOLATION_MODE_DEFINITION_HIGH_QUALITY_CUBIC  = 5,
    D2D1_INTERPOLATION_MODE_DEFINITION_FANT                = 6,
    D2D1_INTERPOLATION_MODE_DEFINITION_MIPMAP_LINEAR       = 7
};

typedef enum D2D1_BITMAP_INTERPOLATION_MODE {
  D2D1_BITMAP_INTERPOLATION_MODE_NEAREST_NEIGHBOR   = 0,
  D2D1_BITMAP_INTERPOLATION_MODE_LINEAR             = 1,
  D2D1_BITMAP_INTERPOLATION_MODE_FORCE_DWORD        = 0xffffffff
} D2D1_BITMAP_INTERPOLATION_MODE;

typedef enum D2D1_CAP_STYLE {
  D2D1_CAP_STYLE_FLAT        = 0,
  D2D1_CAP_STYLE_SQUARE      = 1,
  D2D1_CAP_STYLE_ROUND       = 2,
  D2D1_CAP_STYLE_TRIANGLE    = 3,
  D2D1_CAP_STYLE_FORCE_DWORD = 0xffffffff
} D2D1_CAP_STYLE;

typedef enum D2D1_COMBINE_MODE {
  D2D1_COMBINE_MODE_UNION       = 0,
  D2D1_COMBINE_MODE_INTERSECT   = 1,
  D2D1_COMBINE_MODE_XOR         = 2,
  D2D1_COMBINE_MODE_EXCLUDE     = 3,
  D2D1_COMBINE_MODE_FORCE_DWORD = 0xffffffff
} D2D1_COMBINE_MODE;

typedef enum D2D1_COMPATIBLE_RENDER_TARGET_OPTIONS {
  D2D1_COMPATIBLE_RENDER_TARGET_OPTIONS_NONE             = 0x00000000,
  D2D1_COMPATIBLE_RENDER_TARGET_OPTIONS_GDI_COMPATIBLE   = 0x00000001,
  D2D1_COMPATIBLE_RENDER_TARGET_OPTIONS_FORCE_DWORD      = 0xffffffff
} D2D1_COMPATIBLE_RENDER_TARGET_OPTIONS;

typedef enum D2D1_DASH_STYLE {
  D2D1_DASH_STYLE_SOLID          = 0,
  D2D1_DASH_STYLE_DASH           = 1,
  D2D1_DASH_STYLE_DOT            = 2,
  D2D1_DASH_STYLE_DASH_DOT       = 3,
  D2D1_DASH_STYLE_DASH_DOT_DOT   = 4,
  D2D1_DASH_STYLE_CUSTOM         = 5,
  D2D1_DASH_STYLE_FORCE_DWORD    = 0xffffffff
} D2D1_DASH_STYLE;

typedef enum D2D1_DC_INITIALIZE_MODE {
  D2D1_DC_INITIALIZE_MODE_COPY        = 0,
  D2D1_DC_INITIALIZE_MODE_CLEAR       = 1,
  D2D1_DC_INITIALIZE_MODE_FORCE_DWORD = 0xffffffff
} D2D1_DC_INITIALIZE_MODE;

typedef enum D2D1_DEBUG_LEVEL {
  D2D1_DEBUG_LEVEL_NONE          = 0,
  D2D1_DEBUG_LEVEL_ERROR         = 1,
  D2D1_DEBUG_LEVEL_WARNING       = 2,
  D2D1_DEBUG_LEVEL_INFORMATION   = 3,
  D2D1_DEBUG_LEVEL_FORCE_DWORD   = 0xffffffff
} D2D1_DEBUG_LEVEL;

typedef enum D2D1_DRAW_TEXT_OPTIONS {
  D2D1_DRAW_TEXT_OPTIONS_NO_SNAP                       = 0x00000001,
  D2D1_DRAW_TEXT_OPTIONS_CLIP                          = 0x00000002,
  D2D1_DRAW_TEXT_OPTIONS_ENABLE_COLOR_FONT             = 0x00000004,
  D2D1_DRAW_TEXT_OPTIONS_DISABLE_COLOR_BITMAP_SNAPPING = 0x00000008,
  D2D1_DRAW_TEXT_OPTIONS_NONE                          = 0x00000000,
  D2D1_DRAW_TEXT_OPTIONS_FORCE_DWORD                   = 0xffffffff
} D2D1_DRAW_TEXT_OPTIONS;

typedef enum D2D1_EXTEND_MODE {
  D2D1_EXTEND_MODE_CLAMP       = 0,
  D2D1_EXTEND_MODE_WRAP        = 1,
  D2D1_EXTEND_MODE_MIRROR      = 2,
  D2D1_EXTEND_MODE_FORCE_DWORD = 0xffffffff
} D2D1_EXTEND_MODE;

typedef enum D2D1_FACTORY_TYPE {
  D2D1_FACTORY_TYPE_SINGLE_THREADED   = 0,
  D2D1_FACTORY_TYPE_MULTI_THREADED    = 1,
  D2D1_FACTORY_TYPE_FORCE_DWORD       = 0xffffffff
} D2D1_FACTORY_TYPE;

typedef enum D2D1_FEATURE_LEVEL {
  D2D1_FEATURE_LEVEL_DEFAULT     = 0,
  D2D1_FEATURE_LEVEL_9           = D3D10_FEATURE_LEVEL_9_1,
  D2D1_FEATURE_LEVEL_10          = D3D10_FEATURE_LEVEL_10_0,
  D2D1_FEATURE_LEVEL_FORCE_DWORD = 0xffffffff
} D2D1_FEATURE_LEVEL;

typedef enum D2D1_FIGURE_BEGIN {
  D2D1_FIGURE_BEGIN_FILLED      = 0,
  D2D1_FIGURE_BEGIN_HOLLOW      = 1,
  D2D1_FIGURE_BEGIN_FORCE_DWORD = 0xffffffff
} D2D1_FIGURE_BEGIN;

typedef enum D2D1_FIGURE_END {
  D2D1_FIGURE_END_OPEN        = 0,
  D2D1_FIGURE_END_CLOSED      = 1,
  D2D1_FIGURE_END_FORCE_DWORD = 0xffffffff
} D2D1_FIGURE_END;

typedef enum D2D1_FILL_MODE {
  D2D1_FILL_MODE_ALTERNATE   = 0,
  D2D1_FILL_MODE_WINDING     = 1,
  D2D1_FILL_MODE_FORCE_DWORD = 0xffffffff
} D2D1_FILL_MODE;

typedef enum D2D1_GAMMA {
  D2D1_GAMMA_2_2         = 0,
  D2D1_GAMMA_1_0         = 1,
  D2D1_GAMMA_FORCE_DWORD = 0xffffffff
} D2D1_GAMMA;

typedef enum D2D1_GEOMETRY_RELATION {
  D2D1_GEOMETRY_RELATION_UNKNOWN        = 0,
  D2D1_GEOMETRY_RELATION_DISJOINT       = 1,
  D2D1_GEOMETRY_RELATION_IS_CONTAINED   = 2,
  D2D1_GEOMETRY_RELATION_CONTAINS       = 3,
  D2D1_GEOMETRY_RELATION_OVERLAP        = 4,
  D2D1_GEOMETRY_RELATION_FORCE_DWORD    = 0xffffffff
} D2D1_GEOMETRY_RELATION;

typedef enum D2D1_GEOMETRY_SIMPLIFICATION_OPTION {
  D2D1_GEOMETRY_SIMPLIFICATION_OPTION_CUBICS_AND_LINES   = 0,
  D2D1_GEOMETRY_SIMPLIFICATION_OPTION_LINES              = 1,
  D2D1_GEOMETRY_SIMPLIFICATION_OPTION_FORCE_DWORD        = 0xffffffff
} D2D1_GEOMETRY_SIMPLIFICATION_OPTION;

typedef enum D2D1_LAYER_OPTIONS {
  D2D1_LAYER_OPTIONS_NONE                       = 0x00000000,
  D2D1_LAYER_OPTIONS_INITIALIZE_FOR_CLEARTYPE   = 0x00000001,
  D2D1_LAYER_OPTIONS_FORCE_DWORD                = 0xffffffff
} D2D1_LAYER_OPTIONS;

typedef enum D2D1_LINE_JOIN {
  D2D1_LINE_JOIN_MITER            = 0,
  D2D1_LINE_JOIN_BEVEL            = 1,
  D2D1_LINE_JOIN_ROUND            = 2,
  D2D1_LINE_JOIN_MITER_OR_BEVEL   = 3,
  D2D1_LINE_JOIN_FORCE_DWORD      = 0xffffffff
} D2D1_LINE_JOIN;

typedef enum D2D1_OPACITY_MASK_CONTENT {
  D2D1_OPACITY_MASK_CONTENT_GRAPHICS              = 0,
  D2D1_OPACITY_MASK_CONTENT_TEXT_NATURAL          = 1,
  D2D1_OPACITY_MASK_CONTENT_TEXT_GDI_COMPATIBLE   = 2,
  D2D1_OPACITY_MASK_CONTENT_FORCE_DWORD           = 0xffffffff
} D2D1_OPACITY_MASK_CONTENT;

typedef enum D2D1_PATH_SEGMENT {
  D2D1_PATH_SEGMENT_NONE                    = 0x00000000,
  D2D1_PATH_SEGMENT_FORCE_UNSTROKED         = 0x00000001,
  D2D1_PATH_SEGMENT_FORCE_ROUND_LINE_JOIN   = 0x00000002,
  D2D1_PATH_SEGMENT_FORCE_DWORD             = 0xffffffff
} D2D1_PATH_SEGMENT;

typedef enum D2D1_PRESENT_OPTIONS {
  D2D1_PRESENT_OPTIONS_NONE              = 0x00000000,
  D2D1_PRESENT_OPTIONS_RETAIN_CONTENTS   = 0x00000001,
  D2D1_PRESENT_OPTIONS_IMMEDIATELY       = 0x00000002,
  D2D1_PRESENT_OPTIONS_FORCE_DWORD       = 0xffffffff
} D2D1_PRESENT_OPTIONS;

typedef enum D2D1_RENDER_TARGET_TYPE {
  D2D1_RENDER_TARGET_TYPE_DEFAULT     = 0,
  D2D1_RENDER_TARGET_TYPE_SOFTWARE    = 1,
  D2D1_RENDER_TARGET_TYPE_HARDWARE    = 2,
  D2D1_RENDER_TARGET_TYPE_FORCE_DWORD = 0xffffffff
} D2D1_RENDER_TARGET_TYPE;

typedef enum D2D1_RENDER_TARGET_USAGE {
  D2D1_RENDER_TARGET_USAGE_NONE                    = 0x00000000,
  D2D1_RENDER_TARGET_USAGE_FORCE_BITMAP_REMOTING   = 0x00000001,
  D2D1_RENDER_TARGET_USAGE_GDI_COMPATIBLE          = 0x00000002,
  D2D1_RENDER_TARGET_USAGE_FORCE_DWORD             = 0xffffffff
} D2D1_RENDER_TARGET_USAGE;

typedef enum D2D1_SWEEP_DIRECTION {
  D2D1_SWEEP_DIRECTION_COUNTER_CLOCKWISE   = 0,
  D2D1_SWEEP_DIRECTION_CLOCKWISE           = 1,
  D2D1_SWEEP_DIRECTION_FORCE_DWORD         = 0xffffffff
} D2D1_SWEEP_DIRECTION;

typedef enum D2D1_TEXT_ANTIALIAS_MODE {
  D2D1_TEXT_ANTIALIAS_MODE_DEFAULT     = 0,
  D2D1_TEXT_ANTIALIAS_MODE_CLEARTYPE   = 1,
  D2D1_TEXT_ANTIALIAS_MODE_GRAYSCALE   = 2,
  D2D1_TEXT_ANTIALIAS_MODE_ALIASED     = 3,
  D2D1_TEXT_ANTIALIAS_MODE_FORCE_DWORD = 0xffffffff
} D2D1_TEXT_ANTIALIAS_MODE;

typedef enum D2D1_WINDOW_STATE {
  D2D1_WINDOW_STATE_NONE        = 0x00000000,
  D2D1_WINDOW_STATE_OCCLUDED    = 0x00000001,
  D2D1_WINDOW_STATE_FORCE_DWORD = 0xffffffff
} D2D1_WINDOW_STATE;

/* this is a hack so we can use forward declares in C (easier than reordering interfaces) */
#if !defined(__cplusplus)
#undef DECLARE_INTERFACE
#define DECLARE_INTERFACE(iface) struct iface { struct iface##Vtbl *lpVtbl; }; typedef struct iface##Vtbl iface##Vtbl; struct iface##Vtbl
#endif

/* interface forward declares */

typedef _COM_interface ID2D1Bitmap ID2D1Bitmap;
typedef _COM_interface ID2D1BitmapBrush ID2D1BitmapBrush;
typedef _COM_interface ID2D1BitmapRenderTarget ID2D1BitmapRenderTarget;
typedef _COM_interface ID2D1Brush ID2D1Brush;
typedef _COM_interface ID2D1DCRenderTarget ID2D1DCRenderTarget;
typedef _COM_interface ID2D1DrawingStateBlock ID2D1DrawingStateBlock;
typedef _COM_interface ID2D1EllipseGeometry ID2D1EllipseGeometry;
typedef _COM_interface ID2D1Factory ID2D1Factory;
typedef _COM_interface ID2D1GdiInteropRenderTarget ID2D1GdiInteropRenderTarget;
typedef _COM_interface ID2D1Geometry ID2D1Geometry;
typedef _COM_interface ID2D1GeometryGroup ID2D1GeometryGroup;
typedef _COM_interface ID2D1GeometrySink ID2D1GeometrySink;
typedef _COM_interface ID2D1GradientStopCollection ID2D1GradientStopCollection;
typedef _COM_interface ID2D1HwndRenderTarget ID2D1HwndRenderTarget;
typedef _COM_interface ID2D1Layer ID2D1Layer;
typedef _COM_interface ID2D1LinearGradientBrush ID2D1LinearGradientBrush;
typedef _COM_interface ID2D1Mesh ID2D1Mesh;
typedef _COM_interface ID2D1PathGeometry ID2D1PathGeometry;
typedef _COM_interface ID2D1RadialGradientBrush ID2D1RadialGradientBrush;
typedef _COM_interface ID2D1RectangleGeometry ID2D1RectangleGeometry;
typedef _COM_interface ID2D1RenderTarget ID2D1RenderTarget;
typedef _COM_interface ID2D1Resource ID2D1Resource;
typedef _COM_interface ID2D1RoundedRectangleGeometry ID2D1RoundedRectangleGeometry;
typedef _COM_interface ID2D1SimplifiedGeometrySink ID2D1SimplifiedGeometrySink;
typedef _COM_interface ID2D1SolidColorBrush ID2D1SolidColorBrush;
typedef _COM_interface ID2D1StrokeStyle ID2D1StrokeStyle;
typedef _COM_interface ID2D1TessellationSink ID2D1TessellationSink;
typedef _COM_interface ID2D1TransformedGeometry ID2D1TransformedGeometry;

/* structures */

typedef struct D2D_MATRIX_3X2_F D2D1_MATRIX_3X2_F;

typedef struct D2D1_ARC_SEGMENT D2D1_ARC_SEGMENT;
typedef struct D2D1_BEZIER_SEGMENT D2D1_BEZIER_SEGMENT;
typedef struct D2D1_BITMAP_BRUSH_PROPERTIES D2D1_BITMAP_BRUSH_PROPERTIES;
typedef struct D2D1_BITMAP_PROPERTIES D2D1_BITMAP_PROPERTIES;
typedef struct D2D1_BRUSH_PROPERTIES D2D1_BRUSH_PROPERTIES;
typedef struct D2D1_DRAWING_STATE_DESCRIPTION D2D1_DRAWING_STATE_DESCRIPTION;
typedef struct D2D1_ELLIPSE D2D1_ELLIPSE;
typedef struct D2D1_FACTORY_OPTIONS D2D1_FACTORY_OPTIONS;
typedef struct D2D1_GRADIENT_STOP D2D1_GRADIENT_STOP;
typedef struct D2D1_HWND_RENDER_TARGET_PROPERTIES D2D1_HWND_RENDER_TARGET_PROPERTIES;
typedef struct D2D1_LAYER_PARAMETERS D2D1_LAYER_PARAMETERS;
typedef struct D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES;
typedef struct D2D1_PIXEL_FORMAT D2D1_PIXEL_FORMAT;
typedef struct D2D1_QUADRATIC_BEZIER_SEGMENT D2D1_QUADRATIC_BEZIER_SEGMENT;
typedef struct D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES;
typedef struct D2D1_RENDER_TARGET_PROPERTIES D2D1_RENDER_TARGET_PROPERTIES;
typedef struct D2D1_ROUNDED_RECT D2D1_ROUNDED_RECT;
typedef struct D2D1_STROKE_STYLE_PROPERTIES D2D1_STROKE_STYLE_PROPERTIES;
typedef struct D2D1_TRIANGLE D2D1_TRIANGLE;

struct D2D1_ARC_SEGMENT {
  D2D1_POINT_2F        point;
  D2D1_SIZE_F          size;
  FLOAT                rotationAngle;
  D2D1_SWEEP_DIRECTION sweepDirection;
  D2D1_ARC_SIZE        arcSize;
};

struct D2D1_BEZIER_SEGMENT {
  D2D1_POINT_2F point1;
  D2D1_POINT_2F point2;
  D2D1_POINT_2F point3;
};

struct D2D1_BITMAP_BRUSH_PROPERTIES {
  D2D1_EXTEND_MODE               extendModeX;
  D2D1_EXTEND_MODE               extendModeY;
  D2D1_BITMAP_INTERPOLATION_MODE interpolationMode;
};

struct D2D1_PIXEL_FORMAT {
  DXGI_FORMAT     format;
  D2D1_ALPHA_MODE alphaMode;
};

struct D2D1_BITMAP_PROPERTIES {
  D2D1_PIXEL_FORMAT pixelFormat;
  FLOAT             dpiX;
  FLOAT             dpiY;
};

struct D2D1_BRUSH_PROPERTIES {
  FLOAT             opacity;
  D2D1_MATRIX_3X2_F transform;
};

struct D2D1_DRAWING_STATE_DESCRIPTION {
  D2D1_ANTIALIAS_MODE      antialiasMode;
  D2D1_TEXT_ANTIALIAS_MODE textAntialiasMode;
  D2D1_TAG                 tag1;
  D2D1_TAG                 tag2;
  D2D1_MATRIX_3X2_F        transform;
};

struct D2D1_ELLIPSE {
  D2D1_POINT_2F point;
  FLOAT         radiusX;
  FLOAT         radiusY;
};

struct D2D1_FACTORY_OPTIONS {
  D2D1_DEBUG_LEVEL debugLevel;
};

struct D2D1_GRADIENT_STOP {
  FLOAT        position;
  D2D1_COLOR_F color;
};

struct D2D1_HWND_RENDER_TARGET_PROPERTIES {
  HWND                 hwnd;
  D2D1_SIZE_U          pixelSize;
  D2D1_PRESENT_OPTIONS presentOptions;
};

struct D2D1_LAYER_PARAMETERS {
  D2D1_RECT_F         contentBounds;
  ID2D1Geometry       *geometricMask;
  D2D1_ANTIALIAS_MODE maskAntialiasMode;
  D2D1_MATRIX_3X2_F   maskTransform;
  FLOAT               opacity;
  ID2D1Brush          *opacityBrush;
  D2D1_LAYER_OPTIONS  layerOptions;
};

struct D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES {
  D2D1_POINT_2F startPoint;
  D2D1_POINT_2F endPoint;
};

struct D2D1_QUADRATIC_BEZIER_SEGMENT {
  D2D1_POINT_2F point1;
  D2D1_POINT_2F point2;
};

struct D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES {
  D2D1_POINT_2F center;
  D2D1_POINT_2F gradientOriginOffset;
  FLOAT         radiusX;
  FLOAT         radiusY;
};

struct D2D1_RENDER_TARGET_PROPERTIES {
  D2D1_RENDER_TARGET_TYPE  type;
  D2D1_PIXEL_FORMAT        pixelFormat;
  FLOAT                    dpiX;
  FLOAT                    dpiY;
  D2D1_RENDER_TARGET_USAGE usage;
  D2D1_FEATURE_LEVEL       minLevel;
};

struct D2D1_ROUNDED_RECT {
  D2D1_RECT_F rect;
  FLOAT       radiusX;
  FLOAT       radiusY;
};

struct D2D1_STROKE_STYLE_PROPERTIES {
  D2D1_CAP_STYLE  startCap;
  D2D1_CAP_STYLE  endCap;
  D2D1_CAP_STYLE  dashCap;
  D2D1_LINE_JOIN  lineJoin;
  FLOAT           miterLimit;
  D2D1_DASH_STYLE dashStyle;
  FLOAT           dashOffset;
};

struct D2D1_TRIANGLE {
  D2D1_POINT_2F point1;
  D2D1_POINT_2F point2;
  D2D1_POINT_2F point3;
};

/* interfaces */

/**
 * Header generated from msdn for the purposes of allowing 
 * 3rd party compiler compatibility with the Microsoft API 
 */
DEFINE_GUID(IID_ID2D1Resource, 0x2cd90691,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1Resource : public IUnknown {
    STDMETHOD_(void, GetFactory)(ID2D1Factory **factory) const PURE;
};

#else

typedef struct ID2D1ResourceVtbl {
    IUnknownVtbl Base;

    STDMETHOD_(void, GetFactory)(ID2D1Resource *This, ID2D1Factory **factory) PURE;
} ID2D1ResourceVtbl;

interface ID2D1Resource {
    const ID2D1ResourceVtbl *lpVtbl;
};

#define ID2D1Resource_QueryInterface(this,A,B) (this)->lpVtbl->Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1Resource_AddRef(this) (this)->lpVtbl->Base.AddRef((IUnknown*)(this))
#define ID2D1Resource_Release(this) (this)->lpVtbl->Base.Release((IUnknown*)(this))
#define ID2D1Resource_GetFactory(this,A) (this)->lpVtbl->GetFactory(this,A)

#endif

DEFINE_GUID(IID_ID2D1Brush, 0x2cd906a8,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1Brush : public ID2D1Resource {
    STDMETHOD_(void, SetOpacity)(FLOAT opacity) PURE;
    STDMETHOD_(void, SetTransform)(const D2D1_MATRIX_3X2_F *transform) PURE;
    STDMETHOD_(FLOAT, GetOpacity)(void) const PURE;
    STDMETHOD_(void, GetTransform)(D2D1_MATRIX_3X2_F *transform) const PURE;

    void SetTransform(const D2D1_MATRIX_3X2_F &transform) {
        SetTransform(&transform);
    }
};

#else

typedef struct ID2D1BrushVtbl {
    ID2D1ResourceVtbl Base;

    STDMETHOD_(void, SetOpacity)(ID2D1Brush *This, FLOAT opacity) PURE;
    STDMETHOD_(void, SetTransform)(ID2D1Brush *This, const D2D1_MATRIX_3X2_F *transform) PURE;
    STDMETHOD_(FLOAT, GetOpacity)(ID2D1Brush *This) PURE;
    STDMETHOD_(void, GetTransform)(ID2D1Brush *This, D2D1_MATRIX_3X2_F *transform) PURE;
} ID2D1BrushVtbl;

interface ID2D1Brush {
    const ID2D1BrushVtbl *lpVtbl;
};

#define ID2D1Brush_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1Brush_AddRef(this) (this)->lpVtbl->Base.Base.AddRef((IUnknown*)(this))
#define ID2D1Brush_Release(this) (this)->lpVtbl->Base.Base.Release((IUnknown*)(this))
#define ID2D1Brush_GetFactory(this,A) (this)->lpVtbl->Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1Brush_SetOpacity(this,A) (this)->lpVtbl->SetOpacity(this,A)
#define ID2D1Brush_SetTransform(this,A) (this)->lpVtbl->SetTransform(this,A)
#define ID2D1Brush_GetOpacity(this) (this)->lpVtbl->GetOpacity(this)
#define ID2D1Brush_GetTransform(this,A) (this)->lpVtbl->GetTransform(this,A)

#endif

DEFINE_GUID(IID_ID2D1Image, 0x65019f75,0x8da2,0x497c,0xb3,0x2c,0xdf,0xa3,0x4e,0x48,0xed,0xe6);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1Image : public ID2D1Resource {};

#else

typedef struct ID2D1ImageVtbl {
    ID2D1ResourceVtbl Base;
} ID2D1ImageVtbl;

interface ID2D1Image {
    const ID2D1ImageVtbl *lpVtbl;
};

#define ID2D1Image_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.QueryInterface((IUnkwnown*)(this),A,B)
#define ID2D1Image_AddRef(this) (this)->lpVtbl->Base.Base.AddRef((IUnknown*)(this))
#define ID2D1Image_Release(this) (this)->lpVtbl->Base.Base.Release((IUnknown*)(this))
#define ID2D1Image_GetFactory(this,A) (this)->lpVtbl->Base.GetFactory((ID2D1Resource*)(this),A)

#endif

DEFINE_GUID(IID_ID2D1Bitmap, 0xa2296057,0xea42,0x4099,0x98,0x3b,0x53,0x9f,0xb6,0x50,0x54,0x26);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1Bitmap : public ID2D1Image {
#ifndef WIDL_EXPLICIT_AGGREGATE_RETURNS
    STDMETHOD_(D2D1_SIZE_F, GetSize)(void) const PURE;
#else
    virtual D2D1_SIZE_F* STDMETHODCALLTYPE GetSize(D2D1_SIZE_F*) const = 0;
    D2D1_SIZE_F STDMETHODCALLTYPE GetSize() const {
        D2D1_SIZE_F __ret;
        GetSize(&__ret);
        return __ret;
    }
#endif

#ifndef WIDL_EXPLICIT_AGGREGATE_RETURNS
    STDMETHOD_(D2D1_SIZE_U, GetPixelSize)(void) const PURE;
#else
    virtual D2D1_SIZE_U* STDMETHODCALLTYPE GetPixelSize(D2D1_SIZE_U*) const = 0;
    D2D1_SIZE_U STDMETHODCALLTYPE GetPixelSize() const {
        D2D1_SIZE_U __ret;
        GetPixelSize(&__ret);
        return __ret;
    }
#endif

#ifndef WIDL_EXPLICIT_AGGREGATE_RETURNS
    STDMETHOD_(D2D1_PIXEL_FORMAT, GetPixelFormat)(void) const PURE;
#else
    virtual D2D1_PIXEL_FORMAT* STDMETHODCALLTYPE GetPixelFormat(D2D1_PIXEL_FORMAT*) const = 0;
    D2D1_PIXEL_FORMAT STDMETHODCALLTYPE GetPixelFormat() const {
        D2D1_PIXEL_FORMAT __ret;
        GetPixelFormat(&__ret);
        return __ret;
    }
#endif

    STDMETHOD_(void, GetDpi)(FLOAT *dpiX, FLOAT *dpiY) const PURE;
    STDMETHOD(CopyFromBitmap)(const D2D1_POINT_2U *destPoint, ID2D1Bitmap *bitmap, const D2D1_RECT_U *srcRect) PURE;
    STDMETHOD(CopyFromRenderTarget)(const D2D1_POINT_2U *destPoint, ID2D1RenderTarget *renderTarget, const D2D1_RECT_U *srcRect) PURE;
    STDMETHOD(CopyFromMemory)(const D2D1_RECT_U *dstRect, const void *srcData, UINT32 pitch) PURE;
};

#else

typedef struct ID2D1BitmapVtbl {
    ID2D1ImageVtbl Base;

    STDMETHOD_(D2D1_SIZE_F, GetSize)(ID2D1Bitmap *This) PURE;
    STDMETHOD_(D2D1_SIZE_U, GetPixelSize)(ID2D1Bitmap *This) PURE;
    STDMETHOD_(D2D1_PIXEL_FORMAT, GetPixelFormat)(ID2D1Bitmap *This) PURE;
    STDMETHOD_(void, GetDpi)(ID2D1Bitmap *This, FLOAT *dpiX, FLOAT *dpiY) PURE;
    STDMETHOD(CopyFromBitmap)(ID2D1Bitmap *This, const D2D1_POINT_2U *destPoint, ID2D1Bitmap *bitmap, const D2D1_RECT_U *srcRect) PURE;
    STDMETHOD(CopyFromRenderTarget)(ID2D1Bitmap *This, const D2D1_POINT_2U *destPoint, ID2D1RenderTarget *renderTarget, const D2D1_RECT_U *srcRect) PURE;
    STDMETHOD(CopyFromMemory)(ID2D1Bitmap *This, const D2D1_RECT_U *dstRect, const void *srcData, UINT32 pitch) PURE;
} ID2D1BitmapVtbl;

interface ID2D1Bitmap {
    const ID2D1BitmapVtbl *lpVtbl;
};

#define ID2D1Bitmap_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.Base.QueryInterface((IUnkwnown*)(this),A,B)
#define ID2D1Bitmap_AddRef(this) (this)->lpVtbl->Base.Base.Base.AddRef((IUnknown*)(this))
#define ID2D1Bitmap_Release(this) (this)->lpVtbl->Base.Base.Base.Release((IUnknown*)(this))
#define ID2D1Bitmap_GetFactory(this,A) (this)->lpVtbl->Base.Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1Bitmap_GetSize(this) (this)->lpVtbl->GetSize(this)
#define ID2D1Bitmap_GetPixelSize(this) (this)->lpVtbl->GetPixelSize(this)
#define ID2D1Bitmap_GetPixelFormat(this) (this)->lpVtbl->GetPixelFormat(this)
#define ID2D1Bitmap_GetDpi(this,A,B) (this)->lpVtbl->GetDpi(this,A,B)
#define ID2D1Bitmap_CopyFromBitmap(this,A,B,C) (this)->lpVtbl->CopyFromBitmap(this,A,B,C)
#define ID2D1Bitmap_CopyFromRenderTarget(this,A,B,C) (this)->lpVtbl->CopyFromRenderTarget(this,A,B,C)
#define ID2D1Bitmap_CopyFromMemory(this,A,B,C) (this)->lpVtbl->CopyFromMemory(this,A,B,C)

#endif

DEFINE_GUID(IID_ID2D1BitmapBrush, 0x2cd906aa,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1BitmapBrush : public ID2D1Brush {
    STDMETHOD_(void, SetExtendModeX)(D2D1_EXTEND_MODE extendModeX) PURE;
    STDMETHOD_(void, SetExtendModeY)(D2D1_EXTEND_MODE extendModeY) PURE;
    STDMETHOD_(void, SetInterpolationMode)(D2D1_BITMAP_INTERPOLATION_MODE interpolationMode) PURE;
    STDMETHOD_(void, SetBitmap)(ID2D1Bitmap *bitmap) PURE;
    STDMETHOD_(D2D1_EXTEND_MODE, GetExtendModeX)(void) const PURE;
    STDMETHOD_(D2D1_EXTEND_MODE, GetExtendModeY)(void) const PURE;
    STDMETHOD_(D2D1_BITMAP_INTERPOLATION_MODE, GetInterpolationMode)(void) const PURE;
    STDMETHOD_(void, GetBitmap)(ID2D1Bitmap **bitmap) const PURE;
};

#else

typedef struct ID2D1BitmapBrushVtbl {
    ID2D1BrushVtbl Base;

    STDMETHOD_(void, SetExtendModeX)(ID2D1BitmapBrush *This, D2D1_EXTEND_MODE extendModeX) PURE;
    STDMETHOD_(void, SetExtendModeY)(ID2D1BitmapBrush *This, D2D1_EXTEND_MODE extendModeY) PURE;
    STDMETHOD_(void, SetInterpolationMode)(ID2D1BitmapBrush *This, D2D1_BITMAP_INTERPOLATION_MODE interpolationMode) PURE;
    STDMETHOD_(void, SetBitmap)(ID2D1BitmapBrush *This, ID2D1Bitmap *bitmap) PURE;
    STDMETHOD_(D2D1_EXTEND_MODE, GetExtendModeX)(ID2D1BitmapBrush *This) PURE;
    STDMETHOD_(D2D1_EXTEND_MODE, GetExtendModeY)(ID2D1BitmapBrush *This) PURE;
    STDMETHOD_(D2D1_BITMAP_INTERPOLATION_MODE, GetInterpolationMode)(ID2D1BitmapBrush *This) PURE;
    STDMETHOD_(void, GetBitmap)(ID2D1BitmapBrush *This, ID2D1Bitmap **bitmap) PURE;
} ID2D1BitmapBrushVtbl;

interface ID2D1BitmapBrush {
    const ID2D1BitmapBrushVtbl *lpVtbl;
};

#define ID2D1BitmapBrush_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.Base.QueryInterface((IUnkwnown*)(this),A,B)
#define ID2D1BitmapBrush_AddRef(this) (this)->lpVtbl->Base.Base.Base.AddRef((IUnknown*)(this))
#define ID2D1BitmapBrush_Release(this) (this)->lpVtbl->Base.Base.Base.Release((IUnknown*)(this))
#define ID2D1BitmapBrush_GetFactory(this,A) (this)->lpVtbl->Base.Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1BitmapBrush_SetOpacity(this,A) (this)->lpVtbl->Base.SetOpacity((ID2D1Brush*)(this),A)
#define ID2D1BitmapBrush_SetTransform(this,A) (this)->lpVtbl->Base.SetTransform((ID2D1Brush*)(this),A)
#define ID2D1BitmapBrush_GetOpacity(this) (this)->lpVtbl->Base.GetOpacity((ID2D1Brush*)(this))
#define ID2D1BitmapBrush_GetTransform(this,A) (this)->lpVtbl->Base.GetTransform((ID2D1Brush*)(this),A)
#define ID2D1BitmapBrush_SetExtendModeX(this,A) (this)->lpVtbl->SetExtendModeX(this,A)
#define ID2D1BitmapBrush_SetExtendModeY(this,A) (this)->lpVtbl->SetExtendModeY(this,A)
#define ID2D1BitmapBrush_SetInterpolationMode(this,A) (this)->lpVtbl->SetInterpolationMode(this,A)
#define ID2D1BitmapBrush_SetBitmap(this,A) (this)->lpVtbl->SetBitmap(this,A)
#define ID2D1BitmapBrush_GetExtendModeX(this) (this)->lpVtbl->GetExtendModeX(this)
#define ID2D1BitmapBrush_GetExtendModeY(this) (this)->lpVtbl->GetExtendModeY(this)
#define ID2D1BitmapBrush_GetInterpolationMode(this) (this)->lpVtbl->GetInterpolationMode(this)
#define ID2D1BitmapBrush_GetBitmap(this,A) (this)->lpVtbl->GetBitmap(this,A)

#endif

DEFINE_GUID(IID_ID2D1RenderTarget, 0x2cd90694,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9); 

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1RenderTarget : public ID2D1Resource {
    STDMETHOD(CreateBitmap)(D2D1_SIZE_U size, const void *srcData, UINT32 pitch, const D2D1_BITMAP_PROPERTIES *bitmapProperties, ID2D1Bitmap **bitmap) PURE;
    STDMETHOD(CreateBitmapFromWicBitmap)(IWICBitmapSource *wicBitmapSource, const D2D1_BITMAP_PROPERTIES *bitmapProperties, ID2D1Bitmap **bitmap) PURE;
    STDMETHOD(CreateSharedBitmap)(REFIID riid, void *data, const D2D1_BITMAP_PROPERTIES *bitmapProperties, ID2D1Bitmap **bitmap) PURE;
    STDMETHOD(CreateBitmapBrush)(ID2D1Bitmap *bitmap, const D2D1_BITMAP_BRUSH_PROPERTIES *bitmapBrushProperties, const D2D1_BRUSH_PROPERTIES *brushProperties, ID2D1BitmapBrush **bitmapBrush) PURE;
    STDMETHOD(CreateSolidColorBrush)(const D2D1_COLOR_F *color, const D2D1_BRUSH_PROPERTIES *brushProperties, ID2D1SolidColorBrush **solidColorBrush) PURE;
    STDMETHOD(CreateGradientStopCollection)(const D2D1_GRADIENT_STOP *gradientStops, UINT gradientStopsCount, D2D1_GAMMA colorInterpolationGamma, D2D1_EXTEND_MODE extendMode, ID2D1GradientStopCollection **gradientStopCollection) PURE;
    STDMETHOD(CreateLinearGradientBrush)(const D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES *linearGradientBrushProperties, const D2D1_BRUSH_PROPERTIES *brushProperties, ID2D1GradientStopCollection *gradientStopCollection, ID2D1LinearGradientBrush **linearGradientBrush) PURE;
    STDMETHOD(CreateRadialGradientBrush)(const D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES *radialGradientBrushProperties, const D2D1_BRUSH_PROPERTIES *brushProperties, ID2D1GradientStopCollection *gradientStopCollection, ID2D1RadialGradientBrush **radialGradientBrush) PURE;
    STDMETHOD(CreateCompatibleRenderTarget)(const D2D1_SIZE_F *desiredSize, const D2D1_SIZE_U *desiredPixelSize, const D2D1_PIXEL_FORMAT *desiredFormat, D2D1_COMPATIBLE_RENDER_TARGET_OPTIONS options, ID2D1BitmapRenderTarget **bitmapRenderTarget) PURE;
    STDMETHOD(CreateLayer)(const D2D1_SIZE_F *size, ID2D1Layer **layer) PURE;
    STDMETHOD(CreateMesh)(ID2D1Mesh **mesh) PURE;
    STDMETHOD_(void, DrawLine)(D2D1_POINT_2F point0, D2D1_POINT_2F point1, ID2D1Brush *brush, FLOAT strokeWidth = 1.0f, ID2D1StrokeStyle *strokeStyle = NULL) PURE;
    STDMETHOD_(void, DrawRectangle)(const D2D1_RECT_F *rect, ID2D1Brush *brush, FLOAT strokeWidth = 1.0f, ID2D1StrokeStyle *strokeStyle = NULL) PURE;
    STDMETHOD_(void, FillRectangle)(const D2D1_RECT_F *rect, ID2D1Brush *brush) PURE;
    STDMETHOD_(void, DrawRoundedRectangle)(const D2D1_ROUNDED_RECT *roundedRect, ID2D1Brush *brush, FLOAT strokeWidth = 1.0f, ID2D1StrokeStyle *strokeStyle = NULL) PURE;
    STDMETHOD_(void, FillRoundedRectangle)(const D2D1_ROUNDED_RECT *roundedRect, ID2D1Brush *brush) PURE;
    STDMETHOD_(void, DrawEllipse)(const D2D1_ELLIPSE *ellipse, ID2D1Brush *brush, FLOAT strokeWidth = 1.0f, ID2D1StrokeStyle *strokeStyle = NULL) PURE;
    STDMETHOD_(void, FillEllipse)(const D2D1_ELLIPSE *ellipse, ID2D1Brush *brush) PURE;
    STDMETHOD_(void, DrawGeometry)(ID2D1Geometry *geometry, ID2D1Brush *brush, FLOAT strokeWidth = 1.0f, ID2D1StrokeStyle *strokeStyle = NULL) PURE;
    STDMETHOD_(void, FillGeometry)(ID2D1Geometry *geometry, ID2D1Brush *brush, ID2D1Brush *opacityBrush = NULL) PURE;
    STDMETHOD_(void, FillMesh)(ID2D1Mesh *mesh, ID2D1Brush *brush) PURE;
    STDMETHOD_(void, FillOpacityMask)(ID2D1Bitmap *opacityMask, ID2D1Brush *brush, D2D1_OPACITY_MASK_CONTENT content, const D2D1_RECT_F *destinationRectangle = NULL, const D2D1_RECT_F *sourceRectangle = NULL) PURE;
    STDMETHOD_(void, DrawBitmap)(ID2D1Bitmap *bitmap, const D2D1_RECT_F *destinationRectangle = NULL, FLOAT opacity = 1.0f, D2D1_BITMAP_INTERPOLATION_MODE interpolationMode = D2D1_BITMAP_INTERPOLATION_MODE_LINEAR, const D2D1_RECT_F *sourceRectangle = NULL) PURE;
    STDMETHOD_(void, DrawText)(const WCHAR *string, UINT stringLength, IDWriteTextFormat *textFormat, const D2D1_RECT_F *layoutRect, ID2D1Brush *defaultForegroundBrush, D2D1_DRAW_TEXT_OPTIONS options = D2D1_DRAW_TEXT_OPTIONS_NONE, DWRITE_MEASURING_MODE measuringMode = DWRITE_MEASURING_MODE_NATURAL) PURE;
    STDMETHOD_(void, DrawTextLayout)(D2D1_POINT_2F origin, IDWriteTextLayout *textLayout, ID2D1Brush *defaultForegroundBrush, D2D1_DRAW_TEXT_OPTIONS options = D2D1_DRAW_TEXT_OPTIONS_NONE) PURE;
    STDMETHOD_(void, DrawGlyphRun)(D2D1_POINT_2F baselineOrigin, CONST DWRITE_GLYPH_RUN *glyphRun, ID2D1Brush *foregroundBrush, DWRITE_MEASURING_MODE measuringMode = DWRITE_MEASURING_MODE_NATURAL) PURE;
    STDMETHOD_(void, SetTransform)(const D2D1_MATRIX_3X2_F *transform) PURE;
    STDMETHOD_(void, GetTransform)(D2D1_MATRIX_3X2_F *transform) const PURE;
    STDMETHOD_(void, SetAntialiasMode)(D2D1_ANTIALIAS_MODE antialiasMode) PURE;
    STDMETHOD_(D2D1_ANTIALIAS_MODE, GetAntialiasMode)(void) const PURE;
    STDMETHOD_(void, SetTextAntialiasMode)(D2D1_TEXT_ANTIALIAS_MODE textAntialiasMode) PURE;
    STDMETHOD_(D2D1_TEXT_ANTIALIAS_MODE, GetTextAntialiasMode)(void) const PURE;
    STDMETHOD_(void, SetTextRenderingParams)(IDWriteRenderingParams *textRenderingParams = NULL) PURE;
    STDMETHOD_(void, GetTextRenderingParams)(IDWriteRenderingParams **textRenderingParams) const PURE;
    STDMETHOD_(void, SetTags)(D2D1_TAG tag1, D2D1_TAG tag2) PURE;
    STDMETHOD_(void, GetTags)(D2D1_TAG *tag1 = NULL, D2D1_TAG *tag2 = NULL) const PURE;
    STDMETHOD_(void, PushLayer)(const D2D1_LAYER_PARAMETERS *layerParameters, ID2D1Layer *layer) PURE;
    STDMETHOD_(void, PopLayer)(void) PURE;
    STDMETHOD(Flush)(D2D1_TAG *tag1 = NULL, D2D1_TAG *tag2 = NULL) PURE;
    STDMETHOD_(void, SaveDrawingState)(ID2D1DrawingStateBlock *drawingStateBlock) const PURE;
    STDMETHOD_(void, RestoreDrawingState)(ID2D1DrawingStateBlock *drawingStateBlock) PURE;
    STDMETHOD_(void, PushAxisAlignedClip)(const D2D1_RECT_F *clipRect, D2D1_ANTIALIAS_MODE antialiasMode) PURE;
    STDMETHOD_(void, PopAxisAlignedClip)(void) PURE;
    STDMETHOD_(void, Clear)(const D2D1_COLOR_F *clearColor = NULL) PURE;
    STDMETHOD_(void, BeginDraw)(void) PURE;
    STDMETHOD(EndDraw)(D2D1_TAG *tag1 = NULL, D2D1_TAG *tag2 = NULL) PURE;

#ifndef WIDL_EXPLICIT_AGGREGATE_RETURNS
    STDMETHOD_(D2D1_PIXEL_FORMAT, GetPixelFormat)(void) const PURE;
#else
    virtual D2D1_PIXEL_FORMAT* STDMETHODCALLTYPE GetPixelFormat(D2D1_PIXEL_FORMAT*) const = 0;
    D2D1_PIXEL_FORMAT STDMETHODCALLTYPE GetPixelFormat() const {
        D2D1_PIXEL_FORMAT __ret;
        GetPixelFormat(&__ret);
        return __ret;
    }
#endif

    STDMETHOD_(void, SetDpi)(FLOAT dpiX, FLOAT dpiY) PURE;
    STDMETHOD_(void, GetDpi)(FLOAT *dpiX, FLOAT *dpiY) const PURE;

#ifndef WIDL_EXPLICIT_AGGREGATE_RETURNS
    STDMETHOD_(D2D1_SIZE_F, GetSize)(void) const PURE;
#else
    virtual D2D1_SIZE_F* STDMETHODCALLTYPE GetSize(D2D1_SIZE_F*) const = 0;
    D2D1_SIZE_F STDMETHODCALLTYPE GetSize() const {
        D2D1_SIZE_F __ret;
        GetSize(&__ret);
        return __ret;
    }
#endif

#ifndef WIDL_EXPLICIT_AGGREGATE_RETURNS
    STDMETHOD_(D2D1_SIZE_U, GetPixelSize)(void) const PURE;
#else
    virtual D2D1_SIZE_U* STDMETHODCALLTYPE GetPixelSize(D2D1_SIZE_U*) const = 0;
    D2D1_SIZE_U STDMETHODCALLTYPE GetPixelSize() const {
        D2D1_SIZE_U __ret;
        GetPixelSize(&__ret);
        return __ret;
    }
#endif

    STDMETHOD_(UINT32, GetMaximumBitmapSize)(void) const PURE;
    STDMETHOD_(BOOL, IsSupported)(const D2D1_RENDER_TARGET_PROPERTIES *renderTargetProperties) const PURE;

    HRESULT CreateBitmap(D2D1_SIZE_U size, const void *srcData, UINT32 pitch, const D2D1_BITMAP_PROPERTIES &bitmapProperties, ID2D1Bitmap **bitmap) {
        return CreateBitmap(size, srcData, pitch, &bitmapProperties, bitmap);
    }

    HRESULT CreateBitmap(D2D1_SIZE_U size, const D2D1_BITMAP_PROPERTIES &bitmapProperties, ID2D1Bitmap **bitmap) {
        return CreateBitmap(size, NULL, 0, &bitmapProperties, bitmap);
    }

    HRESULT CreateBitmapFromWicBitmap(IWICBitmapSource *wicBitmapSource, const D2D1_BITMAP_PROPERTIES &bitmapProperties, ID2D1Bitmap **bitmap) {
        return CreateBitmapFromWicBitmap(wicBitmapSource, &bitmapProperties, bitmap);
    }

    HRESULT CreateBitmapFromWicBitmap(IWICBitmapSource *wicBitmapSource, ID2D1Bitmap **bitmap) {
        return CreateBitmapFromWicBitmap(wicBitmapSource, NULL, bitmap);
    }

    HRESULT CreateBitmapBrush(ID2D1Bitmap *bitmap, ID2D1BitmapBrush **bitmapBrush) {
        return CreateBitmapBrush(bitmap, NULL, NULL, bitmapBrush);
    }

    HRESULT CreateBitmapBrush(ID2D1Bitmap *bitmap, const D2D1_BITMAP_BRUSH_PROPERTIES &bitmapBrushProperties, ID2D1BitmapBrush **bitmapBrush) {
        return CreateBitmapBrush(bitmap, &bitmapBrushProperties, NULL, bitmapBrush);
    }

    HRESULT CreateBitmapBrush(ID2D1Bitmap *bitmap, const D2D1_BITMAP_BRUSH_PROPERTIES &bitmapBrushProperties, const D2D1_BRUSH_PROPERTIES &brushProperties, ID2D1BitmapBrush **bitmapBrush) {
        return CreateBitmapBrush(bitmap, &bitmapBrushProperties, &brushProperties, bitmapBrush);
    }

    HRESULT CreateSolidColorBrush(const D2D1_COLOR_F &color, ID2D1SolidColorBrush **solidColorBrush) {
        return CreateSolidColorBrush(&color, NULL, solidColorBrush);
    }

    HRESULT CreateSolidColorBrush(const D2D1_COLOR_F &color, const D2D1_BRUSH_PROPERTIES &brushProperties, ID2D1SolidColorBrush **solidColorBrush) {
        return CreateSolidColorBrush(&color, &brushProperties, solidColorBrush);
    }

    HRESULT CreateGradientStopCollection(const D2D1_GRADIENT_STOP *gradientStops, UINT gradientStopsCount, ID2D1GradientStopCollection **gradientStopCollection) {
        return CreateGradientStopCollection(gradientStops, gradientStopsCount, D2D1_GAMMA_2_2, D2D1_EXTEND_MODE_CLAMP, gradientStopCollection);
    }

    HRESULT CreateLinearGradientBrush(const D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES &linearGradientBrushProperties, ID2D1GradientStopCollection *gradientStopCollection, ID2D1LinearGradientBrush **linearGradientBrush) {
        return CreateLinearGradientBrush(&linearGradientBrushProperties, NULL, gradientStopCollection, linearGradientBrush);
    }

    HRESULT CreateLinearGradientBrush(const D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES &linearGradientBrushProperties, const D2D1_BRUSH_PROPERTIES &brushProperties, ID2D1GradientStopCollection *gradientStopCollection, ID2D1LinearGradientBrush **linearGradientBrush) {
        return CreateLinearGradientBrush(&linearGradientBrushProperties, &brushProperties, gradientStopCollection, linearGradientBrush);
    }

    HRESULT CreateRadialGradientBrush(const D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES &radialGradientBrushProperties, ID2D1GradientStopCollection *gradientStopCollection, ID2D1RadialGradientBrush **radialGradientBrush) {
        return CreateRadialGradientBrush(&radialGradientBrushProperties, NULL, gradientStopCollection, radialGradientBrush);
    }

    HRESULT CreateRadialGradientBrush(const D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES &radialGradientBrushProperties, const D2D1_BRUSH_PROPERTIES &brushProperties, ID2D1GradientStopCollection *gradientStopCollection, ID2D1RadialGradientBrush **radialGradientBrush) {
        return CreateRadialGradientBrush(&radialGradientBrushProperties, &brushProperties, gradientStopCollection, radialGradientBrush);
    }

    HRESULT CreateCompatibleRenderTarget(ID2D1BitmapRenderTarget **bitmapRenderTarget) {
        return CreateCompatibleRenderTarget(NULL, NULL, NULL, D2D1_COMPATIBLE_RENDER_TARGET_OPTIONS_NONE, bitmapRenderTarget);
    }

    HRESULT CreateCompatibleRenderTarget(D2D1_SIZE_F desiredSize, ID2D1BitmapRenderTarget **bitmapRenderTarget) {
        return CreateCompatibleRenderTarget(&desiredSize, NULL, NULL, D2D1_COMPATIBLE_RENDER_TARGET_OPTIONS_NONE, bitmapRenderTarget);
    }

    HRESULT CreateCompatibleRenderTarget(D2D1_SIZE_F desiredSize, D2D1_SIZE_U desiredPixelSize, ID2D1BitmapRenderTarget **bitmapRenderTarget){
        return CreateCompatibleRenderTarget(&desiredSize, &desiredPixelSize, NULL, D2D1_COMPATIBLE_RENDER_TARGET_OPTIONS_NONE, bitmapRenderTarget);
    }

    HRESULT CreateCompatibleRenderTarget(D2D1_SIZE_F desiredSize, D2D1_SIZE_U desiredPixelSize, D2D1_PIXEL_FORMAT desiredFormat, ID2D1BitmapRenderTarget **bitmapRenderTarget) {
        return CreateCompatibleRenderTarget(&desiredSize, &desiredPixelSize, &desiredFormat, D2D1_COMPATIBLE_RENDER_TARGET_OPTIONS_NONE, bitmapRenderTarget);
    }

    HRESULT CreateCompatibleRenderTarget(D2D1_SIZE_F desiredSize, D2D1_SIZE_U desiredPixelSize, D2D1_PIXEL_FORMAT desiredFormat, D2D1_COMPATIBLE_RENDER_TARGET_OPTIONS options, ID2D1BitmapRenderTarget **bitmapRenderTarget) {
        return CreateCompatibleRenderTarget(&desiredSize, &desiredPixelSize, &desiredFormat, options, bitmapRenderTarget);
    }

    HRESULT CreateLayer(D2D1_SIZE_F size, ID2D1Layer **layer) {
        return CreateLayer(&size, layer);
    }

    HRESULT CreateLayer(ID2D1Layer **layer) {
        return CreateLayer(NULL, layer);
    }

    void DrawRectangle(const D2D1_RECT_F &rect, ID2D1Brush *brush, FLOAT strokeWidth = 1.0f, ID2D1StrokeStyle *strokeStyle = NULL) {
        DrawRectangle(&rect, brush, strokeWidth, strokeStyle);
    }

    void FillRectangle(const D2D1_RECT_F &rect, ID2D1Brush *brush) {
        FillRectangle(&rect, brush);
    }

    void DrawRoundedRectangle(const D2D1_ROUNDED_RECT &roundedRect, ID2D1Brush *brush, FLOAT strokeWidth = 1.0f, ID2D1StrokeStyle *strokeStyle = NULL) {
        DrawRoundedRectangle(&roundedRect, brush, strokeWidth, strokeStyle);
    }

    void FillRoundedRectangle(const D2D1_ROUNDED_RECT &roundedRect, ID2D1Brush *brush) {
        FillRoundedRectangle(&roundedRect, brush);
    }

    void DrawEllipse(const D2D1_ELLIPSE &ellipse, ID2D1Brush *brush, FLOAT strokeWidth = 1.0f, ID2D1StrokeStyle *strokeStyle = NULL) {
        DrawEllipse(&ellipse, brush, strokeWidth, strokeStyle);
    }

    void FillEllipse(const D2D1_ELLIPSE &ellipse, ID2D1Brush *brush) {
        FillEllipse(&ellipse, brush);
    }

    void FillOpacityMask(ID2D1Bitmap *opacityMask, ID2D1Brush *brush, D2D1_OPACITY_MASK_CONTENT content, const D2D1_RECT_F &destinationRectangle, const D2D1_RECT_F &sourceRectangle) {
        FillOpacityMask(opacityMask, brush, content, &destinationRectangle, &sourceRectangle);
    }

    void DrawBitmap(ID2D1Bitmap *bitmap, const D2D1_RECT_F &destinationRectangle, FLOAT opacity = 1.0f, D2D1_BITMAP_INTERPOLATION_MODE interpolationMode = D2D1_BITMAP_INTERPOLATION_MODE_LINEAR, const D2D1_RECT_F *sourceRectangle = NULL) {
        DrawBitmap(bitmap, &destinationRectangle, opacity, interpolationMode, sourceRectangle);
    }

    void DrawBitmap(ID2D1Bitmap *bitmap, const D2D1_RECT_F &destinationRectangle, FLOAT opacity, D2D1_BITMAP_INTERPOLATION_MODE interpolationMode, const D2D1_RECT_F &sourceRectangle) {
        DrawBitmap(bitmap, &destinationRectangle, opacity, interpolationMode, &sourceRectangle);
    }

    void SetTransform(const D2D1_MATRIX_3X2_F &transform) {
        SetTransform(&transform);
    }

    void PushLayer(const D2D1_LAYER_PARAMETERS &layerParameters, ID2D1Layer *layer) {
        PushLayer(&layerParameters, layer);
    }

    void PushAxisAlignedClip(const D2D1_RECT_F &clipRect, D2D1_ANTIALIAS_MODE antialiasMode) {
        return PushAxisAlignedClip(&clipRect, antialiasMode);
    }

    void Clear(const D2D1_COLOR_F &clearColor) {
        return Clear(&clearColor);
    }

    void DrawText(const WCHAR *string, UINT stringLength, IDWriteTextFormat *textFormat, const D2D1_RECT_F &layoutRect, ID2D1Brush *defaultForegroundBrush, D2D1_DRAW_TEXT_OPTIONS options = D2D1_DRAW_TEXT_OPTIONS_NONE, DWRITE_MEASURING_MODE measuringMode = DWRITE_MEASURING_MODE_NATURAL) {
        return DrawText(string, stringLength, textFormat, &layoutRect, defaultForegroundBrush, options, measuringMode);
    }

    BOOL IsSupported(const D2D1_RENDER_TARGET_PROPERTIES &renderTargetProperties) const {
        return IsSupported(&renderTargetProperties);
    }
};

#else

typedef struct ID2D1RenderTargetVtbl {
    ID2D1ResourceVtbl Base;

    STDMETHOD(CreateBitmap)(ID2D1RenderTarget *This, D2D1_SIZE_U size, const void *srcData, UINT32 pitch, const D2D1_BITMAP_PROPERTIES *bitmapProperties, ID2D1Bitmap **bitmap) PURE;
    STDMETHOD(CreateBitmapFromWicBitmap)(ID2D1RenderTarget *This, IWICBitmapSource *wicBitmapSource, const D2D1_BITMAP_PROPERTIES *bitmapProperties, ID2D1Bitmap **bitmap) PURE;
    STDMETHOD(CreateSharedBitmap)(ID2D1RenderTarget *This, REFIID riid, void *data, const D2D1_BITMAP_PROPERTIES *bitmapProperties, ID2D1Bitmap **bitmap) PURE;
    STDMETHOD(CreateBitmapBrush)(ID2D1RenderTarget *This, ID2D1Bitmap *bitmap, const D2D1_BITMAP_BRUSH_PROPERTIES *bitmapBrushProperties, const D2D1_BRUSH_PROPERTIES *brushProperties, ID2D1BitmapBrush **bitmapBrush) PURE;
    STDMETHOD(CreateSolidColorBrush)(ID2D1RenderTarget *This, const D2D1_COLOR_F *color, const D2D1_BRUSH_PROPERTIES *brushProperties, ID2D1SolidColorBrush **solidColorBrush) PURE;
    STDMETHOD(CreateGradientStopCollection)(ID2D1RenderTarget *This, const D2D1_GRADIENT_STOP *gradientStops, UINT gradientStopsCount, D2D1_GAMMA colorInterpolationGamma, D2D1_EXTEND_MODE extendMode, ID2D1GradientStopCollection **gradientStopCollection) PURE;
    STDMETHOD(CreateLinearGradientBrush)(ID2D1RenderTarget *This, const D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES *linearGradientBrushProperties, const D2D1_BRUSH_PROPERTIES *brushProperties, ID2D1GradientStopCollection *gradientStopCollection, ID2D1LinearGradientBrush **linearGradientBrush) PURE;
    STDMETHOD(CreateRadialGradientBrush)(ID2D1RenderTarget *This, const D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES *radialGradientBrushProperties, const D2D1_BRUSH_PROPERTIES *brushProperties, ID2D1GradientStopCollection *gradientStopCollection, ID2D1RadialGradientBrush **radialGradientBrush) PURE;
    STDMETHOD(CreateCompatibleRenderTarget)(ID2D1RenderTarget *This, const D2D1_SIZE_F *desiredSize, const D2D1_SIZE_U *desiredPixelSize, const D2D1_PIXEL_FORMAT *desiredFormat, D2D1_COMPATIBLE_RENDER_TARGET_OPTIONS options, ID2D1BitmapRenderTarget **bitmapRenderTarget) PURE;
    STDMETHOD(CreateLayer)(ID2D1RenderTarget *This, const D2D1_SIZE_F *size, ID2D1Layer **layer) PURE;
    STDMETHOD(CreateMesh)(ID2D1RenderTarget *This, ID2D1Mesh **mesh) PURE;
    STDMETHOD_(void, DrawLine)(ID2D1RenderTarget *This, D2D1_POINT_2F point0, D2D1_POINT_2F point1, ID2D1Brush *brush, FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle) PURE;
    STDMETHOD_(void, DrawRectangle)(ID2D1RenderTarget *This, const D2D1_RECT_F *rect, ID2D1Brush *brush, FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle) PURE;
    STDMETHOD_(void, FillRectangle)(ID2D1RenderTarget *This, const D2D1_RECT_F *rect, ID2D1Brush *brush) PURE;
    STDMETHOD_(void, DrawRoundedRectangle)(ID2D1RenderTarget *This, const D2D1_ROUNDED_RECT *roundedRect, ID2D1Brush *brush, FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle) PURE;
    STDMETHOD_(void, FillRoundedRectangle)(ID2D1RenderTarget *This, const D2D1_ROUNDED_RECT *roundedRect, ID2D1Brush *brush) PURE;
    STDMETHOD_(void, DrawEllipse)(ID2D1RenderTarget *This, const D2D1_ELLIPSE *ellipse, ID2D1Brush *brush, FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle) PURE;
    STDMETHOD_(void, FillEllipse)(ID2D1RenderTarget *This, const D2D1_ELLIPSE *ellipse, ID2D1Brush *brush) PURE;
    STDMETHOD_(void, DrawGeometry)(ID2D1RenderTarget *This, ID2D1Geometry *geometry, ID2D1Brush *brush, FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle) PURE;
    STDMETHOD_(void, FillGeometry)(ID2D1RenderTarget *This, ID2D1Geometry *geometry, ID2D1Brush *brush, ID2D1Brush *opacityBrush) PURE;
    STDMETHOD_(void, FillMesh)(ID2D1RenderTarget *This, ID2D1Mesh *mesh, ID2D1Brush *brush) PURE;
    STDMETHOD_(void, FillOpacityMask)(ID2D1RenderTarget *This, ID2D1Bitmap *opacityMask, ID2D1Brush *brush, D2D1_OPACITY_MASK_CONTENT content, const D2D1_RECT_F *destinationRectangle, const D2D1_RECT_F *sourceRectangle) PURE;
    STDMETHOD_(void, DrawBitmap)(ID2D1RenderTarget *This, ID2D1Bitmap *bitmap, const D2D1_RECT_F *destinationRectangle, FLOAT opacity, D2D1_BITMAP_INTERPOLATION_MODE interpolationMode, const D2D1_RECT_F *sourceRectangle) PURE;
    STDMETHOD_(void, DrawText)(ID2D1RenderTarget *This, const WCHAR *string, UINT stringLength, IDWriteTextFormat *textFormat, const D2D1_RECT_F *layoutRect, ID2D1Brush *defaultForegroundBrush, D2D1_DRAW_TEXT_OPTIONS options, DWRITE_MEASURING_MODE measuringMode) PURE;
    STDMETHOD_(void, DrawTextLayout)(ID2D1RenderTarget *This, D2D1_POINT_2F origin, IDWriteTextLayout *textLayout, ID2D1Brush *defaultForegroundBrush, D2D1_DRAW_TEXT_OPTIONS options) PURE;
    STDMETHOD_(void, DrawGlyphRun)(ID2D1RenderTarget *This, D2D1_POINT_2F baselineOrigin, const DWRITE_GLYPH_RUN *glyphRun, ID2D1Brush *foregroundBrush, DWRITE_MEASURING_MODE measuringMode) PURE;
    STDMETHOD_(void, SetTransform)(ID2D1RenderTarget *This, const D2D1_MATRIX_3X2_F *transform) PURE;
    STDMETHOD_(void, GetTransform)(ID2D1RenderTarget *This, D2D1_MATRIX_3X2_F *transform) PURE;
    STDMETHOD_(void, SetAntialiasMode)(ID2D1RenderTarget *This, D2D1_ANTIALIAS_MODE antialiasMode) PURE;
    STDMETHOD_(D2D1_ANTIALIAS_MODE, GetAntialiasMode)(ID2D1RenderTarget *This) PURE;
    STDMETHOD_(void, SetTextAntialiasMode)(ID2D1RenderTarget *This, D2D1_TEXT_ANTIALIAS_MODE textAntialiasMode) PURE;
    STDMETHOD_(D2D1_TEXT_ANTIALIAS_MODE, GetTextAntialiasMode)(ID2D1RenderTarget *This) PURE;
    STDMETHOD_(void, SetTextRenderingParams)(ID2D1RenderTarget *This, IDWriteRenderingParams *textRenderingParams) PURE;
    STDMETHOD_(void, GetTextRenderingParams)(ID2D1RenderTarget *This, IDWriteRenderingParams **textRenderingParams) PURE;
    STDMETHOD_(void, SetTags)(ID2D1RenderTarget *This, D2D1_TAG tag1, D2D1_TAG tag2) PURE;
    STDMETHOD_(void, GetTags)(ID2D1RenderTarget *This, D2D1_TAG *tag1, D2D1_TAG *tag2) PURE;
    STDMETHOD_(void, PushLayer)(ID2D1RenderTarget *This, const D2D1_LAYER_PARAMETERS *layerParameters, ID2D1Layer *layer) PURE;
    STDMETHOD_(void, PopLayer)(ID2D1RenderTarget *This) PURE;
    STDMETHOD(Flush)(ID2D1RenderTarget *This, D2D1_TAG *tag1, D2D1_TAG *tag2) PURE;
    STDMETHOD_(void, SaveDrawingState)(ID2D1RenderTarget *This, ID2D1DrawingStateBlock *drawingStateBlock) PURE;
    STDMETHOD_(void, RestoreDrawingState)(ID2D1RenderTarget *This, ID2D1DrawingStateBlock *drawingStateBlock) PURE;
    STDMETHOD_(void, PushAxisAlignedClip)(ID2D1RenderTarget *This, const D2D1_RECT_F *clipRect, D2D1_ANTIALIAS_MODE antialiasMode) PURE;
    STDMETHOD_(void, PopAxisAlignedClip)(ID2D1RenderTarget *This) PURE;
    STDMETHOD_(void, Clear)(ID2D1RenderTarget *This, const D2D1_COLOR_F *clearColor) PURE;
    STDMETHOD_(void, BeginDraw)(ID2D1RenderTarget *This) PURE;
    STDMETHOD(EndDraw)(ID2D1RenderTarget *This, D2D1_TAG *tag1, D2D1_TAG *tag2) PURE;
    STDMETHOD_(D2D1_PIXEL_FORMAT, GetPixelFormat)(ID2D1RenderTarget *This) PURE;
    STDMETHOD_(void, SetDpi)(ID2D1RenderTarget *This, FLOAT dpiX, FLOAT dpiY) PURE;
    STDMETHOD_(void, GetDpi)(ID2D1RenderTarget *This, FLOAT *dpiX, FLOAT *dpiY) PURE;
    STDMETHOD_(D2D1_SIZE_F, GetSize)(ID2D1RenderTarget *This) PURE;
    STDMETHOD_(D2D1_SIZE_U, GetPixelSize)(ID2D1RenderTarget *This) PURE;
    STDMETHOD_(UINT32, GetMaximumBitmapSize)(ID2D1RenderTarget *This) PURE;
    STDMETHOD_(BOOL, IsSupported)(ID2D1RenderTarget *This, const D2D1_RENDER_TARGET_PROPERTIES *renderTargetProperties) PURE;
} ID2D1RenderTargetVtbl;

interface ID2D1RenderTarget {
    const ID2D1RenderTargetVtbl *lpVtbl;
};

#define ID2D1RenderTarget_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1RenderTarget_AddRef(this) (this)->lpVtbl->Base.Base.AddRef((IUnknown*)(this))
#define ID2D1RenderTarget_Release(this) (this)->lpVtbl->Base.Base.Release((IUnknown*)(this))
#define ID2D1RenderTarget_GetFactory(this,A) (this)->lpVtbl->Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1RenderTarget_BeginDraw(this) (this)->lpVtbl->BeginDraw(this)
#define ID2D1RenderTarget_Clear(this,A) (this)->lpVtbl->Clear(this,A)
#define ID2D1RenderTarget_CreateBitmap(this,A,B,C,D,E) (this)->lpVtbl->CreateBitmap(this,A,B,C,D,E)
#define ID2D1RenderTarget_CreateBitmapBrush(this,A,B) (this)->lpVtbl->CreateBitmapBrush(this,A,B)
#define ID2D1RenderTarget_CreateBitmapFromWicBitmap(this,A,B,C) (this)->lpVtbl->CreateBitmapFromWicBitmap(this,A,B,C)
#define ID2D1RenderTarget_CreateCompatibleRenderTarget(this,A,B,C,D,E) (this)->lpVtbl->CreateCompatibleRenderTarget(this,A,B,C,D,E)
#define ID2D1RenderTarget_CreateGradientStopCollection(this,A,B,C) (this)->lpVtbl->CreateGradientStopCollection(this,A,B,C)
#define ID2D1RenderTarget_CreateLayer(this,A,B) (this)->lpVtbl->CreateLayer(this,A,B)
#define ID2D1RenderTarget_CreateLinearGradientBrush(this,A,B,C,D) (this)->lpVtbl->CreateLinearGradientBrush(this,A,B,C,D)
#define ID2D1RenderTarget_CreateMesh(this,A) (this)->lpVtbl->CreateMesh(this,A)
#define ID2D1RenderTarget_CreateRadialGradientBrush(this,A,B,C,D) (this)->lpVtbl->CreateRadialGradientBrush(this,A,B,C,D)
#define ID2D1RenderTarget_CreateSharedBitmap(this,A,B,C,D) (this)->lpVtbl->CreateSharedBitmap(this,A,B,C,D)
#define ID2D1RenderTarget_CreateSolidColorBrush(this,A,B,C) (this)->lpVtbl->CreateSolidColorBrush(this,A,B,C)
#define ID2D1RenderTarget_DrawBitmap(this,A,B,C,D,E) (this)->lpVtbl->DrawBitmap(this,A,B,C,D,E)
#define ID2D1RenderTarget_DrawEllipse(this,A,B,C,D) (this)->lpVtbl->DrawEllipse(this,A,B,C,D)
#define ID2D1RenderTarget_DrawGeometry(this,A,B,C,D) (this)->lpVtbl->DrawGeometry(this,A,B,C,D)
#define ID2D1RenderTarget_DrawGlyphRun(this,A,B,C,D) (this)->lpVtbl->DrawGlyphRun(this,A,B,C,D)
#define ID2D1RenderTarget_DrawLine(this,A,B,C,D,E) (this)->lpVtbl->DrawLine(this,A,B,C,D,E)
#define ID2D1RenderTarget_DrawRectangle(this,A,B,C,D) (this)->lpVtbl->DrawRectangle(this,A,B,C,D)
#define ID2D1RenderTarget_DrawRoundedRectangle(this,A,B,C,D) (this)->lpVtbl->DrawRoundedRectangle(this,A,B,C,D)
#define ID2D1RenderTarget_DrawText(this,A,B,C,D,E,F,G) (this)->lpVtbl->DrawText(this,A,B,C,D,E,F,G)
#define ID2D1RenderTarget_DrawTextLayout(this,A,B,C,D) (this)->lpVtbl->DrawTextLayout(this,A,B,C,D)
#define ID2D1RenderTarget_EndDraw(this,A,B) (this)->lpVtbl->EndDraw(this,A,B)
#define ID2D1RenderTarget_FillEllipse(this,A,B) (this)->lpVtbl->FillEllipse(this,A,B)
#define ID2D1RenderTarget_FillGeometry(this,A,B,C) (this)->lpVtbl->FillGeometry(this,A,B,C)
#define ID2D1RenderTarget_FillMesh(this,A,B) (this)->lpVtbl->FillMesh(this,A,B)
#define ID2D1RenderTarget_FillOpacityMask(this,A,B,C,D,E) (this)->lpVtbl->FillOpacityMask(this,A,B,C,D,E)
#define ID2D1RenderTarget_FillRectangle(this,A,B) (this)->lpVtbl->FillRectangle(this,A,B)
#define ID2D1RenderTarget_FillRoundedRectangle(this,A,B) (this)->lpVtbl->FillRoundedRectangle(this,A,B)
#define ID2D1RenderTarget_Flush(this,A,B) (this)->lpVtbl->Flush(this,A,B)
#define ID2D1RenderTarget_GetAntialiasMode(this) (this)->lpVtbl->GetAntialiasMode(this)
#define ID2D1RenderTarget_GetDpi(this,A,B) (this)->lpVtbl->GetDpi(this,A,B)
#define ID2D1RenderTarget_GetMaximumBitmapSize(this) (this)->lpVtbl->GetMaximumBitmapSize(this)
#define ID2D1RenderTarget_GetPixelFormat(this) (this)->lpVtbl->GetPixelFormat(this)
#define ID2D1RenderTarget_GetPixelSize(this) (this)->lpVtbl->GetPixelSize(this)
#define ID2D1RenderTarget_GetSize(this) (this)->lpVtbl->GetSize(this)
#define ID2D1RenderTarget_GetTags(this,A,B) (this)->lpVtbl->GetTags(this,A,B)
#define ID2D1RenderTarget_GetTextAntialiasMode(this) (this)->lpVtbl->GetTextAntialiasMode(this)
#define ID2D1RenderTarget_GetTextRenderingParams(this,A) (this)->lpVtbl->GetTextRenderingParams(this,A)
#define ID2D1RenderTarget_GetTransform(this,A) (this)->lpVtbl->GetTransform(this,A)
#define ID2D1RenderTarget_IsSupported(this,A) (this)->lpVtbl->IsSupported(this,A)
#define ID2D1RenderTarget_PopAxisAlignedClip(this) (this)->lpVtbl->PopAxisAlignedClip(this)
#define ID2D1RenderTarget_PopLayer(this) (this)->lpVtbl->PopLayer(this)
#define ID2D1RenderTarget_PushAxisAlignedClip(this,A,B) (this)->lpVtbl->PushAxisAlignedClip(this,A,B)
#define ID2D1RenderTarget_PushLayer(this,A,B) (this)->lpVtbl->PushLayer(this,A,B)
#define ID2D1RenderTarget_RestoreDrawingState(this,A) (this)->lpVtbl->RestoreDrawingState(this,A)
#define ID2D1RenderTarget_SaveDrawingState(this,A) (this)->lpVtbl->SaveDrawingState(this,A)
#define ID2D1RenderTarget_SetAntialiasMode(this,A) (this)->lpVtbl->SetAntialiasMode(this,A)
#define ID2D1RenderTarget_SetDpi(this,A,B) (this)->lpVtbl->SetDpi(this,A,B)
#define ID2D1RenderTarget_SetTags(this,A,B) (this)->lpVtbl->SetTags(this,A,B)
#define ID2D1RenderTarget_SetTextAntialiasMode(this,A) (this)->lpVtbl->SetTextAntialiasMode(this,A)
#define ID2D1RenderTarget_SetTextRenderingParams(this,A) (this)->lpVtbl->SetTextRenderingParams(this,A)
#define ID2D1RenderTarget_SetTransform(this,A) (this)->lpVtbl->SetTransform(this,A)

#endif

DEFINE_GUID(IID_ID2D1Geometry, 0x2cd906a1,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1Geometry : public ID2D1Resource {
    STDMETHOD(GetBounds)(const D2D1_MATRIX_3X2_F *worldTransform, D2D1_RECT_F *bounds) const PURE;
    STDMETHOD(GetWidenedBounds)(FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, D2D1_RECT_F *bounds) const PURE;
    STDMETHOD(StrokeContainsPoint)(D2D1_POINT_2F point, FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, BOOL *contains) const PURE;
    STDMETHOD(FillContainsPoint)(D2D1_POINT_2F point, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, BOOL *contains) const PURE;
    STDMETHOD(CompareWithGeometry)(ID2D1Geometry *inputGeometry, const D2D1_MATRIX_3X2_F *inputGeometryTransform, FLOAT flatteningTolerance, D2D1_GEOMETRY_RELATION *relation) const PURE;
    STDMETHOD(Simplify)(D2D1_GEOMETRY_SIMPLIFICATION_OPTION simplificationOption, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, ID2D1SimplifiedGeometrySink *geometrySink) const PURE;
    STDMETHOD(Tessellate)(const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, ID2D1TessellationSink *tessellationSink) const PURE;
    STDMETHOD(CombineWithGeometry)(ID2D1Geometry *inputGeometry, D2D1_COMBINE_MODE combineMode, const D2D1_MATRIX_3X2_F *inputGeometryTransform, FLOAT flatteningTolerance, ID2D1SimplifiedGeometrySink *geometrySink) const PURE;
    STDMETHOD(Outline)(const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, ID2D1SimplifiedGeometrySink *geometrySink) const PURE;
    STDMETHOD(ComputeArea)(const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, FLOAT *area) const PURE;
    STDMETHOD(ComputeLength)(const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, FLOAT *length) const PURE;
    STDMETHOD(ComputePointAtLength)(FLOAT length, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, D2D1_POINT_2F *point, D2D1_POINT_2F *unitTangentVector) const PURE;
    STDMETHOD(Widen)(FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, ID2D1SimplifiedGeometrySink *geometrySink) const PURE;

    HRESULT GetBounds(const D2D1_MATRIX_3X2_F &worldTransform, D2D1_RECT_F *bounds) const {
        return GetBounds(&worldTransform, bounds);
    }

    HRESULT GetWidenedBounds(FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle, const D2D1_MATRIX_3X2_F &worldTransform, FLOAT flatteningTolerance, D2D1_RECT_F *bounds) const {
        return GetWidenedBounds(strokeWidth, strokeStyle, &worldTransform, flatteningTolerance, bounds);
    }

    HRESULT GetWidenedBounds(FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle, const D2D1_MATRIX_3X2_F *worldTransform, D2D1_RECT_F *bounds) const {
        return GetWidenedBounds(strokeWidth, strokeStyle, worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, bounds);
    }

    HRESULT GetWidenedBounds(FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle, const D2D1_MATRIX_3X2_F &worldTransform, D2D1_RECT_F *bounds) const {
        return GetWidenedBounds(strokeWidth, strokeStyle, &worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, bounds);
    }

    HRESULT StrokeContainsPoint(D2D1_POINT_2F point, FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle, const D2D1_MATRIX_3X2_F &worldTransform, FLOAT flatteningTolerance, BOOL *contains) const {
        return StrokeContainsPoint(point, strokeWidth, strokeStyle, &worldTransform, flatteningTolerance, contains);
    }

    HRESULT StrokeContainsPoint(D2D1_POINT_2F point, FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle, const D2D1_MATRIX_3X2_F *worldTransform, BOOL *contains) const {
        return StrokeContainsPoint(point, strokeWidth, strokeStyle, worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, contains);
    }

    HRESULT StrokeContainsPoint(D2D1_POINT_2F point, FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle, const D2D1_MATRIX_3X2_F &worldTransform, BOOL *contains) const {
        return StrokeContainsPoint(point, strokeWidth, strokeStyle, &worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, contains);
    }

    HRESULT FillContainsPoint(D2D1_POINT_2F point, const D2D1_MATRIX_3X2_F &worldTransform, FLOAT flatteningTolerance, BOOL *contains) const {
        return FillContainsPoint(point, &worldTransform, flatteningTolerance, contains);
    }

    HRESULT FillContainsPoint(D2D1_POINT_2F point, const D2D1_MATRIX_3X2_F *worldTransform, BOOL *contains) const {
        return FillContainsPoint(point, worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, contains);
    }

    HRESULT FillContainsPoint(D2D1_POINT_2F point, const D2D1_MATRIX_3X2_F &worldTransform, BOOL *contains) const {
        return FillContainsPoint(point, &worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, contains);
    }

    HRESULT CompareWithGeometry(ID2D1Geometry *inputGeometry, const D2D1_MATRIX_3X2_F &inputGeometryTransform, FLOAT flatteningTolerance, D2D1_GEOMETRY_RELATION *relation) const {
        return CompareWithGeometry(inputGeometry, &inputGeometryTransform, flatteningTolerance, relation);
    }

    HRESULT CompareWithGeometry(ID2D1Geometry *inputGeometry, const D2D1_MATRIX_3X2_F *inputGeometryTransform, D2D1_GEOMETRY_RELATION *relation) const {
        return CompareWithGeometry(inputGeometry, inputGeometryTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, relation);
    }

    HRESULT CompareWithGeometry(ID2D1Geometry *inputGeometry, const D2D1_MATRIX_3X2_F &inputGeometryTransform, D2D1_GEOMETRY_RELATION *relation) const {
        return CompareWithGeometry(inputGeometry, &inputGeometryTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, relation);
    }

    HRESULT Simplify(D2D1_GEOMETRY_SIMPLIFICATION_OPTION simplificationOption, const D2D1_MATRIX_3X2_F &worldTransform, FLOAT flatteningTolerance, ID2D1SimplifiedGeometrySink *geometrySink) const {
        return Simplify(simplificationOption, &worldTransform, flatteningTolerance, geometrySink);
    }

    HRESULT Simplify(D2D1_GEOMETRY_SIMPLIFICATION_OPTION simplificationOption, const D2D1_MATRIX_3X2_F *worldTransform, ID2D1SimplifiedGeometrySink *geometrySink) const {
        return Simplify(simplificationOption, worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, geometrySink);
    }

    HRESULT Simplify(D2D1_GEOMETRY_SIMPLIFICATION_OPTION simplificationOption, const D2D1_MATRIX_3X2_F &worldTransform, ID2D1SimplifiedGeometrySink *geometrySink) const {
        return Simplify(simplificationOption, &worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, geometrySink);
    }

    HRESULT Tessellate(const D2D1_MATRIX_3X2_F &worldTransform, FLOAT flatteningTolerance, ID2D1TessellationSink *tessellationSink) const {
        return Tessellate(&worldTransform, flatteningTolerance, tessellationSink);
    }

    HRESULT Tessellate(const D2D1_MATRIX_3X2_F *worldTransform, ID2D1TessellationSink *tessellationSink) const {
        return Tessellate(worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, tessellationSink);
    }

    HRESULT Tessellate(const D2D1_MATRIX_3X2_F &worldTransform, ID2D1TessellationSink *tessellationSink) const {
        return Tessellate(&worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, tessellationSink);
    }

    HRESULT CombineWithGeometry(ID2D1Geometry *inputGeometry, D2D1_COMBINE_MODE combineMode, const D2D1_MATRIX_3X2_F &inputGeometryTransform, FLOAT flatteningTolerance, ID2D1SimplifiedGeometrySink *geometrySink) const {
        return CombineWithGeometry(inputGeometry, combineMode, &inputGeometryTransform, flatteningTolerance, geometrySink);
    }

    HRESULT CombineWithGeometry(ID2D1Geometry *inputGeometry, D2D1_COMBINE_MODE combineMode, CONST D2D1_MATRIX_3X2_F *inputGeometryTransform, ID2D1SimplifiedGeometrySink *geometrySink) const {
        return CombineWithGeometry(inputGeometry, combineMode, inputGeometryTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, geometrySink);
    }

    HRESULT CombineWithGeometry(ID2D1Geometry *inputGeometry, D2D1_COMBINE_MODE combineMode, const D2D1_MATRIX_3X2_F &inputGeometryTransform, ID2D1SimplifiedGeometrySink *geometrySink) const {
        return CombineWithGeometry(inputGeometry, combineMode, &inputGeometryTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, geometrySink);
    }

    HRESULT Outline(const D2D1_MATRIX_3X2_F &worldTransform, FLOAT flatteningTolerance, ID2D1SimplifiedGeometrySink *geometrySink) const {
        return Outline(&worldTransform, flatteningTolerance, geometrySink);
    }

    HRESULT Outline(const D2D1_MATRIX_3X2_F *worldTransform, ID2D1SimplifiedGeometrySink *geometrySink) const {
        return Outline(worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, geometrySink);
    }

    HRESULT Outline(const D2D1_MATRIX_3X2_F &worldTransform, ID2D1SimplifiedGeometrySink *geometrySink) const {
        return Outline(&worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, geometrySink);
    }

    HRESULT ComputeArea(const D2D1_MATRIX_3X2_F &worldTransform, FLOAT flatteningTolerance, FLOAT *area) const {
        return ComputeArea(&worldTransform, flatteningTolerance, area);
    }

    HRESULT ComputeArea(const D2D1_MATRIX_3X2_F *worldTransform, FLOAT *area) const {
        return ComputeArea(worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, area);
    }

    HRESULT ComputeArea(const D2D1_MATRIX_3X2_F &worldTransform, FLOAT *area) const {
        return ComputeArea(&worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, area);
    }

    HRESULT ComputeLength(const D2D1_MATRIX_3X2_F &worldTransform, FLOAT flatteningTolerance, FLOAT *length) const {
        return ComputeLength(&worldTransform, flatteningTolerance, length);
    }

    HRESULT ComputeLength(const D2D1_MATRIX_3X2_F *worldTransform, FLOAT *length) const {
        return ComputeLength(worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, length);
    }

    HRESULT  ComputeLength(const D2D1_MATRIX_3X2_F &worldTransform, FLOAT *length) const {
        return ComputeLength(&worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, length);
    }

    HRESULT ComputePointAtLength(FLOAT length, const D2D1_MATRIX_3X2_F &worldTransform, FLOAT flatteningTolerance, D2D1_POINT_2F *point, D2D1_POINT_2F *unitTangentVector) const {
        return ComputePointAtLength(length, &worldTransform, flatteningTolerance, point, unitTangentVector);
    }

    HRESULT ComputePointAtLength(FLOAT length, const D2D1_MATRIX_3X2_F *worldTransform, D2D1_POINT_2F *point, D2D1_POINT_2F *unitTangentVector) const {
        return ComputePointAtLength(length, worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, point, unitTangentVector);
    }

    HRESULT ComputePointAtLength(FLOAT length, const D2D1_MATRIX_3X2_F &worldTransform, D2D1_POINT_2F *point, D2D1_POINT_2F *unitTangentVector) const {
        return ComputePointAtLength(length, &worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, point, unitTangentVector);
    }

    HRESULT Widen(FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle, const D2D1_MATRIX_3X2_F &worldTransform, FLOAT flatteningTolerance, ID2D1SimplifiedGeometrySink *geometrySink) const {
        return Widen(strokeWidth, strokeStyle, &worldTransform, flatteningTolerance, geometrySink);
    }

    HRESULT Widen(FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle, const D2D1_MATRIX_3X2_F *worldTransform, ID2D1SimplifiedGeometrySink *geometrySink) const {
        return Widen(strokeWidth, strokeStyle, worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, geometrySink);
    }

    HRESULT Widen(FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle, const D2D1_MATRIX_3X2_F &worldTransform, ID2D1SimplifiedGeometrySink *geometrySink) const {
        return Widen(strokeWidth, strokeStyle, &worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE, geometrySink);
    }
};

#else

typedef struct ID2D1GeometryVtbl {
    ID2D1ResourceVtbl Base;

    STDMETHOD(GetBounds)(ID2D1Geometry *This, const D2D1_MATRIX_3X2_F *worldTransform, D2D1_RECT_F *bounds) PURE;
    STDMETHOD(GetWidenedBounds)(ID2D1Geometry *This, FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, D2D1_RECT_F *bounds) PURE;
    STDMETHOD(StrokeContainsPoint)(ID2D1Geometry *This, D2D1_POINT_2F point, FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, BOOL *contains) PURE;
    STDMETHOD(FillContainsPoint)(ID2D1Geometry *This, D2D1_POINT_2F point, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, BOOL *contains) PURE;
    STDMETHOD(CompareWithGeometry)(ID2D1Geometry *This, ID2D1Geometry *inputGeometry, const D2D1_MATRIX_3X2_F *inputGeometryTransform, FLOAT flatteningTolerance, D2D1_GEOMETRY_RELATION *relation) PURE;
    STDMETHOD(Simplify)(ID2D1Geometry *This, D2D1_GEOMETRY_SIMPLIFICATION_OPTION simplificationOption, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, ID2D1SimplifiedGeometrySink *geometrySink) PURE;
    STDMETHOD(Tessellate)(ID2D1Geometry *This, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, ID2D1TessellationSink *tessellationSink) PURE;
    STDMETHOD(CombineWithGeometry)(ID2D1Geometry *This, ID2D1Geometry *inputGeometry, D2D1_COMBINE_MODE combineMode, const D2D1_MATRIX_3X2_F *inputGeometryTransform, FLOAT flatteningTolerance, ID2D1SimplifiedGeometrySink *geometrySink) PURE;
    STDMETHOD(Outline)(ID2D1Geometry *This, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, ID2D1SimplifiedGeometrySink *geometrySink) PURE;
    STDMETHOD(ComputeArea)(ID2D1Geometry *This, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, FLOAT *area) PURE;
    STDMETHOD(ComputeLength)(ID2D1Geometry *This, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, FLOAT *length) PURE;
    STDMETHOD(ComputePointAtLength)(ID2D1Geometry *This, FLOAT length, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, D2D1_POINT_2F *point, D2D1_POINT_2F *unitTangentVector) PURE;
    STDMETHOD(Widen)(ID2D1Geometry *This, FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle, const D2D1_MATRIX_3X2_F *worldTransform, FLOAT flatteningTolerance, ID2D1SimplifiedGeometrySink *geometrySink) PURE;
} ID2D1GeometryVtbl;

interface ID2D1Geometry {
    const ID2D1GeometryVtbl *lpVtbl;
};

#define ID2D1Geometry_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1Geometry_AddRef(this) (this)->lpVtbl->Base.Base.AddRef((IUnknown*)(this))
#define ID2D1Geometry_Release(this) (this)->lpVtbl->Base.Base.Release((IUnknown*)(this))
#define ID2D1Geometry_GetFactory(this,A) (this)->lpVtbl->Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1Geometry_CombineWithGeometry(this,A,B,C,D) (this)->lpVtbl->CombineWithGeometry(this,A,B,C,D)
#define ID2D1Geometry_CompareWithGeometry(this,A,B,C) (this)->lpVtbl->CompareWithGeometry(this,A,B,C)
#define ID2D1Geometry_ComputeArea(this,A,B) (this)->lpVtbl->ComputeArea(this,A,B)
#define ID2D1Geometry_ComputeLength(this,A,B) (this)->lpVtbl->ComputeLength(this,A,B)
#define ID2D1Geometry_ComputePointAtLength(this,A,B,C,D) (this)->lpVtbl->ComputePointAtLength(this,A,B,C,D)
#define ID2D1Geometry_FillContainsPoint(this,A,B,C) (this)->lpVtbl->FillContainsPoint(this,A,B,C)
#define ID2D1Geometry_GetBounds(this,A,B) (this)->lpVtbl->GetBounds(this,A,B)
#define ID2D1Geometry_GetWidenedBounds(this,A,B,C,D) (this)->lpVtbl->GetWidenedBounds(this,A,B,C,D)
#define ID2D1Geometry_Outline(this,A,B) (this)->lpVtbl->Outline(this,A,B)
#define ID2D1Geometry_StrokeContainsPoint(this,A,B,C,D,E) (this)->lpVtbl->StrokeContainsPoint(this,A,B,C,D,E)
#define ID2D1Geometry_Simplify(this,A,B,C) (this)->lpVtbl->Simplify(this,A,B,C)
#define ID2D1Geometry_Tessellate(this,A,B) (this)->lpVtbl->Tessellate(this,A,B)
#define ID2D1Geometry_Widen(this,A,B,C,D) (this)->lpVtbl->Widen(this,A,B,C,D)

#endif

DEFINE_GUID(IID_ID2D1BitmapRenderTarget, 0x2cd90695,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1BitmapRenderTarget : public ID2D1RenderTarget {
    STDMETHOD(GetBitmap)(ID2D1Bitmap **bitmap) PURE;
};

#else

typedef struct ID2D1BitmapRenderTargetVtbl {
    ID2D1RenderTargetVtbl Base;

    STDMETHOD(GetBitmap)(ID2D1BitmapRenderTarget *This, ID2D1Bitmap **bitmap) PURE;
} ID2D1BitmapRenderTargetVtbl;

interface ID2D1BitmapRenderTarget {
    const ID2D1BitmapRenderTargetVtbl *lpVtbl;
};

#define ID2D1BitmapRenderTarget_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1BitmapRenderTarget_AddRef(this) (this)->lpVtbl->Base.Base.Base.AddRef((IUnknown*)(this))
#define ID2D1BitmapRenderTarget_Release(this) (this)->lpVtbl->Base.Base.Base.Release((IUnknown*)(this))
#define ID2D1BitmapRenderTarget_GetFactory(this,A) (this)->lpVtbl->Base.Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1BitmapRenderTarget_BeginDraw(this) (this)->lpVtbl->Base.BeginDraw((ID2D1RenderTarget*)(this))
#define ID2D1BitmapRenderTarget_Clear(this,A) (this)->lpVtbl->Base.Clear((ID2D1RenderTarget*)(this),A)
#define ID2D1BitmapRenderTarget_CreateBitmap(this,A,B,C,D,E) (this)->lpVtbl->Base.CreateBitmap((ID2D1RenderTarget*)(this),A,B,C,D,E)
#define ID2D1BitmapRenderTarget_CreateBitmapBrush(this,A,B) (this)->lpVtbl->Base.CreateBitmapBrush((ID2D1RenderTarget*)(this),A,B)
#define ID2D1BitmapRenderTarget_CreateBitmapFromWicBitmap(this,A,B,C) (this)->lpVtbl->Base.CreateBitmapFromWicBitmap((ID2D1RenderTarget*)(this),A,B,C)
#define ID2D1BitmapRenderTarget_CreateCompatibleBitmapRenderTarget(this,A,B,C,D,E) (this)->lpVtbl->Base.CreateCompatibleBitmapRenderTarget((ID2D1RenderTarget*)(this),A,B,C,D,E)
#define ID2D1BitmapRenderTarget_CreateGradientStopCollection(this,A,B,C) (this)->lpVtbl->Base.CreateGradientStopCollection((ID2D1RenderTarget*)(this),A,B,C)
#define ID2D1BitmapRenderTarget_CreateLayer(this,A,B) (this)->lpVtbl->Base.CreateLayer((ID2D1RenderTarget*)(this),A,B)
#define ID2D1BitmapRenderTarget_CreateLinearGradientBrush(this,A,B,C,D) (this)->lpVtbl->Base.CreateLinearGradientBrush((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1BitmapRenderTarget_CreateMesh(this,A) (this)->lpVtbl->Base.CreateMesh((ID2D1RenderTarget*)(this),A)
#define ID2D1BitmapRenderTarget_CreateRadialGradientBrush(this,A,B,C,D) (this)->lpVtbl->Base.CreateRadialGradientBrush((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1BitmapRenderTarget_CreateSharedBitmap(this,A,B,C,D) (this)->lpVtbl->Base.CreateSharedBitmap((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1BitmapRenderTarget_CreateSolidColorBrush(this,A,B,C) (this)->lpVtbl->Base.CreateSolidColorBrush((ID2D1RenderTarget*)(this),A,B,C)
#define ID2D1BitmapRenderTarget_DrawBitmap(this,A,B,C,D,E) (this)->lpVtbl->Base.DrawBitmap((ID2D1RenderTarget*)(this),A,B,C,D,E)
#define ID2D1BitmapRenderTarget_DrawEllipse(this,A,B,C,D) (this)->lpVtbl->Base.DrawEllipse((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1BitmapRenderTarget_DrawGeometry(this,A,B,C,D) (this)->lpVtbl->Base.DrawGeometry((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1BitmapRenderTarget_DrawGlyphRun(this,A,B,C,D) (this)->lpVtbl->Base.DrawGlyphRun((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1BitmapRenderTarget_DrawLine(this,A,B,C,D,E) (this)->lpVtbl->Base.DrawLine((ID2D1RenderTarget*)(this),A,B,C,D,E)
#define ID2D1BitmapRenderTarget_DrawRectangle(this,A,B,C,D) (this)->lpVtbl->Base.DrawRectangle((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1BitmapRenderTarget_DrawRoundedRectangle(this,A,B,C,D) (this)->lpVtbl->Base.DrawRoundedRectangle((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1BitmapRenderTarget_DrawText(this,A,B,C,D,E,F,G) (this)->lpVtbl->Base.DrawText((ID2D1RenderTarget*)(this),A,B,C,D,E,F,G)
#define ID2D1BitmapRenderTarget_DrawTextLayout(this,A,B,C,D) (this)->lpVtbl->Base.DrawTextLayout((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1BitmapRenderTarget_EndDraw(this,A,B) (this)->lpVtbl->Base.EndDraw((ID2D1RenderTarget*)(this),A,B)
#define ID2D1BitmapRenderTarget_FillEllipse(this,A,B) (this)->lpVtbl->Base.FillEllipse((ID2D1RenderTarget*)(this),A,B)
#define ID2D1BitmapRenderTarget_FillGeometry(this,A,B,C) (this)->lpVtbl->Base.FillGeometry((ID2D1RenderTarget*)(this),A,B,C)
#define ID2D1BitmapRenderTarget_FillMesh(this,A,B) (this)->lpVtbl->Base.FillMesh((ID2D1RenderTarget*)(this),A,B)
#define ID2D1BitmapRenderTarget_FillOpacityMask(this,A,B,C,D,E) (this)->lpVtbl->Base.FillOpacityMask((ID2D1RenderTarget*)(this),A,B,C,D,E)
#define ID2D1BitmapRenderTarget_FillRectangle(this,A,B) (this)->lpVtbl->Base.FillRectangle((ID2D1RenderTarget*)(this),A,B)
#define ID2D1BitmapRenderTarget_FillRoundedRectangle(this,A,B) (this)->lpVtbl->Base.FillRoundedRectangle((ID2D1RenderTarget*)(this),A,B)
#define ID2D1BitmapRenderTarget_Flush(this,A,B) (this)->lpVtbl->Base.Flush((ID2D1RenderTarget*)(this),A,B)
#define ID2D1BitmapRenderTarget_GetAntialiasMode(this) (this)->lpVtbl->Base.GetAntialiasMode((ID2D1RenderTarget*)(this))
#define ID2D1BitmapRenderTarget_GetDpi(this,A,B) (this)->lpVtbl->Base.GetDpi((ID2D1RenderTarget*)(this),A,B)
#define ID2D1BitmapRenderTarget_GetMaximumBitmapSize(this) (this)->lpVtbl->Base.GetMaximumBitmapSize((ID2D1RenderTarget*)(this))
#define ID2D1BitmapRenderTarget_GetPixelFormat(this) (this)->lpVtbl->Base.GetPixelFormat((ID2D1RenderTarget*)(this))
#define ID2D1BitmapRenderTarget_GetPixelSize(this) (this)->lpVtbl->Base.GetPixelSize((ID2D1RenderTarget*)(this))
#define ID2D1BitmapRenderTarget_GetSize(this) (this)->lpVtbl->Base.GetSize((ID2D1RenderTarget*)(this))
#define ID2D1BitmapRenderTarget_GetTags(this,A,B) (this)->lpVtbl->Base.GetTags((ID2D1RenderTarget*)(this),A,B)
#define ID2D1BitmapRenderTarget_GetTextAntialiasMode(this) (this)->lpVtbl->Base.GetTextAntialiasMode((ID2D1RenderTarget*)(this))
#define ID2D1BitmapRenderTarget_GetTextRenderingParams(this,A) (this)->lpVtbl->Base.GetTextRenderingParams((ID2D1RenderTarget*)(this),A)
#define ID2D1BitmapRenderTarget_GetTransform(this,A) (this)->lpVtbl->Base.GetTransform((ID2D1RenderTarget*)(this),A)
#define ID2D1BitmapRenderTarget_IsSupported(this,A) (this)->lpVtbl->Base.IsSupported((ID2D1RenderTarget*)(this),A)
#define ID2D1BitmapRenderTarget_PopAxisAlignedClip(this) (this)->lpVtbl->Base.PopAxisAlignedClip((ID2D1RenderTarget*)(this))
#define ID2D1BitmapRenderTarget_PopLayer(this) (this)->lpVtbl->Base.PopLayer((ID2D1RenderTarget*)(this))
#define ID2D1BitmapRenderTarget_PushAxisAlignedClip(this,A,B) (this)->lpVtbl->Base.PushAxisAlignedClip((ID2D1RenderTarget*)(this),A,B)
#define ID2D1BitmapRenderTarget_PushLayer(this,A,B) (this)->lpVtbl->Base.PushLayer((ID2D1RenderTarget*)(this),A,B)
#define ID2D1BitmapRenderTarget_RestoreDrawingState(this,A) (this)->lpVtbl->Base.RestoreDrawingState((ID2D1RenderTarget*)(this),A)
#define ID2D1BitmapRenderTarget_SaveDrawingState(this,A) (this)->lpVtbl->Base.SaveDrawingState((ID2D1RenderTarget*)(this),A)
#define ID2D1BitmapRenderTarget_SetAntialiasMode(this,A) (this)->lpVtbl->Base.SetAntialiasMode((ID2D1RenderTarget*)(this),A)
#define ID2D1BitmapRenderTarget_SetDpi(this,A,B) (this)->lpVtbl->Base.SetDpi((ID2D1RenderTarget*)(this),A,B)
#define ID2D1BitmapRenderTarget_SetTags(this,A,B) (this)->lpVtbl->Base.SetTags((ID2D1RenderTarget*)(this),A,B)
#define ID2D1BitmapRenderTarget_SetTextAntialiasMode(this,A) (this)->lpVtbl->Base.SetTextAntialiasMode((ID2D1RenderTarget*)(this),A)
#define ID2D1BitmapRenderTarget_SetTextRenderingParams(this,A) (this)->lpVtbl->Base.SetTextRenderingParams((ID2D1RenderTarget*)(this),A)
#define ID2D1BitmapRenderTarget_SetTransform(this,A) (this)->lpVtbl->Base.SetTransform((ID2D1RenderTarget*)(this),A)
#define ID2D1BitmapRenderTarget_GetBitmap(this,A) (this)->lpVtbl->GetBitmap(this,A)

#endif

DEFINE_GUID(IID_ID2D1DCRenderTarget, 0x1c51bc64,0xde61,0x46fd,0x98,0x99,0x63,0xa5,0xd8,0xf0,0x39,0x50);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1DCRenderTarget : public ID2D1RenderTarget {
    STDMETHOD(BindDC)(const HDC hDC, const RECT *pSubRect) PURE;
};

#else

typedef struct ID2D1DCRenderTargetVtbl {
    ID2D1RenderTargetVtbl Base;

    STDMETHOD(BindDC)(ID2D1DCRenderTarget *This, const HDC hDC, const RECT *pSubRect) PURE;
} ID2D1DCRenderTargetVtbl;

interface ID2D1DCRenderTarget
{
    const ID2D1DCRenderTargetVtbl *lpVtbl;
};

#define ID2D1DCRenderTarget_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1DCRenderTarget_AddRef(this) (this)->lpVtbl->Base.Base.Base.AddRef((IUnknown*)(this))
#define ID2D1DCRenderTarget_Release(this) (this)->lpVtbl->Base.Base.Base.Release((IUnknown*)(this))
#define ID2D1DCRenderTarget_GetFactory(this,A) (this)->lpVtbl->Base.Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1DCRenderTarget_BeginDraw(this) (this)->lpVtbl->Base.BeginDraw((ID2D1RenderTarget*)(this))
#define ID2D1DCRenderTarget_Clear(this,A) (this)->lpVtbl->Base.Clear((ID2D1RenderTarget*)(this),A)
#define ID2D1DCRenderTarget_CreateBitmap(this,A,B,C,D,E) (this)->lpVtbl->Base.CreateBitmap((ID2D1RenderTarget*)(this),A,B,C,D,E)
#define ID2D1DCRenderTarget_CreateBitmapBrush(this,A,B) (this)->lpVtbl->Base.CreateBitmapBrush((ID2D1RenderTarget*)(this),A,B)
#define ID2D1DCRenderTarget_CreateBitmapFromWicBitmap(this,A,B,C) (this)->lpVtbl->Base.CreateBitmapFromWicBitmap((ID2D1RenderTarget*)(this),A,B,C)
#define ID2D1DCRenderTarget_CreateCompatibleRenderTarget(this,A,B,C,D,E) (this)->lpVtbl->Base.CreateCompatibleRenderTarget((ID2D1RenderTarget*)(this),A,B,C,D,E)
#define ID2D1DCRenderTarget_CreateGradientStopCollection(this,A,B,C) (this)->lpVtbl->Base.CreateGradientStopCollection((ID2D1RenderTarget*)(this),A,B,C)
#define ID2D1DCRenderTarget_CreateLayer(this,A,B) (this)->lpVtbl->Base.CreateLayer((ID2D1RenderTarget*)(this),A,B)
#define ID2D1DCRenderTarget_CreateLinearGradientBrush(this,A,B,C,D) (this)->lpVtbl->Base.CreateLinearGradientBrush((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1DCRenderTarget_CreateMesh(this,A) (this)->lpVtbl->Base.CreateMesh((ID2D1RenderTarget*)(this),A)
#define ID2D1DCRenderTarget_CreateRadialGradientBrush(this,A,B,C,D) (this)->lpVtbl->Base.CreateRadialGradientBrush((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1DCRenderTarget_CreateSharedBitmap(this,A,B,C,D) (this)->lpVtbl->Base.CreateSharedBitmap((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1DCRenderTarget_CreateSolidColorBrush(this,A,B,C) (this)->lpVtbl->Base.CreateSolidColorBrush((ID2D1RenderTarget*)(this),A,B,C)
#define ID2D1DCRenderTarget_DrawBitmap(this,A,B,C,D,E) (this)->lpVtbl->Base.DrawBitmap((ID2D1RenderTarget*)(this),A,B,C,D,E)
#define ID2D1DCRenderTarget_DrawEllipse(this,A,B,C,D) (this)->lpVtbl->Base.DrawEllipse((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1DCRenderTarget_DrawGeometry(this,A,B,C,D) (this)->lpVtbl->Base.DrawGeometry((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1DCRenderTarget_DrawGlyphRun(this,A,B,C,D) (this)->lpVtbl->Base.DrawGlyphRun((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1DCRenderTarget_DrawLine(this,A,B,C,D,E) (this)->lpVtbl->Base.DrawLine((ID2D1RenderTarget*)(this),A,B,C,D,E)
#define ID2D1DCRenderTarget_DrawRectangle(this,A,B,C,D) (this)->lpVtbl->Base.DrawRectangle((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1DCRenderTarget_DrawRoundedRectangle(this,A,B,C,D) (this)->lpVtbl->Base.DrawRoundedRectangle((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1DCRenderTarget_DrawText(this,A,B,C,D,E,F,G) (this)->lpVtbl->Base.DrawText((ID2D1RenderTarget*)(this),A,B,C,D,E,F,G)
#define ID2D1DCRenderTarget_DrawTextLayout(this,A,B,C,D) (this)->lpVtbl->Base.DrawTextLayout((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1DCRenderTarget_EndDraw(this,A,B) (this)->lpVtbl->Base.EndDraw((ID2D1RenderTarget*)(this),A,B)
#define ID2D1DCRenderTarget_FillEllipse(this,A,B) (this)->lpVtbl->Base.FillEllipse((ID2D1RenderTarget*)(this),A,B)
#define ID2D1DCRenderTarget_FillGeometry(this,A,B,C) (this)->lpVtbl->Base.FillGeometry((ID2D1RenderTarget*)(this),A,B,C)
#define ID2D1DCRenderTarget_FillMesh(this,A,B) (this)->lpVtbl->Base.FillMesh((ID2D1RenderTarget*)(this),A,B)
#define ID2D1DCRenderTarget_FillOpacityMask(this,A,B,C,D,E) (this)->lpVtbl->Base.FillOpacityMask((ID2D1RenderTarget*)(this),A,B,C,D,E)
#define ID2D1DCRenderTarget_FillRectangle(this,A,B) (this)->lpVtbl->Base.FillRectangle((ID2D1RenderTarget*)(this),A,B)
#define ID2D1DCRenderTarget_FillRoundedRectangle(this,A,B) (this)->lpVtbl->Base.FillRoundedRectangle((ID2D1RenderTarget*)(this),A,B)
#define ID2D1DCRenderTarget_Flush(this,A,B) (this)->lpVtbl->Base.Flush((ID2D1RenderTarget*)(this),A,B)
#define ID2D1DCRenderTarget_GetAntialiasMode(this) (this)->lpVtbl->Base.GetAntialiasMode((ID2D1RenderTarget*)(this))
#define ID2D1DCRenderTarget_GetDpi(this,A,B) (this)->lpVtbl->Base.GetDpi((ID2D1RenderTarget*)(this),A,B)
#define ID2D1DCRenderTarget_GetMaximumBitmapSize(this) (this)->lpVtbl->Base.GetMaximumBitmapSize((ID2D1RenderTarget*)(this))
#define ID2D1DCRenderTarget_GetPixelFormat(this) (this)->lpVtbl->Base.GetPixelFormat((ID2D1RenderTarget*)(this))
#define ID2D1DCRenderTarget_GetPixelSize(this) (this)->lpVtbl->Base.GetPixelSize((ID2D1RenderTarget*)(this))
#define ID2D1DCRenderTarget_GetSize(this) (this)->lpVtbl->Base.GetSize((ID2D1RenderTarget*)(this))
#define ID2D1DCRenderTarget_GetTags(this,A,B) (this)->lpVtbl->Base.GetTags((ID2D1RenderTarget*)(this),A,B)
#define ID2D1DCRenderTarget_GetTextAntialiasMode(this) (this)->lpVtbl->Base.GetTextAntialiasMode((ID2D1RenderTarget*)(this))
#define ID2D1DCRenderTarget_GetTextRenderingParams(this,A) (this)->lpVtbl->Base.GetTextRenderingParams((ID2D1RenderTarget*)(this),A)
#define ID2D1DCRenderTarget_GetTransform(this,A) (this)->lpVtbl->Base.GetTransform((ID2D1RenderTarget*)(this),A)
#define ID2D1DCRenderTarget_IsSupported(this,A) (this)->lpVtbl->Base.IsSupported((ID2D1RenderTarget*)(this),A)
#define ID2D1DCRenderTarget_PopAxisAlignedClip(this) (this)->lpVtbl->Base.PopAxisAlignedClip((ID2D1RenderTarget*)(this))
#define ID2D1DCRenderTarget_PopLayer(this) (this)->lpVtbl->Base.PopLayer((ID2D1RenderTarget*)(this))
#define ID2D1DCRenderTarget_PushAxisAlignedClip(this,A,B) (this)->lpVtbl->Base.PushAxisAlignedClip((ID2D1RenderTarget*)(this),A,B)
#define ID2D1DCRenderTarget_PushLayer(this,A,B) (this)->lpVtbl->Base.PushLayer((ID2D1RenderTarget*)(this),A,B)
#define ID2D1DCRenderTarget_RestoreDrawingState(this,A) (this)->lpVtbl->Base.RestoreDrawingState((ID2D1RenderTarget*)(this),A)
#define ID2D1DCRenderTarget_SaveDrawingState(this,A) (this)->lpVtbl->Base.SaveDrawingState((ID2D1RenderTarget*)(this),A)
#define ID2D1DCRenderTarget_SetAntialiasMode(this,A) (this)->lpVtbl->Base.SetAntialiasMode((ID2D1RenderTarget*)(this),A)
#define ID2D1DCRenderTarget_SetDpi(this,A,B) (this)->lpVtbl->Base.SetDpi((ID2D1RenderTarget*)(this),A,B)
#define ID2D1DCRenderTarget_SetTags(this,A,B) (this)->lpVtbl->Base.SetTags((ID2D1RenderTarget*)(this),A,B)
#define ID2D1DCRenderTarget_SetTextAntialiasMode(this,A) (this)->lpVtbl->Base.SetTextAntialiasMode((ID2D1RenderTarget*)(this),A)
#define ID2D1DCRenderTarget_SetTextRenderingParams(this,A) (this)->lpVtbl->Base.SetTextRenderingParams((ID2D1RenderTarget*)(this),A)
#define ID2D1DCRenderTarget_SetTransform(this,A) (this)->lpVtbl->Base.SetTransform((ID2D1RenderTarget*)(this),A)
#define ID2D1DCRenderTarget_BindDC(this,A,B) (this)->lpVtbl->BindDC(this,A,B)

#endif

DEFINE_GUID(IID_ID2D1DrawingStateBlock, 0x28506e39,0xebf6,0x46a1,0xbb,0x47,0xfd,0x85,0x56,0x5a,0xb9,0x57);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1DrawingStateBlock : public ID2D1Resource {
    STDMETHOD_(void, GetDescription)(D2D1_DRAWING_STATE_DESCRIPTION *stateDescription) const PURE;
    STDMETHOD_(void, SetDescription)(const D2D1_DRAWING_STATE_DESCRIPTION *stateDescription) PURE;
    STDMETHOD_(void, SetTextRenderingParams)(IDWriteRenderingParams *textRenderingParams = NULL) PURE;
    STDMETHOD_(void, GetTextRenderingParams)(IDWriteRenderingParams **textRenderingParams) const PURE;

    void SetDescription(const D2D1_DRAWING_STATE_DESCRIPTION &stateDescription) {
        SetDescription(&stateDescription);
    }
};

#else

typedef struct ID2D1DrawingStateBlockVtbl {
    ID2D1ResourceVtbl Base;

    STDMETHOD_(void, GetDescription)(ID2D1DrawingStateBlock *This, D2D1_DRAWING_STATE_DESCRIPTION *stateDescription) PURE;
    STDMETHOD_(void, SetDescription)(ID2D1DrawingStateBlock *This, const D2D1_DRAWING_STATE_DESCRIPTION *stateDescription) PURE;
    STDMETHOD_(void, SetTextRenderingParams)(ID2D1DrawingStateBlock *This, IDWriteRenderingParams *textRenderingParams) PURE;
    STDMETHOD_(void, GetTextRenderingParams)(ID2D1DrawingStateBlock *This, IDWriteRenderingParams **textRenderingParams) PURE;
} ID2D1DrawingStateBlockVtbl;

interface ID2D1DrawingStateBlock {
    const struct ID2D1DrawingStateBlockVtbl *lpVtbl;
};

#define ID2D1DrawingStateBlock_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1DrawingStateBlock_AddRef(this) (this)->lpVtbl->Base.Base.AddRef((IUnknown*)(this))
#define ID2D1DrawingStateBlock_Release(this) (this)->lpVtbl->Base.Base.Release((IUnknown*)(this))
#define ID2D1DrawingStateBlock_GetFactory(this,A) (this)->lpVtbl->Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1DrawingStateBlock_GetDescription(this,A) (this)->lpVtbl->GetDescription(this,A)
#define ID2D1DrawingStateBlock_GetTextRenderingParams(this,A) (this)->lpVtbl->GetTextRenderingParams(this,A)
#define ID2D1DrawingStateBlock_SetDescription(this,A) (this)->lpVtbl->SetDescription(this,A)
#define ID2D1DrawingStateBlock_SetTextRenderingParams(this,A) (this)->lpVtbl->SetTextRenderingParams(this,A)

#endif

DEFINE_GUID(IID_ID2D1SimplifiedGeometrySink, 0x2cd9069e,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1SimplifiedGeometrySink : public IUnknown {
    STDMETHOD_(void, SetFillMode)(D2D1_FILL_MODE fillMode) PURE;
    STDMETHOD_(void, SetSegmentFlags)(D2D1_PATH_SEGMENT vertexFlags) PURE;
    STDMETHOD_(void, BeginFigure)(D2D1_POINT_2F startPoint, D2D1_FIGURE_BEGIN figureBegin) PURE;
    STDMETHOD_(void, AddLines)(const D2D1_POINT_2F *points, UINT pointsCount) PURE;
    STDMETHOD_(void, AddBeziers)(const D2D1_BEZIER_SEGMENT *beziers, UINT beziersCount) PURE;
    STDMETHOD_(void, EndFigure)(D2D1_FIGURE_END figureEnd) PURE;
    STDMETHOD(Close)(void) PURE;
};

#else

typedef struct ID2D1SimplifiedGeometrySinkVtbl {
    IUnknownVtbl Base;

    STDMETHOD_(void, SetFillMode)(ID2D1SimplifiedGeometrySink *This, D2D1_FILL_MODE fillMode) PURE;
    STDMETHOD_(void, SetSegmentFlags)(ID2D1SimplifiedGeometrySink *This, D2D1_PATH_SEGMENT vertexFlags) PURE;
    STDMETHOD_(void, BeginFigure)(ID2D1SimplifiedGeometrySink *This, D2D1_POINT_2F startPoint, D2D1_FIGURE_BEGIN figureBegin) PURE;
    STDMETHOD_(void, AddLines)(ID2D1SimplifiedGeometrySink *This, const D2D1_POINT_2F *points, UINT pointsCount) PURE;
    STDMETHOD_(void, AddBeziers)(ID2D1SimplifiedGeometrySink *This, const D2D1_BEZIER_SEGMENT *beziers, UINT beziersCount) PURE;
    STDMETHOD_(void, EndFigure)(ID2D1SimplifiedGeometrySink *This, D2D1_FIGURE_END figureEnd) PURE;
    STDMETHOD(Close)(ID2D1SimplifiedGeometrySink *This) PURE;
} ID2D1SimplifiedGeometrySinkVtbl;

interface ID2D1SimplifiedGeometrySink {
    const ID2D1SimplifiedGeometrySinkVtbl *lpVtbl;
};

#define ID2D1SimplifiedGeometrySink_QueryInterface(this,A,B) (this)->lpVtbl->Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1SimplifiedGeometrySink_AddRef(this) (this)->lpVtbl->Base.AddRef((IUnknown*)(this))
#define ID2D1SimplifiedGeometrySink_Release(this) (this)->lpVtbl->Base.Release((IUnknown*)(this))
#define ID2D1SimplifiedGeometrySink_SetFillMode(this,A) (this)->lpVtbl->SetFillMode(this,A)
#define ID2D1SimplifiedGeometrySink_SetSegmentFlags(this,A) (this)->lpVtbl->SetSegmentFlags(this,A)
#define ID2D1SimplifiedGeometrySink_BeginFigure(this,A,B) (this)->lpVtbl->BeginFigure(this,A,B)
#define ID2D1SimplifiedGeometrySink_AddLines(this,A,B) (this)->lpVtbl->AddLines(this,A,B)
#define ID2D1SimplifiedGeometrySink_AddBeziers(this,A,B) (this)->lpVtbl->AddBeziers(this,A,B)
#define ID2D1SimplifiedGeometrySink_EndFigure(this,A) (this)->lpVtbl->EndFigure(this,A)
#define ID2D1SimplifiedGeometrySink_Close(this) (this)->lpVtbl->Close(this)

#endif

DEFINE_GUID(IID_ID2D1EllipseGeometry, 0x2cd906a4,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1EllipseGeometry : public ID2D1Geometry {
    STDMETHOD_(void, GetEllipse)(D2D1_ELLIPSE *ellipse) const PURE;
};

#else

typedef struct ID2D1EllipseGeometryVtbl {
    ID2D1GeometryVtbl Base;

    STDMETHOD_(void, GetEllipse)(ID2D1EllipseGeometry *This, D2D1_ELLIPSE *ellipse) PURE;
} ID2D1EllipseGeometryVtbl;

interface ID2D1EllipseGeometry {
    const struct ID2D1EllipseGeometryVtbl *lpVtbl;
};

#define ID2D1EllipseGeometry_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1EllipseGeometry_AddRef(this) (this)->lpVtbl->Base.Base.Base.AddRef((IUnknown*)(this))
#define ID2D1EllipseGeometry_Release(this) (this)->lpVtbl->Base.Base.Base.Release((IUnknown*)(this))
#define ID2D1EllipseGeometry_GetFactory(this,A) (this)->lpVtbl->Base.Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1EllipseGeometry_CombineWithGeometry(this,A,B,C,D) (this)->lpVtbl->Base.CombineWithGeometry((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1EllipseGeometry_CompareWithGeometry(this,A,B,C) (this)->lpVtbl->Base.CompareWithGeometry((ID2D1Geometry*)(this),A,B,C)
#define ID2D1EllipseGeometry_ComputeArea(this,A,B) (this)->lpVtbl->Base.ComputeArea((ID2D1Geometry*)(this),A,B)
#define ID2D1EllipseGeometry_ComputeLength(this,A,B) (this)->lpVtbl->Base.ComputeLength((ID2D1Geometry*)(this),A,B)
#define ID2D1EllipseGeometry_ComputePointAtLength(this,A,B,C,D) (this)->lpVtbl->Base.ComputePointAtLength((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1EllipseGeometry_FillContainsPoint(this,A,B,C) (this)->lpVtbl->Base.FillContainsPoint((ID2D1Geometry*)(this),A,B,C)
#define ID2D1EllipseGeometry_GetBounds(this,A,B) (this)->lpVtbl->Base.GetBounds((ID2D1Geometry*)(this),A,B)
#define ID2D1EllipseGeometry_GetWidenedBounds(this,A,B,C,D) (this)->lpVtbl->Base.GetWidenedBounds((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1EllipseGeometry_Outline(this,A,B) (this)->lpVtbl->Base.Outline((ID2D1Geometry*)(this),A,B)
#define ID2D1EllipseGeometry_StrokeContainsPoint(this,A,B,C,D,E) (this)->lpVtbl->Base.StrokeContainsPoint((ID2D1Geometry*)(this),A,B,C,D,E)
#define ID2D1EllipseGeometry_Simplify(this,A,B,C) (this)->lpVtbl->Base.Simplify((ID2D1Geometry*)(this),A,B,C)
#define ID2D1EllipseGeometry_Tessellate(this,A,B) (this)->lpVtbl->Base.Tessellate((ID2D1Geometry*)(this),A,B)
#define ID2D1EllipseGeometry_Widen(this,A,B,C,D) (this)->lpVtbl->Base.Widen((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1EllipseGeometry_GetEllipse(this,A) (this)->lpVtbl->GetEllipse(this,A)

#endif

DEFINE_GUID(IID_ID2D1Factory, 0x06152247,0x6f50,0x465a,0x92,0x45,0x11,0x8b,0xfd,0x3b,0x60,0x07);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1Factory : public IUnknown {
    STDMETHOD(ReloadSystemMetrics)(void) PURE;
    STDMETHOD_(void, GetDesktopDpi)(FLOAT *dpiX, FLOAT *dpiY) PURE;
    STDMETHOD(CreateRectangleGeometry)(const D2D1_RECT_F *rectangle, ID2D1RectangleGeometry **rectangleGeometry) PURE;
    STDMETHOD(CreateRoundedRectangleGeometry)(const D2D1_ROUNDED_RECT *roundedRectangle, ID2D1RoundedRectangleGeometry **roundedRectangleGeometry) PURE;
    STDMETHOD(CreateEllipseGeometry)(const D2D1_ELLIPSE *ellipse, ID2D1EllipseGeometry **ellipseGeometry) PURE;
    STDMETHOD(CreateGeometryGroup)(D2D1_FILL_MODE fillMode, ID2D1Geometry **geometries, UINT geometriesCount, ID2D1GeometryGroup **geometryGroup) PURE;
    STDMETHOD(CreateTransformedGeometry)(ID2D1Geometry *sourceGeometry, const D2D1_MATRIX_3X2_F *transform, ID2D1TransformedGeometry **transformedGeometry) PURE;
    STDMETHOD(CreatePathGeometry)(ID2D1PathGeometry **pathGeometry) PURE;
    STDMETHOD(CreateStrokeStyle)(const D2D1_STROKE_STYLE_PROPERTIES *strokeStyleProperties, const FLOAT *dashes, UINT dashesCount, ID2D1StrokeStyle **strokeStyle) PURE;
    STDMETHOD(CreateDrawingStateBlock)(const D2D1_DRAWING_STATE_DESCRIPTION *drawingStateDescription, IDWriteRenderingParams *textRenderingParams, ID2D1DrawingStateBlock **drawingStateBlock) PURE;
    STDMETHOD(CreateWicBitmapRenderTarget)(IWICBitmap *target, const D2D1_RENDER_TARGET_PROPERTIES *renderTargetProperties, ID2D1RenderTarget **renderTarget) PURE;
    STDMETHOD(CreateHwndRenderTarget)(const D2D1_RENDER_TARGET_PROPERTIES *renderTargetProperties, const D2D1_HWND_RENDER_TARGET_PROPERTIES *hwndRenderTargetProperties, ID2D1HwndRenderTarget **hwndRenderTarget) PURE;
    STDMETHOD(CreateDxgiSurfaceRenderTarget)(IDXGISurface *dxgiSurface, const D2D1_RENDER_TARGET_PROPERTIES *renderTargetProperties, ID2D1RenderTarget **renderTarget) PURE;
    STDMETHOD(CreateDCRenderTarget)(const D2D1_RENDER_TARGET_PROPERTIES *renderTargetProperties, ID2D1DCRenderTarget **dcRenderTarget) PURE;

    HRESULT CreateRectangleGeometry(const D2D1_RECT_F &rectangle, ID2D1RectangleGeometry **rectangleGeometry) {
        return CreateRectangleGeometry(&rectangle, rectangleGeometry);
    }

    HRESULT CreateRoundedRectangleGeometry(const D2D1_ROUNDED_RECT &roundedRectangle, ID2D1RoundedRectangleGeometry **roundedRectangleGeometry) {
        return CreateRoundedRectangleGeometry(&roundedRectangle, roundedRectangleGeometry);
    }

    HRESULT CreateEllipseGeometry(const D2D1_ELLIPSE &ellipse, ID2D1EllipseGeometry **ellipseGeometry) {
        return CreateEllipseGeometry(&ellipse, ellipseGeometry);
    }

    HRESULT CreateTransformedGeometry(ID2D1Geometry *sourceGeometry, const D2D1_MATRIX_3X2_F &transform, ID2D1TransformedGeometry **transformedGeometry) {
        return CreateTransformedGeometry(sourceGeometry, &transform, transformedGeometry);
    }

    HRESULT CreateStrokeStyle(const D2D1_STROKE_STYLE_PROPERTIES &strokeStyleProperties, const FLOAT *dashes, UINT dashesCount, ID2D1StrokeStyle **strokeStyle) {
        return CreateStrokeStyle(&strokeStyleProperties, dashes, dashesCount, strokeStyle);
    }

    HRESULT CreateDrawingStateBlock(const D2D1_DRAWING_STATE_DESCRIPTION &drawingStateDescription, ID2D1DrawingStateBlock **drawingStateBlock) {
        return CreateDrawingStateBlock(&drawingStateDescription, NULL, drawingStateBlock);
    }

    HRESULT CreateDrawingStateBlock(ID2D1DrawingStateBlock **drawingStateBlock) {
        return CreateDrawingStateBlock(NULL, NULL, drawingStateBlock);
    }

    HRESULT CreateWicBitmapRenderTarget(IWICBitmap *target, const D2D1_RENDER_TARGET_PROPERTIES &renderTargetProperties, ID2D1RenderTarget **renderTarget) {
        return CreateWicBitmapRenderTarget(target, &renderTargetProperties, renderTarget);
    }

    HRESULT CreateHwndRenderTarget(const D2D1_RENDER_TARGET_PROPERTIES &renderTargetProperties, const D2D1_HWND_RENDER_TARGET_PROPERTIES &hwndRenderTargetProperties, ID2D1HwndRenderTarget **hwndRenderTarget) {
        return CreateHwndRenderTarget(&renderTargetProperties, &hwndRenderTargetProperties, hwndRenderTarget);
    }

    HRESULT CreateDxgiSurfaceRenderTarget(IDXGISurface *dxgiSurface, const D2D1_RENDER_TARGET_PROPERTIES &renderTargetProperties, ID2D1RenderTarget **renderTarget) {
        return CreateDxgiSurfaceRenderTarget(dxgiSurface, &renderTargetProperties, renderTarget);
    }
};

#else

typedef struct ID2D1FactoryVtbl {
    IUnknownVtbl Base;

    STDMETHOD(ReloadSystemMetrics)(ID2D1Factory *This) PURE;
    STDMETHOD_(void, GetDesktopDpi)(ID2D1Factory *This, FLOAT *dpiX, FLOAT *dpiY) PURE;
    STDMETHOD(CreateRectangleGeometry)(ID2D1Factory *This, const D2D1_RECT_F *rectangle, ID2D1RectangleGeometry **rectangleGeometry) PURE;
    STDMETHOD(CreateRoundedRectangleGeometry)(ID2D1Factory *This, const D2D1_ROUNDED_RECT *roundedRectangle, ID2D1RoundedRectangleGeometry **roundedRectangleGeometry) PURE;
    STDMETHOD(CreateEllipseGeometry)(ID2D1Factory *This, const D2D1_ELLIPSE *ellipse, ID2D1EllipseGeometry **ellipseGeometry) PURE;
    STDMETHOD(CreateGeometryGroup)(ID2D1Factory *This, D2D1_FILL_MODE fillMode, ID2D1Geometry **geometries, UINT geometriesCount, ID2D1GeometryGroup **geometryGroup) PURE;
    STDMETHOD(CreateTransformedGeometry)(ID2D1Factory *This, ID2D1Geometry *sourceGeometry, const D2D1_MATRIX_3X2_F *transform, ID2D1TransformedGeometry **transformedGeometry) PURE;
    STDMETHOD(CreatePathGeometry)(ID2D1Factory *This, ID2D1PathGeometry **pathGeometry) PURE;
    STDMETHOD(CreateStrokeStyle)(ID2D1Factory *This, const D2D1_STROKE_STYLE_PROPERTIES *strokeStyleProperties, const FLOAT *dashes, UINT dashesCount, ID2D1StrokeStyle **strokeStyle) PURE;
    STDMETHOD(CreateDrawingStateBlock)(ID2D1Factory *This, const D2D1_DRAWING_STATE_DESCRIPTION *drawingStateDescription, IDWriteRenderingParams *textRenderingParams, ID2D1DrawingStateBlock **drawingStateBlock) PURE;
    STDMETHOD(CreateWicBitmapRenderTarget)(ID2D1Factory *This, IWICBitmap *target, const D2D1_RENDER_TARGET_PROPERTIES *renderTargetProperties, ID2D1RenderTarget **renderTarget) PURE;
    STDMETHOD(CreateHwndRenderTarget)(ID2D1Factory *This, const D2D1_RENDER_TARGET_PROPERTIES *renderTargetProperties, const D2D1_HWND_RENDER_TARGET_PROPERTIES *hwndRenderTargetProperties, ID2D1HwndRenderTarget **hwndRenderTarget) PURE;
    STDMETHOD(CreateDxgiSurfaceRenderTarget)(ID2D1Factory *This, IDXGISurface *dxgiSurface, const D2D1_RENDER_TARGET_PROPERTIES *renderTargetProperties, ID2D1RenderTarget **renderTarget) PURE;
    STDMETHOD(CreateDCRenderTarget)(ID2D1Factory *This, const D2D1_RENDER_TARGET_PROPERTIES *renderTargetProperties, ID2D1DCRenderTarget **dcRenderTarget) PURE;
} ID2D1FactoryVtbl;

interface ID2D1Factory {
    const ID2D1FactoryVtbl *lpVtbl;
};

#define ID2D1Factory_QueryInterface(this,A,B) (this)->lpVtbl->Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1Factory_AddRef(this) (this)->lpVtbl->Base.AddRef((IUnknown*)(this))
#define ID2D1Factory_Release(this) (this)->lpVtbl->Base.Release((IUnknown*)(this))
#define ID2D1Factory_CreateDCRenderTarget(this,A,B) (this)->lpVtbl->CreateDCRenderTarget(this,A,B)
#define ID2D1Factory_CreateDrawingStateBlock(this,A,B,C) (this)->lpVtbl->CreateDrawingStateBlock(this,A,B,C)
#define ID2D1Factory_CreateDxgiSurfaceRenderTarget(this,A,B,C) (this)->lpVtbl->CreateDxgiSurfaceRenderTarget(this,A,B,C)
#define ID2D1Factory_CreateEllipseGeometry(this,A,B) (this)->lpVtbl->CreateEllipseGeometry(this,A,B)
#define ID2D1Factory_CreateGeometryGroup(this,A,B,C,D) (this)->lpVtbl->CreateGeometryGroup(this,A,B,C,D)
#define ID2D1Factory_CreateHwndRenderTarget(this,A,B,C) (this)->lpVtbl->CreateHwndRenderTarget(this,A,B,C)
#define ID2D1Factory_CreatePathGeometry(this,A) (this)->lpVtbl->CreatePathGeometry(this,A)
#define ID2D1Factory_CreateRectangleGeometry(this,A,B) (this)->lpVtbl->CreateRectangleGeometry(this,A,B)
#define ID2D1Factory_CreateRoundedRectangleGeometry(this,A,B) (this)->lpVtbl->CreateRoundedRectangleGeometry(this,A,B)
#define ID2D1Factory_CreateStrokeStyle(this,A,B,C,D) (this)->lpVtbl->CreateStrokeStyle(this,A,B,C,D)
#define ID2D1Factory_CreateTransformedGeometry(this,A,B,C) (this)->lpVtbl->CreateTransformedGeometry(this,A,B,C)
#define ID2D1Factory_CreateWicBitmapRenderTarget(this,A,B,C) (this)->lpVtbl->CreateWicBitmapRenderTarget(this,A,B,C)
#define ID2D1Factory_GetDesktopDpi(this,A,B) (this)->lpVtbl->GetDesktopDpi(this,A,B)
#define ID2D1Factory_ReloadSystemMetrics(this) (this)->lpVtbl->ReloadSystemMetrics(this)

#endif

DEFINE_GUID(IID_ID2D1GdiInteropRenderTarget, 0xe0db51c3,0x6f77,0x4bae,0xb3,0xd5,0xe4,0x75,0x09,0xb3,0x58,0x38);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1GdiInteropRenderTarget : public IUnknown {
    STDMETHOD(GetDC)(D2D1_DC_INITIALIZE_MODE mode, HDC *hdc) PURE;
    STDMETHOD(ReleaseDC)(const RECT *update) PURE;
};

#else

typedef struct ID2D1GdiInteropRenderTargetVtbl {
    IUnknownVtbl Base;

    STDMETHOD(GetDC)(ID2D1GdiInteropRenderTarget *This, D2D1_DC_INITIALIZE_MODE mode, HDC *hdc) PURE;
    STDMETHOD(ReleaseDC)(ID2D1GdiInteropRenderTarget *This, const RECT *update) PURE;
} ID2D1GdiInteropRenderTargetVtbl;

interface ID2D1GdiInteropRenderTarget {
    const ID2D1GdiInteropRenderTargetVtbl *lpVtbl;
};

#define ID2D1GdiInteropRenderTarget_QueryInterface(this,A,B) (this)->lpVtbl->Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1GdiInteropRenderTarget_AddRef(this) (this)->lpVtbl->Base.AddRef((IUnknown*)(this))
#define ID2D1GdiInteropRenderTarget_Release(this) (this)->lpVtbl->Base.Release((IUnknown*)(this))
#define ID2D1GdiInteropRenderTarget_GetDC(this,A,B) (this)->lpVtbl->GetDC(this,A,B)
#define ID2D1GdiInteropRenderTarget_ReleaseDC(this,A) (this)->lpVtbl->ReleaseDC(this,A)

#endif

DEFINE_GUID(IID_ID2D1GeometryGroup, 0x2cd906a6,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1GeometryGroup : public ID2D1Geometry {
    STDMETHOD_(D2D1_FILL_MODE, GetFillMode)() const PURE;
    STDMETHOD_(UINT32, GetSourceGeometryCount)() const PURE;
    STDMETHOD_(void, GetSourceGeometries)(ID2D1Geometry **geometries, UINT geometriesCount) const PURE;
};

#else

typedef struct ID2D1GeometryGroupVtbl {
    ID2D1GeometryVtbl Base;

    STDMETHOD_(D2D1_FILL_MODE, GetFillMode)(ID2D1GeometryGroup *This) PURE;
    STDMETHOD_(UINT32, GetSourceGeometryCount)(ID2D1GeometryGroup *This) PURE;
    STDMETHOD_(void, GetSourceGeometries)(ID2D1GeometryGroup *This, ID2D1Geometry **geometries, UINT geometriesCount) PURE;
} ID2D1GeometryGroupVtbl;

interface ID2D1GeometryGroup {
    const struct ID2D1GeometryGroupVtbl *lpVtbl;
};

#define ID2D1GeometryGroup_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1GeometryGroup_AddRef(this) (this)->lpVtbl->Base.Base.Base.AddRef((IUnknown*)(this))
#define ID2D1GeometryGroup_Release(this) (this)->lpVtbl->Base.Base.Base.Release((IUnknown*)(this))
#define ID2D1GeometryGroup_GetFactory(this,A) (this)->lpVtbl->Base.Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1GeometryGroup_CombineWithGeometry(this,A,B,C,D) (this)->lpVtbl->Base.CombineWithGeometry((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1GeometryGroup_CompareWithGeometry(this,A,B,C) (this)->lpVtbl->Base.CompareWithGeometry((ID2D1Geometry*)(this),A,B,C)
#define ID2D1GeometryGroup_ComputeArea(this,A,B) (this)->lpVtbl->Base.ComputeArea((ID2D1Geometry*)(this),A,B)
#define ID2D1GeometryGroup_ComputeLength(this,A,B) (this)->lpVtbl->Base.ComputeLength((ID2D1Geometry*)(this),A,B)
#define ID2D1GeometryGroup_ComputePointAtLength(this,A,B,C,D) (this)->lpVtbl->Base.ComputePointAtLength((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1GeometryGroup_FillContainsPoint(this,A,B,C) (this)->lpVtbl->Base.FillContainsPoint((ID2D1Geometry*)(this),A,B,C)
#define ID2D1GeometryGroup_GetBounds(this,A,B) (this)->lpVtbl->Base.GetBounds((ID2D1Geometry*)(this),A,B)
#define ID2D1GeometryGroup_GetWidenedBounds(this,A,B,C,D) (this)->lpVtbl->Base.GetWidenedBounds((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1GeometryGroup_Outline(this,A,B) (this)->lpVtbl->Base.Outline((ID2D1Geometry*)(this),A,B)
#define ID2D1GeometryGroup_StrokeContainsPoint(this,A,B,C,D,E) (this)->lpVtbl->Base.StrokeContainsPoint((ID2D1Geometry*)(this),A,B,C,D,E)
#define ID2D1GeometryGroup_Simplify(this,A,B,C) (this)->lpVtbl->Base.Simplify((ID2D1Geometry*)(this),A,B,C)
#define ID2D1GeometryGroup_Tessellate(this,A,B) (this)->lpVtbl->Base.Tessellate((ID2D1Geometry*)(this),A,B)
#define ID2D1GeometryGroup_Widen(this,A,B,C,D) (this)->lpVtbl->Base.Widen((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1GeometryGroup_GetFillMode(this) (this)->lpVtbl->GetFillMode(this)
#define ID2D1GeometryGroup_GetSourceGeometries(this,A,B) (this)->lpVtbl->GetSourceGeometries(this,A,B)
#define ID2D1GeometryGroup_GetSourceGeometryCount(this) (this)->lpVtbl->GetSourceGeometryCount(this)

#endif

DEFINE_GUID(IID_ID2D1GeometrySink, 0x2cd9069f,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1GeometrySink : public ID2D1SimplifiedGeometrySink {
    STDMETHOD_(void, AddLine)(D2D1_POINT_2F point) PURE;
    STDMETHOD_(void, AddBezier)(const D2D1_BEZIER_SEGMENT *bezier) PURE;
    STDMETHOD_(void, AddQuadraticBezier)(const D2D1_QUADRATIC_BEZIER_SEGMENT *bezier) PURE;
    STDMETHOD_(void, AddQuadraticBeziers)(const D2D1_QUADRATIC_BEZIER_SEGMENT *beziers, UINT beziersCount) PURE;
    STDMETHOD_(void, AddArc)(const D2D1_ARC_SEGMENT *arc) PURE;

    void AddBezier(const D2D1_BEZIER_SEGMENT &bezier) {
        AddBezier(&bezier);
    }

    void AddQuadraticBezier(const D2D1_QUADRATIC_BEZIER_SEGMENT &bezier) {
        AddQuadraticBezier(&bezier);
    }

    void  AddArc(const D2D1_ARC_SEGMENT &arc) {
        AddArc(&arc);
    }
};

#else

typedef struct ID2D1GeometrySinkVtbl {
    ID2D1SimplifiedGeometrySinkVtbl Base;

    STDMETHOD_(void, AddLine)(ID2D1GeometrySink *This, D2D1_POINT_2F point) PURE;
    STDMETHOD_(void, AddBezier)(ID2D1GeometrySink *This, const D2D1_BEZIER_SEGMENT *bezier) PURE;
    STDMETHOD_(void, AddQuadraticBezier)(ID2D1GeometrySink *This, const D2D1_QUADRATIC_BEZIER_SEGMENT *bezier) PURE;
    STDMETHOD_(void, AddQuadraticBeziers)(ID2D1GeometrySink *This, const D2D1_QUADRATIC_BEZIER_SEGMENT *beziers, UINT beziersCount) PURE;
    STDMETHOD_(void, AddArc)(ID2D1GeometrySink *This, const D2D1_ARC_SEGMENT *arc) PURE;
} ID2D1GeometrySinkVtbl;

interface ID2D1GeometrySink {
    const ID2D1GeometrySinkVtbl *lpVtbl;
};

#define ID2D1GeometrySink_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1GeometrySink_AddRef(this) (this)->lpVtbl->Base.Base.AddRef((IUnknown*)(this))
#define ID2D1GeometrySink_Release(this) (this)->lpVtbl->Base.Base.Release((IUnknown*)(this))
#define ID2D1GeometrySink_SetFillMode(this,A) (this)->lpVtbl->Base.SetFillMode((ID2D1SimplifiedGeometrySink*)(this),A)
#define ID2D1GeometrySink_SetSegmentFlags(this,A) (this)->lpVtbl->Base.SetSegmentFlags((ID2D1SimplifiedGeometrySink*)(this),A)
#define ID2D1GeometrySink_BeginFigure(this,A,B) (this)->lpVtbl->Base.BeginFigure((ID2D1SimplifiedGeometrySink*)(this),A,B)
#define ID2D1GeometrySink_AddLines(this,A,B) (this)->lpVtbl->Base.AddLines((ID2D1SimplifiedGeometrySink*)(this),A,B)
#define ID2D1GeometrySink_AddBeziers(this,A,B) (this)->lpVtbl->Base.AddBeziers((ID2D1SimplifiedGeometrySink*)(this),A,B)
#define ID2D1GeometrySink_EndFigure(this,A) (this)->lpVtbl->Base.EndFigure((ID2D1SimplifiedGeometrySink*)(this),A)
#define ID2D1GeometrySink_Close(this) (this)->lpVtbl->Base.Close((ID2D1SimplifiedGeometrySink*)(this))
#define ID2D1GeometrySink_AddArc(this,A) (this)->lpVtbl->AddArc(this,A)
#define ID2D1GeometrySink_AddBezier(this,A) (this)->lpVtbl->AddBezier(this,A)
#define ID2D1GeometrySink_AddLine(this,A) (this)->lpVtbl->AddLine(this,A)
#define ID2D1GeometrySink_AddQuadraticBezier(this,A) (this)->lpVtbl->AddQuadraticBezier(this,A)
#define ID2D1GeometrySink_AddQuadraticBeziers(this,A,B) (this)->lpVtbl->AddQuadraticBeziers(this,A,B)

#endif

DEFINE_GUID(IID_ID2D1GradientStopCollection, 0x2cd906a7,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1GradientStopCollection : public ID2D1Resource {
    STDMETHOD_(UINT32, GetGradientStopCount)(void) const PURE;
    STDMETHOD_(void, GetGradientStops)(D2D1_GRADIENT_STOP *gradientStops, UINT gradientStopsCount) const PURE;
    STDMETHOD_(D2D1_GAMMA, GetColorInterpolationGamma)(void) const PURE;
    STDMETHOD_(D2D1_EXTEND_MODE, GetExtendMode)(void) const PURE;
};

#else

typedef struct ID2D1GradientStopCollectionVtbl {
    ID2D1ResourceVtbl Base;

    STDMETHOD_(UINT32, GetGradientStopCount)(ID2D1GradientStopCollection *This) PURE;
    STDMETHOD_(void, GetGradientStops)(ID2D1GradientStopCollection *This, D2D1_GRADIENT_STOP *gradientStops, UINT gradientStopsCount) PURE;
    STDMETHOD_(D2D1_GAMMA, GetColorInterpolationGamma)(ID2D1GradientStopCollection *This) PURE;
    STDMETHOD_(D2D1_EXTEND_MODE, GetExtendMode)(ID2D1GradientStopCollection *This) PURE;
} ID2D1GradientStopCollectionVtbl;

interface ID2D1GradientStopCollection {
    const ID2D1GradientStopCollectionVtbl *lpVtbl;
};

#define ID2D1GradientStopCollection_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1GradientStopCollection_AddRef(this) (this)->lpVtbl->Base.Base.AddRef((IUnknown*)(this))
#define ID2D1GradientStopCollection_Release(this) (this)->lpVtbl->Base.Base.Release((IUnknown*)(this))
#define ID2D1GradientStopCollection_GetFactory(this,A) (this)->lpVtbl->Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1GradientStopCollection_GetColorInterpolationGamma(this) (this)->lpVtbl->GetColorInterpolationGamma(this)
#define ID2D1GradientStopCollection_GetExtendMode(this) (this)->lpVtbl->GetExtendMode(this)
#define ID2D1GradientStopCollection_GetGradientStopCount(this) (this)->lpVtbl->GetGradientStopCount(this)
#define ID2D1GradientStopCollection_GetGradientStops(this,A,B) (this)->lpVtbl->GetGradientStops(this,A,B)

#endif

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1HwndRenderTarget : public ID2D1RenderTarget {
    STDMETHOD_(D2D1_WINDOW_STATE, CheckWindowState)() PURE;
    STDMETHOD(Resize)(const D2D1_SIZE_U *pixelSize) PURE;
    STDMETHOD_(HWND, GetHwnd)() const PURE;

    HRESULT Resize(const D2D1_SIZE_U &pixelSize) {
        return Resize(&pixelSize);
    }
};

#else

typedef interface ID2D1HwndRenderTarget ID2D1HwndRenderTarget;

typedef struct ID2D1HwndRenderTargetVtbl {
    ID2D1RenderTargetVtbl Base;

    STDMETHOD_(D2D1_WINDOW_STATE, CheckWindowState)(ID2D1HwndRenderTarget *This) PURE;
    STDMETHOD(Resize)(ID2D1HwndRenderTarget *This, const D2D1_SIZE_U *pixelSize) PURE;
    STDMETHOD_(HWND, GetHwnd)(ID2D1HwndRenderTarget *This) PURE;
} ID2D1HwndRenderTargetVtbl;

interface ID2D1HwndRenderTarget {
    const struct ID2D1HwndRenderTargetVtbl *lpVtbl;
};

#define ID2D1HwndRenderTarget_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1HwndRenderTarget_AddRef(this) (this)->lpVtbl->Base.Base.Base.AddRef((IUnknown*)(this))
#define ID2D1HwndRenderTarget_Release(this) (this)->lpVtbl->Base.Base.Base.Release((IUnknown*)(this))
#define ID2D1HwndRenderTarget_GetFactory(this,A) (this)->lpVtbl->Base.Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1HwndRenderTarget_BeginDraw(this) (this)->lpVtbl->Base.BeginDraw((ID2D1RenderTarget*)(this))
#define ID2D1HwndRenderTarget_Clear(this,A) (this)->lpVtbl->Base.Clear((ID2D1RenderTarget*)(this),A)
#define ID2D1HwndRenderTarget_CreateBitmap(this,A,B,C,D,E) (this)->lpVtbl->Base.CreateBitmap((ID2D1RenderTarget*)(this),A,B,C,D,E)
#define ID2D1HwndRenderTarget_CreateBitmapBrush(this,A,B) (this)->lpVtbl->Base.CreateBitmapBrush((ID2D1RenderTarget*)(this),A,B)
#define ID2D1HwndRenderTarget_CreateBitmapFromWicBitmap(this,A,B,C) (this)->lpVtbl->Base.CreateBitmapFromWicBitmap((ID2D1RenderTarget*)(this),A,B,C)
#define ID2D1HwndRenderTarget_CreateCompatibleRenderTarget(this,A,B,C,D,E) (this)->lpVtbl->Base.CreateCompatibleRenderTarget((ID2D1RenderTarget*)(this),A,B,C,D,E)
#define ID2D1HwndRenderTarget_CreateGradientStopCollection(this,A,B,C) (this)->lpVtbl->Base.CreateGradientStopCollection((ID2D1RenderTarget*)(this),A,B,C)
#define ID2D1HwndRenderTarget_CreateLayer(this,A,B) (this)->lpVtbl->Base.CreateLayer((ID2D1RenderTarget*)(this),A,B)
#define ID2D1HwndRenderTarget_CreateLinearGradientBrush(this,A,B,C,D) (this)->lpVtbl->Base.CreateLinearGradientBrush((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1HwndRenderTarget_CreateMesh(this,A) (this)->lpVtbl->Base.CreateMesh((ID2D1RenderTarget*)(this),A)
#define ID2D1HwndRenderTarget_CreateRadialGradientBrush(this,A,B,C,D) (this)->lpVtbl->Base.CreateRadialGradientBrush((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1HwndRenderTarget_CreateSharedBitmap(this,A,B,C,D) (this)->lpVtbl->Base.CreateSharedBitmap((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1HwndRenderTarget_CreateSolidColorBrush(this,A,B,C) (this)->lpVtbl->Base.CreateSolidColorBrush((ID2D1RenderTarget*)(this),A,B,C)
#define ID2D1HwndRenderTarget_DrawBitmap(this,A,B,C,D,E) (this)->lpVtbl->Base.DrawBitmap((ID2D1RenderTarget*)(this),A,B,C,D,E)
#define ID2D1HwndRenderTarget_DrawEllipse(this,A,B,C,D) (this)->lpVtbl->Base.DrawEllipse((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1HwndRenderTarget_DrawGeometry(this,A,B,C,D) (this)->lpVtbl->Base.DrawGeometry((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1HwndRenderTarget_DrawGlyphRun(this,A,B,C,D) (this)->lpVtbl->Base.DrawGlyphRun((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1HwndRenderTarget_DrawLine(this,A,B,C,D,E) (this)->lpVtbl->Base.DrawLine((ID2D1RenderTarget*)(this),A,B,C,D,E)
#define ID2D1HwndRenderTarget_DrawRectangle(this,A,B,C,D) (this)->lpVtbl->Base.DrawRectangle((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1HwndRenderTarget_DrawRoundedRectangle(this,A,B,C,D) (this)->lpVtbl->Base.DrawRoundedRectangle((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1HwndRenderTarget_DrawText(this,A,B,C,D,E,F,G) (this)->lpVtbl->Base.DrawText((ID2D1RenderTarget*)(this),A,B,C,D,E,F,G)
#define ID2D1HwndRenderTarget_DrawTextLayout(this,A,B,C,D) (this)->lpVtbl->Base.DrawTextLayout((ID2D1RenderTarget*)(this),A,B,C,D)
#define ID2D1HwndRenderTarget_EndDraw(this,A,B) (this)->lpVtbl->Base.EndDraw((ID2D1RenderTarget*)(this),A,B)
#define ID2D1HwndRenderTarget_FillEllipse(this,A,B) (this)->lpVtbl->Base.FillEllipse((ID2D1RenderTarget*)(this),A,B)
#define ID2D1HwndRenderTarget_FillGeometry(this,A,B,C) (this)->lpVtbl->Base.FillGeometry((ID2D1RenderTarget*)(this),A,B,C)
#define ID2D1HwndRenderTarget_FillMesh(this,A,B) (this)->lpVtbl->Base.FillMesh((ID2D1RenderTarget*)(this),A,B)
#define ID2D1HwndRenderTarget_FillOpacityMask(this,A,B,C,D,E) (this)->lpVtbl->Base.FillOpacityMask((ID2D1RenderTarget*)(this),A,B,C,D,E)
#define ID2D1HwndRenderTarget_FillRectangle(this,A,B) (this)->lpVtbl->Base.FillRectangle((ID2D1RenderTarget*)(this),A,B)
#define ID2D1HwndRenderTarget_FillRoundedRectangle(this,A,B) (this)->lpVtbl->Base.FillRoundedRectangle((ID2D1RenderTarget*)(this),A,B)
#define ID2D1HwndRenderTarget_Flush(this,A,B) (this)->lpVtbl->Base.Flush((ID2D1RenderTarget*)(this),A,B)
#define ID2D1HwndRenderTarget_GetAntialiasMode(this) (this)->lpVtbl->Base.GetAntialiasMode((ID2D1RenderTarget*)(this))
#define ID2D1HwndRenderTarget_GetDpi(this,A,B) (this)->lpVtbl->Base.GetDpi((ID2D1RenderTarget*)(this),A,B)
#define ID2D1HwndRenderTarget_GetMaximumBitmapSize(this) (this)->lpVtbl->Base.GetMaximumBitmapSize((ID2D1RenderTarget*)(this))
#define ID2D1HwndRenderTarget_GetPixelFormat(this) (this)->lpVtbl->Base.GetPixelFormat((ID2D1RenderTarget*)(this))
#define ID2D1HwndRenderTarget_GetPixelSize(this) (this)->lpVtbl->Base.GetPixelSize((ID2D1RenderTarget*)(this))
#define ID2D1HwndRenderTarget_GetSize(this) (this)->lpVtbl->Base.GetSize((ID2D1RenderTarget*)(this))
#define ID2D1HwndRenderTarget_GetTags(this,A,B) (this)->lpVtbl->Base.GetTags((ID2D1RenderTarget*)(this),A,B)
#define ID2D1HwndRenderTarget_GetTextAntialiasMode(this) (this)->lpVtbl->Base.GetTextAntialiasMode((ID2D1RenderTarget*)(this))
#define ID2D1HwndRenderTarget_GetTextRenderingParams(this,A) (this)->lpVtbl->Base.GetTextRenderingParams((ID2D1RenderTarget*)(this),A)
#define ID2D1HwndRenderTarget_GetTransform(this,A) (this)->lpVtbl->Base.GetTransform((ID2D1RenderTarget*)(this),A)
#define ID2D1HwndRenderTarget_IsSupported(this,A) (this)->lpVtbl->Base.IsSupported((ID2D1RenderTarget*)(this),A)
#define ID2D1HwndRenderTarget_PopAxisAlignedClip(this) (this)->lpVtbl->Base.PopAxisAlignedClip((ID2D1RenderTarget*)(this))
#define ID2D1HwndRenderTarget_PopLayer(this) (this)->lpVtbl->Base.PopLayer((ID2D1RenderTarget*)(this))
#define ID2D1HwndRenderTarget_PushAxisAlignedClip(this,A,B) (this)->lpVtbl->Base.PushAxisAlignedClip((ID2D1RenderTarget*)(this),A,B)
#define ID2D1HwndRenderTarget_PushLayer(this,A,B) (this)->lpVtbl->Base.PushLayer((ID2D1RenderTarget*)(this),A,B)
#define ID2D1HwndRenderTarget_RestoreDrawingState(this,A) (this)->lpVtbl->Base.RestoreDrawingState((ID2D1RenderTarget*)(this),A)
#define ID2D1HwndRenderTarget_SaveDrawingState(this,A) (this)->lpVtbl->Base.SaveDrawingState((ID2D1RenderTarget*)(this),A)
#define ID2D1HwndRenderTarget_SetAntialiasMode(this,A) (this)->lpVtbl->Base.SetAntialiasMode((ID2D1RenderTarget*)(this),A)
#define ID2D1HwndRenderTarget_SetDpi(this,A,B) (this)->lpVtbl->Base.SetDpi((ID2D1RenderTarget*)(this),A,B)
#define ID2D1HwndRenderTarget_SetTags(this,A,B) (this)->lpVtbl->Base.SetTags((ID2D1RenderTarget*)(this),A,B)
#define ID2D1HwndRenderTarget_SetTextAntialiasMode(this,A) (this)->lpVtbl->Base.SetTextAntialiasMode((ID2D1RenderTarget*)(this),A)
#define ID2D1HwndRenderTarget_SetTextRenderingParams(this,A) (this)->lpVtbl->Base.SetTextRenderingParams((ID2D1RenderTarget*)(this),A)
#define ID2D1HwndRenderTarget_SetTransform(this,A) (this)->lpVtbl->Base.SetTransform((ID2D1RenderTarget*)(this),A)
#define ID2D1HwndRenderTarget_CheckWindowState(this) (this)->lpVtbl->CheckWindowState(this)
#define ID2D1HwndRenderTarget_GetHwnd(this) (this)->lpVtbl->GetHwnd(this)
#define ID2D1HwndRenderTarget_Resize(this,A) (this)->lpVtbl->Resize(this,A)

#endif

DEFINE_GUID(IID_ID2D1Layer, 0x2cd9069b,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1Layer : public ID2D1Resource {
#ifndef WIDL_EXPLICIT_AGGREGATE_RETURNS
    STDMETHOD_(D2D1_SIZE_F, GetSize)(void) const PURE;
#else
    virtual D2D1_SIZE_F* STDMETHODCALLTYPE GetSize(D2D1_SIZE_F*) const = 0;
    D2D1_SIZE_F STDMETHODCALLTYPE GetSize() const {
        D2D1_SIZE_F __ret;
        GetSize(&__ret);
        return __ret;
    }
#endif
};

#else

typedef struct ID2D1LayerVtbl {
    ID2D1ResourceVtbl Base;

    STDMETHOD_(D2D1_SIZE_F, GetSize)(ID2D1Layer *This) PURE;
} ID2D1LayerVtbl;

interface ID2D1Layer {
    const ID2D1LayerVtbl *lpVtbl;
};

#define ID2D1Layer_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1Layer_AddRef(this) (this)->lpVtbl->Base.Base.AddRef((IUnknown*)(this))
#define ID2D1Layer_Release(this) (this)->lpVtbl->Base.Base.Release((IUnknown*)(this))
#define ID2D1Layer_GetFactory(this,A) (this)->lpVtbl->Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1Layer_GetSize(this) (this)->lpVtbl->GetSize(this)

#endif

DEFINE_GUID(IID_ID2D1LinearGradientBrush, 0x2cd906ab,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1LinearGradientBrush : public ID2D1Brush {
    STDMETHOD_(void, SetStartPoint)(D2D1_POINT_2F startPoint) PURE;
    STDMETHOD_(void, SetEndPoint)(D2D1_POINT_2F endPoint) PURE;

#ifndef WIDL_EXPLICIT_AGGREGATE_RETURNS
    STDMETHOD_(D2D1_POINT_2F, GetStartPoint)(void) const PURE;
#else
    virtual D2D1_POINT_2F* STDMETHODCALLTYPE GetStartPoint(D2D1_POINT_2F*) const = 0;
    D2D1_POINT_2F STDMETHODCALLTYPE GetStartPoint() const {
        D2D1_POINT_2F __ret;
        GetStartPoint(&__ret);
        return __ret;
    }
#endif

#ifndef WIDL_EXPLICIT_AGGREGATE_RETURNS
    STDMETHOD_(D2D1_POINT_2F, GetEndPoint)(void) const PURE;
#else
    virtual D2D1_POINT_2F* STDMETHODCALLTYPE GetEndPoint(D2D1_POINT_2F*) const = 0;
    D2D1_POINT_2F STDMETHODCALLTYPE GetEndPoint() const {
        D2D1_POINT_2F __ret;
        GetEndPoint(&__ret);
        return __ret;
    }
#endif

    STDMETHOD_(void, GetGradientStopCollection)(ID2D1GradientStopCollection **gradientStopCollection) const PURE;
};

#else

typedef struct ID2D1LinearGradientBrushVtbl {
    ID2D1BrushVtbl Base;

    STDMETHOD_(void, SetStartPoint)(ID2D1LinearGradientBrush *This, D2D1_POINT_2F startPoint) PURE;
    STDMETHOD_(void, SetEndPoint)(ID2D1LinearGradientBrush *This, D2D1_POINT_2F endPoint) PURE;
    STDMETHOD_(D2D1_POINT_2F, GetStartPoint)(ID2D1LinearGradientBrush *This) PURE;
    STDMETHOD_(D2D1_POINT_2F, GetEndPoint)(ID2D1LinearGradientBrush *This) PURE;
    STDMETHOD_(void, GetGradientStopCollection)(ID2D1LinearGradientBrush *This, ID2D1GradientStopCollection **gradientStopCollection) PURE;
} ID2D1LinearGradientBrushVtbl;

interface ID2D1LinearGradientBrush {
    const ID2D1LinearGradientBrushVtbl *lpVtbl;
};

#define ID2D1LinearGradientBrush_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1LinearGradientBrush_AddRef(this) (this)->lpVtbl->Base.Base.Base.AddRef((IUnknown*)(this))
#define ID2D1LinearGradientBrush_Release(this) (this)->lpVtbl->Base.Base.Base.Release((IUnknown*)(this))
#define ID2D1LinearGradientBrush_GetFactory(this,A) (this)->lpVtbl->Base.Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1LinearGradientBrush_SetOpacity(this,A) (this)->lpVtbl->Base.SetOpacity((ID2D1Brush*)(this),A)
#define ID2D1LinearGradientBrush_SetTransform(this,A) (this)->lpVtbl->Base.SetTransform((ID2D1Brush*)(this),A)
#define ID2D1LinearGradientBrush_GetOpacity(this) (this)->lpVtbl->Base.GetOpacity((ID2D1Brush*)(this))
#define ID2D1LinearGradientBrush_GetTransform(this,A) (this)->lpVtbl->Base.GetTransform((ID2D1Brush*)(this),A)
#define ID2D1LinearGradientBrush_GetEndPoint(this) (this)->lpVtbl->GetEndPoint(this)
#define ID2D1LinearGradientBrush_GetGradientStopCollection(this,A) (this)->lpVtbl->GetGradientStopCollection(this,A)
#define ID2D1LinearGradientBrush_GetStartPoint(this) (this)->lpVtbl->GetStartPoint(this)
#define ID2D1LinearGradientBrush_SetEndPoint(this,A) (this)->lpVtbl->SetEndPoint(this,A)
#define ID2D1LinearGradientBrush_SetStartPoint(this,A) (this)->lpVtbl->SetStartPoint(this,A)

#endif

DEFINE_GUID(IID_ID2D1Mesh,0x2cd906c2,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1Mesh : public ID2D1Resource {
    STDMETHOD(Open)(ID2D1TessellationSink **tessellationSink) PURE;
};

#else

typedef struct ID2D1MeshVtbl{
    ID2D1ResourceVtbl Base;

    STDMETHOD(Open)(ID2D1Mesh *This, ID2D1TessellationSink **tessellationSink) PURE;
} ID2D1MeshVtbl;

interface ID2D1Mesh {
    const struct ID2D1MeshVtbl *lpVtbl;
};

#define ID2D1Mesh_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1Mesh_AddRef(this) (this)->lpVtbl->Base.Base.AddRef((IUnknown*)(this))
#define ID2D1Mesh_Release(this) (this)->lpVtbl->Base.Base.Release((IUnknown*)(this))
#define ID2D1Mesh_GetFactory(this,A) (this)->lpVtbl->Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1Mesh_Open(this,A) (this)->lpVtbl->Open(this,A)

#endif

DEFINE_GUID(IID_ID2D1PathGeometry, 0x2cd906a5,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1PathGeometry : public ID2D1Geometry {
    STDMETHOD(Open)(ID2D1GeometrySink **geometrySink) PURE;
    STDMETHOD(Stream)(ID2D1GeometrySink *geometrySink) const PURE;
    STDMETHOD(GetSegmentCount)(UINT32 *count) const PURE;
    STDMETHOD(GetFigureCount)(UINT32 *count) const PURE;
};

#else

typedef struct ID2D1PathGeometryVtbl {
    ID2D1GeometryVtbl Base;

    STDMETHOD(Open)(ID2D1PathGeometry *This, ID2D1GeometrySink **geometrySink) PURE;
    STDMETHOD(Stream)(ID2D1PathGeometry *This, ID2D1GeometrySink *geometrySink) PURE;
    STDMETHOD(GetSegmentCount)(ID2D1PathGeometry *This, UINT32 *count) PURE;
    STDMETHOD(GetFigureCount)(ID2D1PathGeometry *This, UINT32 *count) PURE;
} ID2D1PathGeometryVtbl;

interface ID2D1PathGeometry {
    const ID2D1PathGeometryVtbl *lpVtbl;
};

#define ID2D1PathGeometry_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1PathGeometry_AddRef(this) (this)->lpVtbl->Base.Base.Base.AddRef((IUnknown*)(this))
#define ID2D1PathGeometry_Release(this) (this)->lpVtbl->Base.Base.Base.Release((IUnknown*)(this))
#define ID2D1PathGeometry_GetFactory(this,A) (this)->lpVtbl->Base.Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1PathGeometry_CombineWithGeometry(this,A,B,C,D) (this)->lpVtbl->Base.CombineWithGeometry((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1PathGeometry_CompareWithGeometry(this,A,B,C) (this)->lpVtbl->Base.CompareWithGeometry((ID2D1Geometry*)(this),A,B,C)
#define ID2D1PathGeometry_ComputeArea(this,A,B) (this)->lpVtbl->Base.ComputeArea((ID2D1Geometry*)(this),A,B)
#define ID2D1PathGeometry_ComputeLength(this,A,B) (this)->lpVtbl->Base.ComputeLength((ID2D1Geometry*)(this),A,B)
#define ID2D1PathGeometry_ComputePointAtLength(this,A,B,C,D) (this)->lpVtbl->Base.ComputePointAtLength((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1PathGeometry_FillContainsPoint(this,A,B,C) (this)->lpVtbl->Base.FillContainsPoint((ID2D1Geometry*)(this),A,B,C)
#define ID2D1PathGeometry_GetBounds(this,A,B) (this)->lpVtbl->Base.GetBounds((ID2D1Geometry*)(this),A,B)
#define ID2D1PathGeometry_GetWidenedBounds(this,A,B,C,D) (this)->lpVtbl->Base.GetWidenedBounds((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1PathGeometry_Outline(this,A,B) (this)->lpVtbl->Base.Outline((ID2D1Geometry*)(this),A,B)
#define ID2D1PathGeometry_StrokeContainsPoint(this,A,B,C,D,E) (this)->lpVtbl->Base.StrokeContainsPoint((ID2D1Geometry*)(this),A,B,C,D,E)
#define ID2D1PathGeometry_Simplify(this,A,B,C) (this)->lpVtbl->Base.Simplify((ID2D1Geometry*)(this),A,B,C)
#define ID2D1PathGeometry_Tessellate(this,A,B) (this)->lpVtbl->Base.Tessellate((ID2D1Geometry*)(this),A,B)
#define ID2D1PathGeometry_Widen(this,A,B,C,D) (this)->lpVtbl->Base.Widen((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1PathGeometry_Open(this,A) (this)->lpVtbl->Open(this,A)
#define ID2D1PathGeometry_Stream(this,A) (this)->lpVtbl->Stream(this,A)
#define ID2D1PathGeometry_GetSegmentCount(this,A) (this)->lpVtbl->GetSegmentCount(this,A)
#define ID2D1PathGeometry_GetFigureCount(this,A) (this)->lpVtbl->GetFigureCount(this,A)

#endif

DEFINE_GUID(IID_ID2D1RadialGradientBrush, 0x2cd906ac,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1RadialGradientBrush : public ID2D1Brush {
    STDMETHOD_(void, SetCenter)(D2D1_POINT_2F center) PURE;
    STDMETHOD_(void, SetGradientOriginOffset)(D2D1_POINT_2F gradientOriginOffset) PURE;
    STDMETHOD_(void, SetRadiusX)(FLOAT radiusX) PURE;
    STDMETHOD_(void, SetRadiusY)(FLOAT radiusY) PURE;

#ifndef WIDL_EXPLICIT_AGGREGATE_RETURNS
    STDMETHOD_(D2D1_POINT_2F, GetCenter)(void) const PURE;
#else
    virtual D2D1_POINT_2F* STDMETHODCALLTYPE GetCenter(D2D1_POINT_2F *__ret) const = 0;
    D2D1_POINT_2F STDMETHODCALLTYPE GetCenter() const
    {
        D2D1_POINT_2F __ret;
        GetCenter(&__ret);
        return __ret;
    }
#endif

#ifndef WIDL_EXPLICIT_AGGREGATE_RETURNS
    STDMETHOD_(D2D1_POINT_2F, GetGradientOriginOffset)(void) const PURE;
#else
    virtual D2D1_POINT_2F* STDMETHODCALLTYPE GetGradientOriginOffset(D2D1_POINT_2F *__ret) const = 0;
    D2D1_POINT_2F STDMETHODCALLTYPE GetGradientOriginOffset() const
    {
        D2D1_POINT_2F __ret;
        GetGradientOriginOffset(&__ret);
        return __ret;
    }
#endif

    STDMETHOD_(FLOAT, GetRadiusX)(void) const PURE;
    STDMETHOD_(FLOAT, GetRadiusY)(void) const PURE;
    STDMETHOD_(void, GetGradientStopCollection)(ID2D1GradientStopCollection **gradientStopCollection) const PURE;
};

#else

typedef struct ID2D1RadialGradientBrushVtbl {
    ID2D1BrushVtbl Base;

    STDMETHOD_(void, SetCenter)(ID2D1RadialGradientBrush *This, D2D1_POINT_2F center) PURE;
    STDMETHOD_(void, SetGradientOriginOffset)(ID2D1RadialGradientBrush *This, D2D1_POINT_2F gradientOriginOffset) PURE;
    STDMETHOD_(void, SetRadiusX)(ID2D1RadialGradientBrush *This, FLOAT radiusX) PURE;
    STDMETHOD_(void, SetRadiusY)(ID2D1RadialGradientBrush *This, FLOAT radiusY) PURE;
    STDMETHOD_(D2D1_POINT_2F, GetCenter)(ID2D1RadialGradientBrush *This) PURE;
    STDMETHOD_(D2D1_POINT_2F, GetGradientOriginOffset)(ID2D1RadialGradientBrush *This) PURE;
    STDMETHOD_(FLOAT, GetRadiusX)(ID2D1RadialGradientBrush *This) PURE;
    STDMETHOD_(FLOAT, GetRadiusY)(ID2D1RadialGradientBrush *This) PURE;
    STDMETHOD_(void, GetGradientStopCollection)(ID2D1RadialGradientBrush *This, ID2D1GradientStopCollection **gradientStopCollection) PURE;
} ID2D1RadialGradientBrushVtbl;

interface ID2D1RadialGradientBrush {
    const ID2D1RadialGradientBrushVtbl *lpVtbl;
};

#define ID2D1RadialGradientBrush_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1RadialGradientBrush_AddRef(this) (this)->lpVtbl->Base.Base.Base.AddRef((IUnknown*)(this))
#define ID2D1RadialGradientBrush_Release(this) (this)->lpVtbl->Base.Base.Base.Release((IUnknown*)(this))
#define ID2D1RadialGradientBrush_GetFactory(this,A) (this)->lpVtbl->Base.Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1RadialGradientBrush_SetOpacity(this,A) (this)->lpVtbl->Base.SetOpacity((ID2D1Brush*)(this),A)
#define ID2D1RadialGradientBrush_SetTransform(this,A) (this)->lpVtbl->Base.SetTransform((ID2D1Brush*)(this),A)
#define ID2D1RadialGradientBrush_GetOpacity(this) (this)->lpVtbl->Base.GetOpacity((ID2D1Brush*)(this))
#define ID2D1RadialGradientBrush_GetTransform(this,A) (this)->lpVtbl->Base.GetTransform((ID2D1Brush*)(this),A)
#define ID2D1RadialGradientBrush_GetCenter(this) (this)->lpVtbl->GetCenter(this)
#define ID2D1RadialGradientBrush_GetGradientOriginOffset(this) (this)->lpVtbl->GetGradientOriginOffset(this)
#define ID2D1RadialGradientBrush_GetGradientStopCollection(this,A) (this)->lpVtbl->GetGradientStopCollection(this,A)
#define ID2D1RadialGradientBrush_GetRadiusX(this) (this)->lpVtbl->GetRadiusX(this)
#define ID2D1RadialGradientBrush_GetRadiusY(this) (this)->lpVtbl->GetRadiusY(this)
#define ID2D1RadialGradientBrush_SetCenter(this,A) (this)->lpVtbl->SetCenter(this,A)
#define ID2D1RadialGradientBrush_SetGradientOriginOffset(this,A) (this)->lpVtbl->SetGradientOriginOffset(this,A)
#define ID2D1RadialGradientBrush_SetRadiusX(this,A) (this)->lpVtbl->SetRadiusX(this,A)
#define ID2D1RadialGradientBrush_SetRadiusY(this,A) (this)->lpVtbl->SetRadiusY(this,A)

#endif

DEFINE_GUID(IID_ID2D1RectangleGeometry, 0x2cd906a2,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1RectangleGeometry : public ID2D1Geometry {
    STDMETHOD_(void, GetRect)(D2D1_RECT_F *rect) const PURE;
};

#else

typedef struct ID2D1RectangleGeometryVtbl {
    ID2D1GeometryVtbl Base;

    STDMETHOD_(void, GetRect)(ID2D1RectangleGeometry *This, D2D1_RECT_F *rect) PURE;
} ID2D1RectangleGeometryVtbl;

interface ID2D1RectangleGeometry {
    const ID2D1RectangleGeometryVtbl *lpVtbl;
};

#define ID2D1RectangleGeometry_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1RectangleGeometry_AddRef(this) (this)->lpVtbl->Base.Base.Base.AddRef((IUnknown*)(this))
#define ID2D1RectangleGeometry_Release(this) (this)->lpVtbl->Base.Base.Base.Release((IUnknown*)(this))
#define ID2D1RectangleGeometry_GetFactory(this,A) (this)->lpVtbl->Base.Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1RectangleGeometry_CombineWithGeometry(this,A,B,C,D) (this)->lpVtbl->Base.CombineWithGeometry((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1RectangleGeometry_CompareWithGeometry(this,A,B,C) (this)->lpVtbl->Base.CompareWithGeometry((ID2D1Geometry*)(this),A,B,C)
#define ID2D1RectangleGeometry_ComputeArea(this,A,B) (this)->lpVtbl->Base.ComputeArea((ID2D1Geometry*)(this),A,B)
#define ID2D1RectangleGeometry_ComputeLength(this,A,B) (this)->lpVtbl->Base.ComputeLength((ID2D1Geometry*)(this),A,B)
#define ID2D1RectangleGeometry_ComputePointAtLength(this,A,B,C,D) (this)->lpVtbl->Base.ComputePointAtLength((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1RectangleGeometry_FillContainsPoint(this,A,B,C) (this)->lpVtbl->Base.FillContainsPoint((ID2D1Geometry*)(this),A,B,C)
#define ID2D1RectangleGeometry_GetBounds(this,A,B) (this)->lpVtbl->Base.GetBounds((ID2D1Geometry*)(this),A,B)
#define ID2D1RectangleGeometry_GetWidenedBounds(this,A,B,C,D) (this)->lpVtbl->Base.GetWidenedBounds((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1RectangleGeometry_Outline(this,A,B) (this)->lpVtbl->Base.Outline((ID2D1Geometry*)(this),A,B)
#define ID2D1RectangleGeometry_StrokeContainsPoint(this,A,B,C,D,E) (this)->lpVtbl->Base.StrokeContainsPoint((ID2D1Geometry*)(this),A,B,C,D,E)
#define ID2D1RectangleGeometry_Simplify(this,A,B,C) (this)->lpVtbl->Base.Simplify((ID2D1Geometry*)(this),A,B,C)
#define ID2D1RectangleGeometry_Tessellate(this,A,B) (this)->lpVtbl->Base.Tessellate((ID2D1Geometry*)(this),A,B)
#define ID2D1RectangleGeometry_Widen(this,A,B,C,D) (this)->lpVtbl->Base.Widen((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1RectangleGeometry_GetRect(this,A) (this)->lpVtbl->GetRect(this,A)

#endif

DEFINE_GUID(IID_ID2D1RoundedRectangleGeometry, 0x2cd906a3,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1RoundedRectangleGeometry : public ID2D1Geometry {
    STDMETHOD_(void, GetRoundedRect)(D2D1_ROUNDED_RECT *roundedRect) const PURE;
};

#else

typedef struct ID2D1RoundedRectangleGeometryVtbl {
    ID2D1GeometryVtbl Base;

    STDMETHOD_(void, GetRoundedRect)(ID2D1RoundedRectangleGeometry *This, D2D1_ROUNDED_RECT *roundedRect) PURE;
} ID2D1RoundedRectangleGeometryVtbl;

interface ID2D1RoundedRectangleGeometry {
    const struct ID2D1RoundedRectangleGeometryVtbl *lpVtbl;
};

#define ID2D1RoundedRectangleGeometry_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1RoundedRectangleGeometry_AddRef(this) (this)->lpVtbl->Base.Base.Base.AddRef((IUnknown*)(this))
#define ID2D1RoundedRectangleGeometry_Release(this) (this)->lpVtbl->Base.Base.Base.Release((IUnknown*)(this))
#define ID2D1RoundedRectangleGeometry_GetFactory(this,A) (this)->lpVtbl->Base.Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1RoundedRectangleGeometry_CombineWithGeometry(this,A,B,C,D) (this)->lpVtbl->Base.CombineWithGeometry((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1RoundedRectangleGeometry_CompareWithGeometry(this,A,B,C) (this)->lpVtbl->Base.CompareWithGeometry((ID2D1Geometry*)(this),A,B,C)
#define ID2D1RoundedRectangleGeometry_ComputeArea(this,A,B) (this)->lpVtbl->Base.ComputeArea((ID2D1Geometry*)(this),A,B)
#define ID2D1RoundedRectangleGeometry_ComputeLength(this,A,B) (this)->lpVtbl->Base.ComputeLength((ID2D1Geometry*)(this),A,B)
#define ID2D1RoundedRectangleGeometry_ComputePointAtLength(this,A,B,C,D) (this)->lpVtbl->Base.ComputePointAtLength((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1RoundedRectangleGeometry_FillContainsPoint(this,A,B,C) (this)->lpVtbl->Base.FillContainsPoint((ID2D1Geometry*)(this),A,B,C)
#define ID2D1RoundedRectangleGeometry_GetBounds(this,A,B) (this)->lpVtbl->Base.GetBounds((ID2D1Geometry*)(this),A,B)
#define ID2D1RoundedRectangleGeometry_GetWidenedBounds(this,A,B,C,D) (this)->lpVtbl->Base.GetWidenedBounds((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1RoundedRectangleGeometry_Outline(this,A,B) (this)->lpVtbl->Base.Outline((ID2D1Geometry*)(this),A,B)
#define ID2D1RoundedRectangleGeometry_StrokeContainsPoint(this,A,B,C,D,E) (this)->lpVtbl->Base.StrokeContainsPoint((ID2D1Geometry*)(this),A,B,C,D,E)
#define ID2D1RoundedRectangleGeometry_Simplify(this,A,B,C) (this)->lpVtbl->Base.Simplify((ID2D1Geometry*)(this),A,B,C)
#define ID2D1RoundedRectangleGeometry_Tessellate(this,A,B) (this)->lpVtbl->Base.Tessellate((ID2D1Geometry*)(this),A,B)
#define ID2D1RoundedRectangleGeometry_Widen(this,A,B,C,D) (this)->lpVtbl->Base.Widen((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1RoundedRectangleGeometry_GetRoundedRect(this,A) (this)->lpVtbl->GetRoundedRect(this,A)

#endif

DEFINE_GUID(IID_ID2D1SolidColorBrush, 0x2cd906a9,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1SolidColorBrush : public ID2D1Brush {
    STDMETHOD_(void, SetColor)(const D2D1_COLOR_F *color) PURE;

#ifndef WIDL_EXPLICIT_AGGREGATE_RETURNS
    STDMETHOD_(D2D1_COLOR_F, GetColor)(void) const PURE;
#else
    virtual D2D1_COLOR_F* STDMETHODCALLTYPE GetColor(D2D1_COLOR_F*) const = 0;
    D2D1_COLOR_F STDMETHODCALLTYPE GetColor() const {
        D2D1_COLOR_F __ret;
        GetColor(&__ret);
        return __ret;
    }
#endif

    void SetColor(const D2D1_COLOR_F &color) {
        SetColor(&color);
    }
};

#else

typedef struct ID2D1SolidColorBrushVtbl {
    ID2D1BrushVtbl Base;

    STDMETHOD_(void, SetColor)(ID2D1SolidColorBrush *This, const D2D1_COLOR_F *color) PURE;
    STDMETHOD_(D2D1_COLOR_F, GetColor)(ID2D1SolidColorBrush *This) PURE;
} ID2D1SolidColorBrushVtbl;

interface ID2D1SolidColorBrush {
    const ID2D1SolidColorBrushVtbl *lpVtbl;
};

#define ID2D1SolidColorBrush_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1SolidColorBrush_AddRef(this) (this)->lpVtbl->Base.Base.Base.AddRef((IUnknown*)(this))
#define ID2D1SolidColorBrush_Release(this) (this)->lpVtbl->Base.Base.Base.Release((IUnknown*)(this))
#define ID2D1SolidColorBrush_GetFactory(this,A) (this)->lpVtbl->Base.Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1SolidColorBrush_SetOpacity(this,A) (this)->lpVtbl->Base.SetOpacity((ID2D1Brush*)(this),A)
#define ID2D1SolidColorBrush_SetTransform(this,A) (this)->lpVtbl->Base.SetTransform((ID2D1Brush*)(this),A)
#define ID2D1SolidColorBrush_GetOpacity(this) (this)->lpVtbl->Base.GetOpacity((ID2D1Brush*)(this))
#define ID2D1SolidColorBrush_GetTransform(this,A) (this)->lpVtbl->Base.GetTransform((ID2D1Brush*)(this),A)
#define ID2D1SolidColorBrush_GetColor(this) (this)->lpVtbl->GetColor(this)
#define ID2D1SolidColorBrush_SetColor(this,A) (this)->lpVtbl->SetColor(this,A)

#endif

DEFINE_GUID(IID_ID2D1StrokeStyle, 0x2cd9069d,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1StrokeStyle : public ID2D1Resource {
    STDMETHOD_(D2D1_CAP_STYLE, GetStartCap)(void) const PURE;
    STDMETHOD_(D2D1_CAP_STYLE, GetEndCap)(void) const PURE;
    STDMETHOD_(D2D1_CAP_STYLE, GetDashCap)(void) const PURE;
    STDMETHOD_(FLOAT, GetMiterLimit)(void) const PURE;
    STDMETHOD_(D2D1_LINE_JOIN, GetLineJoin)(void) const PURE;
    STDMETHOD_(FLOAT, GetDashOffset)(void) const PURE;
    STDMETHOD_(D2D1_DASH_STYLE, GetDashStyle)(void) const PURE;
    STDMETHOD_(UINT32, GetDashesCount)(void) const PURE;
    STDMETHOD_(void, GetDashes)(FLOAT *dashes, UINT dashesCount) const PURE;
};

#else

typedef struct ID2D1StrokeStyleVtbl {
    ID2D1ResourceVtbl Base;

    STDMETHOD_(D2D1_CAP_STYLE, GetStartCap)(ID2D1StrokeStyle *This) PURE;
    STDMETHOD_(D2D1_CAP_STYLE, GetEndCap)(ID2D1StrokeStyle *This) PURE;
    STDMETHOD_(D2D1_CAP_STYLE, GetDashCap)(ID2D1StrokeStyle *This) PURE;
    STDMETHOD_(FLOAT, GetMiterLimit)(ID2D1StrokeStyle *This) PURE;
    STDMETHOD_(D2D1_LINE_JOIN, GetLineJoin)(ID2D1StrokeStyle *This) PURE;
    STDMETHOD_(FLOAT, GetDashOffset)(ID2D1StrokeStyle *This) PURE;
    STDMETHOD_(D2D1_DASH_STYLE, GetDashStyle)(ID2D1StrokeStyle *This) PURE;
    STDMETHOD_(UINT32, GetDashesCount)(ID2D1StrokeStyle *This) PURE;
    STDMETHOD_(void, GetDashes)(ID2D1StrokeStyle *This, FLOAT *dashes, UINT dashesCount) PURE;
} ID2D1StrokeStyleVtbl;

interface ID2D1StrokeStyle {
    const ID2D1StrokeStyleVtbl *lpVtbl;
};

#define ID2D1StrokeStyle_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1StrokeStyle_AddRef(this) (this)->lpVtbl->Base.Base.AddRef((IUnknown*)(this))
#define ID2D1StrokeStyle_Release(this) (this)->lpVtbl->Base.Base.Release((IUnknown*)(this))
#define ID2D1StrokeStyle_GetFactory(this,A) (this)->lpVtbl->Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1StrokeStyle_GetDashCap(this) (this)->lpVtbl->GetDashCap(this)
#define ID2D1StrokeStyle_GetDashes(this,A,B) (this)->lpVtbl->GetDashes(this,A,B)
#define ID2D1StrokeStyle_GetDashesCount(this) (this)->lpVtbl->GetDashesCount(this)
#define ID2D1StrokeStyle_GetDashOffset(this) (this)->lpVtbl->GetDashOffset(this)
#define ID2D1StrokeStyle_GetDashStyle(this) (this)->lpVtbl->GetDashStyle(this)
#define ID2D1StrokeStyle_GetEndCap(this) (this)->lpVtbl->GetEndCap(this)
#define ID2D1StrokeStyle_GetLineJoin(this) (this)->lpVtbl->GetLineJoin(this)
#define ID2D1StrokeStyle_GetMiterLimit(this) (this)->lpVtbl->GetMiterLimit(this)
#define ID2D1StrokeStyle_GetStartCap(this) (this)->lpVtbl->GetStartCap(this)

#endif

DEFINE_GUID(IID_ID2D1TessellationSink, 0x2cd906c1,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1TessellationSink : public IUnknown {
    STDMETHOD_(void, AddTriangles)(const D2D1_TRIANGLE *triangles, UINT trianglesCount) PURE;
    STDMETHOD(Close)() PURE;
};

#else

typedef struct ID2D1TessellationSinkVtbl {
    IUnknownVtbl Base;

    STDMETHOD_(void, AddTriangles)(ID2D1TessellationSink *This, const D2D1_TRIANGLE *triangles, UINT trianglesCount) PURE;
    STDMETHOD(Close)(ID2D1TessellationSink *This) PURE;
} ID2D1TessellationSinkVtbl;

interface ID2D1TessellationSink {
    const struct ID2D1TessellationSinkVtbl *lpVtbl;
};

#define ID2D1TessellationSink_QueryInterface(this,A,B) (this)->lpVtbl->Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1TessellationSink_AddRef(this) (this)->lpVtbl->Base.AddRef((IUnknown*)(this))
#define ID2D1TessellationSink_Release(this) (this)->lpVtbl->Base.Release((IUnknown*)(this))
#define ID2D1TessellationSink_AddTriangles(this,A,B) (this)->lpVtbl->AddTriangles(this,A,B)
#define ID2D1TessellationSink_Close(this) (this)->lpVtbl->Close(this)

#endif

DEFINE_GUID(IID_ID2D1TransformedGeometry, 0x2cd906bb,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1TransformedGeometry : public ID2D1Geometry {
    STDMETHOD_(void, GetSourceGeometry)(ID2D1Geometry **sourceGeometry) const PURE;
    STDMETHOD_(void, GetTransform)(D2D1_MATRIX_3X2_F *transform) const PURE;
};

#else

typedef struct ID2D1TransformedGeometryVtbl {
    ID2D1GeometryVtbl Base;

    STDMETHOD_(void, GetSourceGeometry)(ID2D1TransformedGeometry *This, ID2D1Geometry **sourceGeometry) PURE;
    STDMETHOD_(void, GetTransform)(ID2D1TransformedGeometry *This, D2D1_MATRIX_3X2_F *transform) PURE;
} ID2D1TransformedGeometryVtbl;

interface ID2D1TransformedGeometry {
    const ID2D1TransformedGeometryVtbl *lpVtbl;
};

#define ID2D1TransformedGeometry_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.Base.QueryInterface((IUnknown*)(this),A,B)
#define ID2D1TransformedGeometry_AddRef(this) (this)->lpVtbl->Base.Base.Base.AddRef((IUnknown*)(this))
#define ID2D1TransformedGeometry_Release(this) (this)->lpVtbl->Base.Base.Base.Release((IUnknown*)(this))
#define ID2D1TransformedGeometry_GetFactory(this,A) (this)->lpVtbl->Base.Base.GetFactory((ID2D1Resource*)(this),A)
#define ID2D1TransformedGeometry_CombineWithGeometry(this,A,B,C,D) (this)->lpVtbl->Base.CombineWithGeometry((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1TransformedGeometry_CompareWithGeometry(this,A,B,C) (this)->lpVtbl->Base.CompareWithGeometry((ID2D1Geometry*)(this),A,B,C)
#define ID2D1TransformedGeometry_ComputeArea(this,A,B) (this)->lpVtbl->Base.ComputeArea((ID2D1Geometry*)(this),A,B)
#define ID2D1TransformedGeometry_ComputeLength(this,A,B) (this)->lpVtbl->Base.ComputeLength((ID2D1Geometry*)(this),A,B)
#define ID2D1TransformedGeometry_ComputePointAtLength(this,A,B,C,D) (this)->lpVtbl->Base.ComputePointAtLength((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1TransformedGeometry_FillContainsPoint(this,A,B,C) (this)->lpVtbl->Base.FillContainsPoint((ID2D1Geometry*)(this),A,B,C)
#define ID2D1TransformedGeometry_GetBounds(this,A,B) (this)->lpVtbl->Base.GetBounds((ID2D1Geometry*)(this),A,B)
#define ID2D1TransformedGeometry_GetWidenedBounds(this,A,B,C,D) (this)->lpVtbl->Base.GetWidenedBounds((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1TransformedGeometry_Outline(this,A,B) (this)->lpVtbl->Base.Outline((ID2D1Geometry*)(this),A,B)
#define ID2D1TransformedGeometry_StrokeContainsPoint(this,A,B,C,D,E) (this)->lpVtbl->Base.StrokeContainsPoint((ID2D1Geometry*)(this),A,B,C,D,E)
#define ID2D1TransformedGeometry_Simplify(this,A,B,C) (this)->lpVtbl->Base.Simplify((ID2D1Geometry*)(this),A,B,C)
#define ID2D1TransformedGeometry_Tessellate(this,A,B) (this)->lpVtbl->Base.Tessellate((ID2D1Geometry*)(this),A,B)
#define ID2D1TransformedGeometry_Widen(this,A,B,C,D) (this)->lpVtbl->Base.Widen((ID2D1Geometry*)(this),A,B,C,D)
#define ID2D1TransformedGeometry_GetSourceGeometry(this,A) (this)->lpVtbl->GetSourceGeometry(this,A)
#define ID2D1TransformedGeometry_GetTransform(this,A) (this)->lpVtbl->GetTransform(this,A)

#endif

__CRT_UUID_DECL(ID2D1Resource, 0x2cd90691,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1Brush, 0x2cd906a8,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1Bitmap, 0xa2296057,0xea42,0x4099,0x98,0x3b,0x53,0x9f,0xb6,0x50,0x54,0x26)
__CRT_UUID_DECL(ID2D1BitmapBrush, 0x2cd906aa,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1RenderTarget, 0x2cd90694,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1Geometry, 0x2cd906a1,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1BitmapRenderTarget, 0x2cd90695,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1DCRenderTarget, 0x1c51bc64,0xde61,0x46fd,0x98,0x99,0x63,0xa5,0xd8,0xf0,0x39,0x50)
__CRT_UUID_DECL(ID2D1SimplifiedGeometrySink, 0x2cd9069e,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1Factory, 0x06152247,0x6f50,0x465a,0x92,0x45,0x11,0x8b,0xfd,0x3b,0x60,0x07)
__CRT_UUID_DECL(ID2D1GdiInteropRenderTarget, 0xe0db51c3,0x6f77,0x4bae,0xb3,0xd5,0xe4,0x75,0x09,0xb3,0x58,0x38)
__CRT_UUID_DECL(ID2D1GeometrySink, 0x2cd9069f,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1GradientStopCollection, 0x2cd906a7,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1Layer, 0x2cd9069b,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1LinearGradientBrush, 0x2cd906ab,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1PathGeometry, 0x2cd906a5,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1RadialGradientBrush, 0x2cd906ac,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1RectangleGeometry, 0x2cd906a2,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1SolidColorBrush, 0x2cd906a9,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1StrokeStyle, 0x2cd9069d,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1TransformedGeometry, 0x2cd906bb,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9)
__CRT_UUID_DECL(ID2D1Mesh,0x2cd906c2,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);
__CRT_UUID_DECL(ID2D1DrawingStateBlock, 0x28506e39,0xebf6,0x46a1,0xbb,0x47,0xfd,0x85,0x56,0x5a,0xb9,0x57);
__CRT_UUID_DECL(ID2D1EllipseGeometry, 0x2cd906a4,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);
__CRT_UUID_DECL(ID2D1GeometryGroup, 0x2cd906a6,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);
__CRT_UUID_DECL(ID2D1RoundedRectangleGeometry, 0x2cd906a3,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);
__CRT_UUID_DECL(ID2D1TessellationSink, 0x2cd906c1,0x12e2,0x11dc,0x9f,0xed,0x00,0x11,0x43,0xa0,0x55,0xf9);
__CRT_UUID_DECL(ID2D1Image, 0x65019f75,0x8da2,0x497c,0xb3,0x2c,0xdf,0xa3,0x4e,0x48,0xed,0xe6);

#ifdef __cplusplus
extern "C" {
#endif

HRESULT WINAPI D2D1CreateFactory(
  D2D1_FACTORY_TYPE factoryType,
  REFIID riid,
  const D2D1_FACTORY_OPTIONS *pFactoryOptions,
  void **ppIFactory
);

WINBOOL WINAPI D2D1InvertMatrix(
  D2D1_MATRIX_3X2_F *matrix
);

WINBOOL WINAPI D2D1IsMatrixInvertible(
  const D2D1_MATRIX_3X2_F *matrix
);

void WINAPI D2D1MakeRotateMatrix(
  FLOAT angle,
  D2D1_POINT_2F center,
  D2D1_MATRIX_3X2_F *matrix
);

void WINAPI D2D1MakeSkewMatrix(
  FLOAT angleX,
  FLOAT angleY,
  D2D1_POINT_2F center,
  D2D1_MATRIX_3X2_F *matrix
);
#ifdef __cplusplus
}
#endif

#ifndef D2D1FORCEINLINE
#define D2D1FORCEINLINE FORCEINLINE
#endif

#include <d2d1helper.h>

#ifndef D2D_USE_C_DEFINITIONS

inline HRESULT D2D1CreateFactory(D2D1_FACTORY_TYPE factoryType, REFIID riid, void **ppv) {
    return D2D1CreateFactory(factoryType, riid, NULL, ppv);
}

template<class Factory>
HRESULT D2D1CreateFactory(D2D1_FACTORY_TYPE factoryType, Factory **factory) {
    return D2D1CreateFactory(factoryType, __uuidof(Factory), reinterpret_cast<void**>(factory));
}

template<class Factory>
HRESULT D2D1CreateFactory(D2D1_FACTORY_TYPE factoryType, const D2D1_FACTORY_OPTIONS &factoryOptions, Factory **factory) {
    return D2D1CreateFactory(factoryType, __uuidof(Factory), &factoryOptions, reinterpret_cast<void **>(factory));
}

#endif

#endif /* _D2D1_H */
