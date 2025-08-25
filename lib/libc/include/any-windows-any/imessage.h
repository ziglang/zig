/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _IMESSAGE_H_
#define _IMESSAGE_H_

#include "mapidefs.h"

#ifdef __cplusplus
extern "C" {
#endif

  typedef struct _MSGSESS *LPMSGSESS;
  typedef void (WINAPI MSGCALLRELEASE)(ULONG ulCallerData,LPMESSAGE lpMessage);

  STDAPI_(SCODE) OpenIMsgSession(LPMALLOC lpMalloc,ULONG ulFlags,LPMSGSESS *lppMsgSess);
  STDAPI_(void) CloseIMsgSession(LPMSGSESS lpMsgSess);
  STDAPI_(SCODE) OpenIMsgOnIStg(LPMSGSESS lpMsgSess,LPALLOCATEBUFFER lpAllocateBuffer,LPALLOCATEMORE lpAllocateMore,LPFREEBUFFER lpFreeBuffer,LPMALLOC lpMalloc,LPVOID lpMapiSup,LPSTORAGE lpStg,MSGCALLRELEASE *lpfMsgCallRelease,ULONG ulCallerData,ULONG ulFlags,LPMESSAGE *lppMsg);

#define IMSG_NO_ISTG_COMMIT ((ULONG) 0x00000001)

#define PROPATTR_MANDATORY ((ULONG) 0x00000001)
#define PROPATTR_READABLE ((ULONG) 0x00000002)
#define PROPATTR_WRITEABLE ((ULONG) 0x00000004)

#define PROPATTR_NOT_PRESENT ((ULONG) 0x00000008)

  typedef struct _SPropAttrArray {
    ULONG cValues;
    ULONG aPropAttr[MAPI_DIM];
  } SPropAttrArray,*LPSPropAttrArray;

#define CbNewSPropAttrArray(_cattr) (offsetof(SPropAttrArray,aPropAttr) + (_cattr)*sizeof(ULONG))
#define CbSPropAttrArray(_lparray) (offsetof(SPropAttrArray,aPropAttr) + (UINT)((_lparray)->cValues)*sizeof(ULONG))
#define SizedSPropAttrArray(_cattr,_name) struct _SPropAttrArray_ ## _name { ULONG cValues; ULONG aPropAttr[_cattr]; } _name

  STDAPI GetAttribIMsgOnIStg(LPVOID lpObject,LPSPropTagArray lpPropTagArray,LPSPropAttrArray *lppPropAttrArray);
  STDAPI SetAttribIMsgOnIStg(LPVOID lpObject,LPSPropTagArray lpPropTags,LPSPropAttrArray lpPropAttrs,LPSPropProblemArray *lppPropProblems);
  STDAPI_(SCODE) MapStorageSCode(SCODE StgSCode);

#ifdef __cplusplus
}
#endif
#endif
