/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _BEM_H_
#define _BEM_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#ifndef __WIDL__
  typedef struct _CONTRACT_DESCRIPTION CONTRACT_DESCRIPTION;
  typedef struct _BEM_REFERENCE BEM_REFERENCE;
  typedef void (CALLBACK *BEM_FREE_INTERFACE_CALLBACK) (void *interfaceInstance);

  HRESULT WINAPI BemCreateReference (REFGUID iid, void *interfaceInstance, BEM_FREE_INTERFACE_CALLBACK freeCallback, BEM_REFERENCE **reference);
  HRESULT WINAPI BemCreateContractFrom (LPCWSTR dllPath, REFGUID extensionId, const CONTRACT_DESCRIPTION *contractDescription, void *hostContract, void **contract);
  HRESULT WINAPI BemCopyReference (BEM_REFERENCE *reference, BEM_REFERENCE **copiedReference);
  void WINAPI BemFreeReference (BEM_REFERENCE *reference);
  void WINAPI BemFreeContract (void *contract);
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
