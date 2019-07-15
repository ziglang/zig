/*
 * gdiplusheaders.h
 *
 * GDI+ Bitmap, CachedBitmap, CustomLineCap, Font, FontCollection,
 *      FontFamily, Image, InstalledFontCollection, PrivateFontCollection,
 *      Region class definitions.
 *      Implementation of these classes is in gdiplusimpl.h.
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

#ifndef __GDIPLUS_HEADERS_H
#define __GDIPLUS_HEADERS_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

#ifndef __cplusplus
#error "A C++ compiler is required to include gdiplusheaders.h."
#endif

/*
 * Note: Virtual inline functions (dtors, Clone()) are implemented here: If
 * these were defined outside class scope, the compiler would always generate
 * code for them (and the vtable), even if these classes were never used.
 */

class Bitmap;
class Effect;
class FontCollection;
class FontFamily;
class Graphics;
class GraphicsPath;
class Matrix;
class Pen;

class Image: public GdiplusBase
{
	friend class Bitmap;
	friend class Metafile;
	friend class CachedBitmap;
	friend class Graphics;
	friend class TextureBrush;

public:
	static Image* FromFile(const WCHAR *filename,
			BOOL useEmbeddedColorManagement = FALSE);
	static Image* FromStream(IStream *stream,
			BOOL useEmbeddedColorManagement = FALSE);

	Image(const WCHAR *filename, BOOL useEmbeddedColorManagement = FALSE);
	Image(IStream *stream, BOOL useEmbeddedColorManagement = FALSE);

	virtual ~Image()
	{
		DllExports::GdipDisposeImage(nativeImage);
	}
	virtual Image* Clone() const
	{
		GpImage *cloneImage = NULL;
		Status status = updateStatus(DllExports::GdipCloneImage(
				nativeImage, &cloneImage));
		if (status == Ok) {
			Image *result = new Image(cloneImage, lastStatus);
			if (!result) {
				DllExports::GdipDisposeImage(cloneImage);
				lastStatus = OutOfMemory;
			}
			return result;
		} else {
			return NULL;
		}
	}

	Status FindFirstItem(ImageItemData *item);
	Status FindNextItem(ImageItemData *item);
	Status GetAllPropertyItems(UINT totalBufferSize,
			UINT numProperties, PropertyItem *allItems);
	Status GetBounds(RectF *srcRect, Unit *srcUnit);
	Status GetEncoderParameterList(const CLSID *clsidEncoder,
			UINT size, EncoderParameters *buffer);
	UINT GetEncoderParameterListSize(const CLSID *clsidEncoder);
	UINT GetFlags();
	UINT GetFrameCount(const GUID *dimensionID);
	UINT GetFrameDimensionsCount();
	Status GetFrameDimensionsList(GUID *dimensionIDs, UINT count);
	UINT GetHeight();
	REAL GetHorizontalResolution();
	Status GetItemData(ImageItemData *item);
	Status GetPalette(ColorPalette *palette, INT size);
	INT GetPaletteSize();
	Status GetPhysicalDimension(SizeF *size);
	PixelFormat GetPixelFormat();
	UINT GetPropertyCount();
	Status GetPropertyIdList(UINT numOfProperty, PROPID *list);
	Status GetPropertyItem(PROPID propId, UINT propSize,
			PropertyItem *buffer);
	UINT GetPropertyItemSize(PROPID propId);
	Status GetPropertySize(UINT *totalBufferSize, UINT *numProperties);
	Status GetRawFormat(GUID *format);
	Image* GetThumbnailImage(UINT thumbWidth, UINT thumbHeight,
			GetThumbnailImageAbort callback, VOID *callbackData);
	ImageType GetType() const;
	REAL GetVerticalResolution();
	UINT GetWidth();
	Status RemovePropertyItem(PROPID propId);
	Status RotateFlip(RotateFlipType rotateFlipType);
	Status Save(IStream *stream, const CLSID *clsidEncoder,
			const EncoderParameters *encoderParams);
	Status Save(const WCHAR *filename, const CLSID *clsidEncoder,
			const EncoderParameters *encoderParams);
	Status SaveAdd(const EncoderParameters *encoderParams);
	Status SaveAdd(Image *newImage, const EncoderParameters *encoderParams);
	Status SelectActiveFrame(const GUID *dimensionID, UINT frameIndex);
	Status SetAbort(GdiplusAbort *pIAbort);
	Status SetPalette(const ColorPalette *palette);
	Status SetPropertyItem(const PropertyItem *item);

	Status GetLastStatus() const
	{
		Status result = lastStatus;
		lastStatus = Ok;
		return result;
	}

private:
	Image(GpImage *image, Status status):
		nativeImage(image), lastStatus(status) {}
	Image(const Image&);
	Image& operator=(const Image&);

	Status updateStatus(Status newStatus) const
	{
		if (newStatus != Ok) lastStatus = newStatus;
		return newStatus;
	}

	GpImage *nativeImage;
	mutable Status lastStatus;
};

class Bitmap: public Image
{
public:
	static Bitmap* FromBITMAPINFO(const BITMAPINFO *gdiBitmapInfo,
			VOID *gdiBitmapData);
	static Bitmap* FromDirectDrawSurface7(IDirectDrawSurface7 *surface);
	static Bitmap* FromFile(const WCHAR *filename,
			BOOL useEmbeddedColorManagement = FALSE);
	static Bitmap* FromHBITMAP(HBITMAP hbm, HPALETTE hpal);
	static Bitmap* FromHICON(HICON icon);
	static Bitmap* FromResource(HINSTANCE hInstance,
			const WCHAR *bitmapName);
	static Bitmap* FromStream(IStream *stream,
			BOOL useEmbeddedColorManagement = FALSE);
	static Status ApplyEffect(Bitmap **inputs, INT numInputs,
			Effect *effect, RECT *ROI,
			RECT *outputRect, Bitmap **output);
	static Status InitializePalette(ColorPalette *palette,
			PaletteType paletteType, INT optimalColors,
			BOOL useTransparentColor, Bitmap *bitmap);

	Bitmap(const BITMAPINFO *gdiBitmapInfo, VOID *gdiBitmapData);
	Bitmap(IDirectDrawSurface7 *surface);
	Bitmap(const WCHAR *filename, BOOL useEmbeddedColorManagement = FALSE);
	Bitmap(HBITMAP hbm, HPALETTE hpal);
	Bitmap(HICON hicon);
	Bitmap(HINSTANCE hInstance, const WCHAR *bitmapName);
	Bitmap(IStream *stream, BOOL useEmbeddedColorManagement = FALSE);
	Bitmap(INT width, INT height, Graphics *target);
	Bitmap(INT width, INT height, PixelFormat format = PixelFormat32bppARGB);
	Bitmap(INT width, INT height, INT stride, PixelFormat format, BYTE *scan0);

	virtual ~Bitmap()
	{
	}
	virtual Bitmap* Clone() const
	{
		GpImage *cloneImage = NULL;
		Status status = updateStatus(DllExports::GdipCloneImage(
				nativeImage, &cloneImage));
		if (status == Ok) {
			Bitmap *result = new Bitmap(cloneImage, lastStatus);
			if (!result) {
				DllExports::GdipDisposeImage(cloneImage);
				lastStatus = OutOfMemory;
			}
			return result;
		} else {
			return NULL;
		}
	}

	Bitmap* Clone(const RectF& rect, PixelFormat format) const;
	Bitmap* Clone(const Rect& rect, PixelFormat format) const;
	Bitmap* Clone(REAL x, REAL y, REAL width, REAL height,
			PixelFormat format) const;
	Bitmap* Clone(INT x, INT y, INT width, INT height,
			PixelFormat format) const;

	Status ApplyEffect(Effect *effect, RECT *ROI);
	Status ConvertFormat(PixelFormat format, DitherType ditherType,
			PaletteType paletteType, ColorPalette *palette,
			REAL alphaThresholdPercent);
	Status GetHBITMAP(const Color& colorBackground, HBITMAP *hbmReturn) const;
	Status GetHICON(HICON *icon) const;
	Status GetHistogram(HistogramFormat format, UINT numberOfEntries,
			UINT *channel0, UINT *channel1,
			UINT *channel2, UINT *channel3) const;
	Status GetHistogramSize(HistogramFormat format,
			UINT *numberOfEntries) const;
	Status GetPixel(INT x, INT y, Color *color) const;
	Status LockBits(const Rect *rect, UINT flags, PixelFormat format,
			BitmapData *lockedBitmapData);
	Status SetPixel(INT x, INT y, const Color& color);
	Status SetResolution(REAL xdpi, REAL ydpi);
	Status UnlockBits(BitmapData *lcokedBitmapData);

private:
	Bitmap(GpImage *image, Status status): Image(image, status) {}
	Bitmap(const Bitmap&);
	Bitmap& operator=(const Bitmap&);
};

class CachedBitmap: public GdiplusBase
{
	friend class Graphics;

public:
	CachedBitmap(Bitmap *bitmap, Graphics *graphics);
	~CachedBitmap();

	Status GetLastStatus() const
	{
		return lastStatus;
	}

private:
	CachedBitmap(const CachedBitmap&);
	CachedBitmap& operator=(const CachedBitmap&);

	GpCachedBitmap *nativeCachedBitmap;
	Status lastStatus;
};

class CustomLineCap: public GdiplusBase
{
	friend class AdjustableArrowCap;
	friend class Pen;

public:
	CustomLineCap(const GraphicsPath *fillPath,
			const GraphicsPath *strokePath,
			LineCap baseCap = LineCapFlat,
			REAL baseInset = 0.0f);

	virtual ~CustomLineCap()
	{
		DllExports::GdipDeleteCustomLineCap(nativeCustomLineCap);
	}
	virtual CustomLineCap* Clone() const
	{
		GpCustomLineCap *cloneCustomLineCap = NULL;
		Status status = updateStatus(DllExports::GdipCloneCustomLineCap(
				nativeCustomLineCap, &cloneCustomLineCap));
		if (status == Ok) {
			CustomLineCap *result = new CustomLineCap(
					cloneCustomLineCap, lastStatus);
			if (!result) {
				DllExports::GdipDeleteCustomLineCap(cloneCustomLineCap);
				lastStatus = OutOfMemory;
			}
			return result;
		} else {
			return NULL;
		}
	}

	LineCap GetBaseCap() const;
	REAL GetBaseInset() const;
	Status GetStrokeCaps(LineCap *startCap, LineCap *endCap) const;
	LineJoin GetStrokeJoin() const;
	REAL GetWidthScale() const;
	Status SetBaseCap(LineCap baseCap);
	Status SetBaseInset(REAL inset);
	Status SetStrokeCap(LineCap strokeCap);
	Status SetStrokeCaps(LineCap startCap, LineCap endCap);
	Status SetStrokeJoin(LineJoin lineJoin);
	Status SetWidthScale(REAL widthScale);

	Status GetLastStatus() const
	{
		Status result = lastStatus;
		lastStatus = Ok;
		return result;
	}

private:
	CustomLineCap(GpCustomLineCap *customLineCap, Status status):
		nativeCustomLineCap(customLineCap), lastStatus(status) {}
	CustomLineCap(const CustomLineCap&);
	CustomLineCap& operator=(const CustomLineCap&);

	Status updateStatus(Status newStatus) const
	{
		if (newStatus != Ok) lastStatus = newStatus;
		return newStatus;
	}

	GpCustomLineCap *nativeCustomLineCap;
	mutable Status lastStatus;
};

class Font: public GdiplusBase
{
	friend class Graphics;

public:
	Font(const FontFamily *family, REAL emSize,
			INT style = FontStyleRegular,
			Unit unit = UnitPoint);
	Font(HDC hdc, HFONT hfont);
	Font(HDC hdc, const LOGFONTA *logfont);
	Font(HDC hdc, const LOGFONTW *logfont);
	Font(HDC hdc);
	Font(const WCHAR *familyName, REAL emSize,
			INT style = FontStyleRegular,
			Unit unit = UnitPoint,
			const FontCollection *fontCollection = NULL);
	~Font();
	Font* Clone() const;

	Status GetFamily(FontFamily *family) const;
	REAL GetHeight(const Graphics *graphics) const;
	REAL GetHeight(REAL dpi) const;
	Status GetLogFontA(const Graphics *graphics, LOGFONTA *logfontA) const;
	Status GetLogFontW(const Graphics *graphics, LOGFONTW *logfontW) const;
	REAL GetSize() const;
	INT GetStyle() const;
	Unit GetUnit() const;

	Status GetLastStatus() const
	{
		return lastStatus;
	}
	BOOL IsAvailable() const
	{
		return nativeFont != NULL;
	}

private:
	Font(GpFont *font, Status status):
		nativeFont(font), lastStatus(status) {}
	Font(const Font&);
	Font& operator=(const Font&);

	Status updateStatus(Status newStatus) const
	{
		if (newStatus != Ok) lastStatus = newStatus;
		return newStatus;
	}

	GpFont *nativeFont;
	mutable Status lastStatus;
};

class FontCollection: public GdiplusBase
{
	friend class InstalledFontCollection;
	friend class PrivateFontCollection;
	friend class Font;
	friend class FontFamily;

public:
	FontCollection();
	virtual ~FontCollection() {}

	Status GetFamilies(INT numSought, FontFamily *families,
			INT *numFound) const;
	INT GetFamilyCount() const;

	Status GetLastStatus() const
	{
		return lastStatus;
	}

private:
	FontCollection(const FontCollection&);
	FontCollection& operator=(const FontCollection&);

	Status updateStatus(Status newStatus) const
	{
		return lastStatus = newStatus;
	}

	GpFontCollection *nativeFontCollection;
	mutable Status lastStatus;
};

class FontFamily: public GdiplusBase
{
	friend class Font;
	friend class FontCollection;
	friend class GraphicsPath;

public:
	static const FontFamily* GenericMonospace();
	static const FontFamily* GenericSansSerif();
	static const FontFamily* GenericSerif();

	FontFamily();
	FontFamily(const WCHAR *name,
			const FontCollection *fontCollection = NULL);
	~FontFamily();
	FontFamily* Clone() const;

	UINT16 GetCellAscent(INT style) const;
	UINT16 GetCellDescent(INT style) const;
	UINT16 GetEmHeight(INT style) const;
	Status GetFamilyName(WCHAR name[LF_FACESIZE],
			LANGID language = LANG_NEUTRAL) const;
	UINT16 GetLineSpacing(INT style) const;
	BOOL IsStyleAvailable(INT style) const;

	Status GetLastStatus() const
	{
		Status result = lastStatus;
		lastStatus = Ok;
		return result;
	}
	BOOL IsAvailable() const
	{
		return nativeFontFamily != NULL;
	}

private:
	FontFamily(GpFontFamily *fontFamily, Status status):
		nativeFontFamily(fontFamily), lastStatus(status) {}
	FontFamily(const FontFamily&);
	FontFamily& operator=(const FontFamily&);

	Status updateStatus(Status newStatus) const
	{
		if (newStatus != Ok) lastStatus = newStatus;
		return newStatus;
	}

	GpFontFamily *nativeFontFamily;
	mutable Status lastStatus;
};

class InstalledFontCollection: public FontCollection
{
public:
	InstalledFontCollection();
	virtual ~InstalledFontCollection() {}
};

class PrivateFontCollection: public FontCollection
{
public:
	PrivateFontCollection();

	virtual ~PrivateFontCollection()
	{
		DllExports::GdipDeletePrivateFontCollection(&nativeFontCollection);
	}

	Status AddFontFile(const WCHAR *filename);
	Status AddMemoryFont(const VOID *memory, INT length);
};

class Region: public GdiplusBase
{
	friend class Graphics;

public:
	static Region* FromHRGN(HRGN hrgn);

	Region();
	Region(const RectF& rect);
	Region(const Rect& rect);
	Region(const GraphicsPath *path);
	Region(const BYTE *regionData, INT size);
	Region(HRGN hrgn);
	~Region();
	Region* Clone() const;

	Status Complement(const RectF& rect);
	Status Complement(const Rect& rect);
	Status Complement(const Region *region);
	Status Complement(const GraphicsPath *path);
	BOOL Equals(const Region *region, const Graphics *graphics) const;
	Status Exclude(const RectF& rect);
	Status Exclude(const Rect& rect);
	Status Exclude(const Region *region);
	Status Exclude(const GraphicsPath *path);
	Status GetBounds(RectF *rect, const Graphics *graphics) const;
	Status GetBounds(Rect *rect, const Graphics *graphics) const;
	Status GetData(BYTE *buffer, UINT bufferSize, UINT *sizeFilled) const;
	UINT GetDataSize() const;
	HRGN GetHRGN(const Graphics *graphics) const;
	Status GetRegionScans(const Matrix *matrix,
			RectF *rects, INT *count) const;
	Status GetRegionScans(const Matrix *matrix,
			Rect *rects, INT *count) const;
	UINT GetRegionScansCount(const Matrix *matrix) const;
	Status Intersect(const RectF& rect);
	Status Intersect(const Rect& rect);
	Status Intersect(const Region *region);
	Status Intersect(const GraphicsPath *path);
	BOOL IsEmpty(const Graphics *graphics) const;
	BOOL IsInfinite(const Graphics *graphics) const;
	BOOL IsVisible(REAL x, REAL y,
			const Graphics *graphics = NULL) const;
	BOOL IsVisible(INT x, INT y,
			const Graphics *graphics = NULL) const;
	BOOL IsVisible(const PointF& point,
			const Graphics *graphics = NULL) const;
	BOOL IsVisible(const Point& point,
			const Graphics *graphics = NULL) const;
	BOOL IsVisible(REAL x, REAL y, REAL width, REAL height,
			const Graphics *graphics = NULL) const;
	BOOL IsVisible(INT x, INT y, INT width, INT height,
			const Graphics *graphics = NULL) const;
	BOOL IsVisible(const RectF& rect,
			const Graphics *graphics = NULL) const;
	BOOL IsVisible(const Rect& rect,
			const Graphics *graphics = NULL) const;
	Status MakeEmpty();
	Status MakeInfinite();
	Status Transform(const Matrix *matrix);
	Status Translate(REAL dx, REAL dy);
	Status Translate(INT dx, INT dy);
	Status Union(const RectF& rect);
	Status Union(const Rect& rect);
	Status Union(const Region *region);
	Status Union(const GraphicsPath *path);
	Status Xor(const RectF& rect);
	Status Xor(const Rect& rect);
	Status Xor(const Region *region);
	Status Xor(const GraphicsPath *path);

	Status GetLastStatus() const
	{
		Status result = lastStatus;
		lastStatus = Ok;
		return result;
	}

private:
	Region(GpRegion *region, Status status):
		nativeRegion(region), lastStatus(status) {}
	Region(const Region&);
	Region& operator=(const Region&);

	Status updateStatus(Status newStatus) const
	{
		if (newStatus != Ok) lastStatus = newStatus;
		return newStatus;
	}

	GpRegion *nativeRegion;
	mutable Status lastStatus;
};

#endif /* __GDIPLUS_HEADERS_H */
