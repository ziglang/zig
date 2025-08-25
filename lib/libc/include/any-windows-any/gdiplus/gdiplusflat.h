/*
 * gdiplusflat.h
 *
 * GDI+ Flat API
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Markus Koenig <markus@stber-koenig.de>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef __GDIPLUS_FLAT_H
#define __GDIPLUS_FLAT_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

#ifdef __cplusplus
namespace DllExports {
extern "C" {
#endif

/* AdjustableArrowCap functions */
GpStatus WINGDIPAPI GdipCreateAdjustableArrowCap(REAL,REAL,BOOL,GpAdjustableArrowCap**);
GpStatus WINGDIPAPI GdipSetAdjustableArrowCapHeight(GpAdjustableArrowCap*,REAL);
GpStatus WINGDIPAPI GdipGetAdjustableArrowCapHeight(GpAdjustableArrowCap*,REAL*);
GpStatus WINGDIPAPI GdipSetAdjustableArrowCapWidth(GpAdjustableArrowCap*,REAL);
GpStatus WINGDIPAPI GdipGetAdjustableArrowCapWidth(GpAdjustableArrowCap*,REAL*);
GpStatus WINGDIPAPI GdipSetAdjustableArrowCapMiddleInset(GpAdjustableArrowCap*,REAL);
GpStatus WINGDIPAPI GdipGetAdjustableArrowCapMiddleInset(GpAdjustableArrowCap*,REAL*);
GpStatus WINGDIPAPI GdipSetAdjustableArrowCapFillState(GpAdjustableArrowCap*,BOOL);
GpStatus WINGDIPAPI GdipGetAdjustableArrowCapFillState(GpAdjustableArrowCap*,BOOL*);

/* Bitmap functions */
GpStatus WINGDIPAPI GdipCreateBitmapFromStream(IStream*,GpBitmap**);
GpStatus WINGDIPAPI GdipCreateBitmapFromFile(GDIPCONST WCHAR*,GpBitmap**);
GpStatus WINGDIPAPI GdipCreateBitmapFromStreamICM(IStream*,GpBitmap**);
GpStatus WINGDIPAPI GdipCreateBitmapFromFileICM(GDIPCONST WCHAR*,GpBitmap**);
GpStatus WINGDIPAPI GdipCreateBitmapFromScan0(INT,INT,INT,PixelFormat,BYTE*,GpBitmap**);
GpStatus WINGDIPAPI GdipCreateBitmapFromGraphics(INT,INT,GpGraphics*,GpBitmap**);
GpStatus WINGDIPAPI GdipCreateBitmapFromDirectDrawSurface(IDirectDrawSurface7*,GpBitmap**);
GpStatus WINGDIPAPI GdipCreateBitmapFromGdiDib(GDIPCONST BITMAPINFO*,VOID*,GpBitmap**);
GpStatus WINGDIPAPI GdipCreateBitmapFromHBITMAP(HBITMAP,HPALETTE,GpBitmap**);
GpStatus WINGDIPAPI GdipCreateHBITMAPFromBitmap(GpBitmap*,HBITMAP*,ARGB);
GpStatus WINGDIPAPI GdipCreateBitmapFromHICON(HICON,GpBitmap**);
GpStatus WINGDIPAPI GdipCreateHICONFromBitmap(GpBitmap*,HICON*);
GpStatus WINGDIPAPI GdipCreateBitmapFromResource(HINSTANCE,GDIPCONST WCHAR*,GpBitmap**);
GpStatus WINGDIPAPI GdipCloneBitmapArea(REAL,REAL,REAL,REAL,PixelFormat,GpBitmap*,GpBitmap**);
GpStatus WINGDIPAPI GdipCloneBitmapAreaI(INT,INT,INT,INT,PixelFormat,GpBitmap*,GpBitmap**);
GpStatus WINGDIPAPI GdipBitmapLockBits(GpBitmap*,GDIPCONST GpRect*,UINT,PixelFormat,BitmapData*);
GpStatus WINGDIPAPI GdipBitmapUnlockBits(GpBitmap*,BitmapData*);
GpStatus WINGDIPAPI GdipBitmapGetPixel(GpBitmap*,INT,INT,ARGB*);
GpStatus WINGDIPAPI GdipBitmapSetPixel(GpBitmap*,INT,INT,ARGB);
GpStatus WINGDIPAPI GdipBitmapSetResolution(GpBitmap*,REAL,REAL);
GpStatus WINGDIPAPI GdipBitmapConvertFormat(GpBitmap*,PixelFormat,DitherType,PaletteType,ColorPalette*,REAL);
GpStatus WINGDIPAPI GdipInitializePalette(ColorPalette*,PaletteType,INT,BOOL,GpBitmap*);
GpStatus WINGDIPAPI GdipBitmapApplyEffect(GpBitmap*,CGpEffect*,RECT*,BOOL,VOID**,INT*);
GpStatus WINGDIPAPI GdipBitmapCreateApplyEffect(GpBitmap**,INT,CGpEffect*,RECT*,RECT*,GpBitmap**,BOOL,VOID**,INT*);
GpStatus WINGDIPAPI GdipBitmapGetHistogram(GpBitmap*,HistogramFormat,UINT,UINT*,UINT*,UINT*,UINT*);
GpStatus WINGDIPAPI GdipBitmapGetHistogramSize(HistogramFormat,UINT*);

/* Brush functions */
GpStatus WINGDIPAPI GdipCloneBrush(GpBrush*,GpBrush**);
GpStatus WINGDIPAPI GdipDeleteBrush(GpBrush*);
GpStatus WINGDIPAPI GdipGetBrushType(GpBrush*,GpBrushType*);

/* CachedBitmap functions */
GpStatus WINGDIPAPI GdipCreateCachedBitmap(GpBitmap*,GpGraphics*,GpCachedBitmap**);
GpStatus WINGDIPAPI GdipDeleteCachedBitmap(GpCachedBitmap*);
GpStatus WINGDIPAPI GdipDrawCachedBitmap(GpGraphics*,GpCachedBitmap*,INT,INT);

/* CustomLineCap functions */
GpStatus WINGDIPAPI GdipCreateCustomLineCap(GpPath*,GpPath*,GpLineCap,REAL,GpCustomLineCap**);
GpStatus WINGDIPAPI GdipDeleteCustomLineCap(GpCustomLineCap*);
GpStatus WINGDIPAPI GdipCloneCustomLineCap(GpCustomLineCap*,GpCustomLineCap**);
GpStatus WINGDIPAPI GdipGetCustomLineCapType(GpCustomLineCap*,CustomLineCapType*);
GpStatus WINGDIPAPI GdipSetCustomLineCapStrokeCaps(GpCustomLineCap*,GpLineCap,GpLineCap);
GpStatus WINGDIPAPI GdipGetCustomLineCapStrokeCaps(GpCustomLineCap*,GpLineCap*,GpLineCap*);
GpStatus WINGDIPAPI GdipSetCustomLineCapStrokeJoin(GpCustomLineCap*,GpLineJoin);
GpStatus WINGDIPAPI GdipGetCustomLineCapStrokeJoin(GpCustomLineCap*,GpLineJoin*);
GpStatus WINGDIPAPI GdipSetCustomLineCapBaseCap(GpCustomLineCap*,GpLineCap);
GpStatus WINGDIPAPI GdipGetCustomLineCapBaseCap(GpCustomLineCap*,GpLineCap*);
GpStatus WINGDIPAPI GdipSetCustomLineCapBaseInset(GpCustomLineCap*,REAL);
GpStatus WINGDIPAPI GdipGetCustomLineCapBaseInset(GpCustomLineCap*,REAL*);
GpStatus WINGDIPAPI GdipSetCustomLineCapWidthScale(GpCustomLineCap*,REAL);
GpStatus WINGDIPAPI GdipGetCustomLineCapWidthScale(GpCustomLineCap*,REAL*);

/* Effect functions */
GpStatus WINGDIPAPI GdipCreateEffect(GDIPCONST GUID,CGpEffect**);
GpStatus WINGDIPAPI GdipDeleteEffect(CGpEffect*);
GpStatus WINGDIPAPI GdipGetEffectParameterSize(CGpEffect*,UINT*);
GpStatus WINGDIPAPI GdipSetEffectParameters(CGpEffect*,GDIPCONST VOID*,UINT);
GpStatus WINGDIPAPI GdipGetEffectParameters(CGpEffect*,UINT*,VOID*);

/* Font functions */
GpStatus WINGDIPAPI GdipCreateFontFromDC(HDC,GpFont**);
GpStatus WINGDIPAPI GdipCreateFontFromLogfontA(HDC,GDIPCONST LOGFONTA*,GpFont**);
GpStatus WINGDIPAPI GdipCreateFontFromLogfontW(HDC,GDIPCONST LOGFONTW*,GpFont**);
GpStatus WINGDIPAPI GdipCreateFont(GDIPCONST GpFontFamily*,REAL,INT,Unit,GpFont**);
GpStatus WINGDIPAPI GdipCloneFont(GpFont*,GpFont**);
GpStatus WINGDIPAPI GdipDeleteFont(GpFont*);
GpStatus WINGDIPAPI GdipGetFamily(GpFont*,GpFontFamily**);
GpStatus WINGDIPAPI GdipGetFontStyle(GpFont*,INT*);
GpStatus WINGDIPAPI GdipGetFontSize(GpFont*,REAL*);
GpStatus WINGDIPAPI GdipGetFontUnit(GpFont*,Unit*);
GpStatus WINGDIPAPI GdipGetFontHeight(GDIPCONST GpFont*,GDIPCONST GpGraphics*,REAL*);
GpStatus WINGDIPAPI GdipGetFontHeightGivenDPI(GDIPCONST GpFont*,REAL,REAL*);
GpStatus WINGDIPAPI GdipGetLogFontA(GpFont*,GpGraphics*,LOGFONTA*);
GpStatus WINGDIPAPI GdipGetLogFontW(GpFont*,GpGraphics*,LOGFONTW*);
GpStatus WINGDIPAPI GdipNewInstalledFontCollection(GpFontCollection**);
GpStatus WINGDIPAPI GdipNewPrivateFontCollection(GpFontCollection**);
GpStatus WINGDIPAPI GdipDeletePrivateFontCollection(GpFontCollection**);
GpStatus WINGDIPAPI GdipGetFontCollectionFamilyCount(GpFontCollection*,INT*);
GpStatus WINGDIPAPI GdipGetFontCollectionFamilyList(GpFontCollection*,INT,GpFontFamily**,INT*);
GpStatus WINGDIPAPI GdipPrivateAddFontFile(GpFontCollection*,GDIPCONST WCHAR*);
GpStatus WINGDIPAPI GdipPrivateAddMemoryFont(GpFontCollection*,GDIPCONST void*,INT);

/* FontFamily functions */
GpStatus WINGDIPAPI GdipCreateFontFamilyFromName(GDIPCONST WCHAR*,GpFontCollection*,GpFontFamily**);
GpStatus WINGDIPAPI GdipDeleteFontFamily(GpFontFamily*);
GpStatus WINGDIPAPI GdipCloneFontFamily(GpFontFamily*,GpFontFamily**);
GpStatus WINGDIPAPI GdipGetGenericFontFamilySansSerif(GpFontFamily**);
GpStatus WINGDIPAPI GdipGetGenericFontFamilySerif(GpFontFamily**);
GpStatus WINGDIPAPI GdipGetGenericFontFamilyMonospace(GpFontFamily**);
GpStatus WINGDIPAPI GdipGetFamilyName(GDIPCONST GpFontFamily*,WCHAR[LF_FACESIZE],LANGID);
GpStatus WINGDIPAPI GdipIsStyleAvailable(GDIPCONST GpFontFamily*,INT,BOOL*);
GpStatus WINGDIPAPI GdipFontCollectionEnumerable(GpFontCollection*,GpGraphics*,INT*);
GpStatus WINGDIPAPI GdipFontCollectionEnumerate(GpFontCollection*,INT,GpFontFamily**,INT*,GpGraphics*);
GpStatus WINGDIPAPI GdipGetEmHeight(GDIPCONST GpFontFamily*,INT,UINT16*);
GpStatus WINGDIPAPI GdipGetCellAscent(GDIPCONST GpFontFamily*,INT,UINT16*);
GpStatus WINGDIPAPI GdipGetCellDescent(GDIPCONST GpFontFamily*,INT,UINT16*);
GpStatus WINGDIPAPI GdipGetLineSpacing(GDIPCONST GpFontFamily*,INT,UINT16*);

/* Graphics functions */
GpStatus WINGDIPAPI GdipFlush(GpGraphics*,GpFlushIntention);
GpStatus WINGDIPAPI GdipCreateFromHDC(HDC,GpGraphics**);
GpStatus WINGDIPAPI GdipCreateFromHDC2(HDC,HANDLE,GpGraphics**);
GpStatus WINGDIPAPI GdipCreateFromHWND(HWND,GpGraphics**);
GpStatus WINGDIPAPI GdipCreateFromHWNDICM(HWND,GpGraphics**);
GpStatus WINGDIPAPI GdipDeleteGraphics(GpGraphics*);
GpStatus WINGDIPAPI GdipGetDC(GpGraphics*,HDC*);
GpStatus WINGDIPAPI GdipReleaseDC(GpGraphics*,HDC);
GpStatus WINGDIPAPI GdipSetCompositingMode(GpGraphics*,CompositingMode);
GpStatus WINGDIPAPI GdipGetCompositingMode(GpGraphics*,CompositingMode*);
GpStatus WINGDIPAPI GdipSetRenderingOrigin(GpGraphics*,INT,INT);
GpStatus WINGDIPAPI GdipGetRenderingOrigin(GpGraphics*,INT*,INT*);
GpStatus WINGDIPAPI GdipSetCompositingQuality(GpGraphics*,CompositingQuality);
GpStatus WINGDIPAPI GdipGetCompositingQuality(GpGraphics*,CompositingQuality*);
GpStatus WINGDIPAPI GdipSetSmoothingMode(GpGraphics*,SmoothingMode);
GpStatus WINGDIPAPI GdipGetSmoothingMode(GpGraphics*,SmoothingMode*);
GpStatus WINGDIPAPI GdipSetPixelOffsetMode(GpGraphics*,PixelOffsetMode);
GpStatus WINGDIPAPI GdipGetPixelOffsetMode(GpGraphics*,PixelOffsetMode*);
GpStatus WINGDIPAPI GdipSetTextRenderingHint(GpGraphics*,TextRenderingHint);
GpStatus WINGDIPAPI GdipGetTextRenderingHint(GpGraphics*,TextRenderingHint*);
GpStatus WINGDIPAPI GdipSetTextContrast(GpGraphics*,UINT);
GpStatus WINGDIPAPI GdipGetTextContrast(GpGraphics*,UINT*);
GpStatus WINGDIPAPI GdipSetInterpolationMode(GpGraphics*,InterpolationMode);
GpStatus WINGDIPAPI GdipGraphicsSetAbort(GpGraphics*,GdiplusAbort*);
GpStatus WINGDIPAPI GdipGetInterpolationMode(GpGraphics*,InterpolationMode*);
GpStatus WINGDIPAPI GdipSetWorldTransform(GpGraphics*,GpMatrix*);
GpStatus WINGDIPAPI GdipResetWorldTransform(GpGraphics*);
GpStatus WINGDIPAPI GdipMultiplyWorldTransform(GpGraphics*,GDIPCONST GpMatrix*,GpMatrixOrder);
GpStatus WINGDIPAPI GdipTranslateWorldTransform(GpGraphics*,REAL,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipScaleWorldTransform(GpGraphics*,REAL,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipRotateWorldTransform(GpGraphics*,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipGetWorldTransform(GpGraphics*,GpMatrix*);
GpStatus WINGDIPAPI GdipResetPageTransform(GpGraphics*);
GpStatus WINGDIPAPI GdipGetPageUnit(GpGraphics*,GpUnit*);
GpStatus WINGDIPAPI GdipGetPageScale(GpGraphics*,REAL*);
GpStatus WINGDIPAPI GdipSetPageUnit(GpGraphics*,GpUnit);
GpStatus WINGDIPAPI GdipSetPageScale(GpGraphics*,REAL);
GpStatus WINGDIPAPI GdipGetDpiX(GpGraphics*,REAL*);
GpStatus WINGDIPAPI GdipGetDpiY(GpGraphics*,REAL*);
GpStatus WINGDIPAPI GdipTransformPoints(GpGraphics*,GpCoordinateSpace,GpCoordinateSpace,GpPointF*,INT);
GpStatus WINGDIPAPI GdipTransformPointsI(GpGraphics*,GpCoordinateSpace,GpCoordinateSpace,GpPoint*,INT);
GpStatus WINGDIPAPI GdipGetNearestColor(GpGraphics*,ARGB*);
HPALETTE WINGDIPAPI GdipCreateHalftonePalette(void);
GpStatus WINGDIPAPI GdipDrawLine(GpGraphics*,GpPen*,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipDrawLineI(GpGraphics*,GpPen*,INT,INT,INT,INT);
GpStatus WINGDIPAPI GdipDrawLines(GpGraphics*,GpPen*,GDIPCONST GpPointF*,INT);
GpStatus WINGDIPAPI GdipDrawLinesI(GpGraphics*,GpPen*,GDIPCONST GpPoint*,INT);
GpStatus WINGDIPAPI GdipDrawArc(GpGraphics*,GpPen*,REAL,REAL,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipDrawArcI(GpGraphics*,GpPen*,INT,INT,INT,INT,REAL,REAL);
GpStatus WINGDIPAPI GdipDrawBezier(GpGraphics*,GpPen*,REAL,REAL,REAL,REAL,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipDrawBezierI(GpGraphics*,GpPen*,INT,INT,INT,INT,INT,INT,INT,INT);
GpStatus WINGDIPAPI GdipDrawBeziers(GpGraphics*,GpPen*,GDIPCONST GpPointF*,INT);
GpStatus WINGDIPAPI GdipDrawBeziersI(GpGraphics*,GpPen*,GDIPCONST GpPoint*,INT);
GpStatus WINGDIPAPI GdipDrawRectangle(GpGraphics*,GpPen*,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipDrawRectangleI(GpGraphics*,GpPen*,INT,INT,INT,INT);
GpStatus WINGDIPAPI GdipDrawRectangles(GpGraphics*,GpPen*,GDIPCONST GpRectF*,INT);
GpStatus WINGDIPAPI GdipDrawRectanglesI(GpGraphics*,GpPen*,GDIPCONST GpRect*,INT);
GpStatus WINGDIPAPI GdipDrawEllipse(GpGraphics*,GpPen*,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipDrawEllipseI(GpGraphics*,GpPen*,INT,INT,INT,INT);
GpStatus WINGDIPAPI GdipDrawPie(GpGraphics*,GpPen*,REAL,REAL,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipDrawPieI(GpGraphics*,GpPen*,INT,INT,INT,INT,REAL,REAL);
GpStatus WINGDIPAPI GdipDrawPolygon(GpGraphics*,GpPen*,GDIPCONST GpPointF*,INT);
GpStatus WINGDIPAPI GdipDrawPolygonI(GpGraphics*,GpPen*,GDIPCONST GpPoint*,INT);
GpStatus WINGDIPAPI GdipDrawPath(GpGraphics*,GpPen*,GpPath*);
GpStatus WINGDIPAPI GdipDrawCurve(GpGraphics*,GpPen*,GDIPCONST GpPointF*,INT);
GpStatus WINGDIPAPI GdipDrawCurveI(GpGraphics*,GpPen*,GDIPCONST GpPoint*,INT);
GpStatus WINGDIPAPI GdipDrawCurve2(GpGraphics*,GpPen*,GDIPCONST GpPointF*,INT,REAL);
GpStatus WINGDIPAPI GdipDrawCurve2I(GpGraphics*,GpPen*,GDIPCONST GpPoint*,INT,REAL);
GpStatus WINGDIPAPI GdipDrawCurve3(GpGraphics*,GpPen*,GDIPCONST GpPointF*,INT,INT,INT,REAL);
GpStatus WINGDIPAPI GdipDrawCurve3I(GpGraphics*,GpPen*,GDIPCONST GpPoint*,INT,INT,INT,REAL);
GpStatus WINGDIPAPI GdipDrawClosedCurve(GpGraphics*,GpPen*,GDIPCONST GpPointF*,INT);
GpStatus WINGDIPAPI GdipDrawClosedCurveI(GpGraphics*,GpPen*,GDIPCONST GpPoint*,INT);
GpStatus WINGDIPAPI GdipDrawClosedCurve2(GpGraphics*,GpPen*,GDIPCONST GpPointF*,INT,REAL);
GpStatus WINGDIPAPI GdipDrawClosedCurve2I(GpGraphics*,GpPen*,GDIPCONST GpPoint*,INT,REAL);
GpStatus WINGDIPAPI GdipGraphicsClear(GpGraphics*,ARGB);
GpStatus WINGDIPAPI GdipFillRectangle(GpGraphics*,GpBrush*,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipFillRectangleI(GpGraphics*,GpBrush*,INT,INT,INT,INT);
GpStatus WINGDIPAPI GdipFillRectangles(GpGraphics*,GpBrush*,GDIPCONST GpRectF*,INT);
GpStatus WINGDIPAPI GdipFillRectanglesI(GpGraphics*,GpBrush*,GDIPCONST GpRect*,INT);
GpStatus WINGDIPAPI GdipFillPolygon(GpGraphics*,GpBrush*,GDIPCONST GpPointF*,INT,GpFillMode);
GpStatus WINGDIPAPI GdipFillPolygonI(GpGraphics*,GpBrush*,GDIPCONST GpPoint*,INT,GpFillMode);
GpStatus WINGDIPAPI GdipFillPolygon2(GpGraphics*,GpBrush*,GDIPCONST GpPointF*,INT);
GpStatus WINGDIPAPI GdipFillPolygon2I(GpGraphics*,GpBrush*,GDIPCONST GpPoint*,INT);
GpStatus WINGDIPAPI GdipFillEllipse(GpGraphics*,GpBrush*,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipFillEllipseI(GpGraphics*,GpBrush*,INT,INT,INT,INT);
GpStatus WINGDIPAPI GdipFillPie(GpGraphics*,GpBrush*,REAL,REAL,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipFillPieI(GpGraphics*,GpBrush*,INT,INT,INT,INT,REAL,REAL);
GpStatus WINGDIPAPI GdipFillPath(GpGraphics*,GpBrush*,GpPath*);
GpStatus WINGDIPAPI GdipFillClosedCurve(GpGraphics*,GpBrush*,GDIPCONST GpPointF*,INT);
GpStatus WINGDIPAPI GdipFillClosedCurveI(GpGraphics*,GpBrush*,GDIPCONST GpPoint*,INT);
GpStatus WINGDIPAPI GdipFillClosedCurve2(GpGraphics*,GpBrush*,GDIPCONST GpPointF*,INT,REAL,GpFillMode);
GpStatus WINGDIPAPI GdipFillClosedCurve2I(GpGraphics*,GpBrush*,GDIPCONST GpPoint*,INT,REAL,GpFillMode);
GpStatus WINGDIPAPI GdipFillRegion(GpGraphics*,GpBrush*,GpRegion*);
GpStatus WINGDIPAPI GdipDrawImage(GpGraphics*,GpImage*,REAL,REAL);
GpStatus WINGDIPAPI GdipDrawImageI(GpGraphics*,GpImage*,INT,INT);
GpStatus WINGDIPAPI GdipDrawImageRect(GpGraphics*,GpImage*,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipDrawImageRectI(GpGraphics*,GpImage*,INT,INT,INT,INT);
GpStatus WINGDIPAPI GdipDrawImagePoints(GpGraphics*,GpImage*,GDIPCONST GpPointF*,INT);
GpStatus WINGDIPAPI GdipDrawImagePointsI(GpGraphics*,GpImage*,GDIPCONST GpPoint*,INT);
GpStatus WINGDIPAPI GdipDrawImagePointRect(GpGraphics*,GpImage*,REAL,REAL,REAL,REAL,REAL,REAL,GpUnit);
GpStatus WINGDIPAPI GdipDrawImagePointRectI(GpGraphics*,GpImage*,INT,INT,INT,INT,INT,INT,GpUnit);
GpStatus WINGDIPAPI GdipDrawImageRectRect(GpGraphics*,GpImage*,REAL,REAL,REAL,REAL,REAL,REAL,REAL,REAL,GpUnit,GDIPCONST GpImageAttributes*,DrawImageAbort,VOID*);
GpStatus WINGDIPAPI GdipDrawImageRectRectI(GpGraphics*,GpImage*,INT,INT,INT,INT,INT,INT,INT,INT,GpUnit,GDIPCONST GpImageAttributes*,DrawImageAbort,VOID*);
GpStatus WINGDIPAPI GdipDrawImagePointsRect(GpGraphics*,GpImage*,GDIPCONST GpPointF*,INT,REAL,REAL,REAL,REAL,GpUnit,GDIPCONST GpImageAttributes*,DrawImageAbort,VOID*);
GpStatus WINGDIPAPI GdipDrawImagePointsRectI(GpGraphics*,GpImage*,GDIPCONST GpPoint*,INT,INT,INT,INT,INT,GpUnit,GDIPCONST GpImageAttributes*,DrawImageAbort,VOID*);
GpStatus WINGDIPAPI GdipDrawImageFX(GpGraphics*,GpImage*,GpRectF*,GpMatrix*,CGpEffect*,GpImageAttributes*,GpUnit);
#ifdef __cplusplus
GpStatus WINGDIPAPI GdipEnumerateMetafileDestPoint(GpGraphics*,GDIPCONST GpMetafile*,GDIPCONST PointF&,EnumerateMetafileProc,VOID*,GDIPCONST GpImageAttributes*);
GpStatus WINGDIPAPI GdipEnumerateMetafileDestPointI(GpGraphics*,GDIPCONST GpMetafile*,GDIPCONST Point&,EnumerateMetafileProc,VOID*,GDIPCONST GpImageAttributes*);
GpStatus WINGDIPAPI GdipEnumerateMetafileDestRect(GpGraphics*,GDIPCONST GpMetafile*,GDIPCONST RectF&,EnumerateMetafileProc,VOID*,GDIPCONST GpImageAttributes*);
GpStatus WINGDIPAPI GdipEnumerateMetafileDestRectI(GpGraphics*,GDIPCONST GpMetafile*,GDIPCONST Rect&,EnumerateMetafileProc,VOID*,GDIPCONST GpImageAttributes*);
#endif
GpStatus WINGDIPAPI GdipEnumerateMetafileDestPoints(GpGraphics*,GDIPCONST GpMetafile*,GDIPCONST PointF*,INT,EnumerateMetafileProc,VOID*,GDIPCONST GpImageAttributes*);
GpStatus WINGDIPAPI GdipEnumerateMetafileDestPointsI(GpGraphics*,GDIPCONST GpMetafile*,GDIPCONST Point*,INT,EnumerateMetafileProc,VOID*,GDIPCONST GpImageAttributes*);
#ifdef __cplusplus
GpStatus WINGDIPAPI GdipEnumerateMetafileSrcRectDestPoint(GpGraphics*,GDIPCONST GpMetafile*,GDIPCONST PointF&,GDIPCONST RectF&,Unit,EnumerateMetafileProc,VOID*,GDIPCONST GpImageAttributes*);
GpStatus WINGDIPAPI GdipEnumerateMetafileSrcRectDestPointI(GpGraphics*,GDIPCONST GpMetafile*,GDIPCONST Point&,GDIPCONST Rect&,Unit,EnumerateMetafileProc,VOID*,GDIPCONST GpImageAttributes*);
GpStatus WINGDIPAPI GdipEnumerateMetafileSrcRectDestRect(GpGraphics*,GDIPCONST GpMetafile*,GDIPCONST RectF&,GDIPCONST RectF&,Unit,EnumerateMetafileProc,VOID*,GDIPCONST GpImageAttributes*);
GpStatus WINGDIPAPI GdipEnumerateMetafileSrcRectDestRectI(GpGraphics*,GDIPCONST GpMetafile*,GDIPCONST Rect&,GDIPCONST Rect&,Unit,EnumerateMetafileProc,VOID*,GDIPCONST GpImageAttributes*);
GpStatus WINGDIPAPI GdipEnumerateMetafileSrcRectDestPoints(GpGraphics*,GDIPCONST GpMetafile*,GDIPCONST PointF*,INT,GDIPCONST RectF&,Unit,EnumerateMetafileProc,VOID*,GDIPCONST GpImageAttributes*);
GpStatus WINGDIPAPI GdipEnumerateMetafileSrcRectDestPointsI(GpGraphics*,GDIPCONST GpMetafile*,GDIPCONST Point*,INT,GDIPCONST Rect&,Unit,EnumerateMetafileProc,VOID*,GDIPCONST GpImageAttributes*);
#endif
GpStatus WINGDIPAPI GdipSetClipGraphics(GpGraphics*,GpGraphics*,CombineMode);
GpStatus WINGDIPAPI GdipSetClipRect(GpGraphics*,REAL,REAL,REAL,REAL,CombineMode);
GpStatus WINGDIPAPI GdipSetClipRectI(GpGraphics*,INT,INT,INT,INT,CombineMode);
GpStatus WINGDIPAPI GdipSetClipPath(GpGraphics*,GpPath*,CombineMode);
GpStatus WINGDIPAPI GdipSetClipRegion(GpGraphics*,GpRegion*,CombineMode);
GpStatus WINGDIPAPI GdipSetClipHrgn(GpGraphics*,HRGN,CombineMode);
GpStatus WINGDIPAPI GdipResetClip(GpGraphics*);
GpStatus WINGDIPAPI GdipTranslateClip(GpGraphics*,REAL,REAL);
GpStatus WINGDIPAPI GdipTranslateClipI(GpGraphics*,INT,INT);
GpStatus WINGDIPAPI GdipGetClip(GpGraphics*,GpRegion*);
GpStatus WINGDIPAPI GdipGetClipBounds(GpGraphics*,GpRectF*);
GpStatus WINGDIPAPI GdipGetClipBoundsI(GpGraphics*,GpRect*);
GpStatus WINGDIPAPI GdipIsClipEmpty(GpGraphics*,BOOL*);
GpStatus WINGDIPAPI GdipGetVisibleClipBounds(GpGraphics*,GpRectF*);
GpStatus WINGDIPAPI GdipGetVisibleClipBoundsI(GpGraphics*,GpRect*);
GpStatus WINGDIPAPI GdipIsVisibleClipEmpty(GpGraphics*,BOOL*);
GpStatus WINGDIPAPI GdipIsVisiblePoint(GpGraphics*,REAL,REAL,BOOL*);
GpStatus WINGDIPAPI GdipIsVisiblePointI(GpGraphics*,INT,INT,BOOL*);
GpStatus WINGDIPAPI GdipIsVisibleRect(GpGraphics*,REAL,REAL,REAL,REAL,BOOL*);
GpStatus WINGDIPAPI GdipIsVisibleRectI(GpGraphics*,INT,INT,INT,INT,BOOL*);
GpStatus WINGDIPAPI GdipSaveGraphics(GpGraphics*,GraphicsState*);
GpStatus WINGDIPAPI GdipRestoreGraphics(GpGraphics*,GraphicsState);
GpStatus WINGDIPAPI GdipBeginContainer(GpGraphics*,GDIPCONST GpRectF*,GDIPCONST GpRectF*,GpUnit,GraphicsContainer*);
GpStatus WINGDIPAPI GdipBeginContainerI(GpGraphics*,GDIPCONST GpRect*,GDIPCONST GpRect*,GpUnit,GraphicsContainer*);
GpStatus WINGDIPAPI GdipBeginContainer2(GpGraphics*,GraphicsContainer*);
GpStatus WINGDIPAPI GdipEndContainer(GpGraphics*,GraphicsContainer);
GpStatus WINGDIPAPI GdipComment(GpGraphics*,UINT,GDIPCONST BYTE*);

/* GraphicsPath functions */
GpStatus WINGDIPAPI GdipCreatePath(GpFillMode,GpPath**);
GpStatus WINGDIPAPI GdipCreatePath2(GDIPCONST GpPointF*,GDIPCONST BYTE*,INT,GpFillMode,GpPath**);
GpStatus WINGDIPAPI GdipCreatePath2I(GDIPCONST GpPoint*,GDIPCONST BYTE*,INT,GpFillMode,GpPath**);
GpStatus WINGDIPAPI GdipClonePath(GpPath*,GpPath**);
GpStatus WINGDIPAPI GdipDeletePath(GpPath*);
GpStatus WINGDIPAPI GdipResetPath(GpPath*);
GpStatus WINGDIPAPI GdipGetPointCount(GpPath*,INT*);
GpStatus WINGDIPAPI GdipGetPathTypes(GpPath*,BYTE*,INT);
GpStatus WINGDIPAPI GdipGetPathPoints(GpPath*,GpPointF*,INT);
GpStatus WINGDIPAPI GdipGetPathPointsI(GpPath*,GpPoint*,INT);
GpStatus WINGDIPAPI GdipGetPathFillMode(GpPath*,GpFillMode*);
GpStatus WINGDIPAPI GdipSetPathFillMode(GpPath*,GpFillMode);
GpStatus WINGDIPAPI GdipGetPathData(GpPath*,GpPathData*);
GpStatus WINGDIPAPI GdipStartPathFigure(GpPath*);
GpStatus WINGDIPAPI GdipClosePathFigure(GpPath*);
GpStatus WINGDIPAPI GdipClosePathFigures(GpPath*);
GpStatus WINGDIPAPI GdipSetPathMarker(GpPath*);
GpStatus WINGDIPAPI GdipClearPathMarkers(GpPath*);
GpStatus WINGDIPAPI GdipReversePath(GpPath*);
GpStatus WINGDIPAPI GdipGetPathLastPoint(GpPath*,GpPointF*);
GpStatus WINGDIPAPI GdipAddPathLine(GpPath*,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipAddPathLine2(GpPath*,GDIPCONST GpPointF*,INT);
GpStatus WINGDIPAPI GdipAddPathArc(GpPath*,REAL,REAL,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipAddPathBezier(GpPath*,REAL,REAL,REAL,REAL,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipAddPathBeziers(GpPath*,GDIPCONST GpPointF*,INT);
GpStatus WINGDIPAPI GdipAddPathCurve(GpPath*,GDIPCONST GpPointF*,INT);
GpStatus WINGDIPAPI GdipAddPathCurve2(GpPath*,GDIPCONST GpPointF*,INT,REAL);
GpStatus WINGDIPAPI GdipAddPathCurve3(GpPath*,GDIPCONST GpPointF*,INT,INT,INT,REAL);
GpStatus WINGDIPAPI GdipAddPathClosedCurve(GpPath*,GDIPCONST GpPointF*,INT);
GpStatus WINGDIPAPI GdipAddPathClosedCurve2(GpPath*,GDIPCONST GpPointF*,INT,REAL);
GpStatus WINGDIPAPI GdipAddPathRectangle(GpPath*,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipAddPathRectangles(GpPath*,GDIPCONST GpRectF*,INT);
GpStatus WINGDIPAPI GdipAddPathEllipse(GpPath*,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipAddPathPie(GpPath*,REAL,REAL,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipAddPathPolygon(GpPath*,GDIPCONST GpPointF*,INT);
GpStatus WINGDIPAPI GdipAddPathPath(GpPath*,GDIPCONST GpPath*,BOOL);
GpStatus WINGDIPAPI GdipAddPathString(GpPath*,GDIPCONST WCHAR*,INT,GDIPCONST GpFontFamily*,INT,REAL,GDIPCONST RectF*,GDIPCONST GpStringFormat*);
GpStatus WINGDIPAPI GdipAddPathStringI(GpPath*,GDIPCONST WCHAR*,INT,GDIPCONST GpFontFamily*,INT,REAL,GDIPCONST Rect*,GDIPCONST GpStringFormat*);
GpStatus WINGDIPAPI GdipAddPathLineI(GpPath*,INT,INT,INT,INT);
GpStatus WINGDIPAPI GdipAddPathLine2I(GpPath*,GDIPCONST GpPoint*,INT);
GpStatus WINGDIPAPI GdipAddPathArcI(GpPath*,INT,INT,INT,INT,REAL,REAL);
GpStatus WINGDIPAPI GdipAddPathBezierI(GpPath*,INT,INT,INT,INT,INT,INT,INT,INT);
GpStatus WINGDIPAPI GdipAddPathBeziersI(GpPath*,GDIPCONST GpPoint*,INT);
GpStatus WINGDIPAPI GdipAddPathCurveI(GpPath*,GDIPCONST GpPoint*,INT);
GpStatus WINGDIPAPI GdipAddPathCurve2I(GpPath*,GDIPCONST GpPoint*,INT,REAL);
GpStatus WINGDIPAPI GdipAddPathCurve3I(GpPath*,GDIPCONST GpPoint*,INT,INT,INT,REAL);
GpStatus WINGDIPAPI GdipAddPathClosedCurveI(GpPath*,GDIPCONST GpPoint*,INT);
GpStatus WINGDIPAPI GdipAddPathClosedCurve2I(GpPath*,GDIPCONST GpPoint*,INT,REAL);
GpStatus WINGDIPAPI GdipAddPathRectangleI(GpPath*,INT,INT,INT,INT);
GpStatus WINGDIPAPI GdipAddPathRectanglesI(GpPath*,GDIPCONST GpRect*,INT);
GpStatus WINGDIPAPI GdipAddPathEllipseI(GpPath*,INT,INT,INT,INT);
GpStatus WINGDIPAPI GdipAddPathPieI(GpPath*,INT,INT,INT,INT,REAL,REAL);
GpStatus WINGDIPAPI GdipAddPathPolygonI(GpPath*,GDIPCONST GpPoint*,INT);
GpStatus WINGDIPAPI GdipFlattenPath(GpPath*,GpMatrix*,REAL);
GpStatus WINGDIPAPI GdipWindingModeOutline(GpPath*,GpMatrix*,REAL);
GpStatus WINGDIPAPI GdipWidenPath(GpPath*,GpPen*,GpMatrix*,REAL);
GpStatus WINGDIPAPI GdipWarpPath(GpPath*,GpMatrix*,GDIPCONST GpPointF*,INT,REAL,REAL,REAL,REAL,WarpMode,REAL);
GpStatus WINGDIPAPI GdipTransformPath(GpPath*,GpMatrix*);
GpStatus WINGDIPAPI GdipGetPathWorldBounds(GpPath*,GpRectF*,GDIPCONST GpMatrix*,GDIPCONST GpPen*);
GpStatus WINGDIPAPI GdipGetPathWorldBoundsI(GpPath*,GpRect*,GDIPCONST GpMatrix*,GDIPCONST GpPen*);
GpStatus WINGDIPAPI GdipIsVisiblePathPoint(GpPath*,REAL,REAL,GpGraphics*,BOOL*);
GpStatus WINGDIPAPI GdipIsVisiblePathPointI(GpPath*,INT,INT,GpGraphics*,BOOL*);
GpStatus WINGDIPAPI GdipIsOutlineVisiblePathPoint(GpPath*,REAL,REAL,GpPen*,GpGraphics*,BOOL*);
GpStatus WINGDIPAPI GdipIsOutlineVisiblePathPointI(GpPath*,INT,INT,GpPen*,GpGraphics*,BOOL*);

/* HatchBrush functions */
GpStatus WINGDIPAPI GdipCreateHatchBrush(GpHatchStyle,ARGB,ARGB,GpHatch**);
GpStatus WINGDIPAPI GdipGetHatchStyle(GpHatch*,GpHatchStyle*);
GpStatus WINGDIPAPI GdipGetHatchForegroundColor(GpHatch*,ARGB*);
GpStatus WINGDIPAPI GdipGetHatchBackgroundColor(GpHatch*,ARGB*);

/* Image functions */
GpStatus WINGDIPAPI GdipLoadImageFromStream(IStream*,GpImage**);
GpStatus WINGDIPAPI GdipLoadImageFromFile(GDIPCONST WCHAR*,GpImage**);
GpStatus WINGDIPAPI GdipLoadImageFromStreamICM(IStream*,GpImage**);
GpStatus WINGDIPAPI GdipLoadImageFromFileICM(GDIPCONST WCHAR*,GpImage**);
GpStatus WINGDIPAPI GdipCloneImage(GpImage*,GpImage**);
GpStatus WINGDIPAPI GdipDisposeImage(GpImage*);
GpStatus WINGDIPAPI GdipSaveImageToFile(GpImage*,GDIPCONST WCHAR*,GDIPCONST CLSID*,GDIPCONST EncoderParameters*);
GpStatus WINGDIPAPI GdipSaveImageToStream(GpImage*,IStream*,GDIPCONST CLSID*,GDIPCONST EncoderParameters*);
GpStatus WINGDIPAPI GdipSaveAdd(GpImage*,GDIPCONST EncoderParameters*);
GpStatus WINGDIPAPI GdipSaveAddImage(GpImage*,GpImage*,GDIPCONST EncoderParameters*);
GpStatus WINGDIPAPI GdipGetImageGraphicsContext(GpImage*,GpGraphics**);
GpStatus WINGDIPAPI GdipGetImageBounds(GpImage*,GpRectF*,GpUnit*);
GpStatus WINGDIPAPI GdipGetImageDimension(GpImage*,REAL*,REAL*);
GpStatus WINGDIPAPI GdipGetImageType(GpImage*,ImageType*);
GpStatus WINGDIPAPI GdipGetImageWidth(GpImage*,UINT*);
GpStatus WINGDIPAPI GdipGetImageHeight(GpImage*,UINT*);
GpStatus WINGDIPAPI GdipGetImageHorizontalResolution(GpImage*,REAL*);
GpStatus WINGDIPAPI GdipGetImageVerticalResolution(GpImage*,REAL*);
GpStatus WINGDIPAPI GdipGetImageFlags(GpImage*,UINT*);
GpStatus WINGDIPAPI GdipGetImageRawFormat(GpImage*,GUID*);
GpStatus WINGDIPAPI GdipGetImagePixelFormat(GpImage*,PixelFormat*);
GpStatus WINGDIPAPI GdipGetImageThumbnail(GpImage*,UINT,UINT,GpImage**,GetThumbnailImageAbort,VOID*);
GpStatus WINGDIPAPI GdipGetEncoderParameterListSize(GpImage*,GDIPCONST CLSID*,UINT*);
GpStatus WINGDIPAPI GdipGetEncoderParameterList(GpImage*,GDIPCONST CLSID*,UINT,EncoderParameters*);
GpStatus WINGDIPAPI GdipImageGetFrameDimensionsCount(GpImage*,UINT*);
GpStatus WINGDIPAPI GdipImageGetFrameDimensionsList(GpImage*,GUID*,UINT);
GpStatus WINGDIPAPI GdipImageGetFrameCount(GpImage*,GDIPCONST GUID*,UINT*);
GpStatus WINGDIPAPI GdipImageSelectActiveFrame(GpImage*,GDIPCONST GUID*,UINT);
GpStatus WINGDIPAPI GdipImageRotateFlip(GpImage*,RotateFlipType);
GpStatus WINGDIPAPI GdipGetImagePalette(GpImage*,ColorPalette*,INT);
GpStatus WINGDIPAPI GdipSetImagePalette(GpImage*,GDIPCONST ColorPalette*);
GpStatus WINGDIPAPI GdipGetImagePaletteSize(GpImage*,INT*);
GpStatus WINGDIPAPI GdipGetPropertyCount(GpImage*,UINT*);
GpStatus WINGDIPAPI GdipGetPropertyIdList(GpImage*,UINT,PROPID*);
GpStatus WINGDIPAPI GdipGetPropertyItemSize(GpImage*,PROPID,UINT*);
GpStatus WINGDIPAPI GdipGetPropertyItem(GpImage*,PROPID,UINT,PropertyItem*);
GpStatus WINGDIPAPI GdipGetPropertySize(GpImage*,UINT*,UINT*);
GpStatus WINGDIPAPI GdipGetAllPropertyItems(GpImage*,UINT,UINT,PropertyItem*);
GpStatus WINGDIPAPI GdipRemovePropertyItem(GpImage*,PROPID);
GpStatus WINGDIPAPI GdipSetPropertyItem(GpImage*,GDIPCONST PropertyItem*);
GpStatus WINGDIPAPI GdipFindFirstImageItem(GpImage*,ImageItemData*);
GpStatus WINGDIPAPI GdipFindNextImageItem(GpImage*,ImageItemData*);
GpStatus WINGDIPAPI GdipGetImageItemData(GpImage*,ImageItemData*);
GpStatus WINGDIPAPI GdipImageSetAbort(GpImage*,GdiplusAbort*);
GpStatus WINGDIPAPI GdipImageForceValidation(GpImage*);

/* Image codec functions */
GpStatus WINGDIPAPI GdipGetImageDecodersSize(UINT*,UINT*);
GpStatus WINGDIPAPI GdipGetImageDecoders(UINT,UINT,ImageCodecInfo*);
GpStatus WINGDIPAPI GdipGetImageEncodersSize(UINT*,UINT*);
GpStatus WINGDIPAPI GdipGetImageEncoders(UINT,UINT,ImageCodecInfo*);

/* ImageAttributes functions */
GpStatus WINGDIPAPI GdipCreateImageAttributes(GpImageAttributes**);
GpStatus WINGDIPAPI GdipCloneImageAttributes(GDIPCONST GpImageAttributes*,GpImageAttributes**);
GpStatus WINGDIPAPI GdipDisposeImageAttributes(GpImageAttributes*);
GpStatus WINGDIPAPI GdipSetImageAttributesToIdentity(GpImageAttributes*,ColorAdjustType);
GpStatus WINGDIPAPI GdipResetImageAttributes(GpImageAttributes*,ColorAdjustType);
GpStatus WINGDIPAPI GdipSetImageAttributesColorMatrix(GpImageAttributes*,ColorAdjustType,BOOL,GDIPCONST ColorMatrix*,GDIPCONST ColorMatrix*,ColorMatrixFlags);
GpStatus WINGDIPAPI GdipSetImageAttributesThreshold(GpImageAttributes*,ColorAdjustType,BOOL,REAL);
GpStatus WINGDIPAPI GdipSetImageAttributesGamma(GpImageAttributes*,ColorAdjustType,BOOL,REAL);
GpStatus WINGDIPAPI GdipSetImageAttributesNoOp(GpImageAttributes*,ColorAdjustType,BOOL);
GpStatus WINGDIPAPI GdipSetImageAttributesColorKeys(GpImageAttributes*,ColorAdjustType,BOOL,ARGB,ARGB);
GpStatus WINGDIPAPI GdipSetImageAttributesOutputChannel(GpImageAttributes*,ColorAdjustType,BOOL,ColorChannelFlags);
GpStatus WINGDIPAPI GdipSetImageAttributesOutputChannelColorProfile(GpImageAttributes*,ColorAdjustType,BOOL,GDIPCONST WCHAR*);
GpStatus WINGDIPAPI GdipSetImageAttributesRemapTable(GpImageAttributes*,ColorAdjustType,BOOL,UINT,GDIPCONST ColorMap*);
GpStatus WINGDIPAPI GdipSetImageAttributesWrapMode(GpImageAttributes*,WrapMode,ARGB,BOOL);
GpStatus WINGDIPAPI GdipSetImageAttributesICMMode(GpImageAttributes*,BOOL);
GpStatus WINGDIPAPI GdipGetImageAttributesAdjustedPalette(GpImageAttributes*,ColorPalette*,ColorAdjustType);
GpStatus WINGDIPAPI GdipSetImageAttributesCachedBackground(GpImageAttributes*,BOOL);

/* LinearGradientBrush functions */
GpStatus WINGDIPAPI GdipCreateLineBrush(GDIPCONST GpPointF*,GDIPCONST GpPointF*,ARGB,ARGB,GpWrapMode,GpLineGradient**);
GpStatus WINGDIPAPI GdipCreateLineBrushI(GDIPCONST GpPoint*,GDIPCONST GpPoint*,ARGB,ARGB,GpWrapMode,GpLineGradient**);
GpStatus WINGDIPAPI GdipCreateLineBrushFromRect(GDIPCONST GpRectF*,ARGB,ARGB,LinearGradientMode,GpWrapMode,GpLineGradient**);
GpStatus WINGDIPAPI GdipCreateLineBrushFromRectI(GDIPCONST GpRect*,ARGB,ARGB,LinearGradientMode,GpWrapMode,GpLineGradient**);
GpStatus WINGDIPAPI GdipCreateLineBrushFromRectWithAngle(GDIPCONST GpRectF*,ARGB,ARGB,REAL,BOOL,GpWrapMode,GpLineGradient**);
GpStatus WINGDIPAPI GdipCreateLineBrushFromRectWithAngleI(GDIPCONST GpRect*,ARGB,ARGB,REAL,BOOL,GpWrapMode,GpLineGradient**);
GpStatus WINGDIPAPI GdipSetLineColors(GpLineGradient*,ARGB,ARGB);
GpStatus WINGDIPAPI GdipGetLineColors(GpLineGradient*,ARGB*);
GpStatus WINGDIPAPI GdipGetLineRect(GpLineGradient*,GpRectF*);
GpStatus WINGDIPAPI GdipGetLineRectI(GpLineGradient*,GpRect*);
GpStatus WINGDIPAPI GdipSetLineGammaCorrection(GpLineGradient*,BOOL);
GpStatus WINGDIPAPI GdipGetLineGammaCorrection(GpLineGradient*,BOOL*);
GpStatus WINGDIPAPI GdipGetLineBlendCount(GpLineGradient*,INT*);
GpStatus WINGDIPAPI GdipGetLineBlend(GpLineGradient*,REAL*,REAL*,INT);
GpStatus WINGDIPAPI GdipSetLineBlend(GpLineGradient*,GDIPCONST REAL*,GDIPCONST REAL*,INT);
GpStatus WINGDIPAPI GdipGetLinePresetBlendCount(GpLineGradient*,INT*);
GpStatus WINGDIPAPI GdipGetLinePresetBlend(GpLineGradient*,ARGB*,REAL*,INT);
GpStatus WINGDIPAPI GdipSetLinePresetBlend(GpLineGradient*,GDIPCONST ARGB*,GDIPCONST REAL*,INT);
GpStatus WINGDIPAPI GdipSetLineSigmaBlend(GpLineGradient*,REAL,REAL);
GpStatus WINGDIPAPI GdipSetLineLinearBlend(GpLineGradient*,REAL,REAL);
GpStatus WINGDIPAPI GdipSetLineWrapMode(GpLineGradient*,GpWrapMode);
GpStatus WINGDIPAPI GdipGetLineWrapMode(GpLineGradient*,GpWrapMode*);
GpStatus WINGDIPAPI GdipGetLineTransform(GpLineGradient*,GpMatrix*);
GpStatus WINGDIPAPI GdipSetLineTransform(GpLineGradient*,GDIPCONST GpMatrix*);
GpStatus WINGDIPAPI GdipResetLineTransform(GpLineGradient*);
GpStatus WINGDIPAPI GdipMultiplyLineTransform(GpLineGradient*,GDIPCONST GpMatrix*,GpMatrixOrder);
GpStatus WINGDIPAPI GdipTranslateLineTransform(GpLineGradient*,REAL,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipScaleLineTransform(GpLineGradient*,REAL,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipRotateLineTransform(GpLineGradient*,REAL,GpMatrixOrder);

/* Matrix functions */
GpStatus WINGDIPAPI GdipCreateMatrix(GpMatrix**);
GpStatus WINGDIPAPI GdipCreateMatrix2(REAL,REAL,REAL,REAL,REAL,REAL,GpMatrix**);
GpStatus WINGDIPAPI GdipCreateMatrix3(GDIPCONST GpRectF*,GDIPCONST GpPointF*,GpMatrix**);
GpStatus WINGDIPAPI GdipCreateMatrix3I(GDIPCONST GpRect*,GDIPCONST GpPoint*,GpMatrix**);
GpStatus WINGDIPAPI GdipCloneMatrix(GpMatrix*,GpMatrix**);
GpStatus WINGDIPAPI GdipDeleteMatrix(GpMatrix*);
GpStatus WINGDIPAPI GdipSetMatrixElements(GpMatrix*,REAL,REAL,REAL,REAL,REAL,REAL);
GpStatus WINGDIPAPI GdipMultiplyMatrix(GpMatrix*,GpMatrix*,GpMatrixOrder);
GpStatus WINGDIPAPI GdipTranslateMatrix(GpMatrix*,REAL,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipScaleMatrix(GpMatrix*,REAL,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipRotateMatrix(GpMatrix*,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipShearMatrix(GpMatrix*,REAL,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipInvertMatrix(GpMatrix*);
GpStatus WINGDIPAPI GdipTransformMatrixPoints(GpMatrix*,GpPointF*,INT);
GpStatus WINGDIPAPI GdipTransformMatrixPointsI(GpMatrix*,GpPoint*,INT);
GpStatus WINGDIPAPI GdipVectorTransformMatrixPoints(GpMatrix*,GpPointF*,INT);
GpStatus WINGDIPAPI GdipVectorTransformMatrixPointsI(GpMatrix*,GpPoint*,INT);
GpStatus WINGDIPAPI GdipGetMatrixElements(GDIPCONST GpMatrix*,REAL*);
GpStatus WINGDIPAPI GdipIsMatrixInvertible(GDIPCONST GpMatrix*,BOOL*);
GpStatus WINGDIPAPI GdipIsMatrixIdentity(GDIPCONST GpMatrix*,BOOL*);
GpStatus WINGDIPAPI GdipIsMatrixEqual(GDIPCONST GpMatrix*,GDIPCONST GpMatrix*,BOOL*);

/* Metafile functions */
GpStatus WINGDIPAPI GdipGetMetafileHeaderFromEmf(HENHMETAFILE,MetafileHeader*);
GpStatus WINGDIPAPI GdipGetMetafileHeaderFromFile(GDIPCONST WCHAR*,MetafileHeader*);
GpStatus WINGDIPAPI GdipGetMetafileHeaderFromStream(IStream*,MetafileHeader*);
GpStatus WINGDIPAPI GdipGetMetafileHeaderFromMetafile(GpMetafile*,MetafileHeader*);
GpStatus WINGDIPAPI GdipGetHemfFromMetafile(GpMetafile*,HENHMETAFILE*);
GpStatus WINGDIPAPI GdipCreateStreamOnFile(GDIPCONST WCHAR*,UINT,IStream**);
GpStatus WINGDIPAPI GdipCreateMetafileFromWmf(HMETAFILE,BOOL,GDIPCONST WmfPlaceableFileHeader*,GpMetafile**);
GpStatus WINGDIPAPI GdipCreateMetafileFromEmf(HENHMETAFILE,BOOL,GpMetafile**);
GpStatus WINGDIPAPI GdipCreateMetafileFromFile(GDIPCONST WCHAR*,GpMetafile**);
GpStatus WINGDIPAPI GdipCreateMetafileFromWmfFile(GDIPCONST WCHAR*,GDIPCONST WmfPlaceableFileHeader*,GpMetafile**);
GpStatus WINGDIPAPI GdipCreateMetafileFromStream(IStream*,GpMetafile**);
GpStatus WINGDIPAPI GdipRecordMetafile(HDC,EmfType,GDIPCONST GpRectF*,MetafileFrameUnit,GDIPCONST WCHAR*,GpMetafile**);
GpStatus WINGDIPAPI GdipRecordMetafileI(HDC,EmfType,GDIPCONST GpRect*,MetafileFrameUnit,GDIPCONST WCHAR*,GpMetafile**);
GpStatus WINGDIPAPI GdipRecordMetafileFileName(GDIPCONST WCHAR*,HDC,EmfType,GDIPCONST GpRectF*,MetafileFrameUnit,GDIPCONST WCHAR*,GpMetafile**);
GpStatus WINGDIPAPI GdipRecordMetafileFileNameI(GDIPCONST WCHAR*,HDC,EmfType,GDIPCONST GpRect*,MetafileFrameUnit,GDIPCONST WCHAR*,GpMetafile**);
GpStatus WINGDIPAPI GdipRecordMetafileStream(IStream*,HDC,EmfType,GDIPCONST GpRectF*,MetafileFrameUnit,GDIPCONST WCHAR*,GpMetafile**);
GpStatus WINGDIPAPI GdipRecordMetafileStreamI(IStream*,HDC,EmfType,GDIPCONST GpRect*,MetafileFrameUnit,GDIPCONST WCHAR*,GpMetafile**);
GpStatus WINGDIPAPI GdipPlayMetafileRecord(GDIPCONST GpMetafile*,EmfPlusRecordType,UINT,UINT,GDIPCONST BYTE*);
GpStatus WINGDIPAPI GdipSetMetafileDownLevelRasterizationLimit(GpMetafile*,UINT);
GpStatus WINGDIPAPI GdipGetMetafileDownLevelRasterizationLimit(GDIPCONST GpMetafile*,UINT*);
GpStatus WINGDIPAPI GdipConvertToEmfPlus(GDIPCONST GpGraphics*,GpMetafile*,BOOL*,EmfType,GDIPCONST WCHAR*,GpMetafile**);
GpStatus WINGDIPAPI GdipConvertToEmfPlusToFile(GDIPCONST GpGraphics*,GpMetafile*,BOOL*,GDIPCONST WCHAR*,EmfType,GDIPCONST WCHAR*,GpMetafile**);
GpStatus WINGDIPAPI GdipConvertToEmfPlusToStream(GDIPCONST GpGraphics*,GpMetafile*,BOOL*,IStream*,EmfType,GDIPCONST WCHAR*,GpMetafile**);
UINT WINGDIPAPI GdipEmfToWmfBits(HENHMETAFILE,UINT,LPBYTE,INT,INT);

/* PathGradientBrush functions */
GpStatus WINGDIPAPI GdipCreatePathGradient(GDIPCONST GpPointF*,INT,GpWrapMode,GpPathGradient**);
GpStatus WINGDIPAPI GdipCreatePathGradientI(GDIPCONST GpPoint*,INT,GpWrapMode,GpPathGradient**);
GpStatus WINGDIPAPI GdipCreatePathGradientFromPath(GDIPCONST GpPath*,GpPathGradient**);
GpStatus WINGDIPAPI GdipGetPathGradientCenterColor(GpPathGradient*,ARGB*);
GpStatus WINGDIPAPI GdipSetPathGradientCenterColor(GpPathGradient*,ARGB);
GpStatus WINGDIPAPI GdipGetPathGradientSurroundColorsWithCount(GpPathGradient*,ARGB*,INT*);
GpStatus WINGDIPAPI GdipSetPathGradientSurroundColorsWithCount(GpPathGradient*,GDIPCONST ARGB*,INT*);
GpStatus WINGDIPAPI GdipGetPathGradientPath(GpPathGradient*,GpPath*);
GpStatus WINGDIPAPI GdipSetPathGradientPath(GpPathGradient*,GDIPCONST GpPath*);
GpStatus WINGDIPAPI GdipGetPathGradientCenterPoint(GpPathGradient*,GpPointF*);
GpStatus WINGDIPAPI GdipGetPathGradientCenterPointI(GpPathGradient*,GpPoint*);
GpStatus WINGDIPAPI GdipSetPathGradientCenterPoint(GpPathGradient*,GDIPCONST GpPointF*);
GpStatus WINGDIPAPI GdipSetPathGradientCenterPointI(GpPathGradient*,GDIPCONST GpPoint*);
GpStatus WINGDIPAPI GdipGetPathGradientRect(GpPathGradient*,GpRectF*);
GpStatus WINGDIPAPI GdipGetPathGradientRectI(GpPathGradient*,GpRect*);
GpStatus WINGDIPAPI GdipGetPathGradientPointCount(GpPathGradient*,INT*);
GpStatus WINGDIPAPI GdipGetPathGradientSurroundColorCount(GpPathGradient*,INT*);
GpStatus WINGDIPAPI GdipSetPathGradientGammaCorrection(GpPathGradient*,BOOL);
GpStatus WINGDIPAPI GdipGetPathGradientGammaCorrection(GpPathGradient*,BOOL*);
GpStatus WINGDIPAPI GdipGetPathGradientBlendCount(GpPathGradient*,INT*);
GpStatus WINGDIPAPI GdipGetPathGradientBlend(GpPathGradient*,REAL*,REAL*,INT);
GpStatus WINGDIPAPI GdipSetPathGradientBlend(GpPathGradient*,GDIPCONST REAL*,GDIPCONST REAL*,INT);
GpStatus WINGDIPAPI GdipGetPathGradientPresetBlendCount(GpPathGradient*,INT*);
GpStatus WINGDIPAPI GdipGetPathGradientPresetBlend(GpPathGradient*,ARGB*,REAL*,INT);
GpStatus WINGDIPAPI GdipSetPathGradientPresetBlend(GpPathGradient*,GDIPCONST ARGB*,GDIPCONST REAL*,INT);
GpStatus WINGDIPAPI GdipSetPathGradientSigmaBlend(GpPathGradient*,REAL,REAL);
GpStatus WINGDIPAPI GdipSetPathGradientLinearBlend(GpPathGradient*,REAL,REAL);
GpStatus WINGDIPAPI GdipGetPathGradientWrapMode(GpPathGradient*,GpWrapMode*);
GpStatus WINGDIPAPI GdipSetPathGradientWrapMode(GpPathGradient*,GpWrapMode);
GpStatus WINGDIPAPI GdipGetPathGradientTransform(GpPathGradient*,GpMatrix*);
GpStatus WINGDIPAPI GdipSetPathGradientTransform(GpPathGradient*,GpMatrix*);
GpStatus WINGDIPAPI GdipResetPathGradientTransform(GpPathGradient*);
GpStatus WINGDIPAPI GdipMultiplyPathGradientTransform(GpPathGradient*,GDIPCONST GpMatrix*,GpMatrixOrder);
GpStatus WINGDIPAPI GdipTranslatePathGradientTransform(GpPathGradient*,REAL,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipScalePathGradientTransform(GpPathGradient*,REAL,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipRotatePathGradientTransform(GpPathGradient*,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipGetPathGradientFocusScales(GpPathGradient*,REAL*,REAL*);
GpStatus WINGDIPAPI GdipSetPathGradientFocusScales(GpPathGradient*,REAL,REAL);

/* PathIterator functions */
GpStatus WINGDIPAPI GdipCreatePathIter(GpPathIterator**,GpPath*);
GpStatus WINGDIPAPI GdipDeletePathIter(GpPathIterator*);
GpStatus WINGDIPAPI GdipPathIterNextSubpath(GpPathIterator*,INT*,INT*,INT*,BOOL*);
GpStatus WINGDIPAPI GdipPathIterNextSubpathPath(GpPathIterator*,INT*,GpPath*,BOOL*);
GpStatus WINGDIPAPI GdipPathIterNextPathType(GpPathIterator*,INT*,BYTE*,INT*,INT*);
GpStatus WINGDIPAPI GdipPathIterNextMarker(GpPathIterator*,INT*,INT*,INT*);
GpStatus WINGDIPAPI GdipPathIterNextMarkerPath(GpPathIterator*,INT*,GpPath*);
GpStatus WINGDIPAPI GdipPathIterGetCount(GpPathIterator*,INT*);
GpStatus WINGDIPAPI GdipPathIterGetSubpathCount(GpPathIterator*,INT*);
GpStatus WINGDIPAPI GdipPathIterIsValid(GpPathIterator*,BOOL*);
GpStatus WINGDIPAPI GdipPathIterHasCurve(GpPathIterator*,BOOL*);
GpStatus WINGDIPAPI GdipPathIterRewind(GpPathIterator*);
GpStatus WINGDIPAPI GdipPathIterEnumerate(GpPathIterator*,INT*,GpPointF*,BYTE*,INT);
GpStatus WINGDIPAPI GdipPathIterCopyData(GpPathIterator*,INT*,GpPointF*,BYTE*,INT,INT);

/* Pen functions */
GpStatus WINGDIPAPI GdipCreatePen1(ARGB,REAL,GpUnit,GpPen**);
GpStatus WINGDIPAPI GdipCreatePen2(GpBrush*,REAL,GpUnit,GpPen**);
GpStatus WINGDIPAPI GdipClonePen(GpPen*,GpPen**);
GpStatus WINGDIPAPI GdipDeletePen(GpPen*);
GpStatus WINGDIPAPI GdipSetPenWidth(GpPen*,REAL);
GpStatus WINGDIPAPI GdipGetPenWidth(GpPen*,REAL*);
GpStatus WINGDIPAPI GdipSetPenUnit(GpPen*,GpUnit);
GpStatus WINGDIPAPI GdipGetPenUnit(GpPen*,GpUnit*);
GpStatus WINGDIPAPI GdipSetPenLineCap197819(GpPen*,GpLineCap,GpLineCap,GpDashCap);
GpStatus WINGDIPAPI GdipSetPenStartCap(GpPen*,GpLineCap);
GpStatus WINGDIPAPI GdipSetPenEndCap(GpPen*,GpLineCap);
GpStatus WINGDIPAPI GdipSetPenDashCap197819(GpPen*,GpDashCap);
GpStatus WINGDIPAPI GdipGetPenStartCap(GpPen*,GpLineCap*);
GpStatus WINGDIPAPI GdipGetPenEndCap(GpPen*,GpLineCap*);
GpStatus WINGDIPAPI GdipGetPenDashCap197819(GpPen*,GpDashCap*);
GpStatus WINGDIPAPI GdipSetPenLineJoin(GpPen*,GpLineJoin);
GpStatus WINGDIPAPI GdipGetPenLineJoin(GpPen*,GpLineJoin*);
GpStatus WINGDIPAPI GdipSetPenCustomStartCap(GpPen*,GpCustomLineCap*);
GpStatus WINGDIPAPI GdipGetPenCustomStartCap(GpPen*,GpCustomLineCap**);
GpStatus WINGDIPAPI GdipSetPenCustomEndCap(GpPen*,GpCustomLineCap*);
GpStatus WINGDIPAPI GdipGetPenCustomEndCap(GpPen*,GpCustomLineCap**);
GpStatus WINGDIPAPI GdipSetPenMiterLimit(GpPen*,REAL);
GpStatus WINGDIPAPI GdipGetPenMiterLimit(GpPen*,REAL*);
GpStatus WINGDIPAPI GdipSetPenMode(GpPen*,GpPenAlignment);
GpStatus WINGDIPAPI GdipGetPenMode(GpPen*,GpPenAlignment*);
GpStatus WINGDIPAPI GdipSetPenTransform(GpPen*,GpMatrix*);
GpStatus WINGDIPAPI GdipGetPenTransform(GpPen*,GpMatrix*);
GpStatus WINGDIPAPI GdipResetPenTransform(GpPen*);
GpStatus WINGDIPAPI GdipMultiplyPenTransform(GpPen*,GDIPCONST GpMatrix*,GpMatrixOrder);
GpStatus WINGDIPAPI GdipTranslatePenTransform(GpPen*,REAL,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipScalePenTransform(GpPen*,REAL,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipRotatePenTransform(GpPen*,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipSetPenColor(GpPen*,ARGB);
GpStatus WINGDIPAPI GdipGetPenColor(GpPen*,ARGB*);
GpStatus WINGDIPAPI GdipSetPenBrushFill(GpPen*,GpBrush*);
GpStatus WINGDIPAPI GdipGetPenBrushFill(GpPen*,GpBrush**);
GpStatus WINGDIPAPI GdipGetPenFillType(GpPen*,GpPenType*);
GpStatus WINGDIPAPI GdipGetPenDashStyle(GpPen*,GpDashStyle*);
GpStatus WINGDIPAPI GdipSetPenDashStyle(GpPen*,GpDashStyle);
GpStatus WINGDIPAPI GdipGetPenDashOffset(GpPen*,REAL*);
GpStatus WINGDIPAPI GdipSetPenDashOffset(GpPen*,REAL);
GpStatus WINGDIPAPI GdipGetPenDashCount(GpPen*,INT*);
GpStatus WINGDIPAPI GdipSetPenDashArray(GpPen*,GDIPCONST REAL*,INT);
GpStatus WINGDIPAPI GdipGetPenDashArray(GpPen*,REAL*,INT);
GpStatus WINGDIPAPI GdipGetPenCompoundCount(GpPen*,INT*);
GpStatus WINGDIPAPI GdipSetPenCompoundArray(GpPen*,GDIPCONST REAL*,INT);
GpStatus WINGDIPAPI GdipGetPenCompoundArray(GpPen*,REAL*,INT);

/* Region functions */
GpStatus WINGDIPAPI GdipCreateRegion(GpRegion**);
GpStatus WINGDIPAPI GdipCreateRegionRect(GDIPCONST GpRectF*,GpRegion**);
GpStatus WINGDIPAPI GdipCreateRegionRectI(GDIPCONST GpRect*,GpRegion**);
GpStatus WINGDIPAPI GdipCreateRegionPath(GpPath*,GpRegion**);
GpStatus WINGDIPAPI GdipCreateRegionRgnData(GDIPCONST BYTE*,INT,GpRegion**);
GpStatus WINGDIPAPI GdipCreateRegionHrgn(HRGN,GpRegion**);
GpStatus WINGDIPAPI GdipCloneRegion(GpRegion*,GpRegion**);
GpStatus WINGDIPAPI GdipDeleteRegion(GpRegion*);
GpStatus WINGDIPAPI GdipSetInfinite(GpRegion*);
GpStatus WINGDIPAPI GdipSetEmpty(GpRegion*);
GpStatus WINGDIPAPI GdipCombineRegionRect(GpRegion*,GDIPCONST GpRectF*,CombineMode);
GpStatus WINGDIPAPI GdipCombineRegionRectI(GpRegion*,GDIPCONST GpRect*,CombineMode);
GpStatus WINGDIPAPI GdipCombineRegionPath(GpRegion*,GpPath*,CombineMode);
GpStatus WINGDIPAPI GdipCombineRegionRegion(GpRegion*,GpRegion*,CombineMode);
GpStatus WINGDIPAPI GdipTranslateRegion(GpRegion*,REAL,REAL);
GpStatus WINGDIPAPI GdipTranslateRegionI(GpRegion*,INT,INT);
GpStatus WINGDIPAPI GdipTransformRegion(GpRegion*,GpMatrix*);
GpStatus WINGDIPAPI GdipGetRegionBounds(GpRegion*,GpGraphics*,GpRectF*);
GpStatus WINGDIPAPI GdipGetRegionBoundsI(GpRegion*,GpGraphics*,GpRect*);
GpStatus WINGDIPAPI GdipGetRegionHRgn(GpRegion*,GpGraphics*,HRGN*);
GpStatus WINGDIPAPI GdipIsEmptyRegion(GpRegion*,GpGraphics*,BOOL*);
GpStatus WINGDIPAPI GdipIsInfiniteRegion(GpRegion*,GpGraphics*,BOOL*);
GpStatus WINGDIPAPI GdipIsEqualRegion(GpRegion*,GpRegion*,GpGraphics*,BOOL*);
GpStatus WINGDIPAPI GdipGetRegionDataSize(GpRegion*,UINT*);
GpStatus WINGDIPAPI GdipGetRegionData(GpRegion*,BYTE*,UINT,UINT*);
GpStatus WINGDIPAPI GdipIsVisibleRegionPoint(GpRegion*,REAL,REAL,GpGraphics*,BOOL*);
GpStatus WINGDIPAPI GdipIsVisibleRegionPointI(GpRegion*,INT,INT,GpGraphics*,BOOL*);
GpStatus WINGDIPAPI GdipIsVisibleRegionRect(GpRegion*,REAL,REAL,REAL,REAL,GpGraphics*,BOOL*);
GpStatus WINGDIPAPI GdipIsVisibleRegionRectI(GpRegion*,INT,INT,INT,INT,GpGraphics*,BOOL*);
GpStatus WINGDIPAPI GdipGetRegionScansCount(GpRegion*,UINT*,GpMatrix*);
GpStatus WINGDIPAPI GdipGetRegionScans(GpRegion*,GpRectF*,INT*,GpMatrix*);
GpStatus WINGDIPAPI GdipGetRegionScansI(GpRegion*,GpRect*,INT*,GpMatrix*);

/* SolidBrush functions */
GpStatus WINGDIPAPI GdipCreateSolidFill(ARGB,GpSolidFill**);
GpStatus WINGDIPAPI GdipSetSolidFillColor(GpSolidFill*,ARGB);
GpStatus WINGDIPAPI GdipGetSolidFillColor(GpSolidFill*,ARGB*);

/* StringFormat functions */
GpStatus WINGDIPAPI GdipCreateStringFormat(INT,LANGID,GpStringFormat**);
GpStatus WINGDIPAPI GdipStringFormatGetGenericDefault(GpStringFormat**);
GpStatus WINGDIPAPI GdipStringFormatGetGenericTypographic(GpStringFormat**);
GpStatus WINGDIPAPI GdipDeleteStringFormat(GpStringFormat*);
GpStatus WINGDIPAPI GdipCloneStringFormat(GDIPCONST GpStringFormat*,GpStringFormat**);
GpStatus WINGDIPAPI GdipSetStringFormatFlags(GpStringFormat*,INT);
GpStatus WINGDIPAPI GdipGetStringFormatFlags(GDIPCONST GpStringFormat*,INT*);
GpStatus WINGDIPAPI GdipSetStringFormatAlign(GpStringFormat*,StringAlignment);
GpStatus WINGDIPAPI GdipGetStringFormatAlign(GDIPCONST GpStringFormat*,StringAlignment*);
GpStatus WINGDIPAPI GdipSetStringFormatLineAlign(GpStringFormat*,StringAlignment);
GpStatus WINGDIPAPI GdipGetStringFormatLineAlign(GDIPCONST GpStringFormat*,StringAlignment*);
GpStatus WINGDIPAPI GdipSetStringFormatTrimming(GpStringFormat*,StringTrimming);
GpStatus WINGDIPAPI GdipGetStringFormatTrimming(GDIPCONST GpStringFormat*,StringTrimming*);
GpStatus WINGDIPAPI GdipSetStringFormatHotkeyPrefix(GpStringFormat*,INT);
GpStatus WINGDIPAPI GdipGetStringFormatHotkeyPrefix(GDIPCONST GpStringFormat*,INT*);
GpStatus WINGDIPAPI GdipSetStringFormatTabStops(GpStringFormat*,REAL,INT,GDIPCONST REAL*);
GpStatus WINGDIPAPI GdipGetStringFormatTabStops(GDIPCONST GpStringFormat*,INT,REAL*,REAL*);
GpStatus WINGDIPAPI GdipGetStringFormatTabStopCount(GDIPCONST GpStringFormat*,INT*);
GpStatus WINGDIPAPI GdipSetStringFormatDigitSubstitution(GpStringFormat*,LANGID,StringDigitSubstitute);
GpStatus WINGDIPAPI GdipGetStringFormatDigitSubstitution(GDIPCONST GpStringFormat*,LANGID*,StringDigitSubstitute*);
GpStatus WINGDIPAPI GdipGetStringFormatMeasurableCharacterRangeCount(GDIPCONST GpStringFormat*,INT*);
GpStatus WINGDIPAPI GdipSetStringFormatMeasurableCharacterRanges(GpStringFormat*,INT,GDIPCONST CharacterRange*);

/* Text functions */
GpStatus WINGDIPAPI GdipDrawString(GpGraphics*,GDIPCONST WCHAR*,INT,GDIPCONST GpFont*,GDIPCONST RectF*,GDIPCONST GpStringFormat*,GDIPCONST GpBrush*);
GpStatus WINGDIPAPI GdipMeasureString(GpGraphics*,GDIPCONST WCHAR*,INT,GDIPCONST GpFont*,GDIPCONST RectF*,GDIPCONST GpStringFormat*,RectF*,INT*,INT*);
#ifdef __cplusplus
GpStatus WINGDIPAPI GdipMeasureCharacterRanges(GpGraphics*,GDIPCONST WCHAR*,INT,GDIPCONST GpFont*,GDIPCONST RectF&,GDIPCONST GpStringFormat*,INT,GpRegion**);
#endif
GpStatus WINGDIPAPI GdipDrawDriverString(GpGraphics*,GDIPCONST UINT16*,INT,GDIPCONST GpFont*,GDIPCONST GpBrush*,GDIPCONST PointF*,INT,GDIPCONST GpMatrix*);
GpStatus WINGDIPAPI GdipMeasureDriverString(GpGraphics*,GDIPCONST UINT16*,INT,GDIPCONST GpFont*,GDIPCONST PointF*,INT,GDIPCONST GpMatrix*,RectF*);

/* TextureBrush functions */
GpStatus WINGDIPAPI GdipCreateTexture(GpImage*,GpWrapMode,GpTexture**);
GpStatus WINGDIPAPI GdipCreateTexture2(GpImage*,GpWrapMode,REAL,REAL,REAL,REAL,GpTexture**);
GpStatus WINGDIPAPI GdipCreateTexture2I(GpImage*,GpWrapMode,INT,INT,INT,INT,GpTexture**);
GpStatus WINGDIPAPI GdipCreateTextureIA(GpImage*,GDIPCONST GpImageAttributes*,REAL,REAL,REAL,REAL,GpTexture**);
GpStatus WINGDIPAPI GdipCreateTextureIAI(GpImage*,GDIPCONST GpImageAttributes*,INT,INT,INT,INT,GpTexture**);
GpStatus WINGDIPAPI GdipGetTextureTransform(GpTexture*,GpMatrix*);
GpStatus WINGDIPAPI GdipSetTextureTransform(GpTexture*,GDIPCONST GpMatrix*);
GpStatus WINGDIPAPI GdipResetTextureTransform(GpTexture*);
GpStatus WINGDIPAPI GdipMultiplyTextureTransform(GpTexture*,GDIPCONST GpMatrix*,GpMatrixOrder);
GpStatus WINGDIPAPI GdipTranslateTextureTransform(GpTexture*,REAL,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipScaleTextureTransform(GpTexture*,REAL,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipRotateTextureTransform(GpTexture*,REAL,GpMatrixOrder);
GpStatus WINGDIPAPI GdipSetTextureWrapMode(GpTexture*,GpWrapMode);
GpStatus WINGDIPAPI GdipGetTextureWrapMode(GpTexture*,GpWrapMode*);
GpStatus WINGDIPAPI GdipGetTextureImage(GpTexture*,GpImage**);

/* uncategorized functions */
GpStatus WINGDIPAPI GdipTestControl(GpTestControlEnum,void*);

#ifdef __cplusplus
}  /* extern "C" */
}  /* namespace DllExports */
#endif

#endif /* __GDIPLUS_FLAT_H */
