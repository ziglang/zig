/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error this stub requires an updated version of <rpcndr.h>
#endif

#ifndef __certbase_h__
#define __certbase_h__

#include "wtypes.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef struct _CERTTRANSBLOB {
    unsigned __LONG32 cb;
    BYTE *pb;
  } CERTTRANSBLOB;

  typedef struct _CERTVIEWRESTRICTION {
    DWORD ColumnIndex;
    LONG SeekOperator;
    LONG SortOrder;
    BYTE *pbValue;
    DWORD cbValue;
  } CERTVIEWRESTRICTION;

  extern RPC_IF_HANDLE __MIDL_itf_certbase_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_certbase_0000_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
