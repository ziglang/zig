/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_TABFLICKS
#define _INC_TABFLICKS
#if (_WIN32_WINNT >= 0x0600)
#ifdef __cplusplus
extern "C" {
#endif

typedef enum FLICKACTION_COMMANDCODE {
  FLICKACTION_COMMANDCODE_NULL          = 0,
  FLICKACTION_COMMANDCODE_SCROLL        = 1,
  FLICKACTION_COMMANDCODE_APPCOMMAND    = 2,
  FLICKACTION_COMMANDCODE_CUSTOMKEY     = 3,
  FLICKACTION_COMMANDCODE_KEYMODIFIER   = 4 
} FLICKACTION_COMMANDCODE;

typedef enum FLICKDIRECTION {
  FLICKDIRECTION_RIGHT       = 0,
  FLICKDIRECTION_UPRIGHT     = 1,
  FLICKDIRECTION_UP          = 2,
  FLICKDIRECTION_UPLEFT      = 3,
  FLICKDIRECTION_LEFT        = 4,
  FLICKDIRECTION_DOWN        = 6,
  FLICKDIRECTION_DOWNRIGHT   = 7,
  FLICKDIRECTION_INVALID     = 8 
} FLICKDIRECTION;

typedef enum FLICKMODE {
  FLICKMODE_OFF   = 0,
  FLICKMODE_ON    = 1 
} FLICKMODE;

typedef enum KEYMODIFIER {
  KEYMODIFIER_CONTROL   = 1,
  KEYMODIFIER_MENU      = 2,
  KEYMODIFIER_SHIFT     = 4,
  KEYMODIFIER_WIN       = 8,
  KEYMODIFIER_ALTGR     = 16,
  KEYMODIFIER_EXT       = 32 
} KEYMODIFIER;

typedef enum SCROLLDIRECTION {
  SCROLLDIRECTION_UP     = 0,
  SCROLLDIRECTION_DOWN   = 1 
} SCROLLDIRECTION;

typedef struct FLICK_DATA {
  FLICKACTION_COMMANDCODE iFlickActionCommandCode  :5;
  FLICKDIRECTION          iFlickDirection  :3;
  WINBOOL                 fControlModifier  :1;
  WINBOOL                 fMenuModifier  :1;
  WINBOOL                 fAltGRModifier  :1;
  WINBOOL                 fWinModifier  :1;
  WINBOOL                 fShiftModifier  :1;
  INT                     iReserved  :2;
  WINBOOL                 fOnInkingSurface  :1;
  INT                     iActionArgument  :16;
} FLICK_DATA;

typedef struct FLICK_POINT {
  INT x  :16;
  INT y  :16;
} FLICK_POINT;

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /* _INC_TABFLICKS */
