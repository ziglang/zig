/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

/**
 * Normal users should include `windowsnumerics.h` instead of this header.
 * However, the cppwinrt headers set `_WINDOWS_NUMERICS_NAMESPACE_`,
 * `_WINDOWS_NUMERICS_BEGIN_NAMESPACE_` and `_WINDOWS_NUMERICS_END_NAMESPACE_`
 * to custom values and include `windowsnumerics.impl.h`. Therefore this shall
 * be considered a public header, and these macros are public API.
*/


#ifdef min
#  pragma push_macro("min")
#  undef min
#  define _WINDOWS_NUMERICS_IMPL_PUSHED_MIN_
#endif

#ifdef max
#  pragma push_macro("max")
#  undef max
#  define _WINDOWS_NUMERICS_IMPL_PUSHED_MAX_
#endif

#include <algorithm>
#include <cmath>

#include "directxmath.h"


// === Internal macros ===
#define _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(_ty1, _op, _ty2) \
  inline _ty1 &operator _op ## =(_ty1 &val1, _ty2 val2) { \
    val1 = operator _op (val1, val2); \
    return val1; \
  }


// === Internal functions ===
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {
  namespace _impl {

#if 0 && defined(__cpp_lib_clamp)
    using std::clamp;
#else
    constexpr const float &clamp(const float &val, const float &min, const float &max) {
      return val < min ? min : (val > max ? max : val);
    }
#endif

#if 0 && defined(__cpp_lib_interpolate)
    using std::lerp;
#else
    constexpr float lerp(float val1, float val2, float amount) {
      // Don't do (val2 - val1) * amount + val1 as it has worse precision.
      return val2 * amount + val1 * (1.0f - amount);
    }
#endif

  }
} _WINDOWS_NUMERICS_END_NAMESPACE_


// === Forward decls ===
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {

  struct float2;
  struct float3;
  struct float4;
  struct float3x2;
  struct float4x4;
  struct plane;
  struct quaternion;

} _WINDOWS_NUMERICS_END_NAMESPACE_


// === float2: Struct and function defs ===
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {

  struct float2 {
    float2() = default;
    constexpr float2(float x, float y)
      : x(x), y(y)
    {}
    constexpr explicit float2(float val)
      : x(val), y(val)
    {}

    static constexpr float2 zero() {
      return float2(0.0f);
    }
    static constexpr float2 one() {
      return float2(1.0f);
    }
    static constexpr float2 unit_x() {
      return { 1.0f, 0.0f };
    }
    static constexpr float2 unit_y() {
      return { 0.0f, 1.0f };
    }

    float x;
    float y;
  };

  // Forward decl functions
  inline float length(const float2 &val);
  inline float length_squared(const float2 &val);
  inline float distance(const float2 &val1, const float2 &val2);
  inline float distance_squared(const float2 &val1, const float2 &val2);
  inline float dot(const float2 &val1, const float2 &val2);
  inline float2 normalize(const float2 &val);
  inline float2 reflect(const float2 &vec, const float2 &norm);
  inline float2 min(const float2 &val1, const float2 &val2);
  inline float2 max(const float2 &val1, const float2 &val2);
  inline float2 clamp(const float2 &val, const float2 &min, const float2 &max);
  inline float2 lerp(const float2 &val1, const float2 &val2, float amount);
  inline float2 transform(const float2 &pos, const float3x2 &mat);
  inline float2 transform(const float2 &pos, const float4x4 &mat);
  inline float2 transform_normal(const float2 &norm, const float3x2 &mat);
  inline float2 transform_normal(const float2 &norm, const float4x4 &mat);
  inline float2 transform(const float2 &val, const quaternion &rot);

  // Define operators
#define _WINDOWS_NUMERICS_IMPL_BINARY_OP(_ty, _op) \
  inline _ty operator _op(const _ty &val1, const _ty &val2) { \
    return { val1.x _op val2.x, val1.y _op val2.y }; \
  }
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float2, +)
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float2, -)
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float2, *)
  inline float2 operator*(const float2 &val1, float val2) {
    return { val1.x * val2, val1.y * val2 };
  }
  inline float2 operator*(float val1, const float2 &val2) {
    return operator*(val2, val1);
  }
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float2, /)
  inline float2 operator/(const float2 &val1, float val2) {
    return operator*(val1, 1.0f / val2);
  }
  inline float2 operator-(const float2 &val) {
    return { -val.x, -val.y };
  }
#undef _WINDOWS_NUMERICS_IMPL_BINARY_OP
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float2, +, const float2 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float2, -, const float2 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float2, *, const float2 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float2, *, float)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float2, /, const float2 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float2, /, float)
  inline bool operator==(const float2 &val1, const float2 &val2) {
    return val1.x == val2.x && val1.y == val2.y;
  }
  inline bool operator!=(const float2 &val1, const float2 &val2) {
    return !operator==(val1, val2);
  }

} _WINDOWS_NUMERICS_END_NAMESPACE_


// === float3: Struct and function defs ===
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {

  struct float3 {
    float3() = default;
    constexpr float3(float x, float y, float z)
      : x(x), y(y), z(z)
    {}
    constexpr float3(float2 val, float z)
      : x(val.x), y(val.y), z(z)
    {}
    constexpr explicit float3(float val)
      : x(val), y(val), z(val)
    {}

    static constexpr float3 zero() {
      return float3(0.0);
    }
    static constexpr float3 one() {
      return float3(1.0);
    }
    static constexpr float3 unit_x() {
      return { 1.0f, 0.0f, 0.0f };
    }
    static constexpr float3 unit_y() {
      return { 0.0f, 1.0f, 0.0f };
    }
    static constexpr float3 unit_z() {
      return { 0.0f, 0.0f, 1.0f };
    }

    float x;
    float y;
    float z;
  };

  // Forward decl functions
  inline float length(const float3 &val);
  inline float length_squared(const float3 &val);
  inline float distance(const float3 &val1, const float3 &val2);
  inline float distance_squared(const float3 &val1, const float3 &val2);
  inline float dot(const float3 &val1, const float3 &val2);
  inline float3 normalize(const float3 &val);
  inline float3 cross(const float3 &val1, const float3 &val2);
  inline float3 reflect(const float3 &vec, const float3 &norm);
  inline float3 min(const float3 &val1, const float3 &val2);
  inline float3 max(const float3 &val1, const float3 &val2);
  inline float3 clamp(const float3 &val, const float3 &min, const float3 &max);
  inline float3 lerp(const float3 &val1, const float3 &val2, float amount);
  inline float3 transform(const float3 &pos, const float4x4 &mat);
  inline float3 transform_normal(const float3 &norm, const float4x4 &mat);
  inline float3 transform(const float3 &val, const quaternion &rot);

  // Define operators
#define _WINDOWS_NUMERICS_IMPL_BINARY_OP(_ty, _op) \
  inline _ty operator _op(const _ty &val1, const _ty &val2) { \
    return { val1.x _op val2.x, val1.y _op val2.y, val1.z _op val2.z }; \
  }
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float3, +)
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float3, -)
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float3, *)
  inline float3 operator*(const float3 &val1, float val2) {
    return { val1.x * val2, val1.y * val2, val1.z * val2 };
  }
  inline float3 operator*(float val1, const float3 &val2) {
    return operator*(val2, val1);
  }
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float3, /)
  inline float3 operator/(const float3 &val1, float val2) {
    return operator*(val1, 1.0f / val2);
  }
  inline float3 operator-(const float3 &val) {
    return { -val.x, -val.y, -val.z };
  }
#undef _WINDOWS_NUMERICS_IMPL_BINARY_OP
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float3, +, const float3 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float3, -, const float3 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float3, *, const float3 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float3, *, float)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float3, /, const float3 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float3, /, float)
  inline bool operator==(const float3 &val1, const float3 &val2) {
    return val1.x == val2.x && val1.y == val2.y && val1.z == val2.z;
  }
  inline bool operator!=(const float3 &val1, const float3 &val2) {
    return !operator==(val1, val2);
  }

} _WINDOWS_NUMERICS_END_NAMESPACE_


// === float4: Struct and function defs ===
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {

  struct float4 {
    float4() = default;
    constexpr float4(float x, float y, float z, float w)
      : x(x), y(y), z(z), w(w)
    {}
    constexpr float4(float2 val, float z, float w)
      : x(val.x), y(val.y), z(z), w(w)
    {}
    constexpr float4(float3 val, float w)
      : x(val.x), y(val.y), z(val.z), w(w)
    {}
    constexpr explicit float4(float val)
      : x(val), y(val), z(val), w(val)
    {}

    static constexpr float4 zero() {
      return float4(0.0);
    }
    static constexpr float4 one() {
      return float4(1.0);
    }
    static constexpr float4 unit_x() {
      return { 1.0f, 0.0f, 0.0f, 0.0f };
    }
    static constexpr float4 unit_y() {
      return { 0.0f, 1.0f, 0.0f, 0.0f };
    }
    static constexpr float4 unit_z() {
      return { 0.0f, 0.0f, 1.0f, 0.0f };
    }
    static constexpr float4 unit_w() {
      return { 0.0f, 0.0f, 0.0f, 1.0f };
    }

    float x;
    float y;
    float z;
    float w;
  };

  // Forward decl functions
  inline float length(const float4 &val);
  inline float length_squared(const float4 &val);
  inline float distance(const float4 &val1, const float4 &val2);
  inline float distance_squared(const float4 &val1, const float4 &val2);
  inline float dot(const float4 &val1, const float4 &val2);
  inline float4 normalize(const float4 &val);
  inline float4 min(const float4 &val1, const float4 &val2);
  inline float4 max(const float4 &val1, const float4 &val2);
  inline float4 clamp(const float4 &val, const float4 &min, const float4 &max);
  inline float4 lerp(const float4 &val1, const float4 &val2, float amount);
  inline float4 transform(const float4 &pos, const float4x4 &mat);
  inline float4 transform4(const float3 &pos, const float4x4 &mat);
  inline float4 transform4(const float2 &pos, const float4x4 &mat);
  inline float4 transform(const float4 &val, const quaternion &rot);
  inline float4 transform4(const float3 &val, const quaternion &rot);
  inline float4 transform4(const float2 &val, const quaternion &rot);

  // Define operators
#define _WINDOWS_NUMERICS_IMPL_BINARY_OP(_ty, _op) \
  inline _ty operator _op(const _ty &val1, const _ty &val2) { \
    return { val1.x _op val2.x, val1.y _op val2.y, val1.z _op val2.z, val1.w _op val2.w }; \
  }
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float4, +)
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float4, -)
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float4, *)
  inline float4 operator*(const float4 &val1, float val2) {
    return { val1.x * val2, val1.y * val2, val1.z * val2, val1.w * val2 };
  }
  inline float4 operator*(float val1, const float4 &val2) {
    return operator*(val2, val1);
  }
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float4, /)
  inline float4 operator/(const float4 &val1, float val2) {
    return operator*(val1, 1.0f / val2);
  }
  inline float4 operator-(const float4 &val) {
    return { -val.x, -val.y, -val.z, -val.w };
  }
#undef _WINDOWS_NUMERICS_IMPL_BINARY_OP
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float4, +, const float4 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float4, -, const float4 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float4, *, const float4 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float4, *, float)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float4, /, const float4 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float4, /, float)
  inline bool operator==(const float4 &val1, const float4 &val2) {
    return val1.x == val2.x && val1.y == val2.y && val1.z == val2.z && val2.w == val2.w;
  }
  inline bool operator!=(const float4 &val1, const float4 &val2) {
    return !operator==(val1, val2);
  }

} _WINDOWS_NUMERICS_END_NAMESPACE_


// === float3x2: Struct and function defs ===
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {

  struct float3x2 {
    float3x2() = default;
    constexpr float3x2(
      float m11, float m12,
      float m21, float m22,
      float m31, float m32
    )
      : m11(m11), m12(m12)
      , m21(m21), m22(m22)
      , m31(m31), m32(m32)
    {}

    static constexpr float3x2 identity() {
      return {
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f
      };
    }

    float m11; float m12;
    float m21; float m22;
    float m31; float m32;
  };

  // Forward decl functions
  inline float3x2 make_float3x2_translation(const float2 &pos);
  inline float3x2 make_float3x2_translation(float xpos, float ypos);
  inline float3x2 make_float3x2_scale(float xscale, float yscale);
  inline float3x2 make_float3x2_scale(float xscale, float yscale, const float2 &center);
  inline float3x2 make_float3x2_scale(const float2 &xyscale);
  inline float3x2 make_float3x2_scale(const float2 &xyscale, const float2 &center);
  inline float3x2 make_float3x2_scale(float scale);
  inline float3x2 make_float3x2_scale(float scale, const float2 &center);
  inline float3x2 make_float3x2_skew(float xrad, float yrad);
  inline float3x2 make_float3x2_skew(float xrad, float yrad, const float2 &center);
  inline float3x2 make_float3x2_rotation(float rad);
  inline float3x2 make_float3x2_rotation(float rad, const float2 &center);
  inline bool is_identity(const float3x2 &val);
  inline float determinant(const float3x2 &val);
  inline float2 translation(const float3x2 &val);
  inline bool invert(const float3x2 &val, float3x2 *out);
  inline float3x2 lerp(const float3x2 &mat1, const float3x2 &mat2, float amount);

  // Define operators
#define _WINDOWS_NUMERICS_IMPL_BINARY_OP(_ty, _op) \
  inline _ty operator _op(const _ty &val1, const _ty &val2) { \
    return { \
      val1.m11 _op val2.m11, val1.m12 _op val2.m12, \
      val1.m21 _op val2.m21, val1.m22 _op val2.m22, \
      val1.m31 _op val2.m31, val1.m32 _op val2.m32, \
    }; \
  }
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float3x2, +)
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float3x2, -)
  inline float3x2 operator*(const float3x2 &val1, const float3x2 &val2) {
    // 2D transformation matrix has an implied 3rd column with (0, 0, 1)
    const float3 v1r1(val1.m11, val1.m12, 0.0f);
    const float3 v1r2(val1.m21, val1.m22, 0.0f);
    const float3 v1r3(val1.m31, val1.m32, 1.0f);
    const float3 v2c1(val2.m11, val2.m21, val2.m31);
    const float3 v2c2(val2.m12, val2.m22, val2.m32);
    // const float3 v2c3(0.0f, 0.0f, 1.0f);
    return {
      dot(v1r1, v2c1), dot(v1r1, v2c2),
      dot(v1r2, v2c1), dot(v1r2, v2c2),
      dot(v1r3, v2c1), dot(v1r3, v2c2)
    };
  }
  inline float3x2 operator*(const float3x2 &val1, float val2) {
    return {
      val1.m11 * val2, val1.m12 * val2,
      val1.m21 * val2, val1.m22 * val2,
      val1.m31 * val2, val1.m32 * val2
    };
  }
  inline float3x2 operator-(const float3x2 &val) {
    return {
      -val.m11, -val.m12,
      -val.m21, -val.m22,
      -val.m31, -val.m32
    };
  }
#undef _WINDOWS_NUMERICS_IMPL_BINARY_OP
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float3x2, +, const float3x2 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float3x2, -, const float3x2 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float3x2, *, const float3x2 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float3x2, *, float)
  inline bool operator==(const float3x2 &val1, const float3x2 &val2) {
    return
      val1.m11 == val2.m11 && val1.m12 == val2.m12 &&
      val1.m21 == val2.m21 && val1.m22 == val2.m22 &&
      val1.m31 == val2.m31 && val1.m32 == val2.m32;
  }
  inline bool operator!=(const float3x2 &val1, const float3x2 &val2) {
    return !operator==(val1, val2);
  }

} _WINDOWS_NUMERICS_END_NAMESPACE_


// === float4x4: Struct and function defs ===
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {

  struct float4x4 {
    float4x4() = default;
    constexpr float4x4(
      float m11, float m12, float m13, float m14,
      float m21, float m22, float m23, float m24,
      float m31, float m32, float m33, float m34,
      float m41, float m42, float m43, float m44
    )
      : m11(m11), m12(m12), m13(m13), m14(m14)
      , m21(m21), m22(m22), m23(m23), m24(m24)
      , m31(m31), m32(m32), m33(m33), m34(m34)
      , m41(m41), m42(m42), m43(m43), m44(m44)
    {}

    static constexpr float4x4 identity() {
      return {
        1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 1.0f
      };
    }

    float m11; float m12; float m13; float m14;
    float m21; float m22; float m23; float m24;
    float m31; float m32; float m33; float m34;
    float m41; float m42; float m43; float m44;
  };

  // Forward decl functions
  inline float4x4 make_float4x4_billboard(const float3 &objpos, const float3 &camerapos, const float3 &cameraup, const float3 &camerafwd);
  inline float4x4 make_float4x4_constrained_billboard(const float3 &objpos, const float3 &camerapos, const float3 &rotateaxis, const float3 &camerafwd, const float3 &objfwd);
  inline float4x4 make_float4x4_translation(const float3 &pos);
  inline float4x4 make_float4x4_translation(float xpos, float ypos, float zpos);
  inline float4x4 make_float4x4_scale(float xscale, float yscale, float zscale);
  inline float4x4 make_float4x4_scale(float xscale, float yscale, float zscale, const float3 &center);
  inline float4x4 make_float4x4_scale(const float3 &xyzscale);
  inline float4x4 make_float4x4_scale(const float3 &xyzscale, const float3 &center);
  inline float4x4 make_float4x4_scale(float scale);
  inline float4x4 make_float4x4_scale(float scale, const float3 &center);
  inline float4x4 make_float4x4_rotation_x(float rad);
  inline float4x4 make_float4x4_rotation_x(float rad, const float3 &center);
  inline float4x4 make_float4x4_rotation_y(float rad);
  inline float4x4 make_float4x4_rotation_y(float rad, const float3 &center);
  inline float4x4 make_float4x4_rotation_z(float rad);
  inline float4x4 make_float4x4_rotation_z(float rad, const float3 &center);
  inline float4x4 make_float4x4_from_axis_angle(const float3 &axis, float angle);
  inline float4x4 make_float4x4_perspective_field_of_view(float fov, float aspect, float nearplane, float farplane);
  inline float4x4 make_float4x4_perspective(float w, float h, float nearplane, float farplane);
  inline float4x4 make_float4x4_perspective_off_center(float left, float right, float bottom, float top, float nearplane, float farplane);
  inline float4x4 make_float4x4_orthographic(float w, float h, float znearplane, float zfarplane);
  inline float4x4 make_float4x4_orthographic_off_center(float left, float right, float bottom, float top, float znearplane, float zfarplane);
  inline float4x4 make_float4x4_look_at(const float3 &camerapos, const float3 &target, const float3 &cameraup);
  inline float4x4 make_float4x4_world(const float3 &pos, const float3 &fwd, const float3 &up);
  inline float4x4 make_float4x4_from_quaternion(const quaternion &quat);
  inline float4x4 make_float4x4_from_yaw_pitch_roll(float yaw, float pitch, float roll);
  inline float4x4 make_float4x4_shadow(const float3 &lightdir, const plane &plane);
  inline float4x4 make_float4x4_reflection(const plane &plane);
  inline bool is_identity(const float4x4 &val);
  inline float determinant(const float4x4 &val);
  inline float3 translation(const float4x4 &val);
  inline bool invert(const float4x4 &mat, float4x4 *out);
  inline bool decompose(const float4x4 &mat, float3 *out_scale, quaternion *out_rot, float3 *out_translate);
  inline float4x4 transform(const float4x4 &val, const quaternion &rot);
  inline float4x4 transpose(const float4x4 &val);
  inline float4x4 lerp(const float4x4 &val1, const float4x4 &val2, float amount);

  // Define operators
#define _WINDOWS_NUMERICS_IMPL_BINARY_OP(_ty, _op) \
  inline _ty operator _op(const _ty &val1, const _ty &val2) { \
    return { \
      val1.m11 _op val2.m11, val1.m12 _op val2.m12, val1.m13 _op val2.m13, val1.m14 _op val2.m14, \
      val1.m21 _op val2.m21, val1.m22 _op val2.m22, val1.m23 _op val2.m23, val1.m24 _op val2.m24, \
      val1.m31 _op val2.m31, val1.m32 _op val2.m32, val1.m33 _op val2.m33, val1.m34 _op val2.m34, \
      val1.m41 _op val2.m41, val1.m42 _op val2.m42, val1.m43 _op val2.m43, val1.m44 _op val2.m44, \
    }; \
  }
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float4x4, +)
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(float4x4, -)
  inline float4x4 operator*(const float4x4 &val1, const float4x4 &val2) {
    const float4 v1r1(val1.m11, val1.m12, val1.m13, val1.m14);
    const float4 v1r2(val1.m21, val1.m22, val1.m23, val1.m24);
    const float4 v1r3(val1.m31, val1.m32, val1.m33, val1.m34);
    const float4 v1r4(val1.m41, val1.m42, val1.m43, val1.m44);
    const float4 v2c1(val2.m11, val2.m21, val2.m31, val2.m41);
    const float4 v2c2(val2.m12, val2.m22, val2.m32, val2.m42);
    const float4 v2c3(val2.m13, val2.m23, val2.m33, val2.m43);
    const float4 v2c4(val2.m14, val2.m24, val2.m34, val2.m44);
    return {
      dot(v1r1, v2c1), dot(v1r1, v2c2), dot(v1r1, v2c3), dot(v1r1, v2c4),
      dot(v1r2, v2c1), dot(v1r2, v2c2), dot(v1r2, v2c3), dot(v1r2, v2c4),
      dot(v1r3, v2c1), dot(v1r3, v2c2), dot(v1r3, v2c3), dot(v1r3, v2c4),
      dot(v1r4, v2c1), dot(v1r4, v2c2), dot(v1r4, v2c3), dot(v1r4, v2c4)
    };
  }
  inline float4x4 operator*(const float4x4 &val1, float val2) {
    return {
      val1.m11 * val2, val1.m12 * val2, val1.m13 * val2, val1.m14 * val2,
      val1.m21 * val2, val1.m22 * val2, val1.m23 * val2, val1.m24 * val2,
      val1.m31 * val2, val1.m32 * val2, val1.m33 * val2, val1.m34 * val2,
      val1.m41 * val2, val1.m42 * val2, val1.m43 * val2, val1.m44 * val2
    };
  }
  inline float4x4 operator-(const float4x4 &val) {
    return {
      -val.m11, -val.m12, -val.m13, -val.m14,
      -val.m21, -val.m22, -val.m23, -val.m24,
      -val.m31, -val.m32, -val.m33, -val.m34,
      -val.m41, -val.m42, -val.m43, -val.m44
    };
  }
#undef _WINDOWS_NUMERICS_IMPL_BINARY_OP
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float4x4, +, const float4x4 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float4x4, -, const float4x4 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float4x4, *, const float4x4 &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(float4x4, *, float)
  inline bool operator==(const float4x4 &val1, const float4x4 &val2) {
    return
      val1.m11 == val2.m11 && val1.m12 == val2.m12 && val1.m13 == val2.m13 && val1.m14 == val2.m14 &&
      val1.m21 == val2.m21 && val1.m22 == val2.m22 && val1.m23 == val2.m23 && val1.m24 == val2.m24 &&
      val1.m31 == val2.m31 && val1.m32 == val2.m32 && val1.m33 == val2.m33 && val1.m34 == val2.m34 &&
      val1.m41 == val2.m41 && val1.m42 == val2.m42 && val1.m43 == val2.m43 && val1.m44 == val2.m44;
  }
  inline bool operator!=(const float4x4 &val1, const float4x4 &val2) {
    return !operator==(val1, val2);
  }

} _WINDOWS_NUMERICS_END_NAMESPACE_


// === plane: Struct and function defs ===
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {

  struct plane {
    plane() = default;
    constexpr plane(float x, float y, float z, float d)
      : normal(float3(x, y, z)), d(d)
    {}
    constexpr plane(float3 normal, float d)
      : normal(normal), d(d)
    {}
    constexpr explicit plane(float4 val)
      : normal(float3(val.x, val.y, val.z)), d(val.w)
    {}

    float3 normal;
    float d;
  };

  // Forward decl functions
  inline plane make_plane_from_vertices(const float3 &pt1, const float3 &pt2, const float3 &pt3);
  inline plane normalize(const plane &val);
  inline plane transform(const plane &plane, const float4x4 &mat);
  inline plane transform(const plane &plane, const quaternion &rot);
  inline float dot(const plane &plane, const float4 &val);
  inline float dot_coordinate(const plane &plane, const float3 &val);
  inline float dot_normal(const plane &plane, const float3 &val);

  // Define operators
  inline bool operator==(const plane &val1, const plane &val2) {
    return val1.normal == val2.normal && val1.d == val2.d;
  }
  inline bool operator!=(const plane &val1, const plane &val2) {
    return !operator==(val1, val2);
  }

} _WINDOWS_NUMERICS_END_NAMESPACE_


// === quaternion: Struct and function defs ===
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {

  struct quaternion {
    quaternion() = default;
    constexpr quaternion(float x, float y, float z, float w)
      : x(x), y(y), z(z), w(w)
    {}
    constexpr quaternion(float3 vecPart, float scalarPart)
      : x(vecPart.x), y(vecPart.y), z(vecPart.z), w(scalarPart)
    {}

    static constexpr quaternion identity() {
      return { 0.0f, 0.0f, 0.0f, 1.0f };
    }

    float x;
    float y;
    float z;
    float w;
  };

  // Forward decl functions
  inline quaternion make_quaternion_from_axis_angle(const float3 &axis, float angle);
  inline quaternion make_quaternion_from_yaw_pitch_roll(float yaw, float pitch, float roll);
  inline quaternion make_quaternion_from_rotation_matrix(const float4x4 &mat);
  inline bool is_identity(const quaternion &val);
  inline float length(const quaternion &val);
  inline float length_squared(const quaternion &val);
  inline float dot(const quaternion &val1, const quaternion &val2);
  inline quaternion normalize(const quaternion &val);
  inline quaternion conjugate(const quaternion &val);
  inline quaternion inverse(const quaternion &val);
  inline quaternion slerp(const quaternion &val1, const quaternion &val2, float amount);
  inline quaternion lerp(const quaternion &val1, const quaternion &val2, float amount);
  inline quaternion concatenate(const quaternion &val1, const quaternion &val2);

  // Define operators
#define _WINDOWS_NUMERICS_IMPL_BINARY_OP(_ty, _op) \
  inline _ty operator _op(const _ty &val1, const _ty &val2) { \
    return { val1.x _op val2.x, val1.y _op val2.y, val1.z _op val2.z, val1.w _op val2.w }; \
  }
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(quaternion, +)
  _WINDOWS_NUMERICS_IMPL_BINARY_OP(quaternion, -)
  inline quaternion operator*(const quaternion &val1, const quaternion &val2) {
    return {
      val1.w * val2.x + val1.x * val2.w + val1.y * val2.z - val1.z * val2.y,
      val1.w * val2.y - val1.x * val2.z + val1.y * val2.w + val1.z * val2.x,
      val1.w * val2.z + val1.x * val2.y - val1.y * val2.x + val1.z * val2.w,
      val1.w * val2.w - val1.x * val2.x - val1.y * val2.y - val1.z * val2.z
    }; }
  inline quaternion operator*(const quaternion &val1, float val2) {
    return { val1.x * val2, val1.y * val2, val1.z * val2, val1.w * val2 };
  }
  inline quaternion operator/(const quaternion &val1, const quaternion &val2) {
    return operator*(val1, inverse(val2));
  }
  inline quaternion operator-(const quaternion &val) {
    return { -val.x, -val.y, -val.z, -val.w };
  }
#undef _WINDOWS_NUMERICS_IMPL_BINARY_OP
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(quaternion, +, const quaternion &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(quaternion, -, const quaternion &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(quaternion, *, const quaternion &)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(quaternion, *, float)
  _WINDOWS_NUMERICS_IMPL_ASSIGN_OP(quaternion, /, const quaternion &)
  inline bool operator==(const quaternion &val1, const quaternion &val2) {
    return val1.x == val2.x && val1.y == val2.y && val1.z == val2.z && val2.w == val2.w;
  }
  inline bool operator!=(const quaternion &val1, const quaternion &val2) {
    return !operator==(val1, val2);
  }

} _WINDOWS_NUMERICS_END_NAMESPACE_


// === Function definitions ===

// Define float2 functions
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {

  inline float length(const float2 &val) {
    return ::std::sqrt(length_squared(val));
  }
  inline float length_squared(const float2 &val) {
    return val.x * val.x + val.y * val.y;
  }
  inline float distance(const float2 &val1, const float2 &val2) {
    return length(val2 - val1);
  }
  inline float distance_squared(const float2 &val1, const float2 &val2) {
    return length_squared(val2 - val1);
  }
  inline float dot(const float2 &val1, const float2 &val2) {
    return val1.x * val2.x + val1.y * val2.y;
  }
  inline float2 normalize(const float2 &val) {
    return val / length(val);
  }
  inline float2 reflect(const float2 &vec, const float2 &norm) {
    // norm is assumed to be normalized.
    return vec - 2.0f * dot(vec, norm) * norm;
  }
  inline float2 min(const float2 &val1, const float2 &val2) {
    return { ::std::min(val1.x, val2.x), ::std::min(val1.y, val2.y) };
  }
  inline float2 max(const float2 &val1, const float2 &val2) {
    return { ::std::max(val1.x, val2.x), ::std::max(val1.y, val2.y) };
  }
  inline float2 clamp(const float2 &val, const float2 &min, const float2 &max) {
    return { _impl::clamp(val.x, min.x, max.x), _impl::clamp(val.y, min.y, max.y) };
  }
  inline float2 lerp(const float2 &val1, const float2 &val2, float amount) {
    return { _impl::lerp(val1.x, val2.x, amount), _impl::lerp(val1.y, val2.y, amount) };
  }
  // TODO: impl
  inline float2 transform(const float2 &pos, const float3x2 &mat);
  inline float2 transform(const float2 &pos, const float4x4 &mat);
  inline float2 transform_normal(const float2 &norm, const float3x2 &mat);
  inline float2 transform_normal(const float2 &norm, const float4x4 &mat);
  inline float2 transform(const float2 &val, const quaternion &rot) {
    // See comments in the float3 transform function.
    quaternion result = rot * quaternion(float3(val.x, val.y, 0.0f), 0.0f) * inverse(rot);
    return { result.x, result.y };
  }

} _WINDOWS_NUMERICS_END_NAMESPACE_


// Define float3 functions
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {

  inline float length(const float3 &val) {
    return ::std::sqrt(length_squared(val));
  }
  inline float length_squared(const float3 &val) {
    return val.x * val.x + val.y * val.y + val.z * val.z;
  }
  inline float distance(const float3 &val1, const float3 &val2) {
    return length(val2 - val1);
  }
  inline float distance_squared(const float3 &val1, const float3 &val2) {
    return length_squared(val2 - val1);
  }
  inline float dot(const float3 &val1, const float3 &val2) {
    return val1.x * val2.x + val1.y * val2.y + val1.z * val2.z;
  }
  inline float3 normalize(const float3 &val) {
    return val / length(val);
  }
  inline float3 cross(const float3 &val1, const float3 &val2) {
    return {
      val1.y * val2.z - val2.y * val1.z,
      val1.z * val2.x - val2.z * val1.x,
      val1.x * val2.y - val2.x * val1.y
    };
  }
  inline float3 reflect(const float3 &vec, const float3 &norm) {
    // norm is assumed to be normalized.
    return vec - 2.0f * dot(vec, norm) * norm;
  }
  inline float3 min(const float3 &val1, const float3 &val2) {
    return { ::std::min(val1.x, val2.x), ::std::min(val1.y, val2.y), ::std::min(val1.z, val2.z) };
  }
  inline float3 max(const float3 &val1, const float3 &val2) {
    return { ::std::max(val1.x, val2.x), ::std::max(val1.y, val2.y), ::std::max(val1.z, val2.z) };
  }
  inline float3 clamp(const float3 &val, const float3 &min, const float3 &max) {
    return { _impl::clamp(val.x, min.x, max.x), _impl::clamp(val.y, min.y, max.y), _impl::clamp(val.z, min.z, max.z) };
  }
  inline float3 lerp(const float3 &val1, const float3 &val2, float amount) {
    return { _impl::lerp(val1.x, val2.x, amount), _impl::lerp(val1.y, val2.y, amount), _impl::lerp(val1.z, val2.z, amount) };
  }
  // TODO: impl
  inline float3 transform(const float3 &pos, const float4x4 &mat);
  inline float3 transform_normal(const float3 &norm, const float4x4 &mat);
  inline float3 transform(const float3 &val, const quaternion &rot) {
    // https://en.wikipedia.org/wiki/Quaternions_and_spatial_rotation#Using_quaternions_as_rotations
    // If assuming rot is a unit quaternion, this could use
    // conjugate() instead of inverse() too.
    // This can be expressed as a matrix operation too, with
    // https://en.wikipedia.org/wiki/Quaternions_and_spatial_rotation#Quaternion-derived_rotation_matrix
    // (see make_float4x4_from_quaternion).
    quaternion result = rot * quaternion(val, 0.0f) * inverse(rot);
    return { result.x, result.y, result.z };
  }

} _WINDOWS_NUMERICS_END_NAMESPACE_


// Define float4 functions
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {

  inline float length(const float4 &val) {
    return ::std::sqrt(length_squared(val));
  }
  inline float length_squared(const float4 &val) {
    return val.x * val.x + val.y * val.y + val.z * val.z + val.w * val.w;
  }
  inline float distance(const float4 &val1, const float4 &val2) {
    return length(val2 - val1);
  }
  inline float distance_squared(const float4 &val1, const float4 &val2) {
    return length_squared(val2 - val1);
  }
  inline float dot(const float4 &val1, const float4 &val2) {
    return val1.x * val2.x + val1.y * val2.y + val1.z * val2.z + val1.w * val2.w;
  }
  inline float4 normalize(const float4 &val) {
    return val / length(val);
  }
  inline float4 min(const float4 &val1, const float4 &val2) {
    return {
      ::std::min(val1.x, val2.x),
      ::std::min(val1.y, val2.y),
      ::std::min(val1.z, val2.z),
      ::std::min(val1.w, val2.w)
    };
  }
  inline float4 max(const float4 &val1, const float4 &val2) {
    return {
      ::std::max(val1.x, val2.x),
      ::std::max(val1.y, val2.y),
      ::std::max(val1.z, val2.z),
      ::std::max(val1.w, val2.w)
    };
  }
  inline float4 clamp(const float4 &val, const float4 &min, const float4 &max) {
    return {
      _impl::clamp(val.x, min.x, max.x),
      _impl::clamp(val.y, min.y, max.y),
      _impl::clamp(val.z, min.z, max.z),
      _impl::clamp(val.w, min.w, max.w)
    };
  }
  inline float4 lerp(const float4 &val1, const float4 &val2, float amount) {
    return {
      _impl::lerp(val1.x, val2.x, amount),
      _impl::lerp(val1.y, val2.y, amount),
      _impl::lerp(val1.z, val2.z, amount),
      _impl::lerp(val1.w, val2.w, amount)
    };
  }
  // TODO: impl
  inline float4 transform(const float4 &pos, const float4x4 &mat);
  inline float4 transform4(const float3 &pos, const float4x4 &mat);
  inline float4 transform4(const float2 &pos, const float4x4 &mat);
  inline float4 transform(const float4 &val, const quaternion &rot) {
    // See comments in the float3 transform function.
    quaternion result = rot * quaternion(float3(val.x, val.y, val.z), 0.0f) * inverse(rot);
    return { result.x, result.y, result.z, val.w };
  }
  inline float4 transform4(const float3 &val, const quaternion &rot) {
    quaternion result = rot * quaternion(val, 0.0f) * inverse(rot);
    return { result.x, result.y, result.z, 1.0f };
  }
  inline float4 transform4(const float2 &val, const quaternion &rot) {
    quaternion result = rot * quaternion(float3(val.x, val.y, 0.0f), 0.0f) * inverse(rot);
    return { result.x, result.y, result.z, 1.0f };
  }

} _WINDOWS_NUMERICS_END_NAMESPACE_


// Define float3x2 functions
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {

  // TODO: impl
  inline float3x2 make_float3x2_translation(const float2 &pos);
  inline float3x2 make_float3x2_translation(float xpos, float ypos);
  inline float3x2 make_float3x2_scale(float xscale, float yscale);
  inline float3x2 make_float3x2_scale(float xscale, float yscale, const float2 &center);
  inline float3x2 make_float3x2_scale(const float2 &xyscale);
  inline float3x2 make_float3x2_scale(const float2 &xyscale, const float2 &center);
  inline float3x2 make_float3x2_scale(float scale);
  inline float3x2 make_float3x2_scale(float scale, const float2 &center);
  inline float3x2 make_float3x2_skew(float xrad, float yrad);
  inline float3x2 make_float3x2_skew(float xrad, float yrad, const float2 &center);
  inline float3x2 make_float3x2_rotation(float rad);
  inline float3x2 make_float3x2_rotation(float rad, const float2 &center);
  inline bool is_identity(const float3x2 &val) {
    return val == float3x2::identity();
  }
  inline float determinant(const float3x2 &val) {
    // 2D transformation matrix has an implied 3rd column with (0, 0, 1)
    // det = m11 * m22 * m33 + m12 * m23 * m31 + m13 * m21 * m32
    //     - m31 * m22 * m13 - m21 * m12 * m33 - m11 * m32 * m23;
    return val.m11 * val.m22 - val.m21 * val.m12;
  }
  inline float2 translation(const float3x2 &val) {
    return { val.m31, val.m32 };
  }
  inline bool invert(const float3x2 &val, float3x2 *out);
  inline float3x2 lerp(const float3x2 &mat1, const float3x2 &mat2, float amount);

} _WINDOWS_NUMERICS_END_NAMESPACE_


// Define float4x4 functions
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {

  // TODO: impl
  inline float4x4 make_float4x4_billboard(const float3 &objpos, const float3 &camerapos, const float3 &cameraup, const float3 &camerafwd);
  inline float4x4 make_float4x4_constrained_billboard(const float3 &objpos, const float3 &camerapos, const float3 &rotateaxis, const float3 &camerafwd, const float3 &objfwd);
  inline float4x4 make_float4x4_translation(const float3 &pos) {
    return {
      1.0f,  0.0f,  0.0f,  0.0f,
      0.0f,  1.0f,  0.0f,  0.0f,
      0.0f,  0.0f,  1.0f,  0.0f,
      pos.x, pos.y, pos.z, 1.0f
    };
  }
  inline float4x4 make_float4x4_translation(float xpos, float ypos, float zpos);
  inline float4x4 make_float4x4_scale(float xscale, float yscale, float zscale);
  inline float4x4 make_float4x4_scale(float xscale, float yscale, float zscale, const float3 &center);
  inline float4x4 make_float4x4_scale(const float3 &xyzscale) {
    return {
      xyzscale.x, 0.0f,       0.0f,       0.0f,
      0.0f,       xyzscale.y, 0.0f,       0.0f,
      0.0f,       0.0f,       xyzscale.z, 0.0f,
      0.0f,       0.0f,       0.0f,       1.0f
    };
  }
  inline float4x4 make_float4x4_scale(const float3 &xyzscale, const float3 &center);
  inline float4x4 make_float4x4_scale(float scale);
  inline float4x4 make_float4x4_scale(float scale, const float3 &center);
  inline float4x4 make_float4x4_rotation_x(float rad);
  inline float4x4 make_float4x4_rotation_x(float rad, const float3 &center);
  inline float4x4 make_float4x4_rotation_y(float rad);
  inline float4x4 make_float4x4_rotation_y(float rad, const float3 &center);
  inline float4x4 make_float4x4_rotation_z(float rad);
  inline float4x4 make_float4x4_rotation_z(float rad, const float3 &center);
  inline float4x4 make_float4x4_from_axis_angle(const float3 &axis, float angle);
  inline float4x4 make_float4x4_perspective_field_of_view(float fov, float aspect, float nearplane, float farplane);
  inline float4x4 make_float4x4_perspective(float w, float h, float nearplane, float farplane);
  inline float4x4 make_float4x4_perspective_off_center(float left, float right, float bottom, float top, float nearplane, float farplane);
  inline float4x4 make_float4x4_orthographic(float w, float h, float znearplane, float zfarplane);
  inline float4x4 make_float4x4_orthographic_off_center(float left, float right, float bottom, float top, float znearplane, float zfarplane);
  inline float4x4 make_float4x4_look_at(const float3 &camerapos, const float3 &target, const float3 &cameraup);
  inline float4x4 make_float4x4_world(const float3 &pos, const float3 &fwd, const float3 &up);
  inline float4x4 make_float4x4_from_quaternion(const quaternion &quat) {
    // https://en.wikipedia.org/wiki/Rotation_matrix#Quaternion
    float xx = quat.x * quat.x;
    float yy = quat.y * quat.y;
    float zz = quat.z * quat.z;
    float xy = quat.x * quat.y;
    float xz = quat.x * quat.z;
    float xw = quat.x * quat.w;
    float yz = quat.y * quat.z;
    float yw = quat.y * quat.w;
    float zw = quat.z * quat.w;
    return {
      1.0f - 2.0f*yy - 2.0f*zz, 2.0f*xy + 2.0f*zw,        2.0f*xz - 2.0f*yw,        0.0f,
      2.0f*xy - 2.0f*zw,        1.0f - 2.0f*xx - 2.0f*zz, 2.0f*yz + 2.0f*xw,        0.0f,
      2.0f*xz + 2.0f*yw,        2.0f*yz - 2.0f*xw,        1.0f - 2.0f*xx - 2.0f*yy, 0.0f,
      0.0f,                     0.0f,                     0.0f,                     1.0f
    };
  }
  inline float4x4 make_float4x4_from_yaw_pitch_roll(float yaw, float pitch, float roll);
  inline float4x4 make_float4x4_shadow(const float3 &lightdir, const plane &plane);
  inline float4x4 make_float4x4_reflection(const plane &plane);
  inline bool is_identity(const float4x4 &val) {
    return val == float4x4::identity();
  }
  inline float determinant(const float4x4 &val) {
    const float det_33_44 = (val.m33 * val.m44 - val.m34 * val.m43);
    const float det_32_44 = (val.m32 * val.m44 - val.m34 * val.m42);
    const float det_32_43 = (val.m32 * val.m43 - val.m33 * val.m42);
    const float det_31_44 = (val.m31 * val.m44 - val.m34 * val.m41);
    const float det_31_43 = (val.m31 * val.m43 - val.m33 * val.m41);
    const float det_31_42 = (val.m31 * val.m42 - val.m32 * val.m41);
    return val.m11 * (val.m22 * det_33_44 - val.m23 * det_32_44 + val.m24 * det_32_43)
      - val.m12 * (val.m21 * det_33_44 - val.m23 * det_31_44 + val.m24 * det_31_43)
      + val.m13 * (val.m21 * det_32_44 - val.m22 * det_31_44 + val.m24 * det_31_42)
      - val.m14 * (val.m21 * det_32_43 - val.m22 * det_31_43 + val.m23 * det_31_42);
  }
  inline float3 translation(const float4x4 &val) {
    return { val.m41, val.m42, val.m43 };
  }
  inline bool invert(const float4x4 &mat, float4x4 *out);
  inline bool decompose(const float4x4 &mat, float3 *out_scale, quaternion *out_rot, float3 *out_translate);
  inline float4x4 transform(const float4x4 &val, const quaternion &rot) {
    return val * make_float4x4_from_quaternion(rot);
  }
  inline float4x4 transpose(const float4x4 &val) {
    return  {
      val.m11, val.m21, val.m31, val.m41,
      val.m12, val.m22, val.m32, val.m42,
      val.m13, val.m23, val.m33, val.m43,
      val.m14, val.m24, val.m34, val.m44
    };
  }
  inline float4x4 lerp(const float4x4 &val1, const float4x4 &val2, float amount);

} _WINDOWS_NUMERICS_END_NAMESPACE_


// Define plane functions
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {

  // TODO: impl
  inline plane make_plane_from_vertices(const float3 &pt1, const float3 &pt2, const float3 &pt3);
  inline plane normalize(const plane &val) {
    const float invlen = 1.0f / length(val.normal);
    return { val.normal * invlen, val.d * invlen };
  }
  inline plane transform(const plane &plane, const float4x4 &mat);
  inline plane transform(const plane &plane, const quaternion &rot) {
    quaternion result = rot * quaternion(plane.normal, 0.0f) * inverse(rot);
    return { float3(result.x, result.y, result.z), plane.d };
  }
  inline float dot(const plane &plane, const float4 &val);
  inline float dot_coordinate(const plane &plane, const float3 &val);
  inline float dot_normal(const plane &plane, const float3 &val);

} _WINDOWS_NUMERICS_END_NAMESPACE_


// Define quaternion functions
_WINDOWS_NUMERICS_BEGIN_NAMESPACE_ {

  inline quaternion make_quaternion_from_axis_angle(const float3 &axis, float angle) {
    return quaternion(axis * ::std::sin(angle * 0.5f), ::std::cos(angle * 0.5f));
  }
  inline quaternion make_quaternion_from_yaw_pitch_roll(float yaw, float pitch, float roll) {
    quaternion yq = make_quaternion_from_axis_angle(float3(0.0f, 1.0f, 0.0f), yaw);
    quaternion pq = make_quaternion_from_axis_angle(float3(1.0f, 0.0f, 0.0f), pitch);
    quaternion rq = make_quaternion_from_axis_angle(float3(0.0f, 0.0f, 1.0f), roll);
    return concatenate(concatenate(rq, pq), yq);
  }
  inline quaternion make_quaternion_from_rotation_matrix(const float4x4 &mat) {
    // https://en.wikipedia.org/wiki/Rotation_matrix#Quaternion
    float t = mat.m11 + mat.m22 + mat.m33;
    if (t > 0) {
      float r = ::std::sqrt(1.0f + t);
      float s = 1.0f / (2.0f * r);
      return { (mat.m23 - mat.m32) * s, (mat.m31 - mat.m13) * s,
               (mat.m12 - mat.m21) * s, r * 0.5f };
    } else if (mat.m11 >= mat.m22 && mat.m11 >= mat.m33) {
      float r = ::std::sqrt(1.0f + mat.m11 - mat.m22 - mat.m33);
      float s = 1.0f / (2.0f * r);
      return { r * 0.5f, (mat.m21 + mat.m12) * s,
               (mat.m13 + mat.m31) * s, (mat.m23 - mat.m32) * s };
    } else if (mat.m22 >= mat.m11 && mat.m22 >= mat.m33) {
      float r = ::std::sqrt(1.0f + mat.m22 - mat.m11 - mat.m33);
      float s = 1.0f / (2.0f * r);
      return { (mat.m21 + mat.m12) * s, r * 0.5f,
               (mat.m32 + mat.m23) * s, (mat.m31 - mat.m13) * s };
    } else {
      float r = ::std::sqrt(1.0f + mat.m33 - mat.m11 - mat.m22);
      float s = 1.0f / (2.0f * r);
      return { (mat.m13 + mat.m31) * s, (mat.m32 + mat.m23) * s,
               r * 0.5f, (mat.m12 - mat.m21) * s };
    }
  }
  inline bool is_identity(const quaternion &val) {
    return val == quaternion::identity();
  }
  inline float length(const quaternion &val) {
    return ::std::sqrt(length_squared(val));
  }
  inline float length_squared(const quaternion &val) {
    return dot(val, val);
  }
  inline float dot(const quaternion &val1, const quaternion &val2) {
    return val1.x * val2.x + val1.y * val2.y + val1.z * val2.z + val1.w * val2.w;
  }
  inline quaternion normalize(const quaternion &val) {
    return operator*(val, 1.0f / length(val));
  }
  inline quaternion conjugate(const quaternion &val) {
    return { -val.x, -val.y, -val.z, val.w};
  }
  inline quaternion inverse(const quaternion &val) {
    return operator*(conjugate(val), 1.0f / length_squared(val));
  }
  inline quaternion slerp(const quaternion &val1, const quaternion &val2, float amount) {
    // https://en.wikipedia.org/wiki/Slerp#Geometric_Slerp
    float cosangle = dot(val1, val2);
    quaternion end = val2;
    if (cosangle < 0.0f) {
      end = -val2;
      cosangle = -cosangle;
    }
    float fact1, fact2;
    const float epsilon = 1.0e-6f;
    if (cosangle > 1.0f - epsilon) {
      // Very small rotation range, or non-normalized input quaternions.
      fact1 = (1.0f - amount);
      fact2 = amount;
    } else {
      float angle = ::std::acos(cosangle);
      float sinangle = ::std::sin(angle);
      fact1 = ::std::sin((1.0f - amount) * angle) / sinangle;
      fact2 = ::std::sin(amount * angle) / sinangle;
    }
    return val1 * fact1 + end * fact2;
  }
  inline quaternion lerp(const quaternion &val1, const quaternion &val2, float amount) {
    quaternion end = val2;
    if (dot(val1, val2) < 0.0f)
      end = -val2;
    return normalize(quaternion(
      _impl::lerp(val1.x, end.x, amount), _impl::lerp(val1.y, end.y, amount),
      _impl::lerp(val1.z, end.z, amount), _impl::lerp(val1.w, end.w, amount)
    ));
  }
  inline quaternion concatenate(const quaternion &val1, const quaternion &val2) {
    return val2 * val1;
  }

} _WINDOWS_NUMERICS_END_NAMESPACE_


/**
 * FIXME: Implement interop functions with DirectXMath.
 * This is where we are supposed to define the functions to convert between
 * Windows::Foundation::Numerics types and XMVECTOR / XMMATRIX. But our
 * directxmath.h does not contain the definitions for these types...
 */
#if 0
// === DirectXMath Interop ===
namespace DirectX {

  // TODO: impl
  XMVECTOR XMLoadFloat2(const _WINDOWS_NUMERICS_NAMESPACE_::float2 *src);
  XMVECTOR XMLoadFloat3(const _WINDOWS_NUMERICS_NAMESPACE_::float3 *src);
  XMVECTOR XMLoadFloat4(const _WINDOWS_NUMERICS_NAMESPACE_::float4 *src);
  XMMATRIX XMLoadFloat3x2(const _WINDOWS_NUMERICS_NAMESPACE_::float3x2 *src);
  XMMATRIX XMLoadFloat4x4(const _WINDOWS_NUMERICS_NAMESPACE_::float4x4 *src);
  XMVECTOR XMLoadPlane(const _WINDOWS_NUMERICS_NAMESPACE_::plane *src);
  XMVECTOR XMLoadQuaternion(const _WINDOWS_NUMERICS_NAMESPACE_::quaternion *src);
  void XMStoreFloat2(_WINDOWS_NUMERICS_NAMESPACE_::float2 *out, FXMVECTOR in);
  void XMStoreFloat3(_WINDOWS_NUMERICS_NAMESPACE_::float3 *out, FXMVECTOR in);
  void XMStoreFloat4(_WINDOWS_NUMERICS_NAMESPACE_::float4 *out, FXMVECTOR in);
  void XMStoreFloat3x2(_WINDOWS_NUMERICS_NAMESPACE_::float3x2 *out, FXMMATRIX in);
  void XMStoreFloat4x4(_WINDOWS_NUMERICS_NAMESPACE_::float4x4 *out, FXMMATRIX in);
  void XMStorePlane(_WINDOWS_NUMERICS_NAMESPACE_::plane *out, FXMVECTOR in);
  void XMStoreQuaternion(_WINDOWS_NUMERICS_NAMESPACE_::quaternion *out, FXMVECTOR in);

} /* namespace DirectX */
#endif


#undef _WINDOWS_NUMERICS_IMPL_ASSIGN_OP

#ifdef _WINDOWS_NUMERICS_IMPL_PUSHED_MIN_
#  undef _WINDOWS_NUMERICS_IMPL_PUSHED_MIN_
#  pragma pop_macro("min")
#endif

#ifdef _WINDOWS_NUMERICS_IMPL_PUSHED_MAX_
#  undef _WINDOWS_NUMERICS_IMPL_PUSHED_MAX_
#  pragma pop_macro("max")
#endif
