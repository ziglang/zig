/*
 * gdiplusimpl.h
 *
 * GDI+ Bitmap, CachedBitmap, CustomLineCap, Font, FontCollection, FontFamily,
 *      Image, InstalledFontCollection, PrivateFontCollection, Region
 *      implementation.  Definitions of these classes are in gdiplusheaders.h.
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

#ifndef __GDIPLUS_IMPL_H
#define __GDIPLUS_IMPL_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

#ifndef __cplusplus
#error "A C++ compiler is required to include gdiplusimpl.h."
#endif

/*
 * FIXME: I called this file gdiplusimpl.h, but what should it really be called?
 * Or did Microsoft create separate files for each class implemented here?
 */


// Image

__inline__ Image* Image::FromFile(const WCHAR *filename,
		BOOL useEmbeddedColorManagement)
{
	return new Image(filename, useEmbeddedColorManagement);
}

__inline__ Image* Image::FromStream(IStream *stream,
		BOOL useEmbeddedColorManagement)
{
	return new Image(stream, useEmbeddedColorManagement);
}

__inline__ Image::Image(const WCHAR *filename, BOOL useEmbeddedColorManagement):
	nativeImage(NULL), lastStatus(Ok)
{
	if (useEmbeddedColorManagement) {
		lastStatus = DllExports::GdipLoadImageFromFileICM(
				filename, &nativeImage);
	} else {
		lastStatus = DllExports::GdipLoadImageFromFile(
				filename, &nativeImage);
	}
}

__inline__ Image::Image(IStream *stream, BOOL useEmbeddedColorManagement):
	nativeImage(NULL), lastStatus(Ok)
{
	if (useEmbeddedColorManagement) {
		lastStatus = DllExports::GdipLoadImageFromStreamICM(
				stream, &nativeImage);
	} else {
		lastStatus = DllExports::GdipLoadImageFromStream(
				stream, &nativeImage);
	}
}

__inline__ Status Image::FindFirstItem(ImageItemData *item)
{
	// FIXME: can't test GdipFindFirstImageItem b/c it isn't exported in 1.0
	return updateStatus(DllExports::GdipFindFirstImageItem(
			nativeImage, item));
}

__inline__ Status Image::FindNextItem(ImageItemData *item)
{
	// FIXME: can't test GdipFindFirstImageItem b/c it isn't exported in 1.0
	return updateStatus(DllExports::GdipFindNextImageItem(
			nativeImage, item));
}

__inline__ Status Image::GetAllPropertyItems(UINT totalBufferSize,
		UINT numProperties, PropertyItem *allItems)
{
	return updateStatus(DllExports::GdipGetAllPropertyItems(
			nativeImage, totalBufferSize, numProperties, allItems));
}

__inline__ Status Image::GetBounds(RectF *srcRect, Unit *srcUnit)
{
	return updateStatus(DllExports::GdipGetImageBounds(
			nativeImage, srcRect, srcUnit));
}

__inline__ Status Image::GetEncoderParameterList(const CLSID *clsidEncoder,
		UINT size, EncoderParameters *buffer)
{
	return updateStatus(DllExports::GdipGetEncoderParameterList(
			nativeImage, clsidEncoder, size, buffer));
}

__inline__ UINT Image::GetEncoderParameterListSize(const CLSID *clsidEncoder)
{
	UINT result = 0;
	updateStatus(DllExports::GdipGetEncoderParameterListSize(
			nativeImage, clsidEncoder, &result));
	return result;
}

__inline__ UINT Image::GetFlags()
{
	UINT result = 0;
	updateStatus(DllExports::GdipGetImageFlags(nativeImage, &result));
	return result;
}

__inline__ UINT Image::GetFrameCount(const GUID *dimensionID)
{
	UINT result = 0;
	updateStatus(DllExports::GdipImageGetFrameCount(
			nativeImage, dimensionID, &result));
	return result;
}

__inline__ UINT Image::GetFrameDimensionsCount()
{
	UINT result = 0;
	updateStatus(DllExports::GdipImageGetFrameDimensionsCount(
			nativeImage, &result));
	return result;
}

__inline__ Status Image::GetFrameDimensionsList(GUID *dimensionIDs, UINT count)
{
	return updateStatus(DllExports::GdipImageGetFrameDimensionsList(
			nativeImage, dimensionIDs, count));
}

__inline__ UINT Image::GetHeight()
{
	UINT result = 0;
	updateStatus(DllExports::GdipGetImageHeight(nativeImage, &result));
	return result;
}

__inline__ REAL Image::GetHorizontalResolution()
{
	REAL result = 0.0f;
	updateStatus(DllExports::GdipGetImageHorizontalResolution(
			nativeImage, &result));
	return result;
}

__inline__ Status Image::GetItemData(ImageItemData *item)
{
	// FIXME: can't test GdipGetImageItemData b/c it isn't exported in 1.0
	return updateStatus(DllExports::GdipGetImageItemData(
			nativeImage, item));
}

__inline__ Status Image::GetPalette(ColorPalette *palette, INT size)
{
	return updateStatus(DllExports::GdipGetImagePalette(
			nativeImage, palette, size));
}

__inline__ INT Image::GetPaletteSize()
{
	INT result = 0;
	updateStatus(DllExports::GdipGetImagePaletteSize(nativeImage, &result));
	return result;
}

__inline__ Status Image::GetPhysicalDimension(SizeF *size)
{
	if (!size) return lastStatus = InvalidParameter;
	return updateStatus(DllExports::GdipGetImageDimension(
			nativeImage, &size->Width, &size->Height));
}

__inline__ PixelFormat Image::GetPixelFormat()
{
	PixelFormat result = (PixelFormat) 0;
	updateStatus(DllExports::GdipGetImagePixelFormat(nativeImage, &result));
	return result;
}

__inline__ UINT Image::GetPropertyCount()
{
	UINT result = 0;
	updateStatus(DllExports::GdipGetPropertyCount(nativeImage, &result));
	return result;
}

__inline__ Status Image::GetPropertyIdList(UINT numOfProperty, PROPID *list)
{
	return updateStatus(DllExports::GdipGetPropertyIdList(
			nativeImage, numOfProperty, list));
}

__inline__ Status Image::GetPropertyItem(PROPID propId, UINT propSize,
		PropertyItem *buffer)
{
	return updateStatus(DllExports::GdipGetPropertyItem(
			nativeImage, propId, propSize, buffer));
}

__inline__ UINT Image::GetPropertyItemSize(PROPID propId)
{
	UINT result = 0;
	updateStatus(DllExports::GdipGetPropertyItemSize(
			nativeImage, propId, &result));
	return result;
}

__inline__ Status Image::GetPropertySize(
		UINT *totalBufferSize, UINT *numProperties)
{
	return updateStatus(DllExports::GdipGetPropertySize(
			nativeImage, totalBufferSize, numProperties));
}

__inline__ Status Image::GetRawFormat(GUID *format)
{
	return updateStatus(DllExports::GdipGetImageRawFormat(
			nativeImage, format));
}

__inline__ Image* Image::GetThumbnailImage(UINT thumbWidth, UINT thumbHeight,
		GetThumbnailImageAbort callback, VOID *callbackData)
{
	GpImage *thumbImage = NULL;
	Status status = updateStatus(DllExports::GdipGetImageThumbnail(
			nativeImage, thumbWidth, thumbHeight, &thumbImage,
			callback, callbackData));

	if (status == Ok) {
		Image *result = new Image(thumbImage, Ok);
		if (!result) {
			DllExports::GdipDisposeImage(thumbImage);
			lastStatus = OutOfMemory;
		}
		return result;
	} else {
		return NULL;
	}
}

__inline__ ImageType Image::GetType() const
{
	ImageType result = ImageTypeUnknown;
	updateStatus(DllExports::GdipGetImageType(nativeImage, &result));
	return result;
}

__inline__ REAL Image::GetVerticalResolution()
{
	REAL result = 0.0f;
	updateStatus(DllExports::GdipGetImageVerticalResolution(
			nativeImage, &result));
	return result;
}

__inline__ UINT Image::GetWidth()
{
	UINT result = 0;
	updateStatus(DllExports::GdipGetImageWidth(nativeImage, &result));
	return result;
}

__inline__ Status Image::RemovePropertyItem(PROPID propId)
{
	return updateStatus(DllExports::GdipRemovePropertyItem(
			nativeImage, propId));
}

__inline__ Status Image::RotateFlip(RotateFlipType rotateFlipType)
{
	return updateStatus(DllExports::GdipImageRotateFlip(
			nativeImage, rotateFlipType));
}

__inline__ Status Image::Save(const WCHAR *filename, const CLSID *clsidEncoder,
		const EncoderParameters *encoderParams)
{
	return updateStatus(DllExports::GdipSaveImageToFile(
			nativeImage, filename, clsidEncoder, encoderParams));
}

__inline__ Status Image::Save(IStream *stream, const CLSID *clsidEncoder,
		const EncoderParameters *encoderParams)
{
	return updateStatus(DllExports::GdipSaveImageToStream(
			nativeImage, stream, clsidEncoder, encoderParams));
}

__inline__ Status Image::SaveAdd(const EncoderParameters *encoderParams)
{
	return updateStatus(DllExports::GdipSaveAdd(
			nativeImage, encoderParams));
}

__inline__ Status Image::SaveAdd(Image *newImage,
		const EncoderParameters *encoderParams)
{
	return updateStatus(DllExports::GdipSaveAddImage(
			nativeImage,
			newImage ? newImage->nativeImage : NULL,
			encoderParams));
}

__inline__ Status Image::SelectActiveFrame(
		const GUID *dimensionID, UINT frameIndex)
{
	return updateStatus(DllExports::GdipImageSelectActiveFrame(
			nativeImage, dimensionID, frameIndex));
}

__inline__ Status Image::SetAbort(GdiplusAbort *pIAbort)
{
	// FIXME: can't test GdipImageSetAbort because it isn't exported in 1.0
	return updateStatus(DllExports::GdipImageSetAbort(
			nativeImage, pIAbort));
}

__inline__ Status Image::SetPalette(const ColorPalette *palette)
{
	return updateStatus(DllExports::GdipSetImagePalette(
			nativeImage, palette));
}

__inline__ Status Image::SetPropertyItem(const PropertyItem *item)
{
	return updateStatus(DllExports::GdipSetPropertyItem(nativeImage, item));
}


// Bitmap

__inline__ Bitmap* Bitmap::FromBITMAPINFO(const BITMAPINFO *gdiBitmapInfo,
		VOID *gdiBitmapData)
{
	return new Bitmap(gdiBitmapInfo, gdiBitmapData);
}

__inline__ Bitmap* Bitmap::FromDirectDrawSurface7(IDirectDrawSurface7 *surface)
{
	return new Bitmap(surface);
}

__inline__ Bitmap* Bitmap::FromFile(const WCHAR *filename,
		BOOL useEmbeddedColorManagement)
{
	return new Bitmap(filename, useEmbeddedColorManagement);
}

__inline__ Bitmap* Bitmap::FromHBITMAP(HBITMAP hbm, HPALETTE hpal)
{
	return new Bitmap(hbm, hpal);
}

__inline__ Bitmap* Bitmap::FromHICON(HICON icon)
{
	return new Bitmap(icon);
}

__inline__ Bitmap* Bitmap::FromResource(
		HINSTANCE hInstance, const WCHAR *bitmapName)
{
	return new Bitmap(hInstance, bitmapName);
}

__inline__ Bitmap* Bitmap::FromStream(IStream *stream,
		BOOL useEmbeddedColorManagement)
{
	return new Bitmap(stream, useEmbeddedColorManagement);
}

//TODO: [GDI+ 1.1] Bitmap::ApplyEffect
//__inline__ Status Bitmap::ApplyEffect(Bitmap **inputs, INT numInputs,
//		Effect *effect, RECT *ROI, RECT *outputRect, Bitmap **output)
//{
//	return NotImplemented;
//}

__inline__ Status Bitmap::InitializePalette(ColorPalette *palette,
		PaletteType paletteType, INT optimalColors,
		BOOL useTransparentColor, Bitmap *bitmap)
{
	// FIXME: can't test GdipInitializePalette b/c it isn't exported in 1.0
	return DllExports::GdipInitializePalette(palette, paletteType,
			optimalColors, useTransparentColor,
			bitmap ? (GpBitmap*) bitmap->nativeImage : NULL);
}

__inline__ Bitmap::Bitmap(const BITMAPINFO *gdiBitmapInfo, VOID *gdiBitmapData):
	Image(NULL, Ok)
{
	GpBitmap *nativeBitmap = NULL;
	lastStatus = DllExports::GdipCreateBitmapFromGdiDib(
			gdiBitmapInfo, gdiBitmapData, &nativeBitmap);
	nativeImage = nativeBitmap;
}

__inline__ Bitmap::Bitmap(IDirectDrawSurface7 *surface): Image(NULL, Ok)
{
	GpBitmap *nativeBitmap = NULL;
	lastStatus = DllExports::GdipCreateBitmapFromDirectDrawSurface(
			surface, &nativeBitmap);
	nativeImage = nativeBitmap;
}

__inline__ Bitmap::Bitmap(const WCHAR *filename,
		BOOL useEmbeddedColorManagement): Image(NULL, Ok)
{
	GpBitmap *nativeBitmap = NULL;
	if (useEmbeddedColorManagement) {
		lastStatus = DllExports::GdipCreateBitmapFromFileICM(
				filename, &nativeBitmap);
	} else {
		lastStatus = DllExports::GdipCreateBitmapFromFile(
				filename, &nativeBitmap);
	}
	nativeImage = nativeBitmap;
}

__inline__ Bitmap::Bitmap(HBITMAP hbm, HPALETTE hpal):
	Image(NULL, Ok)
{
	GpBitmap *nativeBitmap = NULL;
	lastStatus = DllExports::GdipCreateBitmapFromHBITMAP(
			hbm, hpal, &nativeBitmap);
	nativeImage = nativeBitmap;
}

__inline__ Bitmap::Bitmap(HICON hicon):
	Image(NULL, Ok)
{
	GpBitmap *nativeBitmap = NULL;
	lastStatus = DllExports::GdipCreateBitmapFromHICON(hicon, &nativeBitmap);
	nativeImage = nativeBitmap;
}

__inline__ Bitmap::Bitmap(HINSTANCE hInstance, const WCHAR *bitmapName):
	Image(NULL, Ok)
{
	GpBitmap *nativeBitmap = NULL;
	lastStatus = DllExports::GdipCreateBitmapFromResource(
			hInstance, bitmapName, &nativeBitmap);
	nativeImage = nativeBitmap;
}

__inline__ Bitmap::Bitmap(IStream *stream, BOOL useEmbeddedColorManagement):
	Image(NULL, Ok)
{
	GpBitmap *nativeBitmap = NULL;
	if (useEmbeddedColorManagement) {
		lastStatus = DllExports::GdipCreateBitmapFromStreamICM(
				stream, &nativeBitmap);
	} else {
		lastStatus = DllExports::GdipCreateBitmapFromStream(
				stream, &nativeBitmap);
	}
	nativeImage = nativeBitmap;
}

__inline__ Bitmap::Bitmap(INT width, INT height, Graphics *target):
	Image(NULL, Ok)
{
	GpBitmap *nativeBitmap = NULL;
	lastStatus = DllExports::GdipCreateBitmapFromGraphics(
			width, height, target ? target->nativeGraphics : NULL,
			&nativeBitmap);
	nativeImage = nativeBitmap;
}

__inline__ Bitmap::Bitmap(INT width, INT height, PixelFormat format):
	Image(NULL, Ok)
{
	GpBitmap *nativeBitmap = NULL;
	lastStatus = DllExports::GdipCreateBitmapFromScan0(
			width, height, 0, format, NULL, &nativeBitmap);
	nativeImage = nativeBitmap;
}

__inline__ Bitmap::Bitmap(INT width, INT height, INT stride,
		PixelFormat format, BYTE *scan0): Image(NULL, Ok)
{
	GpBitmap *nativeBitmap = NULL;
	lastStatus = DllExports::GdipCreateBitmapFromScan0(
			width, height, stride, format, scan0, &nativeBitmap);
	nativeImage = nativeBitmap;
}

__inline__ Bitmap* Bitmap::Clone(const RectF& rect, PixelFormat format) const
{
	return Clone(rect.X, rect.Y, rect.Width, rect.Height, format);
}

__inline__ Bitmap* Bitmap::Clone(const Rect& rect, PixelFormat format) const
{
	return Clone(rect.X, rect.Y, rect.Width, rect.Height, format);
}

__inline__ Bitmap* Bitmap::Clone(REAL x, REAL y, REAL width, REAL height,
		PixelFormat format) const
{
	GpBitmap *cloneBitmap = NULL;
	Status status = updateStatus(DllExports::GdipCloneBitmapArea(
			x, y, width, height, format,
			(GpBitmap*) nativeImage, &cloneBitmap));
	if (status == Ok) {
		Bitmap *result = new Bitmap(cloneBitmap, lastStatus);
		if (!result) {
			DllExports::GdipDisposeImage(cloneBitmap);
			lastStatus = OutOfMemory;
		}
		return result;
	} else {
		return NULL;
	}
}

__inline__ Bitmap* Bitmap::Clone(INT x, INT y, INT width, INT height,
		PixelFormat format) const
{
	GpBitmap *cloneBitmap = NULL;
	Status status = updateStatus(DllExports::GdipCloneBitmapAreaI(
			x, y, width, height, format,
			(GpBitmap*) nativeImage, &cloneBitmap));
	if (status == Ok) {
		Bitmap *result = new Bitmap(cloneBitmap, lastStatus);
		if (!result) {
			DllExports::GdipDisposeImage(cloneBitmap);
			lastStatus = OutOfMemory;
		}
		return result;
	} else {
		return NULL;
	}
}

//TODO: [GDI+ 1.1] Bitmap::ApplyEffect
//__inline__ Status Bitmap::ApplyEffect(Effect *effect, RECT *ROI)
//{
//	return NotImplemented;
//}

__inline__ Status Bitmap::ConvertFormat(PixelFormat format,
		DitherType ditherType, PaletteType paletteType,
		ColorPalette *palette, REAL alphaThresholdPercent)
{
	// FIXME: can't test GdipBitmapConvertFormat b/c it isn't exported in 1.0
	return updateStatus(DllExports::GdipBitmapConvertFormat(
			(GpBitmap*) nativeImage, format, ditherType,
			paletteType, palette, alphaThresholdPercent));
}

__inline__ Status Bitmap::GetHBITMAP(
		const Color& colorBackground, HBITMAP *hbmReturn) const
{
	return updateStatus(DllExports::GdipCreateHBITMAPFromBitmap(
			(GpBitmap*) nativeImage, hbmReturn,
			colorBackground.GetValue()));
}

__inline__ Status Bitmap::GetHICON(HICON *icon) const
{
	return updateStatus(DllExports::GdipCreateHICONFromBitmap(
			(GpBitmap*) nativeImage, icon));
}

__inline__ Status Bitmap::GetHistogram(HistogramFormat format,
		UINT numberOfEntries,
		UINT *channel0, UINT *channel1,
		UINT *channel2, UINT *channel3) const
{
	return updateStatus(DllExports::GdipBitmapGetHistogram(
			(GpBitmap*) nativeImage, format, numberOfEntries,
			channel0, channel1, channel2, channel3));
}

__inline__ Status Bitmap::GetHistogramSize(HistogramFormat format,
		UINT *numberOfEntries) const
{
	return updateStatus(DllExports::GdipBitmapGetHistogramSize(
			format, numberOfEntries));
}

__inline__ Status Bitmap::GetPixel(INT x, INT y, Color *color) const
{
	return updateStatus(DllExports::GdipBitmapGetPixel(
			(GpBitmap*) nativeImage, x, y,
			color ? &color->Value : NULL));
}

__inline__ Status Bitmap::LockBits(const Rect *rect, UINT flags,
		PixelFormat format, BitmapData *lockedBitmapData)
{
	return updateStatus(DllExports::GdipBitmapLockBits(
			(GpBitmap*) nativeImage, rect, flags, format,
			lockedBitmapData));
}

__inline__ Status Bitmap::SetPixel(INT x, INT y, const Color& color)
{
	return updateStatus(DllExports::GdipBitmapSetPixel(
			(GpBitmap*) nativeImage, x, y, color.GetValue()));
}

__inline__ Status Bitmap::SetResolution(REAL xdpi, REAL ydpi)
{
	return updateStatus(DllExports::GdipBitmapSetResolution(
			(GpBitmap*) nativeImage, xdpi, ydpi));
}

__inline__ Status Bitmap::UnlockBits(BitmapData *lockedBitmapData)
{
	return updateStatus(DllExports::GdipBitmapUnlockBits(
			(GpBitmap*) nativeImage, lockedBitmapData));
}


// CachedBitmap

__inline__ CachedBitmap::CachedBitmap(Bitmap *bitmap, Graphics *graphics):
	nativeCachedBitmap(NULL), lastStatus(Ok)
{
	lastStatus = DllExports::GdipCreateCachedBitmap(
			bitmap ? ((GpBitmap*) bitmap->nativeImage) : NULL,
			graphics ? graphics->nativeGraphics : NULL,
			&nativeCachedBitmap);
}

__inline__ CachedBitmap::~CachedBitmap()
{
	DllExports::GdipDeleteCachedBitmap(nativeCachedBitmap);
}


// CustomLineCap

__inline__ CustomLineCap::CustomLineCap(
		const GraphicsPath *fillPath,
		const GraphicsPath *strokePath,
		LineCap baseCap, REAL baseInset):
		nativeCustomLineCap(NULL), lastStatus(Ok)
{
	lastStatus = DllExports::GdipCreateCustomLineCap(
			fillPath ? fillPath->nativePath : NULL,
			strokePath ? strokePath->nativePath : NULL,
			baseCap, baseInset, &nativeCustomLineCap);
}

__inline__ LineCap CustomLineCap::GetBaseCap() const
{
	LineCap result = LineCapFlat;
	updateStatus(DllExports::GdipGetCustomLineCapBaseCap(
			nativeCustomLineCap, &result));
	return result;
}

__inline__ REAL CustomLineCap::GetBaseInset() const
{
	REAL result = 0.0f;
	updateStatus(DllExports::GdipGetCustomLineCapBaseInset(
			nativeCustomLineCap, &result));
	return result;
}

__inline__ Status CustomLineCap::GetStrokeCaps(LineCap *startCap,
		LineCap *endCap) const
{
	return updateStatus(DllExports::GdipGetCustomLineCapStrokeCaps(
			nativeCustomLineCap, startCap, endCap));
}

__inline__ LineJoin CustomLineCap::GetStrokeJoin() const
{
	LineJoin result = LineJoinMiter;
	updateStatus(DllExports::GdipGetCustomLineCapStrokeJoin(
			nativeCustomLineCap, &result));
	return result;
}

__inline__ REAL CustomLineCap::GetWidthScale() const
{
	REAL result = 0.0f;
	updateStatus(DllExports::GdipGetCustomLineCapWidthScale(
			nativeCustomLineCap, &result));
	return result;
}

__inline__ Status CustomLineCap::SetBaseCap(LineCap baseCap)
{
	return updateStatus(DllExports::GdipSetCustomLineCapBaseCap(
			nativeCustomLineCap, baseCap));
}

__inline__ Status CustomLineCap::SetBaseInset(REAL inset)
{
	return updateStatus(DllExports::GdipSetCustomLineCapBaseInset(
			nativeCustomLineCap, inset));
}

__inline__ Status CustomLineCap::SetStrokeCap(LineCap strokeCap)
{
	return updateStatus(DllExports::GdipSetCustomLineCapStrokeCaps(
			nativeCustomLineCap, strokeCap, strokeCap));
}

__inline__ Status CustomLineCap::SetStrokeCaps(LineCap startCap, LineCap endCap)
{
	return updateStatus(DllExports::GdipSetCustomLineCapStrokeCaps(
			nativeCustomLineCap, startCap, endCap));
}

__inline__ Status CustomLineCap::SetStrokeJoin(LineJoin lineJoin)
{
	return updateStatus(DllExports::GdipSetCustomLineCapStrokeJoin(
			nativeCustomLineCap, lineJoin));
}

__inline__ Status CustomLineCap::SetWidthScale(REAL widthScale)
{
	return updateStatus(DllExports::GdipSetCustomLineCapWidthScale(
			nativeCustomLineCap, widthScale));
}


// Font

__inline__ Font::Font(const FontFamily *family,
		REAL emSize, INT style, Unit unit):
		nativeFont(NULL), lastStatus(Ok)
{
	lastStatus = DllExports::GdipCreateFont(
			family ? family->nativeFontFamily : NULL,
			emSize, style, unit, &nativeFont);
}

__inline__ Font::Font(HDC hdc, HFONT hfont):
	nativeFont(NULL), lastStatus(Ok)
{
	LOGFONTA logfont;
	if (hfont && GetObjectA(hfont, sizeof logfont, &logfont)) {
		lastStatus = DllExports::GdipCreateFontFromLogfontA(
				hdc, &logfont, &nativeFont);
	} else {
		lastStatus = DllExports::GdipCreateFontFromDC(
				hdc, &nativeFont);
	}
}

__inline__ Font::Font(HDC hdc, const LOGFONTA *logfont):
	nativeFont(NULL), lastStatus(Ok)
{
	lastStatus = DllExports::GdipCreateFontFromLogfontA(
			hdc, logfont, &nativeFont);
}

__inline__ Font::Font(HDC hdc, const LOGFONTW *logfont):
	nativeFont(NULL), lastStatus(Ok)
{
	lastStatus = DllExports::GdipCreateFontFromLogfontW(
			hdc, logfont, &nativeFont);
}

__inline__ Font::Font(HDC hdc):
	nativeFont(NULL), lastStatus(Ok)
{
	lastStatus = DllExports::GdipCreateFontFromDC(hdc, &nativeFont);
}

__inline__ Font::Font(const WCHAR *familyName, REAL emSize, INT style,
		Unit unit, const FontCollection *fontCollection):
		nativeFont(NULL), lastStatus(Ok)
{
	GpFontFamily *nativeFamily = NULL;
	lastStatus = DllExports::GdipCreateFontFamilyFromName(
			familyName,
			fontCollection ? fontCollection->nativeFontCollection : NULL,
			&nativeFamily);

	if (nativeFamily) {
		lastStatus = DllExports::GdipCreateFont(
				nativeFamily, emSize, style, unit, &nativeFont);
		DllExports::GdipDeleteFontFamily(nativeFamily);
	}
}

__inline__ Font::~Font()
{
	DllExports::GdipDeleteFont(nativeFont);
}

__inline__ Font* Font::Clone() const
{
	GpFont *cloneFont = NULL;
	Status status = updateStatus(DllExports::GdipCloneFont(
			nativeFont, &cloneFont));
	if (status == Ok) {
		Font *result = new Font(cloneFont, lastStatus);
		if (!result) {
			DllExports::GdipDeleteFont(cloneFont);
			lastStatus = OutOfMemory;
		}
		return result;
	} else {
		return NULL;
	}
}

__inline__ Status Font::GetFamily(FontFamily *family) const
{
	if (!family) return lastStatus = InvalidParameter;
	// FIXME: do we need to call GdipDeleteFontFamily first?
	return family->lastStatus = updateStatus(DllExports::GdipGetFamily(
			nativeFont, &family->nativeFontFamily));
}

__inline__ REAL Font::GetHeight(const Graphics *graphics) const
{
	REAL result = 0.0f;
	updateStatus(DllExports::GdipGetFontHeight(
			nativeFont, graphics ? graphics->nativeGraphics : NULL,
			&result));
	return result;
}

__inline__ REAL Font::GetHeight(REAL dpi) const
{
	REAL result = 0.0f;
	updateStatus(DllExports::GdipGetFontHeightGivenDPI(
			nativeFont, dpi, &result));
	return result;
}

__inline__ Status Font::GetLogFontA(const Graphics *graphics, LOGFONTA *logfontA)
const
{
	return updateStatus(DllExports::GdipGetLogFontA(
			nativeFont, graphics ? graphics->nativeGraphics : NULL,
			logfontA));
}

__inline__ Status Font::GetLogFontW(const Graphics *graphics, LOGFONTW *logfontW)
const
{
	return updateStatus(DllExports::GdipGetLogFontW(
			nativeFont, graphics ? graphics->nativeGraphics : NULL,
			logfontW));
}

__inline__ REAL Font::GetSize() const
{
	REAL result = 0.0;
	updateStatus(DllExports::GdipGetFontSize(nativeFont, &result));
	return result;
}

__inline__ INT Font::GetStyle() const
{
	INT result = FontStyleRegular;
	updateStatus(DllExports::GdipGetFontStyle(nativeFont, &result));
	return result;
}

__inline__ Unit Font::GetUnit() const
{
	Unit result = UnitPoint;
	updateStatus(DllExports::GdipGetFontUnit(nativeFont, &result));
	return result;
}


// FontCollection

__inline__ FontCollection::FontCollection():
	nativeFontCollection(NULL), lastStatus(Ok)
{
}

__inline__ Status FontCollection::GetFamilies(INT numSought,
		FontFamily *families, INT *numFound) const
{
	if (numSought <= 0 || !families || !numFound)
		return lastStatus = InvalidParameter;

	for (int i = 0; i < numSought; ++i) {
		families[i].nativeFontFamily = NULL;
		families[i].lastStatus = FontFamilyNotFound;
	}
	*numFound = 0;

	GpFontFamily **nativeFamilyArray = (GpFontFamily**)
		DllExports::GdipAlloc(numSought * sizeof (GpFontFamily*));
	if (!nativeFamilyArray)
		return lastStatus = OutOfMemory;

	Status status = updateStatus(DllExports::GdipGetFontCollectionFamilyList(
			nativeFontCollection, numSought, nativeFamilyArray,
			numFound));

	// FIXME: must the native GpFontFamily objects be cloned? Seems so.
	// (if this is not done, the "Creating a Private Font Collection"
	// example crashes on "delete[] pFontFamily")

	if (status == Ok) {
		for (int i = 0; i < *numFound; ++i) {
			families[i].lastStatus =
				updateStatus(DllExports::GdipCloneFontFamily(
					nativeFamilyArray[i],
					&families[i].nativeFontFamily));
		}
	}

	DllExports::GdipFree(nativeFamilyArray);
	return status;
}

__inline__ INT FontCollection::GetFamilyCount() const
{
	INT result = 0;
	updateStatus(DllExports::GdipGetFontCollectionFamilyCount(
			nativeFontCollection, &result));
	return result;
}


// FontFamily

// FIXME: do FontFamily::GenericMonospace() et al. need to be thread safe?
// FIXME: maybe put parts of this in gdiplus.c

extern "C" void *_GdipFontFamilyCachedGenericMonospace;
extern "C" void *_GdipFontFamilyCachedGenericSansSerif;
extern "C" void *_GdipFontFamilyCachedGenericSerif;

__inline__ const FontFamily* FontFamily::GenericMonospace()
{
	if (!_GdipFontFamilyCachedGenericMonospace) {
		GpFontFamily *nativeFontFamily = 0;
		Status status = DllExports::GdipGetGenericFontFamilyMonospace(
				&nativeFontFamily);
		if (status == Ok && nativeFontFamily) {
			_GdipFontFamilyCachedGenericMonospace = (void*)
				new FontFamily(nativeFontFamily, Ok);
		}
	}
	return (FontFamily*) _GdipFontFamilyCachedGenericMonospace;
}

__inline__ const FontFamily* FontFamily::GenericSansSerif()
{
	if (!_GdipFontFamilyCachedGenericSansSerif) {
		GpFontFamily *nativeFontFamily = 0;
		Status status = DllExports::GdipGetGenericFontFamilySansSerif(
				&nativeFontFamily);
		if (status == Ok && nativeFontFamily) {
			_GdipFontFamilyCachedGenericSansSerif = (void*)
				new FontFamily(nativeFontFamily, Ok);
		}
	}
	return (FontFamily*) _GdipFontFamilyCachedGenericSansSerif;
}

__inline__ const FontFamily* FontFamily::GenericSerif()
{
	if (!_GdipFontFamilyCachedGenericSerif) {
		GpFontFamily *nativeFontFamily = 0;
		Status status = DllExports::GdipGetGenericFontFamilySerif(
				&nativeFontFamily);
		if (status == Ok && nativeFontFamily) {
			_GdipFontFamilyCachedGenericSerif = (void*)
				new FontFamily(nativeFontFamily, Ok);
		}
	}
	return (FontFamily*) _GdipFontFamilyCachedGenericSerif;
}

__inline__ FontFamily::FontFamily():
	nativeFontFamily(NULL), lastStatus(Ok)
{
}

__inline__ FontFamily::FontFamily(const WCHAR *name,
		const FontCollection *fontCollection):
		nativeFontFamily(NULL), lastStatus(Ok)
{
	lastStatus = DllExports::GdipCreateFontFamilyFromName(name,
			fontCollection ? fontCollection->nativeFontCollection : NULL,
			&nativeFontFamily);
}

__inline__ FontFamily::~FontFamily()
{
	DllExports::GdipDeleteFontFamily(nativeFontFamily);
}

__inline__ FontFamily* FontFamily::Clone() const
{
	GpFontFamily *cloneFontFamily = NULL;
	Status status = updateStatus(DllExports::GdipCloneFontFamily(
			nativeFontFamily, &cloneFontFamily));
	if (status == Ok) {
		FontFamily *result = new FontFamily(cloneFontFamily, lastStatus);
		if (!result) {
			DllExports::GdipDeleteFontFamily(cloneFontFamily);
			lastStatus = OutOfMemory;
		}
		return result;
	} else {
		return NULL;
	}
}

__inline__ UINT16 FontFamily::GetCellAscent(INT style) const
{
	UINT16 result = 0;
	updateStatus(DllExports::GdipGetCellAscent(
			nativeFontFamily, style, &result));
	return result;
}

__inline__ UINT16 FontFamily::GetCellDescent(INT style) const
{
	UINT16 result = 0;
	updateStatus(DllExports::GdipGetCellDescent(
			nativeFontFamily, style, &result));
	return result;
}

__inline__ UINT16 FontFamily::GetEmHeight(INT style) const
{
	UINT16 result = 0;
	updateStatus(DllExports::GdipGetEmHeight(
			nativeFontFamily, style, &result));
	return result;
}

__inline__ Status FontFamily::GetFamilyName(WCHAR name[LF_FACESIZE],
		LANGID language) const
{
	return updateStatus(DllExports::GdipGetFamilyName(
			nativeFontFamily, name, language));
}

__inline__ UINT16 FontFamily::GetLineSpacing(INT style) const
{
	UINT16 result = 0;
	updateStatus(DllExports::GdipGetLineSpacing(
			nativeFontFamily, style, &result));
	return result;
}

__inline__ BOOL FontFamily::IsStyleAvailable(INT style) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsStyleAvailable(
			nativeFontFamily, style, &result));
	return result;
}


// InstalledFontCollection

__inline__ InstalledFontCollection::InstalledFontCollection()
{
	lastStatus = DllExports::GdipNewInstalledFontCollection(
			&nativeFontCollection);
}


// PrivateFontCollection

__inline__ PrivateFontCollection::PrivateFontCollection()
{
	lastStatus = DllExports::GdipNewPrivateFontCollection(
			&nativeFontCollection);
}

__inline__ Status PrivateFontCollection::AddFontFile(const WCHAR *filename)
{
	return updateStatus(DllExports::GdipPrivateAddFontFile(
			nativeFontCollection, filename));
}

__inline__ Status PrivateFontCollection::AddMemoryFont(
		const VOID *memory, INT length)
{
	return updateStatus(DllExports::GdipPrivateAddMemoryFont(
			nativeFontCollection, memory, length));
}


// Region

__inline__ Region* Region::FromHRGN(HRGN hrgn)
{
	return new Region(hrgn);
}

__inline__ Region::Region(): nativeRegion(NULL), lastStatus(Ok)
{
	lastStatus = DllExports::GdipCreateRegion(&nativeRegion);
}

__inline__ Region::Region(const RectF& rect): nativeRegion(NULL), lastStatus(Ok)
{
	lastStatus = DllExports::GdipCreateRegionRect(&rect, &nativeRegion);
}

__inline__ Region::Region(const Rect& rect): nativeRegion(NULL), lastStatus(Ok)
{
	lastStatus = DllExports::GdipCreateRegionRectI(&rect, &nativeRegion);
}

__inline__ Region::Region(const GraphicsPath *path):
	nativeRegion(NULL), lastStatus(Ok)
{
	lastStatus = DllExports::GdipCreateRegionPath(
			path ? path->nativePath : NULL, &nativeRegion);
}

__inline__ Region::Region(const BYTE *regionData, INT size):
	nativeRegion(NULL), lastStatus(Ok)
{
	lastStatus = DllExports::GdipCreateRegionRgnData(
			regionData, size, &nativeRegion);
}

__inline__ Region::Region(HRGN hrgn): nativeRegion(NULL), lastStatus(Ok)
{
	lastStatus = DllExports::GdipCreateRegionHrgn(hrgn, &nativeRegion);
}

__inline__ Region::~Region()
{
	DllExports::GdipDeleteRegion(nativeRegion);
}

__inline__ Region* Region::Clone() const
{
	GpRegion *cloneRegion = NULL;
	Status status = updateStatus(DllExports::GdipCloneRegion(
			nativeRegion, &cloneRegion));
	if (status == Ok) {
		Region *result = new Region(cloneRegion, lastStatus);
		if (!result) {
			DllExports::GdipDeleteRegion(cloneRegion);
			lastStatus = OutOfMemory;
		}
		return result;
	} else {
		return NULL;
	}
}

__inline__ Status Region::Complement(const RectF& rect)
{
	return updateStatus(DllExports::GdipCombineRegionRect(
			nativeRegion, &rect, CombineModeComplement));
}

__inline__ Status Region::Complement(const Rect& rect)
{
	return updateStatus(DllExports::GdipCombineRegionRectI(
			nativeRegion, &rect, CombineModeComplement));
}

__inline__ Status Region::Complement(const Region *region)
{
	return updateStatus(DllExports::GdipCombineRegionRegion(
			nativeRegion, region ? region->nativeRegion : NULL,
			CombineModeComplement));
}

__inline__ Status Region::Complement(const GraphicsPath *path)
{
	return updateStatus(DllExports::GdipCombineRegionPath(
			nativeRegion, path ? path->nativePath : NULL,
			CombineModeComplement));
}

__inline__ BOOL Region::Equals(const Region *region, const Graphics *graphics)
const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsEqualRegion(
			nativeRegion, region ? region->nativeRegion : NULL,
			graphics ? graphics->nativeGraphics : NULL, &result));
	return result;
}

__inline__ Status Region::Exclude(const RectF& rect)
{
	return updateStatus(DllExports::GdipCombineRegionRect(
			nativeRegion, &rect, CombineModeExclude));
}

__inline__ Status Region::Exclude(const Rect& rect)
{
	return updateStatus(DllExports::GdipCombineRegionRectI(
			nativeRegion, &rect, CombineModeExclude));
}

__inline__ Status Region::Exclude(const Region *region)
{
	return updateStatus(DllExports::GdipCombineRegionRegion(
			nativeRegion, region ? region->nativeRegion : NULL,
			CombineModeExclude));
}

__inline__ Status Region::Exclude(const GraphicsPath *path)
{
	return updateStatus(DllExports::GdipCombineRegionPath(
			nativeRegion, path ? path->nativePath : NULL,
			CombineModeExclude));
}

__inline__ Status Region::GetBounds(RectF *rect, const Graphics *graphics) const
{
	return updateStatus(DllExports::GdipGetRegionBounds(nativeRegion,
			graphics ? graphics->nativeGraphics : NULL, rect));
}

__inline__ Status Region::GetBounds(Rect *rect, const Graphics *graphics) const
{
	return updateStatus(DllExports::GdipGetRegionBoundsI(nativeRegion,
			graphics ? graphics->nativeGraphics : NULL, rect));
}

__inline__ Status Region::GetData(BYTE *buffer, UINT bufferSize,
		UINT *sizeFilled) const
{
	return updateStatus(DllExports::GdipGetRegionData(
			nativeRegion, buffer, bufferSize, sizeFilled));
}

__inline__ UINT Region::GetDataSize() const
{
	UINT result = 0;
	updateStatus(DllExports::GdipGetRegionDataSize(nativeRegion, &result));
	return result;
}

__inline__ HRGN Region::GetHRGN(const Graphics *graphics) const
{
	HRGN result = NULL;
	updateStatus(DllExports::GdipGetRegionHRgn(nativeRegion,
			graphics ? graphics->nativeGraphics : NULL, &result));
	return result;
}

__inline__ Status Region::GetRegionScans(const Matrix *matrix,
		RectF *rects, INT *count) const
{
	return updateStatus(DllExports::GdipGetRegionScans(
			nativeRegion, rects, count,
			matrix ? matrix->nativeMatrix : NULL));
}

__inline__ Status Region::GetRegionScans(const Matrix *matrix,
		Rect *rects, INT *count) const
{
	return updateStatus(DllExports::GdipGetRegionScansI(
			nativeRegion, rects, count,
			matrix ? matrix->nativeMatrix : NULL));
}

__inline__ UINT Region::GetRegionScansCount(const Matrix *matrix) const
{
	UINT result = 0;
	updateStatus(DllExports::GdipGetRegionScansCount(
			nativeRegion, &result,
			matrix ? matrix->nativeMatrix : NULL));
	return result;
}

__inline__ Status Region::Intersect(const RectF& rect)
{
	return updateStatus(DllExports::GdipCombineRegionRect(
			nativeRegion, &rect, CombineModeIntersect));
}

__inline__ Status Region::Intersect(const Rect& rect)
{
	return updateStatus(DllExports::GdipCombineRegionRectI(
			nativeRegion, &rect, CombineModeIntersect));
}

__inline__ Status Region::Intersect(const Region *region)
{
	return updateStatus(DllExports::GdipCombineRegionRegion(
			nativeRegion, region ? region->nativeRegion : NULL,
			CombineModeIntersect));
}

__inline__ Status Region::Intersect(const GraphicsPath *path)
{
	return updateStatus(DllExports::GdipCombineRegionPath(
			nativeRegion, path ? path->nativePath : NULL,
			CombineModeIntersect));
}

__inline__ BOOL Region::IsEmpty(const Graphics *graphics) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsEmptyRegion(nativeRegion,
			graphics ? graphics->nativeGraphics : NULL, &result));
	return result;
}

__inline__ BOOL Region::IsInfinite(const Graphics *graphics) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsInfiniteRegion(nativeRegion,
			graphics ? graphics->nativeGraphics : NULL, &result));
	return result;
}

__inline__ BOOL Region::IsVisible(REAL x, REAL y,
		const Graphics *graphics) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsVisibleRegionPoint(
			nativeRegion, x, y,
			graphics ? graphics->nativeGraphics : NULL, &result));
	return result;
}

__inline__ BOOL Region::IsVisible(INT x, INT y,
		const Graphics *graphics) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsVisibleRegionPointI(
			nativeRegion, x, y,
			graphics ? graphics->nativeGraphics : NULL, &result));
	return result;
}

__inline__ BOOL Region::IsVisible(const PointF& point,
		const Graphics *graphics) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsVisibleRegionPoint(
			nativeRegion, point.X, point.Y,
			graphics ? graphics->nativeGraphics : NULL, &result));
	return result;
}

__inline__ BOOL Region::IsVisible(const Point& point,
		const Graphics *graphics) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsVisibleRegionPointI(
			nativeRegion, point.X, point.Y,
			graphics ? graphics->nativeGraphics : NULL, &result));
	return result;
}

__inline__ BOOL Region::IsVisible(REAL x, REAL y, REAL width, REAL height,
		const Graphics *graphics) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsVisibleRegionRect(
			nativeRegion, x, y, width, height,
			graphics ? graphics->nativeGraphics : NULL, &result));
	return result;
}

__inline__ BOOL Region::IsVisible(INT x, INT y, INT width, INT height,
		const Graphics *graphics) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsVisibleRegionRectI(
			nativeRegion, x, y, width, height,
			graphics ? graphics->nativeGraphics : NULL, &result));
	return result;
}

__inline__ BOOL Region::IsVisible(const RectF& rect,
		const Graphics *graphics) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsVisibleRegionRect(
			nativeRegion, rect.X, rect.Y, rect.Width, rect.Height,
			graphics ? graphics->nativeGraphics : NULL, &result));
	return result;
}

__inline__ BOOL Region::IsVisible(const Rect& rect,
		const Graphics *graphics) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsVisibleRegionRectI(
			nativeRegion, rect.X, rect.Y, rect.Width, rect.Height,
			graphics ? graphics->nativeGraphics : NULL, &result));
	return result;
}

__inline__ Status Region::MakeEmpty()
{
	return updateStatus(DllExports::GdipSetEmpty(nativeRegion));
}

__inline__ Status Region::MakeInfinite()
{
	return updateStatus(DllExports::GdipSetInfinite(nativeRegion));
}

__inline__ Status Region::Transform(const Matrix *matrix)
{
	return updateStatus(DllExports::GdipTransformRegion(
			nativeRegion, matrix ? matrix->nativeMatrix : NULL));
}

__inline__ Status Region::Translate(REAL dx, REAL dy)
{
	return updateStatus(DllExports::GdipTranslateRegion(
			nativeRegion, dx, dy));
}

__inline__ Status Region::Translate(INT dx, INT dy)
{
	return updateStatus(DllExports::GdipTranslateRegionI(
			nativeRegion, dx, dy));
}

__inline__ Status Region::Union(const RectF& rect)
{
	return updateStatus(DllExports::GdipCombineRegionRect(
			nativeRegion, &rect, CombineModeUnion));
}

__inline__ Status Region::Union(const Rect& rect)
{
	return updateStatus(DllExports::GdipCombineRegionRectI(
			nativeRegion, &rect, CombineModeUnion));
}

__inline__ Status Region::Union(const Region *region)
{
	return updateStatus(DllExports::GdipCombineRegionRegion(
			nativeRegion, region ? region->nativeRegion : NULL,
			CombineModeUnion));
}

__inline__ Status Region::Union(const GraphicsPath *path)
{
	return updateStatus(DllExports::GdipCombineRegionPath(
			nativeRegion, path ? path->nativePath : NULL,
			CombineModeUnion));
}

__inline__ Status Region::Xor(const RectF& rect)
{
	return updateStatus(DllExports::GdipCombineRegionRect(
			nativeRegion, &rect, CombineModeXor));
}

__inline__ Status Region::Xor(const Rect& rect)
{
	return updateStatus(DllExports::GdipCombineRegionRectI(
			nativeRegion, &rect, CombineModeXor));
}

__inline__ Status Region::Xor(const Region *region)
{
	return updateStatus(DllExports::GdipCombineRegionRegion(
			nativeRegion, region ? region->nativeRegion : NULL,
			CombineModeXor));
}

__inline__ Status Region::Xor(const GraphicsPath *path)
{
	return updateStatus(DllExports::GdipCombineRegionPath(
			nativeRegion, path ? path->nativePath : NULL,
			CombineModeXor));
}


// GraphicsPath

__inline__ BOOL GraphicsPath::IsOutlineVisible(REAL x, REAL y, const Pen *pen,
		const Graphics *g) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsOutlineVisiblePathPoint(
			nativePath, x, y, pen ? pen->nativePen : NULL,
			g ? g->nativeGraphics : NULL, &result));
	return result;
}

__inline__ BOOL GraphicsPath::IsOutlineVisible(INT x, INT y, const Pen *pen,
		const Graphics *g) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsOutlineVisiblePathPointI(
			nativePath, x, y, pen ? pen->nativePen : NULL,
			g ? g->nativeGraphics : NULL, &result));
	return result;
}

__inline__ BOOL GraphicsPath::IsOutlineVisible(const PointF& point, const Pen *pen,
		const Graphics *g) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsOutlineVisiblePathPoint(
			nativePath, point.X, point.Y,
			pen ? pen->nativePen : NULL,
			g ? g->nativeGraphics : NULL, &result));
	return result;
}

__inline__ BOOL GraphicsPath::IsOutlineVisible(const Point& point, const Pen *pen,
		const Graphics *g) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsOutlineVisiblePathPointI(
			nativePath, point.X, point.Y,
			pen ? pen->nativePen : NULL,
			g ? g->nativeGraphics : NULL, &result));
	return result;
}

__inline__ BOOL GraphicsPath::IsVisible(REAL x, REAL y, const Graphics *g) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsVisiblePathPoint(
			nativePath, x, y,
			g ? g->nativeGraphics : NULL, &result));
	return result;
}
__inline__ BOOL GraphicsPath::IsVisible(INT x, INT y, const Graphics *g) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsVisiblePathPointI(
			nativePath, x, y,
			g ? g->nativeGraphics : NULL, &result));
	return result;
}

__inline__ BOOL GraphicsPath::IsVisible(const PointF& point,
		const Graphics *g) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsVisiblePathPoint(
			nativePath, point.X, point.Y,
			g ? g->nativeGraphics : NULL, &result));
	return result;
}

__inline__ BOOL GraphicsPath::IsVisible(const Point& point, const Graphics *g) const
{
	BOOL result = FALSE;
	updateStatus(DllExports::GdipIsVisiblePathPointI(
			nativePath, point.X, point.Y,
			g ? g->nativeGraphics : NULL, &result));
	return result;
}


// PathData

__inline__ Status PathData::AllocateArrays(INT capacity)
{
	if (capacity < 0) {
		return InvalidParameter;
	} else if (Count < capacity) {
		FreeArrays();

		PointF *pointArray = (PointF*)
			DllExports::GdipAlloc(capacity * sizeof(PointF));
		if (!pointArray)
			return OutOfMemory;

		BYTE *typeArray = (BYTE*)
			DllExports::GdipAlloc(capacity * sizeof(BYTE));
		if (!typeArray) {
			DllExports::GdipFree(pointArray);
			return OutOfMemory;
		}

		Count = capacity;
		Points = pointArray;
		Types = typeArray;
	}
	return Ok;
}

__inline__ VOID PathData::FreeArrays()
{
	if (Points) DllExports::GdipFree(Points);
	if (Types) DllExports::GdipFree(Types);
	Count = 0;
	Points = NULL;
	Types = NULL;
}

#endif /* __GDIPLUS_IMPL_H */
