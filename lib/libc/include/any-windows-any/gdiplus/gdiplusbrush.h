/*
 * gdiplusbrush.h
 *
 * GDI+ brush classes
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

#ifndef __GDIPLUS_BRUSH_H
#define __GDIPLUS_BRUSH_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

#ifndef __cplusplus
#error "A C++ compiler is required to include gdiplusbrush.h."
#endif

class Brush: public GdiplusBase
{
	friend class HatchBrush;
	friend class LinearGradientBrush;
	friend class PathGradientBrush;
	friend class SolidBrush;
	friend class TextureBrush;
	friend class Graphics;
	friend class Pen;

public:
	virtual ~Brush()
	{
		DllExports::GdipDeleteBrush(nativeBrush);
	}
	virtual Brush* Clone() const  // each subclass must implement this
	{
		lastStatus = NotImplemented;
		return NULL;
	}

	Status GetLastStatus() const
	{
		Status result = lastStatus;
		lastStatus = Ok;
		return result;
	}
	BrushType GetType() const
	{
		BrushType result = BrushTypeSolidColor;
		updateStatus(DllExports::GdipGetBrushType(nativeBrush, &result));
		return result;  
	}

private:
	Brush(): nativeBrush(NULL), lastStatus(Ok) {}
	Brush(GpBrush *brush, Status status):
		nativeBrush(brush), lastStatus(status) {}
	Brush(const Brush& brush);
	Brush& operator=(const Brush&);

	Status updateStatus(Status newStatus) const
	{
		if (newStatus != Ok) lastStatus = newStatus;
		return newStatus;
	}

	GpBrush *nativeBrush;
	mutable Status lastStatus;
};

class HatchBrush: public Brush
{
public:
	HatchBrush(HatchStyle hatchStyle,
			const Color& foreColor,
			const Color& backColor = Color())
	{
		GpHatch *nativeHatch = NULL;
		lastStatus = DllExports::GdipCreateHatchBrush(hatchStyle,
				foreColor.GetValue(), backColor.GetValue(),
				&nativeHatch);
		nativeBrush = nativeHatch; 
	}
	virtual HatchBrush* Clone() const
	{
		GpBrush *cloneBrush = NULL;
		Status status = updateStatus(DllExports::GdipCloneBrush(
				nativeBrush, &cloneBrush));
		if (status == Ok) {
			HatchBrush *result =
				new HatchBrush(cloneBrush, lastStatus);
			if (!result) {
				DllExports::GdipDeleteBrush(cloneBrush);
				updateStatus(OutOfMemory);
			}
			return result;
		} else {
			return NULL;
		}
	}

	Status GetBackgroundColor(Color *color) const
	{
		return updateStatus(DllExports::GdipGetHatchBackgroundColor(
				(GpHatch*) nativeBrush,
				color ? &color->Value : NULL));
	}
	Status GetForegroundColor(Color *color) const
	{
		return updateStatus(DllExports::GdipGetHatchForegroundColor(
				(GpHatch*) nativeBrush,
				color ? &color->Value : NULL));
	}
	HatchStyle GetHatchStyle() const
	{
		HatchStyle result;
		updateStatus(DllExports::GdipGetHatchStyle(
				(GpHatch*) nativeBrush, &result));
		return result;
	}

private:
	HatchBrush(GpBrush *brush, Status status): Brush(brush, status) {}
	HatchBrush(const HatchBrush& brush);
	HatchBrush& operator=(const HatchBrush&);
};

class LinearGradientBrush: public Brush
{
public:
	LinearGradientBrush(const PointF& point1, const PointF& point2,
			const Color& color1, const Color& color2)
	{
		GpLineGradient *nativeLineGradient = NULL;
		lastStatus = DllExports::GdipCreateLineBrush(
				&point1, &point2,
				color1.GetValue(), color2.GetValue(),
				WrapModeTile, &nativeLineGradient);
		nativeBrush = nativeLineGradient;
	}
	LinearGradientBrush(const Point& point1, const Point& point2,
			const Color& color1, const Color& color2)
	{
		GpLineGradient *nativeLineGradient = NULL;
		lastStatus = DllExports::GdipCreateLineBrushI(
				&point1, &point2,
				color1.GetValue(), color2.GetValue(),
				WrapModeTile, &nativeLineGradient);
		nativeBrush = nativeLineGradient;
	}
	LinearGradientBrush(const RectF& rect, const Color& color1,
			const Color& color2, LinearGradientMode mode)
	{
		GpLineGradient *nativeLineGradient = NULL;
		lastStatus = DllExports::GdipCreateLineBrushFromRect(
				&rect, color1.GetValue(), color2.GetValue(),
				mode, WrapModeTile, &nativeLineGradient);
		nativeBrush = nativeLineGradient;
	}
	LinearGradientBrush(const Rect& rect, const Color& color1,
			const Color& color2, LinearGradientMode mode)
	{
		GpLineGradient *nativeLineGradient = NULL;
		lastStatus = DllExports::GdipCreateLineBrushFromRectI(
				&rect, color1.GetValue(), color2.GetValue(),
				mode, WrapModeTile, &nativeLineGradient);
		nativeBrush = nativeLineGradient;
	}
	LinearGradientBrush(const RectF& rect, const Color& color1,
			const Color& color2, REAL angle,
			BOOL isAngleScalable = FALSE)
	{
		GpLineGradient *nativeLineGradient = NULL;
		lastStatus = DllExports::GdipCreateLineBrushFromRectWithAngle(
				&rect, color1.GetValue(), color2.GetValue(),
				angle, isAngleScalable, WrapModeTile,
				&nativeLineGradient);
		nativeBrush = nativeLineGradient;
	}
	LinearGradientBrush(const Rect& rect, const Color& color1,
			const Color& color2, REAL angle,
			BOOL isAngleScalable = FALSE)
	{
		GpLineGradient *nativeLineGradient = NULL;
		lastStatus = DllExports::GdipCreateLineBrushFromRectWithAngleI(
				&rect, color1.GetValue(), color2.GetValue(),
				angle, isAngleScalable, WrapModeTile,
				&nativeLineGradient);
		nativeBrush = nativeLineGradient;
	}
	virtual LinearGradientBrush* Clone() const
	{
		GpBrush *cloneBrush = NULL;
		Status status = updateStatus(DllExports::GdipCloneBrush(
				nativeBrush, &cloneBrush));
		if (status == Ok) {
			LinearGradientBrush *result =
				new LinearGradientBrush(cloneBrush, lastStatus);
			if (!result) {
				DllExports::GdipDeleteBrush(cloneBrush);
				updateStatus(OutOfMemory);
			}
			return result;
		} else {
			return NULL;
		}
	}

	Status GetBlend(REAL *blendFactors, REAL *blendPositions,
			INT count) const
	{
		return updateStatus(DllExports::GdipGetLineBlend(
				(GpLineGradient*) nativeBrush,
				blendFactors, blendPositions, count));
	}
	INT GetBlendCount() const
	{
		INT result = 0;
		updateStatus(DllExports::GdipGetLineBlendCount(
				(GpLineGradient*) nativeBrush, &result));
		return result;
	}
	BOOL GetGammaCorrection() const
	{
		BOOL result = FALSE;
		updateStatus(DllExports::GdipGetLineGammaCorrection(
				(GpLineGradient*) nativeBrush, &result));
		return result;
	}
	INT GetInterpolationColorCount() const
	{
		INT result = 0;
		updateStatus(DllExports::GdipGetLinePresetBlendCount(
				(GpLineGradient*) nativeBrush, &result));
		return result;
	}
	Status GetInterpolationColors(Color *presetColors,
			REAL *blendPositions, INT count) const
	{
		if (!presetColors || count <= 0)
			return lastStatus = InvalidParameter;

		ARGB *presetArgb =
			(ARGB*) DllExports::GdipAlloc(count * sizeof(ARGB));
		if (!presetArgb)
			return lastStatus = OutOfMemory;

		Status status = updateStatus(DllExports::GdipGetLinePresetBlend(
				(GpLineGradient*) nativeBrush, presetArgb,
				blendPositions, count));
		for (INT i = 0; i < count; ++i) {
			presetColors[i].SetValue(presetArgb[i]);
		}
		DllExports::GdipFree((void*) presetArgb);
		return status;
	}
	Status GetLinearColors(Color *colors) const
	{
		if (!colors) return lastStatus = InvalidParameter;

		ARGB colorsArgb[2];
		Status status = updateStatus(DllExports::GdipGetLineColors(
				(GpLineGradient*) nativeBrush, colorsArgb));
		colors[0].SetValue(colorsArgb[0]);
		colors[1].SetValue(colorsArgb[1]);
		return status;
	}
	Status GetRectangle(RectF *rect) const
	{
		return updateStatus(DllExports::GdipGetLineRect(
				(GpLineGradient*) nativeBrush, rect));
	}
	Status GetRectangle(Rect *rect) const
	{
		return updateStatus(DllExports::GdipGetLineRectI(
				(GpLineGradient*) nativeBrush, rect));
	}
	Status GetTransform(Matrix *matrix) const
	{
		return updateStatus(DllExports::GdipGetLineTransform(
				(GpLineGradient*) nativeBrush,
				matrix ? matrix->nativeMatrix : NULL));
	}
	WrapMode GetWrapMode() const
	{
		WrapMode wrapMode = WrapModeTile;
		updateStatus(DllExports::GdipGetLineWrapMode(
				(GpLineGradient*) nativeBrush, &wrapMode));
		return wrapMode;
	}
	Status MultiplyTransform(const Matrix *matrix,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipMultiplyLineTransform(
				(GpLineGradient*) nativeBrush,
				matrix ? matrix->nativeMatrix : NULL, order));
	}
	Status ResetTransform()
	{
		return updateStatus(DllExports::GdipResetLineTransform(
				(GpLineGradient*) nativeBrush));
	}
	Status RotateTranform(REAL angle, MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipRotateLineTransform(
				(GpLineGradient*) nativeBrush, angle, order));
	}
	Status ScaleTransform(REAL sx, REAL sy,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipScaleLineTransform(
				(GpLineGradient*) nativeBrush, sx, sy, order));
	}
	Status SetBlend(const REAL *blendFactors,
			const REAL *blendPositions, INT count)
	{
		return updateStatus(DllExports::GdipSetLineBlend(
				(GpLineGradient*) nativeBrush,
				blendFactors, blendPositions, count));
	}
	Status SetBlendBellShape(REAL focus, REAL scale = 1.0f)
	{
		return updateStatus(DllExports::GdipSetLineSigmaBlend(
				(GpLineGradient*) nativeBrush,
				focus, scale));
	}
	Status SetBlendTriangularShape(REAL focus, REAL scale = 1.0f)
	{
		return updateStatus(DllExports::GdipSetLineLinearBlend(
				(GpLineGradient*) nativeBrush,
				focus, scale));
	}
	Status SetGammaCorrection(BOOL useGammaCorrection)
	{
		return updateStatus(DllExports::GdipSetLineGammaCorrection(
				(GpLineGradient*) nativeBrush,
				useGammaCorrection));
	}
	Status SetInterpolationColors(const Color *presetColors,
			const REAL *blendPositions, INT count)
	{
		if (!presetColors || count < 0)
			return lastStatus = InvalidParameter;

		ARGB *presetArgb =
			(ARGB*) DllExports::GdipAlloc(count * sizeof(ARGB));
		if (!presetArgb)
			return lastStatus = OutOfMemory;
		for (INT i = 0; i < count; ++i) {
			presetArgb[i] = presetColors[i].GetValue();
		}

		Status status = updateStatus(DllExports::GdipSetLinePresetBlend(
				(GpLineGradient*) nativeBrush,
				presetArgb, blendPositions, count));
		DllExports::GdipFree((void*) presetArgb);
		return status;
	}
	Status SetLinearColors(const Color& color1, const Color& color2)
	{
		return updateStatus(DllExports::GdipSetLineColors(
				(GpLineGradient*) nativeBrush,
				color1.GetValue(), color2.GetValue()));
	}
	Status SetTransform(const Matrix *matrix)
	{
		return updateStatus(DllExports::GdipSetLineTransform(
				(GpLineGradient*) nativeBrush,
				matrix ? matrix->nativeMatrix : NULL));
	}
	Status SetWrapMode(WrapMode wrapMode)
	{
		return updateStatus(DllExports::GdipSetLineWrapMode(
				(GpLineGradient*) nativeBrush, wrapMode));
	}
	Status TranslateTransform(REAL dx, REAL dy,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipTranslateLineTransform(
				(GpLineGradient*) nativeBrush, dx, dy, order));
	}

private:
	LinearGradientBrush(GpBrush *brush, Status status): Brush(brush, status) {}
	LinearGradientBrush(const LinearGradientBrush& brush);
	LinearGradientBrush& operator=(const LinearGradientBrush&);
};

class SolidBrush: public Brush
{
public:
	SolidBrush(const Color& color)
	{
		GpSolidFill *nativeSolidFill = NULL;
		lastStatus = DllExports::GdipCreateSolidFill(
				color.GetValue(), &nativeSolidFill);
		nativeBrush = nativeSolidFill; 
	}
	virtual SolidBrush* Clone() const
	{
		GpBrush *cloneBrush = NULL;
		Status status = updateStatus(DllExports::GdipCloneBrush(
				nativeBrush, &cloneBrush));
		if (status == Ok) {
			SolidBrush *result =
				new SolidBrush(cloneBrush, lastStatus);
			if (!result) {
				DllExports::GdipDeleteBrush(cloneBrush);
				updateStatus(OutOfMemory);
			}
			return result;
		} else {
			return NULL;
		}
	}

	Status GetColor(Color *color) const
	{
		return updateStatus(DllExports::GdipGetSolidFillColor(
				(GpSolidFill*) nativeBrush,
				color ? &color->Value : NULL));
	}
	Status SetColor(const Color& color)
	{
		return updateStatus(DllExports::GdipSetSolidFillColor(
				(GpSolidFill*) nativeBrush, color.GetValue()));
	}

private:
	SolidBrush(GpBrush *brush, Status status): Brush(brush, status) {}
	SolidBrush(const SolidBrush&);
	SolidBrush& operator=(const SolidBrush&);
};

class TextureBrush: public Brush
{
public:
	TextureBrush(Image *image, WrapMode wrapMode = WrapModeTile)
	{
		GpTexture *nativeTexture = NULL;
		lastStatus = DllExports::GdipCreateTexture(
				image ? image->nativeImage : NULL,
				wrapMode, &nativeTexture);
		nativeBrush = nativeTexture;
	}
	TextureBrush(Image *image, WrapMode wrapMode,
			REAL dstX, REAL dstY, REAL dstWidth, REAL dstHeight)
	{
		GpTexture *nativeTexture = NULL;
		lastStatus = DllExports::GdipCreateTexture2(
				image ? image->nativeImage : NULL,
				wrapMode, dstX, dstY, dstWidth, dstHeight,
				&nativeTexture);
		nativeBrush = nativeTexture;
	}
	TextureBrush(Image *image, WrapMode wrapMode,
			INT dstX, INT dstY, INT dstWidth, INT dstHeight)
	{
		GpTexture *nativeTexture = NULL;
		lastStatus = DllExports::GdipCreateTexture2I(
				image ? image->nativeImage : NULL,
				wrapMode, dstX, dstY, dstWidth, dstHeight,
				&nativeTexture);
		nativeBrush = nativeTexture;
	}
	TextureBrush(Image *image, WrapMode wrapMode, const RectF& dstRect)
	{
		GpTexture *nativeTexture = NULL;
		lastStatus = DllExports::GdipCreateTexture2(
				image ? image->nativeImage : NULL, wrapMode,
				dstRect.X, dstRect.Y,
				dstRect.Width, dstRect.Height, &nativeTexture);
		nativeBrush = nativeTexture;
	}
	TextureBrush(Image *image, WrapMode wrapMode, const Rect& dstRect)
	{
		GpTexture *nativeTexture = NULL;
		lastStatus = DllExports::GdipCreateTexture2I(
				image ? image->nativeImage : NULL, wrapMode,
				dstRect.X, dstRect.Y,
				dstRect.Width, dstRect.Height, &nativeTexture);
		nativeBrush = nativeTexture;
	}
	TextureBrush(Image *image, const RectF& dstRect,
			ImageAttributes *imageAttributes = NULL)
	{
		GpTexture *nativeTexture = NULL;
		lastStatus = DllExports::GdipCreateTextureIA(
				image ? image->nativeImage : NULL,
				imageAttributes ? imageAttributes->nativeImageAttributes : NULL,
				dstRect.X, dstRect.Y,
				dstRect.Width, dstRect.Height, &nativeTexture);
		nativeBrush = nativeTexture;
	}
	TextureBrush(Image *image, const Rect& dstRect,
			ImageAttributes *imageAttributes = NULL)
	{
		GpTexture *nativeTexture = NULL;
		lastStatus = DllExports::GdipCreateTextureIAI(
				image ? image->nativeImage : NULL,
				imageAttributes ? imageAttributes->nativeImageAttributes : NULL,
				dstRect.X, dstRect.Y,
				dstRect.Width, dstRect.Height, &nativeTexture);
		nativeBrush = nativeTexture;
	}
	virtual TextureBrush* Clone() const
	{
		GpBrush *cloneBrush = NULL;
		Status status = updateStatus(DllExports::GdipCloneBrush(
				nativeBrush, &cloneBrush));
		if (status == Ok) {
			TextureBrush *result =
				new TextureBrush(cloneBrush, lastStatus);
			if (!result) {
				DllExports::GdipDeleteBrush(cloneBrush);
				updateStatus(OutOfMemory);
			}
			return result;
		} else {
			return NULL;
		}
	}

	//TODO: implement TextureBrush::GetImage()
	//Image *GetImage() const
	//{
	//	// where is the Image allocated (static,member,new,other)?
	//	// GdipGetTextureImage just returns a GpImage*
	//	updateStatus(NotImplemented);
	//	return NULL;
	//}
	Status GetTransfrom(Matrix *matrix) const
	{
		return updateStatus(DllExports::GdipGetTextureTransform(
				(GpTexture*) nativeBrush,
				matrix ? matrix->nativeMatrix : NULL));
	}
	WrapMode GetWrapMode() const
	{
		WrapMode result = WrapModeTile;
		updateStatus(DllExports::GdipGetTextureWrapMode(
				(GpTexture*) nativeBrush, &result));
		return result;
	}
	Status MultiplyTransform(const Matrix *matrix,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipMultiplyTextureTransform(
				(GpTexture*) nativeBrush,
				matrix ? matrix->nativeMatrix : NULL, order));
	}
	Status ResetTransform()
	{
		return updateStatus(DllExports::GdipResetTextureTransform(
				(GpTexture*) nativeBrush));
	}
	Status RotateTransform(REAL angle,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipRotateTextureTransform(
				(GpTexture*) nativeBrush, angle, order));
	}
	Status ScaleTransform(REAL sx, REAL sy,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipScaleTextureTransform(
				(GpTexture*) nativeBrush, sx, sy, order));
	}
	Status SetTransform(const Matrix *matrix)
	{
		return updateStatus(DllExports::GdipSetTextureTransform(
				(GpTexture*) nativeBrush,
				matrix ? matrix->nativeMatrix : NULL));
	}
	Status SetWrapMode(WrapMode wrapMode)
	{
		return updateStatus(DllExports::GdipSetTextureWrapMode(
				(GpTexture*) nativeBrush, wrapMode));
	}
	Status TranslateTransform(REAL dx, REAL dy,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipTranslateTextureTransform(
				(GpTexture*) nativeBrush, dx, dy, order));
	}

private:
	TextureBrush(GpBrush *brush, Status status): Brush(brush, status) {}
	TextureBrush(const TextureBrush&);
	TextureBrush& operator=(const TextureBrush&);
};

#endif /* __GDIPLUS_BRUSH_H */
