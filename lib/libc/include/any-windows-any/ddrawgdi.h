/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _DDRAWGDI_H_
#define _DDRAWGDI_H_

#include <ddraw.h>

#define DdCreateDirectDrawObject GdiEntry1
#define DdQueryDirectDrawObject GdiEntry2
#define DdDeleteDirectDrawObject GdiEntry3
#define DdCreateSurfaceObject GdiEntry4
#define DdDeleteSurfaceObject GdiEntry5
#define DdResetVisrgn GdiEntry6
#define DdGetDC GdiEntry7
#define DdReleaseDC GdiEntry8
#define DdCreateDIBSection GdiEntry9
#define DdReenableDirectDrawObject GdiEntry10
#define DdAttachSurface GdiEntry11
#define DdUnattachSurface GdiEntry12
#define DdQueryDisplaySettingsUniqueness GdiEntry13
#define DdGetDxHandle GdiEntry14
#define DdSetGammaRamp GdiEntry15
#define DdSwapTextureHandles GdiEntry16

#ifndef D3DHAL_CALLBACKS_DEFINED
typedef struct _D3DHAL_CALLBACKS *LPD3DHAL_CALLBACKS;
#define D3DHAL_CALLBACKS_DEFINED
#endif
#ifndef D3DHAL_GLOBALDRIVERDATA_DEFINED
typedef struct _D3DHAL_GLOBALDRIVERDATA *LPD3DHAL_GLOBALDRIVERDATA;
#define D3DHAL_GLOBALDRIVERDATA_DEFINED
#endif

WINBOOL WINAPI DdCreateDirectDrawObject(LPDDRAWI_DIRECTDRAW_GBL pDirectDrawGlobal,HDC hdc);
WINBOOL WINAPI DdQueryDirectDrawObject(LPDDRAWI_DIRECTDRAW_GBL pDirectDrawGlobal,LPDDHALINFO pHalInfo,LPDDHAL_DDCALLBACKS pDDCallbacks,LPDDHAL_DDSURFACECALLBACKS pDDSurfaceCallbacks,LPDDHAL_DDPALETTECALLBACKS pDDPaletteCallbacks,LPD3DHAL_CALLBACKS pD3dCallbacks,LPD3DHAL_GLOBALDRIVERDATA pD3dDriverData,LPDDHAL_DDEXEBUFCALLBACKS pD3dBufferCallbacks,LPDDSURFACEDESC pD3dTextureFormats,LPDWORD pdwFourCC,LPVIDMEM pvmList);
WINBOOL WINAPI DdDeleteDirectDrawObject(LPDDRAWI_DIRECTDRAW_GBL pDirectDrawGlobal);
WINBOOL WINAPI DdCreateSurfaceObject(LPDDRAWI_DDRAWSURFACE_LCL pSurfaceLocal,WINBOOL bPrimarySurface);
WINBOOL WINAPI DdDeleteSurfaceObject(LPDDRAWI_DDRAWSURFACE_LCL pSurfaceLocal);
WINBOOL WINAPI DdResetVisrgn(LPDDRAWI_DDRAWSURFACE_LCL pSurfaceLocal,HWND hWnd);
HDC WINAPI DdGetDC(LPDDRAWI_DDRAWSURFACE_LCL pSurfaceLocal,LPPALETTEENTRY pColorTable);
WINBOOL WINAPI DdReleaseDC(LPDDRAWI_DDRAWSURFACE_LCL pSurfaceLocal);
HBITMAP WINAPI DdCreateDIBSection(HDC hdc,CONST BITMAPINFO *pbmi,UINT iUsage,VOID **ppvBits,HANDLE hSectionApp,DWORD dwOffset);
WINBOOL WINAPI DdReenableDirectDrawObject(LPDDRAWI_DIRECTDRAW_GBL pDirectDrawGlobal,WINBOOL *pbNewMode);
WINBOOL WINAPI DdAttachSurface(LPDDRAWI_DDRAWSURFACE_LCL pSurfaceFrom,LPDDRAWI_DDRAWSURFACE_LCL pSurfaceTo);
VOID WINAPI DdUnattachSurface(LPDDRAWI_DDRAWSURFACE_LCL pSurface,LPDDRAWI_DDRAWSURFACE_LCL pSurfaceAttached);
ULONG WINAPI DdQueryDisplaySettingsUniqueness(VOID);
HANDLE WINAPI DdGetDxHandle(LPDDRAWI_DIRECTDRAW_LCL pDDraw,LPDDRAWI_DDRAWSURFACE_LCL pSurface,WINBOOL bRelease);
WINBOOL WINAPI DdSetGammaRamp(LPDDRAWI_DIRECTDRAW_LCL pDDraw,HDC hdc,LPVOID lpGammaRamp);
DWORD WINAPI DdSwapTextureHandles(LPDDRAWI_DIRECTDRAW_LCL pDDraw,LPDDRAWI_DDRAWSURFACE_LCL pDDSLcl1,LPDDRAWI_DDRAWSURFACE_LCL pDDSLcl2);

#endif /*  _DDRAWGDI_H_ */
