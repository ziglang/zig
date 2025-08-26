/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _D2D1_1_H_
#define _D2D1_1_H_

#include <d2d1.h>
#include <d2d1effects.h>
#include <dxgi.h>

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)

typedef interface ID2D1ColorContext ID2D1ColorContext;
typedef interface IWICColorContext IWICColorContext;
typedef interface IWICImagingFactory IWICImagingFactory;
typedef interface IPrintDocumentPackageTarget IPrintDocumentPackageTarget;
typedef interface IDWriteFactory IDWriteFactory;

typedef struct D2D1_PROPERTY_BINDING D2D1_PROPERTY_BINDING;

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1Device;
interface ID2D1Effect;
#else
typedef interface ID2D1Device ID2D1Device;
typedef interface ID2D1Effect ID2D1Effect;
#endif

typedef struct DWRITE_GLYPH_RUN_DESCRIPTION DWRITE_GLYPH_RUN_DESCRIPTION;

typedef HRESULT (CALLBACK *PD2D1_EFFECT_FACTORY)(IUnknown**);

typedef D2D_RECT_L D2D1_RECT_L;

typedef enum D2D1_PROPERTY_TYPE {
    D2D1_PROPERTY_TYPE_UNKNOWN       = 0,
    D2D1_PROPERTY_TYPE_STRING        = 1,
    D2D1_PROPERTY_TYPE_BOOL          = 2,
    D2D1_PROPERTY_TYPE_UINT32        = 3,
    D2D1_PROPERTY_TYPE_INT32         = 4,
    D2D1_PROPERTY_TYPE_FLOAT         = 5,
    D2D1_PROPERTY_TYPE_VECTOR2       = 6,
    D2D1_PROPERTY_TYPE_VECTOR3       = 7,
    D2D1_PROPERTY_TYPE_VECTOR4       = 8,
    D2D1_PROPERTY_TYPE_BLOB          = 9,
    D2D1_PROPERTY_TYPE_IUNKNOWN      = 10,
    D2D1_PROPERTY_TYPE_ENUM          = 11,
    D2D1_PROPERTY_TYPE_ARRAY         = 12,
    D2D1_PROPERTY_TYPE_CLSID         = 13,
    D2D1_PROPERTY_TYPE_MATRIX_3X2    = 14,
    D2D1_PROPERTY_TYPE_MATRIX_4X3    = 15,
    D2D1_PROPERTY_TYPE_MATRIX_4X4    = 16,
    D2D1_PROPERTY_TYPE_MATRIX_5X4    = 17,
    D2D1_PROPERTY_TYPE_COLOR_CONTEXT = 18,
    D2D1_PROPERTY_TYPE_FORCE_DWORD   = 0xffffffff
} D2D1_PROPERTY_TYPE;

typedef enum D2D1_PROPERTY {
    D2D1_PROPERTY_CLSID       = 0x80000000,
    D2D1_PROPERTY_DISPLAYNAME = 0x80000001,
    D2D1_PROPERTY_AUTHOR      = 0x80000002,
    D2D1_PROPERTY_CATEGORY    = 0x80000003,
    D2D1_PROPERTY_DESCRIPTION = 0x80000004,
    D2D1_PROPERTY_INPUTS      = 0x80000005,
    D2D1_PROPERTY_CACHED      = 0x80000006,
    D2D1_PROPERTY_PRECISION   = 0x80000007,
    D2D1_PROPERTY_MIN_INPUTS  = 0x80000008,
    D2D1_PROPERTY_MAX_INPUTS  = 0x80000009,
    D2D1_PROPERTY_FORCE_DWORD = 0xffffffff
} D2D1_PROPERTY;

typedef enum D2D1_SUBPROPERTY {
    D2D1_SUBPROPERTY_DISPLAYNAME = 0x80000000,
    D2D1_SUBPROPERTY_ISREADONLY  = 0x80000001,
    D2D1_SUBPROPERTY_MIN         = 0x80000002,
    D2D1_SUBPROPERTY_MAX         = 0x80000003,
    D2D1_SUBPROPERTY_DEFAULT     = 0x80000004,
    D2D1_SUBPROPERTY_FIELDS      = 0x80000005,
    D2D1_SUBPROPERTY_INDEX       = 0x80000006,
    D2D1_SUBPROPERTY_FORCE_DWORD = 0xffffffff
} D2D1_SUBPROPERTY;

typedef enum D2D1_CHANNEL_DEPTH {
    D2D1_CHANNEL_DEPTH_DEFAULT = 0,
    D2D1_CHANNEL_DEPTH_1       = 1,
    D2D1_CHANNEL_DEPTH_4       = 4,
    D2D1_CHANNEL_DEPTH_FORCE_DWORD = 0xffffffff
} D2D1_CHANNEL_DEPTH;

typedef enum D2D1_BUFFER_PRECISION {
    D2D1_BUFFER_PRECISION_UNKNOWN         = 0,
    D2D1_BUFFER_PRECISION_8BPC_UNORM      = 1,
    D2D1_BUFFER_PRECISION_8BPC_UNORM_SRGB = 2,
    D2D1_BUFFER_PRECISION_16BPC_UNORM     = 3,
    D2D1_BUFFER_PRECISION_16BPC_FLOAT     = 4,
    D2D1_BUFFER_PRECISION_32BPC_FLOAT     = 5,
    D2D1_BUFFER_PRECISION_FORCE_DWORD     = 0xffffffff
} D2D1_BUFFER_PRECISION;

typedef enum D2D1_COLOR_SPACE {
    D2D1_COLOR_SPACE_CUSTOM = 0,
    D2D1_COLOR_SPACE_SRGB   = 1,
    D2D1_COLOR_SPACE_SCRGB  = 2,
    D2D1_COLOR_SPACE_FORCE_DWORD = 0xffffffff
} D2D1_COLOR_SPACE;

typedef enum D2D1_DEVICE_CONTEXT_OPTIONS {
    D2D1_DEVICE_CONTEXT_OPTIONS_NONE                               = 0,
    D2D1_DEVICE_CONTEXT_OPTIONS_ENABLE_MULTITHREADED_OPTIMIZATIONS = 1,
    D2D1_DEVICE_CONTEXT_OPTIONS_FORCE_DWORD = 0xffffffff
} D2D1_DEVICE_CONTEXT_OPTIONS;

DEFINE_ENUM_FLAG_OPERATORS(D2D1_DEVICE_CONTEXT_OPTIONS);

typedef enum D2D1_BITMAP_OPTIONS {
    D2D1_BITMAP_OPTIONS_NONE           = 0x00000000,
    D2D1_BITMAP_OPTIONS_TARGET         = 0x00000001,
    D2D1_BITMAP_OPTIONS_CANNOT_DRAW    = 0x00000002,
    D2D1_BITMAP_OPTIONS_CPU_READ       = 0x00000004,
    D2D1_BITMAP_OPTIONS_GDI_COMPATIBLE = 0x00000008,
    D2D1_BITMAP_OPTIONS_FORCE_DWORD = 0xffffffff
} D2D1_BITMAP_OPTIONS;

DEFINE_ENUM_FLAG_OPERATORS(D2D1_BITMAP_OPTIONS);

typedef enum D2D1_MAP_OPTIONS {
    D2D1_MAP_OPTIONS_NONE    = 0,
    D2D1_MAP_OPTIONS_READ    = 1,
    D2D1_MAP_OPTIONS_WRITE   = 2,
    D2D1_MAP_OPTIONS_DISCARD = 4,
    D2D1_MAP_OPTIONS_FORCE_DWORD = 0xffffffff
} D2D1_MAP_OPTIONS;

DEFINE_ENUM_FLAG_OPERATORS(D2D1_MAP_OPTIONS);

typedef enum D2D1_COLOR_INTERPOLATION_MODE {
    D2D1_COLOR_INTERPOLATION_MODE_STRAIGHT      = 0,
    D2D1_COLOR_INTERPOLATION_MODE_PREMULTIPLIED = 1,
    D2D1_COLOR_INTERPOLATION_MODE_FORCE_DWORD = 0xffffffff
} D2D1_COLOR_INTERPOLATION_MODE;

typedef enum D2D1_INTERPOLATION_MODE {
    D2D1_INTERPOLATION_MODE_NEAREST_NEIGHBOR    = D2D1_INTERPOLATION_MODE_DEFINITION_NEAREST_NEIGHBOR,
    D2D1_INTERPOLATION_MODE_LINEAR              = D2D1_INTERPOLATION_MODE_DEFINITION_LINEAR,
    D2D1_INTERPOLATION_MODE_CUBIC               = D2D1_INTERPOLATION_MODE_DEFINITION_CUBIC,
    D2D1_INTERPOLATION_MODE_MULTI_SAMPLE_LINEAR = D2D1_INTERPOLATION_MODE_DEFINITION_MULTI_SAMPLE_LINEAR,
    D2D1_INTERPOLATION_MODE_ANISOTROPIC         = D2D1_INTERPOLATION_MODE_DEFINITION_ANISOTROPIC,
    D2D1_INTERPOLATION_MODE_HIGH_QUALITY_CUBIC  = D2D1_INTERPOLATION_MODE_DEFINITION_HIGH_QUALITY_CUBIC,
    D2D1_INTERPOLATION_MODE_FORCE_DWORD = 0xffffffff
} D2D1_INTERPOLATION_MODE;

typedef enum D2D1_COMPOSITE_MODE {
    D2D1_COMPOSITE_MODE_SOURCE_OVER         = 0,
    D2D1_COMPOSITE_MODE_DESTINATION_OVER    = 1,
    D2D1_COMPOSITE_MODE_SOURCE_IN           = 2,
    D2D1_COMPOSITE_MODE_DESTINATION_IN      = 3,
    D2D1_COMPOSITE_MODE_SOURCE_OUT          = 4,
    D2D1_COMPOSITE_MODE_DESTINATION_OUT     = 5,
    D2D1_COMPOSITE_MODE_SOURCE_ATOP         = 6,
    D2D1_COMPOSITE_MODE_DESTINATION_ATOP    = 7,
    D2D1_COMPOSITE_MODE_XOR                 = 8,
    D2D1_COMPOSITE_MODE_PLUS                = 9,
    D2D1_COMPOSITE_MODE_SOURCE_COPY         = 10,
    D2D1_COMPOSITE_MODE_BOUNDED_SOURCE_COPY = 11,
    D2D1_COMPOSITE_MODE_MASK_INVERT         = 12,
    D2D1_COMPOSITE_MODE_FORCE_DWORD = 0xffffffff
} D2D1_COMPOSITE_MODE;

typedef enum D2D1_PRIMITIVE_BLEND {
    D2D1_PRIMITIVE_BLEND_SOURCE_OVER = 0,
    D2D1_PRIMITIVE_BLEND_COPY        = 1,
    D2D1_PRIMITIVE_BLEND_MIN         = 2,
    D2D1_PRIMITIVE_BLEND_ADD         = 3,
    D2D1_PRIMITIVE_BLEND_FORCE_DWORD = 0xffffffff
} D2D1_PRIMITIVE_BLEND;

typedef enum D2D1_THREADING_MODE {
    D2D1_THREADING_MODE_SINGLE_THREADED = D2D1_FACTORY_TYPE_SINGLE_THREADED,
    D2D1_THREADING_MODE_MULTI_THREADED  = D2D1_FACTORY_TYPE_MULTI_THREADED,
    D2D1_THREADING_MODE_FORCE_DWORD     = 0xffffffff
} D2D1_THREADING_MODE;

typedef enum D2D1_UNIT_MODE {
    D2D1_UNIT_MODE_DIPS   = 0,
    D2D1_UNIT_MODE_PIXELS = 1,
    D2D1_UNIT_MODE_FORCE_DWORD = 0xffffffff
} D2D1_UNIT_MODE;

typedef enum D2D1_LAYER_OPTIONS1 {
    D2D1_LAYER_OPTIONS1_NONE                       = 0,
    D2D1_LAYER_OPTIONS1_INITIALIZE_FROM_BACKGROUND = 1,
    D2D1_LAYER_OPTIONS1_IGNORE_ALPHA               = 2,
    D2D1_LAYER_OPTIONS1_FORCE_DWORD = 0xffffffff
} D2D1_LAYER_OPTIONS1;

DEFINE_ENUM_FLAG_OPERATORS(D2D1_LAYER_OPTIONS1);

typedef enum D2D1_PRINT_FONT_SUBSET_MODE {
    D2D1_PRINT_FONT_SUBSET_MODE_DEFAULT  = 0,
    D2D1_PRINT_FONT_SUBSET_MODE_EACHPAGE = 1,
    D2D1_PRINT_FONT_SUBSET_MODE_NONE     = 2,
    D2D1_PRINT_FONT_SUBSET_MODE_FORCE_DWORD = 0xffffffff
} D2D1_PRINT_FONT_SUBSET_MODE;

typedef enum D2D1_STROKE_TRANSFORM_TYPE {
    D2D1_STROKE_TRANSFORM_TYPE_NORMAL   = 0,
    D2D1_STROKE_TRANSFORM_TYPE_FIXED    = 1,
    D2D1_STROKE_TRANSFORM_TYPE_HAIRLINE = 2,
    D2D1_STROKE_TRANSFORM_TYPE_FORCE_DWORD = 0xffffffff
} D2D1_STROKE_TRANSFORM_TYPE;

typedef struct D2D1_BITMAP_PROPERTIES1 {
    D2D1_PIXEL_FORMAT pixelFormat;
    FLOAT dpiX;
    FLOAT dpiY;
    D2D1_BITMAP_OPTIONS bitmapOptions;
    ID2D1ColorContext *colorContext;
} D2D1_BITMAP_PROPERTIES1;

typedef struct D2D1_MAPPED_RECT {
    UINT32 pitch;
    BYTE *bits;
} D2D1_MAPPED_RECT;

typedef struct D2D1_IMAGE_BRUSH_PROPERTIES {
    D2D1_RECT_F sourceRectangle;
    D2D1_EXTEND_MODE extendModeX;
    D2D1_EXTEND_MODE extendModeY;
    D2D1_INTERPOLATION_MODE interpolationMode;
} D2D1_IMAGE_BRUSH_PROPERTIES;

typedef struct D2D1_BITMAP_BRUSH_PROPERTIES1 {
    D2D1_EXTEND_MODE extendModeX;
    D2D1_EXTEND_MODE extendModeY;
    D2D1_INTERPOLATION_MODE interpolationMode;
} D2D1_BITMAP_BRUSH_PROPERTIES1;

typedef D2D_MATRIX_4X3_F D2D1_MATRIX_4X3_F;
typedef D2D_MATRIX_4X4_F D2D1_MATRIX_4X4_F;
typedef D2D_MATRIX_5X4_F D2D1_MATRIX_5X4_F;
typedef D2D_VECTOR_2F D2D1_VECTOR_2F;
typedef D2D_VECTOR_3F D2D1_VECTOR_3F;
typedef D2D_VECTOR_4F D2D1_VECTOR_4F;

typedef struct D2D1_LAYER_PARAMETERS1 {
    D2D1_RECT_F contentBounds;
    ID2D1Geometry *geometricMask;
    D2D1_ANTIALIAS_MODE maskAntialiasMode;
    D2D1_MATRIX_3X2_F maskTransform;
    FLOAT opacity;
    ID2D1Brush *opacityBrush;
    D2D1_LAYER_OPTIONS1 layerOptions;
} D2D1_LAYER_PARAMETERS1;

typedef struct D2D1_RENDERING_CONTROLS {
    D2D1_BUFFER_PRECISION bufferPrecision;
    D2D1_SIZE_U tileSize;
} D2D1_RENDERING_CONTROLS;

typedef struct D2D1_EFFECT_INPUT_DESCRIPTION {
    ID2D1Effect *effect;
    UINT32 inputIndex;
    D2D1_RECT_F inputRectangle;
} D2D1_EFFECT_INPUT_DESCRIPTION;

typedef struct D2D1_PRINT_CONTROL_PROPERTIES {
    D2D1_PRINT_FONT_SUBSET_MODE fontSubset;
    FLOAT rasterDPI;
    D2D1_COLOR_SPACE colorSpace;
} D2D1_PRINT_CONTROL_PROPERTIES;

typedef struct D2D1_CREATION_PROPERTIES {
    D2D1_THREADING_MODE threadingMode;
    D2D1_DEBUG_LEVEL debugLevel;
    D2D1_DEVICE_CONTEXT_OPTIONS options;
} D2D1_CREATION_PROPERTIES;

typedef struct D2D1_STROKE_STYLE_PROPERTIES1 {
    D2D1_CAP_STYLE startCap;
    D2D1_CAP_STYLE endCap;
    D2D1_CAP_STYLE dashCap;
    D2D1_LINE_JOIN lineJoin;
    FLOAT miterLimit;
    D2D1_DASH_STYLE dashStyle;
    FLOAT dashOffset;
    D2D1_STROKE_TRANSFORM_TYPE transformType;
} D2D1_STROKE_STYLE_PROPERTIES1;

typedef struct D2D1_DRAWING_STATE_DESCRIPTION1 {
    D2D1_ANTIALIAS_MODE antialiasMode;
    D2D1_TEXT_ANTIALIAS_MODE textAntialiasMode;
    D2D1_TAG tag1;
    D2D1_TAG tag2;
    D2D1_MATRIX_3X2_F transform;
    D2D1_PRIMITIVE_BLEND primitiveBlend;
    D2D1_UNIT_MODE unitMode;
} D2D1_DRAWING_STATE_DESCRIPTION1;

typedef struct D2D1_POINT_DESCRIPTION {
    D2D1_POINT_2F point;
    D2D1_POINT_2F unitTangentVector;
    UINT32 endSegment;
    UINT32 endFigure;
    FLOAT lengthToEndSegment;
} D2D1_POINT_DESCRIPTION;

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1Properties : public IUnknown
{
    STDMETHOD_(UINT32, GetPropertyCount)() CONST PURE;
    STDMETHOD(GetPropertyName)(UINT32 index, PWSTR name, UINT32 nameCount) CONST PURE;
    STDMETHOD_(UINT32, GetPropertyNameLength)(UINT32 index) CONST PURE;
    STDMETHOD_(D2D1_PROPERTY_TYPE, GetType)(UINT32 index) CONST PURE;
    STDMETHOD_(UINT32, GetPropertyIndex)(PCWSTR name) CONST PURE;
    STDMETHOD(SetValueByName)(PCWSTR name, D2D1_PROPERTY_TYPE type, CONST BYTE *data, UINT32 dataSize) PURE;
    STDMETHOD(SetValue)(UINT32 index, D2D1_PROPERTY_TYPE type, CONST BYTE *data, UINT32 dataSize) PURE;
    STDMETHOD(GetValueByName)(PCWSTR name, D2D1_PROPERTY_TYPE type, BYTE *data, UINT32 dataSize) CONST PURE;
    STDMETHOD(GetValue)(UINT32 index, D2D1_PROPERTY_TYPE type, BYTE *data, UINT32 dataSize) CONST PURE;
    STDMETHOD_(UINT32, GetValueSize)(UINT32 index) CONST PURE;
    STDMETHOD(GetSubProperties)(UINT32 index, ID2D1Properties **subProperties) CONST PURE;

    HRESULT SetValueByName(PCWSTR name, CONST BYTE *data, UINT32 dataSize) {
        return SetValueByName(name, D2D1_PROPERTY_TYPE_UNKNOWN, data, dataSize);
    }

    HRESULT SetValue(UINT32 index, CONST BYTE *data, UINT32 dataSize) {
        return SetValue(index, D2D1_PROPERTY_TYPE_UNKNOWN, data, dataSize);
    }

    HRESULT GetValueByName(PCWSTR name, BYTE *data, UINT32 dataSize) CONST {
        return GetValueByName(name, D2D1_PROPERTY_TYPE_UNKNOWN, data, dataSize);
    }

    HRESULT GetValue(UINT32 index, BYTE *data, UINT32 dataSize) CONST {
        return GetValue(index, D2D1_PROPERTY_TYPE_UNKNOWN, data, dataSize);
    }

    template<typename T>
    HRESULT GetValueByName(PCWSTR propertyName, T *value) const {
        return GetValueByName(propertyName, reinterpret_cast<BYTE*>(value), sizeof(*value));
    }

    template<typename T>
    T GetValueByName(PCWSTR propertyName) const {
        T ret;
        GetValueByName(propertyName, reinterpret_cast<BYTE*>(&ret), sizeof(ret));
        return ret;
    }

    template<typename T>
    HRESULT SetValueByName(PCWSTR propertyName, const T &value) {
        return SetValueByName(propertyName, reinterpret_cast<const BYTE*>(&value), sizeof(value));
    }

    template<typename T>
    HRESULT GetValue(T index, BYTE *data, UINT32 dataSize) CONST {
        return GetValue(static_cast<UINT32>(index), data, dataSize);
    }

    template<typename T, typename U>
    HRESULT GetValue(U index, T *value) const {
        return GetValue(static_cast<UINT32>(index), reinterpret_cast<BYTE*>(value), sizeof(*value));
    }

    template<typename T, typename U>
    T GetValue(U index) const {
        T ret;
        GetValue(static_cast<UINT32>(index), reinterpret_cast<BYTE*>(&ret), sizeof(ret));
        return ret;
    }

    template<typename T>
    HRESULT SetValue(T index, CONST BYTE *data, UINT32 dataSize) {
        return SetValue(static_cast<UINT32>(index), data, dataSize);
    }

    template<typename T, typename U>
    HRESULT SetValue(U index, const T &value) {
        return SetValue(static_cast<UINT32>(index), reinterpret_cast<const BYTE*>(&value), sizeof(value));
    }

    template<typename T>
    HRESULT GetPropertyName(T index, PWSTR name, UINT32 nameCount) CONST {
        return GetPropertyName(static_cast<UINT32>(index), name, nameCount);
    }

    template<typename T>
    UINT32 GetPropertyNameLength(T index) CONST {
        return GetPropertyNameLength(static_cast<UINT32>(index));
    }

    template<typename T>
    D2D1_PROPERTY_TYPE GetType(T index) CONST {
        return GetType(static_cast<UINT32>(index));
    }

    template<typename T>
    UINT32 GetValueSize(T index) CONST {
        return GetValueSize(static_cast<UINT32>(index));
    }

    template<typename T>
    HRESULT GetSubProperties(T index, ID2D1Properties **subProperties) CONST {
        return GetSubProperties(static_cast<UINT32>(index), subProperties);
    }
};

#else

typedef interface ID2D1Properties ID2D1Properties;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1Properties,0x483473d7,0xcd46,0x4f9d,0x9d,0x3a,0x31,0x12,0xaa,0x80,0x15,0x9d);
__CRT_UUID_DECL(ID2D1Properties,0x483473d7,0xcd46,0x4f9d,0x9d,0x3a,0x31,0x12,0xaa,0x80,0x15,0x9d);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1GdiMetafileSink : public IUnknown
{
    STDMETHOD(ProcessRecord)(DWORD recordType, CONST void *recordData, DWORD recordDataSize) PURE;
};

#else

typedef interface ID2D1GdiMetafileSink ID2D1GdiMetafileSink;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1GdiMetafileSink, 0x82237326,0x8111,0x4f7c,0xbc,0xf4,0xb5,0xc1,0x17,0x55,0x64,0xfe);
__CRT_UUID_DECL(ID2D1GdiMetafileSink, 0x82237326,0x8111,0x4f7c,0xbc,0xf4,0xb5,0xc1,0x17,0x55,0x64,0xfe);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1GdiMetafile : public ID2D1Resource
{
    STDMETHOD(Stream)(ID2D1GdiMetafileSink *sink) PURE;
    STDMETHOD(GetBounds)(D2D1_RECT_F *bounds) PURE;
};

#else

typedef interface ID2D1GdiMetafile ID2D1GdiMetafile;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1GdiMetafile, 0x2f543dc3,0xcfc1,0x4211,0x86,0x4f,0xcf,0xd9,0x1c,0x6f,0x33,0x95);
__CRT_UUID_DECL(ID2D1GdiMetafile, 0x2f543dc3,0xcfc1,0x4211,0x86,0x4f,0xcf,0xd9,0x1c,0x6f,0x33,0x95);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1StrokeStyle1 : public ID2D1StrokeStyle
{
    STDMETHOD_(D2D1_STROKE_TRANSFORM_TYPE, GetStrokeTransformType)() CONST PURE;
};

#else

typedef interface ID2D1StrokeStyle1 ID2D1StrokeStyle1;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1StrokeStyle1, 0x10a72a66,0xe91c,0x43f4,0x99,0x3f,0xdd,0xf4,0xb8,0x2b,0x0b,0x4a);
__CRT_UUID_DECL(ID2D1StrokeStyle1, 0x10a72a66,0xe91c,0x43f4,0x99,0x3f,0xdd,0xf4,0xb8,0x2b,0x0b,0x4a);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1CommandSink : public IUnknown
{
    STDMETHOD(BeginDraw)() PURE;
    STDMETHOD(EndDraw)() PURE;
    STDMETHOD(SetAntialiasMode)(D2D1_ANTIALIAS_MODE antialiasMode) PURE;
    STDMETHOD(SetTags)(D2D1_TAG tag1, D2D1_TAG tag2) PURE;
    STDMETHOD(SetTextAntialiasMode)(D2D1_TEXT_ANTIALIAS_MODE textAntialiasMode) PURE;
    STDMETHOD(SetTextRenderingParams)(IDWriteRenderingParams *textRenderingParams) PURE;
    STDMETHOD(SetTransform)(CONST D2D1_MATRIX_3X2_F *transform) PURE;
    STDMETHOD(SetPrimitiveBlend)(D2D1_PRIMITIVE_BLEND primitiveBlend) PURE;
    STDMETHOD(SetUnitMode)(D2D1_UNIT_MODE unitMode) PURE;
    STDMETHOD(Clear)(CONST D2D1_COLOR_F *color) PURE;
    STDMETHOD(DrawGlyphRun)(D2D1_POINT_2F baselineOrigin, CONST DWRITE_GLYPH_RUN *glyphRun,
            CONST DWRITE_GLYPH_RUN_DESCRIPTION *glyphRunDescription, ID2D1Brush *foregroundBrush,
            DWRITE_MEASURING_MODE measuringMode) PURE;
    STDMETHOD(DrawLine)(D2D1_POINT_2F point0, D2D1_POINT_2F point1, ID2D1Brush *brush, FLOAT strokeWidth,
            ID2D1StrokeStyle *strokeStyle) PURE;
    STDMETHOD(DrawGeometry)(ID2D1Geometry *geometry, ID2D1Brush *brush, FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle) PURE;
    STDMETHOD(DrawRectangle)(CONST D2D1_RECT_F *rect, ID2D1Brush *brush, FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle) PURE;
    STDMETHOD(DrawBitmap)(ID2D1Bitmap *bitmap, CONST D2D1_RECT_F *destinationRectangle, FLOAT opacity,
            D2D1_INTERPOLATION_MODE interpolationMode, CONST D2D1_RECT_F *sourceRectangle,
            CONST D2D1_MATRIX_4X4_F *perspectiveTransform) PURE;
    STDMETHOD(DrawImage)(ID2D1Image *image, CONST D2D1_POINT_2F *targetOffset, CONST D2D1_RECT_F *imageRectangle,
            D2D1_INTERPOLATION_MODE interpolationMode, D2D1_COMPOSITE_MODE compositeMode) PURE;
    STDMETHOD(DrawGdiMetafile)(ID2D1GdiMetafile *gdiMetafile, CONST D2D1_POINT_2F *targetOffset) PURE;
    STDMETHOD(FillMesh)(ID2D1Mesh *mesh, ID2D1Brush *brush) PURE;
    STDMETHOD(FillOpacityMask)(ID2D1Bitmap *opacityMask, ID2D1Brush *brush, CONST D2D1_RECT_F *destinationRectangle,
            CONST D2D1_RECT_F *sourceRectangle) PURE;
    STDMETHOD(FillGeometry)(ID2D1Geometry *geometry, ID2D1Brush *brush, ID2D1Brush *opacityBrush) PURE;
    STDMETHOD(FillRectangle)(CONST D2D1_RECT_F *rect, ID2D1Brush *brush) PURE;
    STDMETHOD(PushAxisAlignedClip)(CONST D2D1_RECT_F *clipRect, D2D1_ANTIALIAS_MODE antialiasMode) PURE;
    STDMETHOD(PushLayer)(CONST D2D1_LAYER_PARAMETERS1 *layerParameters1, ID2D1Layer *layer) PURE;
    STDMETHOD(PopAxisAlignedClip)() PURE;
    STDMETHOD(PopLayer)() PURE;
};

#else

typedef interface ID2D1CommandSink ID2D1CommandSink;

#endif

DEFINE_GUID(IID_ID2D1CommandSink, 0x54d7898a,0xa061,0x40a7,0xbe,0xc7,0xe4,0x65,0xbc,0xba,0x2c,0x4f);
__CRT_UUID_DECL(ID2D1CommandSink, 0x54d7898a,0xa061,0x40a7,0xbe,0xc7,0xe4,0x65,0xbc,0xba,0x2c,0x4f);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1CommandList : public ID2D1Image
{
    STDMETHOD(Stream)(ID2D1CommandSink *sink) PURE;
    STDMETHOD(Close)() PURE;
};

#else

typedef interface ID2D1CommandList ID2D1CommandList;

#endif

DEFINE_GUID(IID_ID2D1CommandList, 0xb4f34a19,0x2383,0x4d76,0x94,0xf6,0xec,0x34,0x36,0x57,0xc3,0xdc);
__CRT_UUID_DECL(ID2D1CommandList, 0xb4f34a19,0x2383,0x4d76,0x94,0xf6,0xec,0x34,0x36,0x57,0xc3,0xdc);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1PrintControl : public IUnknown
{
    STDMETHOD(AddPage)(ID2D1CommandList *commandList, D2D_SIZE_F pageSize, IStream *pagePrintTicketStream,
            D2D1_TAG *tag1 = NULL, D2D1_TAG *tag2 = NULL) PURE;
    STDMETHOD(Close)() PURE;
};

#else

typedef interface ID2D1PrintControl ID2D1PrintControl;

#endif

DEFINE_GUID(IID_ID2D1PrintControl, 0x2c1d867d,0xc290,0x41c8,0xae,0x7e,0x34,0xa9,0x87,0x02,0xe9,0xa5);
__CRT_UUID_DECL(ID2D1PrintControl, 0x2c1d867d,0xc290,0x41c8,0xae,0x7e,0x34,0xa9,0x87,0x02,0xe9,0xa5);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1Effect : public ID2D1Properties
{
    STDMETHOD_(void, SetInput)(UINT32 index, ID2D1Image *input, BOOL invalidate=TRUE) PURE;
    STDMETHOD(SetInputCount)(UINT32 inputCount) PURE;
    STDMETHOD_(void, GetInput)(UINT32 index, ID2D1Image **input) CONST PURE;
    STDMETHOD_(UINT32, GetInputCount)() CONST PURE;
    STDMETHOD_(void, GetOutput)(ID2D1Image **outputImage) CONST PURE;

    void SetInputEffect(UINT32 index, ID2D1Effect *inputEffect, BOOL invalidate=TRUE) {
        ID2D1Image *output = NULL;
        if(inputEffect)
            inputEffect->GetOutput(&output);
        SetInput(index, output, invalidate);
        if(output)
            output->Release();
    }
};

#else

typedef interface ID2D1Effect ID2D1Effect;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1Effect,0x28211a43,0x7d89,0x476f,0x81,0x81,0x2d,0x61,0x59,0xb2,0x20,0xad);
__CRT_UUID_DECL(ID2D1Effect,0x28211a43,0x7d89,0x476f,0x81,0x81,0x2d,0x61,0x59,0xb2,0x20,0xad);

#endif

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1Bitmap1 : public ID2D1Bitmap
{
    STDMETHOD_(void, GetColorContext)(ID2D1ColorContext **colorContext) CONST PURE;
    STDMETHOD_(D2D1_BITMAP_OPTIONS, GetOptions)() CONST PURE;
    STDMETHOD(GetSurface)(IDXGISurface **dxgiSurface) CONST PURE;
    STDMETHOD(Map)(D2D1_MAP_OPTIONS options, D2D1_MAPPED_RECT *mappedRect) PURE;
    STDMETHOD(Unmap)() PURE;
};

#else

typedef interface ID2D1Bitmap1 ID2D1Bitmap1;

typedef struct ID2D1Bitmap1Vtbl {
    ID2D1BitmapVtbl Base;

    STDMETHOD_(void, GetColorContext)(ID2D1Bitmap1 *This, ID2D1ColorContext **colorContext) PURE;
    STDMETHOD_(D2D1_BITMAP_OPTIONS, GetOptions)(ID2D1Bitmap1 *This) PURE;
    STDMETHOD(GetSurface)(ID2D1Bitmap1 *This, IDXGISurface **dxgiSurface) PURE;
    STDMETHOD(Map)(ID2D1Bitmap1 *This, D2D1_MAP_OPTIONS options, D2D1_MAPPED_RECT *mappedRect) PURE;
    STDMETHOD(Unmap)(ID2D1Bitmap1 *This) PURE;
}
ID2D1Bitmap1Vtbl;

interface ID2D1Bitmap1 {
    const ID2D1Bitmap1Vtbl *lpVtbl;
};

/*** IUnknown methods ***/
#define ID2D1Bitmap1_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ID2D1Bitmap1_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ID2D1Bitmap1_Release(This) (This)->lpVtbl->Release(This)
/*** ID2D1Resource methods ***/
#define ID2D1Bitmap1_GetFactory(This,factory) (This)->lpVtbl->GetFactory(This,factory)
/*** ID2D1Bitmap methods ***/
#define ID2D1Bitmap1_GetSize(This) ID2D1Bitmap1_GetSize_define_WIDL_C_INLINE_WRAPPERS_for_aggregate_return_support
#define ID2D1Bitmap1_GetPixelSize(This) ID2D1Bitmap1_GetPixelSize_define_WIDL_C_INLINE_WRAPPERS_for_aggregate_return_support
#define ID2D1Bitmap1_GetPixelFormat(This) ID2D1Bitmap1_GetPixelFormat_define_WIDL_C_INLINE_WRAPPERS_for_aggregate_return_support
#define ID2D1Bitmap1_GetDpi(This,dpi_x,dpi_y) (This)->lpVtbl->GetDpi(This,dpi_x,dpi_y)
#define ID2D1Bitmap1_CopyFromBitmap(This,dst_point,bitmap,src_rect) (This)->lpVtbl->CopyFromBitmap(This,dst_point,bitmap,src_rect)
#define ID2D1Bitmap1_CopyFromRenderTarget(This,dst_point,render_target,src_rect) (This)->lpVtbl->CopyFromRenderTarget(This,dst_point,render_target,src_rect)
#define ID2D1Bitmap1_CopyFromMemory(This,dst_rect,src_data,pitch) (This)->lpVtbl->CopyFromMemory(This,dst_rect,src_data,pitch)
/*** ID2D1Bitmap1 methods ***/
#define ID2D1Bitmap1_GetColorContext(This,context) (This)->lpVtbl->GetColorContext(This,context)
#define ID2D1Bitmap1_GetOptions(This) (This)->lpVtbl->GetOptions(This)
#define ID2D1Bitmap1_GetSurface(This,surface) (This)->lpVtbl->GetSurface(This,surface)
#define ID2D1Bitmap1_Map(This,options,mapped_rect) (This)->lpVtbl->Map(This,options,mapped_rect)
#define ID2D1Bitmap1_Unmap(This) (This)->lpVtbl->Unmap(This)

#endif

DEFINE_GUID(IID_ID2D1Bitmap1, 0xa898a84c,0x3873,0x4588,0xb0,0x8b,0xeb,0xbf,0x97,0x8d,0xf0,0x41);
__CRT_UUID_DECL(ID2D1Bitmap1, 0xa898a84c,0x3873,0x4588,0xb0,0x8b,0xeb,0xbf,0x97,0x8d,0xf0,0x41);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1ImageBrush : public ID2D1Brush
{
    STDMETHOD_(void, SetImage)(ID2D1Image *image) PURE;
    STDMETHOD_(void, SetExtendModeX)(D2D1_EXTEND_MODE extendModeX) PURE;
    STDMETHOD_(void, SetExtendModeY)(D2D1_EXTEND_MODE extendModeY) PURE;
    STDMETHOD_(void, SetInterpolationMode)(D2D1_INTERPOLATION_MODE interpolationMode) PURE;
    STDMETHOD_(void, SetSourceRectangle)(CONST D2D1_RECT_F *sourceRectangle) PURE;
    STDMETHOD_(void, GetImage)(ID2D1Image **image) CONST PURE;
    STDMETHOD_(D2D1_EXTEND_MODE, GetExtendModeX)() CONST PURE;
    STDMETHOD_(D2D1_EXTEND_MODE, GetExtendModeY)() CONST PURE;
    STDMETHOD_(D2D1_INTERPOLATION_MODE, GetInterpolationMode)() CONST PURE;
    STDMETHOD_(void, GetSourceRectangle)(D2D1_RECT_F *sourceRectangle) CONST PURE;
};

#else

typedef interface ID2D1ImageBrush ID2D1ImageBrush;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1ImageBrush, 0xfe9e984d,0x3f95,0x407c,0xb5,0xdb,0xcb,0x94,0xd4,0xe8,0xf8,0x7c);
__CRT_UUID_DECL(ID2D1ImageBrush, 0xfe9e984d,0x3f95,0x407c,0xb5,0xdb,0xcb,0x94,0xd4,0xe8,0xf8,0x7c);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1BitmapBrush1 : public ID2D1BitmapBrush
{
    STDMETHOD_(void, SetInterpolationMode1)(D2D1_INTERPOLATION_MODE interpolationMode) PURE;
    STDMETHOD_(D2D1_INTERPOLATION_MODE, GetInterpolationMode1)() CONST PURE;
};

#else

typedef interface ID2D1BitmapBrush1 ID2D1BitmapBrush1;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1BitmapBrush1, 0x41343a53,0xe41a,0x49a2,0x91,0xcd,0x21,0x79,0x3b,0xbb,0x62,0xe5);
__CRT_UUID_DECL(ID2D1BitmapBrush1, 0x41343a53,0xe41a,0x49a2,0x91,0xcd,0x21,0x79,0x3b,0xbb,0x62,0xe5);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1GradientStopCollection1 : public ID2D1GradientStopCollection
{
    STDMETHOD_(void, GetGradientStops1)(D2D1_GRADIENT_STOP *gradientStops, UINT32 gradientStopsCount) CONST PURE;
    STDMETHOD_(D2D1_COLOR_SPACE, GetPreInterpolationSpace)() CONST PURE;
    STDMETHOD_(D2D1_COLOR_SPACE, GetPostInterpolationSpace)() CONST PURE;
    STDMETHOD_(D2D1_BUFFER_PRECISION, GetBufferPrecision)() CONST PURE;
    STDMETHOD_(D2D1_COLOR_INTERPOLATION_MODE, GetColorInterpolationMode)() CONST PURE;
};

#else

typedef interface ID2D1GradientStopCollection1 ID2D1GradientStopCollection1;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1GradientStopCollection1, 0xae1572f4,0x5dd0,0x4777,0x99,0x8b,0x92,0x79,0x47,0x2a,0xe6,0x3b);
__CRT_UUID_DECL(ID2D1GradientStopCollection1, 0xae1572f4,0x5dd0,0x4777,0x99,0x8b,0x92,0x79,0x47,0x2a,0xe6,0x3b);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1ColorContext : public ID2D1Resource
{
    STDMETHOD_(D2D1_COLOR_SPACE, GetColorSpace)() CONST PURE;
    STDMETHOD_(UINT32, GetProfileSize)() CONST PURE;
    STDMETHOD(GetProfile)(BYTE *profile, UINT32 profileSize) CONST PURE;
};

#else

typedef interface ID2D1ColorContext ID2D1ColorContext;

#endif

DEFINE_GUID(IID_ID2D1ColorContext, 0x1c4820bb,0x5771,0x4518,0xa5,0x81,0x2f,0xe4,0xdd,0x0e,0xc6,0x57);
__CRT_UUID_DECL(ID2D1ColorContext, 0x1c4820bb,0x5771,0x4518,0xa5,0x81,0x2f,0xe4,0xdd,0x0e,0xc6,0x57);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1DeviceContext : public ID2D1RenderTarget
{
    STDMETHOD(CreateBitmap)(D2D1_SIZE_U size, CONST void *sourceData, UINT32 pitch,
            CONST D2D1_BITMAP_PROPERTIES1 *bitmapProperties, ID2D1Bitmap1 **bitmap) PURE;
    using ID2D1RenderTarget::CreateBitmap;

    STDMETHOD(CreateBitmapFromWicBitmap)(IWICBitmapSource *wicBitmapSource,
            CONST D2D1_BITMAP_PROPERTIES1 *bitmapProperties, ID2D1Bitmap1 **bitmap) PURE;
    using ID2D1RenderTarget::CreateBitmapFromWicBitmap;

    STDMETHOD(CreateColorContext)(D2D1_COLOR_SPACE space, CONST BYTE *profile, UINT32 profileSize,
            ID2D1ColorContext **colorContext) PURE;
    STDMETHOD(CreateColorContextFromFilename)(PCWSTR filename, ID2D1ColorContext **colorContext) PURE;
    STDMETHOD(CreateColorContextFromWicColorContext)(IWICColorContext *wicColorContext, ID2D1ColorContext **colorContext) PURE;
    STDMETHOD(CreateBitmapFromDxgiSurface)(IDXGISurface *surface, CONST D2D1_BITMAP_PROPERTIES1 *bitmapProperties,
            ID2D1Bitmap1 **bitmap) PURE;
    STDMETHOD(CreateEffect)(REFCLSID effectId, ID2D1Effect **effect) PURE;

    STDMETHOD(CreateGradientStopCollection)(CONST D2D1_GRADIENT_STOP *straightAlphaGradientStops,
        UINT32 straightAlphaGradientStopsCount, D2D1_COLOR_SPACE preInterpolationSpace,
        D2D1_COLOR_SPACE postInterpolationSpace, D2D1_BUFFER_PRECISION bufferPrecision,
        D2D1_EXTEND_MODE extendMode, D2D1_COLOR_INTERPOLATION_MODE colorInterpolationMode,
        ID2D1GradientStopCollection1 **gradientStopCollection1) PURE;
    using ID2D1RenderTarget::CreateGradientStopCollection;

    STDMETHOD(CreateImageBrush)(ID2D1Image *image, CONST D2D1_IMAGE_BRUSH_PROPERTIES *imageBrushProperties,
            CONST D2D1_BRUSH_PROPERTIES *brushProperties, ID2D1ImageBrush **imageBrush) PURE;

    STDMETHOD(CreateBitmapBrush)(ID2D1Bitmap *bitmap, CONST D2D1_BITMAP_BRUSH_PROPERTIES1 *bitmapBrushProperties,
            CONST D2D1_BRUSH_PROPERTIES *brushProperties, ID2D1BitmapBrush1 **bitmapBrush) PURE;
    using ID2D1RenderTarget::CreateBitmapBrush;

    STDMETHOD(CreateCommandList)(ID2D1CommandList **commandList) PURE;
    STDMETHOD_(BOOL, IsDxgiFormatSupported)(DXGI_FORMAT format) CONST PURE;
    STDMETHOD_(BOOL, IsBufferPrecisionSupported)(D2D1_BUFFER_PRECISION bufferPrecision) CONST PURE;
    STDMETHOD(GetImageLocalBounds)(ID2D1Image *image, D2D1_RECT_F *localBounds) CONST PURE;
    STDMETHOD(GetImageWorldBounds)(ID2D1Image *image, D2D1_RECT_F *worldBounds) CONST PURE;
    STDMETHOD(GetGlyphRunWorldBounds)(D2D1_POINT_2F baselineOrigin, CONST DWRITE_GLYPH_RUN *glyphRun,
            DWRITE_MEASURING_MODE measuringMode, D2D1_RECT_F *bounds) CONST PURE;
    STDMETHOD_(void, GetDevice)(ID2D1Device **device) CONST PURE;
    STDMETHOD_(void, SetTarget)(ID2D1Image *image) PURE;
    STDMETHOD_(void, GetTarget)(ID2D1Image **image) CONST PURE;
    STDMETHOD_(void, SetRenderingControls)(CONST D2D1_RENDERING_CONTROLS *renderingControls) PURE;
    STDMETHOD_(void, GetRenderingControls)(D2D1_RENDERING_CONTROLS *renderingControls) CONST PURE;
    STDMETHOD_(void, SetPrimitiveBlend)(D2D1_PRIMITIVE_BLEND primitiveBlend) PURE;
    STDMETHOD_(D2D1_PRIMITIVE_BLEND, GetPrimitiveBlend)() CONST PURE;
    STDMETHOD_(void, SetUnitMode)(D2D1_UNIT_MODE unitMode) PURE;
    STDMETHOD_(D2D1_UNIT_MODE, GetUnitMode)() CONST PURE;

    STDMETHOD_(void, DrawGlyphRun)(D2D1_POINT_2F baselineOrigin, CONST DWRITE_GLYPH_RUN *glyphRun,
            CONST DWRITE_GLYPH_RUN_DESCRIPTION *glyphRunDescription, ID2D1Brush *foregroundBrush,
            DWRITE_MEASURING_MODE measuringMode = DWRITE_MEASURING_MODE_NATURAL) PURE;
    using ID2D1RenderTarget::DrawGlyphRun;

    STDMETHOD_(void, DrawImage)(ID2D1Image *image, CONST D2D1_POINT_2F *targetOffset = NULL,
            CONST D2D1_RECT_F *imageRectangle = NULL, D2D1_INTERPOLATION_MODE interpolationMode = D2D1_INTERPOLATION_MODE_LINEAR,
            D2D1_COMPOSITE_MODE compositeMode = D2D1_COMPOSITE_MODE_SOURCE_OVER) PURE;
    STDMETHOD_(void, DrawGdiMetafile)(ID2D1GdiMetafile *gdiMetafile, CONST D2D1_POINT_2F *targetOffset = NULL) PURE;

    STDMETHOD_(void, DrawBitmap)(ID2D1Bitmap *bitmap, CONST D2D1_RECT_F *destinationRectangle, FLOAT opacity,
            D2D1_INTERPOLATION_MODE interpolationMode, CONST D2D1_RECT_F *sourceRectangle = NULL,
            CONST D2D1_MATRIX_4X4_F *perspectiveTransform = NULL) PURE;
    using ID2D1RenderTarget::DrawBitmap;

    STDMETHOD_(void, PushLayer)(CONST D2D1_LAYER_PARAMETERS1 *layerParameters, ID2D1Layer *layer) PURE;
    using ID2D1RenderTarget::PushLayer;

    STDMETHOD(InvalidateEffectInputRectangle)(ID2D1Effect *effect, UINT32 input, CONST D2D1_RECT_F *inputRectangle) PURE;
    STDMETHOD(GetEffectInvalidRectangleCount)(ID2D1Effect *effect, UINT32 *rectangleCount) PURE;
    STDMETHOD(GetEffectInvalidRectangles)(ID2D1Effect *effect, D2D1_RECT_F *rectangles, UINT32 rectanglesCount) PURE;
    STDMETHOD(GetEffectRequiredInputRectangles)(ID2D1Effect *renderEffect, CONST D2D1_RECT_F *renderImageRectangle,
            CONST D2D1_EFFECT_INPUT_DESCRIPTION *inputDescriptions, D2D1_RECT_F *requiredInputRects, UINT32 inputCount) PURE;

    STDMETHOD_(void, FillOpacityMask)(ID2D1Bitmap *opacityMask, ID2D1Brush *brush, CONST D2D1_RECT_F *destinationRectangle = NULL,
            CONST D2D1_RECT_F *sourceRectangle = NULL) PURE;
    using ID2D1RenderTarget::FillOpacityMask;

    HRESULT CreateBitmap(D2D1_SIZE_U size, CONST void *sourceData, UINT32 pitch, CONST D2D1_BITMAP_PROPERTIES1 &bitmapProperties,
            ID2D1Bitmap1 **bitmap) {
        return CreateBitmap(size, sourceData, pitch, &bitmapProperties, bitmap);
    }

    HRESULT CreateBitmapFromWicBitmap(IWICBitmapSource *wicBitmapSource, CONST D2D1_BITMAP_PROPERTIES1 &bitmapProperties,
            ID2D1Bitmap1 **bitmap) {
        return CreateBitmapFromWicBitmap(wicBitmapSource, &bitmapProperties, bitmap);
    }

    HRESULT CreateBitmapFromWicBitmap(IWICBitmapSource *wicBitmapSource, ID2D1Bitmap1 **bitmap) {
        return CreateBitmapFromWicBitmap(wicBitmapSource, NULL, bitmap);
    }

    HRESULT CreateBitmapFromDxgiSurface(IDXGISurface *surface, CONST D2D1_BITMAP_PROPERTIES1 &bitmapProperties,
        ID2D1Bitmap1 **bitmap) {
        return CreateBitmapFromDxgiSurface(surface, &bitmapProperties, bitmap);
    }

    HRESULT CreateImageBrush(ID2D1Image *image, CONST D2D1_IMAGE_BRUSH_PROPERTIES &imageBrushProperties,
        CONST D2D1_BRUSH_PROPERTIES &brushProperties, ID2D1ImageBrush **imageBrush) {
        return CreateImageBrush(image, &imageBrushProperties, &brushProperties, imageBrush);
    }

    HRESULT CreateImageBrush(ID2D1Image *image, CONST D2D1_IMAGE_BRUSH_PROPERTIES &imageBrushProperties,
        ID2D1ImageBrush **imageBrush) {
        return CreateImageBrush(image,&imageBrushProperties, NULL, imageBrush);
    }

    HRESULT CreateBitmapBrush(ID2D1Bitmap *bitmap, ID2D1BitmapBrush1 **bitmapBrush) {
        return CreateBitmapBrush(bitmap, NULL, NULL, bitmapBrush);
    }

    HRESULT CreateBitmapBrush(ID2D1Bitmap *bitmap, CONST D2D1_BITMAP_BRUSH_PROPERTIES1 &bitmapBrushProperties,
            ID2D1BitmapBrush1 **bitmapBrush) {
        return CreateBitmapBrush(bitmap, &bitmapBrushProperties, NULL, bitmapBrush);
    }

    HRESULT CreateBitmapBrush(ID2D1Bitmap *bitmap, CONST D2D1_BITMAP_BRUSH_PROPERTIES1 &bitmapBrushProperties,
            CONST D2D1_BRUSH_PROPERTIES &brushProperties, ID2D1BitmapBrush1 **bitmapBrush) {
        return CreateBitmapBrush(bitmap, &bitmapBrushProperties, &brushProperties, bitmapBrush);
    }

    void DrawImage(ID2D1Effect *effect, CONST D2D1_POINT_2F *targetOffset = NULL, CONST D2D1_RECT_F *imageRectangle = NULL,
            D2D1_INTERPOLATION_MODE interpolationMode = D2D1_INTERPOLATION_MODE_LINEAR,
            D2D1_COMPOSITE_MODE compositeMode = D2D1_COMPOSITE_MODE_SOURCE_OVER) {
        ID2D1Image *output = NULL;
        effect->GetOutput(&output);
        DrawImage(output, targetOffset, imageRectangle, interpolationMode, compositeMode);
        output->Release();
    }

    void DrawImage(ID2D1Image *image, D2D1_INTERPOLATION_MODE interpolationMode,
            D2D1_COMPOSITE_MODE compositeMode = D2D1_COMPOSITE_MODE_SOURCE_OVER) {
        DrawImage(image, NULL, NULL, interpolationMode, compositeMode);
    }

    void DrawImage(ID2D1Effect *effect, D2D1_INTERPOLATION_MODE interpolationMode,
            D2D1_COMPOSITE_MODE compositeMode = D2D1_COMPOSITE_MODE_SOURCE_OVER) {
        DrawImage(effect, NULL, NULL, interpolationMode, compositeMode);
    }

    void DrawImage(ID2D1Image *image, D2D1_POINT_2F targetOffset,
            D2D1_INTERPOLATION_MODE interpolationMode = D2D1_INTERPOLATION_MODE_LINEAR,
            D2D1_COMPOSITE_MODE compositeMode = D2D1_COMPOSITE_MODE_SOURCE_OVER) {
        DrawImage(image, &targetOffset, NULL, interpolationMode, compositeMode);
    }

    void DrawImage(ID2D1Effect *effect, D2D1_POINT_2F targetOffset,
            D2D1_INTERPOLATION_MODE interpolationMode = D2D1_INTERPOLATION_MODE_LINEAR,
            D2D1_COMPOSITE_MODE compositeMode = D2D1_COMPOSITE_MODE_SOURCE_OVER) {
        DrawImage(effect, &targetOffset, NULL, interpolationMode, compositeMode);
    }

    void DrawImage(ID2D1Image *image, D2D1_POINT_2F targetOffset, CONST D2D1_RECT_F &imageRectangle,
            D2D1_INTERPOLATION_MODE interpolationMode = D2D1_INTERPOLATION_MODE_LINEAR,
            D2D1_COMPOSITE_MODE compositeMode = D2D1_COMPOSITE_MODE_SOURCE_OVER) {
        DrawImage(image, &targetOffset, &imageRectangle, interpolationMode, compositeMode);
    }

    void DrawImage(ID2D1Effect *effect, D2D1_POINT_2F targetOffset, CONST D2D1_RECT_F &imageRectangle,
            D2D1_INTERPOLATION_MODE interpolationMode = D2D1_INTERPOLATION_MODE_LINEAR,
            D2D1_COMPOSITE_MODE compositeMode = D2D1_COMPOSITE_MODE_SOURCE_OVER) {
        DrawImage(effect, &targetOffset, &imageRectangle, interpolationMode, compositeMode);
    }

    void PushLayer(CONST D2D1_LAYER_PARAMETERS1 &layerParameters, ID2D1Layer *layer) {
        PushLayer(&layerParameters, layer);
    }

    void DrawGdiMetafile(ID2D1GdiMetafile *gdiMetafile, D2D1_POINT_2F targetOffset) {
        DrawGdiMetafile(gdiMetafile, &targetOffset);
    }

    void DrawBitmap(ID2D1Bitmap *bitmap, CONST D2D1_RECT_F &destinationRectangle, FLOAT opacity,
            D2D1_INTERPOLATION_MODE interpolationMode, CONST D2D1_RECT_F *sourceRectangle = NULL,
            CONST D2D1_MATRIX_4X4_F *perspectiveTransform = NULL) {
        DrawBitmap(bitmap, &destinationRectangle, opacity, interpolationMode, sourceRectangle, perspectiveTransform);
    }

    void DrawBitmap(ID2D1Bitmap *bitmap, CONST D2D1_RECT_F &destinationRectangle, FLOAT opacity,
            D2D1_INTERPOLATION_MODE interpolationMode, CONST D2D1_RECT_F &sourceRectangle,
            CONST D2D1_MATRIX_4X4_F *perspectiveTransform = NULL) {
        DrawBitmap(bitmap, &destinationRectangle, opacity, interpolationMode, &sourceRectangle, perspectiveTransform);
    }

    void DrawBitmap(ID2D1Bitmap *bitmap, CONST D2D1_RECT_F &destinationRectangle, FLOAT opacity,
            D2D1_INTERPOLATION_MODE interpolationMode, CONST D2D1_RECT_F &sourceRectangle,
            CONST D2D1_MATRIX_4X4_F &perspectiveTransform) {
        DrawBitmap(bitmap, &destinationRectangle, opacity, interpolationMode, &sourceRectangle, &perspectiveTransform);
    }

    void FillOpacityMask(ID2D1Bitmap *opacityMask, ID2D1Brush *brush, CONST D2D1_RECT_F &destinationRectangle,
            CONST D2D1_RECT_F *sourceRectangle = NULL) {
        FillOpacityMask(opacityMask, brush, &destinationRectangle, sourceRectangle);
    }

    void FillOpacityMask(ID2D1Bitmap *opacityMask, ID2D1Brush *brush, CONST D2D1_RECT_F &destinationRectangle,
            CONST D2D1_RECT_F &sourceRectangle) {
        FillOpacityMask(opacityMask, brush, &destinationRectangle, &sourceRectangle);
    }

    void SetRenderingControls(CONST D2D1_RENDERING_CONTROLS &renderingControls) {
        return SetRenderingControls(&renderingControls);
    }
};


#else

typedef interface ID2D1DeviceContext ID2D1DeviceContext;

typedef struct ID2D1DeviceContextVtbl {
    struct ID2D1RenderTargetVtbl Base;

    STDMETHOD(CreateBitmap)(ID2D1DeviceContext *This, D2D1_SIZE_U size,
        CONST void *sourceData, UINT32 pitch,
        CONST D2D1_BITMAP_PROPERTIES1 *bitmapProperties,
        ID2D1Bitmap1 **bitmap) PURE;

    STDMETHOD(CreateBitmapFromWicBitmap)(ID2D1DeviceContext *This,
        IWICBitmapSource *wicBitmapSource,
        CONST D2D1_BITMAP_PROPERTIES1 *bitmapProperties,
        ID2D1Bitmap1 **bitmap) PURE;

    STDMETHOD(CreateColorContext)(ID2D1DeviceContext *This,
        D2D1_COLOR_SPACE space, CONST BYTE *profile, UINT32 profileSize,
        ID2D1ColorContext **colorContext) PURE;
    STDMETHOD(CreateColorContextFromFilename)(ID2D1DeviceContext *This,
        PCWSTR filename, ID2D1ColorContext **colorContext) PURE;
    STDMETHOD(CreateColorContextFromWicColorContext)(ID2D1DeviceContext *This,
        IWICColorContext *wicColorContext,
        ID2D1ColorContext **colorContext) PURE;
    STDMETHOD(CreateBitmapFromDxgiSurface)(ID2D1DeviceContext *This,
        IDXGISurface *surface, CONST D2D1_BITMAP_PROPERTIES1 *bitmapProperties,
        ID2D1Bitmap1 **bitmap) PURE;
    STDMETHOD(CreateEffect)(ID2D1DeviceContext *This, REFCLSID effectId,
        ID2D1Effect **effect) PURE;

    STDMETHOD(CreateGradientStopCollection)(ID2D1DeviceContext *This,
        CONST D2D1_GRADIENT_STOP *straightAlphaGradientStops,
        UINT32 straightAlphaGradientStopsCount,
        D2D1_COLOR_SPACE preInterpolationSpace,
        D2D1_COLOR_SPACE postInterpolationSpace,
        D2D1_BUFFER_PRECISION bufferPrecision,
        D2D1_EXTEND_MODE extendMode,
        D2D1_COLOR_INTERPOLATION_MODE colorInterpolationMode,
        ID2D1GradientStopCollection1 **gradientStopCollection1) PURE;

    STDMETHOD(CreateImageBrush)(ID2D1DeviceContext *This,
        struct ID2D1Image *image,
        CONST D2D1_IMAGE_BRUSH_PROPERTIES *imageBrushProperties,
        CONST D2D1_BRUSH_PROPERTIES *brushProperties,
        ID2D1ImageBrush **imageBrush) PURE;

    STDMETHOD(CreateBitmapBrush)(ID2D1DeviceContext *This, ID2D1Bitmap *bitmap,
        CONST D2D1_BITMAP_BRUSH_PROPERTIES1 *bitmapBrushProperties,
        CONST D2D1_BRUSH_PROPERTIES *brushProperties,
        ID2D1BitmapBrush1 **bitmapBrush) PURE;

    STDMETHOD(CreateCommandList)(ID2D1DeviceContext *This,
        ID2D1CommandList **commandList) PURE;
    STDMETHOD_(BOOL, IsDxgiFormatSupported)(ID2D1DeviceContext *This,
        DXGI_FORMAT format) PURE;
    STDMETHOD_(BOOL, IsBufferPrecisionSupported)(ID2D1DeviceContext *This,
        D2D1_BUFFER_PRECISION bufferPrecision) PURE;
    STDMETHOD(GetImageLocalBounds)(ID2D1DeviceContext *This,
        struct ID2D1Image *image, D2D1_RECT_F *localBounds) PURE;
    STDMETHOD(GetImageWorldBounds)(ID2D1DeviceContext *This,
        struct ID2D1Image *image, D2D1_RECT_F *worldBounds) PURE;
    STDMETHOD(GetGlyphRunWorldBounds)(ID2D1DeviceContext *This,
        D2D1_POINT_2F baselineOrigin, CONST DWRITE_GLYPH_RUN *glyphRun,
        DWRITE_MEASURING_MODE measuringMode, D2D1_RECT_F *bounds) PURE;
    STDMETHOD_(void, GetDevice)(ID2D1DeviceContext *This,
        ID2D1Device **device) PURE;
    STDMETHOD_(void, SetTarget)(ID2D1DeviceContext *This,
        struct ID2D1Image *image) PURE;
    STDMETHOD_(void, GetTarget)(ID2D1DeviceContext *This,
        struct ID2D1Image **image) PURE;
    STDMETHOD_(void, SetRenderingControls)(ID2D1DeviceContext *This,
        CONST D2D1_RENDERING_CONTROLS *renderingControls) PURE;
    STDMETHOD_(void, GetRenderingControls)(ID2D1DeviceContext *This,
        D2D1_RENDERING_CONTROLS *renderingControls) PURE;
    STDMETHOD_(void, SetPrimitiveBlend)(ID2D1DeviceContext *This,
        D2D1_PRIMITIVE_BLEND primitiveBlend) PURE;
    STDMETHOD_(D2D1_PRIMITIVE_BLEND, GetPrimitiveBlend)(ID2D1DeviceContext *This) PURE;
    STDMETHOD_(void, SetUnitMode)(ID2D1DeviceContext *This,
        D2D1_UNIT_MODE unitMode) PURE;
    STDMETHOD_(D2D1_UNIT_MODE, GetUnitMode)(ID2D1DeviceContext *This) PURE;

    STDMETHOD_(void, DrawGlyphRun)(ID2D1DeviceContext *This,
        D2D1_POINT_2F baselineOrigin, CONST DWRITE_GLYPH_RUN *glyphRun,
        CONST DWRITE_GLYPH_RUN_DESCRIPTION *glyphRunDescription,
        ID2D1Brush *foregroundBrush, DWRITE_MEASURING_MODE measuringMode) PURE;

    STDMETHOD_(void, DrawImage)(ID2D1DeviceContext *This,
        struct ID2D1Image *image, CONST D2D1_POINT_2F *targetOffset,
        CONST D2D1_RECT_F *imageRectangle,
        D2D1_INTERPOLATION_MODE interpolationMode,
        D2D1_COMPOSITE_MODE compositeMode) PURE;
    STDMETHOD_(void, DrawGdiMetafile)(ID2D1DeviceContext *This,
        ID2D1GdiMetafile *gdiMetafile, CONST D2D1_POINT_2F *targetOffset) PURE;

    STDMETHOD_(void, DrawBitmap)(ID2D1DeviceContext *This,
        ID2D1Bitmap *bitmap, CONST D2D1_RECT_F *destinationRectangle,
        FLOAT opacity, D2D1_INTERPOLATION_MODE interpolationMode,
        CONST D2D1_RECT_F *sourceRectangle,
        CONST D2D1_MATRIX_4X4_F *perspectiveTransform) PURE;

    STDMETHOD_(void, PushLayer)(ID2D1DeviceContext *This,
        CONST D2D1_LAYER_PARAMETERS1 *layerParameters, ID2D1Layer *layer) PURE;

    STDMETHOD(InvalidateEffectInputRectangle)(ID2D1DeviceContext *This,
        ID2D1Effect *effect, UINT32 input,
        CONST D2D1_RECT_F *inputRectangle) PURE;
    STDMETHOD(GetEffectInvalidRectangleCount)(ID2D1DeviceContext *This,
        ID2D1Effect *effect, UINT32 *rectangleCount) PURE;
    STDMETHOD(GetEffectInvalidRectangles)(ID2D1DeviceContext *This,
        ID2D1Effect *effect, D2D1_RECT_F *rectangles,
        UINT32 rectanglesCount) PURE;
    STDMETHOD(GetEffectRequiredInputRectangles)(ID2D1DeviceContext *This,
        ID2D1Effect *renderEffect, CONST D2D1_RECT_F *renderImageRectangle,
        CONST D2D1_EFFECT_INPUT_DESCRIPTION *inputDescriptions,
        D2D1_RECT_F *requiredInputRects, UINT32 inputCount) PURE;

    STDMETHOD_(void, FillOpacityMask)(ID2D1DeviceContext *This,
        ID2D1Bitmap *opacityMask, ID2D1Brush *brush,
        CONST D2D1_RECT_F *destinationRectangle,
        CONST D2D1_RECT_F *sourceRectangle) PURE;
}
ID2D1DeviceContextVtbl;

interface ID2D1DeviceContext {
    const ID2D1DeviceContextVtbl *lpVtbl;
};

/*** IUnknown methods ***/
#define ID2D1DeviceContext_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ID2D1DeviceContext_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ID2D1DeviceContext_Release(This) (This)->lpVtbl->Release(This)
/*** ID2D1Resource methods ***/
#define ID2D1DeviceContext_GetFactory(This,factory) (This)->lpVtbl->GetFactory(This,factory)
/*** ID2D1RenderTarget methods ***/
#define ID2D1DeviceContext_CreateSharedBitmap(This,iid,data,desc,bitmap) (This)->lpVtbl->CreateSharedBitmap(This,iid,data,desc,bitmap)
#define ID2D1DeviceContext_CreateSolidColorBrush(This,color,desc,brush) (This)->lpVtbl->CreateSolidColorBrush(This,color,desc,brush)
#define ID2D1DeviceContext_CreateLinearGradientBrush(This,gradient_brush_desc,brush_desc,gradient,brush) (This)->lpVtbl->CreateLinearGradientBrush(This,gradient_brush_desc,brush_desc,gradient,brush)
#define ID2D1DeviceContext_CreateRadialGradientBrush(This,gradient_brush_desc,brush_desc,gradient,brush) (This)->lpVtbl->CreateRadialGradientBrush(This,gradient_brush_desc,brush_desc,gradient,brush)
#define ID2D1DeviceContext_CreateCompatibleRenderTarget(This,size,pixel_size,format,options,render_target) (This)->lpVtbl->CreateCompatibleRenderTarget(This,size,pixel_size,format,options,render_target)
#define ID2D1DeviceContext_CreateLayer(This,size,layer) (This)->lpVtbl->CreateLayer(This,size,layer)
#define ID2D1DeviceContext_CreateMesh(This,mesh) (This)->lpVtbl->CreateMesh(This,mesh)
#define ID2D1DeviceContext_DrawLine(This,p0,p1,brush,stroke_width,stroke_style) (This)->lpVtbl->DrawLine(This,p0,p1,brush,stroke_width,stroke_style)
#define ID2D1DeviceContext_DrawRectangle(This,rect,brush,stroke_width,stroke_style) (This)->lpVtbl->DrawRectangle(This,rect,brush,stroke_width,stroke_style)
#define ID2D1DeviceContext_FillRectangle(This,rect,brush) (This)->lpVtbl->FillRectangle(This,rect,brush)
#define ID2D1DeviceContext_DrawRoundedRectangle(This,rect,brush,stroke_width,stroke_style) (This)->lpVtbl->DrawRoundedRectangle(This,rect,brush,stroke_width,stroke_style)
#define ID2D1DeviceContext_FillRoundedRectangle(This,rect,brush) (This)->lpVtbl->FillRoundedRectangle(This,rect,brush)
#define ID2D1DeviceContext_DrawEllipse(This,ellipse,brush,stroke_width,stroke_style) (This)->lpVtbl->DrawEllipse(This,ellipse,brush,stroke_width,stroke_style)
#define ID2D1DeviceContext_FillEllipse(This,ellipse,brush) (This)->lpVtbl->FillEllipse(This,ellipse,brush)
#define ID2D1DeviceContext_DrawGeometry(This,geometry,brush,stroke_width,stroke_style) (This)->lpVtbl->DrawGeometry(This,geometry,brush,stroke_width,stroke_style)
#define ID2D1DeviceContext_FillGeometry(This,geometry,brush,opacity_brush) (This)->lpVtbl->FillGeometry(This,geometry,brush,opacity_brush)
#define ID2D1DeviceContext_FillMesh(This,mesh,brush) (This)->lpVtbl->FillMesh(This,mesh,brush)
#define ID2D1DeviceContext_DrawText(This,string,string_len,text_format,layout_rect,brush,options,measuring_mode) (This)->lpVtbl->DrawText(This,string,string_len,text_format,layout_rect,brush,options,measuring_mode)
#define ID2D1DeviceContext_DrawTextLayout(This,origin,layout,brush,options) (This)->lpVtbl->DrawTextLayout(This,origin,layout,brush,options)
#define ID2D1DeviceContext_SetTransform(This,transform) (This)->lpVtbl->SetTransform(This,transform)
#define ID2D1DeviceContext_GetTransform(This,transform) (This)->lpVtbl->GetTransform(This,transform)
#define ID2D1DeviceContext_SetAntialiasMode(This,antialias_mode) (This)->lpVtbl->SetAntialiasMode(This,antialias_mode)
#define ID2D1DeviceContext_GetAntialiasMode(This) (This)->lpVtbl->GetAntialiasMode(This)
#define ID2D1DeviceContext_SetTextAntialiasMode(This,antialias_mode) (This)->lpVtbl->SetTextAntialiasMode(This,antialias_mode)
#define ID2D1DeviceContext_GetTextAntialiasMode(This) (This)->lpVtbl->GetTextAntialiasMode(This)
#define ID2D1DeviceContext_SetTextRenderingParams(This,text_rendering_params) (This)->lpVtbl->SetTextRenderingParams(This,text_rendering_params)
#define ID2D1DeviceContext_GetTextRenderingParams(This,text_rendering_params) (This)->lpVtbl->GetTextRenderingParams(This,text_rendering_params)
#define ID2D1DeviceContext_SetTags(This,tag1,tag2) (This)->lpVtbl->SetTags(This,tag1,tag2)
#define ID2D1DeviceContext_GetTags(This,tag1,tag2) (This)->lpVtbl->GetTags(This,tag1,tag2)
#define ID2D1DeviceContext_PopLayer(This) (This)->lpVtbl->PopLayer(This)
#define ID2D1DeviceContext_Flush(This,tag1,tag2) (This)->lpVtbl->Flush(This,tag1,tag2)
#define ID2D1DeviceContext_SaveDrawingState(This,state_block) (This)->lpVtbl->SaveDrawingState(This,state_block)
#define ID2D1DeviceContext_RestoreDrawingState(This,state_block) (This)->lpVtbl->RestoreDrawingState(This,state_block)
#define ID2D1DeviceContext_PushAxisAlignedClip(This,clip_rect,antialias_mode) (This)->lpVtbl->PushAxisAlignedClip(This,clip_rect,antialias_mode)
#define ID2D1DeviceContext_PopAxisAlignedClip(This) (This)->lpVtbl->PopAxisAlignedClip(This)
#define ID2D1DeviceContext_Clear(This,color) (This)->lpVtbl->Clear(This,color)
#define ID2D1DeviceContext_BeginDraw(This) (This)->lpVtbl->BeginDraw(This)
#define ID2D1DeviceContext_EndDraw(This,tag1,tag2) (This)->lpVtbl->EndDraw(This,tag1,tag2)
#define ID2D1DeviceContext_GetPixelFormat(This) ID2D1DeviceContext_GetPixelFormat_define_WIDL_C_INLINE_WRAPPERS_for_aggregate_return_support
#define ID2D1DeviceContext_SetDpi(This,dpi_x,dpi_y) (This)->lpVtbl->SetDpi(This,dpi_x,dpi_y)
#define ID2D1DeviceContext_GetDpi(This,dpi_x,dpi_y) (This)->lpVtbl->GetDpi(This,dpi_x,dpi_y)
#define ID2D1DeviceContext_GetSize(This) ID2D1DeviceContext_GetSize_define_WIDL_C_INLINE_WRAPPERS_for_aggregate_return_support
#define ID2D1DeviceContext_GetPixelSize(This) ID2D1DeviceContext_GetPixelSize_define_WIDL_C_INLINE_WRAPPERS_for_aggregate_return_support
#define ID2D1DeviceContext_GetMaximumBitmapSize(This) (This)->lpVtbl->GetMaximumBitmapSize(This)
#define ID2D1DeviceContext_IsSupported(This,desc) (This)->lpVtbl->IsSupported(This,desc)
/*** ID2D1DeviceContext methods ***/
#define ID2D1DeviceContext_CreateBitmap(This,size,src_data,pitch,desc,bitmap) (This)->lpVtbl->ID2D1DeviceContext_CreateBitmap(This,size,src_data,pitch,desc,bitmap)
#define ID2D1DeviceContext_CreateBitmapFromWicBitmap(This,bitmap_source,desc,bitmap) (This)->lpVtbl->ID2D1DeviceContext_CreateBitmapFromWicBitmap(This,bitmap_source,desc,bitmap)
#define ID2D1DeviceContext_CreateColorContext(This,space,profile,profile_size,color_context) (This)->lpVtbl->CreateColorContext(This,space,profile,profile_size,color_context)
#define ID2D1DeviceContext_CreateColorContextFromFilename(This,filename,color_context) (This)->lpVtbl->CreateColorContextFromFilename(This,filename,color_context)
#define ID2D1DeviceContext_CreateColorContextFromWicColorContext(This,wic_color_context,color_context) (This)->lpVtbl->CreateColorContextFromWicColorContext(This,wic_color_context,color_context)
#define ID2D1DeviceContext_CreateBitmapFromDxgiSurface(This,surface,desc,bitmap) (This)->lpVtbl->CreateBitmapFromDxgiSurface(This,surface,desc,bitmap)
#define ID2D1DeviceContext_CreateEffect(This,effect_id,effect) (This)->lpVtbl->CreateEffect(This,effect_id,effect)
#define ID2D1DeviceContext_CreateGradientStopCollection(This,stops,stop_count,preinterpolation_space,postinterpolation_space,buffer_precision,extend_mode,color_interpolation_mode,gradient) (This)->lpVtbl->ID2D1DeviceContext_CreateGradientStopCollection(This,stops,stop_count,preinterpolation_space,postinterpolation_space,buffer_precision,extend_mode,color_interpolation_mode,gradient)
#define ID2D1DeviceContext_CreateImageBrush(This,image,image_brush_desc,brush_desc,brush) (This)->lpVtbl->CreateImageBrush(This,image,image_brush_desc,brush_desc,brush)
#define ID2D1DeviceContext_CreateBitmapBrush(This,bitmap,bitmap_brush_desc,brush_desc,bitmap_brush) (This)->lpVtbl->ID2D1DeviceContext_CreateBitmapBrush(This,bitmap,bitmap_brush_desc,brush_desc,bitmap_brush)
#define ID2D1DeviceContext_CreateCommandList(This,command_list) (This)->lpVtbl->CreateCommandList(This,command_list)
#define ID2D1DeviceContext_IsDxgiFormatSupported(This,format) (This)->lpVtbl->IsDxgiFormatSupported(This,format)
#define ID2D1DeviceContext_IsBufferPrecisionSupported(This,buffer_precision) (This)->lpVtbl->IsBufferPrecisionSupported(This,buffer_precision)
#define ID2D1DeviceContext_GetImageLocalBounds(This,image,local_bounds) (This)->lpVtbl->GetImageLocalBounds(This,image,local_bounds)
#define ID2D1DeviceContext_GetImageWorldBounds(This,image,world_bounds) (This)->lpVtbl->GetImageWorldBounds(This,image,world_bounds)
#define ID2D1DeviceContext_GetGlyphRunWorldBounds(This,baseline_origin,glyph_run,measuring_mode,bounds) (This)->lpVtbl->GetGlyphRunWorldBounds(This,baseline_origin,glyph_run,measuring_mode,bounds)
#define ID2D1DeviceContext_GetDevice(This,device) (This)->lpVtbl->GetDevice(This,device)
#define ID2D1DeviceContext_SetTarget(This,target) (This)->lpVtbl->SetTarget(This,target)
#define ID2D1DeviceContext_GetTarget(This,target) (This)->lpVtbl->GetTarget(This,target)
#define ID2D1DeviceContext_SetRenderingControls(This,rendering_controls) (This)->lpVtbl->SetRenderingControls(This,rendering_controls)
#define ID2D1DeviceContext_GetRenderingControls(This,rendering_controls) (This)->lpVtbl->GetRenderingControls(This,rendering_controls)
#define ID2D1DeviceContext_SetPrimitiveBlend(This,primitive_blend) (This)->lpVtbl->SetPrimitiveBlend(This,primitive_blend)
#define ID2D1DeviceContext_GetPrimitiveBlend(This) (This)->lpVtbl->GetPrimitiveBlend(This)
#define ID2D1DeviceContext_SetUnitMode(This,unit_mode) (This)->lpVtbl->SetUnitMode(This,unit_mode)
#define ID2D1DeviceContext_GetUnitMode(This) (This)->lpVtbl->GetUnitMode(This)
#define ID2D1DeviceContext_DrawGlyphRun(This,baseline_origin,glyph_run,glyph_run_desc,brush,measuring_mode) (This)->lpVtbl->ID2D1DeviceContext_DrawGlyphRun(This,baseline_origin,glyph_run,glyph_run_desc,brush,measuring_mode)
#define ID2D1DeviceContext_DrawImage(This,image,target_offset,image_rect,interpolation_mode,composite_mode) (This)->lpVtbl->DrawImage(This,image,target_offset,image_rect,interpolation_mode,composite_mode)
#define ID2D1DeviceContext_DrawGdiMetafile(This,metafile,target_offset) (This)->lpVtbl->DrawGdiMetafile(This,metafile,target_offset)
#define ID2D1DeviceContext_DrawBitmap(This,bitmap,dst_rect,opacity,interpolation_mode,src_rect,perspective_transform) (This)->lpVtbl->ID2D1DeviceContext_DrawBitmap(This,bitmap,dst_rect,opacity,interpolation_mode,src_rect,perspective_transform)
#define ID2D1DeviceContext_PushLayer(This,layer_parameters,layer) (This)->lpVtbl->ID2D1DeviceContext_PushLayer(This,layer_parameters,layer)
#define ID2D1DeviceContext_InvalidateEffectInputRectangle(This,effect,input,input_rect) (This)->lpVtbl->InvalidateEffectInputRectangle(This,effect,input,input_rect)
#define ID2D1DeviceContext_GetEffectInvalidRectangleCount(This,effect,rect_count) (This)->lpVtbl->GetEffectInvalidRectangleCount(This,effect,rect_count)
#define ID2D1DeviceContext_GetEffectInvalidRectangles(This,effect,rectangles,rect_count) (This)->lpVtbl->GetEffectInvalidRectangles(This,effect,rectangles,rect_count)
#define ID2D1DeviceContext_GetEffectRequiredInputRectangles(This,effect,image_rect,desc,input_rect,input_count) (This)->lpVtbl->GetEffectRequiredInputRectangles(This,effect,image_rect,desc,input_rect,input_count)
#define ID2D1DeviceContext_FillOpacityMask(This,mask,brush,dst_rect,src_rect) (This)->lpVtbl->ID2D1DeviceContext_FillOpacityMask(This,mask,brush,dst_rect,src_rect)

#endif

DEFINE_GUID(IID_ID2D1DeviceContext, 0xe8f7fe7a,0x191c,0x466d,0xad,0x95,0x97,0x56,0x78,0xbd,0xa9,0x98);
__CRT_UUID_DECL(ID2D1DeviceContext, 0xe8f7fe7a,0x191c,0x466d,0xad,0x95,0x97,0x56,0x78,0xbd,0xa9,0x98);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1Device : public ID2D1Resource
{
    STDMETHOD(CreateDeviceContext)(D2D1_DEVICE_CONTEXT_OPTIONS options, ID2D1DeviceContext **deviceContext) PURE;
    STDMETHOD(CreatePrintControl)(IWICImagingFactory *wicFactory, IPrintDocumentPackageTarget *documentTarget,
            CONST D2D1_PRINT_CONTROL_PROPERTIES *printControlProperties, ID2D1PrintControl **printControl) PURE;
    STDMETHOD_(void, SetMaximumTextureMemory)(UINT64 maximumInBytes) PURE;
    STDMETHOD_(UINT64, GetMaximumTextureMemory)() CONST PURE;
    STDMETHOD_(void, ClearResources)(UINT32 millisecondsSinceUse = 0) PURE;

    HRESULT CreatePrintControl(IWICImagingFactory *wicFactory, IPrintDocumentPackageTarget *documentTarget,
            CONST D2D1_PRINT_CONTROL_PROPERTIES &printControlProperties, ID2D1PrintControl **printControl) {
        return CreatePrintControl(wicFactory, documentTarget, &printControlProperties, printControl);
    }
};

#else

typedef interface ID2D1Device ID2D1Device;

typedef struct ID2D1DeviceVtbl {
    struct ID2D1ResourceVtbl Base;

    STDMETHOD(CreateDeviceContext)(ID2D1Device *This,
        D2D1_DEVICE_CONTEXT_OPTIONS options,
        ID2D1DeviceContext **deviceContext) PURE;
    STDMETHOD(CreatePrintControl)(ID2D1Device *This,
        IWICImagingFactory *wicFactory,
        IPrintDocumentPackageTarget *documentTarget,
        CONST D2D1_PRINT_CONTROL_PROPERTIES *printControlProperties,
        ID2D1PrintControl **printControl) PURE;
    STDMETHOD_(void, SetMaximumTextureMemory)(ID2D1Device *This,
        UINT64 maximumInBytes) PURE;
    STDMETHOD_(UINT64, GetMaximumTextureMemory)(ID2D1Device *This) PURE;
    STDMETHOD_(void, ClearResources)(ID2D1Device *This,
        UINT32 millisecondsSinceUse) PURE;
}
ID2D1DeviceVtbl;

interface ID2D1Device {
    const ID2D1DeviceVtbl *lpVtbl;
};

/*** IUnknown methods ***/
#define ID2D1Device_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ID2D1Device_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ID2D1Device_Release(This) (This)->lpVtbl->Release(This)
/*** ID2D1Resource methods ***/
#define ID2D1Device_GetFactory(This,factory) (This)->lpVtbl->GetFactory(This,factory)
/*** ID2D1Device methods ***/
#define ID2D1Device_CreateDeviceContext(This,options,context) (This)->lpVtbl->CreateDeviceContext(This,options,context)
#define ID2D1Device_CreatePrintControl(This,wic_factory,document_target,desc,print_control) (This)->lpVtbl->CreatePrintControl(This,wic_factory,document_target,desc,print_control)
#define ID2D1Device_SetMaximumTextureMemory(This,max_texture_memory) (This)->lpVtbl->SetMaximumTextureMemory(This,max_texture_memory)
#define ID2D1Device_GetMaximumTextureMemory(This) (This)->lpVtbl->GetMaximumTextureMemory(This)
#define ID2D1Device_ClearResources(This,msec_since_use) (This)->lpVtbl->ClearResources(This,msec_since_use)

#endif

DEFINE_GUID(IID_ID2D1Device, 0x47dd575d,0xac05,0x4cdd,0x80,0x49,0x9b,0x02,0xcd,0x16,0xf4,0x4c);
__CRT_UUID_DECL(ID2D1Device, 0x47dd575d,0xac05,0x4cdd,0x80,0x49,0x9b,0x02,0xcd,0x16,0xf4,0x4c);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1DrawingStateBlock1 : public ID2D1DrawingStateBlock
{
    STDMETHOD_(void, GetDescription)(D2D1_DRAWING_STATE_DESCRIPTION1 *stateDescription) CONST PURE;
    using ID2D1DrawingStateBlock::GetDescription;

    STDMETHOD_(void, SetDescription)(CONST D2D1_DRAWING_STATE_DESCRIPTION1 *stateDescription) PURE;
    using ID2D1DrawingStateBlock::SetDescription;
};

#else

typedef interface ID2D1DrawingStateBlock1 ID2D1DrawingStateBlock1;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1DrawingStateBlock1, 0x689f1f85,0xc72e,0x4e33,0x8f,0x19,0x85,0x75,0x4e,0xfd,0x5a,0xce);
__CRT_UUID_DECL(ID2D1DrawingStateBlock1, 0x689f1f85,0xc72e,0x4e33,0x8f,0x19,0x85,0x75,0x4e,0xfd,0x5a,0xce);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1PathGeometry1 : public ID2D1PathGeometry
{
    STDMETHOD(ComputePointAndSegmentAtLength)(FLOAT length, UINT32 startSegment, CONST D2D1_MATRIX_3X2_F *worldTransform,
            FLOAT flatteningTolerance, D2D1_POINT_DESCRIPTION *pointDescription) CONST PURE;

    HRESULT ComputePointAndSegmentAtLength(FLOAT length, UINT32 startSegment, CONST D2D1_MATRIX_3X2_F &worldTransform,
            FLOAT flatteningTolerance, D2D1_POINT_DESCRIPTION *pointDescription) CONST {
        return ComputePointAndSegmentAtLength(length, startSegment, &worldTransform, flatteningTolerance, pointDescription);
    }

    HRESULT ComputePointAndSegmentAtLength(FLOAT length, UINT32 startSegment, CONST D2D1_MATRIX_3X2_F *worldTransform,
            D2D1_POINT_DESCRIPTION *pointDescription) CONST {
        return ComputePointAndSegmentAtLength(length, startSegment, worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE,
                                              pointDescription);
    }

    HRESULT ComputePointAndSegmentAtLength(FLOAT length, UINT32 startSegment, CONST D2D1_MATRIX_3X2_F &worldTransform,
            D2D1_POINT_DESCRIPTION *pointDescription) CONST {
        return ComputePointAndSegmentAtLength(length, startSegment, &worldTransform, D2D1_DEFAULT_FLATTENING_TOLERANCE,
                                              pointDescription);
    }
};

#else

typedef interface ID2D1PathGeometry1 ID2D1PathGeometry1;
/* FIXME: Add full C declaration */

#endif

DEFINE_GUID(IID_ID2D1PathGeometry1, 0x62baa2d2,0xab54,0x41b7,0xb8,0x72,0x78,0x7e,0x01,0x06,0xa4,0x21);
__CRT_UUID_DECL(ID2D1PathGeometry1, 0x62baa2d2,0xab54,0x41b7,0xb8,0x72,0x78,0x7e,0x01,0x06,0xa4,0x21);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1Factory1 : public ID2D1Factory
{
    STDMETHOD(CreateDevice)(IDXGIDevice *dxgiDevice, ID2D1Device **d2dDevice) PURE;

    STDMETHOD(CreateStrokeStyle)(CONST D2D1_STROKE_STYLE_PROPERTIES1 *strokeStyleProperties,
            CONST FLOAT *dashes, UINT32 dashesCount, ID2D1StrokeStyle1 **strokeStyle) PURE;
    using ID2D1Factory::CreateStrokeStyle;

    STDMETHOD(CreatePathGeometry)(ID2D1PathGeometry1 **pathGeometry) PURE;
    using ID2D1Factory::CreatePathGeometry;

    STDMETHOD(CreateDrawingStateBlock)(CONST D2D1_DRAWING_STATE_DESCRIPTION1 *drawingStateDescription,
            IDWriteRenderingParams *textRenderingParams, ID2D1DrawingStateBlock1 **drawingStateBlock) PURE;
    using ID2D1Factory::CreateDrawingStateBlock;

    STDMETHOD(CreateGdiMetafile)(IStream *metafileStream, ID2D1GdiMetafile **metafile) PURE;
    STDMETHOD(RegisterEffectFromStream)(REFCLSID classId, IStream *propertyXml, CONST D2D1_PROPERTY_BINDING *bindings,
            UINT32 bindingsCount, CONST PD2D1_EFFECT_FACTORY effectFactory) PURE;
    STDMETHOD(RegisterEffectFromString)(REFCLSID classId, PCWSTR propertyXml, CONST D2D1_PROPERTY_BINDING *bindings,
            UINT32 bindingsCount, CONST PD2D1_EFFECT_FACTORY effectFactory) PURE;
    STDMETHOD(UnregisterEffect)(REFCLSID classId) PURE;
    STDMETHOD(GetRegisteredEffects)(CLSID *effects, UINT32 effectsCount, UINT32 *effectsReturned,
            UINT32 *effectsRegistered) CONST PURE;
    STDMETHOD(GetEffectProperties)(REFCLSID effectId, ID2D1Properties **properties) CONST PURE;

    HRESULT CreateStrokeStyle(CONST D2D1_STROKE_STYLE_PROPERTIES1 &strokeStyleProperties, CONST FLOAT *dashes,
            UINT32 dashesCount, ID2D1StrokeStyle1 **strokeStyle) {
        return CreateStrokeStyle(&strokeStyleProperties, dashes, dashesCount, strokeStyle);
    }

    HRESULT CreateDrawingStateBlock(CONST D2D1_DRAWING_STATE_DESCRIPTION1 &drawingStateDescription,
            ID2D1DrawingStateBlock1 **drawingStateBlock) {
        return CreateDrawingStateBlock(&drawingStateDescription, NULL, drawingStateBlock);
    }

    HRESULT CreateDrawingStateBlock(ID2D1DrawingStateBlock1 **drawingStateBlock) {
        return CreateDrawingStateBlock(NULL, NULL, drawingStateBlock);
    }
};

#else

typedef interface ID2D1Factory1 ID2D1Factory1;

typedef struct ID2D1Factory1Vtbl {
    ID2D1FactoryVtbl Base;

    STDMETHOD(CreateDevice)(ID2D1Factory1 *This, IDXGIDevice *dxgiDevice,
            ID2D1Device **d2dDevice) PURE;
    STDMETHOD(CreateStrokeStyle)(ID2D1Factory1 *This,
            CONST D2D1_STROKE_STYLE_PROPERTIES1 *strokeStyleProperties,
            CONST FLOAT *dashes, UINT32 dashesCount,
            ID2D1StrokeStyle1 **strokeStyle) PURE;
    STDMETHOD(CreatePathGeometry)(ID2D1Factory1 *This,
            ID2D1PathGeometry1 **pathGeometry) PURE;
    STDMETHOD(CreateDrawingStateBlock)(ID2D1Factory1 *This,
            CONST D2D1_DRAWING_STATE_DESCRIPTION1 *drawingStateDescription,
            IDWriteRenderingParams *textRenderingParams,
            ID2D1DrawingStateBlock1 **drawingStateBlock) PURE;
    STDMETHOD(CreateGdiMetafile)(ID2D1Factory1 *This, IStream *metafileStream,
            ID2D1GdiMetafile **metafile) PURE;
    STDMETHOD(RegisterEffectFromStream)(ID2D1Factory1 *This, REFCLSID classId,
            IStream *propertyXml, CONST D2D1_PROPERTY_BINDING *bindings,
            UINT32 bindingsCount,
            CONST PD2D1_EFFECT_FACTORY effectFactory) PURE;
    STDMETHOD(RegisterEffectFromString)(ID2D1Factory1 *This,
            REFCLSID classId, PCWSTR propertyXml,
            CONST D2D1_PROPERTY_BINDING *bindings, UINT32 bindingsCount,
            CONST PD2D1_EFFECT_FACTORY effectFactory) PURE;
    STDMETHOD(UnregisterEffect)(ID2D1Factory1 *This, REFCLSID classId) PURE;
    STDMETHOD(GetRegisteredEffects)(ID2D1Factory1 *This, CLSID *effects,
            UINT32 effectsCount, UINT32 *effectsReturned,
            UINT32 *effectsRegistered) PURE;
    STDMETHOD(GetEffectProperties)(ID2D1Factory1 *This, REFCLSID effectId,
            ID2D1Properties **properties) PURE;
} ID2D1Factory1Vtbl;

interface ID2D1Factory1 {
    const ID2D1Factory1Vtbl *lpVtbl;
};

#define ID2D1Factory1_QueryInterface(this,A,B) (this)->lpVtbl->Base.Base.QueryInterface((IUnknown *)(this),A,B)
#define ID2D1Factory1_AddRef(this) (this)->lpVtbl->Base.Base.AddRef((IUnknown *)(this))
#define ID2D1Factory1_Release(this) (this)->lpVtbl->Base.Base.Release((IUnknown *)(this))
#define ID2D1Factory1_CreateDevice(this,A,B) (this)->lpVtbl->CreateDevice(this,A,B)
#define ID2D1Factory1_CreateStrokeStyle(this,A,B,C,D) (this)->lpVtbl->CreateStrokeStyle(this,A,B,C,D)
#define ID2D1Factory1_CreatePathGeometry(this,A) (this)->lpVbtl->CreatePathGeometry(this,A)
#define ID2D1Factory1_CreateDrawingStateBlock(this,A,B, C) (this)->lpVtbl->CreateDrawingStateBlock(this,A,B,C)
#define ID2D1Factory1_CreateGdiMetafile(this,A,B) (this)->lpVtbl->CreateGdiMetafile(this,A,B)
#define ID2D1Factory1_RegisterEffectFromStream(this,A,B,C,D,E) (this)->lpVtbl->RegisterEffectFromStream(this,A,B,C,D,E)
#define ID2D1Factory1_RegisterEffectFromString(this,A,B,C,D,E) (this)->lpVtbl->RegisterEffectFromString(this,A,B,C,D,E)
#define ID2D1Factory1_UnregisterEffect(this,A) (this)->lpVtbl->UnregisterEffect(this,A)
#define ID2D1Factory1_GetRegisteredEffects(this,A,B,C,D) (this)->lpVtbl->GetRegisteredEffects(this,A,B,C,D)
#define ID2D1Factory1_GetEffectProperties(this,A,B) (this)->lpVtbl->GetEffectProperties(this,A,B)

#endif

DEFINE_GUID(IID_ID2D1Factory1, 0xbb12d362,0xdaee,0x4b9a,0xaa,0x1d,0x14,0xba,0x40,0x1c,0xfa,0x1f);
__CRT_UUID_DECL(ID2D1Factory1, 0xbb12d362,0xdaee,0x4b9a,0xaa,0x1d,0x14,0xba,0x40,0x1c,0xfa,0x1f);

#ifndef D2D_USE_C_DEFINITIONS

interface ID2D1Multithread : public IUnknown
{
    STDMETHOD_(BOOL, GetMultithreadProtected)() CONST PURE;
    STDMETHOD_(void, Enter)() PURE;
    STDMETHOD_(void, Leave)() PURE;
};

#else

typedef interface ID2D1Multithread ID2D1Multithread;

typedef struct ID2D1MultithreadVtbl {
    IUnknownVtbl Base;

    STDMETHOD_(BOOL, GetMultithreadProtected)(ID2D1Multithread *This) PURE;
    STDMETHOD_(void, Enter)(ID2D1Multithread *This) PURE;
    STDMETHOD_(void, Leave)(ID2D1Multithread *This) PURE;
} ID2D1MultithreadVtbl;

interface ID2D1Multithread {
    ID2D1MultithreadVtbl *lpVtbl;
};

#define ID2D1Multithread_QueryInterface(this,A,B) (this)->lpVtbl->Base.QueryInterface((IUnknown *)(this),A,B)
#define ID2D1Multithread_AddRef(this) (this)->lpVtbl->Base.AddRef((IUnknown *)(this))
#define ID2D1Multithread_Release(this) (this)->lpVtbl->Base.Release((IUnknown *)(this))
#define ID2D1Mutlithread_GetMultithreadProtected(this) (this)->lpVtbl->GetMultihreadProtected(this)
#define ID2D1Multithread_Enter(this) (this)->lpVtbl->Enter(this)
#define ID2D1Multithread_Leave(this) (this)->lpVtbl->Leave(this)

#endif

DEFINE_GUID(IID_ID2D1Multithread, 0x31e6e7bc,0xe0ff,0x4d46,0x8c,0x64,0xa0,0xa8,0xc4,0x1c,0x15,0xd3);
__CRT_UUID_DECL(ID2D1Multithread, 0x31e6e7bc,0xe0ff,0x4d46,0x8c,0x64,0xa0,0xa8,0xc4,0x1c,0x15,0xd3);

#include <d2d1_1helper.h>

#endif
