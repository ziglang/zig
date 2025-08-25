/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef MAPIHOOK_H
#define MAPIHOOK_H

#include <mapidefs.h>
#include <mapicode.h>
#include <mapiguid.h>
#include <mapitags.h>

#ifndef BEGIN_INTERFACE
#define BEGIN_INTERFACE
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define HOOK_DELETE ((ULONG) 0x00000001)
#define HOOK_CANCEL ((ULONG) 0x00000002)

#define MAPI_ISPOOLERHOOK_METHODS(IPURE) MAPIMETHOD(InboundMsgHook) (THIS_ LPMESSAGE lpMessage,LPMAPIFOLDER lpFolder,LPMDB lpMDB,ULONG *lpulFlags,ULONG *lpcbEntryID,LPBYTE *lppEntryID) IPURE; MAPIMETHOD(OutboundMsgHook) (THIS_ LPMESSAGE lpMessage,LPMAPIFOLDER lpFolder,LPMDB lpMDB,ULONG *lpulFlags,ULONG *lpcbEntryID,LPBYTE *lppEntryID) IPURE;
#undef INTERFACE
#define INTERFACE ISpoolerHook
  DECLARE_MAPI_INTERFACE_(ISpoolerHook,IUnknown) {
    BEGIN_INTERFACE
      MAPI_IUNKNOWN_METHODS(PURE)
      MAPI_ISPOOLERHOOK_METHODS(PURE)
  };

  DECLARE_MAPI_INTERFACE_PTR(ISpoolerHook,LPSPOOLERHOOK);

#define HOOK_INBOUND ((ULONG) 0x00000200)
#define HOOK_OUTBOUND ((ULONG) 0x00000400)

  typedef HRESULT (__cdecl HPPROVIDERINIT)(LPMAPISESSION lpSession,HINSTANCE hInstance,LPALLOCATEBUFFER lpAllocateBuffer,LPALLOCATEMORE lpAllocateMore,LPFREEBUFFER lpFreeBuffer,LPMAPIUID lpSectionUID,ULONG ulFlags,LPSPOOLERHOOK *lppSpoolerHook);

  HPPROVIDERINIT HPProviderInit;

#ifdef __cplusplus
}
#endif
#endif
