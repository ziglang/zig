/*
 * gdipluspath.h
 *
 * GDI+ GraphicsPath class
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

#ifndef __GDIPLUS_PATH_H
#define __GDIPLUS_PATH_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

#ifndef __cplusplus
#error "A C++ compiler is required to include gdipluspath.h."
#endif

// Note that some methods of GraphicsPath are implemented in gdiplusimpl.h.
// This avoids a cyclic dependency on Graphics and Pen.

class GraphicsPath: public GdiplusBase
{
	friend class CustomLineCap;
	friend class Graphics;
	friend class GraphicsPathIterator;
	friend class PathGradientBrush;
	friend class Region;

public:
	GraphicsPath(FillMode fillMode = FillModeAlternate):
			nativePath(NULL), lastStatus(Ok)
	{
		lastStatus = DllExports::GdipCreatePath(fillMode, &nativePath);
	}
	GraphicsPath(const PointF *points, const BYTE *types, INT count,
			FillMode fillMode = FillModeAlternate):
			nativePath(NULL), lastStatus(Ok)
	{
		lastStatus = DllExports::GdipCreatePath2(
				points, types, count, fillMode, &nativePath);
	}
	GraphicsPath(const Point *points, const BYTE *types, INT count,
			FillMode fillMode = FillModeAlternate):
			nativePath(NULL), lastStatus(Ok)
	{
		lastStatus = DllExports::GdipCreatePath2I(
				points, types, count, fillMode, &nativePath);
	}
	~GraphicsPath()
	{
		DllExports::GdipDeletePath(nativePath);
	}
	GraphicsPath* Clone() const
	{
		GpPath *clonePath = NULL;
		Status status = updateStatus(DllExports::GdipClonePath(
				nativePath, &clonePath));
		if (status == Ok) {
			GraphicsPath *result = new GraphicsPath(clonePath, lastStatus);
			if (!result) {
				DllExports::GdipDeletePath(clonePath);
				lastStatus = OutOfMemory;
			}
			return result;
		} else {
			return NULL;
		}
	}

	Status AddArc(REAL x, REAL y, REAL width, REAL height,
			REAL startAngle, REAL sweepAngle)
	{
		return updateStatus(DllExports::GdipAddPathArc(nativePath,
				x, y, width, height, startAngle, sweepAngle));
	}
	Status AddArc(INT x, INT y, INT width, INT height,
			REAL startAngle, REAL sweepAngle)
	{
		return updateStatus(DllExports::GdipAddPathArcI(nativePath,
				x, y, width, height, startAngle, sweepAngle));
	}
	Status AddArc(const RectF& rect, REAL startAngle, REAL sweepAngle)
	{
		return updateStatus(DllExports::GdipAddPathArc(nativePath,
				rect.X, rect.Y, rect.Width, rect.Height,
				startAngle, sweepAngle));
	}
	Status AddArc(const Rect& rect, REAL startAngle, REAL sweepAngle)
	{
		return updateStatus(DllExports::GdipAddPathArcI(nativePath,
				rect.X, rect.Y, rect.Width, rect.Height,
				startAngle, sweepAngle));
	}
	Status AddBezier(REAL x1, REAL y1, REAL x2, REAL y2,
			REAL x3, REAL y3, REAL x4, REAL y4)
	{
		return updateStatus(DllExports::GdipAddPathBezier(nativePath,
				x1, y1, x2, y2, x3, y3, x4, y4));
	}
	Status AddBezier(INT x1, INT y1, INT x2, INT y2,
			INT x3, INT y3, INT x4, INT y4)
	{
		return updateStatus(DllExports::GdipAddPathBezierI(nativePath,
				x1, y1, x2, y2, x3, y3, x4, y4));
	}
	Status AddBezier(const PointF& pt1, const PointF& pt2,
			const PointF& pt3, const PointF& pt4)
	{
		return updateStatus(DllExports::GdipAddPathBezier(nativePath,
				pt1.X, pt1.Y, pt2.X, pt2.Y,
				pt3.X, pt3.Y, pt4.X, pt4.Y));
	}
	Status AddBezier(const Point& pt1, const Point& pt2,
			const Point& pt3, const Point& pt4)
	{
		return updateStatus(DllExports::GdipAddPathBezierI(nativePath,
				pt1.X, pt1.Y, pt2.X, pt2.Y,
				pt3.X, pt3.Y, pt4.X, pt4.Y));
	}
	Status AddBeziers(const PointF *points, INT count)
	{
		return updateStatus(DllExports::GdipAddPathBeziers(
				nativePath, points, count));
	}
	Status AddBeziers(const Point *points, INT count)
	{
		return updateStatus(DllExports::GdipAddPathBeziersI(
				nativePath, points, count));
	}
	Status AddClosedCurve(const PointF *points, INT count)
	{
		return updateStatus(DllExports::GdipAddPathClosedCurve(
				nativePath, points, count));
	}
	Status AddClosedCurve(const Point *points, INT count)
	{
		return updateStatus(DllExports::GdipAddPathClosedCurveI(
				nativePath, points, count));
	}
	Status AddClosedCurve(const PointF *points, INT count, REAL tension)
	{
		return updateStatus(DllExports::GdipAddPathClosedCurve2(
				nativePath, points, count, tension));
	}
	Status AddClosedCurve(const Point *points, INT count, REAL tension)
	{
		return updateStatus(DllExports::GdipAddPathClosedCurve2I(
				nativePath, points, count, tension));
	}
	Status AddCurve(const PointF *points, INT count)
	{
		return updateStatus(DllExports::GdipAddPathCurve(
				nativePath, points, count));
	}
	Status AddCurve(const Point *points, INT count)
	{
		return updateStatus(DllExports::GdipAddPathCurveI(
				nativePath, points, count));
	}
	Status AddCurve(const PointF *points, INT count, REAL tension)
	{
		return updateStatus(DllExports::GdipAddPathCurve2(
				nativePath, points, count, tension));
	}
	Status AddCurve(const Point *points, INT count, REAL tension)
	{
		return updateStatus(DllExports::GdipAddPathCurve2I(
				nativePath, points, count, tension));
	}
	Status AddCurve(const PointF *points, INT count, INT offset,
			INT numberOfSegments, REAL tension)
	{
		return updateStatus(DllExports::GdipAddPathCurve3(
				nativePath, points, count,
				offset, numberOfSegments, tension));
	}
	Status AddCurve(const Point *points, INT count, INT offset,
			INT numberOfSegments, REAL tension)
	{
		return updateStatus(DllExports::GdipAddPathCurve3I(
				nativePath, points, count,
				offset, numberOfSegments, tension));
	}
	Status AddEllipse(REAL x, REAL y, REAL width, REAL height)
	{
		return updateStatus(DllExports::GdipAddPathEllipse(nativePath,
				x, y, width, height));
	}
	Status AddEllipse(INT x, INT y, INT width, INT height)
	{
		return updateStatus(DllExports::GdipAddPathEllipseI(nativePath,
				x, y, width, height));
	}
	Status AddEllipse(const RectF& rect)
	{
		return updateStatus(DllExports::GdipAddPathEllipse(nativePath,
				rect.X, rect.Y, rect.Width, rect.Height));
	}
	Status AddEllipse(const Rect& rect)
	{
		return updateStatus(DllExports::GdipAddPathEllipseI(nativePath,
				rect.X, rect.Y, rect.Width, rect.Height));
	}
	Status AddLine(REAL x1, REAL y1, REAL x2, REAL y2)
	{
		return updateStatus(DllExports::GdipAddPathLine(nativePath,
				x1, y1, x2, y2));
	}
	Status AddLine(INT x1, INT y1, INT x2, INT y2)
	{
		return updateStatus(DllExports::GdipAddPathLineI(nativePath,
				x1, y1, x2, y2));
	}
	Status AddLine(const PointF& pt1, const PointF& pt2)
	{
		return updateStatus(DllExports::GdipAddPathLine(nativePath,
				pt1.X, pt1.Y, pt2.X, pt2.Y));
	}
	Status AddLine(const Point& pt1, const Point& pt2)
	{
		return updateStatus(DllExports::GdipAddPathLineI(nativePath,
				pt1.X, pt1.Y, pt2.X, pt2.Y));
	}
	Status AddLines(const PointF *points, INT count)
	{
		return updateStatus(DllExports::GdipAddPathLine2(nativePath,
				points, count));
	}
	Status AddLines(const Point *points, INT count)
	{
		return updateStatus(DllExports::GdipAddPathLine2I(nativePath,
				points, count));
	}
	Status AddPath(const GraphicsPath *addingPath, BOOL connect)
	{
		return updateStatus(DllExports::GdipAddPathPath(nativePath,
				addingPath ? addingPath->nativePath : NULL,
				connect));
	}
	Status AddPie(REAL x, REAL y, REAL width, REAL height,
			REAL startAngle, REAL sweepAngle)
	{
		return updateStatus(DllExports::GdipAddPathPie(nativePath,
				x, y, width, height, startAngle, sweepAngle));
	}
	Status AddPie(INT x, INT y, INT width, INT height,
			REAL startAngle, REAL sweepAngle)
	{
		return updateStatus(DllExports::GdipAddPathPieI(nativePath,
				x, y, width, height, startAngle, sweepAngle));
	}
	Status AddPie(const RectF& rect, REAL startAngle, REAL sweepAngle)
	{
		return updateStatus(DllExports::GdipAddPathPie(nativePath,
				rect.X, rect.Y, rect.Width, rect.Height,
				startAngle, sweepAngle));
	}
	Status AddPie(const Rect& rect, REAL startAngle, REAL sweepAngle)
	{
		return updateStatus(DllExports::GdipAddPathPieI(nativePath,
				rect.X, rect.Y, rect.Width, rect.Height,
				startAngle, sweepAngle));
	}
	Status AddPolygon(const PointF *points, INT count)
	{
		return updateStatus(DllExports::GdipAddPathPolygon(nativePath,
				points, count));
	}
	Status AddPolygon(const Point *points, INT count)
	{
		return updateStatus(DllExports::GdipAddPathPolygonI(nativePath,
				points, count));
	}
	Status AddRectangle(const RectF& rect)
	{
		return updateStatus(DllExports::GdipAddPathRectangle(nativePath,
				rect.X, rect.Y, rect.Width, rect.Height));
	}
	Status AddRectangle(const Rect& rect)
	{
		return updateStatus(DllExports::GdipAddPathRectangleI(
				nativePath,
				rect.X, rect.Y, rect.Width, rect.Height));
	}
	Status AddRectangles(const RectF *rects, INT count)
	{
		return updateStatus(DllExports::GdipAddPathRectangles(
				nativePath, rects, count));
	}
	Status AddRectangles(const Rect *rects, INT count)
	{
		return updateStatus(DllExports::GdipAddPathRectanglesI(
				nativePath, rects, count));
	}
	Status AddString(const WCHAR *string, INT length,
			const FontFamily *family, INT style, REAL emSize,
			const PointF& origin, const StringFormat *format)
	{
		RectF layoutRect(origin, SizeF(0.0f, 0.0f));
		return updateStatus(DllExports::GdipAddPathString(nativePath,
				string, length,
				family ? family->nativeFontFamily : NULL,
				style, emSize, &layoutRect,
				format ? format->nativeStringFormat : NULL));
	}
	Status AddString(const WCHAR *string, INT length,
			const FontFamily *family, INT style, REAL emSize,
			const Point& origin, const StringFormat *format)
	{
		Rect layoutRect(origin, Size(0, 0));
		return updateStatus(DllExports::GdipAddPathStringI(nativePath,
				string, length,
				family ? family->nativeFontFamily : NULL,
				style, emSize, &layoutRect,
				format ? format->nativeStringFormat : NULL));
	}
	Status AddString(const WCHAR *string, INT length,
			const FontFamily *family, INT style, REAL emSize,
			const RectF& layoutRect, const StringFormat *format)
	{
		return updateStatus(DllExports::GdipAddPathString(nativePath,
				string, length,
				family ? family->nativeFontFamily : NULL,
				style, emSize, &layoutRect,
				format ? format->nativeStringFormat : NULL));
	}
	Status AddString(const WCHAR *string, INT length,
			const FontFamily *family, INT style, REAL emSize,
			const Rect& layoutRect, const StringFormat *format)
	{
		return updateStatus(DllExports::GdipAddPathStringI(nativePath,
				string, length,
				family ? family->nativeFontFamily : NULL,
				style, emSize, &layoutRect,
				format ? format->nativeStringFormat : NULL));
	}
	Status ClearMarkers()
	{
		return updateStatus(DllExports::GdipClearPathMarkers(
				nativePath));
	}
	Status CloseAllFigures()
	{
		return updateStatus(DllExports::GdipClosePathFigures(
				nativePath));
	}
	Status CloseFigure()
	{
		return updateStatus(DllExports::GdipClosePathFigure(
				nativePath));
	}
	Status Flatten(const Matrix *matrix = NULL,
			REAL flatness = FlatnessDefault)
	{
		return updateStatus(DllExports::GdipFlattenPath(nativePath,
				matrix ? matrix->nativeMatrix : NULL,
				flatness));
	}
	Status GetBounds(RectF *bounds, const Matrix *matrix = NULL,
			const Pen *pen = NULL) const
	{
		return updateStatus(DllExports::GdipGetPathWorldBounds(
				nativePath, bounds,
				matrix ? matrix->nativeMatrix : NULL,
				pen ? pen->nativePen : NULL));
	}
	Status GetBounds(Rect *bounds, const Matrix *matrix = NULL,
			const Pen *pen = NULL) const
	{
		return updateStatus(DllExports::GdipGetPathWorldBoundsI(
				nativePath, bounds,
				matrix ? matrix->nativeMatrix : NULL,
				pen ? pen->nativePen : NULL));
	}	
	FillMode GetFillMode() const
	{
		FillMode result = FillModeAlternate;
		updateStatus(DllExports::GdipGetPathFillMode(nativePath,
				&result));
		return result;
	}
	Status GetLastPoint(PointF *lastPoint) const
	{
		return updateStatus(DllExports::GdipGetPathLastPoint(
				nativePath, lastPoint));
	}
	Status GetLastStatus() const
	{
		Status result = lastStatus;
		lastStatus = Ok;
		return result;
	}
	Status GetPathData(PathData *pathData) const
	{
		if (!pathData) return lastStatus = InvalidParameter;

		Status status;
		INT count;

		status = updateStatus(DllExports::GdipGetPointCount(
				nativePath, &count));
		if (status != Ok) return status;

		status = updateStatus(pathData->AllocateArrays(count));
		if (status != Ok) return status;

		return updateStatus(DllExports::GdipGetPathData(
				nativePath, (GpPathData*) pathData));
	}
	Status GetPathPoints(PointF *points, INT count) const
	{
		return updateStatus(DllExports::GdipGetPathPoints(nativePath,
				points, count));
	}
	Status GetPathPoints(Point *points, INT count) const
	{
		return updateStatus(DllExports::GdipGetPathPointsI(nativePath,
				points, count));
	}
	Status GetPathTypes(BYTE *types, INT count) const
	{
		return updateStatus(DllExports::GdipGetPathTypes(nativePath,
				types, count));
	}
	INT GetPointCount() const
	{
		INT result = 0;
		updateStatus(DllExports::GdipGetPointCount(nativePath,
				&result));
		return result;
	}
	BOOL IsOutlineVisible(REAL x, REAL y, const Pen *pen,
			const Graphics *g = NULL) const;
	BOOL IsOutlineVisible(INT x, INT y, const Pen *pen,
			const Graphics *g = NULL) const;
	BOOL IsOutlineVisible(const PointF& point, const Pen *pen,
			const Graphics *g = NULL) const;
	BOOL IsOutlineVisible(const Point& point, const Pen *pen,
			const Graphics *g = NULL) const;
	BOOL IsVisible(REAL x, REAL y, const Graphics *g = NULL) const;
	BOOL IsVisible(INT x, INT y, const Graphics *g = NULL) const;
	BOOL IsVisible(const PointF& point, const Graphics *g = NULL) const;
	BOOL IsVisible(const Point& point, const Graphics *g = NULL) const;
	Status Outline(const Matrix *matrix = NULL,
			REAL flatness = FlatnessDefault)
	{
		return updateStatus(DllExports::GdipWindingModeOutline(
				nativePath,
				matrix ? matrix->nativeMatrix : NULL,
				flatness));
	}
	Status Reset()
	{
		return updateStatus(DllExports::GdipResetPath(nativePath));
	}
	Status Reverse()
	{
		return updateStatus(DllExports::GdipReversePath(nativePath));
	}
	Status SetFillMode(FillMode fillMode)
	{
		return updateStatus(DllExports::GdipSetPathFillMode(
				nativePath, fillMode));
	}
	Status SetMarker()
	{
		return updateStatus(DllExports::GdipSetPathMarker(nativePath));
	}
	Status StartFigure()
	{
		return updateStatus(DllExports::GdipStartPathFigure(
				nativePath));
	}
	Status Transform(const Matrix *matrix)
	{
		return updateStatus(DllExports::GdipTransformPath(
				nativePath,
				matrix ? matrix->nativeMatrix : NULL));
	}
	Status Warp(const PointF *destPoints, INT count, const RectF& srcRect,
			const Matrix *matrix = NULL,
			WarpMode warpMode = WarpModePerspective,
			REAL flatness = FlatnessDefault)
	{
		return updateStatus(DllExports::GdipWarpPath(nativePath,
				matrix ? matrix->nativeMatrix : NULL,
				destPoints, count,
				srcRect.X, srcRect.Y,
				srcRect.Width, srcRect.Height,
				warpMode, flatness));
	}
	Status Widen(const Pen *pen, const Matrix *matrix = NULL,
			REAL flatness = FlatnessDefault)
	{
		return updateStatus(DllExports::GdipWidenPath(nativePath,
				pen ? pen->nativePen : NULL,
				matrix ? matrix->nativeMatrix : NULL,
				flatness));
	}

private:
	GraphicsPath(GpPath *path, Status status):
		nativePath(path), lastStatus(status) {}
	GraphicsPath(const GraphicsPath&);
	GraphicsPath& operator=(const GraphicsPath&);

	Status updateStatus(Status newStatus) const
	{
		if (newStatus != Ok) lastStatus = newStatus;
		return newStatus;
	}

	GpPath *nativePath;
	mutable Status lastStatus;
};

class GraphicsPathIterator: public GdiplusBase
{
public:
	GraphicsPathIterator(GraphicsPath *path):
		nativePathIterator(NULL), lastStatus(Ok)
	{
		lastStatus = DllExports::GdipCreatePathIter(
				&nativePathIterator,
				path ? path->nativePath : NULL);
	}
	~GraphicsPathIterator()
	{
		DllExports::GdipDeletePathIter(nativePathIterator);
	}

	INT CopyData(PointF *points, BYTE *types, INT startIndex, INT endIndex)
	{
		INT result = 0;
		updateStatus(DllExports::GdipPathIterCopyData(
				nativePathIterator, &result,
				points, types, startIndex, endIndex));
		return result;
	}
	INT Enumerate(PointF *points, BYTE *types, INT count)
	{
		INT result = 0;
		updateStatus(DllExports::GdipPathIterEnumerate(
				nativePathIterator, &result,
				points, types, count));
		return result;
	}
	INT GetCount() const
	{
		INT result = 0;
		updateStatus(DllExports::GdipPathIterGetCount(
				nativePathIterator, &result));
		return result;
	}
	Status GetLastStatus() const
	{
		Status result = lastStatus;
		lastStatus = Ok;
		return result;
	}
	INT GetSubpathCount() const
	{
		INT result = 0;
		updateStatus(DllExports::GdipPathIterGetSubpathCount(
				nativePathIterator, &result));
		return result;
	}
	BOOL HasCurve() const
	{
		BOOL result = FALSE;
		updateStatus(DllExports::GdipPathIterHasCurve(
				nativePathIterator, &result));
		return result;
	}
	INT NextMarker(INT *startIndex, INT *endIndex)
	{
		INT result = 0;
		updateStatus(DllExports::GdipPathIterNextMarker(
				nativePathIterator, &result,
				startIndex, endIndex));
		return result;
	}
	INT NextMarker(GraphicsPath *path)
	{
		INT result = 0;
		updateStatus(DllExports::GdipPathIterNextMarkerPath(
				nativePathIterator, &result,
				path ? path->nativePath : NULL));
		return result;
	}
	INT NextPathType(BYTE *pathType, INT *startIndex, INT *endIndex)
	{
		INT result = 0;
		updateStatus(DllExports::GdipPathIterNextPathType(
				nativePathIterator, &result,
				pathType, startIndex, endIndex));
		return result;
	}
	INT NextSubpath(INT *startIndex, INT *endIndex, BOOL *isClosed)
	{
		INT result = 0;
		updateStatus(DllExports::GdipPathIterNextSubpath(
				nativePathIterator, &result,
				startIndex, endIndex, isClosed));
		return result;
	}
	INT NextSubpath(GraphicsPath *path, BOOL *isClosed)
	{
		INT result = 0;
		updateStatus(DllExports::GdipPathIterNextSubpathPath(
				nativePathIterator, &result,
				path ? path->nativePath : NULL, isClosed));
		return result;
	}
	VOID Rewind()
	{
		updateStatus(DllExports::GdipPathIterRewind(
				nativePathIterator));
	}

private:
	GraphicsPathIterator(GpPathIterator *pathIterator, Status status):
		nativePathIterator(pathIterator), lastStatus(status) {}
	GraphicsPathIterator(const GraphicsPathIterator&);
	GraphicsPathIterator& operator=(const GraphicsPathIterator&);

	Status updateStatus(Status newStatus) const
	{
		if (newStatus != Ok) lastStatus = newStatus;
		return newStatus;
	}

	GpPathIterator *nativePathIterator;
	mutable Status lastStatus;
};

class PathGradientBrush: public Brush
{
public:
	PathGradientBrush(const PointF *points, INT count,
			WrapMode wrapMode = WrapModeClamp)
	{
		GpPathGradient *nativePathGradient = NULL;
		lastStatus = DllExports::GdipCreatePathGradient(
				points, count, wrapMode, &nativePathGradient);
		nativeBrush = nativePathGradient;
	}
	PathGradientBrush(const Point *points, INT count,
			WrapMode wrapMode = WrapModeClamp)
	{
		GpPathGradient *nativePathGradient = NULL;
		lastStatus = DllExports::GdipCreatePathGradientI(
				points, count, wrapMode, &nativePathGradient);
		nativeBrush = nativePathGradient;
	}
	PathGradientBrush(const GraphicsPath *path)
	{
		GpPathGradient *nativePathGradient = NULL;
		lastStatus = DllExports::GdipCreatePathGradientFromPath(
				path ? path->nativePath : NULL,
				&nativePathGradient);
		nativeBrush = nativePathGradient;
	}
	virtual PathGradientBrush *Clone() const
	{
		GpBrush *cloneBrush = NULL;
		Status status = updateStatus(DllExports::GdipCloneBrush(
				nativeBrush, &cloneBrush));
		if (status == Ok) {
			PathGradientBrush *result =
				new PathGradientBrush(cloneBrush, lastStatus);
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
		return updateStatus(DllExports::GdipGetPathGradientBlend(
				(GpPathGradient*) nativeBrush,
				blendFactors, blendPositions, count));
	}
	INT GetBlendCount() const
	{
		INT result = 0;
		updateStatus(DllExports::GdipGetPathGradientBlendCount(
				(GpPathGradient*) nativeBrush, &result));
		return result;
	}
	Status GetCenterColor(Color *color) const
	{
		return updateStatus(DllExports::GdipGetPathGradientCenterColor(
				(GpPathGradient*) nativeBrush,
				color ? &color->Value : NULL));
	}
	Status GetCenterPoint(PointF *point) const
	{
		return updateStatus(DllExports::GdipGetPathGradientCenterPoint(
				(GpPathGradient*) nativeBrush, point));
	}
	Status GetCenterPoint(Point *point) const
	{
		return updateStatus(DllExports::GdipGetPathGradientCenterPointI(
				(GpPathGradient*) nativeBrush, point));
	}
	Status GetFocusScales(REAL *xScale, REAL *yScale) const
	{
		return updateStatus(DllExports::GdipGetPathGradientFocusScales(
				(GpPathGradient*) nativeBrush, xScale, yScale));
	}
	BOOL GetGammaCorrection() const
	{
		BOOL result = FALSE;
		updateStatus(DllExports::GdipGetPathGradientGammaCorrection(
				(GpPathGradient*) nativeBrush, &result));
		return result;
	}
	//Status GetGraphicsPath(GraphicsPath *path) const
	//{
	//	// TODO: implement PathGradientBrush::GetGraphicsPath
	//	return updateStatus(NotImplemented);
	//}
	INT GetInterpolationColorCount() const
	{
		INT result = 0;
		updateStatus(DllExports::GdipGetPathGradientPresetBlendCount(
				(GpPathGradient*) nativeBrush, &result));
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

		Status status = updateStatus(DllExports::GdipGetPathGradientPresetBlend(
				(GpPathGradient*) nativeBrush,
				presetArgb, blendPositions, count));
		for (INT i = 0; i < count; ++i) {
			presetColors[i].SetValue(presetArgb[i]);
		}
		DllExports::GdipFree((void*) presetArgb);
		return status;
	}
	INT GetPointCount() const
	{
		INT result = 0;
		updateStatus(DllExports::GdipGetPathGradientPointCount(
				(GpPathGradient*) nativeBrush, &result));
		return result;
	}
	Status GetRectangle(RectF *rect) const
	{
		return updateStatus(DllExports::GdipGetPathGradientRect(
				(GpPathGradient*) nativeBrush, rect));
	}
	Status GetRectangle(Rect *rect) const
	{
		return updateStatus(DllExports::GdipGetPathGradientRectI(
				(GpPathGradient*) nativeBrush, rect));
	}
	INT GetSurroundColorCount() const
	{
		INT result = 0;
		updateStatus(DllExports::GdipGetPathGradientSurroundColorCount(
				(GpPathGradient*) nativeBrush, &result));
		return result;
	}
	Status GetSurroundColors(Color *colors, INT *count)
	{
		if (!colors || !count || *count <= 0)
			return lastStatus = InvalidParameter;

		ARGB *colorsArgb =
			(ARGB*) DllExports::GdipAlloc(*count * sizeof(ARGB));
		if (!colorsArgb)
			return lastStatus = OutOfMemory;

		Status status = updateStatus(DllExports::GdipGetPathGradientSurroundColorsWithCount(
				(GpPathGradient*) nativeBrush,
				colorsArgb, count));
		for (INT i = 0; i < *count; ++i) {
			colors[i].SetValue(colorsArgb[i]);
		}
		DllExports::GdipFree((void*) colorsArgb);
		return status;
	}
	Status GetTransform(Matrix *matrix) const
	{
		return updateStatus(DllExports::GdipGetPathGradientTransform(
				(GpPathGradient*) nativeBrush,
				matrix ? matrix->nativeMatrix : NULL));
	}
	WrapMode GetWrapMode() const
	{
		WrapMode result = WrapModeTile;
		updateStatus(DllExports::GdipGetPathGradientWrapMode(
				(GpPathGradient*) nativeBrush, &result));
		return result;
	}
	Status MultiplyTransform(const Matrix *matrix,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipMultiplyPathGradientTransform(
				(GpPathGradient*) nativeBrush,
				matrix ? matrix->nativeMatrix : NULL, order));
	}
	Status ResetTransform()
	{
		return updateStatus(DllExports::GdipResetPathGradientTransform(
				(GpPathGradient*) nativeBrush));
	}
	Status RotateTransform(REAL angle,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipRotatePathGradientTransform(
				(GpPathGradient*) nativeBrush, angle, order));
	}
	Status ScaleTransform(REAL sx, REAL sy,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipScalePathGradientTransform(
				(GpPathGradient*) nativeBrush, sx, sy, order));
	}
	Status SetBlend(REAL *blendFactors, REAL *blendPositions, INT count)
	{
		return updateStatus(DllExports::GdipSetPathGradientBlend(
				(GpPathGradient*) nativeBrush,
				blendFactors, blendPositions, count));
	}
	Status SetBlendBellShape(REAL focus, REAL scale = 1.0f)
	{
		return updateStatus(DllExports::GdipSetPathGradientSigmaBlend(
				(GpPathGradient*) nativeBrush, focus, scale));
	}
	Status SetBlendTriangularShape(REAL focus, REAL scale = 1.0f)
	{
		return updateStatus(DllExports::GdipSetPathGradientLinearBlend(
				(GpPathGradient*) nativeBrush, focus, scale));
	}
	Status SetCenterColor(const Color& color)
	{
		return updateStatus(DllExports::GdipSetPathGradientCenterColor(
				(GpPathGradient*) nativeBrush,
				color.GetValue()));
	}
	Status SetCenterPoint(const PointF& point)
	{
		return updateStatus(DllExports::GdipSetPathGradientCenterPoint(
				(GpPathGradient*) nativeBrush, &point));
	}
	Status SetCenterPoint(const Point& point)
	{
		return updateStatus(DllExports::GdipSetPathGradientCenterPointI(
				(GpPathGradient*) nativeBrush, &point));
	}
	Status SetFocusScales(REAL xScale, REAL yScale)
	{
		return updateStatus(DllExports::GdipSetPathGradientFocusScales(
				(GpPathGradient*) nativeBrush, xScale, yScale));
	}
	Status SetGammaCorrection(BOOL useGammaCorrection)
	{
		return updateStatus(DllExports::GdipSetPathGradientGammaCorrection(
				(GpPathGradient*) nativeBrush,
				useGammaCorrection));
	}
	//Status SetGraphicsPath(const GraphicsPath *path)
	//{
	//	// TODO: implement PathGradientBrush::SetGraphicsPath
	//	return updateStatus(NotImplemented);
	//}
	Status SetInterpolationColors(const Color *presetColors,
			REAL *blendPositions, INT count)
	{
		if (!presetColors || count <= 0)
			return lastStatus = InvalidParameter;

		ARGB *presetArgb =
			(ARGB*) DllExports::GdipAlloc(count * sizeof(ARGB));
		if (!presetArgb)
			return lastStatus = OutOfMemory;
		for (INT i = 0; i < count; ++i) {
			presetArgb[i] = presetColors[i].GetValue();
		}

		Status status = updateStatus(DllExports::GdipSetPathGradientPresetBlend(
				(GpPathGradient*) nativeBrush,
				presetArgb, blendPositions, count));
		DllExports::GdipFree((void*) presetArgb);
		return status;
	}
	Status SetSurroundColors(const Color *colors, INT *count)
	{
		if (!colors || !count || *count <= 0)
			return lastStatus = InvalidParameter;

		ARGB *colorsArgb =
			(ARGB*) DllExports::GdipAlloc(*count * sizeof(ARGB));
		if (!colorsArgb)
			return lastStatus = OutOfMemory;
		for (INT i = 0; i < *count; ++i) {
			colorsArgb[i] = colors[i].GetValue();
		}

		Status status = updateStatus(DllExports::GdipSetPathGradientSurroundColorsWithCount(
				(GpPathGradient*) nativeBrush,
				colorsArgb, count));
		DllExports::GdipFree((void*) colorsArgb);
		return status;
	}
	Status SetTransform(const Matrix *matrix)
	{
		return updateStatus(DllExports::GdipSetPathGradientTransform(
				(GpPathGradient*) nativeBrush,
				matrix ? matrix->nativeMatrix : NULL));
	}
	Status SetWrapMode(WrapMode wrapMode)
	{
		return updateStatus(DllExports::GdipSetPathGradientWrapMode(
				(GpPathGradient*) nativeBrush, wrapMode));
	}
	Status TranslateTransform(REAL dx, REAL dy,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipTranslatePathGradientTransform(
				(GpPathGradient*) nativeBrush, dx, dy, order));
	}

private:
	PathGradientBrush(GpBrush *brush, Status status): Brush(brush, status) {}
	PathGradientBrush(const PathGradientBrush&);
	PathGradientBrush& operator=(const PathGradientBrush&);
};



#endif /* __GDIPLUS_PATH_H */
