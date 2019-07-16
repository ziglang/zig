/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _WINDEF_
#define _WINDEF_

#include <minwindef.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef WINVER
#define WINVER 0x0502
#endif

/* Make sure winnt.h is included.  */
#ifndef NT_INCLUDED
#include <winnt.h>
#endif

#ifndef WIN_INTERNAL
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
DECLARE_HANDLE (HWND);
DECLARE_HANDLE (HHOOK);
#endif
#ifdef WINABLE
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
DECLARE_HANDLE (HEVENT);
#endif
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
#ifdef STRICT
  typedef void *HGDIOBJ;
#else
  DECLARE_HANDLE (HGDIOBJ);
#endif

DECLARE_HANDLE(HACCEL);
DECLARE_HANDLE(HBITMAP);
DECLARE_HANDLE(HBRUSH);
DECLARE_HANDLE(HCOLORSPACE);
DECLARE_HANDLE(HDC);
DECLARE_HANDLE(HGLRC);
DECLARE_HANDLE(HDESK);
DECLARE_HANDLE(HENHMETAFILE);
DECLARE_HANDLE(HFONT);
DECLARE_HANDLE(HICON);
DECLARE_HANDLE(HMENU);
DECLARE_HANDLE(HPALETTE);
DECLARE_HANDLE(HPEN);
DECLARE_HANDLE(HMONITOR);
#define HMONITOR_DECLARED 1
DECLARE_HANDLE(HWINEVENTHOOK);

typedef HICON HCURSOR;
typedef DWORD COLORREF;
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
DECLARE_HANDLE(HUMPD);

typedef DWORD *LPCOLORREF;

#define HFILE_ERROR ((HFILE)-1)
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
typedef struct tagRECT {
  LONG left;
  LONG top;
  LONG right;
  LONG bottom;
} RECT,*PRECT,*NPRECT,*LPRECT;

typedef const RECT *LPCRECT;

typedef struct _RECTL {
  LONG left;
  LONG top;
  LONG right;
  LONG bottom;
} RECTL,*PRECTL,*LPRECTL;

typedef const RECTL *LPCRECTL;

typedef struct tagPOINT {
  LONG x;
  LONG y;
} POINT,*PPOINT,*NPPOINT,*LPPOINT;

typedef struct _POINTL {
  LONG x;
  LONG y;
} POINTL,*PPOINTL;

typedef struct tagSIZE {
  LONG cx;
  LONG cy;
} SIZE,*PSIZE,*LPSIZE;

typedef SIZE SIZEL;
typedef SIZE *PSIZEL,*LPSIZEL;

typedef struct tagPOINTS {
  SHORT x;
  SHORT y;
} POINTS,*PPOINTS,*LPPOINTS;
#endif

#define DM_UPDATE 1
#define DM_COPY 2
#define DM_PROMPT 4
#define DM_MODIFY 8

#define DM_IN_BUFFER DM_MODIFY
#define DM_IN_PROMPT DM_PROMPT
#define DM_OUT_BUFFER DM_COPY
#define DM_OUT_DEFAULT DM_UPDATE

#define DC_FIELDS 1
#define DC_PAPERS 2
#define DC_PAPERSIZE 3
#define DC_MINEXTENT 4
#define DC_MAXEXTENT 5
#define DC_BINS 6
#define DC_DUPLEX 7
#define DC_SIZE 8
#define DC_EXTRA 9
#define DC_VERSION 10
#define DC_DRIVER 11
#define DC_BINNAMES 12
#define DC_ENUMRESOLUTIONS 13
#define DC_FILEDEPENDENCIES 14
#define DC_TRUETYPE 15
#define DC_PAPERNAMES 16
#define DC_ORIENTATION 17
#define DC_COPIES 18

#ifdef __cplusplus
}
#endif

#endif /* _WINDEF_ */

