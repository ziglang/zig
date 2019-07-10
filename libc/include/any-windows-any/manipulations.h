/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __INC_MANIPULATIONS__
#define __INC_MANIPULATIONS__

typedef enum _MANIPULATION_PROCESSOR_MANIPULATIONS {
  MANIPULATION_NONE          = 0x00000000,
  MANIPULATION_TRANSLATE_X   = 0x00000001,
  MANIPULATION_TRANSLATE_Y   = 0x00000002,
  MANIPULATION_SCALE         = 0x00000004,
  MANIPULATION_ROTATE        = 0x00000008,
  MANIPULATION_ALL           = 0x0000000F 
} MANIPULATION_PROCESSOR_MANIPULATIONS;

#endif /*__INC_MANIPULATIONS__*/
