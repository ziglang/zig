/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_WINSATCOMINTERFACEI
#define _INC_WINSATCOMINTERFACEI

typedef enum _WINSAT_ASSESSMENT_STATE {
  WINSAT_ASSESSMENT_STATE_MIN                        = 0,
  WINSAT_ASSESSMENT_STATE_UNKNOWN                    = 0,
  WINSAT_ASSESSMENT_STATE_VALID                      = 1,
  WINSAT_ASSESSMENT_STATE_INCOHERENT_WITH_HARDWARE   = 2,
  WINSAT_ASSESSMENT_STATE_NOT_AVAILABLE              = 3,
  WINSAT_ASSESSMENT_STATE_INVALID                    = 4,
  WINSAT_ASSESSMENT_STATE_MAX                        = 4 
} WINSAT_ASSESSMENT_STATE;

typedef enum _WINSAT_ASSESSMENT_TYPE {
  WINSAT_ASSESSMENT_MEMORY     = 0,
  WINSAT_ASSESSMENT_CPU        = 1,
  WINSAT_ASSESSMENT_DISK       = 2,
  WINSAT_ASSESSMENT_D3D        = 3,
  WINSAT_ASSESSMENT_GRAPHICS   = 4 
} WINSAT_ASSESSMENT_TYPE;

typedef enum _WINSAT_BITMAP_SIZE {
  WINSAT_BITMAP_SIZE_SMALL    = 0,
  WINSAT_BITMAP_SIZE_NORMAL   = 1 
} WINSAT_BITMAP_SIZE;

#endif /*_INC_WINSATCOMINTERFACEI*/
