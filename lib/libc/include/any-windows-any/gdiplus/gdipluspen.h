/*
 * gdipluspen.h
 *
 * GDI+ Pen class
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

#ifndef __GDIPLUS_PEN_H
#define __GDIPLUS_PEN_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

#ifndef __cplusplus
#error "A C++ compiler is required to include gdipluspen.h."
#endif

class Pen: public GdiplusBase
{
	friend class Graphics;
	friend class GraphicsPath;

public:
	Pen(const Color& color, REAL width = 1.0f):
		nativePen(NULL), lastStatus(Ok)
	{
		lastStatus = DllExports::GdipCreatePen1(
				color.GetValue(), width, UnitWorld,
				&nativePen);
	}
	Pen(const Brush *brush, REAL width = 1.0f):
		nativePen(NULL), lastStatus(Ok)
	{
		lastStatus = DllExports::GdipCreatePen2(
				brush ? brush->nativeBrush : NULL,
				width, UnitWorld, &nativePen);
	}
	~Pen()
	{
		DllExports::GdipDeletePen(nativePen);
	}
	Pen* Clone() const
	{
		GpPen *clonePen = NULL;
		Status status = updateStatus(DllExports::GdipClonePen(
				nativePen, &clonePen));
		if (status == Ok) {
			Pen *result = new Pen(clonePen, lastStatus);
			if (!result) {
				DllExports::GdipDeletePen(clonePen);
				lastStatus = OutOfMemory;
			}
			return result;
		} else {
			return NULL;
		}
	}

	PenAlignment GetAlignment() const
	{
		PenAlignment result = PenAlignmentCenter;
		updateStatus(DllExports::GdipGetPenMode(nativePen, &result));
		return result;
	}
	// TODO: implement Pen::GetBrush()
	//Brush *GetBrush() const
	//{
	//	// where is the pen brush allocated (static,member,new,other)?
	//	// GdipGetPenBrushFill just returns a GpBrush*
	//	updateStatus(NotImplemented);
	//	return NULL;
	//}
	Status GetColor(Color *color) const
	{
		return updateStatus(DllExports::GdipGetPenColor(
				nativePen, color ? &color->Value : NULL));
	}
	Status GetCompoundArray(REAL *compoundArray, INT count) const
	{
		return updateStatus(DllExports::GdipGetPenCompoundArray(
				nativePen, compoundArray, count));
	}
	INT GetCompoundArrayCount() const
	{
		INT result = 0;
		updateStatus(DllExports::GdipGetPenCompoundCount(
				nativePen, &result));
		return result;
	}
	Status GetCustomEndCap(CustomLineCap *customCap) const
	{
		if (!customCap) return lastStatus = InvalidParameter;
		// FIXME: do we need to call GdipDeleteCustomLineCap first?
		return updateStatus(DllExports::GdipGetPenCustomEndCap(
				nativePen, &customCap->nativeCustomLineCap));
	}
	Status GetCustomStartCap(CustomLineCap *customCap) const
	{
		if (!customCap) return lastStatus = InvalidParameter;
		// FIXME: do we need to call GdipDeleteCustomLineCap first?
		return updateStatus(DllExports::GdipGetPenCustomStartCap(
				nativePen, &customCap->nativeCustomLineCap));
	}
	DashCap GetDashCap() const
	{
		DashCap result = DashCapFlat;
		updateStatus(DllExports::GdipGetPenDashCap197819(
				nativePen, &result));
		return result;
	}
	REAL GetDashOffset() const
	{
		REAL result = 0.0f;
		updateStatus(DllExports::GdipGetPenDashOffset(
				nativePen, &result));
		return result;
	}
	Status GetDashPattern(REAL *dashArray, INT count) const
	{
		return updateStatus(DllExports::GdipGetPenDashArray(
				nativePen, dashArray, count));
	}
	INT GetDashPatternCount() const
	{
		INT result = 0;
		updateStatus(DllExports::GdipGetPenDashCount(
				nativePen, &result));
		return result;
	}
	DashStyle GetDashStyle() const
	{
		DashStyle result = DashStyleSolid;
		updateStatus(DllExports::GdipGetPenDashStyle(
				nativePen, &result));
		return result;
	}
	LineCap GetEndCap() const
	{
		LineCap result = LineCapFlat;
		updateStatus(DllExports::GdipGetPenEndCap(nativePen, &result));
		return result;
	}
	Status GetLastStatus() const
	{
		Status result = lastStatus;
		lastStatus = Ok;
		return result;
	}
	LineJoin GetLineJoin() const
	{
		LineJoin result = LineJoinMiter;
		updateStatus(DllExports::GdipGetPenLineJoin(
				nativePen, &result));
		return result;
	}
	REAL GetMiterLimit() const
	{
		REAL result = 10.0f;
		updateStatus(DllExports::GdipGetPenMiterLimit(
				nativePen, &result));
		return result;
	}
	PenType GetPenType() const
	{
		PenType result = PenTypeUnknown;
		updateStatus(DllExports::GdipGetPenFillType(
				nativePen, &result));
		return result;
	}
	LineCap GetStartCap() const
	{
		LineCap result = LineCapFlat;
		updateStatus(DllExports::GdipGetPenStartCap(
				nativePen, &result));
		return result;
	}
	Status GetTransform(Matrix *matrix) const
	{
		return updateStatus(DllExports::GdipGetPenTransform(
				nativePen,
				matrix ? matrix->nativeMatrix : NULL));
	}
	REAL GetWidth() const
	{
		REAL result = 1.0f;
		updateStatus(DllExports::GdipGetPenWidth(nativePen, &result));
		return result;
	}
	Status MultiplyTransform(const Matrix *matrix,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipMultiplyPenTransform(
				nativePen,
				matrix ? matrix->nativeMatrix : NULL, order));
	}
	Status ResetTransform()
	{
		return updateStatus(DllExports::GdipResetPenTransform(
				nativePen));
	}
	Status RotateTransform(REAL angle,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipRotatePenTransform(
				nativePen, angle, order));
	}
	Status ScaleTransform(REAL sx, REAL sy,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipScalePenTransform(
				nativePen, sx, sy, order));
	}
	Status SetAlignment(PenAlignment penAlignment)
	{
		return updateStatus(DllExports::GdipSetPenMode(
				nativePen, penAlignment));
	}
	Status SetBrush(const Brush *brush)
	{
		return updateStatus(DllExports::GdipSetPenBrushFill(
				nativePen, brush ? brush->nativeBrush : NULL));
	}
	Status SetColor(const Color& color)
	{
		return updateStatus(DllExports::GdipSetPenColor(
				nativePen, color.GetValue()));
	}
	Status SetCompoundArray(const REAL *compoundArray, INT count)
	{
		return updateStatus(DllExports::GdipSetPenCompoundArray(
				nativePen, compoundArray, count));
	}
	Status SetCustomEndCap(const CustomLineCap *customCap)
	{
		return updateStatus(DllExports::GdipSetPenCustomEndCap(
				nativePen,
				customCap ? customCap->nativeCustomLineCap : NULL));
	}
	Status SetCustomStartCap(const CustomLineCap *customCap)
	{
		return updateStatus(DllExports::GdipSetPenCustomStartCap(
				nativePen,
				customCap ? customCap->nativeCustomLineCap : NULL));
	}
	Status SetDashCap(DashCap dashCap)
	{
		return updateStatus(DllExports::GdipSetPenDashCap197819(
				nativePen, dashCap));
	}
	Status SetDashOffset(REAL dashOffset)
	{
		return updateStatus(DllExports::GdipSetPenDashOffset(
				nativePen, dashOffset));
	}
	Status SetDashPattern(const REAL *dashArray, INT count)
	{
		return updateStatus(DllExports::GdipSetPenDashArray(
				nativePen, dashArray, count));
	}
	Status SetDashStyle(DashStyle dashStyle)
	{
		return updateStatus(DllExports::GdipSetPenDashStyle(
				nativePen, dashStyle));
	}
	Status SetEndCap(LineCap endCap)
	{
		return updateStatus(DllExports::GdipSetPenEndCap(
				nativePen, endCap));
	}
	Status SetLineCap(LineCap startCap, LineCap endCap, DashCap dashCap)
	{
		return updateStatus(DllExports::GdipSetPenLineCap197819(
				nativePen, startCap, endCap, dashCap));
	}
	Status SetLineJoin(LineJoin lineJoin)
	{
		return updateStatus(DllExports::GdipSetPenLineJoin(
				nativePen, lineJoin));
	}
	Status SetMiterLimit(REAL miterLimit)
	{
		return updateStatus(DllExports::GdipSetPenMiterLimit(
				nativePen, miterLimit));
	}
	Status SetStartCap(LineCap startCap)
	{
		return updateStatus(DllExports::GdipSetPenStartCap(
				nativePen, startCap));
	}
	Status SetTransform(const Matrix *matrix)
	{
		return updateStatus(DllExports::GdipSetPenTransform(
				nativePen,
				matrix ? matrix->nativeMatrix : NULL));
	}
	Status SetWidth(REAL width)
	{
		return updateStatus(DllExports::GdipSetPenWidth(
				nativePen, width));
	}
	Status TranslateTransform(REAL dx, REAL dy,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipTranslatePenTransform(
				nativePen, dx, dy, order));
	}

private:
	Pen(GpPen *pen, Status status): nativePen(pen), lastStatus(status) {}
	Pen(const Pen& pen);
	Pen& operator=(const Pen&);

	Status updateStatus(Status newStatus) const
	{
		if (newStatus != Ok) lastStatus = newStatus;
		return newStatus;
	}

	GpPen *nativePen;
	mutable Status lastStatus;
};

#endif /* __GDIPLUS_PEN_H */
