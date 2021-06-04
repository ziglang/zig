/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef DIRECTXMATH_H
#define DIRECTXMATH_H

#ifndef __cplusplus
#error DirectX Math requires C++
#endif

#include <stdint.h>

#define DIRECTX_MATH_VERSION 314

#define XM_CONST const
#if __cplusplus >= 201103L
#define XM_CONSTEXPR constexpr
#else
#define XM_CONSTEXPR
#endif

namespace DirectX {

struct XMFLOAT2 {
  float x, y;
  XMFLOAT2() = default;
  XMFLOAT2(const XMFLOAT2&) = default;
  XMFLOAT2& operator=(const XMFLOAT2&) = default;
  XMFLOAT2(XMFLOAT2&&) = default;
  XMFLOAT2& operator=(XMFLOAT2&&) = default;
  XM_CONSTEXPR XMFLOAT2(float _x, float _y) : x(_x), y(_y) {}
  explicit XMFLOAT2(const float *pArray) : x(pArray[0]), y(pArray[1]) {}
};

struct __attribute__ ((__aligned__ (16))) XMFLOAT2A : public XMFLOAT2 {
  XMFLOAT2A() = default;
  XMFLOAT2A(const XMFLOAT2A&) = default;
  XMFLOAT2A& operator=(const XMFLOAT2A&) = default;
  XMFLOAT2A(XMFLOAT2A&&) = default;
  XMFLOAT2A& operator=(XMFLOAT2A&&) = default;
  XM_CONSTEXPR XMFLOAT2A(float _x, float _y) : XMFLOAT2(_x, _y) {}
  explicit XMFLOAT2A(const float *pArray) : XMFLOAT2(pArray) {}
};

struct XMINT2 {
  int32_t x, y;
  XMINT2() = default;
  XMINT2(const XMINT2&) = default;
  XMINT2& operator=(const XMINT2&) = default;
  XMINT2(XMINT2&&) = default;
  XMINT2& operator=(XMINT2&&) = default;
  XM_CONSTEXPR XMINT2(int32_t _x, int32_t _y) : x(_x), y(_y) {}
  explicit XMINT2(const int32_t *pArray) : x(pArray[0]), y(pArray[1]) {}
};

struct XMUINT2 {
  uint32_t x, y;
  XMUINT2() = default;
  XMUINT2(const XMUINT2&) = default;
  XMUINT2& operator=(const XMUINT2&) = default;
  XMUINT2(XMUINT2&&) = default;
  XMUINT2& operator=(XMUINT2&&) = default;
  XM_CONSTEXPR XMUINT2(uint32_t _x, uint32_t _y) : x(_x), y(_y) {}
  explicit XMUINT2(const uint32_t *pArray) : x(pArray[0]), y(pArray[1]) {}
};

struct XMFLOAT3 {
  float x, y, z;
  XMFLOAT3() = default;
  XMFLOAT3(const XMFLOAT3&) = default;
  XMFLOAT3& operator=(const XMFLOAT3&) = default;
  XMFLOAT3(XMFLOAT3&&) = default;
  XMFLOAT3& operator=(XMFLOAT3&&) = default;
  XM_CONSTEXPR XMFLOAT3(float _x, float _y, float _z) : x(_x), y(_y), z(_z) {}
  explicit XMFLOAT3(const float *pArray) : x(pArray[0]), y(pArray[1]), z(pArray[2]) {}
};

struct __attribute__ ((__aligned__ (16))) XMFLOAT3A : public XMFLOAT3 {
  XMFLOAT3A() = default;
  XMFLOAT3A(const XMFLOAT3A&) = default;
  XMFLOAT3A& operator=(const XMFLOAT3A&) = default;
  XMFLOAT3A(XMFLOAT3A&&) = default;
  XMFLOAT3A& operator=(XMFLOAT3A&&) = default;
  XM_CONSTEXPR XMFLOAT3A(float _x, float _y, float _z) : XMFLOAT3(_x, _y, _z) {}
  explicit XMFLOAT3A(const float *pArray) : XMFLOAT3(pArray) {}
};

struct XMINT3 {
  int32_t x, y, z;
  XMINT3() = default;
  XMINT3(const XMINT3&) = default;
  XMINT3& operator=(const XMINT3&) = default;
  XMINT3(XMINT3&&) = default;
  XMINT3& operator=(XMINT3&&) = default;
  XM_CONSTEXPR XMINT3(int32_t _x, int32_t _y, int32_t _z) : x(_x), y(_y), z(_z) {}
  explicit XMINT3(const int32_t *pArray) : x(pArray[0]), y(pArray[1]), z(pArray[2]) {}
};

struct XMUINT3 {
  uint32_t x, y, z;
  XMUINT3() = default;
  XMUINT3(const XMUINT3&) = default;
  XMUINT3& operator=(const XMUINT3&) = default;
  XMUINT3(XMUINT3&&) = default;
  XMUINT3& operator=(XMUINT3&&) = default;
  XM_CONSTEXPR XMUINT3(uint32_t _x, uint32_t _y, uint32_t _z) : x(_x), y(_y), z(_z) {}
  explicit XMUINT3(const uint32_t *pArray) : x(pArray[0]), y(pArray[1]), z(pArray[2]) {}
};

struct XMFLOAT4 {
  float x, y, z, w;
  XMFLOAT4() = default;
  XMFLOAT4(const XMFLOAT4&) = default;
  XMFLOAT4& operator=(const XMFLOAT4&) = default;
  XMFLOAT4(XMFLOAT4&&) = default;
  XMFLOAT4& operator=(XMFLOAT4&&) = default;
  XM_CONSTEXPR XMFLOAT4(float _x, float _y, float _z, float _w) : x(_x), y(_y), z(_z), w(_w) {}
  explicit XMFLOAT4(const float *pArray) : x(pArray[0]), y(pArray[1]), z(pArray[2]), w(pArray[3]) {}
};

struct __attribute__ ((__aligned__ (16))) XMFLOAT4A : public XMFLOAT4 {
  XMFLOAT4A() = default;
  XMFLOAT4A(const XMFLOAT4A&) = default;
  XMFLOAT4A& operator=(const XMFLOAT4A&) = default;
  XMFLOAT4A(XMFLOAT4A&&) = default;
  XMFLOAT4A& operator=(XMFLOAT4A&&) = default;
  XM_CONSTEXPR XMFLOAT4A(float _x, float _y, float _z, float _w) : XMFLOAT4(_x, _y, _z, _w) {}
  explicit XMFLOAT4A(const float *pArray) : XMFLOAT4(pArray) {}
};

struct XMINT4 {
  int32_t x, y, z, w;
  XMINT4() = default;
  XMINT4(const XMINT4&) = default;
  XMINT4& operator=(const XMINT4&) = default;
  XMINT4(XMINT4&&) = default;
  XMINT4& operator=(XMINT4&&) = default;
  XM_CONSTEXPR XMINT4(int32_t _x, int32_t _y, int32_t _z, int32_t _w) : x(_x), y(_y), z(_z), w(_w) {}
  explicit XMINT4(const int32_t *pArray) : x(pArray[0]), y(pArray[1]), z(pArray[2]), w(pArray[3]) {}
};

struct XMUINT4 {
  uint32_t x, y, z, w;
  XMUINT4() = default;
  XMUINT4(const XMUINT4&) = default;
  XMUINT4& operator=(const XMUINT4&) = default;
  XMUINT4(XMUINT4&&) = default;
  XMUINT4& operator=(XMUINT4&&) = default;
  XM_CONSTEXPR XMUINT4(uint32_t _x, uint32_t _y, uint32_t _z, uint32_t _w) : x(_x), y(_y), z(_z), w(_w) {}
  explicit XMUINT4(const uint32_t *pArray) : x(pArray[0]), y(pArray[1]), z(pArray[2]), w(pArray[3]) {}
};

struct XMFLOAT3X3 {
  union
  {
    struct
    {
      float _11, _12, _13;
      float _21, _22, _23;
      float _31, _32, _33;
    };
    float m[3][3];
  };

  XMFLOAT3X3() = default;
  XMFLOAT3X3(const XMFLOAT3X3&) = default;
  XMFLOAT3X3& operator=(const XMFLOAT3X3&) = default;
  XMFLOAT3X3(XMFLOAT3X3&&) = default;
  XMFLOAT3X3& operator=(XMFLOAT3X3&&) = default;
  XM_CONSTEXPR XMFLOAT3X3(
    float m00, float m01, float m02,
    float m10, float m11, float m12,
    float m20, float m21, float m22)
    : _11(m00), _12(m01), _13(m02),
      _21(m10), _22(m11), _23(m12),
      _31(m20), _32(m21), _33(m22) {}
  explicit XMFLOAT3X3(const float *pArray);
  float operator() (size_t Row, size_t Column) const { return m[Row][Column]; }
  float& operator() (size_t Row, size_t Column) { return m[Row][Column]; }
  };

struct XMFLOAT4X3 {
  union
  {
    struct
    {
      float _11, _12, _13;
      float _21, _22, _23;
      float _31, _32, _33;
      float _41, _42, _43;
    };
    float m[4][3];
    float f[12];
  };

  XMFLOAT4X3() = default;
  XMFLOAT4X3(const XMFLOAT4X3&) = default;
  XMFLOAT4X3& operator=(const XMFLOAT4X3&) = default;
  XMFLOAT4X3(XMFLOAT4X3&&) = default;
  XMFLOAT4X3& operator=(XMFLOAT4X3&&) = default;
  XM_CONSTEXPR XMFLOAT4X3(
    float m00, float m01, float m02,
    float m10, float m11, float m12,
    float m20, float m21, float m22,
    float m30, float m31, float m32)
    : _11(m00), _12(m01), _13(m02),
      _21(m10), _22(m11), _23(m12),
      _31(m20), _32(m21), _33(m22),
      _41(m30), _42(m31), _43(m32) {}
  explicit XMFLOAT4X3(const float *pArray);
  float operator() (size_t Row, size_t Column) const { return m[Row][Column]; }
  float& operator() (size_t Row, size_t Column) { return m[Row][Column]; }
};

struct __attribute__ ((__aligned__ (16))) XMFLOAT4X3A : public XMFLOAT4X3 {
  XMFLOAT4X3A() = default;
  XMFLOAT4X3A(const XMFLOAT4X3A&) = default;
  XMFLOAT4X3A& operator=(const XMFLOAT4X3A&) = default;
  XMFLOAT4X3A(XMFLOAT4X3A&&) = default;
  XMFLOAT4X3A& operator=(XMFLOAT4X3A&&) = default;
  XM_CONSTEXPR XMFLOAT4X3A(
    float m00, float m01, float m02,
    float m10, float m11, float m12,
    float m20, float m21, float m22,
    float m30, float m31, float m32) :
    XMFLOAT4X3(m00,m01,m02,m10,m11,m12,m20,m21,m22,m30,m31,m32) {}
  explicit XMFLOAT4X3A(const float *pArray) : XMFLOAT4X3(pArray) {}
};

struct XMFLOAT3X4 {
  union
  {
    struct
    {
      float _11, _12, _13, _14;
      float _21, _22, _23, _24;
      float _31, _32, _33, _34;
    };
    float m[3][4];
    float f[12];
  };

  XMFLOAT3X4() = default;
  XMFLOAT3X4(const XMFLOAT3X4&) = default;
  XMFLOAT3X4& operator=(const XMFLOAT3X4&) = default;
  XMFLOAT3X4(XMFLOAT3X4&&) = default;
  XMFLOAT3X4& operator=(XMFLOAT3X4&&) = default;
  XM_CONSTEXPR XMFLOAT3X4(
    float m00, float m01, float m02, float m03,
    float m10, float m11, float m12, float m13,
    float m20, float m21, float m22, float m23)
    : _11(m00), _12(m01), _13(m02), _14(m03),
      _21(m10), _22(m11), _23(m12), _24(m13),
      _31(m20), _32(m21), _33(m22), _34(m23) {}
  explicit XMFLOAT3X4(const float *pArray);
  float operator() (size_t Row, size_t Column) const { return m[Row][Column]; }
  float& operator() (size_t Row, size_t Column) { return m[Row][Column]; }
};

struct __attribute__ ((__aligned__ (16))) XMFLOAT3X4A : public XMFLOAT3X4 {
  XMFLOAT3X4A() = default;
  XMFLOAT3X4A(const XMFLOAT3X4A&) = default;
  XMFLOAT3X4A& operator=(const XMFLOAT3X4A&) = default;
  XMFLOAT3X4A(XMFLOAT3X4A&&) = default;
  XMFLOAT3X4A& operator=(XMFLOAT3X4A&&) = default;
  XM_CONSTEXPR XMFLOAT3X4A(
    float m00, float m01, float m02, float m03,
    float m10, float m11, float m12, float m13,
    float m20, float m21, float m22, float m23) :
    XMFLOAT3X4(m00, m01, m02, m03, m10, m11, m12, m13, m20, m21, m22, m23) {}
  explicit XMFLOAT3X4A(const float *pArray) : XMFLOAT3X4(pArray) {}
};

struct XMFLOAT4X4 {
  union
  {
    struct
    {
      float _11, _12, _13, _14;
      float _21, _22, _23, _24;
      float _31, _32, _33, _34;
      float _41, _42, _43, _44;
    };
    float m[4][4];
  };

  XMFLOAT4X4() = default;
  XMFLOAT4X4(const XMFLOAT4X4&) = default;
  XMFLOAT4X4& operator=(const XMFLOAT4X4&) = default;
  XMFLOAT4X4(XMFLOAT4X4&&) = default;
  XMFLOAT4X4& operator=(XMFLOAT4X4&&) = default;
  XM_CONSTEXPR XMFLOAT4X4(
    float m00, float m01, float m02, float m03,
    float m10, float m11, float m12, float m13,
    float m20, float m21, float m22, float m23,
    float m30, float m31, float m32, float m33)
    : _11(m00), _12(m01), _13(m02), _14(m03),
      _21(m10), _22(m11), _23(m12), _24(m13),
      _31(m20), _32(m21), _33(m22), _34(m23),
      _41(m30), _42(m31), _43(m32), _44(m33) {}
  explicit XMFLOAT4X4(const float *pArray);
  float operator() (size_t Row, size_t Column) const { return m[Row][Column]; }
  float& operator() (size_t Row, size_t Column) { return m[Row][Column]; }
};

struct __attribute__ ((__aligned__ (16))) XMFLOAT4X4A : public XMFLOAT4X4 {
  XMFLOAT4X4A() = default;
  XMFLOAT4X4A(const XMFLOAT4X4A&) = default;
  XMFLOAT4X4A& operator=(const XMFLOAT4X4A&) = default;
  XMFLOAT4X4A(XMFLOAT4X4A&&) = default;
  XMFLOAT4X4A& operator=(XMFLOAT4X4A&&) = default;
  XM_CONSTEXPR XMFLOAT4X4A(
    float m00, float m01, float m02, float m03,
    float m10, float m11, float m12, float m13,
    float m20, float m21, float m22, float m23,
    float m30, float m31, float m32, float m33)
    : XMFLOAT4X4(m00,m01,m02,m03,m10,m11,m12,m13,m20,m21,m22,m23,m30,m31,m32,m33) {}
  explicit XMFLOAT4X4A(const float *pArray) : XMFLOAT4X4(pArray) {}
};

} /* namespace DirectX */

#endif /* DIRECTXMATH_H */
