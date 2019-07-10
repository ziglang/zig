/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _D2D1_1HELPER_H_
#define _D2D1_1HELPER_H_

#ifndef D2D_USE_C_DEFINITIONS

namespace D2D1 {
    template<> struct TypeTraits<INT32> {
        typedef D2D1_POINT_2L Point;
        typedef D2D1_RECT_L Rect;
    };

    template<> struct TypeTraits<LONG> {
        typedef D2D1_POINT_2L Point;
        typedef D2D1_RECT_L Rect;
    };

    D2D1FORCEINLINE D2D1_LAYER_PARAMETERS1 LayerParameters1(CONST D2D1_RECT_F &contentBounds = D2D1::InfiniteRect(),
            ID2D1Geometry *geometricMask = NULL, D2D1_ANTIALIAS_MODE maskAntialiasMode = D2D1_ANTIALIAS_MODE_PER_PRIMITIVE,
            D2D1_MATRIX_3X2_F maskTransform = D2D1::IdentityMatrix(), FLOAT opacity = 1.0, ID2D1Brush *opacityBrush = NULL,
            D2D1_LAYER_OPTIONS1 layerOptions = D2D1_LAYER_OPTIONS1_NONE) {
        D2D1_LAYER_PARAMETERS1 r = {contentBounds, geometricMask, maskAntialiasMode, maskTransform, opacity,
                                    opacityBrush, layerOptions};
        return r;
    }

    D2D1FORCEINLINE D2D1_IMAGE_BRUSH_PROPERTIES ImageBrushProperties(D2D1_RECT_F sourceRectangle,
            D2D1_EXTEND_MODE extendModeX = D2D1_EXTEND_MODE_CLAMP, D2D1_EXTEND_MODE extendModeY = D2D1_EXTEND_MODE_CLAMP,
            D2D1_INTERPOLATION_MODE interpolationMode = D2D1_INTERPOLATION_MODE_LINEAR) {
        D2D1_IMAGE_BRUSH_PROPERTIES r = {sourceRectangle, extendModeX, extendModeY, interpolationMode};
        return r;
    }

    D2D1FORCEINLINE D2D1_BITMAP_PROPERTIES1 BitmapProperties1(D2D1_BITMAP_OPTIONS bitmapOptions = D2D1_BITMAP_OPTIONS_NONE,
            CONST D2D1_PIXEL_FORMAT pixelFormat = D2D1::PixelFormat(), FLOAT dpiX = 96.0f, FLOAT dpiY = 96.0f,
            ID2D1ColorContext *colorContext = NULL) {
        D2D1_BITMAP_PROPERTIES1 r = {pixelFormat, dpiX, dpiY, bitmapOptions, colorContext};
        return r;
    }

    D2D1FORCEINLINE D2D1_BITMAP_BRUSH_PROPERTIES1 BitmapBrushProperties1(D2D1_EXTEND_MODE extendmodeX = D2D1_EXTEND_MODE_CLAMP,
            D2D1_EXTEND_MODE extendmodeY = D2D1_EXTEND_MODE_CLAMP,
            D2D1_INTERPOLATION_MODE interpolationMode = D2D1_INTERPOLATION_MODE_LINEAR) {
        D2D1_BITMAP_BRUSH_PROPERTIES1 r = {extendmodeX, extendmodeY, interpolationMode};
        return r;
    }

    class Matrix5x4F : public D2D1_MATRIX_5X4_F {
    public:
        inline Matrix5x4F(
                FLOAT m11, FLOAT m12, FLOAT m13, FLOAT m14,
                FLOAT m21, FLOAT m22, FLOAT m23, FLOAT m24,
                FLOAT m31, FLOAT m32, FLOAT m33, FLOAT m34,
                FLOAT m41, FLOAT m42, FLOAT m43, FLOAT m44,
                FLOAT m51, FLOAT m52, FLOAT m53, FLOAT m54) {
            _11 = m11; _12 = m12; _13 = m13; _14 = m14;
            _21 = m21; _22 = m22; _23 = m23; _24 = m24;
            _31 = m31; _32 = m32; _33 = m33; _34 = m34;
            _41 = m41; _42 = m42; _43 = m43; _44 = m44;
            _51 = m51; _52 = m52; _53 = m53; _54 = m54;
        }

        inline Matrix5x4F() {
            _11 = 1; _12 = 0; _13 = 0; _14 = 0;
            _21 = 0; _22 = 1; _23 = 0; _24 = 0;
            _31 = 0; _32 = 0; _33 = 1; _34 = 0;
            _41 = 0; _42 = 0; _43 = 0; _44 = 1;
            _51 = 0; _52 = 0; _53 = 0; _54 = 0;
        }
    };

    D2D1FORCEINLINE D2D1_VECTOR_2F Vector2F(FLOAT x = 0.0f, FLOAT y = 0.0f) {
        D2D1_VECTOR_2F r = {x, y};
        return r;
    }

    D2D1FORCEINLINE D2D1_VECTOR_3F Vector3F(FLOAT x = 0.0f, FLOAT y = 0.0f, FLOAT z = 0.0f) {
        D2D1_VECTOR_3F r = {x, y, z};
        return r;
    }

    D2D1FORCEINLINE D2D1_VECTOR_4F Vector4F(FLOAT x = 0.0f, FLOAT y = 0.0f, FLOAT z = 0.0f, FLOAT w = 0.0f) {
        D2D1_VECTOR_4F r = {x, y, z, w};
        return r;
    }

    D2D1FORCEINLINE D2D1_POINT_2L Point2L(INT32 x = 0, INT32 y = 0) {
        return Point2<INT32>(x, y);
    }

    D2D1FORCEINLINE D2D1_RECT_L RectL(INT32 left = 0.0f, INT32 top = 0.0f, INT32 right = 0.0f, INT32 bottom = 0.0f) {
        return Rect<INT32>(left, top, right, bottom);
    }
}

#endif /* D2D_USE_C_DEFINITIONS */

#endif /* _D2D1_1HELPER_H_ */
