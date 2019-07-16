/*
    ReactOS Kernel-Mode COM
    by Andrew Greenwood

    This file is in the public domain.
*/

#ifndef _UNKNOWN_H_
#define _UNKNOWN_H_

#ifdef __cplusplus
extern "C" {
#include <wdm.h>
}
#else
#include <wdm.h>
#endif

#include <windef.h>
#define COM_NO_WINDOWS_H
#include <basetyps.h>

#ifdef PUT_GUIDS_HERE
#include <initguid.h>
#endif


/* ===============================================================
    IUnknown
*/

#ifndef __IUnknown_INTERFACE_DEFINED__
#define __IUnknown_INTERFACE_DEFINED__
DEFINE_GUID(
    IID_IUnknown,
    0x00000000, 0x0000, 0x0000, 0x00, 0x00, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x46);

#undef INTERFACE
#define INTERFACE IUnknown

DECLARE_INTERFACE(IUnknown)
{
    STDMETHOD_(NTSTATUS, QueryInterface)( THIS_
        IN  REFIID,
        OUT PVOID*)
    PURE;

    STDMETHOD_(ULONG, AddRef)( THIS )
    PURE;

    STDMETHOD_(ULONG, Release)( THIS )
    PURE;
};
#endif

#undef INTERFACE

typedef IUnknown *PUNKNOWN;


/* ===============================================================
    IUnknown definition
    Boilerplate code macro for use in subclassed interfaces
*/

#define DEFINE_ABSTRACT_UNKNOWN() \
    STDMETHOD_(NTSTATUS, QueryInterface)( THIS_ \
        REFIID InterfaceId, \
        PVOID* Interface) \
    PURE; \
\
    STDMETHOD_(ULONG, AddRef)(THIS) \
    PURE; \
\
    STDMETHOD_(ULONG, Release)(THIS) \
    PURE;


/* ===============================================================
    Constructor callback definition
*/

typedef HRESULT (NTAPI *PFNCREATEINSTANCE)(
    OUT PUNKNOWN* Unknown,
    IN  REFCLSID ClassId,
    IN  PUNKNOWN OuterUnknown,
    IN  POOL_TYPE PoolType);

#endif /* _UNKNOWN_H_ */

