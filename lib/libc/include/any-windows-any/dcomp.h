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
    STDMETHOD(SetOffsetX)(THIS_ float) PURE;
    STDMETHOD(SetOffsetX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOffsetY)(THIS_ float) PURE;
    STDMETHOD(SetOffsetY)(THIS_ IDCompositionAnimation*) PURE;
};

#undef INTERFACE
#define INTERFACE IDCompositionScaleTransform
DECLARE_INTERFACE_IID_(IDCompositionScaleTransform,IDCompositionTransform,"71fde914-40ef-45ef-bd51-68b037c339f9")
{
    STDMETHOD(SetScaleX)(THIS_ float) PURE;
    STDMETHOD(SetScaleX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetScaleY)(THIS_ float) PURE;
    STDMETHOD(SetScaleY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterX)(THIS_ float) PURE;
    STDMETHOD(SetCenterX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterY)(THIS_ float) PURE;
    STDMETHOD(SetCenterY)(THIS_ IDCompositionAnimation*) PURE;
};

#undef INTERFACE
#define INTERFACE IDCompositionRotateTransform
DECLARE_INTERFACE_IID_(IDCompositionRotateTransform,IDCompositionTransform,"641ed83c-ae96-46c5-90dc-32774cc5c6d5")
{
    STDMETHOD(SetAngle)(THIS_ float) PURE;
    STDMETHOD(SetAngle)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterX)(THIS_ float) PURE;
    STDMETHOD(SetCenterX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterY)(THIS_ float) PURE;
    STDMETHOD(SetCenterY)(THIS_ IDCompositionAnimation*) PURE;
};

#undef INTERFACE
#define INTERFACE IDCompositionSkewTransform
DECLARE_INTERFACE_IID_(IDCompositionSkewTransform,IDCompositionTransform,"e57aa735-dcdb-4c72-9c61-0591f58889ee")
{
    STDMETHOD(SetAngleX)(THIS_ float) PURE;
    STDMETHOD(SetAngleX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetAngleY)(THIS_ float) PURE;
    STDMETHOD(SetAngleY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterX)(THIS_ float) PURE;
    STDMETHOD(SetCenterX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetCenterY)(THIS_ float) PURE;
    STDMETHOD(SetCenterY)(THIS_ IDCompositionAnimation*) PURE;
};

#undef INTERFACE
#define INTERFACE IDCompositionMatrixTransform
DECLARE_INTERFACE_IID_(IDCompositionMatrixTransform,IDCompositionTransform,"16cdff07-c503-419c-83f2-0965c7af1fa6")
{
    STDMETHOD(SetMatrix)(THIS_ const D2D_MATRIX_3X2_F&) PURE;
    STDMETHOD(SetMatrixElement)(THIS_ int,int,float) PURE;
    STDMETHOD(SetMatrixElement)(THIS_ int,int,IDCompositionAnimation*) PURE;
};

#undef INTERFACE
#define INTERFACE IDCompositionTranslateTransform3D
DECLARE_INTERFACE_IID_(IDCompositionTranslateTransform3D,IDCompositionTransform3D,"91636d4b-9ba1-4532-aaf7-e3344994d788")
{
    STDMETHOD(SetOffsetX)(THIS_ float) PURE;
    STDMETHOD(SetOffsetX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOffsetY)(THIS_ float) PURE;
    STDMETHOD(SetOffsetY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOffsetZ)(THIS_ float) PURE;
    STDMETHOD(SetOffsetZ)(THIS_ IDCompositionAnimation*) PURE;
};

#undef INTERFACE
#define INTERFACE IDCompositionScaleTransform3D
DECLARE_INTERFACE_IID_(IDCompositionScaleTransform3D,IDCompositionTransform3D,"2a9e9ead-364b-4b15-a7c4-a1997f78b389")
{
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
};

#undef INTERFACE
#define INTERFACE IDCompositionRotateTransform3D
DECLARE_INTERFACE_IID_(IDCompositionRotateTransform3D,IDCompositionTransform3D,"d8f5b23f-d429-4a91-b55a-d2f45fd75b18")
{
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
};

#undef INTERFACE
#define INTERFACE IDCompositionMatrixTransform3D
DECLARE_INTERFACE_IID_(IDCompositionMatrixTransform3D,IDCompositionTransform3D,"4b3363f0-643b-41b7-b6e0-ccf22d34467c")
{
    STDMETHOD(SetMatrix)(THIS_ const D3DMATRIX&) PURE;
    STDMETHOD(SetMatrixElement)(THIS_ int,int,float) PURE;
    STDMETHOD(SetMatrixElement)(THIS_ int,int,IDCompositionAnimation*) PURE;
};

#undef INTERFACE
#define INTERFACE IDCompositionEffectGroup
DECLARE_INTERFACE_IID_(IDCompositionEffectGroup,IDCompositionEffect,"a7929a74-e6b2-4bd6-8b95-4040119ca34d")
{
    STDMETHOD(SetOpacity)(THIS_ float) PURE;
    STDMETHOD(SetOpacity)(THIS_ IDCompositionAnimation*) PURE;
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
};

#undef INTERFACE
#define INTERFACE IDCompositionVisual
DECLARE_INTERFACE_IID_(IDCompositionVisual,IUnknown,"4d93059d-097b-4651-9a60-f0f25116e2f3")
{
    STDMETHOD(SetOffsetX)(THIS_ float) PURE;
    STDMETHOD(SetOffsetX)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetOffsetY)(THIS_ float) PURE;
    STDMETHOD(SetOffsetY)(THIS_ IDCompositionAnimation*) PURE;
    STDMETHOD(SetTransform)(THIS_ const D2D_MATRIX_3X2_F&) PURE;
    STDMETHOD(SetTransform)(THIS_ IDCompositionTransform*) PURE;
    STDMETHOD(SetTransformParent)(THIS_ IDCompositionVisual*) PURE;
    STDMETHOD(SetEffect)(THIS_ IDCompositionEffect*) PURE;
    STDMETHOD(SetBitmapInterpolationMode)(THIS_ DCOMPOSITION_BITMAP_INTERPOLATION_MODE) PURE;
    STDMETHOD(SetBorderMode)(THIS_ DCOMPOSITION_BORDER_MODE) PURE;
    STDMETHOD(SetClip)(THIS_ const D2D_RECT_F&) PURE;
    STDMETHOD(SetClip)(THIS_ IDCompositionClip*) PURE;
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

#endif

#if (_WIN32_WINNT >= 0x0A00)

STDAPI DCompositionCreateDevice3(IUnknown *renderingDevice, REFIID iid, void **dcompositionDevice);

#endif

STDAPI DCompositionCreateSurfaceHandle(DWORD desiredAccess, SECURITY_ATTRIBUTES *securityAttributes, HANDLE *surfaceHandle);

STDAPI DCompositionAttachMouseWheelToHwnd(IDCompositionVisual* visual, HWND hwnd, BOOL enable);

STDAPI DCompositionAttachMouseDragToHwnd(IDCompositionVisual* visual, HWND hwnd, BOOL enable);


#endif
#endif /* _DCOMP_H_ */
