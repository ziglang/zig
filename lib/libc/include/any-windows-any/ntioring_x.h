/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _NTIORINGX_H_
#define _NTIORINGX_H_

#ifdef __cplusplus
extern "C" {
#endif

#if NTDDI_VERSION >= NTDDI_WIN10_CO

typedef enum IORING_VERSION {
  IORING_VERSION_INVALID = 0,
  IORING_VERSION_1
} IORING_VERSION;

typedef enum IORING_FEATURE_FLAGS {
  IORING_FEATURE_FLAGS_NONE = 0,
  IORING_FEATURE_UM_EMULATION = 0x00000001,
  IORING_FEATURE_SET_COMPLETION_EVENT = 0x00000002
} IORING_FEATURE_FLAGS;
DEFINE_ENUM_FLAG_OPERATORS(IORING_FEATURE_FLAGS)

typedef enum IORING_OP_CODE {
  IORING_OP_NOP,
  IORING_OP_READ,
  IORING_OP_REGISTER_FILES,
  IORING_OP_REGISTER_BUFFERS,
  IORING_OP_CANCEL
} IORING_OP_CODE;

typedef struct IORING_BUFFER_INFO {
  void* Address;
  UINT32 Length;
} IORING_BUFFER_INFO;

typedef struct IORING_REGISTERED_BUFFER {
  UINT32 BufferIndex;
  UINT32 Offset;
} IORING_REGISTERED_BUFFER;

#define IORING_SUBMIT_WAIT_ALL MAXUINT32

#endif /* NTDDI_WIN10_CO */

#ifdef __cplusplus
}
#endif

#endif /* _NTIORINGX_H_ */
