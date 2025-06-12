/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
/*
 * evntprov.h
 *
 * This file is part of the ReactOS PSDK package.
 *
 * Contributors:
 *   Created by Amine Khaldi.
 *   Extended by Kai Tietz for mingw-w64
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

#ifndef _EVNTPROV_H_
#define _EVNTPROV_H_

#include <winapifamily.h>

#if !defined (EVNTAPI) && !defined (__WIDL__) && !defined (MIDL_PASS)
#ifdef _EVNT_SOURCE_
#ifdef _ARM_
#define EVNTAPI
#else
#define EVNTAPI __stdcall
#endif
#else
#ifdef _ARM_
#define EVNTAPI DECLSPEC_IMPORT
#else
#define EVNTAPI DECLSPEC_IMPORT __stdcall
#endif
#endif
#endif

#define EVENT_MIN_LEVEL (0)
#define EVENT_MAX_LEVEL (0xff)

#define EVENT_ACTIVITY_CTRL_GET_ID (1)
#define EVENT_ACTIVITY_CTRL_SET_ID (2)
#define EVENT_ACTIVITY_CTRL_CREATE_ID (3)
#define EVENT_ACTIVITY_CTRL_GET_SET_ID (4)
#define EVENT_ACTIVITY_CTRL_CREATE_SET_ID (5)

#define EVENT_FILTER_TYPE_SCHEMATIZED (0x80000000)
#define EVENT_FILTER_TYPE_SYSTEM_FLAGS (0x80000001)
#define EVENT_FILTER_TYPE_TRACEHANDLE (0x80000002)

#define MAX_EVENT_DATA_DESCRIPTORS (128)
#define MAX_EVENT_FILTER_DATA_SIZE (1024)

#ifdef __cplusplus
extern "C" {
#endif

#include <guiddef.h>

  typedef ULONGLONG REGHANDLE,*PREGHANDLE;

  typedef struct _EVENT_DATA_DESCRIPTOR {
    ULONGLONG Ptr;
    ULONG Size;
    ULONG Reserved;
  } EVENT_DATA_DESCRIPTOR,*PEVENT_DATA_DESCRIPTOR;

#ifndef EVENT_DESCRIPTOR_DEF
#define EVENT_DESCRIPTOR_DEF
  typedef struct _EVENT_DESCRIPTOR {
    USHORT Id;
    UCHAR Version;
    UCHAR Channel;
    UCHAR Level;
    UCHAR Opcode;
    USHORT Task;
    ULONGLONG Keyword;
  } EVENT_DESCRIPTOR,*PEVENT_DESCRIPTOR;
  typedef const EVENT_DESCRIPTOR *PCEVENT_DESCRIPTOR;
#endif

  struct _EVENT_FILTER_DESCRIPTOR {
    ULONGLONG Ptr;
    ULONG Size;
    ULONG Type;
  };

#ifndef DEFINED_PEVENT_FILTER_DESC
#define DEFINED_PEVENT_FILTER_DESC
  typedef struct _EVENT_FILTER_DESCRIPTOR EVENT_FILTER_DESCRIPTOR,*PEVENT_FILTER_DESCRIPTOR;
#endif /* for evntrace.h */

  typedef struct _EVENT_FILTER_HEADER {
    USHORT Id;
    UCHAR Version;
    UCHAR Reserved[5];
    ULONGLONG InstanceId;
    ULONG Size;
    ULONG NextOffset;
  } EVENT_FILTER_HEADER,*PEVENT_FILTER_HEADER;

#if !defined (_ETW_KM_) && !defined (__WIDL__)  /* for wdm.h & widl */
  typedef enum _EVENT_INFO_CLASS {
    EventProviderBinaryTrackInfo,
    MaxEventInfo
  } EVENT_INFO_CLASS;

  typedef VOID (NTAPI *PENABLECALLBACK) (LPCGUID SourceId, ULONG IsEnabled, UCHAR Level, ULONGLONG MatchAnyKeyword, ULONGLONG MatchAllKeyword, PEVENT_FILTER_DESCRIPTOR FilterData, PVOID CallbackContext);

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#if WINVER >= 0x0600
  BOOLEAN EVNTAPI EventEnabled (REGHANDLE RegHandle, PCEVENT_DESCRIPTOR EventDescriptor);
  BOOLEAN EVNTAPI EventProviderEnabled (REGHANDLE RegHandle, UCHAR Level, ULONGLONG Keyword);
  ULONG EVNTAPI EventWriteTransfer (REGHANDLE RegHandle, PCEVENT_DESCRIPTOR EventDescriptor, LPCGUID ActivityId, LPCGUID RelatedActivityId, ULONG UserDataCount, PEVENT_DATA_DESCRIPTOR UserData);
  ULONG EVNTAPI EventWriteString (REGHANDLE RegHandle, UCHAR Level, ULONGLONG Keyword, PCWSTR String);
  ULONG EVNTAPI EventActivityIdControl (ULONG ControlCode, LPGUID ActivityId);
#endif
#if WINVER >= 0x0601
  ULONG EVNTAPI EventWriteEx (REGHANDLE RegHandle, PCEVENT_DESCRIPTOR EventDescriptor, ULONG64 Filter, ULONG Flags, LPCGUID ActivityId, LPCGUID RelatedActivityId, ULONG UserDataCount, PEVENT_DATA_DESCRIPTOR UserData);
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
#if WINVER >= 0x0600
  ULONG EVNTAPI EventRegister (LPCGUID ProviderId, PENABLECALLBACK EnableCallback, PVOID CallbackContext, PREGHANDLE RegHandle);
  ULONG EVNTAPI EventUnregister (REGHANDLE RegHandle);
  ULONG EVNTAPI EventWrite (REGHANDLE RegHandle, PCEVENT_DESCRIPTOR EventDescriptor, ULONG UserDataCount, PEVENT_DATA_DESCRIPTOR UserData);
#endif
#if WINVER >= 0x0602
  ULONG EVNTAPI EventSetInformation (REGHANDLE RegHandle, EVENT_INFO_CLASS InformationClass, PVOID EventInformation, ULONG InformationLength);
#endif
#endif

#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  FORCEINLINE VOID EventDataDescCreate (PEVENT_DATA_DESCRIPTOR evp, const VOID *d, ULONG sz) {
    evp->Ptr = (ULONGLONG) (ULONG_PTR) d;
    evp->Size = sz;
    evp->Reserved = 0;
  }
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  FORCEINLINE VOID EventDescCreate (PEVENT_DESCRIPTOR ev, USHORT Id, UCHAR ver, UCHAR ch, UCHAR lvl, USHORT t, UCHAR opc, ULONGLONG keyw) {
    ev->Id = Id;
    ev->Version = ver;
    ev->Channel = ch;
    ev->Level = lvl;
    ev->Task = t;
    ev->Opcode = opc;
    ev->Keyword = keyw;
  }

  FORCEINLINE UCHAR EventDescGetChannel (PCEVENT_DESCRIPTOR ev) {
    return ev->Channel;
  }

  FORCEINLINE USHORT EventDescGetId (PCEVENT_DESCRIPTOR ev) {
    return ev->Id;
  }

  FORCEINLINE ULONGLONG EventDescGetKeyword (PCEVENT_DESCRIPTOR ev) {
    return ev->Keyword;
  }

  FORCEINLINE UCHAR EventDescGetLevel (PCEVENT_DESCRIPTOR ev) {
    return ev->Level;
  }

  FORCEINLINE UCHAR EventDescGetOpcode (PCEVENT_DESCRIPTOR ev) {
    return ev->Opcode;
  }

  FORCEINLINE USHORT EventDescGetTask (PCEVENT_DESCRIPTOR ev) {
    return ev->Task;
  }

  FORCEINLINE PEVENT_DESCRIPTOR EventDescOrKeyword (PEVENT_DESCRIPTOR ev, ULONGLONG keyw) {
    ev->Keyword |= keyw;
    return ev;
  }

  FORCEINLINE UCHAR EventDescGetVersion (PCEVENT_DESCRIPTOR ev) {
    return ev->Version;
  }

  FORCEINLINE PEVENT_DESCRIPTOR EventDescSetChannel (PEVENT_DESCRIPTOR ev, UCHAR ch) {
    ev->Channel = ch;
    return ev;
  }

  FORCEINLINE PEVENT_DESCRIPTOR EventDescSetId (PEVENT_DESCRIPTOR ev, USHORT Id) {
    ev->Id = Id;
    return ev;
  }

  FORCEINLINE PEVENT_DESCRIPTOR EventDescSetKeyword (PEVENT_DESCRIPTOR ev, ULONGLONG keyw) {
    ev->Keyword = keyw;
    return ev;
  }

  FORCEINLINE PEVENT_DESCRIPTOR EventDescSetLevel (PEVENT_DESCRIPTOR ev, UCHAR lvl) {
    ev->Level = lvl;
    return ev;
  }

  FORCEINLINE PEVENT_DESCRIPTOR EventDescSetOpcode (PEVENT_DESCRIPTOR ev, UCHAR opc) {
    ev->Opcode = opc;
    return ev;
  }

  FORCEINLINE PEVENT_DESCRIPTOR EventDescSetTask (PEVENT_DESCRIPTOR ev, USHORT t) {
    ev->Task = t;
    return ev;
  }

  FORCEINLINE PEVENT_DESCRIPTOR EventDescSetVersion (PEVENT_DESCRIPTOR ev, UCHAR ver) {
    ev->Version = ver;
    return ev;
  }

  FORCEINLINE VOID EventDescZero (PEVENT_DESCRIPTOR ev) {
    memset (ev, 0, sizeof (EVENT_DESCRIPTOR));
  }
#endif

#ifdef __cplusplus
}
#endif

#endif
