/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _DCOMP_H_
#define _DCOMP_H_

#include <d2dbasetypes.h>
#ifndef D3DMATRIX_DEFINED
#include <d3d9types.h>
#endif
#include <d2d1_1.h>
#include <winapifamily.h>

#include <dcomptypes.h>
#include <dcompanimation.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#undef INTERFACE
#define INTERFACE IDCompositionSurface
DECLARE_INTERFACE_IID_(IDCompositionSurface,IUnknown,"bb8a4953-2c99-4f5a-96f5-4819027fa3ac")
{
    STDMETHOD(BeginDraw)(THIS_ const RECT*,REFIID,void**,POINT*) PURE;
    STDMETHOD(EndDraw)(THIS) PURE;
    STDMETHOD(SuspendDraw)(THIS) PURE;
    STDMETHOD(ResumeDraw)(THIS) PURE;
    STDMETHOD(Scroll)(THIS_ const RECT*,const RECT*,int,int) PURE;
};

#undef INTERFACE
#define INTERFACE IDCompositionVirtualSurface
DECLARE_INTERFACE_IID_(IDCompositionVirtualSurface,IDCompositionSurface,"ae471c51-5f53-4a24-8d3e-d0c39c30b3f0")
{
    STDMETHOD(Resize)(THIS_ UINT,UINT) PURE;
    STDMETHOD(Trim)(THIS_ const RECT*,UINT) PURE;
};

#undef INTERFACE
#define INTERFACE IDCompositionEffect
DECLARE_INTERFACE_IID_(IDCompositionEffect,IUnknown,"ec81b08f-bfcb-4e8d-b193-a915587999e8")
{
};

#undef INTERFACE
#define INTERFACE IDCompositionTransform3D
DECLARE_INTERFACE_IID_(IDCompositionTransform3D,IDCompositionEffect,"71185722-246b-41f2-aad1-0443f7f4bfc2")
{
};

#undef INTERFACE
#define INTERFACE IDCompositionTransform
DECLARE_INTERFACE_IID_(IDCompositionTransform,IDCompositionTransform3D,"fd55faa7-37e0-4c20-95d2-9be45bc33f55")
{
};

#undef INTERFACE
#define INTERFACE IDCompositionTranslateTransform
DECLARE_INTERFACE_IID_(IDCompositionTranslateTransform,IDCompositionTransform,"06791122-c6f0-417d-8323-269e987f5954")
{
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetOffsetX)(THIS_ float) PURE;
    STDMETHOD(SetOffsetX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOffsetY)(THIS_ float) PURE;
    STDMETHOD(SetOffsetY)(THIS_ IDCompositionAnimation*) PURE;
#else
    STDMETHOD(SetOffsetX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOffsetX)(THIS_ float) PURE;
    STDMETHOD(SetOffsetY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOffsetY)(THIS_ float) PURE;
#endif
};

#undef INTERFACE
#define INTERFACE IDCompositionScaleTransform
DECLARE_INTERFACE_IID_(IDCompositionScaleTransform,IDCompositionTransform,"71fde914-40ef-45ef-bd51-68b037c339f9")
{
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetScaleX)(THIS_ float) PURE;
    STDMETHOD(SetScaleX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetScaleY)(THIS_ float) PURE;
    STDMETHOD(SetScaleY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterX)(THIS_ float) PURE;
    STDMETHOD(SetCenterX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterY)(THIS_ float) PURE;
    STDMETHOD(SetCenterY)(THIS_ IDCompositionAnimation*) PURE;
#else
    STDMETHOD(SetScaleX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetScaleX)(THIS_ float) PURE;
    STDMETHOD(SetScaleY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetScaleY)(THIS_ float) PURE;
    STDMETHOD(SetCenterX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterX)(THIS_ float) PURE;
    STDMETHOD(SetCenterY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterY)(THIS_ float) PURE;
#endif
};

#undef INTERFACE
#define INTERFACE IDCompositionRotateTransform
DECLARE_INTERFACE_IID_(IDCompositionRotateTransform,IDCompositionTransform,"641ed83c-ae96-46c5-90dc-32774cc5c6d5")
{
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetAngle)(THIS_ float) PURE;
    STDMETHOD(SetAngle)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterX)(THIS_ float) PURE;
    STDMETHOD(SetCenterX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterY)(THIS_ float) PURE;
    STDMETHOD(SetCenterY)(THIS_ IDCompositionAnimation*) PURE;
#else
    STDMETHOD(SetAngle)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetAngle)(THIS_ float) PURE;
    STDMETHOD(SetCenterX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterX)(THIS_ float) PURE;
    STDMETHOD(SetCenterY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterY)(THIS_ float) PURE;
#endif
};

#undef INTERFACE
#define INTERFACE IDCompositionSkewTransform
DECLARE_INTERFACE_IID_(IDCompositionSkewTransform,IDCompositionTransform,"e57aa735-dcdb-4c72-9c61-0591f58889ee")
{
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetAngleX)(THIS_ float) PURE;
    STDMETHOD(SetAngleX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetAngleY)(THIS_ float) PURE;
    STDMETHOD(SetAngleY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterX)(THIS_ float) PURE;
    STDMETHOD(SetCenterX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterY)(THIS_ float) PURE;
    STDMETHOD(SetCenterY)(THIS_ IDCompositionAnimation*) PURE;
#else
    STDMETHOD(SetAngleX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetAngleX)(THIS_ float) PURE;
    STDMETHOD(SetAngleY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetAngleY)(THIS_ float) PURE;
    STDMETHOD(SetCenterX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterX)(THIS_ float) PURE;
    STDMETHOD(SetCenterY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterY)(THIS_ float) PURE;
#endif
};

#undef INTERFACE
#define INTERFACE IDCompositionMatrixTransform
DECLARE_INTERFACE_IID_(IDCompositionMatrixTransform,IDCompositionTransform,"16cdff07-c503-419c-83f2-0965c7af1fa6")
{
    STDMETHOD(SetMatrix)(THIS_ const D2D_MATRIX_3X2_F&) PURE;
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetMatrixElement)(THIS_ int,int,float) PURE;
    STDMETHOD(SetMatrixElement)(THIS_ int,int,IDCompositionAnimation*) PURE;
#else
    STDMETHOD(SetMatrixElement)(THIS_ int,int,IDCompositionAnimation*) PURE;
    STDMETHOD(SetMatrixElement)(THIS_ int,int,float) PURE;
#endif
};

#undef INTERFACE
#define INTERFACE IDCompositionTranslateTransform3D
DECLARE_INTERFACE_IID_(IDCompositionTranslateTransform3D,IDCompositionTransform3D,"91636d4b-9ba1-4532-aaf7-e3344994d788")
{
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetOffsetX)(THIS_ float) PURE;
    STDMETHOD(SetOffsetX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOffsetY)(THIS_ float) PURE;
    STDMETHOD(SetOffsetY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOffsetZ)(THIS_ float) PURE;
    STDMETHOD(SetOffsetZ)(THIS_ IDCompositionAnimation*) PURE;
#else
    STDMETHOD(SetOffsetX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOffsetX)(THIS_ float) PURE;
    STDMETHOD(SetOffsetY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOffsetY)(THIS_ float) PURE;
    STDMETHOD(SetOffsetZ)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOffsetZ)(THIS_ float) PURE;
#endif
};

#undef INTERFACE
#define INTERFACE IDCompositionScaleTransform3D
DECLARE_INTERFACE_IID_(IDCompositionScaleTransform3D,IDCompositionTransform3D,"2a9e9ead-364b-4b15-a7c4-a1997f78b389")
{
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetScaleX)(THIS_ float) PURE;
    STDMETHOD(SetScaleX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetScaleY)(THIS_ float) PURE;
    STDMETHOD(SetScaleY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetScaleZ)(THIS_ float) PURE;
    STDMETHOD(SetScaleZ)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterX)(THIS_ float) PURE;
    STDMETHOD(SetCenterX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterY)(THIS_ float) PURE;
    STDMETHOD(SetCenterY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterZ)(THIS_ float) PURE;
    STDMETHOD(SetCenterZ)(THIS_ IDCompositionAnimation*) PURE;
#else
    STDMETHOD(SetScaleX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetScaleX)(THIS_ float) PURE;
    STDMETHOD(SetScaleY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetScaleY)(THIS_ float) PURE;
    STDMETHOD(SetScaleZ)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetScaleZ)(THIS_ float) PURE;
    STDMETHOD(SetCenterX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterX)(THIS_ float) PURE;
    STDMETHOD(SetCenterY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterY)(THIS_ float) PURE;
    STDMETHOD(SetCenterZ)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterZ)(THIS_ float) PURE;
#endif
};

#undef INTERFACE
#define INTERFACE IDCompositionRotateTransform3D
DECLARE_INTERFACE_IID_(IDCompositionRotateTransform3D,IDCompositionTransform3D,"d8f5b23f-d429-4a91-b55a-d2f45fd75b18")
{
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetAngle)(THIS_ float) PURE;
    STDMETHOD(SetAngle)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetAxisX)(THIS_ float) PURE;
    STDMETHOD(SetAxisX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetAxisY)(THIS_ float) PURE;
    STDMETHOD(SetAxisY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetAxisZ)(THIS_ float) PURE;
    STDMETHOD(SetAxisZ)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterX)(THIS_ float) PURE;
    STDMETHOD(SetCenterX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterY)(THIS_ float) PURE;
    STDMETHOD(SetCenterY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterZ)(THIS_ float) PURE;
    STDMETHOD(SetCenterZ)(THIS_ IDCompositionAnimation*) PURE;
#else
    STDMETHOD(SetAngle)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetAngle)(THIS_ float) PURE;
    STDMETHOD(SetAxisX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetAxisX)(THIS_ float) PURE;
    STDMETHOD(SetAxisY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetAxisY)(THIS_ float) PURE;
    STDMETHOD(SetAxisZ)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetAxisZ)(THIS_ float) PURE;
    STDMETHOD(SetCenterX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterX)(THIS_ float) PURE;
    STDMETHOD(SetCenterY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterY)(THIS_ float) PURE;
    STDMETHOD(SetCenterZ)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterZ)(THIS_ float) PURE;
#endif
};

#undef INTERFACE
#define INTERFACE IDCompositionMatrixTransform3D
DECLARE_INTERFACE_IID_(IDCompositionMatrixTransform3D,IDCompositionTransform3D,"4b3363f0-643b-41b7-b6e0-ccf22d34467c")
{
    STDMETHOD(SetMatrix)(THIS_ const D3DMATRIX&) PURE;
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetMatrixElement)(THIS_ int,int,float) PURE;
    STDMETHOD(SetMatrixElement)(THIS_ int,int,IDCompositionAnimation*) PURE;
#else
    STDMETHOD(SetMatrixElement)(THIS_ int,int,IDCompositionAnimation*) PURE;
    STDMETHOD(SetMatrixElement)(THIS_ int,int,float) PURE;
#endif
};

#undef INTERFACE
#define INTERFACE IDCompositionEffectGroup
DECLARE_INTERFACE_IID_(IDCompositionEffectGroup,IDCompositionEffect,"a7929a74-e6b2-4bd6-8b95-4040119ca34d")
{
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetOpacity)(THIS_ float) PURE;
    STDMETHOD(SetOpacity)(THIS_ IDCompositionAnimation*) PURE;
#else
    STDMETHOD(SetOpacity)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOpacity)(THIS_ float) PURE;
#endif
    STDMETHOD(SetTransform3D)(THIS_ IDCompositionTransform3D*) PURE;
};

#undef INTERFACE
#define INTERFACE IDCompositionClip
DECLARE_INTERFACE_IID_(IDCompositionClip,IUnknown,"64ac3703-9d3f-45ec-a109-7cac0e7a13a7")
{
};

#undef INTERFACE
#define INTERFACE IDCompositionRectangleClip
DECLARE_INTERFACE_IID_(IDCompositionRectangleClip,IDCompositionClip,"9842ad7d-d9cf-4908-aed7-48b51da5e7c2")
{
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetLeft)(THIS_ float) PURE;
    STDMETHOD(SetLeft)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetTop)(THIS_ float) PURE;
    STDMETHOD(SetTop)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetRight)(THIS_ float) PURE;
    STDMETHOD(SetRight)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetBottom)(THIS_ float) PURE;
    STDMETHOD(SetBottom)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetTopLeftRadiusX)(THIS_ float) PURE;
    STDMETHOD(SetTopLeftRadiusX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetTopLeftRadiusY)(THIS_ float) PURE;
    STDMETHOD(SetTopLeftRadiusY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetTopRightRadiusX)(THIS_ float) PURE;
    STDMETHOD(SetTopRightRadiusX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetTopRightRadiusY)(THIS_ float) PURE;
    STDMETHOD(SetTopRightRadiusY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetBottomLeftRadiusX)(THIS_ float) PURE;
    STDMETHOD(SetBottomLeftRadiusX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetBottomLeftRadiusY)(THIS_ float) PURE;
    STDMETHOD(SetBottomLeftRadiusY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetBottomRightRadiusX)(THIS_ float) PURE;
    STDMETHOD(SetBottomRightRadiusX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetBottomRightRadiusY)(THIS_ float) PURE;
    STDMETHOD(SetBottomRightRadiusY)(THIS_ IDCompositionAnimation*) PURE;
#else
    STDMETHOD(SetLeft)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetLeft)(THIS_ float) PURE;
    STDMETHOD(SetTop)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetTop)(THIS_ float) PURE;
    STDMETHOD(SetRight)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetRight)(THIS_ float) PURE;
    STDMETHOD(SetBottom)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetBottom)(THIS_ float) PURE;
    STDMETHOD(SetTopLeftRadiusX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetTopLeftRadiusX)(THIS_ float) PURE;
    STDMETHOD(SetTopLeftRadiusY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetTopLeftRadiusY)(THIS_ float) PURE;
    STDMETHOD(SetTopRightRadiusX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetTopRightRadiusX)(THIS_ float) PURE;
    STDMETHOD(SetTopRightRadiusY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetTopRightRadiusY)(THIS_ float) PURE;
    STDMETHOD(SetBottomLeftRadiusX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetBottomLeftRadiusX)(THIS_ float) PURE;
    STDMETHOD(SetBottomLeftRadiusY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetBottomLeftRadiusY)(THIS_ float) PURE;
    STDMETHOD(SetBottomRightRadiusX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetBottomRightRadiusX)(THIS_ float) PURE;
    STDMETHOD(SetBottomRightRadiusY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetBottomRightRadiusY)(THIS_ float) PURE;
#endif
};

#undef INTERFACE
#define INTERFACE IDCompositionVisual
DECLARE_INTERFACE_IID_(IDCompositionVisual,IUnknown,"4d93059d-097b-4651-9a60-f0f25116e2f3")
{
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetOffsetX)(THIS_ float) PURE;
    STDMETHOD(SetOffsetX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOffsetY)(THIS_ float) PURE;
    STDMETHOD(SetOffsetY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetTransform)(THIS_ const D2D_MATRIX_3X2_F&) PURE;
    STDMETHOD(SetTransform)(THIS_ IDCompositionTransform*) PURE;
#else
    STDMETHOD(SetOffsetX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOffsetX)(THIS_ float) PURE;
    STDMETHOD(SetOffsetY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOffsetY)(THIS_ float) PURE;
    STDMETHOD(SetTransform)(THIS_ IDCompositionTransform*) PURE;
    STDMETHOD(SetTransform)(THIS_ const D2D_MATRIX_3X2_F&) PURE;
#endif
    STDMETHOD(SetTransformParent)(THIS_ IDCompositionVisual*) PURE;
    STDMETHOD(SetEffect)(THIS_ IDCompositionEffect*) PURE;
    STDMETHOD(SetBitmapInterpolationMode)(THIS_ DCOMPOSITION_BITMAP_INTERPOLATION_MODE) PURE;
    STDMETHOD(SetBorderMode)(THIS_ DCOMPOSITION_BORDER_MODE) PURE;
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetClip)(THIS_ const D2D_RECT_F&) PURE;
    STDMETHOD(SetClip)(THIS_ IDCompositionClip*) PURE;
#else
    STDMETHOD(SetClip)(THIS_ IDCompositionClip*) PURE;
    STDMETHOD(SetClip)(THIS_ const D2D_RECT_F&) PURE;
#endif
    STDMETHOD(SetContent)(THIS_ IUnknown*) PURE;
    STDMETHOD(AddVisual)(THIS_ IDCompositionVisual*,BOOL,IDCompositionVisual*) PURE;
    STDMETHOD(RemoveVisual)(THIS_ IDCompositionVisual*) PURE;
    STDMETHOD(RemoveAllVisuals)(THIS_) PURE;
    STDMETHOD(SetCompositeMode)(THIS_ DCOMPOSITION_COMPOSITE_MODE) PURE;
};

#undef INTERFACE
#define INTERFACE IDCompositionTarget
DECLARE_INTERFACE_IID_(IDCompositionTarget,IUnknown,"eacdd04c-117e-4e17-88f4-d1b12b0e3d89")
{
    STDMETHOD(SetRoot)(THIS_ IDCompositionVisual*) PURE;
};

#undef INTERFACE
#define INTERFACE IDCompositionDevice
DECLARE_INTERFACE_IID_(IDCompositionDevice,IUnknown,"c37ea93a-e7aa-450d-b16f-9746cb0407f3")
{
    STDMETHOD(Commit)(THIS) PURE;
    STDMETHOD(WaitForCommitCompletion)(THIS) PURE;
    STDMETHOD(GetFrameStatistics)(THIS_ DCOMPOSITION_FRAME_STATISTICS*) PURE;
    STDMETHOD(CreateTargetForHwnd)(THIS_ HWND,BOOL,IDCompositionTarget**) PURE;
    STDMETHOD(CreateVisual)(THIS_ IDCompositionVisual**) PURE;
    STDMETHOD(CreateSurface)(THIS_ UINT,UINT,DXGI_FORMAT,DXGI_ALPHA_MODE,IDCompositionSurface**) PURE;
    STDMETHOD(CreateVirtualSurface)(THIS_ UINT,UINT,DXGI_FORMAT,DXGI_ALPHA_MODE,IDCompositionVirtualSurface**) PURE;
    STDMETHOD(CreateSurfaceFromHandle)(THIS_ HANDLE,IUnknown**) PURE;
    STDMETHOD(CreateSurfaceFromHwnd)(THIS_ HWND,IUnknown**) PURE;
    STDMETHOD(CreateTranslateTransform)(THIS_ IDCompositionTranslateTransform**) PURE;
    STDMETHOD(CreateScaleTransform)(THIS_ IDCompositionScaleTransform**) PURE;
    STDMETHOD(CreateRotateTransform)(THIS_ IDCompositionRotateTransform**) PURE;
    STDMETHOD(CreateSkewTransform)(THIS_ IDCompositionSkewTransform**) PURE;
    STDMETHOD(CreateMatrixTransform)(THIS_ IDCompositionMatrixTransform**) PURE;
    STDMETHOD(CreateTransformGroup)(THIS_ IDCompositionTransform**,UINT,IDCompositionTransform**) PURE;
    STDMETHOD(CreateTranslateTransform3D)(THIS_ IDCompositionTranslateTransform3D**) PURE;
    STDMETHOD(CreateScaleTransform3D)(THIS_ IDCompositionScaleTransform3D**) PURE;
    STDMETHOD(CreateRotateTransform3D)(THIS_ IDCompositionRotateTransform3D**) PURE;
    STDMETHOD(CreateMatrixTransform3D)(THIS_ IDCompositionMatrixTransform3D**) PURE;
    STDMETHOD(CreateTransform3DGroup)(THIS_ IDCompositionTransform3D**,UINT,IDCompositionTransform3D**) PURE;
    STDMETHOD(CreateEffectGroup)(THIS_ IDCompositionEffectGroup**) PURE;
    STDMETHOD(CreateRectangleClip)(THIS_ IDCompositionRectangleClip**) PURE;
    STDMETHOD(CreateAnimation)(THIS_ IDCompositionAnimation**) PURE;
    STDMETHOD(CheckDeviceState)(THIS_ BOOL*) PURE;
};

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDCompositionDevice,0xc37ea93a,0xe7aa,0x450d,0xb1,0x6f,0x97,0x46,0xcb,0x04,0x07,0xf3);
#endif

STDAPI DCompositionCreateDevice(IDXGIDevice *dxgiDevice, REFIID iid, void **dcompositionDevice);

#if (_WIN32_WINNT >= 0x0603)

STDAPI DCompositionCreateDevice2(IUnknown *renderingDevice, REFIID iid, void **dcompositionDevice);

#undef INTERFACE
#define INTERFACE IDCompositionVisual2
DECLARE_INTERFACE_IID_(IDCompositionVisual2, IDCompositionVisual, "E8DE1639-4331-4B26-BC5F-6A321D347A85")
{
    STDMETHOD(SetOpacityMode)(THIS_ DCOMPOSITION_OPACITY_MODE) PURE;
    STDMETHOD(SetBackFaceVisibility)(THIS_ DCOMPOSITION_BACKFACE_VISIBILITY) PURE;
};

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDCompositionVisual2,0xe8de1639,0x4331,0x4b26,0xbc,0x5f,0x6a,0x32,0x1d,0x34,0x7a,0x85);
#endif


#undef INTERFACE
#define INTERFACE IDCompositionSurfaceFactory
DECLARE_INTERFACE_IID_(IDCompositionSurfaceFactory, IUnknown, "E334BC12-3937-4E02-85EB-FCF4EB30D2C8")
{
    STDMETHOD(CreateSurface)(THIS_ UINT,UINT, DXGI_FORMAT, DXGI_ALPHA_MODE, IDCompositionSurface**) PURE;
    STDMETHOD(CreateVirtualSurface)(THIS_ UINT, UINT, DXGI_FORMAT , DXGI_ALPHA_MODE, IDCompositionVirtualSurface**) PURE;
};

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDCompositionSurfaceFactory,0xe334bc12,0x3937,0x4e02,0x85,0xeb,0xfc,0xf4,0xeb,0x30,0xd2,0xc8);
#endif


#undef INTERFACE
#define INTERFACE IDCompositionDevice2
DECLARE_INTERFACE_IID_(IDCompositionDevice2, IUnknown, "75F6468D-1B8E-447C-9BC6-75FEA80B5B25")
{
    STDMETHOD(Commit)(THIS) PURE;
    STDMETHOD(WaitForCommitCompletion)(THIS) PURE;
    STDMETHOD(GetFrameStatistics)(THIS_ DCOMPOSITION_FRAME_STATISTICS*) PURE;
    STDMETHOD(CreateVisual)(THIS_ IDCompositionVisual2**) PURE;
    STDMETHOD(CreateSurfaceFactory)(THIS_ IUnknown*, IDCompositionSurfaceFactory**) PURE;
    STDMETHOD(CreateSurface)(THIS_ UINT, UINT, DXGI_FORMAT, DXGI_ALPHA_MODE, IDCompositionSurface**) PURE;
    STDMETHOD(CreateVirtualSurface)(THIS_ UINT, UINT, DXGI_FORMAT, DXGI_ALPHA_MODE, IDCompositionVirtualSurface**) PURE;
    STDMETHOD(CreateTranslateTransform)(THIS_ IDCompositionTranslateTransform**) PURE;
    STDMETHOD(CreateScaleTransform)(THIS_ IDCompositionScaleTransform**) PURE;
    STDMETHOD(CreateRotateTransform)(THIS_ IDCompositionRotateTransform**) PURE;
    STDMETHOD(CreateSkewTransform)(THIS_ IDCompositionSkewTransform**) PURE;
    STDMETHOD(CreateMatrixTransform)(THIS_ IDCompositionMatrixTransform**) PURE;
    STDMETHOD(CreateTransformGroup)(THIS_ IDCompositionTransform**, UINT, IDCompositionTransform**) PURE;
    STDMETHOD(CreateTranslateTransform3D)(THIS_ IDCompositionTranslateTransform3D**) PURE;
    STDMETHOD(CreateScaleTransform3D)(THIS_ IDCompositionScaleTransform3D**) PURE;
    STDMETHOD(CreateRotateTransform3D)(THIS_ IDCompositionRotateTransform3D**) PURE;
    STDMETHOD(CreateMatrixTransform3D)(THIS_ IDCompositionMatrixTransform3D**) PURE;
    STDMETHOD(CreateTransform3DGroup)(THIS_ IDCompositionTransform3D**, UINT, IDCompositionTransform3D**) PURE;
    STDMETHOD(CreateEffectGroup)(THIS_ IDCompositionEffectGroup**) PURE;
    STDMETHOD(CreateRectangleClip)(THIS_ IDCompositionRectangleClip**) PURE;
    STDMETHOD(CreateAnimation)(THIS_ IDCompositionAnimation**) PURE;
};

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDCompositionDevice2,0x75f6468d,0x1b8e,0x447c,0x9b,0xc6,0x75,0xfe,0xa8,0x0b,0x5b,0x25);
#endif


#undef INTERFACE
#define INTERFACE IDCompositionDesktopDevice
DECLARE_INTERFACE_IID_(IDCompositionDesktopDevice, IDCompositionDevice2, "5F4633FE-1E08-4CB8-8C75-CE24333F5602")
{
    STDMETHOD(CreateTargetForHwnd)(THIS_ HWND, BOOL, IDCompositionTarget**) PURE;
    STDMETHOD(CreateSurfaceFromHandle)(THIS_ HANDLE, IUnknown**) PURE;
    STDMETHOD(CreateSurfaceFromHwnd)(THIS_ HWND, IUnknown**) PURE;
};

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDCompositionDesktopDevice,0x5f4633fe,0x1e08,0x4cb8,0x8c,0x75,0xce,0x24,0x33,0x3f,0x56,0x02);
#endif


#undef INTERFACE
#define INTERFACE IDCompositionDeviceDebug
DECLARE_INTERFACE_IID_(IDCompositionDeviceDebug, IUnknown, "A1A3C64A-224F-4A81-9773-4F03A89D3C6C")
{
    STDMETHOD(EnableDebugCounters)(THIS_) PURE;
    STDMETHOD(DisableDebugCounters)(THIS_) PURE;
};

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDCompositionDeviceDebug,0xa1a3c64a,0x224f,0x4a81,0x97,0x73,0x4f,0x03,0xa8,0x9d,0x3c,0x6c);
#endif


#undef INTERFACE
#define INTERFACE IDCompositionVisualDebug
DECLARE_INTERFACE_IID_(IDCompositionVisualDebug, IDCompositionVisual2, "FED2B808-5EB4-43A0-AEA3-35F65280F91B")
{
    STDMETHOD(EnableHeatMap)(THIS_ const D2D1_COLOR_F &color) PURE;
    STDMETHOD(DisableHeatMap)(THIS_) PURE;
    STDMETHOD(EnableRedrawRegions)(THIS_) PURE;
    STDMETHOD(DisableRedrawRegions)(THIS_) PURE;
};

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDCompositionVisualDebug,0xfed2b808,0x5eb4,0x43a0,0xae,0xa3,0x35,0xf6,0x52,0x80,0xf9,0x1b);
#endif


#undef INTERFACE
#define INTERFACE IDCompositionFilterEffect
DECLARE_INTERFACE_IID_(IDCompositionFilterEffect, IDCompositionEffect, "30C421D5-8CB2-4E9F-B133-37BE270D4AC2")
{
    STDMETHOD(SetInput)(THIS_ UINT index, IUnknown *input, UINT flags) PURE;
};

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDCompositionFilterEffect,0x30c421d5,0x8cb2,0x4e9f,0xb1,0x33,0x37,0xbe,0x27,0x0d,0x4a,0xc2);
#endif


#undef INTERFACE
#define INTERFACE IDCompositionSaturationEffect
DECLARE_INTERFACE_IID_(IDCompositionSaturationEffect, IDCompositionFilterEffect, "A08DEBDA-3258-4FA4-9F16-9174D3FE93B1")
{
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetSaturation)(THIS_ float ratio) PURE;
    STDMETHOD(SetSaturation)(THIS_ IDCompositionAnimation* animation) PURE;
#else
    STDMETHOD(SetSaturation)(THIS_ IDCompositionAnimation* animation) PURE;
    STDMETHOD(SetSaturation)(THIS_ float ratio ) PURE;
#endif
};

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDCompositionSaturationEffect,0xa08debda,0x3258,0x4fa4,0x9f,0x16,0x91,0x74,0xd3,0xfe,0x93,0xb1);
#endif


#undef INTERFACE
#define INTERFACE IDCompositionTableTransferEffect
DECLARE_INTERFACE_IID_(IDCompositionTableTransferEffect, IDCompositionFilterEffect, "9B7E82E2-69C5-4EB4-A5F5-A7033F5132CD")
{
    STDMETHOD(SetRedTable)(THIS_ const float *tableValues, UINT count) PURE;
    STDMETHOD(SetGreenTable)(THIS_ const float *tableValues, UINT count) PURE;
    STDMETHOD(SetBlueTable)(THIS_ const float *tableValues, UINT count) PURE;
    STDMETHOD(SetAlphaTable)(THIS_ const float *tableValues, UINT count) PURE;
    STDMETHOD(SetRedDisable)(THIS_ BOOL redDisable) PURE;
    STDMETHOD(SetGreenDisable)(THIS_ BOOL greenDisable) PURE;
    STDMETHOD(SetBlueDisable)(THIS_ BOOL blueDisable) PURE;
    STDMETHOD(SetAlphaDisable)(THIS_ BOOL alphaDisable) PURE;
    STDMETHOD(SetClampOutput)(THIS_ BOOL clampOutput) PURE;
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetRedTableValue)(THIS_ UINT index, float value) PURE;
    STDMETHOD(SetRedTableValue)(THIS_ UINT index, IDCompositionAnimation *animation) PURE;
#else
    STDMETHOD(SetRedTableValue)(THIS_ UINT index, IDCompositionAnimation *animation) PURE;
    STDMETHOD(SetRedTableValue)(THIS_ UINT index, float value) PURE;
#endif
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetGreenTableValue)(THIS_ UINT index, float value) PURE;
    STDMETHOD(SetGreenTableValue)(THIS_ UINT index, IDCompositionAnimation *animation) PURE;
#else
    STDMETHOD(SetGreenTableValue)(THIS_ UINT index, IDCompositionAnimation *animation) PURE;
    STDMETHOD(SetGreenTableValue)(THIS_ UINT index, float value) PURE;
#endif
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetBlueTableValue)(THIS_ UINT index, float value) PURE;
    STDMETHOD(SetBlueTableValue)(THIS_ UINT index, IDCompositionAnimation *animation) PURE;
#else
    STDMETHOD(SetBlueTableValue)(THIS_ UINT index, IDCompositionAnimation *animation) PURE;
    STDMETHOD(SetBlueTableValue)(THIS_ UINT index, float value) PURE;
#endif
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetAlphaTableValue)(THIS_ UINT index, float value) PURE;
    STDMETHOD(SetAlphaTableValue)(THIS_ UINT index, IDCompositionAnimation *animation) PURE;
#else
    STDMETHOD(SetAlphaTableValue)(THIS_ UINT index, IDCompositionAnimation *animation) PURE;
    STDMETHOD(SetAlphaTableValue)(THIS_ UINT index, float value) PURE;
#endif
};

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDCompositionTableTransferEffect,0x9b7e82e2,0x69c5,0x4eb4,0xa5,0xf5,0xa7,0x03,0x3f,0x51,0x32,0xcd);
#endif


#undef INTERFACE
#define INTERFACE IDCompositionGaussianBlurEffect
DECLARE_INTERFACE_IID_(IDCompositionGaussianBlurEffect, IDCompositionFilterEffect, "45D4D0B7-1BD4-454E-8894-2BFA68443033")
{

#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetStandardDeviation)(THIS_ float amount) PURE;
    STDMETHOD(SetStandardDeviation)(THIS_ IDCompositionAnimation* animation) PURE;
#else
    STDMETHOD(SetStandardDeviation)(THIS_ IDCompositionAnimation* animation) PURE;
    STDMETHOD(SetStandardDeviation)(THIS_ float amount) PURE;
#endif
    STDMETHOD(SetBorderMode)(THIS_ D2D1_BORDER_MODE mode) PURE;
};

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDCompositionGaussianBlurEffect,0x45d4d0b7,0x1bd4,0x454e,0x88,0x94,0x2b,0xfa,0x68,0x44,0x30,0x33);
#endif


#undef INTERFACE
#define INTERFACE IDCompositionColorMatrixEffect
DECLARE_INTERFACE_IID_(IDCompositionColorMatrixEffect, IDCompositionFilterEffect, "C1170A22-3CE2-4966-90D4-55408BFC84C4")
{
    STDMETHOD(SetMatrix)(THIS_ const D2D1_MATRIX_5X4_F &matrix) PURE;
#if defined(_MSC_VER) && defined(__cplusplus)
    STDMETHOD(SetMatrixElement)(THIS_ int row, int column, float value) PURE;
    STDMETHOD(SetMatrixElement)(THIS_ int row, int column, IDCompositionAnimation *animation) PURE;
#else
    STDMETHOD(SetMatrixElement)(THIS_ int row, int column, IDCompositionAnimation *animation) PURE;
    STDMETHOD(SetMatrixElement)(THIS_ int row, int column, float value) PURE;
#endif
    STDMETHOD(SetAlphaMode)(THIS_ D2D1_COLORMATRIX_ALPHA_MODE mode) PURE;
    STDMETHOD(SetClampOutput)(THIS_ BOOL clamp) PURE;
};

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDCompositionColorMatrixEffect,0xc1170a22,0x3ce2,0x4966,0x90,0xd4,0x55,0x40,0x8b,0xfc,0x84,0xc4);
#endif


/* WARNING: some of the arguments are replaced with void*, only what's used has been kept */
#undef INTERFACE
#define INTERFACE IDCompositionDevice3
DECLARE_INTERFACE_IID_(IDCompositionDevice3, IDCompositionDevice2, "0987CB06-F916-48BF-8D35-CE7641781BD9")
{
    STDMETHOD(CreateGaussianBlurEffect)(THIS_ IDCompositionGaussianBlurEffect **gaussianBlurEffect) PURE;
    STDMETHOD(CreateBrightnessEffect)(THIS_ /* TODO IDCompositionBrightnessEffect */ void **brightnessEffect) PURE;
    STDMETHOD(CreateColorMatrixEffect)(THIS_ IDCompositionColorMatrixEffect **colorMatrixEffect) PURE;
    STDMETHOD(CreateShadowEffect)(THIS_ /* TODO IDCompositionShadowEffect */ void **shadowEffect) PURE;
    STDMETHOD(CreateHueRotationEffect)(THIS_ /* IDCompositionHueRotationEffect */ void **hueRotationEffect) PURE;
    STDMETHOD(CreateSaturationEffect)(THIS_ IDCompositionSaturationEffect **saturationEffect) PURE;
    STDMETHOD(CreateTurbulenceEffect)(THIS_ /* IDCompositionTurbulenceEffect */ void **turbulenceEffect) PURE;
    STDMETHOD(CreateLinearTransferEffect)(THIS_ /* IDCompositionLinearTransferEffect */ void **linearTransferEffect) PURE;
    STDMETHOD(CreateTableTransferEffect)(THIS_ IDCompositionTableTransferEffect **tableTransferEffect) PURE;
    STDMETHOD(CreateCompositeEffect)(THIS_ /* IDCompositionCompositeEffect */ void **compositeEffect) PURE;
    STDMETHOD(CreateBlendEffect)(THIS_ /* TODO IDCompositionBlendEffect */ void **blendEffect) PURE;
    STDMETHOD(CreateArithmeticCompositeEffect)(THIS_ /* IDCompositionArithmeticCompositeEffect */ void **arithmeticCompositeEffect) PURE;
    STDMETHOD(CreateAffineTransform2DEffect)(THIS_ /* IDCompositionAffineTransform2DEffect */ void **affineTransform2dEffect) PURE;
};

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDCompositionDevice3,0x0987cb06,0xf916,0x48bf,0x8d,0x35,0xce,0x76,0x41,0x78,0x1b,0xd9);
#endif

#endif /* WINAPI_PARTITION_DESKTOP */

#if (_WIN32_WINNT >= 0x0A00)

STDAPI DCompositionCreateDevice3(IUnknown *renderingDevice, REFIID iid, void **dcompositionDevice);

#endif

STDAPI DCompositionCreateSurfaceHandle(DWORD desiredAccess, SECURITY_ATTRIBUTES *securityAttributes, HANDLE *surfaceHandle);

STDAPI DCompositionAttachMouseWheelToHwnd(IDCompositionVisual* visual, HWND hwnd, BOOL enable);

STDAPI DCompositionAttachMouseDragToHwnd(IDCompositionVisual* visual, HWND hwnd, BOOL enable);


#endif
#endif /* _DCOMP_H_ */
