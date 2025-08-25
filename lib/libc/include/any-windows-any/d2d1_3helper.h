/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _D2D1_3HELPER_H_
#define _D2D1_3HELPER_H_

#if NTDDI_VERSION >= NTDDI_WINTHRESHOLD

#ifndef _D2D1_3_H_
#include <d2d1_3.h>
#endif

#ifndef D2D_USE_C_DEFINITIONS

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)

namespace D2D1 {
  COM_DECLSPEC_NOTHROW D2D1FORCEINLINE D2D1_GRADIENT_MESH_PATCH GradientMeshPatch(
    D2D1_POINT_2F point00,
    D2D1_POINT_2F point01,
    D2D1_POINT_2F point02,
    D2D1_POINT_2F point03,
    D2D1_POINT_2F point10,
    D2D1_POINT_2F point11,
    D2D1_POINT_2F point12,
    D2D1_POINT_2F point13,
    D2D1_POINT_2F point20,
    D2D1_POINT_2F point21,
    D2D1_POINT_2F point22,
    D2D1_POINT_2F point23,
    D2D1_POINT_2F point30,
    D2D1_POINT_2F point31,
    D2D1_POINT_2F point32,
    D2D1_POINT_2F point33,
    D2D1_COLOR_F color00,
    D2D1_COLOR_F color03,
    D2D1_COLOR_F color30,
    D2D1_COLOR_F color33,
    D2D1_PATCH_EDGE_MODE top_edge_mode,
    D2D1_PATCH_EDGE_MODE left_edge_mode,
    D2D1_PATCH_EDGE_MODE bottom_edge_mode,
    D2D1_PATCH_EDGE_MODE right_edge_mode
    )
  {
    D2D1_GRADIENT_MESH_PATCH new_patch;
    new_patch.point00 = point00;
    new_patch.point01 = point01;
    new_patch.point02 = point02;
    new_patch.point03 = point03;
    new_patch.point10 = point10;
    new_patch.point11 = point11;
    new_patch.point12 = point12;
    new_patch.point13 = point13;
    new_patch.point20 = point20;
    new_patch.point21 = point21;
    new_patch.point22 = point22;
    new_patch.point23 = point23;
    new_patch.point30 = point30;
    new_patch.point31 = point31;
    new_patch.point32 = point32;
    new_patch.point33 = point33;

    new_patch.color00 = color00;
    new_patch.color03 = color03;
    new_patch.color30 = color30;
    new_patch.color33 = color33;

    new_patch.topEdgeMode = top_edge_mode;
    new_patch.leftEdgeMode = left_edge_mode;
    new_patch.bottomEdgeMode = bottom_edge_mode;
    new_patch.rightEdgeMode = right_edge_mode;

    return new_patch;
  }

  COM_DECLSPEC_NOTHROW D2D1FORCEINLINE D2D1_GRADIENT_MESH_PATCH GradientMeshPatchFromCoonsPatch(
    D2D1_POINT_2F point0,
    D2D1_POINT_2F point1,
    D2D1_POINT_2F point2,
    D2D1_POINT_2F point3,
    D2D1_POINT_2F point4,
    D2D1_POINT_2F point5,
    D2D1_POINT_2F point6,
    D2D1_POINT_2F point7,
    D2D1_POINT_2F point8,
    D2D1_POINT_2F point9,
    D2D1_POINT_2F point10,
    D2D1_POINT_2F point11,
    D2D1_COLOR_F color0,
    D2D1_COLOR_F color1,
    D2D1_COLOR_F color2,
    D2D1_COLOR_F color3,
    D2D1_PATCH_EDGE_MODE top_edge_mode,
    D2D1_PATCH_EDGE_MODE left_edge_mode,
    D2D1_PATCH_EDGE_MODE bottom_edge_mode,
    D2D1_PATCH_EDGE_MODE right_edge_mode
    )
  {
    D2D1_GRADIENT_MESH_PATCH new_patch;
    new_patch.point00 = point0;
    new_patch.point01 = point1;
    new_patch.point02 = point2;
    new_patch.point03 = point3;
    new_patch.point13 = point4;
    new_patch.point23 = point5;
    new_patch.point33 = point6;
    new_patch.point32 = point7;
    new_patch.point31 = point8;
    new_patch.point30 = point9;
    new_patch.point20 = point10;
    new_patch.point10 = point11;

    D2D1GetGradientMeshInteriorPointsFromCoonsPatch(
      &point0,
      &point1,
      &point2,
      &point3,
      &point4,
      &point5,
      &point6,
      &point7,
      &point8,
      &point9,
      &point10,
      &point11,
      &new_patch.point11,
      &new_patch.point12,
      &new_patch.point21,
      &new_patch.point22
      );

    new_patch.color00 = color0;
    new_patch.color03 = color1;
    new_patch.color33 = color2;
    new_patch.color30 = color3;
    new_patch.topEdgeMode = top_edge_mode;
    new_patch.leftEdgeMode = left_edge_mode;
    new_patch.bottomEdgeMode = bottom_edge_mode;
    new_patch.rightEdgeMode = right_edge_mode;

    return new_patch;
  }

  COM_DECLSPEC_NOTHROW D2D1FORCEINLINE D2D1_INK_POINT InkPoint(const D2D1_POINT_2F &point, FLOAT radius) {
    D2D1_INK_POINT ink_point;

    ink_point.x = point.x;
    ink_point.y = point.y;
    ink_point.radius = radius;

    return ink_point;
  }

  COM_DECLSPEC_NOTHROW D2D1FORCEINLINE D2D1_INK_BEZIER_SEGMENT InkBezierSegment(const D2D1_INK_POINT &point1, const D2D1_INK_POINT &point2, const D2D1_INK_POINT &point3) {
    D2D1_INK_BEZIER_SEGMENT ink_bezier_segment;

    ink_bezier_segment.point1 = point1;
    ink_bezier_segment.point2 = point2;
    ink_bezier_segment.point3 = point3;

    return ink_bezier_segment;
  }

  COM_DECLSPEC_NOTHROW D2D1FORCEINLINE D2D1_INK_STYLE_PROPERTIES InkStyleProperties(D2D1_INK_NIB_SHAPE nib_shape, const D2D1_MATRIX_3X2_F &nib_transform) {
    D2D1_INK_STYLE_PROPERTIES ink_style_properties;

    ink_style_properties.nibShape = nib_shape;
    ink_style_properties.nibTransform = nib_transform;

    return ink_style_properties;
  }

  COM_DECLSPEC_NOTHROW D2D1FORCEINLINE D2D1_RECT_U InfiniteRectU(void) {
    D2D1_RECT_U rect = { 0, 0, UINT_MAX, UINT_MAX };

    return rect;
  }

  COM_DECLSPEC_NOTHROW D2D1FORCEINLINE D2D1_SIMPLE_COLOR_PROFILE SimpleColorProfile(
    const D2D1_POINT_2F &red_primary,
    const D2D1_POINT_2F &green_primary,
    const D2D1_POINT_2F &blue_primary,
    const D2D1_GAMMA1 gamma,
    const D2D1_POINT_2F &white_point_xz
    )
  {
    D2D1_SIMPLE_COLOR_PROFILE simple_color_profile;

    simple_color_profile.redPrimary = red_primary;
    simple_color_profile.greenPrimary = green_primary;
    simple_color_profile.bluePrimary = blue_primary;
    simple_color_profile.gamma = gamma;
    simple_color_profile.whitePointXZ = white_point_xz;

    return simple_color_profile;
  }
} /* namespace D2D1 */

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP) */

#endif /* D2D_USE_C_DEFINITIONS */

#endif /* NTDDI_VERSION >= NTDDI_WINTHRESHOLD */

#endif /* _D2D1_HELPER_H_ */
