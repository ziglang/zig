/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 *
 * dmksctrl.h
 *
 * Contributors:
 *   Created by Johannes Anderwald
 *   Reworked by Kai Tietz
 *
 */

#ifndef _DMKSCTRL_
#define _DMKSCTRL_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include <pshpack8.h>
#include <objbase.h>

#ifndef _NTRTL_
#ifndef DEFINE_GUIDEX
#define DEFINE_GUIDEX(name) EXTERN_C const CDECL GUID name
#endif

#ifndef STATICGUIDOF
#define STATICGUIDOF(guid) STATIC_##guid
#endif
#endif

#ifndef STATIC_IID_IKsControl
#define STATIC_IID_IKsControl 0x28f54685, 0x06fd, 0x11d2, 0xb2, 0x7a, 0x00, 0xa0, 0xc9, 0x22, 0x31, 0x96
#endif

#ifndef _KS_
#define _KS_

typedef struct {
  __C89_NAMELESS union {
    __C89_NAMELESS struct {
      GUID Set;
      ULONG Id;
      ULONG Flags;
    };
    LONGLONG Alignment;
  };
} KSIDENTIFIER,*PKSIDENTIFIER;

typedef KSIDENTIFIER KSPROPERTY,*PKSPROPERTY, KSMETHOD,*PKSMETHOD, KSEVENT,*PKSEVENT;

#define KSMETHOD_TYPE_NONE 0x0
#define KSMETHOD_TYPE_READ 0x1
#define KSMETHOD_TYPE_SEND 0x1
#define KSMETHOD_TYPE_WRITE 0x2
#define KSMETHOD_TYPE_MODIFY 0x3
#define KSMETHOD_TYPE_SOURCE 0x4
#define KSMETHOD_TYPE_SETSUPPORT 0x100
#define KSMETHOD_TYPE_BASICSUPPORT 0x200

#define KSPROPERTY_TYPE_GET 0x1
#define KSPROPERTY_TYPE_SET 0x2
#define KSPROPERTY_TYPE_SETSUPPORT 0x100
#define KSPROPERTY_TYPE_BASICSUPPORT 0x200
#define KSPROPERTY_TYPE_RELATIONS 0x400
#define KSPROPERTY_TYPE_SERIALIZESET 0x800
#define KSPROPERTY_TYPE_UNSERIALIZESET 0x1000
#define KSPROPERTY_TYPE_SERIALIZERAW 0x2000
#define KSPROPERTY_TYPE_UNSERIALIZERAW 0x4000
#define KSPROPERTY_TYPE_SERIALIZESIZE 0x8000
#define KSPROPERTY_TYPE_DEFAULTVALUES 0x10000
#define KSPROPERTY_TYPE_TOPOLOGY 0x10000000
#endif

#ifndef _IKsControl_
#define _IKsControl_

#ifdef DECLARE_INTERFACE_
#undef INTERFACE
#define INTERFACE IKsControl

DECLARE_INTERFACE_ (IKsControl, IUnknown) {
#ifndef __cplusplus
  STDMETHOD (QueryInterface) (THIS_ REFIID, LPVOID *) PURE;
  STDMETHOD_ (ULONG, AddRef) (THIS) PURE;
  STDMETHOD_ (ULONG, Release) (THIS) PURE;
#endif
  STDMETHOD (KsProperty) (THIS_ PKSPROPERTY Property, ULONG PropertyLength, LPVOID PropertyData, ULONG DataLength, ULONG *BytesReturned) PURE;
  STDMETHOD (KsMethod) (THIS_ PKSMETHOD Method, ULONG MethodLength, LPVOID MethodData, ULONG DataLength, ULONG *BytesReturned) PURE;
  STDMETHOD (KsEvent) (THIS_ PKSEVENT Event, ULONG EventLength, LPVOID EventData, ULONG DataLength, ULONG *BytesReturned) PURE;
};
#endif
#endif

#include <poppack.h>

DEFINE_GUID (IID_IKsControl, 0x28f54685, 0x06fd, 0x11d2, 0xb2, 0x7a, 0x00, 0xa0, 0xc9, 0x22, 0x31, 0x96);
#ifndef _KSMEDIA_
DEFINE_GUID (KSDATAFORMAT_SUBTYPE_MIDI, 0x1d262760, 0xe957, 0x11cf, 0xa5, 0xd6, 0x28, 0xdb, 0x04, 0xc1, 0x00, 0x00);
DEFINE_GUID (KSDATAFORMAT_SUBTYPE_DIRECTMUSIC, 0x1a82f8bc, 0x3f8b, 0x11d2, 0xb7, 0x74, 0x00, 0x60, 0x08, 0x33, 0x16, 0xc1);
#endif

#endif
#endif
