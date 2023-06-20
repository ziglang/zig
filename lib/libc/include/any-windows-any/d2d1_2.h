/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _D2D1_2_H_
#define _D2D1_2_H_

#ifndef _D2D1_1_H_
#include <d2d1_1.h>
#endif

#ifndef _D2D1_EFFECTS_1_
#include <d2d1effects_1.h>
#endif

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1Device1;
#else
typedef interface ID2D1Device1 ID2D1Device1;
#endif

typedef enum D2D1_RENDERING_PRIORITY {
  D2D1_RENDERING_PRIORITY_NORMAL = 0,
  D2D1_RENDERING_PRIORITY_LOW = 1,
  D2D1_RENDERING_PRIORITY_FORCE_DWORD = 0xffffffff
} D2D1_RENDERING_PRIORITY;

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1GeometryRealization : public ID2D1Resource
{
};
#else
typedef interface ID2D1GeometryRealization ID2D1GeometryRealization;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1GeometryRealization, 0xa16907d7, 0xbc02, 0x4801, 0x99, 0xe8, 0x8c, 0xf7, 0xf4, 0x85, 0xf7, 0x74);
__CRT_UUID_DECL(ID2D1GeometryRealization, 0xa16907d7, 0xbc02, 0x4801, 0x99, 0xe8, 0x8c, 0xf7, 0xf4, 0x85, 0xf7, 0x74);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1DeviceContext1 : public ID2D1DeviceContext
{
  STDMETHOD(CreateFilledGeometryRealization)(ID2D1Geometry *geometry, FLOAT flattening_tolerance, ID2D1GeometryRealization **geometry_realization) PURE;
  STDMETHOD(CreateStrokedGeometryRealization)(ID2D1Geometry *geometry, FLOAT flattening_tolerance, FLOAT stroke_width, ID2D1StrokeStyle *stroke_style, ID2D1GeometryRealization **geometry_realization) PURE;
  STDMETHOD_(void, DrawGeometryRealization)(ID2D1GeometryRealization *geometry_realization, ID2D1Brush *brush) PURE;
};
#else
typedef interface ID2D1DeviceContext1 ID2D1DeviceContext1;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1DeviceContext1, 0xd37f57e4, 0x6908, 0x459f, 0xa1, 0x99, 0xe7, 0x2f, 0x24, 0xf7, 0x99, 0x87);
__CRT_UUID_DECL(ID2D1DeviceContext1, 0xd37f57e4, 0x6908, 0x459f, 0xa1, 0x99, 0xe7, 0x2f, 0x24, 0xf7, 0x99, 0x87);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1Device1 : public ID2D1Device
{
  STDMETHOD_(D2D1_RENDERING_PRIORITY, GetRenderingPriority)() PURE;
  STDMETHOD_(void, SetRenderingPriority)(D2D1_RENDERING_PRIORITY rendering_priority) PURE;
  STDMETHOD(CreateDeviceContext)(D2D1_DEVICE_CONTEXT_OPTIONS options, ID2D1DeviceContext1 **device_context1) PURE;

  using ID2D1Device::CreateDeviceContext;
};
#else
typedef interface ID2D1Device1 ID2D1Device1;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1Device1, 0xd21768e1, 0x23a4, 0x4823, 0xa1, 0x4b, 0x7c, 0x3e, 0xba, 0x85, 0xd6, 0x58);
__CRT_UUID_DECL(ID2D1Device1, 0xd21768e1, 0x23a4, 0x4823, 0xa1, 0x4b, 0x7c, 0x3e, 0xba, 0x85, 0xd6, 0x58);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1Factory2 : public ID2D1Factory1
{
  STDMETHOD(CreateDevice)(IDXGIDevice *dxgi_device, ID2D1Device1 **d2d_device1) PURE;

  using ID2D1Factory1::CreateDevice;
};
#else
typedef interface ID2D1Factory2 ID2D1Factory2;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1Factory2, 0x94f81a73, 0x9212, 0x4376, 0x9c, 0x58, 0xb1, 0x6a, 0x3a, 0x0d, 0x39, 0x92);
__CRT_UUID_DECL(ID2D1Factory2, 0x94f81a73, 0x9212, 0x4376, 0x9c, 0x58, 0xb1, 0x6a, 0x3a, 0x0d, 0x39, 0x92);

#ifndef D2D_USE_C_DEFINITIONS
interface ID2D1CommandSink1 : public ID2D1CommandSink
{
  STDMETHOD(SetPrimitiveBlend1)(D2D1_PRIMITIVE_BLEND primitive_blend) PURE;
};
#else
typedef interface ID2D1CommandSink1 ID2D1CommandSink1;
/* FIXME: Add full C declaration */
#endif

DEFINE_GUID(IID_ID2D1CommandSink1, 0x9eb767fd, 0x4269, 0x4467, 0xb8, 0xc2, 0xeb, 0x30, 0xcb, 0x30, 0x57, 0x43);
__CRT_UUID_DECL(ID2D1CommandSink1, 0x9eb767fd, 0x4269, 0x4467, 0xb8, 0xc2, 0xeb, 0x30, 0xcb, 0x30, 0x57, 0x43);

#ifdef __cplusplus
extern "C"
{
#endif

#if NTDDI_VERSION >= NTDDI_WINBLUE
  FLOAT WINAPI D2D1ComputeMaximumScaleFactor(CONST D2D1_MATRIX_3X2_F *matrix);
#endif

#ifdef __cplusplus
}
#endif

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP) */

#include <d2d1_2helper.h>

#endif /* #ifndef _D2D1_2_H_ */
