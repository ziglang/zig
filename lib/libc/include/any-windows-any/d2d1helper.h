/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_D2D1HELPER
#define _INC_D2D1HELPER

#ifndef D2D_USE_C_DEFINITIONS

namespace D2D1 {

D2D1FORCEINLINE D2D1_MATRIX_3X2_F IdentityMatrix();

template<typename T> struct TypeTraits {
    typedef D2D1_POINT_2F  Point;
    typedef D2D1_SIZE_F    Size;
    typedef D2D1_RECT_F    Rect;
};

template<> struct TypeTraits<UINT32> {
    typedef D2D1_POINT_2U  Point;
    typedef D2D1_SIZE_U    Size;
    typedef D2D1_RECT_U    Rect;
};

static inline FLOAT FloatMax() {
    return 3.402823466e+38f;
}

template<typename T> D2D1FORCEINLINE typename TypeTraits<T>::Point Point2(T x, T y) {
    typename TypeTraits<T>::Point r = {x,y};
    return r;
}

D2D1FORCEINLINE D2D1_POINT_2F Point2F(FLOAT x = 0.f, FLOAT y = 0.f) {
    return Point2<FLOAT>(x, y);
}

D2D1FORCEINLINE D2D1_POINT_2U Point2U(UINT32 x = 0, UINT32 y = 0) {
    return Point2<UINT32>(x, y);
}

template<typename T> D2D1FORCEINLINE typename TypeTraits<T>::Size Size(T width, T height) {
    typename TypeTraits<T>::Size r = {width, height};
    return r;
}

D2D1FORCEINLINE D2D1_SIZE_F SizeF(FLOAT width = 0.0f, FLOAT height = 0.0f) {
    return Size<FLOAT>(width, height);
}

D2D1FORCEINLINE D2D1_SIZE_U SizeU(UINT32 width = 0, UINT32 height = 0) {
    return Size<UINT32>(width, height);
}

template<typename T> D2D1FORCEINLINE typename TypeTraits<T>::Rect Rect(T left, T top, T right, T bottom) {
    typename TypeTraits<T>::Rect r = {left, top, right, bottom};
    return r;
}

D2D1FORCEINLINE D2D1_RECT_F RectF(FLOAT left = 0.0f, FLOAT top = 0.0f, FLOAT right = 0.0f, FLOAT bottom = 0.0f) {
    return Rect<FLOAT>(left, top, right, bottom);
}

D2D1FORCEINLINE D2D1_RECT_U RectU(UINT32 left = 0, UINT32 top = 0, UINT32 right = 0, UINT32 bottom = 0) {
    return Rect<UINT32>(left, top, right, bottom);
}

D2D1FORCEINLINE D2D1_RECT_F InfiniteRect() {
    D2D1_RECT_F r = {-FloatMax(), -FloatMax(), FloatMax(),  FloatMax()};
    return r;
}

D2D1FORCEINLINE D2D1_ARC_SEGMENT ArcSegment(const D2D1_POINT_2F &point, const D2D1_SIZE_F &size, const FLOAT rotationAngle, D2D1_SWEEP_DIRECTION sweepDirection, D2D1_ARC_SIZE arcSize) {
    D2D1_ARC_SEGMENT r = {point, size, rotationAngle, sweepDirection, arcSize};
    return r;
}

D2D1FORCEINLINE D2D1_BEZIER_SEGMENT BezierSegment(const D2D1_POINT_2F &point1, const D2D1_POINT_2F &point2, const D2D1_POINT_2F &point3) {
    D2D1_BEZIER_SEGMENT r = {point1, point2, point3};
    return r;
}

D2D1FORCEINLINE D2D1_ELLIPSE Ellipse(const D2D1_POINT_2F &center, FLOAT radiusX, FLOAT radiusY) {
    D2D1_ELLIPSE r = {center, radiusX, radiusY};
    return r;
}

D2D1FORCEINLINE D2D1_ROUNDED_RECT RoundedRect(const D2D1_RECT_F &rect, FLOAT radiusX, FLOAT radiusY) {
    D2D1_ROUNDED_RECT r = {rect, radiusX, radiusY};
    return r;
}

D2D1FORCEINLINE D2D1_BRUSH_PROPERTIES BrushProperties(
        FLOAT opacity = 1.0f,
        const D2D1_MATRIX_3X2_F &transform = D2D1::IdentityMatrix()) {
    D2D1_BRUSH_PROPERTIES r = {opacity, transform};
    return r;
}

D2D1FORCEINLINE D2D1_GRADIENT_STOP GradientStop(FLOAT position, const D2D1_COLOR_F &color) {
    D2D1_GRADIENT_STOP r = {position, color};
    return r;
}

D2D1FORCEINLINE D2D1_QUADRATIC_BEZIER_SEGMENT QuadraticBezierSegment(const D2D1_POINT_2F &point1, const D2D1_POINT_2F &point2) {
    D2D1_QUADRATIC_BEZIER_SEGMENT r = {point1, point2};
    return r;
}

D2D1FORCEINLINE D2D1_STROKE_STYLE_PROPERTIES StrokeStyleProperties(
        D2D1_CAP_STYLE startCap = D2D1_CAP_STYLE_FLAT,
        D2D1_CAP_STYLE endCap = D2D1_CAP_STYLE_FLAT,
        D2D1_CAP_STYLE dashCap = D2D1_CAP_STYLE_FLAT,
        D2D1_LINE_JOIN lineJoin = D2D1_LINE_JOIN_MITER,
        FLOAT miterLimit = 10.0f,
        D2D1_DASH_STYLE dashStyle = D2D1_DASH_STYLE_SOLID,
        FLOAT dashOffset = 0.0f) {
    D2D1_STROKE_STYLE_PROPERTIES r = {startCap, endCap, dashCap, lineJoin, miterLimit, dashStyle, dashOffset};
    return r;
}

D2D1FORCEINLINE D2D1_BITMAP_BRUSH_PROPERTIES BitmapBrushProperties(
        D2D1_EXTEND_MODE extendModeX = D2D1_EXTEND_MODE_CLAMP,
        D2D1_EXTEND_MODE extendModeY = D2D1_EXTEND_MODE_CLAMP,
        D2D1_BITMAP_INTERPOLATION_MODE interpolationMode = D2D1_BITMAP_INTERPOLATION_MODE_LINEAR) {
    D2D1_BITMAP_BRUSH_PROPERTIES r = {extendModeX, extendModeY, interpolationMode};
    return r;
}

D2D1FORCEINLINE D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES LinearGradientBrushProperties(const D2D1_POINT_2F &startPoint, const D2D1_POINT_2F &endPoint) {
    D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES r = {startPoint, endPoint};
    return r;
}

D2D1FORCEINLINE D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES RadialGradientBrushProperties(const D2D1_POINT_2F &center, const D2D1_POINT_2F &gradientOriginOffset, FLOAT radiusX, FLOAT radiusY) {
    D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES r = {center, gradientOriginOffset, radiusX, radiusY};
    return r;
}

D2D1FORCEINLINE D2D1_PIXEL_FORMAT PixelFormat(
        DXGI_FORMAT dxgiFormat = DXGI_FORMAT_UNKNOWN,
        D2D1_ALPHA_MODE alphaMode = D2D1_ALPHA_MODE_UNKNOWN)
{
    D2D1_PIXEL_FORMAT r = {dxgiFormat, alphaMode};
    return r;
}

D2D1FORCEINLINE D2D1_BITMAP_PROPERTIES BitmapProperties(CONST D2D1_PIXEL_FORMAT &pixelFormat = D2D1::PixelFormat(),
        FLOAT dpiX = 96.0f, FLOAT dpiY = 96.0f) {
    D2D1_BITMAP_PROPERTIES r = {pixelFormat, dpiX, dpiY};
    return r;
}

D2D1FORCEINLINE D2D1_RENDER_TARGET_PROPERTIES RenderTargetProperties(
        D2D1_RENDER_TARGET_TYPE type =  D2D1_RENDER_TARGET_TYPE_DEFAULT,
        CONST D2D1_PIXEL_FORMAT &pixelFormat = D2D1::PixelFormat(),
        FLOAT dpiX = 0.0,
        FLOAT dpiY = 0.0,
        D2D1_RENDER_TARGET_USAGE usage = D2D1_RENDER_TARGET_USAGE_NONE,
        D2D1_FEATURE_LEVEL  minLevel = D2D1_FEATURE_LEVEL_DEFAULT)
{
    D2D1_RENDER_TARGET_PROPERTIES r = {type, pixelFormat, dpiX, dpiY, usage, minLevel};
    return r;
}

D2D1FORCEINLINE D2D1_HWND_RENDER_TARGET_PROPERTIES HwndRenderTargetProperties(
        HWND hwnd,
        D2D1_SIZE_U pixelSize = D2D1::Size(static_cast<UINT>(0), static_cast<UINT>(0)),
        D2D1_PRESENT_OPTIONS presentOptions = D2D1_PRESENT_OPTIONS_NONE) {
    D2D1_HWND_RENDER_TARGET_PROPERTIES r = {hwnd, pixelSize, presentOptions};
    return r;
}

D2D1FORCEINLINE D2D1_LAYER_PARAMETERS LayerParameters(
        CONST D2D1_RECT_F &contentBounds = D2D1::InfiniteRect(),
        ID2D1Geometry *geometricMask = NULL,
        D2D1_ANTIALIAS_MODE maskAntialiasMode = D2D1_ANTIALIAS_MODE_PER_PRIMITIVE,
        D2D1_MATRIX_3X2_F maskTransform = D2D1::IdentityMatrix(),
        FLOAT opacity = 1.0,
        ID2D1Brush *opacityBrush = NULL,
        D2D1_LAYER_OPTIONS layerOptions = D2D1_LAYER_OPTIONS_NONE) {
    D2D1_LAYER_PARAMETERS r =
        {contentBounds, geometricMask, maskAntialiasMode, maskTransform, opacity, opacityBrush, layerOptions };
    return r;
}

D2D1FORCEINLINE D2D1_DRAWING_STATE_DESCRIPTION DrawingStateDescription(
        D2D1_ANTIALIAS_MODE antialiasMode = D2D1_ANTIALIAS_MODE_PER_PRIMITIVE,
        D2D1_TEXT_ANTIALIAS_MODE textAntialiasMode = D2D1_TEXT_ANTIALIAS_MODE_DEFAULT,
        D2D1_TAG tag1 = 0,
        D2D1_TAG tag2 = 0,
        const D2D1_MATRIX_3X2_F &transform = D2D1::IdentityMatrix()) {
    D2D1_DRAWING_STATE_DESCRIPTION r = {antialiasMode, textAntialiasMode, tag1, tag2, transform};
    return r;
}

class ColorF : public D2D1_COLOR_F {
public:
    enum Enum {
        AliceBlue             = 0xf0f8ff,
        AntiqueWhite          = 0xfaebd7,
        Aqua                  = 0x00ffff,
        Aquamarine            = 0x7fffd4,
        Azure                 = 0xf0ffff,
        Beige                 = 0xf5f5dc,
        Bisque                = 0xffe4c4,
        Black                 = 0x000000,
        BlanchedAlmond        = 0xffebcd,
        Blue                  = 0x0000ff,
        BlueViolet            = 0x8a2be2,
        Brown                 = 0xa52a2a,
        BurlyWood             = 0xdeb887,
        CadetBlue             = 0x5f9ea0,
        Chartreuse            = 0x7fff00,
        Chocolate             = 0xd2691e,
        Coral                 = 0xff7f50,
        CornflowerBlue        = 0x6495ed,
        Cornsilk              = 0xfff8dc,
        Crimson               = 0xdc143c,
        Cyan                  = 0x00ffff,
        DarkBlue              = 0x00008b,
        DarkCyan              = 0x008b8b,
        DarkGoldenrod         = 0xb8860b,
        DarkGray              = 0xa9a9a9,
        DarkGreen             = 0x006400,
        DarkKhaki             = 0xbdb76b,
        DarkMagenta           = 0x8b008b,
        DarkOliveGreen        = 0x556B2f,
        DarkOrange            = 0xff8c00,
        DarkOrchid            = 0x9932cc,
        DarkRed               = 0x8b0000,
        DarkSalmon            = 0xe9967a,
        DarkSeaGreen          = 0x8fbc8f,
        DarkSlateBlue         = 0x483d8b,
        DarkSlateGray         = 0x2f4f4f,
        DarkTurquoise         = 0x00ced1,
        DarkViolet            = 0x9400d3,
        DeepPink              = 0xff1493,
        DeepSkyBlue           = 0x00bfff,
        DimGray               = 0x696969,
        DodgerBlue            = 0x1e90ff,
        Firebrick             = 0xb22222,
        FloralWhite           = 0xfffaf0,
        ForestGreen           = 0x228b22,
        Fuchsia               = 0xff00ff,
        Gainsboro             = 0xdcdcdc,
        GhostWhite            = 0xf8f8ff,
        Gold                  = 0xffd700,
        Goldenrod             = 0xdaa520,
        Gray                  = 0x808080,
        Green                 = 0x008000,
        GreenYellow           = 0xadff2f,
        Honeydew              = 0xf0fff0,
        HotPink               = 0xff69b4,
        IndianRed             = 0xcd5c5c,
        Indigo                = 0x4b0082,
        Ivory                 = 0xfffff0,
        Khaki                 = 0xf0e68c,
        Lavender              = 0xe6e6fa,
        LavenderBlush         = 0xfff0f5,
        LawnGreen             = 0x7cfc00,
        LemonChiffon          = 0xfffacd,
        LightBlue             = 0xadd8e6,
        LightCoral            = 0xf08080,
        LightCyan             = 0xe0ffff,
        LightGoldenrodYellow  = 0xfafad2,
        LightGreen            = 0x90ee90,
        LightGray             = 0xd3d3d3,
        LightPink             = 0xffb6c1,
        LightSalmon           = 0xffa07a,
        LightSeaGreen         = 0x20b2aa,
        LightSkyBlue          = 0x87cefa,
        LightSlateGray        = 0x778899,
        LightSteelBlue        = 0xb0c4de,
        LightYellow           = 0xffffe0,
        Lime                  = 0x00ff00,
        LimeGreen             = 0x32cd32,
        Linen                 = 0xfaf0e6,
        Magenta               = 0xff00ff,
        Maroon                = 0x800000,
        MediumAquamarine      = 0x66cdaa,
        MediumBlue            = 0x0000cd,
        MediumOrchid          = 0xba55d3,
        MediumPurple          = 0x9370db,
        MediumSeaGreen        = 0x3cb371,
        MediumSlateBlue       = 0x7b68ee,
        MediumSpringGreen     = 0x00fa9a,
        MediumTurquoise       = 0x48d1cc,
        MediumVioletRed       = 0xc71585,
        MidnightBlue          = 0x191970,
        MintCream             = 0xf5fffa,
        MistyRose             = 0xffe4e1,
        Moccasin              = 0xffe4b5,
        NavajoWhite           = 0xffdead,
        Navy                  = 0x000080,
        OldLace               = 0xfdf5e6,
        Olive                 = 0x808000,
        OliveDrab             = 0x6b8e23,
        Orange                = 0xffa500,
        OrangeRed             = 0xff4500,
        Orchid                = 0xda70d6,
        PaleGoldenrod         = 0xeee8aa,
        PaleGreen             = 0x98fb98,
        PaleTurquoise         = 0xafeeee,
        PaleVioletRed         = 0xdb7093,
        PapayaWhip            = 0xffefd5,
        PeachPuff             = 0xffdab9,
        Peru                  = 0xcd853f,
        Pink                  = 0xffc0cb,
        Plum                  = 0xdda0dd,
        PowderBlue            = 0xb0e0e6,
        Purple                = 0x800080,
        Red                   = 0xff0000,
        RosyBrown             = 0xbc8f8f,
        RoyalBlue             = 0x4169e1,
        SaddleBrown           = 0x8b4513,
        Salmon                = 0xfa8072,
        SandyBrown            = 0xf4a460,
        SeaGreen              = 0x2e8B57,
        SeaShell              = 0xfff5ee,
        Sienna                = 0xa0522d,
        Silver                = 0xc0c0c0,
        SkyBlue               = 0x87ceeb,
        SlateBlue             = 0x6a5acd,
        SlateGray             = 0x708090,
        Snow                  = 0xfffafa,
        SpringGreen           = 0x00ff7f,
        SteelBlue             = 0x4682B4,
        Tan                   = 0xd2b48c,
        Teal                  = 0x008080,
        Thistle               = 0xd8bfd8,
        Tomato                = 0xff6347,
        Turquoise             = 0x40e0d0,
        Violet                = 0xee82ee,
        Wheat                 = 0xf5deb3,
        White                 = 0xffffff,
        WhiteSmoke            = 0xf5f5f5,
        Yellow                = 0xffff00,
        YellowGreen           = 0x9acd32
    };

    FORCEINLINE ColorF(UINT32 rgb, FLOAT _a = 1.0) {
        init(rgb, _a);
    }

    D2D1FORCEINLINE ColorF(Enum knownColor, FLOAT _a = 1.0) {
        init(knownColor, _a);
    }

    D2D1FORCEINLINE ColorF(FLOAT _r, FLOAT _g, FLOAT _b, FLOAT _a = 1.0) {
        r = _r;
        g = _g;
        b = _b;
        a = _a;
    }
private:
    D2D1FORCEINLINE void init(UINT32 rgb, FLOAT _a) {
        r = static_cast<float>((rgb>>16)&0xff)/255.0f;
        g = static_cast<float>((rgb>>8)&0xff)/255.0f;
        b = static_cast<float>(rgb&0xff)/255.0f;
        a = _a;
    }
};

class Matrix3x2F : public D2D1_MATRIX_3X2_F {
public:
    D2D1FORCEINLINE Matrix3x2F(FLOAT __11, FLOAT __12, FLOAT __21, FLOAT __22, FLOAT __31, FLOAT __32) {
        _11 = __11;
        _12 = __12;
        _21 = __21;
        _22 = __22;
        _31 = __31;
        _32 = __32;
    }

    D2D1FORCEINLINE Matrix3x2F() {}

    static D2D1FORCEINLINE Matrix3x2F Identity() {
        return Matrix3x2F(1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f);
    }

    static D2D1FORCEINLINE Matrix3x2F Translation(D2D1_SIZE_F size) {
        return Translation(size.width, size.height);
    }

    static D2D1FORCEINLINE Matrix3x2F Translation(FLOAT x, FLOAT y) {
        return Matrix3x2F(1.0f, 0.0f, 0.0f, 1.0f, x, y);
    }

    static D2D1FORCEINLINE Matrix3x2F Scale(D2D1_SIZE_F size, D2D1_POINT_2F center = D2D1::Point2F()) {
        return Scale(size.width, size.height, center);
    }

    static D2D1FORCEINLINE Matrix3x2F Scale(FLOAT x, FLOAT y, D2D1_POINT_2F center = D2D1::Point2F()) {
        return Matrix3x2F(x, 0.0f, 0.0f, y, center.x - x*center.x, center.y - y*center.y);
    }

    static D2D1FORCEINLINE Matrix3x2F Rotation(FLOAT angle, D2D1_POINT_2F center = D2D1::Point2F()) {
        Matrix3x2F r;
        D2D1MakeRotateMatrix(angle, center, &r);
        return r;
    }

    static D2D1FORCEINLINE Matrix3x2F Skew(FLOAT angleX, FLOAT angleY, D2D1_POINT_2F center = D2D1::Point2F()) {
        Matrix3x2F r;
        D2D1MakeSkewMatrix(angleX, angleY, center, &r);
        return r;
    }

    static inline const Matrix3x2F *ReinterpretBaseType(const D2D1_MATRIX_3X2_F *pMatrix) {
        return static_cast<const Matrix3x2F *>(pMatrix);
    }

    static inline Matrix3x2F *ReinterpretBaseType(D2D1_MATRIX_3X2_F *pMatrix) {
        return static_cast<Matrix3x2F *>(pMatrix);
    }

    inline FLOAT Determinant() const {
        return _11*_22 - _12*_21;
    }

    inline bool IsInvertible() const {
        return !!D2D1IsMatrixInvertible(this);
    }

    inline bool Invert() {
        return !!D2D1InvertMatrix(this);
    }

    inline bool IsIdentity() const {
        return _11 == 1.0f && _12 == 0.0f && _21 == 0.0f && _22 == 1.0f && _31 == 0.0f && _32 == 0.0f;
    }

    inline void SetProduct(const Matrix3x2F &a, const Matrix3x2F &b) {
        _11 = a._11*b._11 + a._12*b._21;
        _12 = a._11*b._12 + a._12*b._22;
        _21 = a._21*b._11 + a._22*b._21;
        _22 = a._21*b._12 + a._22*b._22;
        _31 = a._31*b._11 + a._32*b._21 + b._31;
        _32 = a._31*b._12 + a._32*b._22 + b._32;
    }

    D2D1FORCEINLINE Matrix3x2F operator*(const Matrix3x2F &matrix) const {
        Matrix3x2F r;
        r.SetProduct(*this, matrix);
        return r;
    }

    D2D1FORCEINLINE D2D1_POINT_2F TransformPoint(D2D1_POINT_2F point) const {
        return Point2F(point.x*_11 + point.y*_21 + _31, point.x*_12 + point.y*_22 + _32);
    }
};

D2D1FORCEINLINE D2D1_POINT_2F operator*(const D2D1_POINT_2F &point, const D2D1_MATRIX_3X2_F &matrix) {
    return Matrix3x2F::ReinterpretBaseType(&matrix)->TransformPoint(point);
}

D2D1FORCEINLINE D2D1_MATRIX_3X2_F IdentityMatrix() {
    return Matrix3x2F::Identity();
}

}

D2D1FORCEINLINE D2D1_MATRIX_3X2_F operator*(const D2D1_MATRIX_3X2_F &matrix1, const D2D1_MATRIX_3X2_F &matrix2) {
    D2D1::Matrix3x2F r;
    r.SetProduct(*D2D1::Matrix3x2F::ReinterpretBaseType(&matrix1), *D2D1::Matrix3x2F::ReinterpretBaseType(&matrix2));
    return r;
}

#endif /* D2D_USE_C_DEFINITIONS */

#endif /*_INC_D2D1HELPER*/
