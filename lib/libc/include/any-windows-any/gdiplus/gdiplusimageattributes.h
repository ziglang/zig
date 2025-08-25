/*
 * gdiplusimageattributes.h
 *
 * GDI+ ImageAttributes class
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

#ifndef __GDIPLUS_IMAGEATTRIBUTES_H
#define __GDIPLUS_IMAGEATTRIBUTES_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

#ifndef __cplusplus
#error "A C++ compiler is required to include gdiplusimageattributes.h."
#endif

class ImageAttributes: public GdiplusBase
{
	friend class Graphics;
	friend class TextureBrush;

public:
	ImageAttributes(): nativeImageAttributes(NULL), lastStatus(Ok)
	{
		lastStatus = DllExports::GdipCreateImageAttributes(
				&nativeImageAttributes);
	}
	~ImageAttributes()
	{
		DllExports::GdipDisposeImageAttributes(nativeImageAttributes);
	}
	ImageAttributes* Clone() const
	{
		GpImageAttributes *cloneImageAttributes = NULL;
		Status status = updateStatus(DllExports::GdipCloneImageAttributes(
				nativeImageAttributes, &cloneImageAttributes));
		if (status == Ok) {
			ImageAttributes *result = new ImageAttributes(
					cloneImageAttributes, lastStatus);
			if (!result) {
				DllExports::GdipDisposeImageAttributes(cloneImageAttributes);
				lastStatus = OutOfMemory;
			}
			return result;
		} else {
			return NULL;
		}
	}

	Status ClearBrushRemapTable()
	{
		return updateStatus(DllExports::GdipSetImageAttributesRemapTable(
				nativeImageAttributes, ColorAdjustTypeBrush,
				FALSE, 0, NULL));
	}
	Status ClearColorKey(ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesColorKeys(
				nativeImageAttributes, type, FALSE, 0, 0));
	}
	Status ClearColorMatrices(ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesColorMatrix(
				nativeImageAttributes, type, FALSE,
				NULL, NULL, ColorMatrixFlagsDefault));
	}
	Status ClearColorMatrix(ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesColorMatrix(
				nativeImageAttributes, type, FALSE,
				NULL, NULL, ColorMatrixFlagsDefault));
	}
	Status ClearGamma(ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesGamma(
				nativeImageAttributes, type, FALSE, 1.0f));
	}
	Status ClearNoOp(ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesNoOp(
				nativeImageAttributes, type, FALSE));
	}
	Status ClearOutputChannel(ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesOutputChannel(
				nativeImageAttributes, type, FALSE,
				ColorChannelFlagsC));
	}
	Status ClearOutputChannelColorProfile(
			ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesOutputChannelColorProfile(
				nativeImageAttributes, type, FALSE, NULL));
	}
	Status ClearRemapTable(ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesRemapTable(
				nativeImageAttributes, type, FALSE, 0, NULL));
	}
	Status ClearThreshold(ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesThreshold(
				nativeImageAttributes, type, FALSE, 0.0));
	}
	Status GetAdjustedPalette(ColorPalette *colorPalette,
			ColorAdjustType type) const
	{
		return updateStatus(DllExports::GdipGetImageAttributesAdjustedPalette(
				nativeImageAttributes, colorPalette, type));
	}
	Status GetLastStatus() const
	{
		Status result = lastStatus;
		lastStatus = Ok;
		return result;
	}
	Status Reset(ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipResetImageAttributes(
				nativeImageAttributes, type));
	}
	Status SetBrushRemapTable(UINT mapSize, ColorMap *map)
	{
		return updateStatus(DllExports::GdipSetImageAttributesRemapTable(
				nativeImageAttributes, ColorAdjustTypeBrush,
				TRUE, mapSize, map));
	}
	Status SetColorKey(const Color& colorLow, const Color& colorHigh,
			ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesColorKeys(
				nativeImageAttributes, type, TRUE,
				colorLow.GetValue(), colorHigh.GetValue()));
	}
	Status SetColorMatrices(const ColorMatrix *colorMatrix,
			const ColorMatrix *grayMatrix,
			ColorMatrixFlags mode = ColorMatrixFlagsDefault,
			ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesColorMatrix(
				nativeImageAttributes, type, TRUE,
				colorMatrix, grayMatrix, mode));
	}
	Status SetColorMatrix(const ColorMatrix *colorMatrix,
			ColorMatrixFlags mode = ColorMatrixFlagsDefault,
			ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesColorMatrix(
				nativeImageAttributes, type, TRUE,
				colorMatrix, NULL, mode));
	}
	Status SetGamma(REAL gamma,
			ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesGamma(
				nativeImageAttributes, type, TRUE, gamma));
	}
	Status SetNoOp(ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesNoOp(
				nativeImageAttributes, type, TRUE));
	}
	Status SetOutputChannel(ColorChannelFlags channelFlags,
			ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesOutputChannel(
				nativeImageAttributes, type, TRUE,
				channelFlags));
	}
	Status SetOutputChannelColorProfile(const WCHAR *colorProfileFilename,
			ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesOutputChannelColorProfile(
				nativeImageAttributes, type, TRUE,
				colorProfileFilename));
	}
	Status SetRemapTable(UINT mapSize, const ColorMap *map,
			ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesRemapTable(
				nativeImageAttributes, type, TRUE,
				mapSize, map));
	}
	Status SetThreshold(REAL threshold,
			ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesThreshold(
				nativeImageAttributes, type, TRUE, threshold));
	}
	Status SetToIdentity(ColorAdjustType type = ColorAdjustTypeDefault)
	{
		return updateStatus(DllExports::GdipSetImageAttributesToIdentity(
				nativeImageAttributes, type));
	}
	Status SetWrapMode(WrapMode wrap, const Color& color = Color(),
			BOOL clamp = FALSE)
	{
		return updateStatus(DllExports::GdipSetImageAttributesWrapMode(
				nativeImageAttributes, wrap,
				color.GetValue(), clamp));
	}

private:
	ImageAttributes(GpImageAttributes *imageAttributes, Status status):
		nativeImageAttributes(imageAttributes), lastStatus(status) {}
	ImageAttributes(const ImageAttributes&);
	ImageAttributes& operator=(const ImageAttributes&);

	Status updateStatus(Status newStatus) const
	{
		if (newStatus != Ok) lastStatus = newStatus;
		return newStatus;
	}

	GpImageAttributes *nativeImageAttributes;
	mutable Status lastStatus;
};


#endif /* __GDIPLUS_IMAGEATTRIBUTES_H */
