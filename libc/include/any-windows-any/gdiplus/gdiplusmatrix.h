/*
 * gdiplusmatrix.h
 *
 * GDI+ Matrix class
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

#ifndef __GDIPLUS_MATRIX_H
#define __GDIPLUS_MATRIX_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

#ifndef __cplusplus
#error "A C++ compiler is required to include gdiplusmatrix.h."
#endif

#define GDIP_MATRIX_PI \
	3.1415926535897932384626433832795028841971693993751058209749445923078164

class Matrix: public GdiplusBase
{
	friend class Graphics;
	friend class GraphicsPath;
	friend class LinearGradientBrush;
	friend class PathGradientBrush;
	friend class Pen;
	friend class Region;
	friend class TextureBrush;

public:
	Matrix(): nativeMatrix(NULL), lastStatus(Ok)
	{
		lastStatus = DllExports::GdipCreateMatrix(&nativeMatrix);
	}
	Matrix(REAL m11, REAL m12, REAL m21, REAL m22, REAL dx, REAL dy):
			nativeMatrix(NULL), lastStatus(Ok)
	{
		lastStatus = DllExports::GdipCreateMatrix2(
				m11, m12, m21, m22, dx, dy,
				&nativeMatrix);
	}
	Matrix(const RectF& rect, const PointF *dstplg):
			nativeMatrix(NULL), lastStatus(Ok)
	{
		lastStatus = DllExports::GdipCreateMatrix3(
				&rect, dstplg, &nativeMatrix);
	}
	Matrix(const Rect& rect, const Point *dstplg):
			nativeMatrix(NULL), lastStatus(Ok)
	{
		lastStatus = DllExports::GdipCreateMatrix3I(
				&rect, dstplg, &nativeMatrix);
	}
	~Matrix()
	{
		DllExports::GdipDeleteMatrix(nativeMatrix);
	}
	Matrix* Clone() const
	{
		GpMatrix *cloneMatrix = NULL;
		Status status = updateStatus(DllExports::GdipCloneMatrix(
				nativeMatrix, &cloneMatrix));
		if (status == Ok) {
			Matrix *result = new Matrix(cloneMatrix, lastStatus);
			if (!result) {
				DllExports::GdipDeleteMatrix(cloneMatrix);
				lastStatus = OutOfMemory;
			}
			return result;
		} else {
			return NULL;
		}
	}

	BOOL Equals(const Matrix *matrix) const
	{
		BOOL result;
		updateStatus(DllExports::GdipIsMatrixEqual(
				nativeMatrix,
				matrix ? matrix->nativeMatrix : NULL, &result));
		return result;
	}
	Status GetElements(REAL *m) const
	{
		return updateStatus(DllExports::GdipGetMatrixElements(
				nativeMatrix, m));
	}
	Status GetLastStatus() const
	{
		Status result = lastStatus;
		lastStatus = Ok;
		return result;
	}
	Status Invert()
	{
		return updateStatus(DllExports::GdipInvertMatrix(nativeMatrix));
	}
	BOOL IsIdentity() const
	{
		BOOL result;
		updateStatus(DllExports::GdipIsMatrixIdentity(
				nativeMatrix, &result));
		return result;
	}
	BOOL IsInvertible() const
	{
		BOOL result;
		updateStatus(DllExports::GdipIsMatrixInvertible(
				nativeMatrix, &result));
		return result;
	}
	Status Multiply(const Matrix *matrix,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipMultiplyMatrix(
				nativeMatrix,
				matrix ? matrix->nativeMatrix : NULL, order));
	}
	REAL OffsetX() const
	{
		REAL m[6];
		updateStatus(DllExports::GdipGetMatrixElements(nativeMatrix, m));
		return m[4];
	}
	REAL OffsetY() const
	{
		REAL m[6];
		updateStatus(DllExports::GdipGetMatrixElements(nativeMatrix, m));
		return m[5];
	}
	Status Reset()
	{
		return updateStatus(DllExports::GdipSetMatrixElements(
				nativeMatrix,
				1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f));
	}
	Status Rotate(REAL angle, MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipRotateMatrix(
				nativeMatrix, angle, order));
	}
	Status RotateAt(REAL angle, const PointF& center,
			MatrixOrder order = MatrixOrderPrepend)
	{
		REAL angleRadian = angle * GDIP_MATRIX_PI / 180.0f;
		REAL cosAngle = ::cos(angleRadian);
		REAL sinAngle = ::sin(angleRadian);
		REAL x = center.X;
		REAL y = center.Y;

		Matrix matrix2(cosAngle, sinAngle, -sinAngle, cosAngle,
				x * (1.0f-cosAngle) + y * sinAngle,
				-x * sinAngle + y * (1.0f-cosAngle));
		Status status = matrix2.GetLastStatus();
		if (status == Ok) {
			return Multiply(&matrix2, order);
		} else {
			return lastStatus = status;
		}
	}
	Status Scale(REAL scaleX, REAL scaleY,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipScaleMatrix(
				nativeMatrix, scaleX, scaleY, order));
	}
	Status SetElements(REAL m11, REAL m12, REAL m21, REAL m22,
			REAL dx, REAL dy)
	{
		return updateStatus(DllExports::GdipSetMatrixElements(
				nativeMatrix, m11, m12, m21, m22, dx, dy));
	}
	Status Shear(REAL shearX, REAL shearY,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipShearMatrix(
				nativeMatrix, shearX, shearY, order));
	}
	Status TransformPoints(PointF *pts, INT count = 1) const
	{
		return updateStatus(DllExports::GdipTransformMatrixPoints(
				nativeMatrix, pts, count));
	}
	Status TransformPoints(Point *pts, INT count = 1) const
	{
		return updateStatus(DllExports::GdipTransformMatrixPointsI(
				nativeMatrix, pts, count));
	}
	Status TransformVectors(PointF *pts, INT count = 1) const
	{
		return updateStatus(DllExports::GdipVectorTransformMatrixPoints(
				nativeMatrix, pts, count));
	}
	Status TransformVectors(Point *pts, INT count = 1) const
	{
		return updateStatus(DllExports::GdipVectorTransformMatrixPointsI(
				nativeMatrix, pts, count));
	}
	Status Translate(REAL offsetX, REAL offsetY,
			MatrixOrder order = MatrixOrderPrepend)
	{
		return updateStatus(DllExports::GdipTranslateMatrix(
				nativeMatrix, offsetX, offsetY, order));
	}

private:
	Matrix(GpMatrix *matrix, Status status):
		nativeMatrix(matrix), lastStatus(status) {}
	Matrix(const Matrix&);
	Matrix& operator=(const Matrix&);

	Status updateStatus(Status newStatus) const
	{
		if (newStatus != Ok) lastStatus = newStatus;
		return newStatus;
	}

	GpMatrix *nativeMatrix;
	mutable Status lastStatus;
};

#undef GDIP_MATRIX_PI

#endif /* __GDIPLUS_MATRIX_H */
