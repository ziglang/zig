/*
 * gdiplustypes.h
 *
 * GDI+ basic type declarations
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

#ifndef __GDIPLUS_TYPES_H
#define __GDIPLUS_TYPES_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

#if defined(_ARM_)
#define WINGDIPAPI
#else
#define WINGDIPAPI __stdcall
#endif
#define GDIPCONST const

typedef enum GpStatus {
	Ok = 0,
	GenericError = 1,
	InvalidParameter = 2,
	OutOfMemory = 3,
	ObjectBusy = 4,
	InsufficientBuffer = 5,
	NotImplemented = 6,
	Win32Error = 7,
	WrongState = 8,
	Aborted = 9,
	FileNotFound = 10,
	ValueOverflow = 11,
	AccessDenied = 12,
	UnknownImageFormat = 13,
	FontFamilyNotFound = 14,
	FontStyleNotFound = 15,
	NotTrueTypeFont = 16,
	UnsupportedGdiplusVersion = 17,
	GdiplusNotInitialized = 18,
	PropertyNotFound = 19,
	PropertyNotSupported = 20,
	ProfileNotFound = 21
} GpStatus;

#ifdef __cplusplus
typedef GpStatus Status;
#endif

typedef struct Size {
	INT Width;
	INT Height;

	#ifdef __cplusplus
	Size(): Width(0), Height(0) {}
	Size(INT width, INT height): Width(width), Height(height) {}
	Size(const Size& size): Width(size.Width), Height(size.Height) {}
	
	BOOL Empty() const {
		return Width == 0 && Height == 0;
	}
	BOOL Equals(const Size& size) const {
		return Width == size.Width && Height == size.Height;
	}
	Size operator+(const Size& size) const {
		return Size(Width + size.Width, Height + size.Height);
	}
	Size operator-(const Size& size) const {
		return Size(Width - size.Width, Height - size.Height);
	}
	#endif /* __cplusplus */
} Size;

typedef struct SizeF {
	REAL Width;
	REAL Height;

	#ifdef __cplusplus
	SizeF(): Width(0.0f), Height(0.0f) {}
	SizeF(REAL width, REAL height): Width(width), Height(height) {}
	SizeF(const SizeF& size): Width(size.Width), Height(size.Height) {}
	
	BOOL Empty() const {
		return Width == 0.0f && Height == 0.0f;
	}
	BOOL Equals(const SizeF& size) const {
		return Width == size.Width && Height == size.Height;
	}
	SizeF operator+(const SizeF& size) const {
		return SizeF(Width + size.Width, Height + size.Height);
	}
	SizeF operator-(const SizeF& size) const {
		return SizeF(Width - size.Width, Height - size.Height);
	}
	#endif /* __cplusplus */
} SizeF;

typedef struct Point {
	INT X;
	INT Y;

	#ifdef __cplusplus
	Point(): X(0), Y(0) {}
	Point(INT x, INT y): X(x), Y(y) {}
	Point(const Point& point): X(point.X), Y(point.Y) {}
	Point(const Size& size): X(size.Width), Y(size.Height) {}
	
	BOOL Equals(const Point& point) const {
		return X == point.X && Y == point.Y;
	}
	Point operator+(const Point& point) const {
		return Point(X + point.X, Y + point.Y);
	}
	Point operator-(const Point& point) const {
		return Point(X - point.X, Y - point.Y);
	}
	#endif /* __cplusplus */
} Point;

typedef struct PointF {
	REAL X;
	REAL Y;

	#ifdef __cplusplus
	PointF(): X(0.0f), Y(0.0f) {}
	PointF(REAL x, REAL y): X(x), Y(y) {}
	PointF(const PointF& point): X(point.X), Y(point.Y) {}
	PointF(const SizeF& size): X(size.Width), Y(size.Height) {}
	
	BOOL Equals(const PointF& point) const {
		return X == point.X && Y == point.Y;
	}
	PointF operator+(const PointF& point) const {
		return PointF(X + point.X, Y + point.Y);
	}
	PointF operator-(const PointF& point) const {
		return PointF(X - point.X, Y - point.Y);
	}
	#endif /* __cplusplus */
} PointF;

typedef struct Rect {
	INT X;
	INT Y;
	INT Width;
	INT Height;

	#ifdef __cplusplus
	Rect(): X(0), Y(0), Width(0), Height(0) {}
	Rect(const Point& location, const Size& size):
		X(location.X), Y(location.Y),
		Width(size.Width), Height(size.Height) {}
	Rect(INT x, INT y, INT width, INT height):
		X(x), Y(y), Width(width), Height(height) {}
	
	Rect* Clone() const {
		return new Rect(X, Y, Width, Height);
	}
	BOOL Contains(INT x, INT y) const {
		return X <= x && Y <= y && x < X+Width && y < Y+Height;
	}
	BOOL Contains(const Point& point) const {
		return Contains(point.X, point.Y);
	}
	BOOL Contains(const Rect& rect) const {
		return X <= rect.X && Y <= rect.Y
			&& rect.X+rect.Width <= X+Width
			&& rect.Y+rect.Height <= Y+Height;
	}
	BOOL Equals(const Rect& rect) const {
		return X == rect.X && Y == rect.Y
			&& Width == rect.Width && Height == rect.Height;
	}
	INT GetBottom() const {
		return Y+Height;
	}
	VOID GetBounds(Rect *rect) const {
		if (rect != NULL) {
			rect->X = X;
			rect->Y = Y;
			rect->Width = Width;
			rect->Height = Height;
		}
	}
	INT GetLeft() const {
		return X;
	}
	VOID GetLocation(Point *point) const {
		if (point != NULL) {
			point->X = X;
			point->Y = Y;
		}
	}
	INT GetRight() const {
		return X+Width;
	}
	VOID GetSize(Size *size) const {
		if (size != NULL) {
			size->Width = Width;
			size->Height = Height;
		}
	}
	INT GetTop() const {
		return Y;
	}
	BOOL IsEmptyArea() const {
		return Width <= 0 || Height <= 0;
	}
	VOID Inflate(INT dx, INT dy) {
		X -= dx;
		Y -= dy;
		Width += 2*dx;
		Height += 2*dy;
	}
	VOID Inflate(const Point& point) {
		Inflate(point.X, point.Y);
	}
	static BOOL Intersect(Rect& c, const Rect& a, const Rect& b) {
		INT intersectLeft   = (a.X < b.X) ? b.X : a.X;
		INT intersectTop    = (a.Y < b.Y) ? b.Y : a.Y; 
		INT intersectRight  = (a.GetRight() < b.GetRight())
					? a.GetRight() : b.GetRight();
		INT intersectBottom = (a.GetBottom() < b.GetBottom())
					? a.GetBottom() : b.GetBottom();
		c.X = intersectLeft;
		c.Y = intersectTop;
		c.Width = intersectRight - intersectLeft;
		c.Height = intersectBottom - intersectTop;
		return !c.IsEmptyArea();  
	}
	BOOL Intersect(const Rect& rect) {
		return Intersect(*this, *this, rect);
	}
	BOOL IntersectsWith(const Rect& rc) const {
		INT intersectLeft   = (X < rc.X) ? rc.X : X;
		INT intersectTop    = (Y < rc.Y) ? rc.Y : Y; 
		INT intersectRight  = (GetRight() < rc.GetRight())
					? GetRight() : rc.GetRight();
		INT intersectBottom = (GetBottom() < rc.GetBottom())
					? GetBottom() : rc.GetBottom();
		return intersectLeft < intersectRight
			&& intersectTop < intersectBottom;
	}
	VOID Offset(INT dx, INT dy) {
		X += dx;
		Y += dy;
	}
	VOID Offset(const Point& point) {
		Offset(point.X, point.Y);
	}
	static BOOL Union(Rect& c, const Rect& a, const Rect& b) {
		INT unionLeft   = (a.X < b.X) ? a.X : b.X;
		INT unionTop    = (a.Y < b.Y) ? a.Y : b.Y; 
		INT unionRight  = (a.GetRight() < b.GetRight())
					? b.GetRight() : a.GetRight();
		INT unionBottom = (a.GetBottom() < b.GetBottom())
					? b.GetBottom() : a.GetBottom();
		c.X = unionLeft;
		c.Y = unionTop;
		c.Width = unionRight - unionLeft;
		c.Height = unionBottom - unionTop;
		return !c.IsEmptyArea();
	}
	#endif /* __cplusplus */
} Rect;

typedef struct RectF {
	REAL X;
	REAL Y;
	REAL Width;
	REAL Height;

	#ifdef __cplusplus
	RectF(): X(0.0f), Y(0.0f), Width(0.0f), Height(0.0f) {}
	RectF(const PointF& location, const SizeF& size):
		X(location.X), Y(location.Y),
		Width(size.Width), Height(size.Height) {}
	RectF(REAL x, REAL y, REAL width, REAL height):
		X(x), Y(y), Width(width), Height(height) {}
	
	RectF* Clone() const {
		return new RectF(X, Y, Width, Height);
	}
	BOOL Contains(REAL x, REAL y) const {
		return X <= x && Y <= y && x < X+Width && y < Y+Height;
	}
	BOOL Contains(const PointF& point) const {
		return Contains(point.X, point.Y);
	}
	BOOL Contains(const RectF& rect) const {
		return X <= rect.X && Y <= rect.Y
			&& rect.X+rect.Width <= X+Width
			&& rect.Y+rect.Height <= Y+Height;
	}
	BOOL Equals(const RectF& rect) const {
		return X == rect.X && Y == rect.Y
			&& Width == rect.Width && Height == rect.Height;
	}
	REAL GetBottom() const {
		return Y+Height;
	}
	VOID GetBounds(RectF *rect) const {
		if (rect != NULL) {
			rect->X = X;
			rect->Y = Y;
			rect->Width = Width;
			rect->Height = Height;
		}
	}
	REAL GetLeft() const {
		return X;
	}
	VOID GetLocation(PointF *point) const {
		if (point != NULL) {
			point->X = X;
			point->Y = Y;
		}
	}
	REAL GetRight() const {
		return X+Width;
	}
	VOID GetSize(SizeF *size) const {
		if (size != NULL) {
			size->Width = Width;
			size->Height = Height;
		}
	}
	REAL GetTop() const {
		return Y;
	}
	BOOL IsEmptyArea() const {
		return Width <= 0.0f || Height <= 0.0f;
	}
	VOID Inflate(REAL dx, REAL dy) {
		X -= dx;
		Y -= dy;
		Width += 2*dx;
		Height += 2*dy;
	}
	VOID Inflate(const PointF& point) {
		Inflate(point.X, point.Y);
	}
	static BOOL Intersect(RectF& c, const RectF& a, const RectF& b) {
		INT intersectLeft   = (a.X < b.X) ? b.X : a.X;
		INT intersectTop    = (a.Y < b.Y) ? b.Y : a.Y; 
		INT intersectRight  = (a.GetRight() < b.GetRight())
					? a.GetRight() : b.GetRight();
		INT intersectBottom = (a.GetBottom() < b.GetBottom())
					? a.GetBottom() : b.GetBottom();
		c.X = intersectLeft;
		c.Y = intersectTop;
		c.Width = intersectRight - intersectLeft;
		c.Height = intersectBottom - intersectTop;
		return !c.IsEmptyArea();  
	}
	BOOL Intersect(const RectF& rect) {
		return Intersect(*this, *this, rect);
	}
	BOOL IntersectsWith(const RectF& rc) const {
		INT intersectLeft   = (X < rc.X) ? rc.X : X;
		INT intersectTop    = (Y < rc.Y) ? rc.Y : Y; 
		INT intersectRight  = (GetRight() < rc.GetRight())
					? GetRight() : rc.GetRight();
		INT intersectBottom = (GetBottom() < rc.GetBottom())
					? GetBottom() : rc.GetBottom();
		return intersectLeft < intersectRight
			&& intersectTop < intersectBottom;
	}
	VOID Offset(REAL dx, REAL dy) {
		X += dx;
		Y += dy;
	}
	VOID Offset(const PointF& point) {
		Offset(point.X, point.Y);
	}
	static BOOL Union(RectF& c, const RectF& a, const RectF& b) {
		INT unionLeft   = (a.X < b.X) ? a.X : b.X;
		INT unionTop    = (a.Y < b.Y) ? a.Y : b.Y; 
		INT unionRight  = (a.GetRight() < b.GetRight())
					? b.GetRight() : a.GetRight();
		INT unionBottom = (a.GetBottom() < b.GetBottom())
					? b.GetBottom() : a.GetBottom();
		c.X = unionLeft;
		c.Y = unionTop;
		c.Width = unionRight - unionLeft;
		c.Height = unionBottom - unionTop;
		return !c.IsEmptyArea();
	}
	#endif /* __cplusplus */
} RectF;

/* FIXME: Are descendants of this class, when compiled with g++,
   binary compatible with MSVC++ code (especially GDIPLUS.DLL of course)? */
#ifdef __cplusplus
struct GdiplusAbort {
	virtual HRESULT __stdcall Abort(void) {}
};
#else
typedef struct GdiplusAbort GdiplusAbort;  /* incomplete type */
#endif

typedef struct CharacterRange {
	INT First;
	INT Length;

	#ifdef __cplusplus
	CharacterRange(): First(0), Length(0) {}
	CharacterRange(INT first, INT length): First(first), Length(length) {}
	CharacterRange& operator=(const CharacterRange& rhs) {
		/* This gracefully handles self-assignment */
		First = rhs.First;
		Length = rhs.Length;
		return *this;
	}
	#endif /* __cplusplus */
} CharacterRange;

typedef struct PathData {
	INT Count;
	PointF *Points;
	BYTE *Types;

	#ifdef __cplusplus
	friend class GraphicsPath;

	PathData(): Count(0), Points(NULL), Types(NULL) {}
	~PathData() {
		FreeArrays();
	}
private:
	/* used by GraphicsPath::GetPathData, defined in gdipluspath.h */
	Status AllocateArrays(INT capacity);
	VOID FreeArrays();
	#endif /* __cplusplus */
} PathData;

/* Callback function types */
/* FIXME: need a correct definition for these function pointer types */
typedef void *DebugEventProc;
typedef BOOL CALLBACK (*EnumerateMetafileProc)(EmfPlusRecordType,UINT,UINT,const BYTE*,VOID*);
typedef void *DrawImageAbort;
typedef void *GetThumbnailImageAbort;


#endif /* __GDIPLUS_TYPES_H */
