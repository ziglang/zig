/*
 * Copyright (C) 2007 David Adam
 * Copyright (C) 2007 Tony Wasserka
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#ifndef __D3DX9MATH_INL__
#define __D3DX9MATH_INL__

/* constructors & operators */
#ifdef __cplusplus

inline D3DXVECTOR2::D3DXVECTOR2()
{
}

inline D3DXVECTOR2::D3DXVECTOR2(const FLOAT *pf)
{
    if(!pf) return;
    x = pf[0];
    y = pf[1];
}

inline D3DXVECTOR2::D3DXVECTOR2(FLOAT fx, FLOAT fy)
{
    x = fx;
    y = fy;
}

inline D3DXVECTOR2::operator FLOAT* ()
{
    return (FLOAT*)&x;
}

inline D3DXVECTOR2::operator const FLOAT* () const
{
    return (const FLOAT*)&x;
}

inline D3DXVECTOR2& D3DXVECTOR2::operator += (const D3DXVECTOR2& v)
{
    x += v.x;
    y += v.y;
    return *this;
}

inline D3DXVECTOR2& D3DXVECTOR2::operator -= (const D3DXVECTOR2& v)
{
    x -= v.x;
    y -= v.y;
    return *this;
}

inline D3DXVECTOR2& D3DXVECTOR2::operator *= (FLOAT f)
{
    x *= f;
    y *= f;
    return *this;
}

inline D3DXVECTOR2& D3DXVECTOR2::operator /= (FLOAT f)
{
    x /= f;
    y /= f;
    return *this;
}

inline D3DXVECTOR2 D3DXVECTOR2::operator + () const
{
    return *this;
}

inline D3DXVECTOR2 D3DXVECTOR2::operator - () const
{
    return D3DXVECTOR2(-x, -y);
}

inline D3DXVECTOR2 D3DXVECTOR2::operator + (const D3DXVECTOR2& v) const
{
    return D3DXVECTOR2(x + v.x, y + v.y);
}

inline D3DXVECTOR2 D3DXVECTOR2::operator - (const D3DXVECTOR2& v) const
{
    return D3DXVECTOR2(x - v.x, y - v.y);
}

inline D3DXVECTOR2 D3DXVECTOR2::operator * (FLOAT f) const
{
    return D3DXVECTOR2(x * f, y * f);
}

inline D3DXVECTOR2 D3DXVECTOR2::operator / (FLOAT f) const
{
    return D3DXVECTOR2(x / f, y / f);
}

inline D3DXVECTOR2 operator * (FLOAT f, const D3DXVECTOR2& v)
{
    return D3DXVECTOR2(f * v.x, f * v.y);
}

inline WINBOOL D3DXVECTOR2::operator == (const D3DXVECTOR2& v) const
{
    return x == v.x && y == v.y;
}

inline WINBOOL D3DXVECTOR2::operator != (const D3DXVECTOR2& v) const
{
    return x != v.x || y != v.y;
}

inline D3DXVECTOR3::D3DXVECTOR3()
{
}

inline D3DXVECTOR3::D3DXVECTOR3(const FLOAT *pf)
{
    if(!pf) return;
    x = pf[0];
    y = pf[1];
    z = pf[2];
}

inline D3DXVECTOR3::D3DXVECTOR3(const D3DVECTOR& v)
{
    x = v.x;
    y = v.y;
    z = v.z;
}

inline D3DXVECTOR3::D3DXVECTOR3(FLOAT fx, FLOAT fy, FLOAT fz)
{
    x = fx;
    y = fy;
    z = fz;
}

inline D3DXVECTOR3::operator FLOAT* ()
{
    return (FLOAT*)&x;
}

inline D3DXVECTOR3::operator const FLOAT* () const
{
    return (const FLOAT*)&x;
}

inline D3DXVECTOR3& D3DXVECTOR3::operator += (const D3DXVECTOR3& v)
{
    x += v.x;
    y += v.y;
    z += v.z;
    return *this;
}

inline D3DXVECTOR3& D3DXVECTOR3::operator -= (const D3DXVECTOR3& v)
{
    x -= v.x;
    y -= v.y;
    z -= v.z;
    return *this;
}

inline D3DXVECTOR3& D3DXVECTOR3::operator *= (FLOAT f)
{
    x *= f;
    y *= f;
    z *= f;
    return *this;
}

inline D3DXVECTOR3& D3DXVECTOR3::operator /= (FLOAT f)
{
    x /= f;
    y /= f;
    z /= f;
    return *this;
}

inline D3DXVECTOR3 D3DXVECTOR3::operator + () const
{
    return *this;
}

inline D3DXVECTOR3 D3DXVECTOR3::operator - () const
{
    return D3DXVECTOR3(-x, -y, -z);
}

inline D3DXVECTOR3 D3DXVECTOR3::operator + (const D3DXVECTOR3& v) const
{
    return D3DXVECTOR3(x + v.x, y + v.y, z + v.z);
}

inline D3DXVECTOR3 D3DXVECTOR3::operator - (const D3DXVECTOR3& v) const
{
    return D3DXVECTOR3(x - v.x, y - v.y, z - v.z);
}

inline D3DXVECTOR3 D3DXVECTOR3::operator * (FLOAT f) const
{
    return D3DXVECTOR3(x * f, y * f, z * f);
}

inline D3DXVECTOR3 D3DXVECTOR3::operator / (FLOAT f) const
{
    return D3DXVECTOR3(x / f, y / f, z / f);
}

inline D3DXVECTOR3 operator * (FLOAT f, const D3DXVECTOR3& v)
{
    return D3DXVECTOR3(f * v.x, f * v.y, f * v.z);
}

inline WINBOOL D3DXVECTOR3::operator == (const D3DXVECTOR3& v) const
{
    return x == v.x && y == v.y && z == v.z;
}

inline WINBOOL D3DXVECTOR3::operator != (const D3DXVECTOR3& v) const
{
    return x != v.x || y != v.y || z != v.z;
}

inline D3DXVECTOR4::D3DXVECTOR4()
{
}

inline D3DXVECTOR4::D3DXVECTOR4(const FLOAT *pf)
{
    if(!pf) return;
    x = pf[0];
    y = pf[1];
    z = pf[2];
    w = pf[3];
}

inline D3DXVECTOR4::D3DXVECTOR4(FLOAT fx, FLOAT fy, FLOAT fz, FLOAT fw)
{
    x = fx;
    y = fy;
    z = fz;
    w = fw;
}

inline D3DXVECTOR4::operator FLOAT* ()
{
    return (FLOAT*)&x;
}

inline D3DXVECTOR4::operator const FLOAT* () const
{
    return (const FLOAT*)&x;
}

inline D3DXVECTOR4& D3DXVECTOR4::operator += (const D3DXVECTOR4& v)
{
    x += v.x;
    y += v.y;
    z += v.z;
    w += v.w;
    return *this;
}

inline D3DXVECTOR4& D3DXVECTOR4::operator -= (const D3DXVECTOR4& v)
{
    x -= v.x;
    y -= v.y;
    z -= v.z;
    w -= v.w;
    return *this;
}

inline D3DXVECTOR4& D3DXVECTOR4::operator *= (FLOAT f)
{
    x *= f;
    y *= f;
    z *= f;
    w *= f;
    return *this;
}

inline D3DXVECTOR4& D3DXVECTOR4::operator /= (FLOAT f)
{
    x /= f;
    y /= f;
    z /= f;
    w /= f;
    return *this;
}

inline D3DXVECTOR4 D3DXVECTOR4::operator + () const
{
    return *this;
}

inline D3DXVECTOR4 D3DXVECTOR4::operator - () const
{
    return D3DXVECTOR4(-x, -y, -z, -w);
}

inline D3DXVECTOR4 D3DXVECTOR4::operator + (const D3DXVECTOR4& v) const
{
    return D3DXVECTOR4(x + v.x, y + v.y, z + v.z, w + v.w);
}

inline D3DXVECTOR4 D3DXVECTOR4::operator - (const D3DXVECTOR4& v) const
{
    return D3DXVECTOR4(x - v.x, y - v.y, z - v.z, w - v.w);
}

inline D3DXVECTOR4 D3DXVECTOR4::operator * (FLOAT f) const
{
    return D3DXVECTOR4(x * f, y * f, z * f, w * f);
}

inline D3DXVECTOR4 D3DXVECTOR4::operator / (FLOAT f) const
{
    return D3DXVECTOR4(x / f, y / f, z / f, w / f);
}

inline D3DXVECTOR4 operator * (FLOAT f, const D3DXVECTOR4& v)
{
    return D3DXVECTOR4(f * v.x, f * v.y, f * v.z, f * v.w);
}

inline WINBOOL D3DXVECTOR4::operator == (const D3DXVECTOR4& v) const
{
    return x == v.x && y == v.y && z == v.z && w == v.w;
}

inline WINBOOL D3DXVECTOR4::operator != (const D3DXVECTOR4& v) const
{
    return x != v.x || y != v.y || z != v.z || w != v.w;
}

inline D3DXMATRIX::D3DXMATRIX()
{
}

inline D3DXMATRIX::D3DXMATRIX(const FLOAT *pf)
{
    if(!pf) return;
    memcpy(&_11, pf, sizeof(D3DXMATRIX));
}

inline D3DXMATRIX::D3DXMATRIX(const D3DMATRIX& mat)
{
    memcpy(&_11, &mat, sizeof(D3DXMATRIX));
}

inline D3DXMATRIX::D3DXMATRIX(FLOAT f11, FLOAT f12, FLOAT f13, FLOAT f14,
                              FLOAT f21, FLOAT f22, FLOAT f23, FLOAT f24,
                              FLOAT f31, FLOAT f32, FLOAT f33, FLOAT f34,
                              FLOAT f41, FLOAT f42, FLOAT f43, FLOAT f44)
{
    _11 = f11; _12 = f12; _13 = f13; _14 = f14;
    _21 = f21; _22 = f22; _23 = f23; _24 = f24;
    _31 = f31; _32 = f32; _33 = f33; _34 = f34;
    _41 = f41; _42 = f42; _43 = f43; _44 = f44;
}

inline FLOAT& D3DXMATRIX::operator () (UINT row, UINT col)
{
    return m[row][col];
}

inline FLOAT D3DXMATRIX::operator () (UINT row, UINT col) const
{
    return m[row][col];
}

inline D3DXMATRIX::operator FLOAT* ()
{
    return (FLOAT*)&_11;
}

inline D3DXMATRIX::operator const FLOAT* () const
{
    return (const FLOAT*)&_11;
}

inline D3DXMATRIX& D3DXMATRIX::operator *= (const D3DXMATRIX& mat)
{
    D3DXMatrixMultiply(this, this, &mat);
    return *this;
}

inline D3DXMATRIX& D3DXMATRIX::operator += (const D3DXMATRIX& mat)
{
    _11 += mat._11; _12 += mat._12; _13 += mat._13; _14 += mat._14;
    _21 += mat._21; _22 += mat._22; _23 += mat._23; _24 += mat._24;
    _31 += mat._31; _32 += mat._32; _33 += mat._33; _34 += mat._34;
    _41 += mat._41; _42 += mat._42; _43 += mat._43; _44 += mat._44;
    return *this;
}

inline D3DXMATRIX& D3DXMATRIX::operator -= (const D3DXMATRIX& mat)
{
    _11 -= mat._11; _12 -= mat._12; _13 -= mat._13; _14 -= mat._14;
    _21 -= mat._21; _22 -= mat._22; _23 -= mat._23; _24 -= mat._24;
    _31 -= mat._31; _32 -= mat._32; _33 -= mat._33; _34 -= mat._34;
    _41 -= mat._41; _42 -= mat._42; _43 -= mat._43; _44 -= mat._44;
    return *this;
}

inline D3DXMATRIX& D3DXMATRIX::operator *= (FLOAT f)
{
    _11 *= f; _12 *= f; _13 *= f; _14 *= f;
    _21 *= f; _22 *= f; _23 *= f; _24 *= f;
    _31 *= f; _32 *= f; _33 *= f; _34 *= f;
    _41 *= f; _42 *= f; _43 *= f; _44 *= f;
    return *this;
}

inline D3DXMATRIX& D3DXMATRIX::operator /= (FLOAT f)
{
    FLOAT inv = 1.0f / f;
    _11 *= inv; _12 *= inv; _13 *= inv; _14 *= inv;
    _21 *= inv; _22 *= inv; _23 *= inv; _24 *= inv;
    _31 *= inv; _32 *= inv; _33 *= inv; _34 *= inv;
    _41 *= inv; _42 *= inv; _43 *= inv; _44 *= inv;
    return *this;
}

inline D3DXMATRIX D3DXMATRIX::operator + () const
{
    return *this;
}

inline D3DXMATRIX D3DXMATRIX::operator - () const
{
    return D3DXMATRIX(-_11, -_12, -_13, -_14,
                      -_21, -_22, -_23, -_24,
                      -_31, -_32, -_33, -_34,
                      -_41, -_42, -_43, -_44);
}

inline D3DXMATRIX D3DXMATRIX::operator * (const D3DXMATRIX& mat) const
{
    D3DXMATRIX buf;
    D3DXMatrixMultiply(&buf, this, &mat);
    return buf;
}

inline D3DXMATRIX D3DXMATRIX::operator + (const D3DXMATRIX& mat) const
{
    return D3DXMATRIX(_11 + mat._11, _12 + mat._12, _13 + mat._13, _14 + mat._14,
                      _21 + mat._21, _22 + mat._22, _23 + mat._23, _24 + mat._24,
                      _31 + mat._31, _32 + mat._32, _33 + mat._33, _34 + mat._34,
                      _41 + mat._41, _42 + mat._42, _43 + mat._43, _44 + mat._44);
}

inline D3DXMATRIX D3DXMATRIX::operator - (const D3DXMATRIX& mat) const
{
    return D3DXMATRIX(_11 - mat._11, _12 - mat._12, _13 - mat._13, _14 - mat._14,
                      _21 - mat._21, _22 - mat._22, _23 - mat._23, _24 - mat._24,
                      _31 - mat._31, _32 - mat._32, _33 - mat._33, _34 - mat._34,
                      _41 - mat._41, _42 - mat._42, _43 - mat._43, _44 - mat._44);
}

inline D3DXMATRIX D3DXMATRIX::operator * (FLOAT f) const
{
    return D3DXMATRIX(_11 * f, _12 * f, _13 * f, _14 * f,
                      _21 * f, _22 * f, _23 * f, _24 * f,
                      _31 * f, _32 * f, _33 * f, _34 * f,
                      _41 * f, _42 * f, _43 * f, _44 * f);
}

inline D3DXMATRIX D3DXMATRIX::operator / (FLOAT f) const
{
    FLOAT inv = 1.0f / f;
    return D3DXMATRIX(_11 * inv, _12 * inv, _13 * inv, _14 * inv,
                      _21 * inv, _22 * inv, _23 * inv, _24 * inv,
                      _31 * inv, _32 * inv, _33 * inv, _34 * inv,
                      _41 * inv, _42 * inv, _43 * inv, _44 * inv);
}

inline D3DXMATRIX operator * (FLOAT f, const D3DXMATRIX& mat)
{
    return D3DXMATRIX(f * mat._11, f * mat._12, f * mat._13, f * mat._14,
                      f * mat._21, f * mat._22, f * mat._23, f * mat._24,
                      f * mat._31, f * mat._32, f * mat._33, f * mat._34,
                      f * mat._41, f * mat._42, f * mat._43, f * mat._44);
}

inline WINBOOL D3DXMATRIX::operator == (const D3DXMATRIX& mat) const
{
    return (memcmp(this, &mat, sizeof(D3DXMATRIX)) == 0);
}

inline WINBOOL D3DXMATRIX::operator != (const D3DXMATRIX& mat) const
{
    return (memcmp(this, &mat, sizeof(D3DXMATRIX)) != 0);
}

inline D3DXQUATERNION::D3DXQUATERNION()
{
}

inline D3DXQUATERNION::D3DXQUATERNION(const FLOAT *pf)
{
    if(!pf) return;
    x = pf[0];
    y = pf[1];
    z = pf[2];
    w = pf[3];
}

inline D3DXQUATERNION::D3DXQUATERNION(FLOAT fx, FLOAT fy, FLOAT fz, FLOAT fw)
{
    x = fx;
    y = fy;
    z = fz;
    w = fw;
}

inline D3DXQUATERNION::operator FLOAT* ()
{
    return (FLOAT*)&x;
}

inline D3DXQUATERNION::operator const FLOAT* () const
{
    return (const FLOAT*)&x;
}

inline D3DXQUATERNION& D3DXQUATERNION::operator += (const D3DXQUATERNION& quat)
{
    x += quat.x;
    y += quat.y;
    z += quat.z;
    w += quat.w;
    return *this;
}

inline D3DXQUATERNION& D3DXQUATERNION::operator -= (const D3DXQUATERNION& quat)
{
    x -= quat.x;
    y -= quat.y;
    z -= quat.z;
    w -= quat.w;
    return *this;
}

inline D3DXQUATERNION& D3DXQUATERNION::operator *= (const D3DXQUATERNION& quat)
{
    D3DXQuaternionMultiply(this, this, &quat);
    return *this;
}

inline D3DXQUATERNION& D3DXQUATERNION::operator *= (FLOAT f)
{
    x *= f;
    y *= f;
    z *= f;
    w *= f;
    return *this;
}

inline D3DXQUATERNION& D3DXQUATERNION::operator /= (FLOAT f)
{
    FLOAT inv = 1.0f / f;
    x *= inv;
    y *= inv;
    z *= inv;
    w *= inv;
    return *this;
}

inline D3DXQUATERNION D3DXQUATERNION::operator + () const
{
    return *this;
}

inline D3DXQUATERNION D3DXQUATERNION::operator - () const
{
    return D3DXQUATERNION(-x, -y, -z, -w);
}

inline D3DXQUATERNION D3DXQUATERNION::operator + (const D3DXQUATERNION& quat) const
{
    return D3DXQUATERNION(x + quat.x, y + quat.y, z + quat.z, w + quat.w);
}

inline D3DXQUATERNION D3DXQUATERNION::operator - (const D3DXQUATERNION& quat) const
{
    return D3DXQUATERNION(x - quat.x, y - quat.y, z - quat.z, w - quat.w);
}

inline D3DXQUATERNION D3DXQUATERNION::operator * (const D3DXQUATERNION& quat) const
{
    D3DXQUATERNION buf;
    D3DXQuaternionMultiply(&buf, this, &quat);
    return buf;
}

inline D3DXQUATERNION D3DXQUATERNION::operator * (FLOAT f) const
{
    return D3DXQUATERNION(x * f, y * f, z * f, w * f);
}

inline D3DXQUATERNION D3DXQUATERNION::operator / (FLOAT f) const
{
    FLOAT inv = 1.0f / f;
    return D3DXQUATERNION(x * inv, y * inv, z * inv, w * inv);
}

inline D3DXQUATERNION operator * (FLOAT f, const D3DXQUATERNION& quat)
{
    return D3DXQUATERNION(f * quat.x, f * quat.y, f * quat.z, f * quat.w);
}

inline WINBOOL D3DXQUATERNION::operator == (const D3DXQUATERNION& quat) const
{
    return x == quat.x && y == quat.y && z == quat.z && w == quat.w;
}

inline WINBOOL D3DXQUATERNION::operator != (const D3DXQUATERNION& quat) const
{
    return x != quat.x || y != quat.y || z != quat.z || w != quat.w;
}

inline D3DXPLANE::D3DXPLANE()
{
}

inline D3DXPLANE::D3DXPLANE(const FLOAT *pf)
{
    if(!pf) return;
    a = pf[0];
    b = pf[1];
    c = pf[2];
    d = pf[3];
}

inline D3DXPLANE::D3DXPLANE(FLOAT fa, FLOAT fb, FLOAT fc, FLOAT fd)
{
    a = fa;
    b = fb;
    c = fc;
    d = fd;
}

inline D3DXPLANE::operator FLOAT* ()
{
    return (FLOAT*)&a;
}

inline D3DXPLANE::operator const FLOAT* () const
{
    return (const FLOAT*)&a;
}

inline D3DXPLANE D3DXPLANE::operator + () const
{
    return *this;
}

inline D3DXPLANE D3DXPLANE::operator - () const
{
    return D3DXPLANE(-a, -b, -c, -d);
}

inline WINBOOL D3DXPLANE::operator == (const D3DXPLANE& pl) const
{
    return a == pl.a && b == pl.b && c == pl.c && d == pl.d;
}

inline WINBOOL D3DXPLANE::operator != (const D3DXPLANE& pl) const
{
    return a != pl.a || b != pl.b || c != pl.c || d != pl.d;
}

inline D3DXCOLOR::D3DXCOLOR()
{
}

inline D3DXCOLOR::D3DXCOLOR(DWORD col)
{
    const FLOAT f = 1.0f / 255.0f;
    r = f * (FLOAT)(unsigned char)(col >> 16);
    g = f * (FLOAT)(unsigned char)(col >>  8);
    b = f * (FLOAT)(unsigned char)col;
    a = f * (FLOAT)(unsigned char)(col >> 24);
}

inline D3DXCOLOR::D3DXCOLOR(const FLOAT *pf)
{
    if(!pf) return;
    r = pf[0];
    g = pf[1];
    b = pf[2];
    a = pf[3];
}

inline D3DXCOLOR::D3DXCOLOR(const D3DCOLORVALUE& col)
{
    r = col.r;
    g = col.g;
    b = col.b;
    a = col.a;
}

inline D3DXCOLOR::D3DXCOLOR(FLOAT fr, FLOAT fg, FLOAT fb, FLOAT fa)
{
    r = fr;
    g = fg;
    b = fb;
    a = fa;
}

inline D3DXCOLOR::operator DWORD () const
{
    DWORD _r = r >= 1.0f ? 0xff : r <= 0.0f ? 0x00 : (DWORD)(r * 255.0f + 0.5f);
    DWORD _g = g >= 1.0f ? 0xff : g <= 0.0f ? 0x00 : (DWORD)(g * 255.0f + 0.5f);
    DWORD _b = b >= 1.0f ? 0xff : b <= 0.0f ? 0x00 : (DWORD)(b * 255.0f + 0.5f);
    DWORD _a = a >= 1.0f ? 0xff : a <= 0.0f ? 0x00 : (DWORD)(a * 255.0f + 0.5f);

    return (_a << 24) | (_r << 16) | (_g << 8) | _b;
}

inline D3DXCOLOR::operator FLOAT * ()
{
    return (FLOAT*)&r;
}

inline D3DXCOLOR::operator const FLOAT * () const
{
    return (const FLOAT*)&r;
}

inline D3DXCOLOR::operator D3DCOLORVALUE * ()
{
    return (D3DCOLORVALUE*)&r;
}

inline D3DXCOLOR::operator const D3DCOLORVALUE * () const
{
    return (const D3DCOLORVALUE*)&r;
}

inline D3DXCOLOR::operator D3DCOLORVALUE& ()
{
    return *((D3DCOLORVALUE*)&r);
}

inline D3DXCOLOR::operator const D3DCOLORVALUE& () const
{
    return *((const D3DCOLORVALUE*)&r);
}

inline D3DXCOLOR& D3DXCOLOR::operator += (const D3DXCOLOR& col)
{
    r += col.r;
    g += col.g;
    b += col.b;
    a += col.a;
    return *this;
}

inline D3DXCOLOR& D3DXCOLOR::operator -= (const D3DXCOLOR& col)
{
    r -= col.r;
    g -= col.g;
    b -= col.b;
    a -= col.a;
    return *this;
}

inline D3DXCOLOR& D3DXCOLOR::operator *= (FLOAT f)
{
    r *= f;
    g *= f;
    b *= f;
    a *= f;
    return *this;
}

inline D3DXCOLOR& D3DXCOLOR::operator /= (FLOAT f)
{
    FLOAT inv = 1.0f / f;
    r *= inv;
    g *= inv;
    b *= inv;
    a *= inv;
    return *this;
}

inline D3DXCOLOR D3DXCOLOR::operator + () const
{
    return *this;
}

inline D3DXCOLOR D3DXCOLOR::operator - () const
{
    return D3DXCOLOR(-r, -g, -b, -a);
}

inline D3DXCOLOR D3DXCOLOR::operator + (const D3DXCOLOR& col) const
{
    return D3DXCOLOR(r + col.r, g + col.g, b + col.b, a + col.a);
}

inline D3DXCOLOR D3DXCOLOR::operator - (const D3DXCOLOR& col) const
{
    return D3DXCOLOR(r - col.r, g - col.g, b - col.b, a - col.a);
}

inline D3DXCOLOR D3DXCOLOR::operator * (FLOAT f) const
{
    return D3DXCOLOR(r * f, g * f, b * f, a * f);
}

inline D3DXCOLOR D3DXCOLOR::operator / (FLOAT f) const
{
    FLOAT inv = 1.0f / f;
    return D3DXCOLOR(r * inv, g * inv, b * inv, a * inv);
}

inline D3DXCOLOR operator * (FLOAT f, const D3DXCOLOR& col)
{
    return D3DXCOLOR(f * col.r, f * col.g, f * col.b, f * col.a);
}

inline WINBOOL D3DXCOLOR::operator == (const D3DXCOLOR& col) const
{
    return r == col.r && g == col.g && b == col.b && a == col.a;
}

inline WINBOOL D3DXCOLOR::operator != (const D3DXCOLOR& col) const
{
    return r != col.r || g != col.g || b != col.b || a != col.a;
}

inline D3DXFLOAT16::D3DXFLOAT16()
{
}

inline D3DXFLOAT16::D3DXFLOAT16(FLOAT f)
{
    D3DXFloat32To16Array(this, &f, 1);
}

inline D3DXFLOAT16::D3DXFLOAT16(const D3DXFLOAT16 &f)
{
    value = f.value;
}

inline D3DXFLOAT16::operator FLOAT ()
{
    FLOAT f;
    D3DXFloat16To32Array(&f, this, 1);
    return f;
}

inline WINBOOL D3DXFLOAT16::operator == (const D3DXFLOAT16 &f) const
{
    return value == f.value;
}

inline WINBOOL D3DXFLOAT16::operator != (const D3DXFLOAT16 &f) const
{
    return value != f.value;
}

#endif /* __cplusplus */

/*_______________D3DXCOLOR_____________________*/

static inline D3DXCOLOR* D3DXColorAdd(D3DXCOLOR *pout, const D3DXCOLOR *pc1, const D3DXCOLOR *pc2)
{
    if ( !pout || !pc1 || !pc2 ) return NULL;
    pout->r = (pc1->r) + (pc2->r);
    pout->g = (pc1->g) + (pc2->g);
    pout->b = (pc1->b) + (pc2->b);
    pout->a = (pc1->a) + (pc2->a);
    return pout;
}

static inline D3DXCOLOR* D3DXColorLerp(D3DXCOLOR *pout, const D3DXCOLOR *pc1, const D3DXCOLOR *pc2, FLOAT s)
{
    if ( !pout || !pc1 || !pc2 ) return NULL;
    pout->r = (1-s) * (pc1->r) + s *(pc2->r);
    pout->g = (1-s) * (pc1->g) + s *(pc2->g);
    pout->b = (1-s) * (pc1->b) + s *(pc2->b);
    pout->a = (1-s) * (pc1->a) + s *(pc2->a);
    return pout;
}

static inline D3DXCOLOR* D3DXColorModulate(D3DXCOLOR *pout, const D3DXCOLOR *pc1, const D3DXCOLOR *pc2)
{
    if ( !pout || !pc1 || !pc2 ) return NULL;
    pout->r = (pc1->r) * (pc2->r);
    pout->g = (pc1->g) * (pc2->g);
    pout->b = (pc1->b) * (pc2->b);
    pout->a = (pc1->a) * (pc2->a);
    return pout;
}

static inline D3DXCOLOR* D3DXColorNegative(D3DXCOLOR *pout, const D3DXCOLOR *pc)
{
    if ( !pout || !pc ) return NULL;
    pout->r = 1.0f - pc->r;
    pout->g = 1.0f - pc->g;
    pout->b = 1.0f - pc->b;
    pout->a = pc->a;
    return pout;
}

static inline D3DXCOLOR* D3DXColorScale(D3DXCOLOR *pout, const D3DXCOLOR *pc, FLOAT s)
{
    if ( !pout || !pc ) return NULL;
    pout->r = s* (pc->r);
    pout->g = s* (pc->g);
    pout->b = s* (pc->b);
    pout->a = s* (pc->a);
    return pout;
}

static inline D3DXCOLOR* D3DXColorSubtract(D3DXCOLOR *pout, const D3DXCOLOR *pc1, const D3DXCOLOR *pc2)
{
    if ( !pout || !pc1 || !pc2 ) return NULL;
    pout->r = (pc1->r) - (pc2->r);
    pout->g = (pc1->g) - (pc2->g);
    pout->b = (pc1->b) - (pc2->b);
    pout->a = (pc1->a) - (pc2->a);
    return pout;
}

/*_______________D3DXVECTOR2________________________*/

static inline D3DXVECTOR2* D3DXVec2Add(D3DXVECTOR2 *pout, const D3DXVECTOR2 *pv1, const D3DXVECTOR2 *pv2)
{
    if ( !pout || !pv1 || !pv2) return NULL;
    pout->x = pv1->x + pv2->x;
    pout->y = pv1->y + pv2->y;
    return pout;
}

static inline FLOAT D3DXVec2CCW(const D3DXVECTOR2 *pv1, const D3DXVECTOR2 *pv2)
{
    if ( !pv1 || !pv2) return 0.0f;
    return ( (pv1->x) * (pv2->y) - (pv1->y) * (pv2->x) );
}

static inline FLOAT D3DXVec2Dot(const D3DXVECTOR2 *pv1, const D3DXVECTOR2 *pv2)
{
    if ( !pv1 || !pv2) return 0.0f;
    return ( (pv1->x * pv2->x + pv1->y * pv2->y) );
}

static inline FLOAT D3DXVec2Length(const D3DXVECTOR2 *pv)
{
    if (!pv) return 0.0f;
    return sqrtf( pv->x * pv->x + pv->y * pv->y );
}

static inline FLOAT D3DXVec2LengthSq(const D3DXVECTOR2 *pv)
{
    if (!pv) return 0.0f;
    return( (pv->x) * (pv->x) + (pv->y) * (pv->y) );
}

static inline D3DXVECTOR2* D3DXVec2Lerp(D3DXVECTOR2 *pout, const D3DXVECTOR2 *pv1, const D3DXVECTOR2 *pv2, FLOAT s)
{
    if ( !pout || !pv1 || !pv2) return NULL;
    pout->x = (1-s) * (pv1->x) + s * (pv2->x);
    pout->y = (1-s) * (pv1->y) + s * (pv2->y);
    return pout;
}

static inline D3DXVECTOR2* D3DXVec2Maximize(D3DXVECTOR2 *pout, const D3DXVECTOR2 *pv1, const D3DXVECTOR2 *pv2)
{
    if ( !pout || !pv1 || !pv2) return NULL;
    pout->x = pv1->x > pv2->x ? pv1->x : pv2->x;
    pout->y = pv1->y > pv2->y ? pv1->y : pv2->y;
    return pout;
}

static inline D3DXVECTOR2* D3DXVec2Minimize(D3DXVECTOR2 *pout, const D3DXVECTOR2 *pv1, const D3DXVECTOR2 *pv2)
{
    if ( !pout || !pv1 || !pv2) return NULL;
    pout->x = pv1->x < pv2->x ? pv1->x : pv2->x;
    pout->y = pv1->y < pv2->y ? pv1->y : pv2->y;
    return pout;
}

static inline D3DXVECTOR2* D3DXVec2Scale(D3DXVECTOR2 *pout, const D3DXVECTOR2 *pv, FLOAT s)
{
    if ( !pout || !pv) return NULL;
    pout->x = s * (pv->x);
    pout->y = s * (pv->y);
    return pout;
}

static inline D3DXVECTOR2* D3DXVec2Subtract(D3DXVECTOR2 *pout, const D3DXVECTOR2 *pv1, const D3DXVECTOR2 *pv2)
{
    if ( !pout || !pv1 || !pv2) return NULL;
    pout->x = pv1->x - pv2->x;
    pout->y = pv1->y - pv2->y;
    return pout;
}

/*__________________D3DXVECTOR3_______________________*/

static inline D3DXVECTOR3* D3DXVec3Add(D3DXVECTOR3 *pout, const D3DXVECTOR3 *pv1, const D3DXVECTOR3 *pv2)
{
    if ( !pout || !pv1 || !pv2) return NULL;
    pout->x = pv1->x + pv2->x;
    pout->y = pv1->y + pv2->y;
    pout->z = pv1->z + pv2->z;
    return pout;
}

static inline D3DXVECTOR3* D3DXVec3Cross(D3DXVECTOR3 *pout, const D3DXVECTOR3 *pv1, const D3DXVECTOR3 *pv2)
{
    D3DXVECTOR3 temp;

    if ( !pout || !pv1 || !pv2) return NULL;
    temp.x = (pv1->y) * (pv2->z) - (pv1->z) * (pv2->y);
    temp.y = (pv1->z) * (pv2->x) - (pv1->x) * (pv2->z);
    temp.z = (pv1->x) * (pv2->y) - (pv1->y) * (pv2->x);
    *pout = temp;
    return pout;
}

static inline FLOAT D3DXVec3Dot(const D3DXVECTOR3 *pv1, const D3DXVECTOR3 *pv2)
{
    if ( !pv1 || !pv2 ) return 0.0f;
    return (pv1->x) * (pv2->x) + (pv1->y) * (pv2->y) + (pv1->z) * (pv2->z);
}

static inline FLOAT D3DXVec3Length(const D3DXVECTOR3 *pv)
{
    if (!pv) return 0.0f;
    return sqrtf( pv->x * pv->x + pv->y * pv->y + pv->z * pv->z );
}

static inline FLOAT D3DXVec3LengthSq(const D3DXVECTOR3 *pv)
{
    if (!pv) return 0.0f;
    return (pv->x) * (pv->x) + (pv->y) * (pv->y) + (pv->z) * (pv->z);
}

static inline D3DXVECTOR3* D3DXVec3Lerp(D3DXVECTOR3 *pout, const D3DXVECTOR3 *pv1, const D3DXVECTOR3 *pv2, FLOAT s)
{
    if ( !pout || !pv1 || !pv2) return NULL;
    pout->x = (1-s) * (pv1->x) + s * (pv2->x);
    pout->y = (1-s) * (pv1->y) + s * (pv2->y);
    pout->z = (1-s) * (pv1->z) + s * (pv2->z);
    return pout;
}

static inline D3DXVECTOR3* D3DXVec3Maximize(D3DXVECTOR3 *pout, const D3DXVECTOR3 *pv1, const D3DXVECTOR3 *pv2)
{
    if ( !pout || !pv1 || !pv2) return NULL;
    pout->x = pv1->x > pv2->x ? pv1->x : pv2->x;
    pout->y = pv1->y > pv2->y ? pv1->y : pv2->y;
    pout->z = pv1->z > pv2->z ? pv1->z : pv2->z;
    return pout;
}

static inline D3DXVECTOR3* D3DXVec3Minimize(D3DXVECTOR3 *pout, const D3DXVECTOR3 *pv1, const D3DXVECTOR3 *pv2)
{
    if ( !pout || !pv1 || !pv2) return NULL;
    pout->x = pv1->x < pv2->x ? pv1->x : pv2->x;
    pout->y = pv1->y < pv2->y ? pv1->y : pv2->y;
    pout->z = pv1->z < pv2->z ? pv1->z : pv2->z;
    return pout;
}

static inline D3DXVECTOR3* D3DXVec3Scale(D3DXVECTOR3 *pout, const D3DXVECTOR3 *pv, FLOAT s)
{
    if ( !pout || !pv) return NULL;
    pout->x = s * (pv->x);
    pout->y = s * (pv->y);
    pout->z = s * (pv->z);
    return pout;
}

static inline D3DXVECTOR3* D3DXVec3Subtract(D3DXVECTOR3 *pout, const D3DXVECTOR3 *pv1, const D3DXVECTOR3 *pv2)
{
    if ( !pout || !pv1 || !pv2) return NULL;
    pout->x = pv1->x - pv2->x;
    pout->y = pv1->y - pv2->y;
    pout->z = pv1->z - pv2->z;
    return pout;
}
/*__________________D3DXVECTOR4_______________________*/

static inline D3DXVECTOR4* D3DXVec4Add(D3DXVECTOR4 *pout, const D3DXVECTOR4 *pv1, const D3DXVECTOR4 *pv2)
{
    if ( !pout || !pv1 || !pv2) return NULL;
    pout->x = pv1->x + pv2->x;
    pout->y = pv1->y + pv2->y;
    pout->z = pv1->z + pv2->z;
    pout->w = pv1->w + pv2->w;
    return pout;
}

static inline FLOAT D3DXVec4Dot(const D3DXVECTOR4 *pv1, const D3DXVECTOR4 *pv2)
{
    if (!pv1 || !pv2 ) return 0.0f;
    return (pv1->x) * (pv2->x) + (pv1->y) * (pv2->y) + (pv1->z) * (pv2->z) + (pv1->w) * (pv2->w);
}

static inline FLOAT D3DXVec4Length(const D3DXVECTOR4 *pv)
{
    if (!pv) return 0.0f;
    return sqrtf( pv->x * pv->x + pv->y * pv->y + pv->z * pv->z + pv->w * pv->w );
}

static inline FLOAT D3DXVec4LengthSq(const D3DXVECTOR4 *pv)
{
    if (!pv) return 0.0f;
    return (pv->x) * (pv->x) + (pv->y) * (pv->y) + (pv->z) * (pv->z) + (pv->w) * (pv->w);
}

static inline D3DXVECTOR4* D3DXVec4Lerp(D3DXVECTOR4 *pout, const D3DXVECTOR4 *pv1, const D3DXVECTOR4 *pv2, FLOAT s)
{
    if ( !pout || !pv1 || !pv2) return NULL;
    pout->x = (1-s) * (pv1->x) + s * (pv2->x);
    pout->y = (1-s) * (pv1->y) + s * (pv2->y);
    pout->z = (1-s) * (pv1->z) + s * (pv2->z);
    pout->w = (1-s) * (pv1->w) + s * (pv2->w);
    return pout;
}


static inline D3DXVECTOR4* D3DXVec4Maximize(D3DXVECTOR4 *pout, const D3DXVECTOR4 *pv1, const D3DXVECTOR4 *pv2)
{
    if ( !pout || !pv1 || !pv2) return NULL;
    pout->x = pv1->x > pv2->x ? pv1->x : pv2->x;
    pout->y = pv1->y > pv2->y ? pv1->y : pv2->y;
    pout->z = pv1->z > pv2->z ? pv1->z : pv2->z;
    pout->w = pv1->w > pv2->w ? pv1->w : pv2->w;
    return pout;
}

static inline D3DXVECTOR4* D3DXVec4Minimize(D3DXVECTOR4 *pout, const D3DXVECTOR4 *pv1, const D3DXVECTOR4 *pv2)
{
    if ( !pout || !pv1 || !pv2) return NULL;
    pout->x = pv1->x < pv2->x ? pv1->x : pv2->x;
    pout->y = pv1->y < pv2->y ? pv1->y : pv2->y;
    pout->z = pv1->z < pv2->z ? pv1->z : pv2->z;
    pout->w = pv1->w < pv2->w ? pv1->w : pv2->w;
    return pout;
}

static inline D3DXVECTOR4* D3DXVec4Scale(D3DXVECTOR4 *pout, const D3DXVECTOR4 *pv, FLOAT s)
{
    if ( !pout || !pv) return NULL;
    pout->x = s * (pv->x);
    pout->y = s * (pv->y);
    pout->z = s * (pv->z);
    pout->w = s * (pv->w);
    return pout;
}

static inline D3DXVECTOR4* D3DXVec4Subtract(D3DXVECTOR4 *pout, const D3DXVECTOR4 *pv1, const D3DXVECTOR4 *pv2)
{
    if ( !pout || !pv1 || !pv2) return NULL;
    pout->x = pv1->x - pv2->x;
    pout->y = pv1->y - pv2->y;
    pout->z = pv1->z - pv2->z;
    pout->w = pv1->w - pv2->w;
    return pout;
}

/*__________________D3DXMatrix____________________*/
#ifdef NONAMELESSUNION
# define D3DX_U(x)  (x).u
#else
# define D3DX_U(x)  (x)
#endif

static inline D3DXMATRIX* D3DXMatrixIdentity(D3DXMATRIX *pout)
{
    if ( !pout ) return NULL;
    D3DX_U(*pout).m[0][1] = 0.0f;
    D3DX_U(*pout).m[0][2] = 0.0f;
    D3DX_U(*pout).m[0][3] = 0.0f;
    D3DX_U(*pout).m[1][0] = 0.0f;
    D3DX_U(*pout).m[1][2] = 0.0f;
    D3DX_U(*pout).m[1][3] = 0.0f;
    D3DX_U(*pout).m[2][0] = 0.0f;
    D3DX_U(*pout).m[2][1] = 0.0f;
    D3DX_U(*pout).m[2][3] = 0.0f;
    D3DX_U(*pout).m[3][0] = 0.0f;
    D3DX_U(*pout).m[3][1] = 0.0f;
    D3DX_U(*pout).m[3][2] = 0.0f;
    D3DX_U(*pout).m[0][0] = 1.0f;
    D3DX_U(*pout).m[1][1] = 1.0f;
    D3DX_U(*pout).m[2][2] = 1.0f;
    D3DX_U(*pout).m[3][3] = 1.0f;
    return pout;
}

static inline WINBOOL D3DXMatrixIsIdentity(D3DXMATRIX *pm)
{
    int i,j;
    D3DXMATRIX testmatrix;

    if ( !pm ) return FALSE;
    D3DXMatrixIdentity(&testmatrix);
    for (i=0; i<4; i++)
    {
     for (j=0; j<4; j++)
     {
      if ( D3DX_U(*pm).m[i][j] != D3DX_U(testmatrix).m[i][j] ) return FALSE;
     }
    }
    return TRUE;
}
#undef D3DX_U

/*__________________D3DXPLANE____________________*/

static inline FLOAT D3DXPlaneDot(const D3DXPLANE *pp, const D3DXVECTOR4 *pv)
{
    if ( !pp || !pv ) return 0.0f;
    return ( (pp->a) * (pv->x) + (pp->b) * (pv->y) + (pp->c) * (pv->z) + (pp->d) * (pv->w) );
}

static inline FLOAT D3DXPlaneDotCoord(const D3DXPLANE *pp, const D3DXVECTOR4 *pv)
{
    if ( !pp || !pv ) return 0.0f;
    return ( (pp->a) * (pv->x) + (pp->b) * (pv->y) + (pp->c) * (pv->z) + (pp->d) );
}

static inline FLOAT D3DXPlaneDotNormal(const D3DXPLANE *pp, const D3DXVECTOR4 *pv)
{
    if ( !pp || !pv ) return 0.0f;
    return ( (pp->a) * (pv->x) + (pp->b) * (pv->y) + (pp->c) * (pv->z) );
}

/*__________________D3DXQUATERNION____________________*/

static inline D3DXQUATERNION* D3DXQuaternionConjugate(D3DXQUATERNION *pout, const D3DXQUATERNION *pq)
{
    if ( !pout || !pq) return NULL;
    pout->x = -pq->x;
    pout->y = -pq->y;
    pout->z = -pq->z;
    pout->w = pq->w;
    return pout;
}

static inline FLOAT D3DXQuaternionDot(const D3DXQUATERNION *pq1, const D3DXQUATERNION *pq2)
{
    if ( !pq1 || !pq2 ) return 0.0f;
    return (pq1->x) * (pq2->x) + (pq1->y) * (pq2->y) + (pq1->z) * (pq2->z) + (pq1->w) * (pq2->w);
}

static inline D3DXQUATERNION* D3DXQuaternionIdentity(D3DXQUATERNION *pout)
{
    if ( !pout) return NULL;
    pout->x = 0.0f;
    pout->y = 0.0f;
    pout->z = 0.0f;
    pout->w = 1.0f;
    return pout;
}

static inline WINBOOL D3DXQuaternionIsIdentity(D3DXQUATERNION *pq)
{
    if ( !pq) return FALSE;
    return ( (pq->x == 0.0f) && (pq->y == 0.0f) && (pq->z == 0.0f) && (pq->w == 1.0f) );
}

static inline FLOAT D3DXQuaternionLength(const D3DXQUATERNION *pq)
{
    if (!pq) return 0.0f;
    return sqrtf( pq->x * pq->x + pq->y * pq->y + pq->z * pq->z + pq->w * pq->w );
}

static inline FLOAT D3DXQuaternionLengthSq(const D3DXQUATERNION *pq)
{
    if (!pq) return 0.0f;
    return (pq->x) * (pq->x) + (pq->y) * (pq->y) + (pq->z) * (pq->z) + (pq->w) * (pq->w);
}

#endif
