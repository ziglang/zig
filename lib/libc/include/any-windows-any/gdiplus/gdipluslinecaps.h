/*
 * gdipluslinecaps.h
 *
 * GDI+ AdjustableArrowCap class
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

#ifndef __GDIPLUS_LINECAPS_H
#define __GDIPLUS_LINECAPS_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

#ifndef __cplusplus
#error "A C++ compiler is required to include gdipluslinecaps.h."
#endif

class AdjustableArrowCap: public CustomLineCap
{
public:
	AdjustableArrowCap(REAL height, REAL width, BOOL isFilled):
		CustomLineCap(NULL, Ok)
	{
		GpAdjustableArrowCap *nativeAdjustableArrowCap = NULL;
		lastStatus = DllExports::GdipCreateAdjustableArrowCap(
				height, width, isFilled,
				&nativeAdjustableArrowCap);
		nativeCustomLineCap = nativeAdjustableArrowCap;
	}
	virtual ~AdjustableArrowCap()
	{
	}
	virtual AdjustableArrowCap* Clone() const
	{
		GpCustomLineCap *cloneCustomLineCap = NULL;
		Status status = updateStatus(DllExports::GdipCloneCustomLineCap(
				nativeCustomLineCap, &cloneCustomLineCap));
		if (status == Ok) {
			AdjustableArrowCap *result = new AdjustableArrowCap(
					cloneCustomLineCap, lastStatus);
			if (!result) {
				DllExports::GdipDeleteCustomLineCap(
						cloneCustomLineCap);
				lastStatus = OutOfMemory;
			}
			return result;
		} else {
			return NULL;
		}
	}

	REAL GetHeight() const
	{
		REAL result = 0.0f;
		updateStatus(DllExports::GdipGetAdjustableArrowCapHeight(
				(GpAdjustableArrowCap*) nativeCustomLineCap,
				&result));
		return result;
	}
	REAL GetMiddleInset() const
	{
		REAL result = 0.0f;
		updateStatus(DllExports::GdipGetAdjustableArrowCapMiddleInset(
				(GpAdjustableArrowCap*) nativeCustomLineCap,
				&result));
		return result;
	}
	REAL GetWidth() const
	{
		REAL result = 0.0f;
		updateStatus(DllExports::GdipGetAdjustableArrowCapWidth(
				(GpAdjustableArrowCap*) nativeCustomLineCap,
				&result));
		return result;
	}
	BOOL IsFilled() const
	{
		BOOL result = FALSE;
		updateStatus(DllExports::GdipGetAdjustableArrowCapFillState(
				(GpAdjustableArrowCap*) nativeCustomLineCap,
				&result));
		return result;
	}
	Status SetFillState(BOOL isFilled)
	{
		return updateStatus(DllExports::GdipSetAdjustableArrowCapFillState(
				(GpAdjustableArrowCap*) nativeCustomLineCap,
				isFilled));
	}
	Status SetHeight(REAL height)
	{
		return updateStatus(DllExports::GdipSetAdjustableArrowCapHeight(
				(GpAdjustableArrowCap*) nativeCustomLineCap,
				height));
	}
	Status SetMiddleInset(REAL middleInset)
	{
		return updateStatus(DllExports::GdipSetAdjustableArrowCapMiddleInset(
				(GpAdjustableArrowCap*) nativeCustomLineCap,
				middleInset));
	}
	Status SetWidth(REAL width)
	{
		return updateStatus(DllExports::GdipSetAdjustableArrowCapWidth(
				(GpAdjustableArrowCap*) nativeCustomLineCap,
				width));
	}

private:
	AdjustableArrowCap(GpCustomLineCap *customLineCap, Status status):
		CustomLineCap(customLineCap, status) {}
	AdjustableArrowCap(const AdjustableArrowCap&);
	AdjustableArrowCap& operator=(const AdjustableArrowCap&);
};

#endif /* __GDIPLUS_LINECAPS_H */
