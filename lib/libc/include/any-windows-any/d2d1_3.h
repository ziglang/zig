/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _D2D1_3_H_
#define _D2D1_3_H_

#ifndef _D2D1_2_H_
#include <d2d1_2.h>
#endif

#ifndef _D2D1_EFFECTS_2_
#include <d2d1effects_2.h>
#endif

#ifndef _D2D1_SVG_
#include <d2d1svg.h>
#endif

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)

typedef interface IWICBitmapFrameDecode IWICBitmapFrameDecode;
typedef interface IDWriteFontFace IDWriteFontFace;

typedef enum D2D1_INK_NIB_SHAPE {
  D2D1_INK_NIB_SHAPE_ROUND = 0,
  D2D1_INK_NIB_SHAPE_SQUARE = 1,
  D2D1_INK_NIB_SHAPE_FORCE_DWORD = 0xffffffff
} D2D1_INK_NIB_SHAPE;

typedef enum D2D1_ORIENTATION {
  D2D1_ORIENTATION_DEFAULT = 1,
  D2D1_ORIENTATION_FLIP_HORIZONTAL = 2,
  D2D1_ORIENTATION_ROTATE_CLOCKWISE180 = 3,
  D2D1_ORIENTATION_ROTATE_CLOCKWISE180_FLIP_HORIZONTAL = 4,
  D2D1_ORIENTATION_ROTATE_CLOCKWISE90_FLIP_HORIZONTAL = 5,
  D2D1_ORIENTATION_ROTATE_CLOCKWISE270 = 6,
  D2D1_ORIENTATION_ROTATE_CLOCKWISE270_FLIP_HORIZONTAL = 7,
  D2D1_ORIENTATION_ROTATE_CLOCKWISE90 = 8,
  D2D1_ORIENTATION_FORCE_DWORD = 0xffffffff
} D2D1_ORIENTATION;

typedef enum D2D1_IMAGE_SOURCE_LOADING_OPTIONS {
  D2D1_IMAGE_SOURCE_LOADING_OPTIONS_NONE = 0,
  D2D1_IMAGE_SOURCE_LOADING_OPTIONS_RELEASE_SOURCE = 1,
  D2D1_IMAGE_SOURCE_LOADING_OPTIONS_CACHE_ON_DEMAND = 2,
  D2D1_IMAGE_SOURCE_LOADING_OPTIONS_FORCE_DWORD = 0xffffffff
} D2D1_IMAGE_SOURCE_LOADING_OPTIONS;

DEFINE_ENUM_FLAG_OPERATORS(D2D1_IMAGE_SOURCE_LOADING_OPTIONS);

typedef enum D2D1_IMAGE_SOURCE_FROM_DXGI_OPTIONS {
  D2D1_IMAGE_SOURCE_FROM_DXGI_OPTIONS_NONE = 0,
  D2D1_IMAGE_SOURCE_FROM_DXGI_OPTIONS_LOW_QUALITY_PRIMARY_CONVERSION = 1,
  D2D1_IMAGE_SOURCE_FROM_DXGI_OPTIONS_FORCE_DWORD = 0xffffffff
} D2D1_IMAGE_SOURCE_FROM_DXGI_OPTIONS;

DEFINE_ENUM_FLAG_OPERATORS(D2D1_IMAGE_SOURCE_FROM_DXGI_OPTIONS);

typedef enum D2D1_TRANSFORMED_IMAGE_SOURCE_OPTIONS {
  D2D1_TRANSFORMED_IMAGE_SOURCE_OPTIONS_NONE = 0,
  D2D1_TRANSFORMED_IMAGE_SOURCE_OPTIONS_DISABLE_DPI_SCALE = 1,
  D2D1_TRANSFORMED_IMAGE_SOURCE_OPTIONS_FORCE_DWORD = 0xffffffff
} D2D1_TRANSFORMED_IMAGE_SOURCE_OPTIONS;

DEFINE_ENUM_FLAG_OPERATORS(D2D1_TRANSFORMED_IMAGE_SOURCE_OPTIONS);

typedef struct D2D1_TRANSFORMED_IMAGE_SOURCE_PROPERTIES {
  D2D1_ORIENTATION orientation;
  FLOAT scaleX;
  FLOAT scaleY;
  D2D1_INTERPOLATION_MODE interpolationMode;
  D2D1_TRANSFORMED_IMAGE_SOURCE_OPTIONS options;
} D2D1_TRANSFORMED_IMAGE_SOURCE_PROPERTIES;

typedef struct D2D1_INK_POINT {
  FLOAT x;
  FLOAT y;
  FLOAT radius;
} D2D1_INK_POINT;

typedef struct D2D1_INK_BEZIER_SEGMENT {
  D2D1_INK_POINT point1;
  D2D1_INK_POINT point2;
  D2D1_INK_POINT point3;
} D2D1_INK_BEZIER_SEGMENT;

typedef struct D2D1_INK_STYLE_PROPERTIES {
  D2D1_INK_NIB_SHAPE nibShape;
  D2D1_MATRIX_3X2_F nibTransform;
} D2D1_INK_STYLE_PROPERTIES;

typedef enum D2D1_PATCH_EDGE_MODE {
  D2D1_PATCH_EDGE_MODE_ALIASED = 0,
  D2D1_PATCH_EDGE_MODE_ANTIALIASED = 1,
  D2D1_PATCH_EDGE_MODE_ALIASED_INFLATED = 2,
  D2D1_PATCH_EDGE_MODE_FORCE_DWORD = 0xffffffff
} D2D1_PATCH_EDGE_MODE;

typedef struct D2D1_GRADIENT_MESH_PATCH {
  D2D1_POINT_2F point00;
  D2D1_POINT_2F point01;
  D2D1_POINT_2F point02;
  D2D1_POINT_2F point03;
  D2D1_POINT_2F point10;
  D2D1_POINT_2F point11;
  D2D1_POINT_2F point12;
  D2D1_POINT_2F point13;
  D2D1_POINT_2F point20;
  D2D1_POINT_2F point21;
  D2D1_POINT_2F point22;
  D2D1_POINT_2F point23;
  D2D1_POINT_2F point30;
  D2D1_POINT_2F point31;
  D2D1_POINT_2F point32;
  D2D1_POINT_2F point33;
  D2D1_COLOR_F color00;
  D2D1_COLOR_F color03;
  D2D1_COLOR_F color30;
  D2D1_COLOR_F color33;
  D2D1_PATCH_EDGE_MODE topEdgeMode;
  D2D1_PATCH_EDGE_MODE leftEdgeMode;
  D2D1_PATCH_EDGE_MODE bottomEdgeMode;
  D2D1_PATCH_EDGE_MODE rightEdgeMode;
} D2D1_GRADIENT_MESH_PATCH;

typedef enum D2D1_SPRITE_OPTIONS {
  D2D1_SPRITE_OPTIONS_NONE = 0,
  D2D1_SPRITE_OPTIONS_CLAMP_TO_SOURCE_RECTANGLE = 1,
  D2D1_SPRITE_OPTIONS_FORCE_DWORD = 0xffffffff
} D2D1_SPRITE_OPTIONS;

DEFINE_ENUM_FLAG_OPERATORS(D2D1_SPRITE_OPTIONS);

typedef enum D2D1_COLOR_BITMAP_GLYPH_SNAP_OPTION {
  D2D1_COLOR_BITMAP_GLYPH_SNAP_OPTION_DEFAULT = 0,
  D2D1_COLOR_BITMAP_GLYPH_SNAP_OPTION_DISABLE = 1,
  D2D1_COLOR_BITMAP_GLYPH_SNAP_OPTION_FORCE_DWORD = 0xffffffff
} D2D1_COLOR_BITMAP_GLYPH_SNAP_OPTION;

typedef enum D2D1_GAMMA1 {
  D2D1_GAMMA1_G22 = D2D1_GAMMA_2_2,
  D2D1_GAMMA1_G10 = D2D1_GAMMA_1_0,
  D2D1_GAMMA1_G2084 = 2,
  D2D1_GAMMA1_FORCE_DWORD = 0xffffffff
} D2D1_GAMMA1;

typedef struct D2D1_SIMPLE_COLOR_PROFILE {
  D2D1_POINT_2F redPrimary;
  D2D1_POINT_2F greenPrimary;
  D2D1_POINT_2F bluePrimary;
  D2D1_POINT_2F whitePointXZ;
  D2D1_GAMMA1 gamma;
} D2D1_SIMPLE_COLOR_PROFILE;

typedef enum D2D1_COLOR_CONTEXT_TYPE {
  D2D1_COLOR_CONTEXT_TYPE_ICC = 0,
  D2D1_COLOR_CONTEXT_TYPE_SIMPLE = 1,
  D2D1_COLOR_CONTEXT_TYPE_DXGI = 2,
  D2D1_COLOR_CONTEXT_TYPE_FORCE_DWORD = 0xffffffff
} D2D1_COLOR_CONTEXT_TYPE;

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1InkStyle : public ID2D1Resource
{
  STDMETHOD_(void, SetNibTransform)(const D2D1_MATRIX_3X2_F *transform) PURE;
  STDMETHOD_(void, GetNibTransform)(D2D1_MATRIX_3X2_F *transform) const PURE;
  STDMETHOD_(void, SetNibShape)(D2D1_INK_NIB_SHAPE nib_shape) PURE;
  STDMETHOD_(D2D1_INK_NIB_SHAPE, GetNibShape)() const PURE;

  COM_DECLSPEC_NOTHROW void SetNibTransform(const D2D1_MATRIX_3X2_F &transform) {
    SetNibTransform(&transform);
  }
};
#else
typedef interface ID2D1InkStyle ID2D1InkStyle;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1InkStyle, 0xbae8b344, 0x23fc, 0x4071, 0x8c, 0xb5, 0xd0, 0x5d, 0x6f, 0x07, 0x38, 0x48);
__CRT_UUID_DECL(ID2D1InkStyle, 0xbae8b344, 0x23fc, 0x4071, 0x8c, 0xb5, 0xd0, 0x5d, 0x6f, 0x07, 0x38, 0x48);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1Ink : public ID2D1Resource
{
  STDMETHOD_(void, SetStartPoint)(const D2D1_INK_POINT *start_point) PURE;
#ifndef WIDL_EXPLICIT_AGGREGATE_RETURNS
  STDMETHOD_(D2D1_INK_POINT, GetStartPoint)() const PURE;
#else
  virtual D2D1_INK_POINT* STDMETHODCALLTYPE GetStartPoint(D2D1_INK_POINT*) const = 0;
  D2D1_INK_POINT STDMETHODCALLTYPE GetStartPoint() const {
    D2D1_INK_POINT __ret;
    GetStartPoint(&__ret);
    return __ret;
  }
#endif
  STDMETHOD(AddSegments)(const D2D1_INK_BEZIER_SEGMENT *segments, UINT32 segments_count) PURE;
  STDMETHOD(RemoveSegmentsAtEnd)(UINT32 segments_count) PURE;
  STDMETHOD(SetSegments)(UINT32 start_segment, const D2D1_INK_BEZIER_SEGMENT *segments, UINT32 segments_count) PURE;
  STDMETHOD(SetSegmentAtEnd)(const D2D1_INK_BEZIER_SEGMENT *segment) PURE;
  STDMETHOD_(UINT32, GetSegmentCount)() const PURE;
  STDMETHOD(GetSegments)(UINT32 start_segment, D2D1_INK_BEZIER_SEGMENT *segments, UINT32 segments_count) const PURE;
  STDMETHOD(StreamAsGeometry)(ID2D1InkStyle *ink_style, const D2D1_MATRIX_3X2_F *world_transform, FLOAT flattening_tolerance, ID2D1SimplifiedGeometrySink *geometry_sink) const PURE;
  STDMETHOD(GetBounds)(ID2D1InkStyle *ink_style, const D2D1_MATRIX_3X2_F *world_transform, D2D1_RECT_F *bounds) const PURE;

  COM_DECLSPEC_NOTHROW void SetStartPoint(const D2D1_INK_POINT &start_point) {
    SetStartPoint(&start_point);
  }

  COM_DECLSPEC_NOTHROW HRESULT SetSegmentAtEnd(const D2D1_INK_BEZIER_SEGMENT &segment) {
    return SetSegmentAtEnd(&segment);
  }

  COM_DECLSPEC_NOTHROW HRESULT StreamAsGeometry(ID2D1InkStyle *ink_style, const D2D1_MATRIX_3X2_F &world_transform, FLOAT flattening_tolerance, ID2D1SimplifiedGeometrySink *geometry_sink) const {
    return StreamAsGeometry(ink_style, &world_transform, flattening_tolerance, geometry_sink);
  }

  COM_DECLSPEC_NOTHROW HRESULT StreamAsGeometry(ID2D1InkStyle *ink_style, const D2D1_MATRIX_3X2_F *world_transform, ID2D1SimplifiedGeometrySink *geometry_sink) const {
    return StreamAsGeometry(ink_style, world_transform, D2D1_DEFAULT_FLATTENING_TOLERANCE, geometry_sink);
  }

  COM_DECLSPEC_NOTHROW HRESULT StreamAsGeometry(ID2D1InkStyle *ink_style, const D2D1_MATRIX_3X2_F &world_transform, ID2D1SimplifiedGeometrySink *geometry_sink) const {
    return StreamAsGeometry(ink_style, &world_transform, D2D1_DEFAULT_FLATTENING_TOLERANCE, geometry_sink);
  }
};
#else
typedef interface ID2D1Ink ID2D1Ink;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1Ink, 0xb499923b, 0x7029, 0x478f, 0xa8, 0xb3, 0x43, 0x2c, 0x7c, 0x5f, 0x53, 0x12);
__CRT_UUID_DECL(ID2D1Ink, 0xb499923b, 0x7029, 0x478f, 0xa8, 0xb3, 0x43, 0x2c, 0x7c, 0x5f, 0x53, 0x12);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1GradientMesh : public ID2D1Resource
{
  STDMETHOD_(UINT32, GetPatchCount)() const PURE;
  STDMETHOD(GetPatches)(UINT32 start_index, D2D1_GRADIENT_MESH_PATCH *patches, UINT32 patches_count) const PURE;
};
#else
typedef interface ID2D1GradientMesh ID2D1GradientMesh;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1GradientMesh, 0xf292e401, 0xc050, 0x4cde, 0x83, 0xd7, 0x04, 0x96, 0x2d, 0x3b, 0x23, 0xc2);
__CRT_UUID_DECL(ID2D1GradientMesh, 0xf292e401, 0xc050, 0x4cde, 0x83, 0xd7, 0x04, 0x96, 0x2d, 0x3b, 0x23, 0xc2);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1ImageSource : public ID2D1Image
{
  STDMETHOD(OfferResources)() PURE;
  STDMETHOD(TryReclaimResources)(WINBOOL *resources_discarded) PURE;
};
#else
typedef interface ID2D1ImageSource ID2D1ImageSource;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1ImageSource, 0xc9b664e5, 0x74a1, 0x4378, 0x9a, 0xc2, 0xee, 0xfc, 0x37, 0xa3, 0xf4, 0xd8);
__CRT_UUID_DECL(ID2D1ImageSource, 0xc9b664e5, 0x74a1, 0x4378, 0x9a, 0xc2, 0xee, 0xfc, 0x37, 0xa3, 0xf4, 0xd8);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1ImageSourceFromWic : public ID2D1ImageSource
{
  STDMETHOD(EnsureCached)(const D2D1_RECT_U *rectangle_to_fill) PURE;
  STDMETHOD(TrimCache)(const D2D1_RECT_U *rectangle_to_preserve) PURE;
  STDMETHOD_(void, GetSource)(IWICBitmapSource **wic_bitmap_source) const PURE;

  COM_DECLSPEC_NOTHROW HRESULT EnsureCached(const D2D1_RECT_U &rectangle_to_fill) {
    return EnsureCached(&rectangle_to_fill);
  }

  COM_DECLSPEC_NOTHROW HRESULT TrimCache(const D2D1_RECT_U &rectangle_to_preserve) {
    return TrimCache(&rectangle_to_preserve);
  }
};
#else
typedef interface ID2D1ImageSourceFromWic ID2D1ImageSourceFromWic;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1ImageSourceFromWic, 0x77395441, 0x1c8f, 0x4555, 0x86, 0x83, 0xf5, 0x0d, 0xab, 0x0f, 0xe7, 0x92);
__CRT_UUID_DECL(ID2D1ImageSourceFromWic, 0x77395441, 0x1c8f, 0x4555, 0x86, 0x83, 0xf5, 0x0d, 0xab, 0x0f, 0xe7, 0x92);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1TransformedImageSource : public ID2D1Image
{
  STDMETHOD_(void, GetSource)(ID2D1ImageSource **image_source) const PURE;
  STDMETHOD_(void, GetProperties)(D2D1_TRANSFORMED_IMAGE_SOURCE_PROPERTIES *properties) const PURE;
};
#else
typedef interface ID2D1TransformedImageSource ID2D1TransformedImageSource;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1TransformedImageSource, 0x7f1f79e5, 0x2796, 0x416c, 0x8f, 0x55, 0x70, 0x0f, 0x91, 0x14, 0x45, 0xe5);
__CRT_UUID_DECL(ID2D1TransformedImageSource, 0x7f1f79e5, 0x2796, 0x416c, 0x8f, 0x55, 0x70, 0x0f, 0x91, 0x14, 0x45, 0xe5);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1LookupTable3D : public ID2D1Resource
{
};
#else
typedef interface ID2D1LookupTable3D ID2D1LookupTable3D;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1LookupTable3D, 0x53dd9855, 0xa3b0, 0x4d5b, 0x82, 0xe1, 0x26, 0xe2, 0x5c, 0x5e, 0x57, 0x97);
__CRT_UUID_DECL(ID2D1LookupTable3D, 0x53dd9855, 0xa3b0, 0x4d5b, 0x82, 0xe1, 0x26, 0xe2, 0x5c, 0x5e, 0x57, 0x97);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1DeviceContext2 : public ID2D1DeviceContext1
{
  STDMETHOD(CreateInk)(const D2D1_INK_POINT *start_point, ID2D1Ink **ink) PURE;
  STDMETHOD(CreateInkStyle)(const D2D1_INK_STYLE_PROPERTIES *ink_style_properties, ID2D1InkStyle **ink_style) PURE;
  STDMETHOD(CreateGradientMesh)(const D2D1_GRADIENT_MESH_PATCH *patches, UINT32 patches_count, ID2D1GradientMesh **gradient_mesh) PURE;
  STDMETHOD(CreateImageSourceFromWic)(IWICBitmapSource *wic_bitmap_source, D2D1_IMAGE_SOURCE_LOADING_OPTIONS loading_options, D2D1_ALPHA_MODE alpha_mode, ID2D1ImageSourceFromWic **image_source) PURE;
  STDMETHOD(CreateLookupTable3D)(D2D1_BUFFER_PRECISION precision, const UINT32 *extents, const BYTE *data, UINT32 data_count, const UINT32 *strides, ID2D1LookupTable3D **lookup_table) PURE;
  STDMETHOD(CreateImageSourceFromDxgi)(IDXGISurface **surfaces, UINT32 surface_count, DXGI_COLOR_SPACE_TYPE color_space, D2D1_IMAGE_SOURCE_FROM_DXGI_OPTIONS options, ID2D1ImageSource **image_source) PURE;
  STDMETHOD(GetGradientMeshWorldBounds)(ID2D1GradientMesh *gradient_mesh, D2D1_RECT_F *bounds) const PURE;
  STDMETHOD_(void, DrawInk)(ID2D1Ink *ink, ID2D1Brush *brush, ID2D1InkStyle *ink_style) PURE;
  STDMETHOD_(void, DrawGradientMesh)(ID2D1GradientMesh *gradient_mesh) PURE;
  STDMETHOD_(void, DrawGdiMetafile)(ID2D1GdiMetafile *gdi_metafile, const D2D1_RECT_F *destination_rectangle, const D2D1_RECT_F *source_rectangle = NULL) PURE;

  using ID2D1DeviceContext::DrawGdiMetafile;

  STDMETHOD(CreateTransformedImageSource)(ID2D1ImageSource *image_source, const D2D1_TRANSFORMED_IMAGE_SOURCE_PROPERTIES *properties, ID2D1TransformedImageSource **transformed_image_source) PURE;

  COM_DECLSPEC_NOTHROW HRESULT CreateInk(const D2D1_INK_POINT &start_point, ID2D1Ink **ink) {
    return CreateInk(&start_point, ink);
  }

  COM_DECLSPEC_NOTHROW HRESULT CreateInkStyle(const D2D1_INK_STYLE_PROPERTIES &ink_style_properties, ID2D1InkStyle **ink_style) {
    return CreateInkStyle(&ink_style_properties, ink_style);
  }

  COM_DECLSPEC_NOTHROW HRESULT CreateImageSourceFromWic(IWICBitmapSource *wic_bitmap_source, D2D1_IMAGE_SOURCE_LOADING_OPTIONS loading_options, ID2D1ImageSourceFromWic **image_source) {
    return CreateImageSourceFromWic(wic_bitmap_source, loading_options, D2D1_ALPHA_MODE_UNKNOWN, image_source);
  }

  COM_DECLSPEC_NOTHROW HRESULT CreateImageSourceFromWic(IWICBitmapSource *wic_bitmap_source, ID2D1ImageSourceFromWic **image_source) {
    return CreateImageSourceFromWic(wic_bitmap_source, D2D1_IMAGE_SOURCE_LOADING_OPTIONS_NONE, D2D1_ALPHA_MODE_UNKNOWN, image_source);
  }

  COM_DECLSPEC_NOTHROW void DrawGdiMetafile(ID2D1GdiMetafile *gdi_metafile, const D2D1_RECT_F &destination_rectangle, const D2D1_RECT_F &source_rectangle) {
    return DrawGdiMetafile(gdi_metafile, &destination_rectangle, &source_rectangle);
  }

  COM_DECLSPEC_NOTHROW void DrawGdiMetafile(ID2D1GdiMetafile *gdi_metafile, const D2D1_RECT_F &destination_rectangle, const D2D1_RECT_F *source_rectangle = NULL) {
    return DrawGdiMetafile(gdi_metafile, &destination_rectangle, source_rectangle);
  }
};
#else
typedef interface ID2D1DeviceContext2 ID2D1DeviceContext2;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1DeviceContext2, 0x394ea6a3, 0x0c34, 0x4321, 0x95, 0x0b, 0x6c, 0xa2, 0x0f, 0x0b, 0xe6, 0xc7);
__CRT_UUID_DECL(ID2D1DeviceContext2, 0x394ea6a3, 0x0c34, 0x4321, 0x95, 0x0b, 0x6c, 0xa2, 0x0f, 0x0b, 0xe6, 0xc7);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1Device2 : public ID2D1Device1
{
  STDMETHOD(CreateDeviceContext)(D2D1_DEVICE_CONTEXT_OPTIONS options, ID2D1DeviceContext2 **device_context2) PURE;

  using ID2D1Device1::CreateDeviceContext;
  using ID2D1Device::CreateDeviceContext;

  STDMETHOD_(void, FlushDeviceContexts)(ID2D1Bitmap *bitmap) PURE;
  STDMETHOD(GetDxgiDevice)(IDXGIDevice **dxgi_device) PURE;
};
#else
typedef interface ID2D1Device2 ID2D1Device2;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1Device2, 0xa44472e1, 0x8dfb, 0x4e60, 0x84, 0x92, 0x6e, 0x28, 0x61, 0xc9, 0xca, 0x8b);
__CRT_UUID_DECL(ID2D1Device2, 0xa44472e1, 0x8dfb, 0x4e60, 0x84, 0x92, 0x6e, 0x28, 0x61, 0xc9, 0xca, 0x8b);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1Factory3 : public ID2D1Factory2
{
  STDMETHOD(CreateDevice)(IDXGIDevice *dxgi_device, ID2D1Device2 **d2d_device2) PURE;

  using ID2D1Factory2::CreateDevice;
  using ID2D1Factory1::CreateDevice;
};
#else
typedef interface ID2D1Factory3 ID2D1Factory3;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1Factory3, 0x0869759f, 0x4f00, 0x413f, 0xb0, 0x3e, 0x2b, 0xda, 0x45, 0x40, 0x4d, 0x0f);
__CRT_UUID_DECL(ID2D1Factory3, 0x0869759f, 0x4f00, 0x413f, 0xb0, 0x3e, 0x2b, 0xda, 0x45, 0x40, 0x4d, 0x0f);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1CommandSink2 : public ID2D1CommandSink1
{
  STDMETHOD(DrawInk)(ID2D1Ink *ink, ID2D1Brush *brush, ID2D1InkStyle *ink_style) PURE;
  STDMETHOD(DrawGradientMesh)(ID2D1GradientMesh *gradient_mesh) PURE;
  STDMETHOD(DrawGdiMetafile)(ID2D1GdiMetafile *gdi_metafile, const D2D1_RECT_F *destination_rectangle, const D2D1_RECT_F *source_rectangle) PURE;

  using ID2D1CommandSink::DrawGdiMetafile;
};
#else
typedef interface ID2D1CommandSink2 ID2D1CommandSink2;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1CommandSink2, 0x3bab440e, 0x417e, 0x47df, 0xa2, 0xe2, 0xbc, 0x0b, 0xe6, 0xa0, 0x09, 0x16);
__CRT_UUID_DECL(ID2D1CommandSink2, 0x3bab440e, 0x417e, 0x47df, 0xa2, 0xe2, 0xbc, 0x0b, 0xe6, 0xa0, 0x09, 0x16);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1GdiMetafile1 : public ID2D1GdiMetafile
{
  STDMETHOD(GetDpi)(FLOAT *dpi_x, FLOAT *dpi_y) PURE;
  STDMETHOD(GetSourceBounds)(D2D1_RECT_F *bounds) PURE;
};
#else
typedef interface ID2D1GdiMetafile1 ID2D1GdiMetafile1;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1GdiMetafile1, 0x2e69f9e8, 0xdd3f, 0x4bf9, 0x95, 0xba, 0xc0, 0x4f, 0x49, 0xd7, 0x88, 0xdf);
__CRT_UUID_DECL(ID2D1GdiMetafile1, 0x2e69f9e8, 0xdd3f, 0x4bf9, 0x95, 0xba, 0xc0, 0x4f, 0x49, 0xd7, 0x88, 0xdf);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1GdiMetafileSink1 : public ID2D1GdiMetafileSink
{
  STDMETHOD(ProcessRecord)(DWORD record_type, const void *record_data, DWORD record_data_size, UINT32 flags) PURE;

  using ID2D1GdiMetafileSink::ProcessRecord;
};
#else
typedef interface ID2D1GdiMetafileSink1 ID2D1GdiMetafileSink1;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1GdiMetafileSink1, 0xfd0ecb6b, 0x91e6, 0x411e, 0x86, 0x55, 0x39, 0x5e, 0x76, 0x0f, 0x91, 0xb4);
__CRT_UUID_DECL(ID2D1GdiMetafileSink1, 0xfd0ecb6b, 0x91e6, 0x411e, 0x86, 0x55, 0x39, 0x5e, 0x76, 0x0f, 0x91, 0xb4);

#if NTDDI_VERSION >= NTDDI_WIN10_TH2

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1SpriteBatch : public ID2D1Resource
{
  STDMETHOD(AddSprites)(
    UINT32 sprite_count,
    const D2D1_RECT_F *destination_rectangles,
    const D2D1_RECT_U *source_rectangles = NULL,
    const D2D1_COLOR_F *colors = NULL,
    const D2D1_MATRIX_3X2_F *transforms = NULL,
    UINT32 destination_rectangles_stride = sizeof(D2D1_RECT_F),
    UINT32 source_rectangles_stride = sizeof(D2D1_RECT_U),
    UINT32 colors_stride = sizeof(D2D1_COLOR_F),
    UINT32 transforms_stride = sizeof(D2D1_MATRIX_3X2_F)
    ) PURE;

  STDMETHOD(SetSprites)(
    UINT32 start_index,
    UINT32 sprite_count,
    const D2D1_RECT_F *destination_rectangles = NULL,
    const D2D1_RECT_U *source_rectangles = NULL,
    const D2D1_COLOR_F *colors = NULL,
    const D2D1_MATRIX_3X2_F *transforms = NULL,
    UINT32 destination_rectangles_stride = sizeof(D2D1_RECT_F),
    UINT32 source_rectangles_stride = sizeof(D2D1_RECT_U),
    UINT32 colors_stride = sizeof(D2D1_COLOR_F),
    UINT32 transforms_stride = sizeof(D2D1_MATRIX_3X2_F)
    ) PURE;

  STDMETHOD(GetSprites)(
    UINT32 start_index,
    UINT32 sprite_count,
    D2D1_RECT_F *destination_rectangles = NULL,
    D2D1_RECT_U *source_rectangles = NULL,
    D2D1_COLOR_F *colors = NULL,
    D2D1_MATRIX_3X2_F *transforms = NULL
    ) const PURE;

  STDMETHOD_(UINT32, GetSpriteCount)() const PURE;
  STDMETHOD_(void, Clear)() PURE;
};
#else
typedef interface ID2D1SpriteBatch ID2D1SpriteBatch;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1SpriteBatch, 0x4dc583bf, 0x3a10, 0x438a, 0x87, 0x22, 0xe9, 0x76, 0x52, 0x24, 0xf1, 0xf1);
__CRT_UUID_DECL(ID2D1SpriteBatch, 0x4dc583bf, 0x3a10, 0x438a, 0x87, 0x22, 0xe9, 0x76, 0x52, 0x24, 0xf1, 0xf1);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1DeviceContext3 : public ID2D1DeviceContext2
{
  STDMETHOD(CreateSpriteBatch)(ID2D1SpriteBatch **sprite_batch) PURE;

  STDMETHOD_(void, DrawSpriteBatch)(
    ID2D1SpriteBatch *sprite_batch,
    UINT32 start_index,
    UINT32 sprite_count,
    ID2D1Bitmap *bitmap,
    D2D1_BITMAP_INTERPOLATION_MODE interpolation_mode = D2D1_BITMAP_INTERPOLATION_MODE_LINEAR,
    D2D1_SPRITE_OPTIONS sprite_options = D2D1_SPRITE_OPTIONS_NONE
    ) PURE;

  COM_DECLSPEC_NOTHROW
  void
  DrawSpriteBatch(
    ID2D1SpriteBatch *sprite_batch,
    ID2D1Bitmap *bitmap,
    D2D1_BITMAP_INTERPOLATION_MODE interpolation_mode = D2D1_BITMAP_INTERPOLATION_MODE_LINEAR,
    D2D1_SPRITE_OPTIONS sprite_options = D2D1_SPRITE_OPTIONS_NONE
    )
  {
    return DrawSpriteBatch(sprite_batch, 0, sprite_batch->GetSpriteCount(), bitmap, interpolation_mode, sprite_options);
  }
};
#else
typedef interface ID2D1DeviceContext3 ID2D1DeviceContext3;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1DeviceContext3, 0x235a7496, 0x8351, 0x414c, 0xbc, 0xd4, 0x66, 0x72, 0xab, 0x2d, 0x8e, 0x00);
__CRT_UUID_DECL(ID2D1DeviceContext3, 0x235a7496, 0x8351, 0x414c, 0xbc, 0xd4, 0x66, 0x72, 0xab, 0x2d, 0x8e, 0x00);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1Device3 : public ID2D1Device2
{
  STDMETHOD(CreateDeviceContext)(D2D1_DEVICE_CONTEXT_OPTIONS options, ID2D1DeviceContext3 **device_context3) PURE;

  using ID2D1Device2::CreateDeviceContext;
  using ID2D1Device1::CreateDeviceContext;
  using ID2D1Device::CreateDeviceContext;
};
#else
typedef interface ID2D1Device3 ID2D1Device3;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1Device3, 0x852f2087, 0x802c, 0x4037, 0xab, 0x60, 0xff, 0x2e, 0x7e, 0xe6, 0xfc, 0x01);
__CRT_UUID_DECL(ID2D1Device3, 0x852f2087, 0x802c, 0x4037, 0xab, 0x60, 0xff, 0x2e, 0x7e, 0xe6, 0xfc, 0x01);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1Factory4 : public ID2D1Factory3
{
  STDMETHOD(CreateDevice)(IDXGIDevice *dxgi_device, ID2D1Device3 **d2d_device3) PURE;

  using ID2D1Factory3::CreateDevice;
  using ID2D1Factory2::CreateDevice;
  using ID2D1Factory1::CreateDevice;
};
#else
typedef interface ID2D1Factory4 ID2D1Factory4;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1Factory4, 0xbd4ec2d2, 0x0662, 0x4bee, 0xba, 0x8e, 0x6f, 0x29, 0xf0, 0x32, 0xe0, 0x96);
__CRT_UUID_DECL(ID2D1Factory4, 0xbd4ec2d2, 0x0662, 0x4bee, 0xba, 0x8e, 0x6f, 0x29, 0xf0, 0x32, 0xe0, 0x96);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1CommandSink3 : public ID2D1CommandSink2
{
  STDMETHOD(DrawSpriteBatch)(
    ID2D1SpriteBatch *sprite_batch,
    UINT32 start_index,
    UINT32 sprite_count,
    ID2D1Bitmap *bitmap,
    D2D1_BITMAP_INTERPOLATION_MODE interpolation_mode,
    D2D1_SPRITE_OPTIONS sprite_options
    ) PURE;
};
#else
typedef interface ID2D1CommandSink3 ID2D1CommandSink3;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1CommandSink3, 0x18079135, 0x4cf3, 0x4868, 0xbc, 0x8e, 0x06, 0x06, 0x7e, 0x6d, 0x24, 0x2d);
__CRT_UUID_DECL(ID2D1CommandSink3, 0x18079135, 0x4cf3, 0x4868, 0xbc, 0x8e, 0x06, 0x06, 0x7e, 0x6d, 0x24, 0x2d);

#endif /* NTDDI_VERSION >= NTDDI_WIN10_TH2 */

#if NTDDI_VERSION >= NTDDI_WIN10_RS1

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1SvgGlyphStyle : public ID2D1Resource
{
  STDMETHOD(SetFill)(ID2D1Brush *brush) PURE;
  STDMETHOD_(void, GetFill)(ID2D1Brush **brush) PURE;

  STDMETHOD(SetStroke)(
    ID2D1Brush *brush,
    FLOAT stroke_width = 1.0f,
    const FLOAT *dashes = NULL,
    UINT32 dashes_count = 0,
    FLOAT dash_offset = 1.0f
    ) PURE;

  STDMETHOD_(UINT32, GetStrokeDashesCount)() PURE;

  STDMETHOD_(void, GetStroke)(
    ID2D1Brush **brush,
    FLOAT *stroke_width = NULL,
    FLOAT *dashes = NULL,
    UINT32 dashes_count = 0,
    FLOAT *dash_offset = NULL
    ) PURE;
};
#else
typedef interface ID2D1SvgGlyphStyle ID2D1SvgGlyphStyle;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1SvgGlyphStyle, 0xaf671749, 0xd241, 0x4db8, 0x8e, 0x41, 0xdc, 0xc2, 0xe5, 0xc1, 0xa4, 0x38);
__CRT_UUID_DECL(ID2D1SvgGlyphStyle, 0xaf671749, 0xd241, 0x4db8, 0x8e, 0x41, 0xdc, 0xc2, 0xe5, 0xc1, 0xa4, 0x38);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1DeviceContext4 : public ID2D1DeviceContext3
{
  STDMETHOD(CreateSvgGlyphStyle)(ID2D1SvgGlyphStyle **svg_glyph_style) PURE;

  STDMETHOD_(void, DrawText)(
    const WCHAR *string,
    UINT32 string_length,
    IDWriteTextFormat *text_format,
    const D2D1_RECT_F *layout_rect,
    ID2D1Brush *default_fill_brush,
    ID2D1SvgGlyphStyle *svg_glyph_style,
    UINT32 color_palette_index = 0,
    D2D1_DRAW_TEXT_OPTIONS options = D2D1_DRAW_TEXT_OPTIONS_ENABLE_COLOR_FONT,
    DWRITE_MEASURING_MODE measuring_mode = DWRITE_MEASURING_MODE_NATURAL
    ) PURE;

  using ID2D1RenderTarget::DrawText;

  STDMETHOD_(void, DrawTextLayout)(
    D2D1_POINT_2F origin,
    IDWriteTextLayout *text_layout,
    ID2D1Brush *default_fill_brush,
    ID2D1SvgGlyphStyle *svg_glyph_style,
    UINT32 color_palette_index = 0,
    D2D1_DRAW_TEXT_OPTIONS options = D2D1_DRAW_TEXT_OPTIONS_ENABLE_COLOR_FONT
    ) PURE;

  using ID2D1RenderTarget::DrawTextLayout;

  STDMETHOD_(void, DrawColorBitmapGlyphRun)(
    DWRITE_GLYPH_IMAGE_FORMATS glyph_image_format,
    D2D1_POINT_2F baseline_origin,
    const DWRITE_GLYPH_RUN *glyph_run,
    DWRITE_MEASURING_MODE measuring_mode = DWRITE_MEASURING_MODE_NATURAL,
    D2D1_COLOR_BITMAP_GLYPH_SNAP_OPTION bitmap_snap_option = D2D1_COLOR_BITMAP_GLYPH_SNAP_OPTION_DEFAULT
    ) PURE;

  STDMETHOD_(void, DrawSvgGlyphRun)(
    D2D1_POINT_2F baseline_origin,
    const DWRITE_GLYPH_RUN *glyph_run,
    ID2D1Brush *default_fill_brush = NULL,
    ID2D1SvgGlyphStyle *svg_glyph_style = NULL,
    UINT32 color_palette_index = 0,
    DWRITE_MEASURING_MODE measuring_mode = DWRITE_MEASURING_MODE_NATURAL
    ) PURE;

  STDMETHOD(GetColorBitmapGlyphImage)(
    DWRITE_GLYPH_IMAGE_FORMATS glyph_image_format,
    D2D1_POINT_2F glyph_origin,
    IDWriteFontFace *font_face,
    FLOAT font_em_size,
    UINT16 glyph_index,
    WINBOOL is_sideways,
    const D2D1_MATRIX_3X2_F *world_transform,
    FLOAT dpi_x,
    FLOAT dpi_y,
    D2D1_MATRIX_3X2_F *glyph_transform,
    ID2D1Image **glyph_image
    ) PURE;

  STDMETHOD(GetSvgGlyphImage)(
    D2D1_POINT_2F glyph_origin,
    IDWriteFontFace *font_face,
    FLOAT font_em_size,
    UINT16 glyph_index,
    WINBOOL is_sideways,
    const D2D1_MATRIX_3X2_F *world_transform,
    ID2D1Brush *default_fill_brush,
    ID2D1SvgGlyphStyle *svg_glyph_style,
    UINT32 color_palette_index,
    D2D1_MATRIX_3X2_F *glyph_transform,
    ID2D1CommandList **glyph_image
    ) PURE;

  COM_DECLSPEC_NOTHROW void DrawText(
    const WCHAR *string,
    UINT32 string_length,
    IDWriteTextFormat *text_format,
    const D2D1_RECT_F &layout_rect,
    ID2D1Brush *default_fill_brush,
    ID2D1SvgGlyphStyle *svg_glyph_style,
    UINT32 color_palette_index = 0,
    D2D1_DRAW_TEXT_OPTIONS options = D2D1_DRAW_TEXT_OPTIONS_ENABLE_COLOR_FONT,
    DWRITE_MEASURING_MODE measuring_mode = DWRITE_MEASURING_MODE_NATURAL
    )
  {
    return DrawText(string, string_length, text_format, &layout_rect, default_fill_brush, svg_glyph_style, color_palette_index, options, measuring_mode);
  }
};
#else
typedef interface ID2D1DeviceContext4 ID2D1DeviceContext4;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1DeviceContext4, 0x8c427831, 0x3d90, 0x4476, 0xb6, 0x47, 0xc4, 0xfa, 0xe3, 0x49, 0xe4, 0xdb);
__CRT_UUID_DECL(ID2D1DeviceContext4, 0x8c427831, 0x3d90, 0x4476, 0xb6, 0x47, 0xc4, 0xfa, 0xe3, 0x49, 0xe4, 0xdb);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1Device4 : public ID2D1Device3
{
  STDMETHOD(CreateDeviceContext)(D2D1_DEVICE_CONTEXT_OPTIONS options, ID2D1DeviceContext4 **device_context4) PURE;

  using ID2D1Device3::CreateDeviceContext;
  using ID2D1Device2::CreateDeviceContext;
  using ID2D1Device1::CreateDeviceContext;
  using ID2D1Device::CreateDeviceContext;

  STDMETHOD_(void, SetMaximumColorGlyphCacheMemory)(UINT64 maximum_in_bytes) PURE;
  STDMETHOD_(UINT64, GetMaximumColorGlyphCacheMemory)() const PURE;
};
#else
typedef interface ID2D1Device4 ID2D1Device4;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1Device4, 0xd7bdb159, 0x5683, 0x4a46, 0xbc, 0x9c, 0x72, 0xdc, 0x72, 0x0b, 0x85, 0x8b);
__CRT_UUID_DECL(ID2D1Device4, 0xd7bdb159, 0x5683, 0x4a46, 0xbc, 0x9c, 0x72, 0xdc, 0x72, 0x0b, 0x85, 0x8b);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1Factory5 : public ID2D1Factory4
{
  STDMETHOD(CreateDevice)(IDXGIDevice *dxgi_device, ID2D1Device4 **d2d_device4) PURE;

  using ID2D1Factory4::CreateDevice;
  using ID2D1Factory3::CreateDevice;
  using ID2D1Factory2::CreateDevice;
  using ID2D1Factory1::CreateDevice;
};
#else
typedef interface ID2D1Factory5 ID2D1Factory5;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1Factory5, 0xc4349994, 0x838e, 0x4b0f, 0x8c, 0xab, 0x44, 0x99, 0x7d, 0x9e, 0xea, 0xcc);
__CRT_UUID_DECL(ID2D1Factory5, 0xc4349994, 0x838e, 0x4b0f, 0x8c, 0xab, 0x44, 0x99, 0x7d, 0x9e, 0xea, 0xcc);

#endif /* NTDDI_VERSION >= NTDDI_WIN10_RS1 */

#if NTDDI_VERSION >= NTDDI_WIN10_RS2

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1CommandSink4 : public ID2D1CommandSink3
{
  STDMETHOD(SetPrimitiveBlend2)(D2D1_PRIMITIVE_BLEND primitive_blend) PURE;
};
#else
typedef interface ID2D1CommandSink4 ID2D1CommandSink4;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1CommandSink4, 0xc78a6519, 0x40d6, 0x4218, 0xb2, 0xde, 0xbe, 0xee, 0xb7, 0x44, 0xbb, 0x3e);
__CRT_UUID_DECL(ID2D1CommandSink4, 0xc78a6519, 0x40d6, 0x4218, 0xb2, 0xde, 0xbe, 0xee, 0xb7, 0x44, 0xbb, 0x3e);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1ColorContext1 : public ID2D1ColorContext
{
  STDMETHOD_(D2D1_COLOR_CONTEXT_TYPE, GetColorContextType)() const PURE;
  STDMETHOD_(DXGI_COLOR_SPACE_TYPE, GetDXGIColorSpace)() const PURE;
  STDMETHOD(GetSimpleColorProfile)(D2D1_SIMPLE_COLOR_PROFILE *simple_profile) const PURE;
};
#else
typedef interface ID2D1ColorContext1 ID2D1ColorContext1;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1ColorContext1, 0x1ab42875, 0xc57f, 0x4be9, 0xbd, 0x85, 0x9c, 0xd7, 0x8d, 0x6f, 0x55, 0xee);
__CRT_UUID_DECL(ID2D1ColorContext1, 0x1ab42875, 0xc57f, 0x4be9, 0xbd, 0x85, 0x9c, 0xd7, 0x8d, 0x6f, 0x55, 0xee);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1DeviceContext5 : public ID2D1DeviceContext4
{
  STDMETHOD(CreateSvgDocument)(IStream *input_xml_stream, D2D1_SIZE_F viewport_size, ID2D1SvgDocument **svg_document) PURE;
  STDMETHOD_(void, DrawSvgDocument)(ID2D1SvgDocument *svg_document) PURE;
  STDMETHOD(CreateColorContextFromDxgiColorSpace)(DXGI_COLOR_SPACE_TYPE color_space, ID2D1ColorContext1 **color_context) PURE;
  STDMETHOD(CreateColorContextFromSimpleColorProfile)(const D2D1_SIMPLE_COLOR_PROFILE *simple_profile, ID2D1ColorContext1 **color_context) PURE;

  COM_DECLSPEC_NOTHROW HRESULT CreateColorContextFromSimpleColorProfile(const D2D1_SIMPLE_COLOR_PROFILE &simple_profile, ID2D1ColorContext1 **color_context) {
    return CreateColorContextFromSimpleColorProfile(&simple_profile, color_context);
  }
};
#else
typedef interface ID2D1DeviceContext5 ID2D1DeviceContext5;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1DeviceContext5, 0x7836d248, 0x68cc, 0x4df6, 0xb9, 0xe8, 0xde, 0x99, 0x1b, 0xf6, 0x2e, 0xb7);
__CRT_UUID_DECL(ID2D1DeviceContext5, 0x7836d248, 0x68cc, 0x4df6, 0xb9, 0xe8, 0xde, 0x99, 0x1b, 0xf6, 0x2e, 0xb7);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1Device5 : public ID2D1Device4
{
  STDMETHOD(CreateDeviceContext)(D2D1_DEVICE_CONTEXT_OPTIONS options, ID2D1DeviceContext5 **device_context5) PURE;

  using ID2D1Device4::CreateDeviceContext;
  using ID2D1Device3::CreateDeviceContext;
  using ID2D1Device2::CreateDeviceContext;
  using ID2D1Device1::CreateDeviceContext;
  using ID2D1Device::CreateDeviceContext;
};
#else
typedef interface ID2D1Device5 ID2D1Device5;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1Device5, 0xd55ba0a4, 0x6405, 0x4694, 0xae, 0xf5, 0x08, 0xee, 0x1a, 0x43, 0x58, 0xb4);
__CRT_UUID_DECL(ID2D1Device5, 0xd55ba0a4, 0x6405, 0x4694, 0xae, 0xf5, 0x08, 0xee, 0x1a, 0x43, 0x58, 0xb4);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1Factory6 : public ID2D1Factory5
{
  STDMETHOD(CreateDevice)(IDXGIDevice *dxgi_device, ID2D1Device5 **d2d_device5) PURE;

  using ID2D1Factory5::CreateDevice;
  using ID2D1Factory4::CreateDevice;
  using ID2D1Factory3::CreateDevice;
  using ID2D1Factory2::CreateDevice;
  using ID2D1Factory1::CreateDevice;
};
#else
typedef interface ID2D1Factory6 ID2D1Factory6;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1Factory6, 0xf9976f46, 0xf642, 0x44c1, 0x97, 0xca, 0xda, 0x32, 0xea, 0x2a, 0x26, 0x35);
__CRT_UUID_DECL(ID2D1Factory6, 0xf9976f46, 0xf642, 0x44c1, 0x97, 0xca, 0xda, 0x32, 0xea, 0x2a, 0x26, 0x35);

#endif /* NTDDI_VERSION >= NTDDI_WIN10_RS2 */

#if NTDDI_VERSION >= NTDDI_WIN10_RS3

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1CommandSink5 : public ID2D1CommandSink4
{
  STDMETHOD(BlendImage)(
    ID2D1Image *image,
    D2D1_BLEND_MODE blend_mode,
    const D2D1_POINT_2F *target_offset,
    const D2D1_RECT_F *image_rectangle,
    D2D1_INTERPOLATION_MODE interpolation_mode
    ) PURE;
};
#else
typedef interface ID2D1CommandSink5 ID2D1CommandSink5;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1CommandSink5, 0x7047dd26, 0xb1e7, 0x44a7, 0x95, 0x9a, 0x83, 0x49, 0xe2, 0x14, 0x4f, 0xa8);
__CRT_UUID_DECL(ID2D1CommandSink5, 0x7047dd26, 0xb1e7, 0x44a7, 0x95, 0x9a, 0x83, 0x49, 0xe2, 0x14, 0x4f, 0xa8);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1DeviceContext6 : public ID2D1DeviceContext5
{
  STDMETHOD_(void, BlendImage)(
    ID2D1Image *image,
    D2D1_BLEND_MODE blend_mode,
    const D2D1_POINT_2F *target_offset = NULL,
    const D2D1_RECT_F *image_rectangle = NULL,
    D2D1_INTERPOLATION_MODE interpolation_mode = D2D1_INTERPOLATION_MODE_LINEAR
    ) PURE;
};
#else
typedef interface ID2D1DeviceContext6 ID2D1DeviceContext6;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1DeviceContext6, 0x985f7e37, 0x4ed0, 0x4a19, 0x98, 0xa3, 0x15, 0xb0, 0xed, 0xfd, 0xe3, 0x06);
__CRT_UUID_DECL(ID2D1DeviceContext6, 0x985f7e37, 0x4ed0, 0x4a19, 0x98, 0xa3, 0x15, 0xb0, 0xed, 0xfd, 0xe3, 0x06);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1Device6 : public ID2D1Device5
{
  STDMETHOD(CreateDeviceContext)(D2D1_DEVICE_CONTEXT_OPTIONS options, ID2D1DeviceContext6 **device_context6) PURE;

  using ID2D1Device5::CreateDeviceContext;
  using ID2D1Device4::CreateDeviceContext;
  using ID2D1Device3::CreateDeviceContext;
  using ID2D1Device2::CreateDeviceContext;
  using ID2D1Device1::CreateDeviceContext;
  using ID2D1Device::CreateDeviceContext;
};
#else
typedef interface ID2D1Device6 ID2D1Device6;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1Device6, 0x7bfef914, 0x2d75, 0x4bad, 0xbe, 0x87, 0xe1, 0x8d, 0xdb, 0x07, 0x7b, 0x6d);
__CRT_UUID_DECL(ID2D1Device6, 0x7bfef914, 0x2d75, 0x4bad, 0xbe, 0x87, 0xe1, 0x8d, 0xdb, 0x07, 0x7b, 0x6d);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1Factory7 : public ID2D1Factory6
{
  STDMETHOD(CreateDevice)(IDXGIDevice *dxgi_device, ID2D1Device6 **d2d_device6) PURE;

  using ID2D1Factory6::CreateDevice;
  using ID2D1Factory5::CreateDevice;
  using ID2D1Factory4::CreateDevice;
  using ID2D1Factory3::CreateDevice;
  using ID2D1Factory2::CreateDevice;
  using ID2D1Factory1::CreateDevice;
};
#else
typedef interface ID2D1Factory7 ID2D1Factory7;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1Factory7, 0xbdc2bdd3, 0xb96c, 0x4de6, 0xbd, 0xf7, 0x99, 0xd4, 0x74, 0x54, 0x54, 0xde);
__CRT_UUID_DECL(ID2D1Factory7, 0xbdc2bdd3, 0xb96c, 0x4de6, 0xbd, 0xf7, 0x99, 0xd4, 0x74, 0x54, 0x54, 0xde);

#endif /* NTDDI_VERSION >= NTDDI_WIN10_RS3 */

#ifdef __cplusplus
extern "C"
{
#endif

#if NTDDI_VERSION >= NTDDI_WINTHRESHOLD
  void WINAPI
  D2D1GetGradientMeshInteriorPointsFromCoonsPatch(
    const D2D1_POINT_2F *point0,
    const D2D1_POINT_2F *point1,
    const D2D1_POINT_2F *point2,
    const D2D1_POINT_2F *point3,
    const D2D1_POINT_2F *point4,
    const D2D1_POINT_2F *point5,
    const D2D1_POINT_2F *point6,
    const D2D1_POINT_2F *point7,
    const D2D1_POINT_2F *point8,
    const D2D1_POINT_2F *point9,
    const D2D1_POINT_2F *point10,
    const D2D1_POINT_2F *point11,
    D2D1_POINT_2F *tensor_point11,
    D2D1_POINT_2F *tensor_point12,
    D2D1_POINT_2F *tensor_point21,
    D2D1_POINT_2F *tensor_point22
    );
#endif /* NTDDI_VERSION >= NTDDI_WINTHRESHOLD */

#ifdef __cplusplus
}
#endif

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP) */

#include <d2d1_3helper.h>
#endif /* _D2D1_3_H_ */
