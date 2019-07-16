/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __NDRTYPES_H__
#define __NDRTYPES_H__

#include <limits.h>
#ifdef __cplusplus
extern "C" {
#endif

#define UNION_OFFSET16_MIN -32512

#define PTR_WIRE_SIZE 4

#define NT64_PTR_SIZE 8
#define NT32_PTR_SIZE 4
#define SIZEOF_PTR(f64) ((f64) ? NT64_PTR_SIZE : NT32_PTR_SIZE)
#define SIZEOF_MEM_PTR() ((pCommand->Is64BitEnv()) ? NT64_PTR_SIZE : NT32_PTR_SIZE)

#define SIZEOF_INT3264() ((pCommand->Is64BitEnv()) ? 8 : 4)

#define NDR_MAJOR_VERSION __MSABI_LONG(5U)
#define NDR_MINOR_VERSION __MSABI_LONG(4U)
#define NDR_VERSION ((NDR_MAJOR_VERSION << 16) | NDR_MINOR_VERSION)

#define NDR_VERSION_1_1 ((__MSABI_LONG(1U) << 16) | 1)
#define NDR_VERSION_2_0 ((__MSABI_LONG(2U) << 16) | 0)
#define NDR_VERSION_5_0 ((__MSABI_LONG(5U) << 16) | 0)
#define NDR_VERSION_5_2 ((__MSABI_LONG(5U) << 16) | 2)
#define NDR_VERSION_5_3 ((__MSABI_LONG(5U) << 16) | 3)
#define NDR_VERSION_5_4 ((__MSABI_LONG(5U) << 16) | 4)

#define LOAD_TLB_AS_64BIT 0
#define LOAD_TLB_AS_32BIT 0

  typedef enum {
    FC_ZERO,FC_BYTE,FC_CHAR,FC_SMALL,FC_USMALL,FC_WCHAR,FC_SHORT,FC_USHORT,FC_LONG,FC_ULONG,FC_FLOAT,FC_HYPER,FC_DOUBLE,FC_ENUM16,FC_ENUM32,
    FC_IGNORE,FC_ERROR_STATUS_T,FC_RP,FC_UP,FC_OP,FC_FP,FC_STRUCT,FC_PSTRUCT,FC_CSTRUCT,FC_CPSTRUCT,FC_CVSTRUCT,FC_BOGUS_STRUCT,FC_CARRAY,
    FC_CVARRAY,FC_SMFARRAY,FC_LGFARRAY,FC_SMVARRAY,FC_LGVARRAY,FC_BOGUS_ARRAY,FC_C_CSTRING,FC_C_BSTRING,FC_C_SSTRING,FC_C_WSTRING,FC_CSTRING,
    FC_BSTRING,FC_SSTRING,FC_WSTRING,FC_ENCAPSULATED_UNION,FC_NON_ENCAPSULATED_UNION,FC_BYTE_COUNT_POINTER,FC_TRANSMIT_AS,FC_REPRESENT_AS,FC_IP,
    FC_BIND_CONTEXT,FC_BIND_GENERIC,FC_BIND_PRIMITIVE,FC_AUTO_HANDLE,FC_CALLBACK_HANDLE,FC_UNUSED1,FC_POINTER,FC_ALIGNM2,FC_ALIGNM4,FC_ALIGNM8,
    FC_UNUSED2,FC_UNUSED3,FC_UNUSED4,FC_STRUCTPAD1,FC_STRUCTPAD2,FC_STRUCTPAD3,FC_STRUCTPAD4,FC_STRUCTPAD5,FC_STRUCTPAD6,FC_STRUCTPAD7,
    FC_STRING_SIZED,FC_UNUSED5,FC_NO_REPEAT,FC_FIXED_REPEAT,FC_VARIABLE_REPEAT,FC_FIXED_OFFSET,FC_VARIABLE_OFFSET,FC_PP,FC_EMBEDDED_COMPLEX,
    FC_IN_PARAM,FC_IN_PARAM_BASETYPE,FC_IN_PARAM_NO_FREE_INST,FC_IN_OUT_PARAM,FC_OUT_PARAM,FC_RETURN_PARAM,FC_RETURN_PARAM_BASETYPE,FC_DEREFERENCE,
    FC_DIV_2,FC_MULT_2,FC_ADD_1,FC_SUB_1,FC_CALLBACK,FC_CONSTANT_IID,FC_END,FC_PAD,FC_SPLIT_DEREFERENCE = 0x74,FC_SPLIT_DIV_2,FC_SPLIT_MULT_2,
    FC_SPLIT_ADD_1,FC_SPLIT_SUB_1,FC_SPLIT_CALLBACK,FC_HARD_STRUCT = 0xb1,FC_TRANSMIT_AS_PTR,FC_REPRESENT_AS_PTR,FC_USER_MARSHAL,FC_PIPE,
    FC_BLKHOLE,FC_RANGE,FC_INT3264,FC_UINT3264,FC_END_OF_UNIVERSE
  } FORMAT_CHARACTER;

  typedef struct {
    unsigned char FullPtrUsed : 1;
    unsigned char RpcSsAllocUsed : 1;
    unsigned char ObjectProc : 1;
    unsigned char HasRpcFlags : 1;
    unsigned char IgnoreObjectException : 1;
    unsigned char HasCommOrFault : 1;
    unsigned char UseNewInitRoutines : 1;
    unsigned char Unused : 1;
  } INTERPRETER_FLAGS,*PINTERPRETER_FLAGS;

  typedef struct {
    unsigned short MustSize : 1;
    unsigned short MustFree : 1;
    unsigned short IsPipe : 1;
    unsigned short IsIn : 1;
    unsigned short IsOut : 1;
    unsigned short IsReturn : 1;
    unsigned short IsBasetype : 1;
    unsigned short IsByValue : 1;
    unsigned short IsSimpleRef : 1;
    unsigned short IsDontCallFreeInst : 1;
    unsigned short SaveForAsyncFinish : 1;
    unsigned short Unused : 2;
    unsigned short ServerAllocSize : 3;
  } PARAM_ATTRIBUTES,*PPARAM_ATTRIBUTES;

  typedef struct {
    unsigned char ServerMustSize : 1;
    unsigned char ClientMustSize : 1;
    unsigned char HasReturn : 1;
    unsigned char HasPipes : 1;
    unsigned char Unused : 1;
    unsigned char HasAsyncUuid : 1;
    unsigned char HasExtensions : 1;
    unsigned char HasAsyncHandle : 1;
  } INTERPRETER_OPT_FLAGS,*PINTERPRETER_OPT_FLAGS;

  typedef struct _NDR_DCOM_OI2_PROC_HEADER {
    unsigned char HandleType;
    INTERPRETER_FLAGS OldOiFlags;
    unsigned short RpcFlagsLow;
    unsigned short RpcFlagsHi;
    unsigned short ProcNum;
    unsigned short StackSize;

    unsigned short ClientBufferSize;
    unsigned short ServerBufferSize;
    INTERPRETER_OPT_FLAGS Oi2Flags;
    unsigned char NumberParams;
  } NDR_DCOM_OI2_PROC_HEADER,*PNDR_DCOM_OI2_PROC_HEADER;

  typedef struct {
    unsigned char HasNewCorrDesc : 1;
    unsigned char ClientCorrCheck : 1;
    unsigned char ServerCorrCheck : 1;
    unsigned char HasNotify : 1;
    unsigned char HasNotify2 : 1;
    unsigned char Unused : 3;
  } INTERPRETER_OPT_FLAGS2,*PINTERPRETER_OPT_FLAGS2;

  typedef struct {
    unsigned char Size;
    INTERPRETER_OPT_FLAGS2 Flags2;
    unsigned short ClientCorrHint;
    unsigned short ServerCorrHint;
    unsigned short NotifyIndex;
  } NDR_PROC_HEADER_EXTS,*PNDR_PROC_HEADER_EXTS;

  typedef struct {
    unsigned char Size;
    INTERPRETER_OPT_FLAGS2 Flags2;
    unsigned short ClientCorrHint;
    unsigned short ServerCorrHint;
    unsigned short NotifyIndex;
    unsigned short FloatArgMask;
  } NDR_PROC_HEADER_EXTS64,*PNDR_PROC_HEADER_EXTS64;

  typedef struct {
    unsigned char CannotBeNull : 1;
    unsigned char Serialize : 1;
    unsigned char NoSerialize : 1;
    unsigned char IsStrict : 1;
    unsigned char IsReturn : 1;
    unsigned char IsOut : 1;
    unsigned char IsIn : 1;
    unsigned char IsViaPtr : 1;
  } NDR_CONTEXT_HANDLE_FLAGS,*PNDR_CONTEXT_HANDLE_FLAGS;

  typedef struct _MIDL_TYPE_PICKLING_FLAGS {
    unsigned __LONG32 Oicf : 1;
    unsigned __LONG32 HasNewCorrDesc : 1;
    unsigned __LONG32 Unused : 30;
  } MIDL_TYPE_PICKLING_FLAGS,*PMIDL_TYPE_PICKLING_FLAGS;

#define MAX_INTERPRETER_OUT_SIZE 128
#define MAX_INTERPRETER_PARAM_OUT_SIZE 7*8

#define INTERPRETER_THUNK_PARAM_SIZE_THRESHOLD (sizeof(__LONG32)*32)

#define INTERPRETER_PROC_STACK_FRAME_SIZE_THRESHOLD ((64*1024) - 1)

#define FC_NORMAL_CONFORMANCE (unsigned char) 0x00
#define FC_POINTER_CONFORMANCE (unsigned char) 0x10
#define FC_TOP_LEVEL_CONFORMANCE (unsigned char) 0x20
#define FC_CONSTANT_CONFORMANCE (unsigned char) 0x40
#define FC_TOP_LEVEL_MULTID_CONFORMANCE (unsigned char) 0x80

#define FC_NORMAL_VARIANCE FC_NORMAL_CONFORMANCE
#define FC_POINTER_VARIANCE FC_POINTER_CONFORMANCE
#define FC_TOP_LEVEL_VARIANCE FC_TOP_LEVEL_CONFORMANCE
#define FC_CONSTANT_VARIANCE FC_CONSTANT_CONFORMANCE
#define FC_TOP_LEVEL_MULTID_VARIANCE FC_TOP_LEVEL_MULTID_CONFORMANCE

#define FC_NORMAL_SWITCH_IS FC_NORMAL_CONFORMANCE
#define FC_POINTER_SWITCH_IS FC_POINTER_CONFORMANCE
#define FC_TOP_LEVEL_SWITCH_IS FC_TOP_LEVEL_CONFORMANCE
#define FC_CONSTANT_SWITCH_IS FC_CONSTANT_CONFORMANCE

  typedef struct _NDR_CORRELATION_FLAGS
  {
    unsigned char Early : 1;
    unsigned char Split : 1;
    unsigned char IsIidIs : 1;
    unsigned char DontCheck: 1;
    unsigned char Unused : 4;
  } NDR_CORRELATION_FLAGS;

#define FC_EARLY_CORRELATION (unsigned char) 0x01
#define FC_SPLIT_CORRELATION (unsigned char) 0x02
#define FC_IID_CORRELATION (unsigned char) 0x04
#define FC_NOCHECK_CORRELATION (unsigned char) 0x08

#define FC_ALLOCATE_ALL_NODES 0x01
#define FC_DONT_FREE 0x02
#define FC_ALLOCED_ON_STACK 0x04
#define FC_SIMPLE_POINTER 0x08
#define FC_POINTER_DEREF 0x10

#define LOW_NIBBLE(Byte) (((unsigned char)Byte) & 0x0f)
#define HIGH_NIBBLE(Byte) (((unsigned char)Byte) >> 4)

#define INVALID_RUNDOWN_ROUTINE_INDEX 255

#define OPERATION_MAYBE 0x0001
#define OPERATION_BROADCAST 0x0002
#define OPERATION_IDEMPOTENT 0x0004
#define OPERATION_INPUT_SYNC 0x0008
#define OPERATION_ASYNC 0x0010
#define OPERATION_MESSAGE 0x0020

#define PRESENTED_TYPE_NO_FLAG_SET 0x00
#define PRESENTED_TYPE_IS_ARRAY 0x10
#define PRESENTED_TYPE_ALIGN_4 0x20
#define PRESENTED_TYPE_ALIGN_8 0x40

#define USER_MARSHAL_POINTER 0xc0

#define USER_MARSHAL_UNIQUE 0x80
#define USER_MARSHAL_REF 0x40
#define USER_MARSHAL_IID 0x20

#define HANDLE_PARAM_IS_VIA_PTR 0x80
#define HANDLE_PARAM_IS_IN 0x40
#define HANDLE_PARAM_IS_OUT 0x20
#define HANDLE_PARAM_IS_RETURN 0x10

#define NDR_STRICT_CONTEXT_HANDLE 0x08
#define NDR_CONTEXT_HANDLE_NOSERIALIZE 0x04
#define NDR_CONTEXT_HANDLE_SERIALIZE 0x02
#define NDR_CONTEXT_HANDLE_CANNOT_BE_NULL 0x01

#define Oi_FULL_PTR_USED 0x01
#define Oi_RPCSS_ALLOC_USED 0x02
#define Oi_OBJECT_PROC 0x04
#define Oi_HAS_RPCFLAGS 0x08

#define Oi_IGNORE_OBJECT_EXCEPTION_HANDLING 0x10

#define ENCODE_IS_USED 0x10
#define DECODE_IS_USED 0x20
#define PICKLING_HAS_COMM_OR_FAULT 0x40

#define Oi_HAS_COMM_OR_FAULT 0x20
#define Oi_OBJ_USE_V2_INTERPRETER 0x20

#define Oi_USE_NEW_INIT_ROUTINES 0x40
#define Oi_UNUSED 0x80

#define Oif_HAS_ASYNC_UUID 0x20

#define UNION_CONSECUTIVE_ARMS 1
#define UNION_SMALL_ARMS 2
#define UNION_LARGE_ARMS 3

#define FC_BIG_PIPE 0x80
#define FC_OBJECT_PIPE 0x40
#define FC_PIPE_HAS_RANGE 0x20

#define BLKHOLE_BASETYPE 0x01
#define BLKHOLE_FUNCTION 0x02
#define BLKHOLE_XURTYPE 0x04

#define MAGIC_UNION_SHORT ((unsigned short) 0x8000)

#define NDR_DEFAULT_CORR_CACHE_SIZE 400

#ifdef __cplusplus
}
#endif
#endif
