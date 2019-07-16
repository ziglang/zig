/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef W32KAPI
#define W32KAPI
#endif

#define TRACE_SURFACE_ALLOCS (DBG || 0)

#define FL_UFI_PRIVATEFONT 1
#define FL_UFI_DESIGNVECTOR_PFF 2
#define FL_UFI_MEMORYFONT 4

W32KAPI WINBOOL WINAPI NtGdiInit();
W32KAPI int WINAPI NtGdiSetDIBitsToDeviceInternal(HDC hdcDest,int xDst,int yDst,DWORD cx,DWORD cy,int xSrc,int ySrc,DWORD iStartScan,DWORD cNumScan,LPBYTE pInitBits,LPBITMAPINFO pbmi,DWORD iUsage,UINT cjMaxBits,UINT cjMaxInfo,WINBOOL bTransformCoordinates,HANDLE hcmXform);
W32KAPI WINBOOL WINAPI NtGdiGetFontResourceInfoInternalW(LPWSTR pwszFiles,ULONG cwc,ULONG cFiles,UINT cjIn,LPDWORD pdwBytes,LPVOID pvBuf,DWORD iType);
W32KAPI DWORD WINAPI NtGdiGetGlyphIndicesW(HDC hdc,LPWSTR pwc,int cwc,LPWORD pgi,DWORD iMode);
W32KAPI DWORD WINAPI NtGdiGetGlyphIndicesWInternal(HDC hdc,LPWSTR pwc,int cwc,LPWORD pgi,DWORD iMode,WINBOOL bSubset);
W32KAPI HPALETTE WINAPI NtGdiCreatePaletteInternal(LPLOGPALETTE pLogPal,UINT cEntries);
W32KAPI WINBOOL WINAPI NtGdiArcInternal(ARCTYPE arctype,HDC hdc,int x1,int y1,int x2,int y2,int x3,int y3,int x4,int y4);
W32KAPI int WINAPI NtGdiStretchDIBitsInternal(HDC hdc,int xDst,int yDst,int cxDst,int cyDst,int xSrc,int ySrc,int cxSrc,int cySrc,LPBYTE pjInit,LPBITMAPINFO pbmi,DWORD dwUsage,DWORD dwRop4,UINT cjMaxInfo,UINT cjMaxBits,HANDLE hcmXform);
W32KAPI ULONG WINAPI NtGdiGetOutlineTextMetricsInternalW(HDC hdc,ULONG cjotm,OUTLINETEXTMETRICW *potmw,TMDIFF *ptmd);
W32KAPI WINBOOL WINAPI NtGdiGetAndSetDCDword(HDC hdc,UINT u,DWORD dwIn,DWORD *pdwResult);
W32KAPI HANDLE WINAPI NtGdiGetDCObject(HDC hdc,int itype);
W32KAPI HDC WINAPI NtGdiGetDCforBitmap(HBITMAP hsurf);
W32KAPI WINBOOL WINAPI NtGdiGetMonitorID(HDC hdc,DWORD dwSize,LPWSTR pszMonitorID);
W32KAPI INT WINAPI NtGdiGetLinkedUFIs(HDC hdc,PUNIVERSAL_FONT_ID pufiLinkedUFIs,INT BufferSize);
W32KAPI WINBOOL WINAPI NtGdiSetLinkedUFIs(HDC hdc,PUNIVERSAL_FONT_ID pufiLinks,ULONG uNumUFIs);
W32KAPI WINBOOL WINAPI NtGdiGetUFI(HDC hdc,PUNIVERSAL_FONT_ID pufi,DESIGNVECTOR *pdv,ULONG *pcjDV,ULONG *pulBaseCheckSum,FLONG *pfl);
W32KAPI WINBOOL WINAPI NtGdiForceUFIMapping(HDC hdc,PUNIVERSAL_FONT_ID pufi);
W32KAPI WINBOOL WINAPI NtGdiGetUFIPathname(PUNIVERSAL_FONT_ID pufi,ULONG *pcwc,LPWSTR pwszPathname,ULONG *pcNumFiles,FLONG fl,WINBOOL *pbMemFont,ULONG *pcjView,PVOID pvView,WINBOOL *pbTTC,ULONG *piTTC);
W32KAPI WINBOOL WINAPI NtGdiAddRemoteFontToDC(HDC hdc,PVOID pvBuffer,ULONG cjBuffer,PUNIVERSAL_FONT_ID pufi);
W32KAPI HANDLE WINAPI NtGdiAddFontMemResourceEx(PVOID pvBuffer,DWORD cjBuffer,DESIGNVECTOR *pdv,ULONG cjDV,DWORD *pNumFonts);
W32KAPI WINBOOL WINAPI NtGdiRemoveFontMemResourceEx(HANDLE hMMFont);
W32KAPI WINBOOL WINAPI NtGdiUnmapMemFont(PVOID pvView);
W32KAPI WINBOOL WINAPI NtGdiRemoveMergeFont(HDC hdc,UNIVERSAL_FONT_ID *pufi);
W32KAPI WINBOOL WINAPI NtGdiAnyLinkedFonts();
W32KAPI WINBOOL WINAPI NtGdiGetEmbUFI(HDC hdc,PUNIVERSAL_FONT_ID pufi,DESIGNVECTOR *pdv,ULONG *pcjDV,ULONG *pulBaseCheckSum,FLONG *pfl,KERNEL_PVOID *embFontID);
W32KAPI ULONG WINAPI NtGdiGetEmbedFonts();
W32KAPI WINBOOL WINAPI NtGdiChangeGhostFont(KERNEL_PVOID *pfontID,WINBOOL bLoad);
W32KAPI WINBOOL WINAPI NtGdiAddEmbFontToDC(HDC hdc,VOID **pFontID);
W32KAPI WINBOOL WINAPI NtGdiFontIsLinked(HDC hdc);
W32KAPI ULONG_PTR WINAPI NtGdiPolyPolyDraw(HDC hdc,PPOINT ppt,PULONG pcpt,ULONG ccpt,int iFunc);
W32KAPI LONG WINAPI NtGdiDoPalette(HPALETTE hpal,WORD iStart,WORD cEntries,PALETTEENTRY *pPalEntries,DWORD iFunc,WINBOOL bInbound);
W32KAPI WINBOOL WINAPI NtGdiComputeXformCoefficients(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiGetWidthTable(HDC hdc,ULONG cSpecial,WCHAR *pwc,ULONG cwc,USHORT *psWidth,WIDTHDATA *pwd,FLONG *pflInfo);
W32KAPI int WINAPI NtGdiDescribePixelFormat(HDC hdc,int ipfd,UINT cjpfd,PPIXELFORMATDESCRIPTOR ppfd);
W32KAPI WINBOOL WINAPI NtGdiSetPixelFormat(HDC hdc,int ipfd);
W32KAPI WINBOOL WINAPI NtGdiSwapBuffers(HDC hdc);
W32KAPI int WINAPI NtGdiSetupPublicCFONT(HDC hdc,HFONT hf,ULONG ulAve);
W32KAPI DWORD WINAPI NtGdiDxgGenericThunk(ULONG_PTR ulIndex,ULONG_PTR ulHandle,SIZE_T *pdwSizeOfPtr1,PVOID pvPtr1,SIZE_T *pdwSizeOfPtr2,PVOID pvPtr2);
W32KAPI DWORD WINAPI NtGdiDdAddAttachedSurface(HANDLE hSurface,HANDLE hSurfaceAttached,PDD_ADDATTACHEDSURFACEDATA puAddAttachedSurfaceData);
W32KAPI WINBOOL WINAPI NtGdiDdAttachSurface(HANDLE hSurfaceFrom,HANDLE hSurfaceTo);
W32KAPI DWORD WINAPI NtGdiDdBlt(HANDLE hSurfaceDest,HANDLE hSurfaceSrc,PDD_BLTDATA puBltData);
W32KAPI DWORD WINAPI NtGdiDdCanCreateSurface(HANDLE hDirectDraw,PDD_CANCREATESURFACEDATA puCanCreateSurfaceData);
W32KAPI DWORD WINAPI NtGdiDdColorControl(HANDLE hSurface,PDD_COLORCONTROLDATA puColorControlData);
W32KAPI HANDLE WINAPI NtGdiDdCreateDirectDrawObject(HDC hdc);
W32KAPI DWORD WINAPI NtGdiDdCreateSurface(HANDLE hDirectDraw,HANDLE *hSurface,DDSURFACEDESC *puSurfaceDescription,DD_SURFACE_GLOBAL *puSurfaceGlobalData,DD_SURFACE_LOCAL *puSurfaceLocalData,DD_SURFACE_MORE *puSurfaceMoreData,DD_CREATESURFACEDATA *puCreateSurfaceData,HANDLE *puhSurface);
W32KAPI HANDLE WINAPI NtGdiDdCreateSurfaceObject(HANDLE hDirectDrawLocal,HANDLE hSurface,PDD_SURFACE_LOCAL puSurfaceLocal,PDD_SURFACE_MORE puSurfaceMore,PDD_SURFACE_GLOBAL puSurfaceGlobal,WINBOOL bComplete);
W32KAPI WINBOOL WINAPI NtGdiDdDeleteSurfaceObject(HANDLE hSurface);
W32KAPI WINBOOL WINAPI NtGdiDdDeleteDirectDrawObject(HANDLE hDirectDrawLocal);
W32KAPI DWORD WINAPI NtGdiDdDestroySurface(HANDLE hSurface,WINBOOL bRealDestroy);
W32KAPI DWORD WINAPI NtGdiDdFlip(HANDLE hSurfaceCurrent,HANDLE hSurfaceTarget,HANDLE hSurfaceCurrentLeft,HANDLE hSurfaceTargetLeft,PDD_FLIPDATA puFlipData);
W32KAPI DWORD WINAPI NtGdiDdGetAvailDriverMemory(HANDLE hDirectDraw,PDD_GETAVAILDRIVERMEMORYDATA puGetAvailDriverMemoryData);
W32KAPI DWORD WINAPI NtGdiDdGetBltStatus(HANDLE hSurface,PDD_GETBLTSTATUSDATA puGetBltStatusData);
W32KAPI HDC WINAPI NtGdiDdGetDC(HANDLE hSurface,PALETTEENTRY *puColorTable);
W32KAPI DWORD WINAPI NtGdiDdGetDriverInfo(HANDLE hDirectDraw,PDD_GETDRIVERINFODATA puGetDriverInfoData);
W32KAPI DWORD WINAPI NtGdiDdGetFlipStatus(HANDLE hSurface,PDD_GETFLIPSTATUSDATA puGetFlipStatusData);
W32KAPI DWORD WINAPI NtGdiDdGetScanLine(HANDLE hDirectDraw,PDD_GETSCANLINEDATA puGetScanLineData);
W32KAPI DWORD WINAPI NtGdiDdSetExclusiveMode(HANDLE hDirectDraw,PDD_SETEXCLUSIVEMODEDATA puSetExclusiveModeData);
W32KAPI DWORD WINAPI NtGdiDdFlipToGDISurface(HANDLE hDirectDraw,PDD_FLIPTOGDISURFACEDATA puFlipToGDISurfaceData);
W32KAPI DWORD WINAPI NtGdiDdLock(HANDLE hSurface,PDD_LOCKDATA puLockData,HDC hdcClip);
W32KAPI WINBOOL WINAPI NtGdiDdQueryDirectDrawObject(HANDLE hDirectDrawLocal,PDD_HALINFO pHalInfo,DWORD *pCallBackFlags,LPD3DNTHAL_CALLBACKS puD3dCallbacks,LPD3DNTHAL_GLOBALDRIVERDATA puD3dDriverData,PDD_D3DBUFCALLBACKS puD3dBufferCallbacks,LPDDSURFACEDESC puD3dTextureFormats,DWORD *puNumHeaps,VIDEOMEMORY *puvmList,DWORD *puNumFourCC,DWORD *puFourCC);
W32KAPI WINBOOL WINAPI NtGdiDdReenableDirectDrawObject(HANDLE hDirectDrawLocal,WINBOOL *pubNewMode);
W32KAPI WINBOOL WINAPI NtGdiDdReleaseDC(HANDLE hSurface);
W32KAPI WINBOOL WINAPI NtGdiDdResetVisrgn(HANDLE hSurface,HWND hwnd);
W32KAPI DWORD WINAPI NtGdiDdSetColorKey(HANDLE hSurface,PDD_SETCOLORKEYDATA puSetColorKeyData);
W32KAPI DWORD WINAPI NtGdiDdSetOverlayPosition(HANDLE hSurfaceSource,HANDLE hSurfaceDestination,PDD_SETOVERLAYPOSITIONDATA puSetOverlayPositionData);
W32KAPI VOID WINAPI NtGdiDdUnattachSurface(HANDLE hSurface,HANDLE hSurfaceAttached);
W32KAPI DWORD WINAPI NtGdiDdUnlock(HANDLE hSurface,PDD_UNLOCKDATA puUnlockData);
W32KAPI DWORD WINAPI NtGdiDdUpdateOverlay(HANDLE hSurfaceDestination,HANDLE hSurfaceSource,PDD_UPDATEOVERLAYDATA puUpdateOverlayData);
W32KAPI DWORD WINAPI NtGdiDdWaitForVerticalBlank(HANDLE hDirectDraw,PDD_WAITFORVERTICALBLANKDATA puWaitForVerticalBlankData);
W32KAPI HANDLE WINAPI NtGdiDdGetDxHandle(HANDLE hDirectDraw,HANDLE hSurface,WINBOOL bRelease);
W32KAPI WINBOOL WINAPI NtGdiDdSetGammaRamp(HANDLE hDirectDraw,HDC hdc,LPVOID lpGammaRamp);
W32KAPI DWORD WINAPI NtGdiDdLockD3D(HANDLE hSurface,PDD_LOCKDATA puLockData);
W32KAPI DWORD WINAPI NtGdiDdUnlockD3D(HANDLE hSurface,PDD_UNLOCKDATA puUnlockData);
W32KAPI DWORD WINAPI NtGdiDdCreateD3DBuffer(HANDLE hDirectDraw,HANDLE *hSurface,DDSURFACEDESC *puSurfaceDescription,DD_SURFACE_GLOBAL *puSurfaceGlobalData,DD_SURFACE_LOCAL *puSurfaceLocalData,DD_SURFACE_MORE *puSurfaceMoreData,DD_CREATESURFACEDATA *puCreateSurfaceData,HANDLE *puhSurface);
W32KAPI DWORD WINAPI NtGdiDdCanCreateD3DBuffer(HANDLE hDirectDraw,PDD_CANCREATESURFACEDATA puCanCreateSurfaceData);
W32KAPI DWORD WINAPI NtGdiDdDestroyD3DBuffer(HANDLE hSurface);
W32KAPI DWORD WINAPI NtGdiD3dContextCreate(HANDLE hDirectDrawLocal,HANDLE hSurfColor,HANDLE hSurfZ,D3DNTHAL_CONTEXTCREATEI *pdcci);
W32KAPI DWORD WINAPI NtGdiD3dContextDestroy(LPD3DNTHAL_CONTEXTDESTROYDATA);
W32KAPI DWORD WINAPI NtGdiD3dContextDestroyAll(LPD3DNTHAL_CONTEXTDESTROYALLDATA pdcdad);
W32KAPI DWORD WINAPI NtGdiD3dValidateTextureStageState(LPD3DNTHAL_VALIDATETEXTURESTAGESTATEDATA pData);
W32KAPI DWORD WINAPI NtGdiD3dDrawPrimitives2(HANDLE hCmdBuf,HANDLE hVBuf,LPD3DNTHAL_DRAWPRIMITIVES2DATA pded,FLATPTR *pfpVidMemCmd,DWORD *pdwSizeCmd,FLATPTR *pfpVidMemVtx,DWORD *pdwSizeVtx);
W32KAPI DWORD WINAPI NtGdiDdGetDriverState(PDD_GETDRIVERSTATEDATA pdata);
W32KAPI DWORD WINAPI NtGdiDdCreateSurfaceEx(HANDLE hDirectDraw,HANDLE hSurface,DWORD dwSurfaceHandle);
W32KAPI DWORD WINAPI NtGdiDvpCanCreateVideoPort(HANDLE hDirectDraw,PDD_CANCREATEVPORTDATA puCanCreateVPortData);
W32KAPI DWORD WINAPI NtGdiDvpColorControl(HANDLE hVideoPort,PDD_VPORTCOLORDATA puVPortColorData);
W32KAPI HANDLE WINAPI NtGdiDvpCreateVideoPort(HANDLE hDirectDraw,PDD_CREATEVPORTDATA puCreateVPortData);
W32KAPI DWORD WINAPI NtGdiDvpDestroyVideoPort(HANDLE hVideoPort,PDD_DESTROYVPORTDATA puDestroyVPortData);
W32KAPI DWORD WINAPI NtGdiDvpFlipVideoPort(HANDLE hVideoPort,HANDLE hDDSurfaceCurrent,HANDLE hDDSurfaceTarget,PDD_FLIPVPORTDATA puFlipVPortData);
W32KAPI DWORD WINAPI NtGdiDvpGetVideoPortBandwidth(HANDLE hVideoPort,PDD_GETVPORTBANDWIDTHDATA puGetVPortBandwidthData);
W32KAPI DWORD WINAPI NtGdiDvpGetVideoPortField(HANDLE hVideoPort,PDD_GETVPORTFIELDDATA puGetVPortFieldData);
W32KAPI DWORD WINAPI NtGdiDvpGetVideoPortFlipStatus(HANDLE hDirectDraw,PDD_GETVPORTFLIPSTATUSDATA puGetVPortFlipStatusData);
W32KAPI DWORD WINAPI NtGdiDvpGetVideoPortInputFormats(HANDLE hVideoPort,PDD_GETVPORTINPUTFORMATDATA puGetVPortInputFormatData);
W32KAPI DWORD WINAPI NtGdiDvpGetVideoPortLine(HANDLE hVideoPort,PDD_GETVPORTLINEDATA puGetVPortLineData);
W32KAPI DWORD WINAPI NtGdiDvpGetVideoPortOutputFormats(HANDLE hVideoPort,PDD_GETVPORTOUTPUTFORMATDATA puGetVPortOutputFormatData);
W32KAPI DWORD WINAPI NtGdiDvpGetVideoPortConnectInfo(HANDLE hDirectDraw,PDD_GETVPORTCONNECTDATA puGetVPortConnectData);
W32KAPI DWORD WINAPI NtGdiDvpGetVideoSignalStatus(HANDLE hVideoPort,PDD_GETVPORTSIGNALDATA puGetVPortSignalData);
W32KAPI DWORD WINAPI NtGdiDvpUpdateVideoPort(HANDLE hVideoPort,HANDLE *phSurfaceVideo,HANDLE *phSurfaceVbi,PDD_UPDATEVPORTDATA puUpdateVPortData);
W32KAPI DWORD WINAPI NtGdiDvpWaitForVideoPortSync(HANDLE hVideoPort,PDD_WAITFORVPORTSYNCDATA puWaitForVPortSyncData);
W32KAPI DWORD WINAPI NtGdiDvpAcquireNotification(HANDLE hVideoPort,HANDLE *hEvent,LPDDVIDEOPORTNOTIFY pNotify);
W32KAPI DWORD WINAPI NtGdiDvpReleaseNotification(HANDLE hVideoPort,HANDLE hEvent);
W32KAPI DWORD WINAPI NtGdiDdGetMoCompGuids(HANDLE hDirectDraw,PDD_GETMOCOMPGUIDSDATA puGetMoCompGuidsData);
W32KAPI DWORD WINAPI NtGdiDdGetMoCompFormats(HANDLE hDirectDraw,PDD_GETMOCOMPFORMATSDATA puGetMoCompFormatsData);
W32KAPI DWORD WINAPI NtGdiDdGetMoCompBuffInfo(HANDLE hDirectDraw,PDD_GETMOCOMPCOMPBUFFDATA puGetBuffData);
W32KAPI DWORD WINAPI NtGdiDdGetInternalMoCompInfo(HANDLE hDirectDraw,PDD_GETINTERNALMOCOMPDATA puGetInternalData);
W32KAPI HANDLE WINAPI NtGdiDdCreateMoComp(HANDLE hDirectDraw,PDD_CREATEMOCOMPDATA puCreateMoCompData);
W32KAPI DWORD WINAPI NtGdiDdDestroyMoComp(HANDLE hMoComp,PDD_DESTROYMOCOMPDATA puDestroyMoCompData);
W32KAPI DWORD WINAPI NtGdiDdBeginMoCompFrame(HANDLE hMoComp,PDD_BEGINMOCOMPFRAMEDATA puBeginFrameData);
W32KAPI DWORD WINAPI NtGdiDdEndMoCompFrame(HANDLE hMoComp,PDD_ENDMOCOMPFRAMEDATA puEndFrameData);
W32KAPI DWORD WINAPI NtGdiDdRenderMoComp(HANDLE hMoComp,PDD_RENDERMOCOMPDATA puRenderMoCompData);
W32KAPI DWORD WINAPI NtGdiDdQueryMoCompStatus(HANDLE hMoComp,PDD_QUERYMOCOMPSTATUSDATA puQueryMoCompStatusData);
W32KAPI DWORD WINAPI NtGdiDdAlphaBlt(HANDLE hSurfaceDest,HANDLE hSurfaceSrc,PDD_BLTDATA puBltData);
W32KAPI WINBOOL WINAPI NtGdiAlphaBlend(HDC hdcDst,LONG DstX,LONG DstY,LONG DstCx,LONG DstCy,HDC hdcSrc,LONG SrcX,LONG SrcY,LONG SrcCx,LONG SrcCy,BLENDFUNCTION BlendFunction,HANDLE hcmXform);
W32KAPI WINBOOL WINAPI NtGdiGradientFill(HDC hdc,PTRIVERTEX pVertex,ULONG nVertex,PVOID pMesh,ULONG nMesh,ULONG ulMode);
W32KAPI WINBOOL WINAPI NtGdiSetIcmMode(HDC hdc,ULONG nCommand,ULONG ulMode);

#define ICM_SET_MODE 1
#define ICM_SET_CALIBRATE_MODE 2
#define ICM_SET_COLOR_MODE 3
#define ICM_CHECK_COLOR_MODE 4

typedef struct _LOGCOLORSPACEEXW {
  LOGCOLORSPACEW lcsColorSpace;
  DWORD dwFlags;
} LOGCOLORSPACEEXW,*PLOGCOLORSPACEEXW;

#define LCSEX_ANSICREATED 0x0001
#define LCSEX_TEMPPROFILE 0x0002

W32KAPI HANDLE WINAPI NtGdiCreateColorSpace(PLOGCOLORSPACEEXW pLogColorSpace);
W32KAPI WINBOOL WINAPI NtGdiDeleteColorSpace(HANDLE hColorSpace);
W32KAPI WINBOOL WINAPI NtGdiSetColorSpace(HDC hdc,HCOLORSPACE hColorSpace);
W32KAPI HANDLE WINAPI NtGdiCreateColorTransform(HDC hdc,LPLOGCOLORSPACEW pLogColorSpaceW,PVOID pvSrcProfile,ULONG cjSrcProfile,PVOID pvDestProfile,ULONG cjDestProfile,PVOID pvTargetProfile,ULONG cjTargetProfile);
W32KAPI WINBOOL WINAPI NtGdiDeleteColorTransform(HDC hdc,HANDLE hColorTransform);
W32KAPI WINBOOL WINAPI NtGdiCheckBitmapBits(HDC hdc,HANDLE hColorTransform,PVOID pvBits,ULONG bmFormat,DWORD dwWidth,DWORD dwHeight,DWORD dwStride,PBYTE paResults);
W32KAPI ULONG WINAPI NtGdiColorCorrectPalette(HDC hdc,HPALETTE hpal,ULONG FirstEntry,ULONG NumberOfEntries,PALETTEENTRY *ppalEntry,ULONG Command);
W32KAPI ULONG_PTR WINAPI NtGdiGetColorSpaceforBitmap(HBITMAP hsurf);

typedef enum _COLORPALETTEINFO {
  ColorPaletteQuery,ColorPaletteSet
} COLORPALETTEINFO,*PCOLORPALETTEINFO;

W32KAPI WINBOOL WINAPI NtGdiGetDeviceGammaRamp(HDC hdc,LPVOID lpGammaRamp);
W32KAPI WINBOOL WINAPI NtGdiSetDeviceGammaRamp(HDC hdc,LPVOID lpGammaRamp);
W32KAPI WINBOOL WINAPI NtGdiIcmBrushInfo(HDC hdc,HBRUSH hbrush,PBITMAPINFO pbmiDIB,PVOID pvBits,ULONG *pulBits,DWORD *piUsage,WINBOOL *pbAlreadyTran,ULONG Command);

typedef enum _ICM_DIB_INFO_CMD {
  IcmQueryBrush,IcmSetBrush
} ICM_DIB_INFO,*PICM_DIB_INFO;

W32KAPI VOID WINAPI NtGdiFlush();
W32KAPI HDC WINAPI NtGdiCreateMetafileDC(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiMakeInfoDC(HDC hdc,WINBOOL bSet);
W32KAPI HANDLE WINAPI NtGdiCreateClientObj(ULONG ulType);
W32KAPI WINBOOL WINAPI NtGdiDeleteClientObj(HANDLE h);
W32KAPI LONG WINAPI NtGdiGetBitmapBits(HBITMAP hbm,ULONG cjMax,PBYTE pjOut);
W32KAPI WINBOOL WINAPI NtGdiDeleteObjectApp(HANDLE hobj);
W32KAPI int WINAPI NtGdiGetPath(HDC hdc,LPPOINT pptlBuf,LPBYTE pjTypes,int cptBuf);
W32KAPI HDC WINAPI NtGdiCreateCompatibleDC(HDC hdc);
W32KAPI HBITMAP WINAPI NtGdiCreateDIBitmapInternal(HDC hdc,INT cx,INT cy,DWORD fInit,LPBYTE pjInit,LPBITMAPINFO pbmi,DWORD iUsage,UINT cjMaxInitInfo,UINT cjMaxBits,FLONG f,HANDLE hcmXform);
W32KAPI HBITMAP WINAPI NtGdiCreateDIBSection(HDC hdc,HANDLE hSectionApp,DWORD dwOffset,LPBITMAPINFO pbmi,DWORD iUsage,UINT cjHeader,FLONG fl,ULONG_PTR dwColorSpace,PVOID *ppvBits);
W32KAPI HBRUSH WINAPI NtGdiCreateSolidBrush(COLORREF cr,HBRUSH hbr);
W32KAPI HBRUSH WINAPI NtGdiCreateDIBBrush(PVOID pv,FLONG fl,UINT cj,WINBOOL b8X8,WINBOOL bPen,PVOID pClient);
W32KAPI HBRUSH WINAPI NtGdiCreatePatternBrushInternal(HBITMAP hbm,WINBOOL bPen,WINBOOL b8X8);
W32KAPI HBRUSH WINAPI NtGdiCreateHatchBrushInternal(ULONG ulStyle,COLORREF clrr,WINBOOL bPen);
W32KAPI HPEN WINAPI NtGdiExtCreatePen(ULONG flPenStyle,ULONG ulWidth,ULONG iBrushStyle,ULONG ulColor,ULONG_PTR lClientHatch,ULONG_PTR lHatch,ULONG cstyle,PULONG pulStyle,ULONG cjDIB,WINBOOL bOldStylePen,HBRUSH hbrush);
W32KAPI HRGN WINAPI NtGdiCreateEllipticRgn(int xLeft,int yTop,int xRight,int yBottom);
W32KAPI HRGN WINAPI NtGdiCreateRoundRectRgn(int xLeft,int yTop,int xRight,int yBottom,int xWidth,int yHeight);
W32KAPI HANDLE WINAPI NtGdiCreateServerMetaFile(DWORD iType,ULONG cjData,LPBYTE pjData,DWORD mm,DWORD xExt,DWORD yExt);
W32KAPI HRGN WINAPI NtGdiExtCreateRegion(LPXFORM px,DWORD cj,LPRGNDATA prgn);
W32KAPI ULONG WINAPI NtGdiMakeFontDir(FLONG flEmbed,PBYTE pjFontDir,unsigned cjFontDir,LPWSTR pwszPathname,unsigned cjPathname);
W32KAPI WINBOOL WINAPI NtGdiPolyDraw(HDC hdc,LPPOINT ppt,LPBYTE pjAttr,ULONG cpt);
W32KAPI WINBOOL WINAPI NtGdiPolyTextOutW(HDC hdc,POLYTEXTW *pptw,UINT cStr,DWORD dwCodePage);
W32KAPI ULONG WINAPI NtGdiGetServerMetaFileBits(HANDLE hmo,ULONG cjData,LPBYTE pjData,PDWORD piType,PDWORD pmm,PDWORD pxExt,PDWORD pyExt);
W32KAPI WINBOOL WINAPI NtGdiEqualRgn(HRGN hrgn1,HRGN hrgn2);
W32KAPI WINBOOL WINAPI NtGdiGetBitmapDimension(HBITMAP hbm,LPSIZE psize);
W32KAPI UINT WINAPI NtGdiGetNearestPaletteIndex(HPALETTE hpal,COLORREF crColor);
W32KAPI WINBOOL WINAPI NtGdiPtVisible(HDC hdc,int x,int y);
W32KAPI WINBOOL WINAPI NtGdiRectVisible(HDC hdc,LPRECT prc);
W32KAPI WINBOOL WINAPI NtGdiRemoveFontResourceW(WCHAR *pwszFiles,ULONG cwc,ULONG cFiles,ULONG fl,DWORD dwPidTid,DESIGNVECTOR *pdv);
W32KAPI WINBOOL WINAPI NtGdiResizePalette(HPALETTE hpal,UINT cEntry);
W32KAPI WINBOOL WINAPI NtGdiSetBitmapDimension(HBITMAP hbm,int cx,int cy,LPSIZE psizeOut);
W32KAPI int WINAPI NtGdiOffsetClipRgn(HDC hdc,int x,int y);
W32KAPI int WINAPI NtGdiSetMetaRgn(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiSetTextJustification(HDC hdc,int lBreakExtra,int cBreak);
W32KAPI int WINAPI NtGdiGetAppClipBox(HDC hdc,LPRECT prc);
W32KAPI WINBOOL WINAPI NtGdiGetTextExtentExW(HDC hdc,LPWSTR lpwsz,ULONG cwc,ULONG dxMax,ULONG *pcCh,PULONG pdxOut,LPSIZE psize,FLONG fl);
W32KAPI WINBOOL WINAPI NtGdiGetCharABCWidthsW(HDC hdc,UINT wchFirst,ULONG cwch,PWCHAR pwch,FLONG fl,PVOID pvBuf);
W32KAPI DWORD WINAPI NtGdiGetCharacterPlacementW(HDC hdc,LPWSTR pwsz,int nCount,int nMaxExtent,LPGCP_RESULTSW pgcpw,DWORD dwFlags);
W32KAPI WINBOOL WINAPI NtGdiAngleArc(HDC hdc,int x,int y,DWORD dwRadius,DWORD dwStartAngle,DWORD dwSweepAngle);
W32KAPI WINBOOL WINAPI NtGdiBeginPath(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiSelectClipPath(HDC hdc,int iMode);
W32KAPI WINBOOL WINAPI NtGdiCloseFigure(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiEndPath(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiAbortPath(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiFillPath(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiStrokeAndFillPath(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiStrokePath(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiWidenPath(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiFlattenPath(HDC hdc);
W32KAPI HRGN WINAPI NtGdiPathToRegion(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiSetMiterLimit(HDC hdc,DWORD dwNew,PDWORD pdwOut);
W32KAPI WINBOOL WINAPI NtGdiSetFontXform(HDC hdc,DWORD dwxScale,DWORD dwyScale);
W32KAPI WINBOOL WINAPI NtGdiGetMiterLimit(HDC hdc,PDWORD pdwOut);
W32KAPI WINBOOL WINAPI NtGdiEllipse(HDC hdc,int xLeft,int yTop,int xRight,int yBottom);
W32KAPI WINBOOL WINAPI NtGdiRectangle(HDC hdc,int xLeft,int yTop,int xRight,int yBottom);
W32KAPI WINBOOL WINAPI NtGdiRoundRect(HDC hdc,int x1,int y1,int x2,int y2,int x3,int y3);
W32KAPI WINBOOL WINAPI NtGdiPlgBlt(HDC hdcTrg,LPPOINT pptlTrg,HDC hdcSrc,int xSrc,int ySrc,int cxSrc,int cySrc,HBITMAP hbmMask,int xMask,int yMask,DWORD crBackColor);
W32KAPI WINBOOL WINAPI NtGdiMaskBlt(HDC hdc,int xDst,int yDst,int cx,int cy,HDC hdcSrc,int xSrc,int ySrc,HBITMAP hbmMask,int xMask,int yMask,DWORD dwRop4,DWORD crBackColor);
W32KAPI WINBOOL WINAPI NtGdiExtFloodFill(HDC hdc,INT x,INT y,COLORREF crColor,UINT iFillType);
W32KAPI WINBOOL WINAPI NtGdiFillRgn(HDC hdc,HRGN hrgn,HBRUSH hbrush);
W32KAPI WINBOOL WINAPI NtGdiFrameRgn(HDC hdc,HRGN hrgn,HBRUSH hbrush,int xWidth,int yHeight);
W32KAPI COLORREF WINAPI NtGdiSetPixel(HDC hdcDst,int x,int y,COLORREF crColor);
W32KAPI DWORD WINAPI NtGdiGetPixel(HDC hdc,int x,int y);
W32KAPI WINBOOL WINAPI NtGdiStartPage(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiEndPage(HDC hdc);
W32KAPI int WINAPI NtGdiStartDoc(HDC hdc,DOCINFOW *pdi,WINBOOL *pbBanding,INT iJob);
W32KAPI WINBOOL WINAPI NtGdiEndDoc(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiAbortDoc(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiUpdateColors(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiGetCharWidthW(HDC hdc,UINT wcFirst,UINT cwc,PWCHAR pwc,FLONG fl,PVOID pvBuf);
W32KAPI WINBOOL WINAPI NtGdiGetCharWidthInfo(HDC hdc,PCHWIDTHINFO pChWidthInfo);
W32KAPI int WINAPI NtGdiDrawEscape(HDC hdc,int iEsc,int cjIn,LPSTR pjIn);
W32KAPI int WINAPI NtGdiExtEscape(HDC hdc,PWCHAR pDriver,int nDriver,int iEsc,int cjIn,LPSTR pjIn,int cjOut,LPSTR pjOut);
W32KAPI ULONG WINAPI NtGdiGetFontData(HDC hdc,DWORD dwTable,DWORD dwOffset,PVOID pvBuf,ULONG cjBuf);
W32KAPI ULONG WINAPI NtGdiGetGlyphOutline(HDC hdc,WCHAR wch,UINT iFormat,LPGLYPHMETRICS pgm,ULONG cjBuf,PVOID pvBuf,LPMAT2 pmat2,WINBOOL bIgnoreRotation);
W32KAPI WINBOOL WINAPI NtGdiGetETM(HDC hdc,EXTTEXTMETRIC *petm);
W32KAPI WINBOOL WINAPI NtGdiGetRasterizerCaps(LPRASTERIZER_STATUS praststat,ULONG cjBytes);
W32KAPI ULONG WINAPI NtGdiGetKerningPairs(HDC hdc,ULONG cPairs,KERNINGPAIR *pkpDst);
W32KAPI WINBOOL WINAPI NtGdiMonoBitmap(HBITMAP hbm);
W32KAPI HBITMAP WINAPI NtGdiGetObjectBitmapHandle(HBRUSH hbr,UINT *piUsage);
W32KAPI ULONG WINAPI NtGdiEnumObjects(HDC hdc,int iObjectType,ULONG cjBuf,PVOID pvBuf);
W32KAPI WINBOOL WINAPI NtGdiResetDC(HDC hdc,LPDEVMODEW pdm,PBOOL pbBanding,VOID *pDriverInfo2,VOID *ppUMdhpdev);
W32KAPI DWORD WINAPI NtGdiSetBoundsRect(HDC hdc,LPRECT prc,DWORD f);
W32KAPI WINBOOL WINAPI NtGdiGetColorAdjustment(HDC hdc,PCOLORADJUSTMENT pcaOut);
W32KAPI WINBOOL WINAPI NtGdiSetColorAdjustment(HDC hdc,PCOLORADJUSTMENT pca);
W32KAPI WINBOOL WINAPI NtGdiCancelDC(HDC hdc);
W32KAPI HDC WINAPI NtGdiOpenDCW(PUNICODE_STRING pustrDevice,DEVMODEW *pdm,PUNICODE_STRING pustrLogAddr,ULONG iType,HANDLE hspool,VOID *pDriverInfo2,VOID *pUMdhpdev);
W32KAPI WINBOOL WINAPI NtGdiGetDCDword(HDC hdc,UINT u,DWORD *Result);
W32KAPI WINBOOL WINAPI NtGdiGetDCPoint(HDC hdc,UINT iPoint,PPOINTL pptOut);
W32KAPI WINBOOL WINAPI NtGdiScaleViewportExtEx(HDC hdc,int xNum,int xDenom,int yNum,int yDenom,LPSIZE pszOut);
W32KAPI WINBOOL WINAPI NtGdiScaleWindowExtEx(HDC hdc,int xNum,int xDenom,int yNum,int yDenom,LPSIZE pszOut);
W32KAPI WINBOOL WINAPI NtGdiSetVirtualResolution(HDC hdc,int cxVirtualDevicePixel,int cyVirtualDevicePixel,int cxVirtualDeviceMm,int cyVirtualDeviceMm);
W32KAPI WINBOOL WINAPI NtGdiSetSizeDevice(HDC hdc,int cxVirtualDevice,int cyVirtualDevice);
W32KAPI WINBOOL WINAPI NtGdiGetTransform(HDC hdc,DWORD iXform,LPXFORM pxf);
W32KAPI WINBOOL WINAPI NtGdiModifyWorldTransform(HDC hdc,LPXFORM pxf,DWORD iXform);
W32KAPI WINBOOL WINAPI NtGdiCombineTransform(LPXFORM pxfDst,LPXFORM pxfSrc1,LPXFORM pxfSrc2);
W32KAPI WINBOOL WINAPI NtGdiTransformPoints(HDC hdc,PPOINT pptIn,PPOINT pptOut,int c,int iMode);
W32KAPI LONG WINAPI NtGdiConvertMetafileRect(HDC hdc,PRECTL prect);
W32KAPI int WINAPI NtGdiGetTextCharsetInfo(HDC hdc,LPFONTSIGNATURE lpSig,DWORD dwFlags);
W32KAPI WINBOOL WINAPI NtGdiDoBanding(HDC hdc,WINBOOL bStart,POINTL *pptl,PSIZE pSize);
W32KAPI ULONG WINAPI NtGdiGetPerBandInfo(HDC hdc,PERBANDINFO *ppbi);

#define GS_NUM_OBJS_ALL 0
#define GS_HANDOBJ_CURRENT 1
#define GS_HANDOBJ_MAX 2
#define GS_HANDOBJ_ALLOC 3
#define GS_LOOKASIDE_INFO 4

W32KAPI NTSTATUS WINAPI NtGdiGetStats(HANDLE hProcess,int iIndex,int iPidType,PVOID pResults,UINT cjResultSize);
W32KAPI WINBOOL WINAPI NtGdiSetMagicColors(HDC hdc,PALETTEENTRY peMagic,ULONG Index);
W32KAPI HBRUSH WINAPI NtGdiSelectBrush(HDC hdc,HBRUSH hbrush);
W32KAPI HPEN WINAPI NtGdiSelectPen(HDC hdc,HPEN hpen);
W32KAPI HBITMAP WINAPI NtGdiSelectBitmap(HDC hdc,HBITMAP hbm);
W32KAPI HFONT WINAPI NtGdiSelectFont(HDC hdc,HFONT hf);
W32KAPI int WINAPI NtGdiExtSelectClipRgn(HDC hdc,HRGN hrgn,int iMode);
W32KAPI HPEN WINAPI NtGdiCreatePen(int iPenStyle,int iPenWidth,COLORREF cr,HBRUSH hbr);

#ifndef _WINDOWBLT_NOTIFICATION_
#define _WINDOWBLT_NOTIFICATION_
#endif

W32KAPI WINBOOL WINAPI NtGdiBitBlt(HDC hdcDst,int x,int y,int cx,int cy,HDC hdcSrc,int xSrc,int ySrc,DWORD rop4,DWORD crBackColor,FLONG fl);
W32KAPI WINBOOL WINAPI NtGdiTileBitBlt(HDC hdcDst,RECTL *prectDst,HDC hdcSrc,RECTL *prectSrc,POINTL *pptlOrigin,DWORD rop4,DWORD crBackColor);
W32KAPI WINBOOL WINAPI NtGdiTransparentBlt(HDC hdcDst,int xDst,int yDst,int cxDst,int cyDst,HDC hdcSrc,int xSrc,int ySrc,int cxSrc,int cySrc,COLORREF TransColor);
W32KAPI WINBOOL WINAPI NtGdiGetTextExtent(HDC hdc,LPWSTR lpwsz,int cwc,LPSIZE psize,UINT flOpts);
W32KAPI WINBOOL WINAPI NtGdiGetTextMetricsW(HDC hdc,TMW_INTERNAL *ptm,ULONG cj);
W32KAPI int WINAPI NtGdiGetTextFaceW(HDC hdc,int cChar,LPWSTR pszOut,WINBOOL bAliasName);
W32KAPI int WINAPI NtGdiGetRandomRgn(HDC hdc,HRGN hrgn,int iRgn);
W32KAPI WINBOOL WINAPI NtGdiExtTextOutW(HDC hdc,int x,int y,UINT flOpts,LPRECT prcl,LPWSTR pwsz,int cwc,LPINT pdx,DWORD dwCodePage);
W32KAPI int WINAPI NtGdiIntersectClipRect(HDC hdc,int xLeft,int yTop,int xRight,int yBottom);
W32KAPI HRGN WINAPI NtGdiCreateRectRgn(int xLeft,int yTop,int xRight,int yBottom);
W32KAPI WINBOOL WINAPI NtGdiPatBlt(HDC hdcDst,int x,int y,int cx,int cy,DWORD rop4);

typedef struct _POLYPATBLT POLYPATBLT,*PPOLYPATBLT;

W32KAPI WINBOOL WINAPI NtGdiPolyPatBlt(HDC hdc,DWORD rop4,PPOLYPATBLT pPoly,DWORD Count,DWORD Mode);
W32KAPI WINBOOL WINAPI NtGdiUnrealizeObject(HANDLE h);
W32KAPI HANDLE WINAPI NtGdiGetStockObject(int iObject);
W32KAPI HBITMAP WINAPI NtGdiCreateCompatibleBitmap(HDC hdc,int cx,int cy);
W32KAPI WINBOOL WINAPI NtGdiLineTo(HDC hdc,int x,int y);
W32KAPI WINBOOL WINAPI NtGdiMoveTo(HDC hdc,int x,int y,LPPOINT pptOut);
W32KAPI int WINAPI NtGdiExtGetObjectW(HANDLE h,int cj,LPVOID pvOut);
W32KAPI int WINAPI NtGdiGetDeviceCaps(HDC hdc,int i);
W32KAPI WINBOOL WINAPI NtGdiGetDeviceCapsAll (HDC hdc,PDEVCAPS pDevCaps);
W32KAPI WINBOOL WINAPI NtGdiStretchBlt(HDC hdcDst,int xDst,int yDst,int cxDst,int cyDst,HDC hdcSrc,int xSrc,int ySrc,int cxSrc,int cySrc,DWORD dwRop,DWORD dwBackColor);
W32KAPI WINBOOL WINAPI NtGdiSetBrushOrg(HDC hdc,int x,int y,LPPOINT pptOut);
W32KAPI HBITMAP WINAPI NtGdiCreateBitmap(int cx,int cy,UINT cPlanes,UINT cBPP,LPBYTE pjInit);
W32KAPI HPALETTE WINAPI NtGdiCreateHalftonePalette(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiRestoreDC(HDC hdc,int iLevel);
W32KAPI int WINAPI NtGdiExcludeClipRect(HDC hdc,int xLeft,int yTop,int xRight,int yBottom);
W32KAPI int WINAPI NtGdiSaveDC(HDC hdc);
W32KAPI int WINAPI NtGdiCombineRgn(HRGN hrgnDst,HRGN hrgnSrc1,HRGN hrgnSrc2,int iMode);
W32KAPI WINBOOL WINAPI NtGdiSetRectRgn(HRGN hrgn,int xLeft,int yTop,int xRight,int yBottom);
W32KAPI LONG WINAPI NtGdiSetBitmapBits(HBITMAP hbm,ULONG cj,PBYTE pjInit);
W32KAPI int WINAPI NtGdiGetDIBitsInternal(HDC hdc,HBITMAP hbm,UINT iStartScan,UINT cScans,LPBYTE pBits,LPBITMAPINFO pbmi,UINT iUsage,UINT cjMaxBits,UINT cjMaxInfo);
W32KAPI int WINAPI NtGdiOffsetRgn(HRGN hrgn,int cx,int cy);
W32KAPI int WINAPI NtGdiGetRgnBox(HRGN hrgn,LPRECT prcOut);
W32KAPI WINBOOL WINAPI NtGdiRectInRegion(HRGN hrgn,LPRECT prcl);
W32KAPI DWORD WINAPI NtGdiGetBoundsRect(HDC hdc,LPRECT prc,DWORD f);
W32KAPI WINBOOL WINAPI NtGdiPtInRegion(HRGN hrgn,int x,int y);
W32KAPI COLORREF WINAPI NtGdiGetNearestColor(HDC hdc,COLORREF cr);
W32KAPI UINT WINAPI NtGdiGetSystemPaletteUse(HDC hdc);
W32KAPI UINT WINAPI NtGdiSetSystemPaletteUse(HDC hdc,UINT ui);
W32KAPI DWORD WINAPI NtGdiGetRegionData(HRGN hrgn,DWORD nCount,LPRGNDATA lpRgnData);
W32KAPI WINBOOL WINAPI NtGdiInvertRgn(HDC hdc,HRGN hrgn);
int W32KAPI WINAPI NtGdiAddFontResourceW(WCHAR *pwszFiles,ULONG cwc,ULONG cFiles,FLONG f,DWORD dwPidTid,DESIGNVECTOR *pdv);
W32KAPI HFONT WINAPI NtGdiHfontCreate(ENUMLOGFONTEXDVW *pelfw,ULONG cjElfw,LFTYPE lft,FLONG fl,PVOID pvCliData);
W32KAPI ULONG WINAPI NtGdiSetFontEnumeration(ULONG ulType);
W32KAPI WINBOOL WINAPI NtGdiEnumFontClose(ULONG_PTR idEnum);
W32KAPI WINBOOL WINAPI NtGdiEnumFontChunk(HDC hdc,ULONG_PTR idEnum,ULONG cjEfdw,ULONG *pcjEfdw,PENUMFONTDATAW pefdw);
W32KAPI ULONG_PTR WINAPI NtGdiEnumFontOpen(HDC hdc,ULONG iEnumType,FLONG flWin31Compat,ULONG cwchMax,LPWSTR pwszFaceName,ULONG lfCharSet,ULONG *pulCount);

#define TYPE_ENUMFONTS 1
#define TYPE_ENUMFONTFAMILIES 2
#define TYPE_ENUMFONTFAMILIESEX 3

W32KAPI INT WINAPI NtGdiQueryFonts(PUNIVERSAL_FONT_ID pufiFontList,ULONG nBufferSize,PLARGE_INTEGER pTimeStamp);
W32KAPI WINBOOL WINAPI NtGdiConsoleTextOut(HDC hdc,POLYTEXTW *lpto,UINT nStrings,RECTL *prclBounds);
W32KAPI NTSTATUS WINAPI NtGdiFullscreenControl(FULLSCREENCONTROL FullscreenCommand,PVOID FullscreenInput,DWORD FullscreenInputLength,PVOID FullscreenOutput,PULONG FullscreenOutputLength);
W32KAPI DWORD NtGdiGetCharSet(HDC hdc);
W32KAPI WINBOOL WINAPI NtGdiEnableEudc(WINBOOL);
W32KAPI WINBOOL WINAPI NtGdiEudcLoadUnloadLink(LPCWSTR pBaseFaceName,UINT cwcBaseFaceName,LPCWSTR pEudcFontPath,UINT cwcEudcFontPath,INT iPriority,INT iFontLinkType,WINBOOL bLoadLin);
W32KAPI UINT WINAPI NtGdiGetStringBitmapW(HDC hdc,LPWSTR pwsz,UINT cwc,BYTE *lpSB,UINT cj);
W32KAPI ULONG WINAPI NtGdiGetEudcTimeStampEx(LPWSTR lpBaseFaceName,ULONG cwcBaseFaceName,WINBOOL bSystemTimeStamp);
W32KAPI ULONG WINAPI NtGdiQueryFontAssocInfo(HDC hdc);
W32KAPI DWORD NtGdiGetFontUnicodeRanges(HDC hdc,LPGLYPHSET pgs);

#ifdef LANGPACK
W32KAPI WINBOOL NtGdiGetRealizationInfo(HDC hdc,PREALIZATION_INFO pri,HFONT hf);
#endif

typedef struct tagDOWNLOADDESIGNVECTOR {
  UNIVERSAL_FONT_ID ufiBase;
  DESIGNVECTOR dv;
} DOWNLOADDESIGNVECTOR;

W32KAPI WINBOOL NtGdiAddRemoteMMInstanceToDC(HDC hdc,DOWNLOADDESIGNVECTOR *pddv,ULONG cjDDV);
W32KAPI WINBOOL WINAPI NtGdiUnloadPrinterDriver(LPWSTR pDriverName,ULONG cbDriverName);
W32KAPI WINBOOL WINAPI NtGdiEngAssociateSurface(HSURF hsurf,HDEV hdev,FLONG flHooks);
W32KAPI WINBOOL WINAPI NtGdiEngEraseSurface(SURFOBJ *pso,RECTL *prcl,ULONG iColor);
W32KAPI HBITMAP WINAPI NtGdiEngCreateBitmap(SIZEL sizl,LONG lWidth,ULONG iFormat,FLONG fl,PVOID pvBits);
W32KAPI WINBOOL WINAPI NtGdiEngDeleteSurface(HSURF hsurf);
W32KAPI SURFOBJ *WINAPI NtGdiEngLockSurface(HSURF hsurf);
W32KAPI VOID WINAPI NtGdiEngUnlockSurface(SURFOBJ *);
W32KAPI WINBOOL WINAPI NtGdiEngMarkBandingSurface(HSURF hsurf);
W32KAPI HSURF WINAPI NtGdiEngCreateDeviceSurface(DHSURF dhsurf,SIZEL sizl,ULONG iFormatCompat);
W32KAPI HBITMAP WINAPI NtGdiEngCreateDeviceBitmap(DHSURF dhsurf,SIZEL sizl,ULONG iFormatCompat);
W32KAPI WINBOOL WINAPI NtGdiEngCopyBits(SURFOBJ *psoDst,SURFOBJ *psoSrc,CLIPOBJ *pco,XLATEOBJ *pxlo,RECTL *prclDst,POINTL *pptlSrc);
W32KAPI WINBOOL WINAPI NtGdiEngStretchBlt(SURFOBJ *psoDest,SURFOBJ *psoSrc,SURFOBJ *psoMask,CLIPOBJ *pco,XLATEOBJ *pxlo,COLORADJUSTMENT *pca,POINTL *pptlHTOrg,RECTL *prclDest,RECTL *prclSrc,POINTL *pptlMask,ULONG iMode);
W32KAPI WINBOOL WINAPI NtGdiEngBitBlt(SURFOBJ *psoDst,SURFOBJ *psoSrc,SURFOBJ *psoMask,CLIPOBJ *pco,XLATEOBJ *pxlo,RECTL *prclDst,POINTL *pptlSrc,POINTL *pptlMask,BRUSHOBJ *pbo,POINTL *pptlBrush,ROP4 rop4);
W32KAPI WINBOOL WINAPI NtGdiEngPlgBlt(SURFOBJ *psoTrg,SURFOBJ *psoSrc,SURFOBJ *psoMsk,CLIPOBJ *pco,XLATEOBJ *pxlo,COLORADJUSTMENT *pca,POINTL *pptlBrushOrg,POINTFIX *pptfxDest,RECTL *prclSrc,POINTL *pptlMask,ULONG iMode);
W32KAPI HPALETTE WINAPI NtGdiEngCreatePalette(ULONG iMode,ULONG cColors,ULONG *pulColors,FLONG flRed,FLONG flGreen,FLONG flBlue);
W32KAPI WINBOOL WINAPI NtGdiEngDeletePalette(HPALETTE hPal);
W32KAPI WINBOOL WINAPI NtGdiEngStrokePath(SURFOBJ *pso,PATHOBJ *ppo,CLIPOBJ *pco,XFORMOBJ *pxo,BRUSHOBJ *pbo,POINTL *pptlBrushOrg,LINEATTRS *plineattrs,MIX mix);
W32KAPI WINBOOL WINAPI NtGdiEngFillPath(SURFOBJ *pso,PATHOBJ *ppo,CLIPOBJ *pco,BRUSHOBJ *pbo,POINTL *pptlBrushOrg,MIX mix,FLONG flOptions);
W32KAPI WINBOOL WINAPI NtGdiEngStrokeAndFillPath(SURFOBJ *pso,PATHOBJ *ppo,CLIPOBJ *pco,XFORMOBJ *pxo,BRUSHOBJ *pboStroke,LINEATTRS *plineattrs,BRUSHOBJ *pboFill,POINTL *pptlBrushOrg,MIX mix,FLONG flOptions);
W32KAPI WINBOOL WINAPI NtGdiEngPaint(SURFOBJ *pso,CLIPOBJ *pco,BRUSHOBJ *pbo,POINTL *pptlBrushOrg,MIX mix);
W32KAPI WINBOOL WINAPI NtGdiEngLineTo(SURFOBJ *pso,CLIPOBJ *pco,BRUSHOBJ *pbo,LONG x1,LONG y1,LONG x2,LONG y2,RECTL *prclBounds,MIX mix);
W32KAPI WINBOOL WINAPI NtGdiEngAlphaBlend(SURFOBJ *psoDest,SURFOBJ *psoSrc,CLIPOBJ *pco,XLATEOBJ *pxlo,RECTL *prclDest,RECTL *prclSrc,BLENDOBJ *pBlendObj);
W32KAPI WINBOOL WINAPI NtGdiEngGradientFill(SURFOBJ *psoDest,CLIPOBJ *pco,XLATEOBJ *pxlo,TRIVERTEX *pVertex,ULONG nVertex,PVOID pMesh,ULONG nMesh,RECTL *prclExtents,POINTL *pptlDitherOrg,ULONG ulMode);
W32KAPI WINBOOL WINAPI NtGdiEngTransparentBlt(SURFOBJ *psoDst,SURFOBJ *psoSrc,CLIPOBJ *pco,XLATEOBJ *pxlo,RECTL *prclDst,RECTL *prclSrc,ULONG iTransColor,ULONG ulReserved);
W32KAPI WINBOOL WINAPI NtGdiEngTextOut(SURFOBJ *pso,STROBJ *pstro,FONTOBJ *pfo,CLIPOBJ *pco,RECTL *prclExtra,RECTL *prclOpaque,BRUSHOBJ *pboFore,BRUSHOBJ *pboOpaque,POINTL *pptlOrg,MIX mix);
W32KAPI WINBOOL WINAPI NtGdiEngStretchBltROP(SURFOBJ *psoTrg,SURFOBJ *psoSrc,SURFOBJ *psoMask,CLIPOBJ *pco,XLATEOBJ *pxlo,COLORADJUSTMENT *pca,POINTL *pptlBrushOrg,RECTL *prclTrg,RECTL *prclSrc,POINTL *pptlMask,ULONG iMode,BRUSHOBJ *pbo,ROP4 rop4);
W32KAPI ULONG WINAPI NtGdiXLATEOBJ_cGetPalette(XLATEOBJ *pxlo,ULONG iPal,ULONG cPal,ULONG *pPal);
W32KAPI ULONG WINAPI NtGdiCLIPOBJ_cEnumStart(CLIPOBJ *pco,WINBOOL bAll,ULONG iType,ULONG iDirection,ULONG cLimit);
W32KAPI WINBOOL WINAPI NtGdiCLIPOBJ_bEnum(CLIPOBJ *pco,ULONG cj,ULONG *pul);
W32KAPI PATHOBJ *WINAPI NtGdiCLIPOBJ_ppoGetPath(CLIPOBJ *pco);
W32KAPI CLIPOBJ *WINAPI NtGdiEngCreateClip();
W32KAPI VOID WINAPI NtGdiEngDeleteClip(CLIPOBJ*pco);
W32KAPI PVOID WINAPI NtGdiBRUSHOBJ_pvAllocRbrush(BRUSHOBJ *pbo,ULONG cj);
W32KAPI PVOID WINAPI NtGdiBRUSHOBJ_pvGetRbrush(BRUSHOBJ *pbo);
W32KAPI ULONG WINAPI NtGdiBRUSHOBJ_ulGetBrushColor(BRUSHOBJ *pbo);
W32KAPI HANDLE WINAPI NtGdiBRUSHOBJ_hGetColorTransform(BRUSHOBJ *pbo);
W32KAPI WINBOOL WINAPI NtGdiXFORMOBJ_bApplyXform(XFORMOBJ *pxo,ULONG iMode,ULONG cPoints,PVOID pvIn,PVOID pvOut);
W32KAPI ULONG WINAPI NtGdiXFORMOBJ_iGetXform(XFORMOBJ *pxo,XFORML *pxform);
W32KAPI VOID WINAPI NtGdiFONTOBJ_vGetInfo(FONTOBJ *pfo,ULONG cjSize,FONTINFO *pfi);
W32KAPI ULONG WINAPI NtGdiFONTOBJ_cGetGlyphs(FONTOBJ *pfo,ULONG iMode,ULONG cGlyph,HGLYPH *phg,PVOID *ppvGlyph);
W32KAPI XFORMOBJ *WINAPI NtGdiFONTOBJ_pxoGetXform(FONTOBJ *pfo);
W32KAPI IFIMETRICS *WINAPI NtGdiFONTOBJ_pifi(FONTOBJ *pfo);
W32KAPI FD_GLYPHSET *WINAPI NtGdiFONTOBJ_pfdg(FONTOBJ *pfo);
W32KAPI ULONG WINAPI NtGdiFONTOBJ_cGetAllGlyphHandles(FONTOBJ *pfo,HGLYPH *phg);
W32KAPI PVOID WINAPI NtGdiFONTOBJ_pvTrueTypeFontFile(FONTOBJ *pfo,ULONG *pcjFile);
W32KAPI PFD_GLYPHATTR WINAPI NtGdiFONTOBJ_pQueryGlyphAttrs(FONTOBJ *pfo,ULONG iMode);
W32KAPI WINBOOL WINAPI NtGdiSTROBJ_bEnum(STROBJ *pstro,ULONG *pc,PGLYPHPOS *ppgpos);
W32KAPI WINBOOL WINAPI NtGdiSTROBJ_bEnumPositionsOnly(STROBJ *pstro,ULONG *pc,PGLYPHPOS *ppgpos);
W32KAPI VOID WINAPI NtGdiSTROBJ_vEnumStart(STROBJ *pstro);
W32KAPI DWORD WINAPI NtGdiSTROBJ_dwGetCodePage(STROBJ *pstro);
W32KAPI WINBOOL WINAPI NtGdiSTROBJ_bGetAdvanceWidths(STROBJ*pstro,ULONG iFirst,ULONG c,POINTQF*pptqD);
W32KAPI FD_GLYPHSET *WINAPI NtGdiEngComputeGlyphSet(INT nCodePage,INT nFirstChar,INT cChars);
W32KAPI ULONG WINAPI NtGdiXLATEOBJ_iXlate(XLATEOBJ *pxlo,ULONG iColor);
W32KAPI HANDLE WINAPI NtGdiXLATEOBJ_hGetColorTransform(XLATEOBJ *pxlo);
W32KAPI VOID WINAPI NtGdiPATHOBJ_vGetBounds(PATHOBJ *ppo,PRECTFX prectfx);
W32KAPI WINBOOL WINAPI NtGdiPATHOBJ_bEnum(PATHOBJ *ppo,PATHDATA *ppd);
W32KAPI VOID WINAPI NtGdiPATHOBJ_vEnumStart(PATHOBJ *ppo);
W32KAPI VOID WINAPI NtGdiEngDeletePath(PATHOBJ *ppo);
W32KAPI VOID WINAPI NtGdiPATHOBJ_vEnumStartClipLines(PATHOBJ *ppo,CLIPOBJ *pco,SURFOBJ *pso,LINEATTRS *pla);
W32KAPI WINBOOL WINAPI NtGdiPATHOBJ_bEnumClipLines(PATHOBJ *ppo,ULONG cb,CLIPLINE *pcl);
W32KAPI WINBOOL WINAPI NtGdiEngCheckAbort(SURFOBJ *pso);
W32KAPI DHPDEV NtGdiGetDhpdev(HDEV hdev);
W32KAPI LONG WINAPI NtGdiHT_Get8BPPFormatPalette(LPPALETTEENTRY pPaletteEntry,USHORT RedGamma,USHORT GreenGamma,USHORT BlueGamma);
W32KAPI LONG WINAPI NtGdiHT_Get8BPPMaskPalette(LPPALETTEENTRY pPaletteEntry,WINBOOL Use8BPPMaskPal,BYTE CMYMask,USHORT RedGamma,USHORT GreenGamma,USHORT BlueGamma);
W32KAPI WINBOOL NtGdiUpdateTransform(HDC hdc);
W32KAPI DWORD WINAPI NtGdiSetLayout(HDC hdc,LONG wox,DWORD dwLayout);
W32KAPI WINBOOL WINAPI NtGdiMirrorWindowOrg(HDC hdc);
W32KAPI LONG WINAPI NtGdiGetDeviceWidth(HDC hdc);
W32KAPI WINBOOL NtGdiSetPUMPDOBJ(HUMPD humpd,WINBOOL bStoreID,HUMPD *phumpd,WINBOOL *pbWOW64);
W32KAPI WINBOOL NtGdiBRUSHOBJ_DeleteRbrush(BRUSHOBJ *pbo,BRUSHOBJ *pboB);
W32KAPI WINBOOL NtGdiUMPDEngFreeUserMem(KERNEL_PVOID *ppv);
W32KAPI HBITMAP WINAPI NtGdiSetBitmapAttributes(HBITMAP hbm,DWORD dwFlags);
W32KAPI HBITMAP WINAPI NtGdiClearBitmapAttributes(HBITMAP hbm,DWORD dwFlags);
W32KAPI HBRUSH WINAPI NtGdiSetBrushAttributes(HBRUSH hbm,DWORD dwFlags);
W32KAPI HBRUSH WINAPI NtGdiClearBrushAttributes(HBRUSH hbm,DWORD dwFlags);
W32KAPI WINBOOL WINAPI NtGdiDrawStream(HDC hdcDst,ULONG cjIn,VOID *pvIn);
W32KAPI WINBOOL WINAPI NtGdiMakeObjectXferable(HANDLE h,DWORD dwProcessId);
W32KAPI WINBOOL WINAPI NtGdiMakeObjectUnXferable(HANDLE h);
