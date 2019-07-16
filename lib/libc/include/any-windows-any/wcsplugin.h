/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_WCSPLUGIN
#define _INC_WCSPLUGIN
#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _BlackInformation {
  WINBOOL  bBlackOnly;
  FLOAT blackWeight;
} BlackInformation;

typedef struct _JabColorF {
  FLOAT J;
  FLOAT a;
  FLOAT b;
} JabColorF;

typedef struct _PrimaryJabColors {
  JabColorF red;
  JabColorF yellow;
  JabColorF green;
  JabColorF cyan;
  JabColorF blue;
  JabColorF magenta;
  JabColorF black;
  JabColorF white;
} PrimaryJabColors;

typedef struct _GamutShellTriangle {
  UINT aVertexIndex[3];
} GamutShellTriangle;

typedef struct _GamutShell {
  FLOAT                                    JMin;
  FLOAT                                    JMax;
  UINT                                     cVertices;
  UINT                                     cTriangles;
  JabColorF                                *pVertices;
  GamutShellTriangle                       *pTriangles;
} GamutShell;

typedef struct _GamutBoundaryDescription {
  PrimaryJabColors                      primaries;
  UINT                                 cNeutralSamples
  JabColorF                            *pNeutralSamples;
  GamutShell                           *pReferenceShell;
  GamutShell                           *pPlausibleShell;
  GamutShell                           *pPossibleShell;
} GamutBoundaryDescription;

typedef struct _PrimaryJabColors {
  JabColorF red;
  JabColorF yellow;
  JabColorF green;
  JabColorF cyan;
  JabColorF blue;
  JabColorF magenta;
  JabColorF black;
  JabColorF white;
} PrimaryJabColors;

typedef struct _XYZColorF {
  FLOAT X;
  FLOAT Y;
  FLOAT Z;
} XYZColorF;

typedef struct _PrimaryXYZColors {
  XYZColorF red;
  XYZColorF yellow;
  XYZColorF green;
  XYZColorF cyan;
  XYZColorF blue;
  XYZColorF magenta;
  XYZColorF black;
  XYZColorF white;
} PrimaryXYZColors;

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_WCSPLUGIN*/
