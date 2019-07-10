/*
 * unknown.h
 *
 * Contributors:
 *   Created by Magnus Olsen
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
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

DEFINE_GUID(IID_IUnknown, 0x00000000, 0x0000, 0x0000, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46);
#if defined(__cplusplus) && _MSC_VER >= 1100
struct __declspec(uuid("00000000-0000-0000-C000-000000000046")) IUnknown;
#endif

#undef INTERFACE
#define INTERFACE IUnknown
DECLARE_INTERFACE(IUnknown)
{
    STDMETHOD(QueryInterface)
    (   THIS_
		REFIID,
		PVOID*
    )   PURE;

    STDMETHOD_(ULONG,AddRef)
    (   THIS
    )   PURE;

    STDMETHOD_(ULONG,Release)
    (   THIS
    )   PURE;
};
#undef INTERFACE

typedef IUnknown *PUNKNOWN;
typedef
HRESULT
(NTAPI *PFNCREATEINSTANCE)
(
  PUNKNOWN * Unknown,
  REFCLSID   ClassId,
  PUNKNOWN   OuterUnknown,
  POOL_TYPE  PoolType
);

#endif /* _UNKNOWN_H_ */

