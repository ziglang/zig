/*! @header
 *  This header defines functions for constructing and using quaternions.
 *  @copyright 2015-2016 Apple, Inc. All rights reserved.
 *  @unsorted                                                                 */

#ifndef SIMD_QUATERNIONS
#define SIMD_QUATERNIONS

#include <simd/base.h>
#if SIMD_COMPILER_HAS_REQUIRED_FEATURES
#include <simd/vector.h>
#include <simd/types.h>

#ifdef __cplusplus
extern "C" {
#endif
  
/*  MARK: - C and Objective-C float interfaces                                */

/*! @abstract Constructs a quaternion from four scalar values.
 *
 *  @param ix The first component of the imaginary (vector) part.
 *  @param iy The second component of the imaginary (vector) part.
 *  @param iz The third component of the imaginary (vector) part.
 *
 *  @param r The real (scalar) part.                                          */
static inline SIMD_CFUNC simd_quatf simd_quaternion(float ix, float iy, float iz, float r) {
  return (simd_quatf){ { ix, iy, iz, r } };
}
  
/*! @abstract Constructs a quaternion from an array of four scalars.
 *
 *  @discussion Note that the imaginary part of the quaternion comes from 
 *  array elements 0, 1, and 2, and the real part comes from element 3.       */
static inline SIMD_NONCONST simd_quatf simd_quaternion(const float xyzr[4]) {
  return (simd_quatf){ *(const simd_packed_float4 *)xyzr };
}
  
/*! @abstract Constructs a quaternion from a four-element vector.
 *
 *  @discussion Note that the imaginary (vector) part of the quaternion comes
 *  from lanes 0, 1, and 2 of the vector, and the real (scalar) part comes from
 *  lane 3.                                                                   */
static inline SIMD_CFUNC simd_quatf simd_quaternion(simd_float4 xyzr) {
  return (simd_quatf){ xyzr };
}
  
/*! @abstract Constructs a quaternion that rotates by `angle` radians about
 *  `axis`.                                                                   */
static inline SIMD_CFUNC simd_quatf simd_quaternion(float angle, simd_float3 axis);
  
/*! @abstract Construct a quaternion that rotates from one vector to another.
 *
 *  @param from A normalized three-element vector.
 *  @param to A normalized three-element vector.
 *
 *  @discussion The rotation axis is `simd_cross(from, to)`. If `from` and
 *  `to` point in opposite directions (to within machine precision), an
 *  arbitrary rotation axis is chosen, and the angle is pi radians.           */
static SIMD_NOINLINE simd_quatf simd_quaternion(simd_float3 from, simd_float3 to);

/*! @abstract Construct a quaternion from a 3x3 rotation `matrix`.
 *
 *  @discussion If `matrix` is not orthogonal with determinant 1, the result
 *  is undefined.                                                             */
static SIMD_NOINLINE simd_quatf simd_quaternion(simd_float3x3 matrix);

/*! @abstract Construct a quaternion from a 4x4 rotation `matrix`.
 *
 *  @discussion The last row and column of the matrix are ignored. This
 *  function is equivalent to calling simd_quaternion with the upper-left 3x3
 *  submatrix                .                                                */
static SIMD_NOINLINE simd_quatf simd_quaternion(simd_float4x4 matrix);
  
/*! @abstract The real (scalar) part of the quaternion `q`.                   */
static inline SIMD_CFUNC float simd_real(simd_quatf q) {
  return q.vector.w;
}
  
/*! @abstract The imaginary (vector) part of the quaternion `q`.              */
static inline SIMD_CFUNC simd_float3 simd_imag(simd_quatf q) {
  return q.vector.xyz;
}
  
/*! @abstract The angle (in radians) of rotation represented by `q`.          */
static inline SIMD_CFUNC float simd_angle(simd_quatf q);
  
/*! @abstract The normalized axis (a 3-element vector) around which the
 *  action of the quaternion `q` rotates.                                     */
static inline SIMD_CFUNC simd_float3 simd_axis(simd_quatf q);
  
/*! @abstract The sum of the quaternions `p` and `q`.                         */
static inline SIMD_CFUNC simd_quatf simd_add(simd_quatf p, simd_quatf q);
  
/*! @abstract The difference of the quaternions `p` and `q`.                  */
static inline SIMD_CFUNC simd_quatf simd_sub(simd_quatf p, simd_quatf q);
  
/*! @abstract The product of the quaternions `p` and `q`.                     */
static inline SIMD_CFUNC simd_quatf simd_mul(simd_quatf p, simd_quatf q);
  
/*! @abstract The quaternion `q` scaled by the real value `a`.                */
static inline SIMD_CFUNC simd_quatf simd_mul(simd_quatf q, float a);
  
/*! @abstract The quaternion `q` scaled by the real value `a`.                */
static inline SIMD_CFUNC simd_quatf simd_mul(float a, simd_quatf q);
  
/*! @abstract The conjugate of the quaternion `q`.                            */
static inline SIMD_CFUNC simd_quatf simd_conjugate(simd_quatf q);
  
/*! @abstract The (multiplicative) inverse of the quaternion `q`.             */
static inline SIMD_CFUNC simd_quatf simd_inverse(simd_quatf q);
  
/*! @abstract The negation (additive inverse) of the quaternion `q`.          */
static inline SIMD_CFUNC simd_quatf simd_negate(simd_quatf q);
  
/*! @abstract The dot product of the quaternions `p` and `q` interpreted as
 *  four-dimensional vectors.                                                 */
static inline SIMD_CFUNC float simd_dot(simd_quatf p, simd_quatf q);
  
/*! @abstract The length of the quaternion `q`.                               */
static inline SIMD_CFUNC float simd_length(simd_quatf q);
  
/*! @abstract The unit quaternion obtained by normalizing `q`.                */
static inline SIMD_CFUNC simd_quatf simd_normalize(simd_quatf q);
  
/*! @abstract Rotates the vector `v` by the quaternion `q`.                   */
static inline SIMD_CFUNC simd_float3 simd_act(simd_quatf q, simd_float3 v);
  
/*! @abstract Logarithm of the quaternion `q`.
 *  @discussion Do not call this function directly; use `log(q)` instead.
 *
 *  We can write a quaternion `q` in the form: `r(cos(t) + sin(t)v)` where
 *  `r` is the length of `q`, `t` is an angle, and `v` is a unit 3-vector.
 *  The logarithm of `q` is `log(r) + tv`, just like the logarithm of the
 *  complex number `r*(cos(t) + i sin(t))` is `log(r) + it`.
 *
 *  Note that this function is not robust against poorly-scaled non-unit
 *  quaternions, because it is primarily used for spline interpolation of
 *  unit quaternions. If you need to compute a robust logarithm of general
 *  quaternions, you can use the following approach:
 *
 *    scale = simd_reduce_max(simd_abs(q.vector));
 *    logq = log(simd_recip(scale)*q);
 *    logq.real += log(scale);
 *    return logq;                                                            */
static SIMD_NOINLINE simd_quatf __tg_log(simd_quatf q);
    
/*! @abstract Inverse of `log( )`; the exponential map on quaternions.
 *  @discussion Do not call this function directly; use `exp(q)` instead.     */
static SIMD_NOINLINE simd_quatf __tg_exp(simd_quatf q);
  
/*! @abstract Spherical linear interpolation along the shortest arc between
 *  quaternions `q0` and `q1`.                                                */
static SIMD_NOINLINE simd_quatf simd_slerp(simd_quatf q0, simd_quatf q1, float t);

/*! @abstract Spherical linear interpolation along the longest arc between
 *  quaternions `q0` and `q1`.                                                */
static SIMD_NOINLINE simd_quatf simd_slerp_longest(simd_quatf q0, simd_quatf q1, float t);

/*! @abstract Interpolate between quaternions along a spherical cubic spline.
 *
 *  @discussion The function interpolates between q1 and q2. q0 is the left
 *  endpoint of the previous interval, and q3 is the right endpoint of the next
 *  interval. Use this function to smoothly interpolate between a sequence of
 *  rotations.                                                                */
static SIMD_NOINLINE simd_quatf simd_spline(simd_quatf q0, simd_quatf q1, simd_quatf q2, simd_quatf q3, float t);

/*! @abstract Spherical cubic Bezier interpolation between quaternions.
 *
 *  @discussion The function treats q0 ... q3 as control points and uses slerp
 *  in place of lerp in the De Castlejeau algorithm. The endpoints of
 *  interpolation are thus q0 and q3, and the curve will not generally pass
 *  through q1 or q2. Note that the convex hull property of "standard" Bezier
 *  curve does not hold on the sphere.                                        */
static SIMD_NOINLINE simd_quatf simd_bezier(simd_quatf q0, simd_quatf q1, simd_quatf q2, simd_quatf q3, float t);
  
#ifdef __cplusplus
} /* extern "C" */
/*  MARK: - C++ float interfaces                                              */

namespace simd {
  struct quatf : ::simd_quatf {
    /*! @abstract The identity quaternion.                                    */
    quatf( ) : ::simd_quatf(::simd_quaternion((float4){0,0,0,1})) { }
    
    /*! @abstract Constructs a C++ quaternion from a C quaternion.            */
    quatf(::simd_quatf q) : ::simd_quatf(q) { }
    
    /*! @abstract Constructs a quaternion from components.                    */
    quatf(float ix, float iy, float iz, float r) : ::simd_quatf(::simd_quaternion(ix, iy, iz, r)) { }
    
    /*! @abstract Constructs a quaternion from an array of scalars.           */
    quatf(const float xyzr[4]) : ::simd_quatf(::simd_quaternion(xyzr)) { }
    
    /*! @abstract Constructs a quaternion from a vector.                      */
    quatf(float4 xyzr) : ::simd_quatf(::simd_quaternion(xyzr)) { }
    
    /*! @abstract Quaternion representing rotation about `axis` by `angle` 
     *  radians.                                                              */
    quatf(float angle, float3 axis) : ::simd_quatf(::simd_quaternion(angle, axis)) { }
    
    /*! @abstract Quaternion that rotates `from` into `to`.                   */
    quatf(float3 from, float3 to) : ::simd_quatf(::simd_quaternion(from, to)) { }
    
    /*! @abstract Constructs a quaternion from a rotation matrix.             */
    quatf(::simd_float3x3 matrix) : ::simd_quatf(::simd_quaternion(matrix)) { }
    
    /*! @abstract Constructs a quaternion from a rotation matrix.             */
    quatf(::simd_float4x4 matrix) : ::simd_quatf(::simd_quaternion(matrix)) { }
  
    /*! @abstract The real (scalar) part of the quaternion.                   */
    float real(void) const { return ::simd_real(*this); }
    
    /*! @abstract The imaginary (vector) part of the quaternion.              */
    float3 imag(void) const { return ::simd_imag(*this); }
    
    /*! @abstract The angle the quaternion rotates by.                        */
    float angle(void) const { return ::simd_angle(*this); }
    
    /*! @abstract The axis the quaternion rotates about.                      */
    float3 axis(void) const { return ::simd_axis(*this); }
    
    /*! @abstract The length of the quaternion.                               */
    float length(void) const { return ::simd_length(*this); }
    
    /*! @abstract Act on the vector `v` by rotation.                          */
    float3  operator()(const ::simd_float3 v) const { return ::simd_act(*this, v); }
  };
  
  static SIMD_CPPFUNC quatf operator+(const ::simd_quatf p, const ::simd_quatf q) { return ::simd_add(p, q); }
  static SIMD_CPPFUNC quatf operator-(const ::simd_quatf p, const ::simd_quatf q) { return ::simd_sub(p, q); }
  static SIMD_CPPFUNC quatf operator-(const ::simd_quatf p) { return ::simd_negate(p); }
  static SIMD_CPPFUNC quatf operator*(const float r, const ::simd_quatf p) { return ::simd_mul(r, p); }
  static SIMD_CPPFUNC quatf operator*(const ::simd_quatf p, const float r) { return ::simd_mul(p, r); }
  static SIMD_CPPFUNC quatf operator*(const ::simd_quatf p, const ::simd_quatf q) { return ::simd_mul(p, q); }
  static SIMD_CPPFUNC quatf operator/(const ::simd_quatf p, const ::simd_quatf q) { return ::simd_mul(p, ::simd_inverse(q)); }
  static SIMD_CPPFUNC quatf operator+=(quatf &p, const ::simd_quatf q) { return p = p+q; }
  static SIMD_CPPFUNC quatf operator-=(quatf &p, const ::simd_quatf q) { return p = p-q; }
  static SIMD_CPPFUNC quatf operator*=(quatf &p, const float r) { return p = p*r; }
  static SIMD_CPPFUNC quatf operator*=(quatf &p, const ::simd_quatf q) { return p = p*q; }
  static SIMD_CPPFUNC quatf operator/=(quatf &p, const ::simd_quatf q) { return p = p/q; }
  
  /*! @abstract The conjugate of the quaternion `q`.                          */
  static SIMD_CPPFUNC quatf conjugate(const ::simd_quatf p) { return ::simd_conjugate(p); }
  
  /*! @abstract The (multiplicative) inverse of the quaternion `q`.           */
  static SIMD_CPPFUNC quatf inverse(const ::simd_quatf p) { return ::simd_inverse(p); }

  /*! @abstract The dot product of the quaternions `p` and `q` interpreted as
   *  four-dimensional vectors.                                               */
  static SIMD_CPPFUNC float dot(const ::simd_quatf p, const ::simd_quatf q) { return ::simd_dot(p, q); }
  
  /*! @abstract The unit quaternion obtained by normalizing `q`.              */
  static SIMD_CPPFUNC quatf normalize(const ::simd_quatf p) { return ::simd_normalize(p); }

  /*! @abstract logarithm of the quaternion `q`.                              */
  static SIMD_CPPFUNC quatf log(const ::simd_quatf q) { return ::__tg_log(q); }

  /*! @abstract exponential map of quaterion `q`.                             */
  static SIMD_CPPFUNC quatf exp(const ::simd_quatf q) { return ::__tg_exp(q); }
  
  /*! @abstract Spherical linear interpolation along the shortest arc between
   *  quaternions `q0` and `q1`.                                              */
  static SIMD_CPPFUNC quatf slerp(const ::simd_quatf p0, const ::simd_quatf p1, float t) { return ::simd_slerp(p0, p1, t); }
  
  /*! @abstract Spherical linear interpolation along the longest arc between
   *  quaternions `q0` and `q1`.                                              */
  static SIMD_CPPFUNC quatf slerp_longest(const ::simd_quatf p0, const ::simd_quatf p1, float t) { return ::simd_slerp_longest(p0, p1, t); }
  
  /*! @abstract Interpolate between quaternions along a spherical cubic spline.
   *
   *  @discussion The function interpolates between q1 and q2. q0 is the left
   *  endpoint of the previous interval, and q3 is the right endpoint of the next
   *  interval. Use this function to smoothly interpolate between a sequence of
   *  rotations.                                                              */
  static SIMD_CPPFUNC quatf spline(const ::simd_quatf p0, const ::simd_quatf p1, const ::simd_quatf p2, const ::simd_quatf p3, float t) { return ::simd_spline(p0, p1, p2, p3, t); }
  
  /*! @abstract Spherical cubic Bezier interpolation between quaternions.
   *
   *  @discussion The function treats q0 ... q3 as control points and uses slerp
   *  in place of lerp in the De Castlejeau algorithm. The endpoints of
   *  interpolation are thus q0 and q3, and the curve will not generally pass
   *  through q1 or q2. Note that the convex hull property of "standard" Bezier
   *  curve does not hold on the sphere.                                      */
  static SIMD_CPPFUNC quatf bezier(const ::simd_quatf p0, const ::simd_quatf p1, const ::simd_quatf p2, const ::simd_quatf p3, float t) { return ::simd_bezier(p0, p1, p2, p3, t); }
}

extern "C" {
#endif /* __cplusplus */
  
/*  MARK: - float implementations                                             */

#include <simd/math.h>
#include <simd/geometry.h>
  
/*  tg_promote is implementation gobbledygook that enables the compile-time
 *  dispatching in tgmath.h to work its magic.                                */
static simd_quatf __attribute__((__overloadable__)) __tg_promote(simd_quatf);
  
/*! @abstract Constructs a quaternion from imaginary and real parts.
 *  @discussion This function is hidden behind an underscore to avoid confusion
 *  with the angle-axis constructor.                                          */
static inline SIMD_CFUNC simd_quatf _simd_quaternion(simd_float3 imag, float real) {
  return simd_quaternion(simd_make_float4(imag, real));
}
  
static inline SIMD_CFUNC simd_quatf simd_quaternion(float angle, simd_float3 axis) {
  return _simd_quaternion(sin(angle/2) * axis, cos(angle/2));
}
  
static inline SIMD_CFUNC float simd_angle(simd_quatf q) {
  return 2*atan2(simd_length(q.vector.xyz), q.vector.w);
}
  
static inline SIMD_CFUNC simd_float3 simd_axis(simd_quatf q) {
  return simd_normalize(q.vector.xyz);
}
  
static inline SIMD_CFUNC simd_quatf simd_add(simd_quatf p, simd_quatf q) {
  return simd_quaternion(p.vector + q.vector);
}
  
static inline SIMD_CFUNC simd_quatf simd_sub(simd_quatf p, simd_quatf q) {
  return simd_quaternion(p.vector - q.vector);
}

static inline SIMD_CFUNC simd_quatf simd_mul(simd_quatf p, simd_quatf q) {
  #pragma STDC FP_CONTRACT ON
  return simd_quaternion((p.vector.x * __builtin_shufflevector(q.vector, -q.vector, 3,6,1,4) +
                          p.vector.y * __builtin_shufflevector(q.vector, -q.vector, 2,3,4,5)) +
                         (p.vector.z * __builtin_shufflevector(q.vector, -q.vector, 5,0,3,6) +
                          p.vector.w * q.vector));
}

static inline SIMD_CFUNC simd_quatf simd_mul(simd_quatf q, float a) {
  return simd_quaternion(a * q.vector);
}

static inline SIMD_CFUNC simd_quatf simd_mul(float a, simd_quatf q) {
  return simd_mul(q,a);
}
  
static inline SIMD_CFUNC simd_quatf simd_conjugate(simd_quatf q) {
  return simd_quaternion(q.vector * (simd_float4){-1,-1,-1, 1});
}
  
static inline SIMD_CFUNC simd_quatf simd_inverse(simd_quatf q) {
  return simd_quaternion(simd_conjugate(q).vector * simd_recip(simd_length_squared(q.vector)));
}
  
static inline SIMD_CFUNC simd_quatf simd_negate(simd_quatf q) {
  return simd_quaternion(-q.vector);
}
  
static inline SIMD_CFUNC float simd_dot(simd_quatf p, simd_quatf q) {
  return simd_dot(p.vector, q.vector);
}
  
static inline SIMD_CFUNC float simd_length(simd_quatf q) {
  return simd_length(q.vector);
}
  
static inline SIMD_CFUNC simd_quatf simd_normalize(simd_quatf q) {
  float length_squared = simd_length_squared(q.vector);
  if (length_squared == 0) {
    return simd_quaternion((simd_float4){0,0,0,1});
  }
  return simd_quaternion(q.vector * simd_rsqrt(length_squared));
}

#if defined __arm__ || defined __arm64__
/*! @abstract Multiplies the vector `v` by the quaternion `q`.
 *  
 *  @discussion This IS NOT the action of `q` on `v` (i.e. this is not rotation
 *  by `q`. That operation is provided by `simd_act(q, v)`. This function is an
 *  implementation detail and you should not call it directly. It may be
 *  removed or modified in future versions of the simd module.                */
static inline SIMD_CFUNC simd_quatf _simd_mul_vq(simd_float3 v, simd_quatf q) {
  #pragma STDC FP_CONTRACT ON
  return simd_quaternion(v.x * __builtin_shufflevector(q.vector, -q.vector, 3,6,1,4) +
                         v.y * __builtin_shufflevector(q.vector, -q.vector, 2,3,4,5) +
                         v.z * __builtin_shufflevector(q.vector, -q.vector, 5,0,3,6));
}
#endif
  
static inline SIMD_CFUNC simd_float3 simd_act(simd_quatf q, simd_float3 v) {
#if defined __arm__ || defined __arm64__
  return simd_mul(q, _simd_mul_vq(v, simd_conjugate(q))).vector.xyz;
#else
  #pragma STDC FP_CONTRACT ON
  simd_float3 t = 2*simd_cross(simd_imag(q),v);
  return v + simd_real(q)*t + simd_cross(simd_imag(q), t);
#endif
}

static SIMD_NOINLINE simd_quatf __tg_log(simd_quatf q) {
  float real = __tg_log(simd_length_squared(q.vector))/2;
  if (simd_equal(simd_imag(q), 0)) return _simd_quaternion(0, real);
  simd_float3 imag = __tg_acos(simd_real(q)/simd_length(q)) * simd_normalize(simd_imag(q));
  return _simd_quaternion(imag, real);
}
  
static SIMD_NOINLINE simd_quatf __tg_exp(simd_quatf q) {
  //  angle is actually *twice* the angle of the rotation corresponding to
  //  the resulting quaternion, which is why we don't simply use the (angle,
  //  axis) constructor to generate `unit`.
  float angle = simd_length(simd_imag(q));
  if (angle == 0) return _simd_quaternion(0, exp(simd_real(q)));
  simd_float3 axis = simd_normalize(simd_imag(q));
  simd_quatf unit = _simd_quaternion(sin(angle)*axis, cosf(angle));
  return simd_mul(exp(simd_real(q)), unit);
}
 
/*! @abstract Implementation detail of the `simd_quaternion(from, to)`
 *  initializer.
 *
 *  @discussion Computes the quaternion rotation `from` to `to` if they are
 *  separated by less than 90 degrees. Not numerically stable for larger
 *  angles. This function is an implementation detail and you should not
 *  call it directly. It may be removed or modified in future versions of the
 *  simd module.                                                              */
static inline SIMD_CFUNC simd_quatf _simd_quaternion_reduced(simd_float3 from, simd_float3 to) {
  simd_float3 half = simd_normalize(from + to);
  return _simd_quaternion(simd_cross(from, half), simd_dot(from, half));
}

static SIMD_NOINLINE simd_quatf simd_quaternion(simd_float3 from, simd_float3 to) {
  
  //  If the angle between from and to is not too big, we can compute the
  //  rotation accurately using a simple implementation.
  if (simd_dot(from, to) >= 0) {
    return _simd_quaternion_reduced(from, to);
  }
  
  //  Because from and to are more than 90 degrees apart, we compute the
  //  rotation in two stages (from -> half), (half -> to) to preserve numerical
  //  accuracy.
  simd_float3 half = from + to;
  
  if (simd_length_squared(half) == 0) {
    //  half is nearly zero, so from and to point in nearly opposite directions
    //  and the rotation is numerically underspecified. Pick an axis orthogonal
    //  to the vectors, and use an angle of pi radians.
    simd_float3 abs_from = simd_abs(from);
    if (abs_from.x <= abs_from.y && abs_from.x <= abs_from.z)
      return _simd_quaternion(simd_normalize(simd_cross(from, (simd_float3){1,0,0})), 0.f);
    else if (abs_from.y <= abs_from.z)
      return _simd_quaternion(simd_normalize(simd_cross(from, (simd_float3){0,1,0})), 0.f);
    else
      return _simd_quaternion(simd_normalize(simd_cross(from, (simd_float3){0,0,1})), 0.f);
  }

  //  Compute the two-step rotation.                         */
  half = simd_normalize(half);
  return simd_mul(_simd_quaternion_reduced(from, half),
                  _simd_quaternion_reduced(half, to));
}

static SIMD_NOINLINE simd_quatf simd_quaternion(simd_float3x3 matrix) {
  const simd_float3 *mat = matrix.columns;
  float trace = mat[0][0] + mat[1][1] + mat[2][2];
  if (trace >= 0.0) {
    float r = 2*sqrt(1 + trace);
    float rinv = simd_recip(r);
    return simd_quaternion(rinv*(mat[1][2] - mat[2][1]),
                           rinv*(mat[2][0] - mat[0][2]),
                           rinv*(mat[0][1] - mat[1][0]),
                           r/4);
  } else if (mat[0][0] >= mat[1][1] && mat[0][0] >= mat[2][2]) {
    float r = 2*sqrt(1 - mat[1][1] - mat[2][2] + mat[0][0]);
    float rinv = simd_recip(r);
    return simd_quaternion(r/4,
                           rinv*(mat[0][1] + mat[1][0]),
                           rinv*(mat[0][2] + mat[2][0]),
                           rinv*(mat[1][2] - mat[2][1]));
  } else if (mat[1][1] >= mat[2][2]) {
    float r = 2*sqrt(1 - mat[0][0] - mat[2][2] + mat[1][1]);
    float rinv = simd_recip(r);
    return simd_quaternion(rinv*(mat[0][1] + mat[1][0]),
                           r/4,
                           rinv*(mat[1][2] + mat[2][1]),
                           rinv*(mat[2][0] - mat[0][2]));
  } else {
    float r = 2*sqrt(1 - mat[0][0] - mat[1][1] + mat[2][2]);
    float rinv = simd_recip(r);
    return simd_quaternion(rinv*(mat[0][2] + mat[2][0]),
                           rinv*(mat[1][2] + mat[2][1]),
                           r/4,
                           rinv*(mat[0][1] - mat[1][0]));
  }
}
  
static SIMD_NOINLINE simd_quatf simd_quaternion(simd_float4x4 matrix) {
  const simd_float4 *mat = matrix.columns;
  float trace = mat[0][0] + mat[1][1] + mat[2][2];
  if (trace >= 0.0) {
    float r = 2*sqrt(1 + trace);
    float rinv = simd_recip(r);
    return simd_quaternion(rinv*(mat[1][2] - mat[2][1]),
                           rinv*(mat[2][0] - mat[0][2]),
                           rinv*(mat[0][1] - mat[1][0]),
                           r/4);
  } else if (mat[0][0] >= mat[1][1] && mat[0][0] >= mat[2][2]) {
    float r = 2*sqrt(1 - mat[1][1] - mat[2][2] + mat[0][0]);
    float rinv = simd_recip(r);
    return simd_quaternion(r/4,
                           rinv*(mat[0][1] + mat[1][0]),
                           rinv*(mat[0][2] + mat[2][0]),
                           rinv*(mat[1][2] - mat[2][1]));
  } else if (mat[1][1] >= mat[2][2]) {
    float r = 2*sqrt(1 - mat[0][0] - mat[2][2] + mat[1][1]);
    float rinv = simd_recip(r);
    return simd_quaternion(rinv*(mat[0][1] + mat[1][0]),
                           r/4,
                           rinv*(mat[1][2] + mat[2][1]),
                           rinv*(mat[2][0] - mat[0][2]));
  } else {
    float r = 2*sqrt(1 - mat[0][0] - mat[1][1] + mat[2][2]);
    float rinv = simd_recip(r);
    return simd_quaternion(rinv*(mat[0][2] + mat[2][0]),
                           rinv*(mat[1][2] + mat[2][1]),
                           r/4,
                           rinv*(mat[0][1] - mat[1][0]));
  }
}
  
/*! @abstract The angle between p and q interpreted as 4-dimensional vectors.
 *
 *  @discussion This function is an implementation detail and you should not
 *  call it directly. It may be removed or modified in future versions of the
 *  simd module.                                                              */
static SIMD_NOINLINE float _simd_angle(simd_quatf p, simd_quatf q) {
  return 2*atan2(simd_length(p.vector - q.vector), simd_length(p.vector + q.vector));
}
  
/*! @abstract sin(x)/x.
 *
 *  @discussion This function is an implementation detail and you should not
 *  call it directly. It may be removed or modified in future versions of the
 *  simd module.                                                              */
static SIMD_CFUNC float _simd_sinc(float x) {
  if (x == 0) return 1;
  return sin(x)/x;
}
 
/*! @abstract Spherical lerp between q0 and q1.
 *
 *  @discussion This function may interpolate along either the longer or
 *  shorter path between q0 and q1; it is used as an implementation detail
 *  in `simd_slerp` and `simd_slerp_longest`; you should use those functions
 *  instead of calling this directly.                                         */
static SIMD_NOINLINE simd_quatf _simd_slerp_internal(simd_quatf q0, simd_quatf q1, float t) {
  float s = 1 - t;
  float a = _simd_angle(q0, q1);
  float r = simd_recip(_simd_sinc(a));
  return simd_normalize(simd_quaternion(_simd_sinc(s*a)*r*s*q0.vector + _simd_sinc(t*a)*r*t*q1.vector));
}
  
static SIMD_NOINLINE simd_quatf simd_slerp(simd_quatf q0, simd_quatf q1, float t) {
  if (simd_dot(q0, q1) >= 0)
    return _simd_slerp_internal(q0, q1, t);
  return _simd_slerp_internal(q0, simd_negate(q1), t);
}

static SIMD_NOINLINE simd_quatf simd_slerp_longest(simd_quatf q0, simd_quatf q1, float t) {
  if (simd_dot(q0, q1) >= 0)
    return _simd_slerp_internal(q0, simd_negate(q1), t);
  return _simd_slerp_internal(q0, q1, t);
}
  
/*! @discussion This function is an implementation detail and you should not
 *  call it directly. It may be removed or modified in future versions of the
 *  simd module.                                                              */
static SIMD_NOINLINE simd_quatf _simd_intermediate(simd_quatf q0, simd_quatf q1, simd_quatf q2) {
  simd_quatf p0 = __tg_log(simd_mul(q0, simd_inverse(q1)));
  simd_quatf p2 = __tg_log(simd_mul(q2, simd_inverse(q1)));
  return simd_normalize(simd_mul(q1, __tg_exp(simd_mul(-0.25, simd_add(p0,p2)))));
}

/*! @discussion This function is an implementation detail and you should not
 *  call it directly. It may be removed or modified in future versions of the
 *  simd module.                                                              */
static SIMD_NOINLINE simd_quatf _simd_squad(simd_quatf q0, simd_quatf qa, simd_quatf qb, simd_quatf q1, float t) {
  simd_quatf r0 = _simd_slerp_internal(q0, q1, t);
  simd_quatf r1 = _simd_slerp_internal(qa, qb, t);
  return _simd_slerp_internal(r0, r1, 2*t*(1 - t));
}
  
static SIMD_NOINLINE simd_quatf simd_spline(simd_quatf q0, simd_quatf q1, simd_quatf q2, simd_quatf q3, float t) {
  simd_quatf qa = _simd_intermediate(q0, q1, q2);
  simd_quatf qb = _simd_intermediate(q1, q2, q3);
  return _simd_squad(q1, qa, qb, q2, t);
}
  
static SIMD_NOINLINE simd_quatf simd_bezier(simd_quatf q0, simd_quatf q1, simd_quatf q2, simd_quatf q3, float t) {
  simd_quatf q01 = _simd_slerp_internal(q0, q1, t);
  simd_quatf q12 = _simd_slerp_internal(q1, q2, t);
  simd_quatf q23 = _simd_slerp_internal(q2, q3, t);
  simd_quatf q012 = _simd_slerp_internal(q01, q12, t);
  simd_quatf q123 = _simd_slerp_internal(q12, q23, t);
  return _simd_slerp_internal(q012, q123, t);
}

/*  MARK: - C and Objective-C double interfaces                                */

/*! @abstract Constructs a quaternion from four scalar values.
 *
 *  @param ix The first component of the imaginary (vector) part.
 *  @param iy The second component of the imaginary (vector) part.
 *  @param iz The third component of the imaginary (vector) part.
 *
 *  @param r The real (scalar) part.                                          */
static inline SIMD_CFUNC simd_quatd simd_quaternion(double ix, double iy, double iz, double r) {
  return (simd_quatd){ { ix, iy, iz, r } };
}
  
/*! @abstract Constructs a quaternion from an array of four scalars.
 *
 *  @discussion Note that the imaginary part of the quaternion comes from 
 *  array elements 0, 1, and 2, and the real part comes from element 3.       */
static inline SIMD_NONCONST simd_quatd simd_quaternion(const double xyzr[4]) {
  return (simd_quatd){ *(const simd_packed_double4 *)xyzr };
}
  
/*! @abstract Constructs a quaternion from a four-element vector.
 *
 *  @discussion Note that the imaginary (vector) part of the quaternion comes
 *  from lanes 0, 1, and 2 of the vector, and the real (scalar) part comes from
 *  lane 3.                                                                   */
static inline SIMD_CFUNC simd_quatd simd_quaternion(simd_double4 xyzr) {
  return (simd_quatd){ xyzr };
}
  
/*! @abstract Constructs a quaternion that rotates by `angle` radians about
 *  `axis`.                                                                   */
static inline SIMD_CFUNC simd_quatd simd_quaternion(double angle, simd_double3 axis);
  
/*! @abstract Construct a quaternion that rotates from one vector to another.
 *
 *  @param from A normalized three-element vector.
 *  @param to A normalized three-element vector.
 *
 *  @discussion The rotation axis is `simd_cross(from, to)`. If `from` and
 *  `to` point in opposite directions (to within machine precision), an
 *  arbitrary rotation axis is chosen, and the angle is pi radians.           */
static SIMD_NOINLINE simd_quatd simd_quaternion(simd_double3 from, simd_double3 to);

/*! @abstract Construct a quaternion from a 3x3 rotation `matrix`.
 *
 *  @discussion If `matrix` is not orthogonal with determinant 1, the result
 *  is undefined.                                                             */
static SIMD_NOINLINE simd_quatd simd_quaternion(simd_double3x3 matrix);

/*! @abstract Construct a quaternion from a 4x4 rotation `matrix`.
 *
 *  @discussion The last row and column of the matrix are ignored. This
 *  function is equivalent to calling simd_quaternion with the upper-left 3x3
 *  submatrix                .                                                */
static SIMD_NOINLINE simd_quatd simd_quaternion(simd_double4x4 matrix);
  
/*! @abstract The real (scalar) part of the quaternion `q`.                   */
static inline SIMD_CFUNC double simd_real(simd_quatd q) {
  return q.vector.w;
}
  
/*! @abstract The imaginary (vector) part of the quaternion `q`.              */
static inline SIMD_CFUNC simd_double3 simd_imag(simd_quatd q) {
  return q.vector.xyz;
}
  
/*! @abstract The angle (in radians) of rotation represented by `q`.          */
static inline SIMD_CFUNC double simd_angle(simd_quatd q);
  
/*! @abstract The normalized axis (a 3-element vector) around which the
 *  action of the quaternion `q` rotates.                                     */
static inline SIMD_CFUNC simd_double3 simd_axis(simd_quatd q);
  
/*! @abstract The sum of the quaternions `p` and `q`.                         */
static inline SIMD_CFUNC simd_quatd simd_add(simd_quatd p, simd_quatd q);
  
/*! @abstract The difference of the quaternions `p` and `q`.                  */
static inline SIMD_CFUNC simd_quatd simd_sub(simd_quatd p, simd_quatd q);
  
/*! @abstract The product of the quaternions `p` and `q`.                     */
static inline SIMD_CFUNC simd_quatd simd_mul(simd_quatd p, simd_quatd q);
  
/*! @abstract The quaternion `q` scaled by the real value `a`.                */
static inline SIMD_CFUNC simd_quatd simd_mul(simd_quatd q, double a);
  
/*! @abstract The quaternion `q` scaled by the real value `a`.                */
static inline SIMD_CFUNC simd_quatd simd_mul(double a, simd_quatd q);
  
/*! @abstract The conjugate of the quaternion `q`.                            */
static inline SIMD_CFUNC simd_quatd simd_conjugate(simd_quatd q);
  
/*! @abstract The (multiplicative) inverse of the quaternion `q`.             */
static inline SIMD_CFUNC simd_quatd simd_inverse(simd_quatd q);
  
/*! @abstract The negation (additive inverse) of the quaternion `q`.          */
static inline SIMD_CFUNC simd_quatd simd_negate(simd_quatd q);
  
/*! @abstract The dot product of the quaternions `p` and `q` interpreted as
 *  four-dimensional vectors.                                                 */
static inline SIMD_CFUNC double simd_dot(simd_quatd p, simd_quatd q);
  
/*! @abstract The length of the quaternion `q`.                               */
static inline SIMD_CFUNC double simd_length(simd_quatd q);
  
/*! @abstract The unit quaternion obtained by normalizing `q`.                */
static inline SIMD_CFUNC simd_quatd simd_normalize(simd_quatd q);
  
/*! @abstract Rotates the vector `v` by the quaternion `q`.                   */
static inline SIMD_CFUNC simd_double3 simd_act(simd_quatd q, simd_double3 v);
  
/*! @abstract Logarithm of the quaternion `q`.
 *  @discussion Do not call this function directly; use `log(q)` instead.
 *
 *  We can write a quaternion `q` in the form: `r(cos(t) + sin(t)v)` where
 *  `r` is the length of `q`, `t` is an angle, and `v` is a unit 3-vector.
 *  The logarithm of `q` is `log(r) + tv`, just like the logarithm of the
 *  complex number `r*(cos(t) + i sin(t))` is `log(r) + it`.
 *
 *  Note that this function is not robust against poorly-scaled non-unit
 *  quaternions, because it is primarily used for spline interpolation of
 *  unit quaternions. If you need to compute a robust logarithm of general
 *  quaternions, you can use the following approach:
 *
 *    scale = simd_reduce_max(simd_abs(q.vector));
 *    logq = log(simd_recip(scale)*q);
 *    logq.real += log(scale);
 *    return logq;                                                            */
static SIMD_NOINLINE simd_quatd __tg_log(simd_quatd q);
    
/*! @abstract Inverse of `log( )`; the exponential map on quaternions.
 *  @discussion Do not call this function directly; use `exp(q)` instead.     */
static SIMD_NOINLINE simd_quatd __tg_exp(simd_quatd q);
  
/*! @abstract Spherical linear interpolation along the shortest arc between
 *  quaternions `q0` and `q1`.                                                */
static SIMD_NOINLINE simd_quatd simd_slerp(simd_quatd q0, simd_quatd q1, double t);

/*! @abstract Spherical linear interpolation along the longest arc between
 *  quaternions `q0` and `q1`.                                                */
static SIMD_NOINLINE simd_quatd simd_slerp_longest(simd_quatd q0, simd_quatd q1, double t);

/*! @abstract Interpolate between quaternions along a spherical cubic spline.
 *
 *  @discussion The function interpolates between q1 and q2. q0 is the left
 *  endpoint of the previous interval, and q3 is the right endpoint of the next
 *  interval. Use this function to smoothly interpolate between a sequence of
 *  rotations.                                                                */
static SIMD_NOINLINE simd_quatd simd_spline(simd_quatd q0, simd_quatd q1, simd_quatd q2, simd_quatd q3, double t);

/*! @abstract Spherical cubic Bezier interpolation between quaternions.
 *
 *  @discussion The function treats q0 ... q3 as control points and uses slerp
 *  in place of lerp in the De Castlejeau algorithm. The endpoints of
 *  interpolation are thus q0 and q3, and the curve will not generally pass
 *  through q1 or q2. Note that the convex hull property of "standard" Bezier
 *  curve does not hold on the sphere.                                        */
static SIMD_NOINLINE simd_quatd simd_bezier(simd_quatd q0, simd_quatd q1, simd_quatd q2, simd_quatd q3, double t);
  
#ifdef __cplusplus
} /* extern "C" */
/*  MARK: - C++ double interfaces                                              */

namespace simd {
  struct quatd : ::simd_quatd {
    /*! @abstract The identity quaternion.                                    */
    quatd( ) : ::simd_quatd(::simd_quaternion((double4){0,0,0,1})) { }
    
    /*! @abstract Constructs a C++ quaternion from a C quaternion.            */
    quatd(::simd_quatd q) : ::simd_quatd(q) { }
    
    /*! @abstract Constructs a quaternion from components.                    */
    quatd(double ix, double iy, double iz, double r) : ::simd_quatd(::simd_quaternion(ix, iy, iz, r)) { }
    
    /*! @abstract Constructs a quaternion from an array of scalars.           */
    quatd(const double xyzr[4]) : ::simd_quatd(::simd_quaternion(xyzr)) { }
    
    /*! @abstract Constructs a quaternion from a vector.                      */
    quatd(double4 xyzr) : ::simd_quatd(::simd_quaternion(xyzr)) { }
    
    /*! @abstract Quaternion representing rotation about `axis` by `angle` 
     *  radians.                                                              */
    quatd(double angle, double3 axis) : ::simd_quatd(::simd_quaternion(angle, axis)) { }
    
    /*! @abstract Quaternion that rotates `from` into `to`.                   */
    quatd(double3 from, double3 to) : ::simd_quatd(::simd_quaternion(from, to)) { }
    
    /*! @abstract Constructs a quaternion from a rotation matrix.             */
    quatd(::simd_double3x3 matrix) : ::simd_quatd(::simd_quaternion(matrix)) { }
    
    /*! @abstract Constructs a quaternion from a rotation matrix.             */
    quatd(::simd_double4x4 matrix) : ::simd_quatd(::simd_quaternion(matrix)) { }
  
    /*! @abstract The real (scalar) part of the quaternion.                   */
    double real(void) const { return ::simd_real(*this); }
    
    /*! @abstract The imaginary (vector) part of the quaternion.              */
    double3 imag(void) const { return ::simd_imag(*this); }
    
    /*! @abstract The angle the quaternion rotates by.                        */
    double angle(void) const { return ::simd_angle(*this); }
    
    /*! @abstract The axis the quaternion rotates about.                      */
    double3 axis(void) const { return ::simd_axis(*this); }
    
    /*! @abstract The length of the quaternion.                               */
    double length(void) const { return ::simd_length(*this); }
    
    /*! @abstract Act on the vector `v` by rotation.                          */
    double3  operator()(const ::simd_double3 v) const { return ::simd_act(*this, v); }
  };
  
  static SIMD_CPPFUNC quatd operator+(const ::simd_quatd p, const ::simd_quatd q) { return ::simd_add(p, q); }
  static SIMD_CPPFUNC quatd operator-(const ::simd_quatd p, const ::simd_quatd q) { return ::simd_sub(p, q); }
  static SIMD_CPPFUNC quatd operator-(const ::simd_quatd p) { return ::simd_negate(p); }
  static SIMD_CPPFUNC quatd operator*(const double r, const ::simd_quatd p) { return ::simd_mul(r, p); }
  static SIMD_CPPFUNC quatd operator*(const ::simd_quatd p, const double r) { return ::simd_mul(p, r); }
  static SIMD_CPPFUNC quatd operator*(const ::simd_quatd p, const ::simd_quatd q) { return ::simd_mul(p, q); }
  static SIMD_CPPFUNC quatd operator/(const ::simd_quatd p, const ::simd_quatd q) { return ::simd_mul(p, ::simd_inverse(q)); }
  static SIMD_CPPFUNC quatd operator+=(quatd &p, const ::simd_quatd q) { return p = p+q; }
  static SIMD_CPPFUNC quatd operator-=(quatd &p, const ::simd_quatd q) { return p = p-q; }
  static SIMD_CPPFUNC quatd operator*=(quatd &p, const double r) { return p = p*r; }
  static SIMD_CPPFUNC quatd operator*=(quatd &p, const ::simd_quatd q) { return p = p*q; }
  static SIMD_CPPFUNC quatd operator/=(quatd &p, const ::simd_quatd q) { return p = p/q; }
  
  /*! @abstract The conjugate of the quaternion `q`.                          */
  static SIMD_CPPFUNC quatd conjugate(const ::simd_quatd p) { return ::simd_conjugate(p); }
  
  /*! @abstract The (multiplicative) inverse of the quaternion `q`.           */
  static SIMD_CPPFUNC quatd inverse(const ::simd_quatd p) { return ::simd_inverse(p); }

  /*! @abstract The dot product of the quaternions `p` and `q` interpreted as
   *  four-dimensional vectors.                                               */
  static SIMD_CPPFUNC double dot(const ::simd_quatd p, const ::simd_quatd q) { return ::simd_dot(p, q); }
  
  /*! @abstract The unit quaternion obtained by normalizing `q`.              */
  static SIMD_CPPFUNC quatd normalize(const ::simd_quatd p) { return ::simd_normalize(p); }

  /*! @abstract logarithm of the quaternion `q`.                              */
  static SIMD_CPPFUNC quatd log(const ::simd_quatd q) { return ::__tg_log(q); }

  /*! @abstract exponential map of quaterion `q`.                             */
  static SIMD_CPPFUNC quatd exp(const ::simd_quatd q) { return ::__tg_exp(q); }
  
  /*! @abstract Spherical linear interpolation along the shortest arc between
   *  quaternions `q0` and `q1`.                                              */
  static SIMD_CPPFUNC quatd slerp(const ::simd_quatd p0, const ::simd_quatd p1, double t) { return ::simd_slerp(p0, p1, t); }
  
  /*! @abstract Spherical linear interpolation along the longest arc between
   *  quaternions `q0` and `q1`.                                              */
  static SIMD_CPPFUNC quatd slerp_longest(const ::simd_quatd p0, const ::simd_quatd p1, double t) { return ::simd_slerp_longest(p0, p1, t); }
  
  /*! @abstract Interpolate between quaternions along a spherical cubic spline.
   *
   *  @discussion The function interpolates between q1 and q2. q0 is the left
   *  endpoint of the previous interval, and q3 is the right endpoint of the next
   *  interval. Use this function to smoothly interpolate between a sequence of
   *  rotations.                                                              */
  static SIMD_CPPFUNC quatd spline(const ::simd_quatd p0, const ::simd_quatd p1, const ::simd_quatd p2, const ::simd_quatd p3, double t) { return ::simd_spline(p0, p1, p2, p3, t); }
  
  /*! @abstract Spherical cubic Bezier interpolation between quaternions.
   *
   *  @discussion The function treats q0 ... q3 as control points and uses slerp
   *  in place of lerp in the De Castlejeau algorithm. The endpoints of
   *  interpolation are thus q0 and q3, and the curve will not generally pass
   *  through q1 or q2. Note that the convex hull property of "standard" Bezier
   *  curve does not hold on the sphere.                                      */
  static SIMD_CPPFUNC quatd bezier(const ::simd_quatd p0, const ::simd_quatd p1, const ::simd_quatd p2, const ::simd_quatd p3, double t) { return ::simd_bezier(p0, p1, p2, p3, t); }
}

extern "C" {
#endif /* __cplusplus */
  
/*  MARK: - double implementations                                             */

#include <simd/math.h>
#include <simd/geometry.h>
  
/*  tg_promote is implementation gobbledygook that enables the compile-time
 *  dispatching in tgmath.h to work its magic.                                */
static simd_quatd __attribute__((__overloadable__)) __tg_promote(simd_quatd);
  
/*! @abstract Constructs a quaternion from imaginary and real parts.
 *  @discussion This function is hidden behind an underscore to avoid confusion
 *  with the angle-axis constructor.                                          */
static inline SIMD_CFUNC simd_quatd _simd_quaternion(simd_double3 imag, double real) {
  return simd_quaternion(simd_make_double4(imag, real));
}
  
static inline SIMD_CFUNC simd_quatd simd_quaternion(double angle, simd_double3 axis) {
  return _simd_quaternion(sin(angle/2) * axis, cos(angle/2));
}
  
static inline SIMD_CFUNC double simd_angle(simd_quatd q) {
  return 2*atan2(simd_length(q.vector.xyz), q.vector.w);
}
  
static inline SIMD_CFUNC simd_double3 simd_axis(simd_quatd q) {
  return simd_normalize(q.vector.xyz);
}
  
static inline SIMD_CFUNC simd_quatd simd_add(simd_quatd p, simd_quatd q) {
  return simd_quaternion(p.vector + q.vector);
}
  
static inline SIMD_CFUNC simd_quatd simd_sub(simd_quatd p, simd_quatd q) {
  return simd_quaternion(p.vector - q.vector);
}

static inline SIMD_CFUNC simd_quatd simd_mul(simd_quatd p, simd_quatd q) {
  #pragma STDC FP_CONTRACT ON
  return simd_quaternion((p.vector.x * __builtin_shufflevector(q.vector, -q.vector, 3,6,1,4) +
                          p.vector.y * __builtin_shufflevector(q.vector, -q.vector, 2,3,4,5)) +
                         (p.vector.z * __builtin_shufflevector(q.vector, -q.vector, 5,0,3,6) +
                          p.vector.w * q.vector));
}

static inline SIMD_CFUNC simd_quatd simd_mul(simd_quatd q, double a) {
  return simd_quaternion(a * q.vector);
}

static inline SIMD_CFUNC simd_quatd simd_mul(double a, simd_quatd q) {
  return simd_mul(q,a);
}
  
static inline SIMD_CFUNC simd_quatd simd_conjugate(simd_quatd q) {
  return simd_quaternion(q.vector * (simd_double4){-1,-1,-1, 1});
}
  
static inline SIMD_CFUNC simd_quatd simd_inverse(simd_quatd q) {
  return simd_quaternion(simd_conjugate(q).vector * simd_recip(simd_length_squared(q.vector)));
}
  
static inline SIMD_CFUNC simd_quatd simd_negate(simd_quatd q) {
  return simd_quaternion(-q.vector);
}
  
static inline SIMD_CFUNC double simd_dot(simd_quatd p, simd_quatd q) {
  return simd_dot(p.vector, q.vector);
}
  
static inline SIMD_CFUNC double simd_length(simd_quatd q) {
  return simd_length(q.vector);
}
  
static inline SIMD_CFUNC simd_quatd simd_normalize(simd_quatd q) {
  double length_squared = simd_length_squared(q.vector);
  if (length_squared == 0) {
    return simd_quaternion((simd_double4){0,0,0,1});
  }
  return simd_quaternion(q.vector * simd_rsqrt(length_squared));
}

#if defined __arm__ || defined __arm64__
/*! @abstract Multiplies the vector `v` by the quaternion `q`.
 *  
 *  @discussion This IS NOT the action of `q` on `v` (i.e. this is not rotation
 *  by `q`. That operation is provided by `simd_act(q, v)`. This function is an
 *  implementation detail and you should not call it directly. It may be
 *  removed or modified in future versions of the simd module.                */
static inline SIMD_CFUNC simd_quatd _simd_mul_vq(simd_double3 v, simd_quatd q) {
  #pragma STDC FP_CONTRACT ON
  return simd_quaternion(v.x * __builtin_shufflevector(q.vector, -q.vector, 3,6,1,4) +
                         v.y * __builtin_shufflevector(q.vector, -q.vector, 2,3,4,5) +
                         v.z * __builtin_shufflevector(q.vector, -q.vector, 5,0,3,6));
}
#endif
  
static inline SIMD_CFUNC simd_double3 simd_act(simd_quatd q, simd_double3 v) {
#if defined __arm__ || defined __arm64__
  return simd_mul(q, _simd_mul_vq(v, simd_conjugate(q))).vector.xyz;
#else
  #pragma STDC FP_CONTRACT ON
  simd_double3 t = 2*simd_cross(simd_imag(q),v);
  return v + simd_real(q)*t + simd_cross(simd_imag(q), t);
#endif
}

static SIMD_NOINLINE simd_quatd __tg_log(simd_quatd q) {
  double real = __tg_log(simd_length_squared(q.vector))/2;
  if (simd_equal(simd_imag(q), 0)) return _simd_quaternion(0, real);
  simd_double3 imag = __tg_acos(simd_real(q)/simd_length(q)) * simd_normalize(simd_imag(q));
  return _simd_quaternion(imag, real);
}
  
static SIMD_NOINLINE simd_quatd __tg_exp(simd_quatd q) {
  //  angle is actually *twice* the angle of the rotation corresponding to
  //  the resulting quaternion, which is why we don't simply use the (angle,
  //  axis) constructor to generate `unit`.
  double angle = simd_length(simd_imag(q));
  if (angle == 0) return _simd_quaternion(0, exp(simd_real(q)));
  simd_double3 axis = simd_normalize(simd_imag(q));
  simd_quatd unit = _simd_quaternion(sin(angle)*axis, cosf(angle));
  return simd_mul(exp(simd_real(q)), unit);
}
 
/*! @abstract Implementation detail of the `simd_quaternion(from, to)`
 *  initializer.
 *
 *  @discussion Computes the quaternion rotation `from` to `to` if they are
 *  separated by less than 90 degrees. Not numerically stable for larger
 *  angles. This function is an implementation detail and you should not
 *  call it directly. It may be removed or modified in future versions of the
 *  simd module.                                                              */
static inline SIMD_CFUNC simd_quatd _simd_quaternion_reduced(simd_double3 from, simd_double3 to) {
  simd_double3 half = simd_normalize(from + to);
  return _simd_quaternion(simd_cross(from, half), simd_dot(from, half));
}

static SIMD_NOINLINE simd_quatd simd_quaternion(simd_double3 from, simd_double3 to) {
  
  //  If the angle between from and to is not too big, we can compute the
  //  rotation accurately using a simple implementation.
  if (simd_dot(from, to) >= 0) {
    return _simd_quaternion_reduced(from, to);
  }
  
  //  Because from and to are more than 90 degrees apart, we compute the
  //  rotation in two stages (from -> half), (half -> to) to preserve numerical
  //  accuracy.
  simd_double3 half = from + to;
  
  if (simd_length_squared(half) == 0) {
    //  half is nearly zero, so from and to point in nearly opposite directions
    //  and the rotation is numerically underspecified. Pick an axis orthogonal
    //  to the vectors, and use an angle of pi radians.
    simd_double3 abs_from = simd_abs(from);
    if (abs_from.x <= abs_from.y && abs_from.x <= abs_from.z)
      return _simd_quaternion(simd_normalize(simd_cross(from, (simd_double3){1,0,0})), 0.f);
    else if (abs_from.y <= abs_from.z)
      return _simd_quaternion(simd_normalize(simd_cross(from, (simd_double3){0,1,0})), 0.f);
    else
      return _simd_quaternion(simd_normalize(simd_cross(from, (simd_double3){0,0,1})), 0.f);
  }

  //  Compute the two-step rotation.                         */
  half = simd_normalize(half);
  return simd_mul(_simd_quaternion_reduced(from, half),
                  _simd_quaternion_reduced(half, to));
}

static SIMD_NOINLINE simd_quatd simd_quaternion(simd_double3x3 matrix) {
  const simd_double3 *mat = matrix.columns;
  double trace = mat[0][0] + mat[1][1] + mat[2][2];
  if (trace >= 0.0) {
    double r = 2*sqrt(1 + trace);
    double rinv = simd_recip(r);
    return simd_quaternion(rinv*(mat[1][2] - mat[2][1]),
                           rinv*(mat[2][0] - mat[0][2]),
                           rinv*(mat[0][1] - mat[1][0]),
                           r/4);
  } else if (mat[0][0] >= mat[1][1] && mat[0][0] >= mat[2][2]) {
    double r = 2*sqrt(1 - mat[1][1] - mat[2][2] + mat[0][0]);
    double rinv = simd_recip(r);
    return simd_quaternion(r/4,
                           rinv*(mat[0][1] + mat[1][0]),
                           rinv*(mat[0][2] + mat[2][0]),
                           rinv*(mat[1][2] - mat[2][1]));
  } else if (mat[1][1] >= mat[2][2]) {
    double r = 2*sqrt(1 - mat[0][0] - mat[2][2] + mat[1][1]);
    double rinv = simd_recip(r);
    return simd_quaternion(rinv*(mat[0][1] + mat[1][0]),
                           r/4,
                           rinv*(mat[1][2] + mat[2][1]),
                           rinv*(mat[2][0] - mat[0][2]));
  } else {
    double r = 2*sqrt(1 - mat[0][0] - mat[1][1] + mat[2][2]);
    double rinv = simd_recip(r);
    return simd_quaternion(rinv*(mat[0][2] + mat[2][0]),
                           rinv*(mat[1][2] + mat[2][1]),
                           r/4,
                           rinv*(mat[0][1] - mat[1][0]));
  }
}
  
static SIMD_NOINLINE simd_quatd simd_quaternion(simd_double4x4 matrix) {
  const simd_double4 *mat = matrix.columns;
  double trace = mat[0][0] + mat[1][1] + mat[2][2];
  if (trace >= 0.0) {
    double r = 2*sqrt(1 + trace);
    double rinv = simd_recip(r);
    return simd_quaternion(rinv*(mat[1][2] - mat[2][1]),
                           rinv*(mat[2][0] - mat[0][2]),
                           rinv*(mat[0][1] - mat[1][0]),
                           r/4);
  } else if (mat[0][0] >= mat[1][1] && mat[0][0] >= mat[2][2]) {
    double r = 2*sqrt(1 - mat[1][1] - mat[2][2] + mat[0][0]);
    double rinv = simd_recip(r);
    return simd_quaternion(r/4,
                           rinv*(mat[0][1] + mat[1][0]),
                           rinv*(mat[0][2] + mat[2][0]),
                           rinv*(mat[1][2] - mat[2][1]));
  } else if (mat[1][1] >= mat[2][2]) {
    double r = 2*sqrt(1 - mat[0][0] - mat[2][2] + mat[1][1]);
    double rinv = simd_recip(r);
    return simd_quaternion(rinv*(mat[0][1] + mat[1][0]),
                           r/4,
                           rinv*(mat[1][2] + mat[2][1]),
                           rinv*(mat[2][0] - mat[0][2]));
  } else {
    double r = 2*sqrt(1 - mat[0][0] - mat[1][1] + mat[2][2]);
    double rinv = simd_recip(r);
    return simd_quaternion(rinv*(mat[0][2] + mat[2][0]),
                           rinv*(mat[1][2] + mat[2][1]),
                           r/4,
                           rinv*(mat[0][1] - mat[1][0]));
  }
}
  
/*! @abstract The angle between p and q interpreted as 4-dimensional vectors.
 *
 *  @discussion This function is an implementation detail and you should not
 *  call it directly. It may be removed or modified in future versions of the
 *  simd module.                                                              */
static SIMD_NOINLINE double _simd_angle(simd_quatd p, simd_quatd q) {
  return 2*atan2(simd_length(p.vector - q.vector), simd_length(p.vector + q.vector));
}
  
/*! @abstract sin(x)/x.
 *
 *  @discussion This function is an implementation detail and you should not
 *  call it directly. It may be removed or modified in future versions of the
 *  simd module.                                                              */
static SIMD_CFUNC double _simd_sinc(double x) {
  if (x == 0) return 1;
  return sin(x)/x;
}
 
/*! @abstract Spherical lerp between q0 and q1.
 *
 *  @discussion This function may interpolate along either the longer or
 *  shorter path between q0 and q1; it is used as an implementation detail
 *  in `simd_slerp` and `simd_slerp_longest`; you should use those functions
 *  instead of calling this directly.                                         */
static SIMD_NOINLINE simd_quatd _simd_slerp_internal(simd_quatd q0, simd_quatd q1, double t) {
  double s = 1 - t;
  double a = _simd_angle(q0, q1);
  double r = simd_recip(_simd_sinc(a));
  return simd_normalize(simd_quaternion(_simd_sinc(s*a)*r*s*q0.vector + _simd_sinc(t*a)*r*t*q1.vector));
}
  
static SIMD_NOINLINE simd_quatd simd_slerp(simd_quatd q0, simd_quatd q1, double t) {
  if (simd_dot(q0, q1) >= 0)
    return _simd_slerp_internal(q0, q1, t);
  return _simd_slerp_internal(q0, simd_negate(q1), t);
}

static SIMD_NOINLINE simd_quatd simd_slerp_longest(simd_quatd q0, simd_quatd q1, double t) {
  if (simd_dot(q0, q1) >= 0)
    return _simd_slerp_internal(q0, simd_negate(q1), t);
  return _simd_slerp_internal(q0, q1, t);
}
  
/*! @discussion This function is an implementation detail and you should not
 *  call it directly. It may be removed or modified in future versions of the
 *  simd module.                                                              */
static SIMD_NOINLINE simd_quatd _simd_intermediate(simd_quatd q0, simd_quatd q1, simd_quatd q2) {
  simd_quatd p0 = __tg_log(simd_mul(q0, simd_inverse(q1)));
  simd_quatd p2 = __tg_log(simd_mul(q2, simd_inverse(q1)));
  return simd_normalize(simd_mul(q1, __tg_exp(simd_mul(-0.25, simd_add(p0,p2)))));
}

/*! @discussion This function is an implementation detail and you should not
 *  call it directly. It may be removed or modified in future versions of the
 *  simd module.                                                              */
static SIMD_NOINLINE simd_quatd _simd_squad(simd_quatd q0, simd_quatd qa, simd_quatd qb, simd_quatd q1, double t) {
  simd_quatd r0 = _simd_slerp_internal(q0, q1, t);
  simd_quatd r1 = _simd_slerp_internal(qa, qb, t);
  return _simd_slerp_internal(r0, r1, 2*t*(1 - t));
}
  
static SIMD_NOINLINE simd_quatd simd_spline(simd_quatd q0, simd_quatd q1, simd_quatd q2, simd_quatd q3, double t) {
  simd_quatd qa = _simd_intermediate(q0, q1, q2);
  simd_quatd qb = _simd_intermediate(q1, q2, q3);
  return _simd_squad(q1, qa, qb, q2, t);
}
  
static SIMD_NOINLINE simd_quatd simd_bezier(simd_quatd q0, simd_quatd q1, simd_quatd q2, simd_quatd q3, double t) {
  simd_quatd q01 = _simd_slerp_internal(q0, q1, t);
  simd_quatd q12 = _simd_slerp_internal(q1, q2, t);
  simd_quatd q23 = _simd_slerp_internal(q2, q3, t);
  simd_quatd q012 = _simd_slerp_internal(q01, q12, t);
  simd_quatd q123 = _simd_slerp_internal(q12, q23, t);
  return _simd_slerp_internal(q012, q123, t);
}

#ifdef __cplusplus
}      /* extern "C"  */
#endif /* __cplusplus */
#endif /* SIMD_COMPILER_HAS_REQUIRED_FEATURES */
#endif /* SIMD_QUATERNIONS */
