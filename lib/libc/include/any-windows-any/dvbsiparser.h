/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __DVBSIPARSER_H__
#define __DVBSIPARSER_H__

#include <objbase.h>
#include <mpeg2psiparser.h>

#ifndef __IDVB_EIT2_FWD_DEFINED__
#define __IDVB_EIT2_FWD_DEFINED__
typedef struct IDVB_EIT2 IDVB_EIT2;
#endif

#ifndef __IDVB_EIT_FWD_DEFINED__
#define __IDVB_EIT_FWD_DEFINED__
typedef struct IDVB_EIT IDVB_EIT;
#endif

#ifndef __IDvbComponentDescriptor_FWD_DEFINED__
#define __IDvbComponentDescriptor_FWD_DEFINED__
typedef struct IDvbComponentDescriptor IDvbComponentDescriptor;
#endif

#ifndef __IDvbContentDescriptor_FWD_DEFINED__
#define __IDvbContentDescriptor_FWD_DEFINED__
typedef struct IDvbContentDescriptor IDvbContentDescriptor;
#endif

#ifndef __IDvbContentIdentifierDescriptor_FWD_DEFINED__
#define __IDvbContentIdentifierDescriptor_FWD_DEFINED__
typedef struct IDvbContentIdentifierDescriptor IDvbContentIdentifierDescriptor;
#endif

#ifndef __IDvbDataBroadcastDescriptor_FWD_DEFINED__
#define __IDvbDataBroadcastDescriptor_FWD_DEFINED__
typedef struct IDvbDataBroadcastDescriptor IDvbDataBroadcastDescriptor;
#endif

#ifndef __IDvbDataBroadcastIDDescriptor_FWD_DEFINED__
#define __IDvbDataBroadcastIDDescriptor_FWD_DEFINED__
typedef struct IDvbDataBroadcastIDDescriptor IDvbDataBroadcastIDDescriptor;
#endif

#ifndef __IDvbDefaultAuthorityDescriptor_FWD_DEFINED__
#define __IDvbDefaultAuthorityDescriptor_FWD_DEFINED__
typedef struct IDvbDefaultAuthorityDescriptor IDvbDefaultAuthorityDescriptor;
#endif

#ifndef __IDvbExtendedEventDescriptor_FWD_DEFINED__
#define __IDvbExtendedEventDescriptor_FWD_DEFINED__
typedef struct IDvbExtendedEventDescriptor IDvbExtendedEventDescriptor;
#endif

#ifndef __IDvbLogicalChannelDescriptor_FWD_DEFINED__
#define __IDvbLogicalChannelDescriptor_FWD_DEFINED__
typedef struct IDvbLogicalChannelDescriptor IDvbLogicalChannelDescriptor;
#endif

#ifndef __IDvbHDSimulcastLogicalChannelDescriptor_FWD_DEFINED__
#define __IDvbHDSimulcastLogicalChannelDescriptor_FWD_DEFINED__
typedef struct IDvbHDSimulcastLogicalChannelDescriptor IDvbHDSimulcastLogicalChannelDescriptor;
#endif

#ifndef __IDvbLinkageDescriptor_FWD_DEFINED__
#define __IDvbLinkageDescriptor_FWD_DEFINED__
typedef struct IDvbLinkageDescriptor IDvbLinkageDescriptor;
#endif

#ifndef __IDvbLogicalChannel2Descriptor_FWD_DEFINED__
#define __IDvbLogicalChannel2Descriptor_FWD_DEFINED__
typedef struct IDvbLogicalChannel2Descriptor IDvbLogicalChannel2Descriptor;
#endif

#ifndef __IDvbMultilingualServiceNameDescriptor_FWD_DEFINED__
#define __IDvbMultilingualServiceNameDescriptor_FWD_DEFINED__
typedef struct IDvbMultilingualServiceNameDescriptor IDvbMultilingualServiceNameDescriptor;
#endif

#ifndef __IDvbNetworkNameDescriptor_FWD_DEFINED__
#define __IDvbNetworkNameDescriptor_FWD_DEFINED__
typedef struct IDvbNetworkNameDescriptor IDvbNetworkNameDescriptor;
#endif

#ifndef __IDvbParentalRatingDescriptor_FWD_DEFINED__
#define __IDvbParentalRatingDescriptor_FWD_DEFINED__
typedef struct IDvbParentalRatingDescriptor IDvbParentalRatingDescriptor;
#endif

#ifndef __IDvbPrivateDataSpecifierDescriptor_FWD_DEFINED__
#define __IDvbPrivateDataSpecifierDescriptor_FWD_DEFINED__
typedef struct IDvbPrivateDataSpecifierDescriptor IDvbPrivateDataSpecifierDescriptor;
#endif

#ifndef __IDvbServiceDescriptor_FWD_DEFINED__
#define __IDvbServiceDescriptor_FWD_DEFINED__
typedef struct IDvbServiceDescriptor IDvbServiceDescriptor;
#endif

#ifndef __IDvbServiceDescriptor2_FWD_DEFINED__
#define __IDvbServiceDescriptor2_FWD_DEFINED__
typedef struct IDvbServiceDescriptor2 IDvbServiceDescriptor2;
#endif

#ifndef __IDvbLogicalChannelDescriptor2_FWD_DEFINED__
#define __IDvbLogicalChannelDescriptor2_FWD_DEFINED__
typedef struct IDvbLogicalChannelDescriptor2 IDvbLogicalChannelDescriptor2;
#endif

#ifndef __IDvbShortEventDescriptor_FWD_DEFINED__
#define __IDvbShortEventDescriptor_FWD_DEFINED__
typedef struct IDvbShortEventDescriptor IDvbShortEventDescriptor;
#endif

#ifndef __IDVB_RST_FWD_DEFINED__
#define __IDVB_RST_FWD_DEFINED__
typedef struct IDVB_RST IDVB_RST;
#endif

#ifndef __IDVB_SIT_FWD_DEFINED__
#define __IDVB_SIT_FWD_DEFINED__
typedef struct IDVB_SIT IDVB_SIT;
#endif

#ifndef __IDVB_ST_FWD_DEFINED__
#define __IDVB_ST_FWD_DEFINED__
typedef struct IDVB_ST IDVB_ST;
#endif

#ifndef __IDVB_TDT_FWD_DEFINED__
#define __IDVB_TDT_FWD_DEFINED__
typedef struct IDVB_TDT IDVB_TDT;
#endif

#ifndef __IDVB_TOT_FWD_DEFINED__
#define __IDVB_TOT_FWD_DEFINED__
typedef struct IDVB_TOT IDVB_TOT;
#endif

#ifndef __IDvbSiParser2_FWD_DEFINED__
#define __IDvbSiParser2_FWD_DEFINED__
typedef struct IDvbSiParser2 IDvbSiParser2;
#endif

#ifndef __IDvbSubtitlingDescriptor_FWD_DEFINED__
#define __IDvbSubtitlingDescriptor_FWD_DEFINED__
typedef struct IDvbSubtitlingDescriptor IDvbSubtitlingDescriptor;
#endif

#ifndef __IDvbServiceListDescriptor_FWD_DEFINED__
#define __IDvbServiceListDescriptor_FWD_DEFINED__
typedef struct IDvbServiceListDescriptor IDvbServiceListDescriptor;
#endif

#ifndef __IDvbTeletextDescriptor_FWD_DEFINED__
#define __IDvbTeletextDescriptor_FWD_DEFINED__
typedef struct IDvbTeletextDescriptor IDvbTeletextDescriptor;
#endif

#ifndef __IDVB_BAT_FWD_DEFINED__
#define __IDVB_BAT_FWD_DEFINED__
typedef struct IDVB_BAT IDVB_BAT;
#endif

#ifndef __IDVB_DIT_FWD_DEFINED__
#define __IDVB_DIT_FWD_DEFINED__
typedef struct IDVB_DIT IDVB_DIT;
#endif

#ifndef __IDVB_NIT_FWD_DEFINED__
#define __IDVB_NIT_FWD_DEFINED__
typedef struct IDVB_NIT IDVB_NIT;
#endif

#ifndef __IDVB_SDT_FWD_DEFINED__
#define __IDVB_SDT_FWD_DEFINED__
typedef struct IDVB_SDT IDVB_SDT;
#endif

/* Guessed from: http://www.java2s.com/Open-Source/CSharp/Game/DirectShow/DirectShowLib/BDA/dvbsiparser.cs.htm */
typedef enum _DVB_STRCONV_MODE {
  STRCONV_MODE_DVB = 0,
  STRCONV_MODE_DVB_EMPHASIS,
  STRCONV_MODE_DVB_WITHOUT_EMPHASIS,
  STRCONV_MODE_ISDB
} DVB_STRCONV_MODE;

#undef  INTERFACE
#define INTERFACE IDVB_EIT
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDVB_EIT,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDVB_EIT methods */
    STDMETHOD_(HRESULT,ConvertNextToCurrent)(THIS) PURE;
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetLastTableId)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetNextTable)(THIS_ IDVB_EIT **ppEIT) PURE;
    STDMETHOD_(HRESULT,GetOriginalNetworkId)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordCountOfDescriptors)(THIS_ DWORD dwRecordIndex,DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordDescriptorByIndex)(THIS_ DWORD dwRecordIndex,DWORD dwIndex,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetRecordDescriptorByTag)(THIS_ DWORD dwRecordIndex,BYTE bTag,DWORD *pdwCookie,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetRecordDuration)(THIS_ DWORD dwRecordIndex,MPEG_DURATION *pmdVal) PURE;
    STDMETHOD_(HRESULT,GetRecordEventId)(THIS_ DWORD dwRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordFreeCAMode)(THIS_ DWORD dwRecordIndex,WINBOOL *pfVal) PURE;
    STDMETHOD_(HRESULT,GetRecordRunningStatus)(THIS_ DWORD dwRecordIndex,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordStartTime)(THIS_ DWORD dwRecordIndex,MPEG_DATE_AND_TIME *pmdtVal) PURE;
    STDMETHOD_(HRESULT,GetSegmentLastSectionNumber)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetServiceId)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetTransportStreamId)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetVersionHash)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetVersionNumber)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ISectionList *pSectionList,IMpeg2Data *pMPEGData) PURE;
    STDMETHOD_(HRESULT,RegisterForNextTable)(THIS_ HANDLE hNextTableAvailable) PURE;
    STDMETHOD_(HRESULT,RegisterForWhenCurrent)(THIS_ HANDLE hNextTableIsCurrent) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDVB_EIT_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDVB_EIT_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDVB_EIT_Release(This) (This)->lpVtbl->Release(This)
#define IDVB_EIT_ConvertNextToCurrent() (This)->lpVtbl->ConvertNextToCurrent(This)
#define IDVB_EIT_GetCountOfRecords(This,pdwVal) (This)->lpVtbl->GetCountOfRecords(This,pdwVal)
#define IDVB_EIT_GetLastTableId(This,pbVal) (This)->lpVtbl->GetLastTableId(This,pbVal)
#define IDVB_EIT_GetNextTable(This,ppEIT) (This)->lpVtbl->GetNextTable(This,ppEIT)
#define IDVB_EIT_GetOriginalNetworkId(This,pwVal) (This)->lpVtbl->GetOriginalNetworkId(This,pwVal)
#define IDVB_EIT_GetRecordCountOfDescriptors(This,dwRecordIndex,pdwVal) (This)->lpVtbl->GetRecordCountOfDescriptors(This,dwRecordIndex,pdwVal)
#define IDVB_EIT_GetRecordDescriptorByIndex(This,dwRecordIndex,dwIndex,ppDescriptor) (This)->lpVtbl->GetRecordDescriptorByIndex(This,dwRecordIndex,dwIndex,ppDescriptor)
#define IDVB_EIT_GetRecordDescriptorByTag(This,dwRecordIndex,bTag,pdwCookie,ppDescriptor) (This)->lpVtbl->GetRecordDescriptorByTag(This,dwRecordIndex,bTag,pdwCookie,ppDescriptor)
#define IDVB_EIT_GetRecordDuration(This,dwRecordIndex,pmdVal) (This)->lpVtbl->GetRecordDuration(This,dwRecordIndex,pmdVal)
#define IDVB_EIT_GetRecordEventId(This,dwRecordIndex,pwVal) (This)->lpVtbl->GetRecordEventId(This,dwRecordIndex,pwVal)
#define IDVB_EIT_GetRecordFreeCAMode(This,dwRecordIndex,pfVal) (This)->lpVtbl->GetRecordFreeCAMode(This,dwRecordIndex,pfVal)
#define IDVB_EIT_GetRecordRunningStatus(This,dwRecordIndex,pbVal) (This)->lpVtbl->GetRecordRunningStatus(This,dwRecordIndex,pbVal)
#define IDVB_EIT_GetRecordStartTime(This,dwRecordIndex,pmdtVal) (This)->lpVtbl->GetRecordStartTime(This,dwRecordIndex,pmdtVal)
#define IDVB_EIT_GetSegmentLastSectionNumber(This,pbVal) (This)->lpVtbl->GetSegmentLastSectionNumber(This,pbVal)
#define IDVB_EIT_GetServiceId(This,pwVal) (This)->lpVtbl->GetServiceId(This,pwVal)
#define IDVB_EIT_GetTransportStreamId(This,pwVal) (This)->lpVtbl->GetTransportStreamId(This,pwVal)
#define IDVB_EIT_GetVersionHash(This,pbVal) (This)->lpVtbl->GetVersionHash(This,pbVal)
#define IDVB_EIT_GetVersionNumber(This,pbVal) (This)->lpVtbl->GetVersionNumber(This,pbVal)
#define IDVB_EIT_Initialize(This,pSectionList,pMPEGData) (This)->lpVtbl->Initialize(This,pSectionList,pMPEGData)
#define IDVB_EIT_RegisterForNextTable(This,hNextTableAvailable) (This)->lpVtbl->RegisterForNextTable(This,hNextTableAvailable)
#define IDVB_EIT_RegisterForWhenCurrent(This,hNextTableIsCurrent) (This)->lpVtbl->RegisterForWhenCurrent(This,hNextTableIsCurrent)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDVB_EIT2
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDVB_EIT2,IDVB_EIT)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDVB_EIT methods */
    STDMETHOD_(HRESULT,ConvertNextToCurrent)(THIS) PURE;
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetLastTableId)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetNextTable)(THIS_ IDVB_EIT **ppEIT) PURE;
    STDMETHOD_(HRESULT,GetOriginalNetworkId)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordCountOfDescriptors)(THIS_ DWORD dwRecordIndex,DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordDescriptorByIndex)(THIS_ DWORD dwRecordIndex,DWORD dwIndex,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetRecordDescriptorByTag)(THIS_ DWORD dwRecordIndex,BYTE bTag,DWORD *pdwCookie,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetRecordDuration)(THIS_ DWORD dwRecordIndex,MPEG_DURATION *pmdVal) PURE;
    STDMETHOD_(HRESULT,GetRecordEventId)(THIS_ DWORD dwRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordFreeCAMode)(THIS_ DWORD dwRecordIndex,WINBOOL *pfVal) PURE;
    STDMETHOD_(HRESULT,GetRecordRunningStatus)(THIS_ DWORD dwRecordIndex,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordStartTime)(THIS_ DWORD dwRecordIndex,MPEG_DATE_AND_TIME *pmdtVal) PURE;
    STDMETHOD_(HRESULT,GetSegmentLastSectionNumber)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetServiceId)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetTransportStreamId)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetVersionHash)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetVersionNumber)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ISectionList *pSectionList,IMpeg2Data *pMPEGData) PURE;
    STDMETHOD_(HRESULT,RegisterForNextTable)(THIS_ HANDLE hNextTableAvailable) PURE;
    STDMETHOD_(HRESULT,RegisterForWhenCurrent)(THIS_ HANDLE hNextTableIsCurrent) PURE;

    /* IDVB_EIT2 methods */
    STDMETHOD(GetRecordSection)(THIS_ DWORD dwRecordIndex,BYTE *pbVal) PURE;
    STDMETHOD(GetSegmentInfo)(THIS_ BYTE *pbTid,BYTE *pbSegment) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDVB_EIT2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDVB_EIT2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDVB_EIT2_Release(This) (This)->lpVtbl->Release(This)
#define IDVB_EIT2_ConvertNextToCurrent() (This)->lpVtbl->ConvertNextToCurrent(This)
#define IDVB_EIT2_GetCountOfRecords(This,pdwVal) (This)->lpVtbl->GetCountOfRecords(This,pdwVal)
#define IDVB_EIT2_GetLastTableId(This,pbVal) (This)->lpVtbl->GetLastTableId(This,pbVal)
#define IDVB_EIT2_GetNextTable(This,ppEIT) (This)->lpVtbl->GetNextTable(This,ppEIT)
#define IDVB_EIT2_GetOriginalNetworkId(This,pwVal) (This)->lpVtbl->GetOriginalNetworkId(This,pwVal)
#define IDVB_EIT2_GetRecordCountOfDescriptors(This,dwRecordIndex,pdwVal) (This)->lpVtbl->GetRecordCountOfDescriptors(This,dwRecordIndex,pdwVal)
#define IDVB_EIT2_GetRecordDescriptorByIndex(This,dwRecordIndex,dwIndex,ppDescriptor) (This)->lpVtbl->GetRecordDescriptorByIndex(This,dwRecordIndex,dwIndex,ppDescriptor)
#define IDVB_EIT2_GetRecordDescriptorByTag(This,dwRecordIndex,bTag,pdwCookie,ppDescriptor) (This)->lpVtbl->GetRecordDescriptorByTag(This,dwRecordIndex,bTag,pdwCookie,ppDescriptor)
#define IDVB_EIT2_GetRecordDuration(This,dwRecordIndex,pmdVal) (This)->lpVtbl->GetRecordDuration(This,dwRecordIndex,pmdVal)
#define IDVB_EIT2_GetRecordEventId(This,dwRecordIndex,pwVal) (This)->lpVtbl->GetRecordEventId(This,dwRecordIndex,pwVal)
#define IDVB_EIT2_GetRecordFreeCAMode(This,dwRecordIndex,pfVal) (This)->lpVtbl->GetRecordFreeCAMode(This,dwRecordIndex,pfVal)
#define IDVB_EIT2_GetRecordRunningStatus(This,dwRecordIndex,pbVal) (This)->lpVtbl->GetRecordRunningStatus(This,dwRecordIndex,pbVal)
#define IDVB_EIT2_GetRecordStartTime(This,dwRecordIndex,pmdtVal) (This)->lpVtbl->GetRecordStartTime(This,dwRecordIndex,pmdtVal)
#define IDVB_EIT2_GetSegmentLastSectionNumber(This,pbVal) (This)->lpVtbl->GetSegmentLastSectionNumber(This,pbVal)
#define IDVB_EIT2_GetServiceId(This,pwVal) (This)->lpVtbl->GetServiceId(This,pwVal)
#define IDVB_EIT2_GetTransportStreamId(This,pwVal) (This)->lpVtbl->GetTransportStreamId(This,pwVal)
#define IDVB_EIT2_GetVersionHash(This,pbVal) (This)->lpVtbl->GetVersionHash(This,pbVal)
#define IDVB_EIT2_GetVersionNumber(This,pbVal) (This)->lpVtbl->GetVersionNumber(This,pbVal)
#define IDVB_EIT2_Initialize(This,pSectionList,pMPEGData) (This)->lpVtbl->Initialize(This,pSectionList,pMPEGData)
#define IDVB_EIT2_RegisterForNextTable(This,hNextTableAvailable) (This)->lpVtbl->RegisterForNextTable(This,hNextTableAvailable)
#define IDVB_EIT2_RegisterForWhenCurrent(This,hNextTableIsCurrent) (This)->lpVtbl->RegisterForWhenCurrent(This,hNextTableIsCurrent)
#define IDVB_EIT2_GetRecordSection(This,dwRecordIndex,pbVal) (This)->lpVtbl->GetRecordSection(This,dwRecordIndex,pbVal)
#define IDVB_EIT2_GetSegmentInfo(This,pbTid,pbSegment) (This)->lpVtbl->GetSegmentInfo(This,pbTid,pbSegment)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbComponentDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbComponentDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbComponentDescriptor methods */
    STDMETHOD_(HRESULT,GetComponentTag)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetComponentType)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLanguageCode)(THIS_ char *pszCode) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetStreamContent)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTextW)(THIS_ DVB_STRCONV_MODE convMode,BSTR *pbstrText) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbComponentDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbComponentDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbComponentDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbComponentDescriptor_GetComponentTag(This,pbVal) (This)->lpVtbl->GetComponentTag(This,pbVal)
#define IDvbComponentDescriptor_GetComponentType(This,pbVal) (This)->lpVtbl->GetComponentType(This,pbVal)
#define IDvbComponentDescriptor_GetLanguageCode(This,pszCode) (This)->lpVtbl->GetLanguageCode(This,pszCode)
#define IDvbComponentDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbComponentDescriptor_GetStreamContent(This,pbVal) (This)->lpVtbl->GetStreamContent(This,pbVal)
#define IDvbComponentDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#define IDvbComponentDescriptor_GetTextW(This,convMode,pbstrText) (This)->lpVtbl->GetTextW(This,convMode,pbstrText)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbContentDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbContentDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbContentDescriptor methods */
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordContentNibbles)(THIS_ BYTE bRecordIndex,BYTE *pbValLevel1,BYTE *pbValLevel2) PURE;
    STDMETHOD_(HRESULT,GetRecordUserNibbles)(THIS_ BYTE bRecordIndex,BYTE *pbVal1,BYTE *pbVal2) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbContentDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbContentDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbContentDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbContentDescriptor_GetCountOfRecords(This,pbVal) (This)->lpVtbl->GetCountOfRecords(This,pbVal)
#define IDvbContentDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbContentDescriptor_GetRecordContentNibbles(This,bRecordIndex,pbValLevel1,pbValLevel2) (This)->lpVtbl->GetRecordContentNibbles(This,bRecordIndex,pbValLevel1,pbValLevel2)
#define IDvbContentDescriptor_GetRecordUserNibbles(This,bRecordIndex,pbVal1,pbVal2) (This)->lpVtbl->GetRecordUserNibbles(This,bRecordIndex,pbVal1,pbVal2)
#define IDvbContentDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbContentIdentifierDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbContentIdentifierDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbContentIdentifierDescriptor methods */
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordCrid)(THIS_ BYTE bRecordIndex,BYTE *pbType,BYTE *pbLocation,BYTE *pbLength,BYTE **ppbBytes) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbContentIdentifierDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbContentIdentifierDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbContentIdentifierDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbContentIdentifierDescriptor_GetCountOfRecords(This,pbVal) (This)->lpVtbl->GetCountOfRecords(This,pbVal)
#define IDvbContentIdentifierDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbContentIdentifierDescriptor_GetRecordCrid(This,bRecordIndex,pbType,pbLocation,pbLength,ppbBytes) (This)->lpVtbl->GetRecordCrid(This,bRecordIndex,pbType,pbLocation,pbLength,ppbBytes)
#define IDvbContentIdentifierDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbDataBroadcastDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbDataBroadcastDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbDataBroadcastDescriptor methods */
    STDMETHOD_(HRESULT,GetComponentTag)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetDataBroadcastID)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetLangID)(THIS_ ULONG *pulVal) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetSelectorBytes)(THIS_ BYTE *pbLen,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetSelectorLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetText)(THIS_ BYTE *pbLen,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTextLength)(THIS_ BYTE *pbVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbDataBroadcastDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbDataBroadcastDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbDataBroadcastDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbDataBroadcastDescriptor_GetComponentTag(This,pbVal) (This)->lpVtbl->GetComponentTag(This,pbVal)
#define IDvbDataBroadcastDescriptor_GetDataBroadcastID(This,pwVal) (This)->lpVtbl->GetDataBroadcastID(This,pwVal)
#define IDvbDataBroadcastDescriptor_GetLangID(This,pulVal) (This)->lpVtbl->GetLangID(This,pulVal)
#define IDvbDataBroadcastDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbDataBroadcastDescriptor_GetSelectorBytes(This,pbLen,pbVal) (This)->lpVtbl->GetSelectorBytes(This,pbLen,pbVal)
#define IDvbDataBroadcastDescriptor_GetSelectorLength(This,pbVal) (This)->lpVtbl->GetSelectorLength(This,pbVal)
#define IDvbDataBroadcastDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#define IDvbDataBroadcastDescriptor_GetText(This,pbLen,pbVal) (This)->lpVtbl->GetText(This,pbLen,pbVal)
#define IDvbDataBroadcastDescriptor_GetTextLength(This,pbVal) (This)->lpVtbl->GetTextLength(This,pbVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbDataBroadcastIDDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbDataBroadcastIDDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbDataBroadcastIDDescriptor methods */
    STDMETHOD_(HRESULT,GetDataBroadcastID)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetIDSelectorBytes)(THIS_ BYTE *pbLen,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbDataBroadcastIDDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbDataBroadcastIDDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbDataBroadcastIDDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbDataBroadcastIDDescriptor_GetDataBroadcastID(This,pwVal) (This)->lpVtbl->GetDataBroadcastID(This,pwVal)
#define IDvbDataBroadcastIDDescriptor_GetIDSelectorBytes(This,pbLen,pbVal) (This)->lpVtbl->GetIDSelectorBytes(This,pbLen,pbVal)
#define IDvbDataBroadcastIDDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbDataBroadcastIDDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbDefaultAuthorityDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbDefaultAuthorityDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbDefaultAuthorityDescriptor methods */
    STDMETHOD_(HRESULT,GetDefaultAuthority)(THIS_ BYTE *pbLength,BYTE **ppbBytes) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbDefaultAuthorityDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbDefaultAuthorityDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbDefaultAuthorityDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbDefaultAuthorityDescriptor_GetDefaultAuthority(This,pbLength,ppbBytes) (This)->lpVtbl->GetDefaultAuthority(This,pbLength,ppbBytes)
#define IDvbDefaultAuthorityDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbDefaultAuthorityDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbExtendedEventDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbExtendedEventDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbExtendedEventDescriptor methods */
    STDMETHOD_(HRESULT,GetConcatenatedItemW)(THIS_ IDvbExtendedEventDescriptor *pFollowingDescriptor,DVB_STRCONV_MODE convMode,BSTR *pbstrDesc,BSTR *pbstrItem) PURE;
    STDMETHOD_(HRESULT,GetConcatenatedTextW)(THIS_ IDvbExtendedEventDescriptor *FollowingDescriptor,DVB_STRCONV_MODE convMode,BSTR *pbstrText) PURE;
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetDescriptorNumber)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLanguageCode)(THIS_ char *pszCode) PURE;
    STDMETHOD_(HRESULT,GetLastDescriptorNumber)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordItemRawBytes)(THIS_ BYTE bRecordIndex,BYTE **ppbRawItem,BYTE *pbItemLength) PURE;
    STDMETHOD_(HRESULT,GetRecordItemW)(THIS_ BYTE bRecordIndex,DVB_STRCONV_MODE convMode,BSTR *pbstrDesc,BSTR *pbstrItem) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTextW)(THIS_ DVB_STRCONV_MODE convMode,BSTR *pbstrText) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbExtendedEventDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbExtendedEventDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbExtendedEventDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbExtendedEventDescriptor_GetConcatenatedItemW(This,pFollowingDescriptor,convMode,pbstrDesc,pbstrItem) (This)->lpVtbl->GetConcatenatedItemW(This,pFollowingDescriptor,convMode,pbstrDesc,pbstrItem)
#define IDvbExtendedEventDescriptor_GetConcatenatedTextW(This,FollowingDescriptor,convMode,pbstrText) (This)->lpVtbl->GetConcatenatedTextW(This,FollowingDescriptor,convMode,pbstrText)
#define IDvbExtendedEventDescriptor_GetCountOfRecords(This,pbVal) (This)->lpVtbl->GetCountOfRecords(This,pbVal)
#define IDvbExtendedEventDescriptor_GetDescriptorNumber(This,pbVal) (This)->lpVtbl->GetDescriptorNumber(This,pbVal)
#define IDvbExtendedEventDescriptor_GetLanguageCode(This,pszCode) (This)->lpVtbl->GetLanguageCode(This,pszCode)
#define IDvbExtendedEventDescriptor_GetLastDescriptorNumber(This,pbVal) (This)->lpVtbl->GetLastDescriptorNumber(This,pbVal)
#define IDvbExtendedEventDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbExtendedEventDescriptor_GetRecordItemRawBytes(This,bRecordIndex,ppbRawItem,pbItemLength) (This)->lpVtbl->GetRecordItemRawBytes(This,bRecordIndex,ppbRawItem,pbItemLength)
#define IDvbExtendedEventDescriptor_GetRecordItemW(This,bRecordIndex,convMode,pbstrDesc,pbstrItem) (This)->lpVtbl->GetRecordItemW(This,bRecordIndex,convMode,pbstrDesc,pbstrItem)
#define IDvbExtendedEventDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#define IDvbExtendedEventDescriptor_GetTextW(This,convMode,pbstrText) (This)->lpVtbl->GetTextW(This,convMode,pbstrText)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbLogicalChannelDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbLogicalChannelDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbLogicalChannelDescriptor methods */
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordLogicalChannelNumber)(THIS_ BYTE bRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordServiceId)(THIS_ BYTE bRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbLogicalChannelDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbLogicalChannelDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbLogicalChannelDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbLogicalChannelDescriptor_GetCountOfRecords(This,pbVal) (This)->lpVtbl->GetCountOfRecords(This,pbVal)
#define IDvbLogicalChannelDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbLogicalChannelDescriptor_GetRecordLogicalChannelNumber(This,bRecordIndex,pwVal) (This)->lpVtbl->GetRecordLogicalChannelNumber(This,bRecordIndex,pwVal)
#define IDvbLogicalChannelDescriptor_GetRecordServiceId(This,bRecordIndex,pwVal) (This)->lpVtbl->GetRecordServiceId(This,bRecordIndex,pwVal)
#define IDvbLogicalChannelDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbHDSimulcastLogicalChannelDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbHDSimulcastLogicalChannelDescriptor,IDvbLogicalChannelDescriptor)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbLogicalChannelDescriptor methods */
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordLogicalChannelNumber)(THIS_ BYTE bRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordServiceId)(THIS_ BYTE bRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    /* IDvbHDSimulcastLogicalChannelDescriptor methods */

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbHDSimulcastLogicalChannelDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbHDSimulcastLogicalChannelDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbHDSimulcastLogicalChannelDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbHDSimulcastLogicalChannelDescriptor_GetCountOfRecords(This,pbVal) (This)->lpVtbl->GetCountOfRecords(This,pbVal)
#define IDvbHDSimulcastLogicalChannelDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbHDSimulcastLogicalChannelDescriptor_GetRecordLogicalChannelNumber(This,bRecordIndex,pwVal) (This)->lpVtbl->GetRecordLogicalChannelNumber(This,bRecordIndex,pwVal)
#define IDvbHDSimulcastLogicalChannelDescriptor_GetRecordServiceId(This,bRecordIndex,pwVal) (This)->lpVtbl->GetRecordServiceId(This,bRecordIndex,pwVal)
#define IDvbHDSimulcastLogicalChannelDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbLinkageDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbLinkageDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbLinkageDescriptor methods */
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLinkageType)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetONId)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetPrivateData)(THIS_ BYTE *pbLen,BYTE *pbData) PURE;
    STDMETHOD_(HRESULT,GetPrivateDataLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetServiceId)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTSId)(THIS_ WORD *pwVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbLinkageDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbLinkageDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbLinkageDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbLinkageDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbLinkageDescriptor_GetLinkageType(This,pbVal) (This)->lpVtbl->GetLinkageType(This,pbVal)
#define IDvbLinkageDescriptor_GetONId(This,pwVal) (This)->lpVtbl->GetONId(This,pwVal)
#define IDvbLinkageDescriptor_GetPrivateData(This,pbLen,pbData) (This)->lpVtbl->GetPrivateData(This,pbLen,pbData)
#define IDvbLinkageDescriptor_GetPrivateDataLength(This,pbVal) (This)->lpVtbl->GetPrivateDataLength(This,pbVal)
#define IDvbLinkageDescriptor_GetServiceId(This,pwVal) (This)->lpVtbl->GetServiceId(This,pwVal)
#define IDvbLinkageDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#define IDvbLinkageDescriptor_GetTSId(This,pwVal) (This)->lpVtbl->GetTSId(This,pwVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbLogicalChannelDescriptor2
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbLogicalChannelDescriptor2,IDvbLogicalChannelDescriptor)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbLogicalChannelDescriptor methods */
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordLogicalChannelNumber)(THIS_ BYTE bRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordServiceId)(THIS_ BYTE bRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    /* IDvbLogicalChannelDescriptor2 methods */
    STDMETHOD_(HRESULT,GetListRecordLogicalChannelAndVisibility)(THIS_ BYTE bListIndex,BYTE bRecordIndex,WORD *pwVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbLogicalChannelDescriptor2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbLogicalChannelDescriptor2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbLogicalChannelDescriptor2_Release(This) (This)->lpVtbl->Release(This)
#define IDvbLogicalChannelDescriptor2_GetCountOfRecords(This,pbVal) (This)->lpVtbl->GetCountOfRecords(This,pbVal)
#define IDvbLogicalChannelDescriptor2_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbLogicalChannelDescriptor2_GetRecordLogicalChannelNumber(This,bRecordIndex,pwVal) (This)->lpVtbl->GetRecordLogicalChannelNumber(This,bRecordIndex,pwVal)
#define IDvbLogicalChannelDescriptor2_GetRecordServiceId(This,bRecordIndex,pwVal) (This)->lpVtbl->GetRecordServiceId(This,bRecordIndex,pwVal)
#define IDvbLogicalChannelDescriptor2_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#define IDvbLogicalChannelDescriptor2_GetListRecordLogicalChannelAndVisibility(This,bListIndex,bRecordIndex,pwVal) (This)->lpVtbl->GetListRecordLogicalChannelAndVisibility(This,bListIndex,bRecordIndex,pwVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbLogicalChannel2Descriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbLogicalChannel2Descriptor,IDvbLogicalChannelDescriptor2)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbLogicalChannelDescriptor methods */
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordLogicalChannelNumber)(THIS_ BYTE bRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordServiceId)(THIS_ BYTE bRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    /* IDvbLogicalChannelDescriptor2 methods */
    STDMETHOD_(HRESULT,GetListRecordLogicalChannelAndVisibility)(THIS_ BYTE bListIndex,BYTE bRecordIndex,WORD *pwVal) PURE;

    /* IDvbLogicalChannel2Descriptor methods */
    STDMETHOD_(HRESULT,GetCountOfLists)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetListCountOfRecords)(THIS_ BYTE bChannelListIndex,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetListCountryCode)(THIS_ BYTE bListIndex,char *pszCode) PURE;
    STDMETHOD_(HRESULT,GetListId)(THIS_ BYTE bListIndex,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetListNameW)(THIS_ BYTE bListIndex,DVB_STRCONV_MODE convMode,BSTR *pbstrName) PURE;
    STDMETHOD_(HRESULT,GetListRecordLogicalChannelNumber)(THIS_ BYTE bListIndex,BYTE bRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetListRecordServiceId)(THIS_ BYTE bListIndex,BYTE bRecordIndex,WORD *pwVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbLogicalChannel2Descriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbLogicalChannel2Descriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbLogicalChannel2Descriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbLogicalChannel2Descriptor_GetCountOfRecords(This,pbVal) (This)->lpVtbl->GetCountOfRecords(This,pbVal)
#define IDvbLogicalChannel2Descriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbLogicalChannel2Descriptor_GetRecordLogicalChannelNumber(This,bRecordIndex,pwVal) (This)->lpVtbl->GetRecordLogicalChannelNumber(This,bRecordIndex,pwVal)
#define IDvbLogicalChannel2Descriptor_GetRecordServiceId(This,bRecordIndex,pwVal) (This)->lpVtbl->GetRecordServiceId(This,bRecordIndex,pwVal)
#define IDvbLogicalChannel2Descriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#define IDvbLogicalChannel2Descriptor_GetListRecordLogicalChannelAndVisibility(This,bListIndex,bRecordIndex,pwVal) (This)->lpVtbl->GetListRecordLogicalChannelAndVisibility(This,bListIndex,bRecordIndex,pwVal)
#define IDvbLogicalChannel2Descriptor_GetCountOfLists(This,pbVal) (This)->lpVtbl->GetCountOfLists(This,pbVal)
#define IDvbLogicalChannel2Descriptor_GetListCountOfRecords(This,bChannelListIndex,pbVal) (This)->lpVtbl->GetListCountOfRecords(This,bChannelListIndex,pbVal)
#define IDvbLogicalChannel2Descriptor_GetListCountryCode(This,bListIndex,pszCode) (This)->lpVtbl->GetListCountryCode(This,bListIndex,pszCode)
#define IDvbLogicalChannel2Descriptor_GetListId(This,bListIndex,pbVal) (This)->lpVtbl->GetListId(This,bListIndex,pbVal)
#define IDvbLogicalChannel2Descriptor_GetListNameW(This,bListIndex,convMode,pbstrName) (This)->lpVtbl->GetListNameW(This,bListIndex,convMode,pbstrName)
#define IDvbLogicalChannel2Descriptor_GetListRecordLogicalChannelNumber(This,bListIndex,bRecordIndex,pwVal) (This)->lpVtbl->GetListRecordLogicalChannelNumber(This,bListIndex,bRecordIndex,pwVal)
#define IDvbLogicalChannel2Descriptor_GetListRecordServiceId(This,bListIndex,bRecordIndex,pwVal) (This)->lpVtbl->GetListRecordServiceId(This,bListIndex,bRecordIndex,pwVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbMultilingualServiceNameDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbMultilingualServiceNameDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbMultilingualServiceNameDescriptor methods */
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordLangId)(THIS_ BYTE bRecordIndex,ULONG *ulVal) PURE;
    STDMETHOD_(HRESULT,GetRecordServiceNameW)(THIS_ BYTE bRecordIndex,DVB_STRCONV_MODE convMode,BSTR *pbstrName) PURE;
    STDMETHOD_(HRESULT,GetRecordServiceProviderNameW)(THIS_ BYTE bRecordIndex,DVB_STRCONV_MODE convMode,BSTR *pbstrName) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbMultilingualServiceNameDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbMultilingualServiceNameDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbMultilingualServiceNameDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbMultilingualServiceNameDescriptor_GetCountOfRecords(This,pbVal) (This)->lpVtbl->GetCountOfRecords(This,pbVal)
#define IDvbMultilingualServiceNameDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbMultilingualServiceNameDescriptor_GetRecordLangId(This,bRecordIndex,ulVal) (This)->lpVtbl->GetRecordLangId(This,bRecordIndex,ulVal)
#define IDvbMultilingualServiceNameDescriptor_GetRecordServiceNameW(This,bRecordIndex,convMode,pbstrName) (This)->lpVtbl->GetRecordServiceNameW(This,bRecordIndex,convMode,pbstrName)
#define IDvbMultilingualServiceNameDescriptor_GetRecordServiceProviderNameW(This,bRecordIndex,convMode,pbstrName) (This)->lpVtbl->GetRecordServiceProviderNameW(This,bRecordIndex,convMode,pbstrName)
#define IDvbMultilingualServiceNameDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbNetworkNameDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbNetworkNameDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbNetworkNameDescriptor methods */
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetNetworkName)(THIS_ char **pszName) PURE;
    STDMETHOD_(HRESULT,GetNetworkNameW)(THIS_ DVB_STRCONV_MODE convMode,BSTR *pbstrName) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbNetworkNameDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbNetworkNameDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbNetworkNameDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbNetworkNameDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbNetworkNameDescriptor_GetNetworkName(This,pszName) (This)->lpVtbl->GetNetworkName(This,pszName)
#define IDvbNetworkNameDescriptor_GetNetworkNameW(This,convMode,pbstrName) (This)->lpVtbl->GetNetworkNameW(This,convMode,pbstrName)
#define IDvbNetworkNameDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbParentalRatingDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbParentalRatingDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbParentalRatingDescriptor methods */
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordRating)(THIS_ BYTE bRecordIndex,char *pszCountryCode,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbParentalRatingDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbParentalRatingDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbParentalRatingDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbParentalRatingDescriptor_GetCountOfRecords(This,pbVal) (This)->lpVtbl->GetCountOfRecords(This,pbVal)
#define IDvbParentalRatingDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbParentalRatingDescriptor_GetRecordRating(This,bRecordIndex,pszCountryCode,pbVal) (This)->lpVtbl->GetRecordRating(This,bRecordIndex,pszCountryCode,pbVal)
#define IDvbParentalRatingDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbPrivateDataSpecifierDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbPrivateDataSpecifierDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbPrivateDataSpecifierDescriptor methods */
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetPrivateDataSpecifier)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbPrivateDataSpecifierDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbPrivateDataSpecifierDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbPrivateDataSpecifierDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbPrivateDataSpecifierDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbPrivateDataSpecifierDescriptor_GetPrivateDataSpecifier(This,pdwVal) (This)->lpVtbl->GetPrivateDataSpecifier(This,pdwVal)
#define IDvbPrivateDataSpecifierDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbServiceDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbServiceDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbServiceDescriptor methods */
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetProcessedServiceName)(THIS_ BSTR *pbstrName) PURE;
    STDMETHOD_(HRESULT,GetServiceName)(THIS_ char **pszName) PURE;
    STDMETHOD_(HRESULT,GetServiceNameEmphasized)(THIS_ BSTR *pbstrName) PURE;
    STDMETHOD_(HRESULT,GetServiceProviderName)(THIS_ char **pszName) PURE;
    STDMETHOD_(HRESULT,GetServiceProviderNameW)(THIS_ BSTR *pbstrName) PURE;
    STDMETHOD_(HRESULT,GetServiceType)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbServiceDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbServiceDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbServiceDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbServiceDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbServiceDescriptor_GetProcessedServiceName(This,pbstrName) (This)->lpVtbl->GetProcessedServiceName(This,pbstrName)
#define IDvbServiceDescriptor_GetServiceName(This,pszName) (This)->lpVtbl->GetServiceName(This,pszName)
#define IDvbServiceDescriptor_GetServiceNameEmphasized(This,pbstrName) (This)->lpVtbl->GetServiceNameEmphasized(This,pbstrName)
#define IDvbServiceDescriptor_GetServiceProviderName(This,pszName) (This)->lpVtbl->GetServiceProviderName(This,pszName)
#define IDvbServiceDescriptor_GetServiceProviderNameW(This,pbstrName) (This)->lpVtbl->GetServiceProviderNameW(This,pbstrName)
#define IDvbServiceDescriptor_GetServiceType(This,pbVal) (This)->lpVtbl->GetServiceType(This,pbVal)
#define IDvbServiceDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#endif /*COBJMACROS*/

/* Fixme: Duplicate GetServiceProviderNameW method */
#undef  INTERFACE
#define INTERFACE IDvbServiceDescriptor2
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbServiceDescriptor2,IDvbServiceDescriptor)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbServiceDescriptor methods */
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetProcessedServiceName)(THIS_ BSTR *pbstrName) PURE;
    STDMETHOD_(HRESULT,GetServiceName)(THIS_ char **pszName) PURE;
    STDMETHOD_(HRESULT,GetServiceNameEmphasized)(THIS_ BSTR *pbstrName) PURE;
    STDMETHOD_(HRESULT,GetServiceProviderName)(THIS_ char **pszName) PURE;
    STDMETHOD_(HRESULT,GetServiceProviderNameW)(THIS_ BSTR *pbstrName) PURE;
    STDMETHOD_(HRESULT,GetServiceType)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    /* IDvbServiceDescriptor2 methods */
    STDMETHOD_(HRESULT,GetServiceNameW)(THIS_ DVB_STRCONV_MODE convMode,BSTR *pbstrName) PURE;
    /* STDMETHOD_(HRESULT,GetServiceProviderNameW)(THIS_ DVB_STRCONV_MODE convMode,BSTR *pbstrName) PURE; */

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbServiceDescriptor2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbServiceDescriptor2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbServiceDescriptor2_Release(This) (This)->lpVtbl->Release(This)
#define IDvbServiceDescriptor2_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbServiceDescriptor2_GetProcessedServiceName(This,pbstrName) (This)->lpVtbl->GetProcessedServiceName(This,pbstrName)
#define IDvbServiceDescriptor2_GetServiceName(This,pszName) (This)->lpVtbl->GetServiceName(This,pszName)
#define IDvbServiceDescriptor2_GetServiceNameEmphasized(This,pbstrName) (This)->lpVtbl->GetServiceNameEmphasized(This,pbstrName)
#define IDvbServiceDescriptor2_GetServiceProviderName(This,pszName) (This)->lpVtbl->GetServiceProviderName(This,pszName)
#define IDvbServiceDescriptor2_GetServiceProviderNameW(This,pbstrName) (This)->lpVtbl->GetServiceProviderNameW(This,pbstrName)
#define IDvbServiceDescriptor2_GetServiceType(This,pbVal) (This)->lpVtbl->GetServiceType(This,pbVal)
#define IDvbServiceDescriptor2_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#define IDvbServiceDescriptor2_GetServiceNameW(This,convMode,pbstrName) (This)->lpVtbl->GetServiceNameW(This,convMode,pbstrName)
#define IDvbServiceDescriptor2_GetServiceProviderNameW(This,convMode,pbstrName) (This)->lpVtbl->GetServiceProviderNameW(This,convMode,pbstrName)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbShortEventDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbShortEventDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbShortEventDescriptor methods */
    STDMETHOD_(HRESULT,GetEventNameW)(THIS_ DVB_STRCONV_MODE convMode,BSTR *pbstrName) PURE;
    STDMETHOD_(HRESULT,GetLanguageCode)(THIS_ char *pszCode) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTextW)(THIS_ DVB_STRCONV_MODE convMode,BSTR *pbstrText) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbShortEventDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbShortEventDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbShortEventDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbShortEventDescriptor_GetEventNameW(This,convMode,pbstrName) (This)->lpVtbl->GetEventNameW(This,convMode,pbstrName)
#define IDvbShortEventDescriptor_GetLanguageCode(This,pszCode) (This)->lpVtbl->GetLanguageCode(This,pszCode)
#define IDvbShortEventDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbShortEventDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#define IDvbShortEventDescriptor_GetTextW(This,convMode,pbstrText) (This)->lpVtbl->GetTextW(This,convMode,pbstrText)
#endif /*COBJMACROS*/

#define DVB_EIT_ACTUAL_TID (0x4E)
#define DVB_EIT_OTHER_TID (0x4F)
#define DVB_NIT_ACTUAL_TID (0x40)
#define DVB_NIT_OTHER_TID (0x41)
#define DVB_SDT_ACTUAL_TID (0x42)
#define DVB_SDT_OTHER_TID (0x46)

#undef  INTERFACE
#define INTERFACE IDvbSiParser
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbSiParser,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbSiParser methods */
    STDMETHOD_(HRESULT,GetBAT)(THIS_ WORD *pwBouquetId,IDVB_BAT **ppBAT) PURE;
    STDMETHOD_(HRESULT,GetCAT)(THIS_ DWORD dwTimeout,ICAT **ppCAT) PURE;
    STDMETHOD_(HRESULT,GetDIT)(THIS_ DWORD dwTimeout,IDVB_DIT **ppDIT) PURE;
    STDMETHOD_(HRESULT,GetEIT)(THIS_ TID tableId,WORD *pwServiceId,IDVB_EIT **ppEIT) PURE;
    STDMETHOD_(HRESULT,GetNIT)(THIS_ TID tableId,WORD *pwNetworkId,IDVB_NIT **ppNIT) PURE;
    STDMETHOD_(HRESULT,GetPAT)(THIS_ IPAT **ppPAT) PURE;
    STDMETHOD_(HRESULT,GetPMT)(THIS_ PID pid,WORD *pwProgramNumber,IPMT **ppPMT) PURE;
    STDMETHOD_(HRESULT,GetRST)(THIS_ DWORD dwTimeout,IDVB_RST **ppRST) PURE;
    STDMETHOD_(HRESULT,GetSDT)(THIS_ TID tableId,WORD *pwTransportStreamId,IDVB_SDT **ppSDT) PURE;
    STDMETHOD_(HRESULT,GetSIT)(THIS_ DWORD dwTimeout,IDVB_SIT **ppSIT) PURE;
    STDMETHOD_(HRESULT,GetST)(THIS_ PID pid,DWORD dwTimeout,IDVB_ST **ppST) PURE;
    STDMETHOD_(HRESULT,GetTDT)(THIS_ IDVB_TDT **ppTDT) PURE;
    STDMETHOD_(HRESULT,GetTOT)(THIS_ IDVB_TOT **ppTOT) PURE;
    STDMETHOD_(HRESULT,GetTSDT)(THIS_ ITSDT **ppTSDT) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ IUnknown *punkMpeg2Data) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbSiParser_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbSiParser_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbSiParser_Release(This) (This)->lpVtbl->Release(This)
#define IDvbSiParser_GetBAT(This,pwBouquetId,ppBAT) (This)->lpVtbl->GetBAT(This,pwBouquetId,ppBAT)
#define IDvbSiParser_GetCAT(This,dwTimeout,ppCAT) (This)->lpVtbl->GetCAT(This,dwTimeout,ppCAT)
#define IDvbSiParser_GetDIT(This,dwTimeout,ppDIT) (This)->lpVtbl->GetDIT(This,dwTimeout,ppDIT)
#define IDvbSiParser_GetEIT(This,tableId,pwServiceId,ppEIT) (This)->lpVtbl->GetEIT(This,tableId,pwServiceId,ppEIT)
#define IDvbSiParser_GetNIT(This,tableId,pwNetworkId,ppNIT) (This)->lpVtbl->GetNIT(This,tableId,pwNetworkId,ppNIT)
#define IDvbSiParser_GetPAT(This,ppPAT) (This)->lpVtbl->GetPAT(This,ppPAT)
#define IDvbSiParser_GetPMT(This,pid,pwProgramNumber,ppPMT) (This)->lpVtbl->GetPMT(This,pid,pwProgramNumber,ppPMT)
#define IDvbSiParser_GetRST(This,dwTimeout,ppRST) (This)->lpVtbl->GetRST(This,dwTimeout,ppRST)
#define IDvbSiParser_GetSDT(This,tableId,pwTransportStreamId,ppSDT) (This)->lpVtbl->GetSDT(This,tableId,pwTransportStreamId,ppSDT)
#define IDvbSiParser_GetSIT(This,dwTimeout,ppSIT) (This)->lpVtbl->GetSIT(This,dwTimeout,ppSIT)
#define IDvbSiParser_GetST(This,pid,dwTimeout,ppST) (This)->lpVtbl->GetST(This,pid,dwTimeout,ppST)
#define IDvbSiParser_GetTDT(This,ppTDT) (This)->lpVtbl->GetTDT(This,ppTDT)
#define IDvbSiParser_GetTOT(This,ppTOT) (This)->lpVtbl->GetTOT(This,ppTOT)
#define IDvbSiParser_GetTSDT(This,ppTSDT) (This)->lpVtbl->GetTSDT(This,ppTSDT)
#define IDvbSiParser_Initialize(This,punkMpeg2Data) (This)->lpVtbl->Initialize(This,punkMpeg2Data)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDVB_RST
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDVB_RST,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDVB_RST methods */
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordEventId)(THIS_ DWORD dwRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordOriginalNetworkId)(THIS_ DWORD dwRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordRunningStatus)(THIS_ DWORD dwRecordIndex,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordServiceId)(THIS_ DWORD dwRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordTransportStreamId)(THIS_ DWORD dwRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ISectionList *pSectionList) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDVB_RST_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDVB_RST_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDVB_RST_Release(This) (This)->lpVtbl->Release(This)
#define IDVB_RST_GetCountOfRecords(This,pdwVal) (This)->lpVtbl->GetCountOfRecords(This,pdwVal)
#define IDVB_RST_GetRecordEventId(This,dwRecordIndex,pwVal) (This)->lpVtbl->GetRecordEventId(This,dwRecordIndex,pwVal)
#define IDVB_RST_GetRecordOriginalNetworkId(This,dwRecordIndex,pwVal) (This)->lpVtbl->GetRecordOriginalNetworkId(This,dwRecordIndex,pwVal)
#define IDVB_RST_GetRecordRunningStatus(This,dwRecordIndex,pbVal) (This)->lpVtbl->GetRecordRunningStatus(This,dwRecordIndex,pbVal)
#define IDVB_RST_GetRecordServiceId(This,dwRecordIndex,pwVal) (This)->lpVtbl->GetRecordServiceId(This,dwRecordIndex,pwVal)
#define IDVB_RST_GetRecordTransportStreamId(This,dwRecordIndex,pwVal) (This)->lpVtbl->GetRecordTransportStreamId(This,dwRecordIndex,pwVal)
#define IDVB_RST_Initialize(This,pSectionList) (This)->lpVtbl->Initialize(This,pSectionList)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDVB_SIT
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDVB_SIT,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDVB_SIT methods */
    STDMETHOD_(HRESULT,ConvertNextToCurrent)(THIS) PURE;
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetCountOfTableDescriptors)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetNextTable)(THIS_ DWORD dwTimeout,IDVB_SIT **ppSIT) PURE;
    STDMETHOD_(HRESULT,GetRecordCountOfDescriptors)(THIS_ DWORD dwRecordIndex,DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordDescriptorByIndex)(THIS_ DWORD dwRecordIndex,DWORD dwIndex,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetRecordDescriptorByTag)(THIS_ DWORD dwRecordIndex,BYTE bTag,DWORD *pdwCookie,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetRecordRunningStatus)(THIS_ DWORD dwRecordIndex,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordServiceId)(THIS_ DWORD dwRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetTableDescriptorByIndex)(THIS_ DWORD dwIndex,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetTableDescriptorByTag)(THIS_ BYTE bTag,DWORD *pdwCookie,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetVersionNumber)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ISectionList *pSectionList,IMpeg2Data *pMPEGData) PURE;
    STDMETHOD_(HRESULT,RegisterForNextTable)(THIS_ HANDLE hNextTableAvailable) PURE;
    STDMETHOD_(HRESULT,RegisterForWhenCurrent)(THIS_ HANDLE hNextTableIsCurrent) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDVB_SIT_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDVB_SIT_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDVB_SIT_Release(This) (This)->lpVtbl->Release(This)
#define IDVB_SIT_ConvertNextToCurrent() (This)->lpVtbl->ConvertNextToCurrent(This)
#define IDVB_SIT_GetCountOfRecords(This,pdwVal) (This)->lpVtbl->GetCountOfRecords(This,pdwVal)
#define IDVB_SIT_GetCountOfTableDescriptors(This,pdwVal) (This)->lpVtbl->GetCountOfTableDescriptors(This,pdwVal)
#define IDVB_SIT_GetNextTable(This,dwTimeout,ppSIT) (This)->lpVtbl->GetNextTable(This,dwTimeout,ppSIT)
#define IDVB_SIT_GetRecordCountOfDescriptors(This,dwRecordIndex,pdwVal) (This)->lpVtbl->GetRecordCountOfDescriptors(This,dwRecordIndex,pdwVal)
#define IDVB_SIT_GetRecordDescriptorByIndex(This,dwRecordIndex,dwIndex,ppDescriptor) (This)->lpVtbl->GetRecordDescriptorByIndex(This,dwRecordIndex,dwIndex,ppDescriptor)
#define IDVB_SIT_GetRecordDescriptorByTag(This,dwRecordIndex,bTag,pdwCookie,ppDescriptor) (This)->lpVtbl->GetRecordDescriptorByTag(This,dwRecordIndex,bTag,pdwCookie,ppDescriptor)
#define IDVB_SIT_GetRecordRunningStatus(This,dwRecordIndex,pbVal) (This)->lpVtbl->GetRecordRunningStatus(This,dwRecordIndex,pbVal)
#define IDVB_SIT_GetRecordServiceId(This,dwRecordIndex,pwVal) (This)->lpVtbl->GetRecordServiceId(This,dwRecordIndex,pwVal)
#define IDVB_SIT_GetTableDescriptorByIndex(This,dwIndex,ppDescriptor) (This)->lpVtbl->GetTableDescriptorByIndex(This,dwIndex,ppDescriptor)
#define IDVB_SIT_GetTableDescriptorByTag(This,bTag,pdwCookie,ppDescriptor) (This)->lpVtbl->GetTableDescriptorByTag(This,bTag,pdwCookie,ppDescriptor)
#define IDVB_SIT_GetVersionNumber(This,pbVal) (This)->lpVtbl->GetVersionNumber(This,pbVal)
#define IDVB_SIT_Initialize(This,pSectionList,pMPEGData) (This)->lpVtbl->Initialize(This,pSectionList,pMPEGData)
#define IDVB_SIT_RegisterForNextTable(This,hNextTableAvailable) (This)->lpVtbl->RegisterForNextTable(This,hNextTableAvailable)
#define IDVB_SIT_RegisterForWhenCurrent(This,hNextTableIsCurrent) (This)->lpVtbl->RegisterForWhenCurrent(This,hNextTableIsCurrent)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDVB_ST
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDVB_ST,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDVB_ST methods */
    STDMETHOD_(HRESULT,GetData)(THIS_ BYTE **ppData) PURE;
    STDMETHOD_(HRESULT,GetDataLength)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ISectionList *pSectionList) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDVB_ST_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDVB_ST_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDVB_ST_Release(This) (This)->lpVtbl->Release(This)
#define IDVB_ST_GetData(This,ppData) (This)->lpVtbl->GetData(This,ppData)
#define IDVB_ST_GetDataLength(This,pwVal) (This)->lpVtbl->GetDataLength(This,pwVal)
#define IDVB_ST_Initialize(This,pSectionList) (This)->lpVtbl->Initialize(This,pSectionList)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDVB_TDT
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDVB_TDT,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDVB_TDT methods */
    STDMETHOD_(HRESULT,GetUTCTime)(THIS_ MPEG_DATE_AND_TIME *pmdtVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ISectionList *pSectionList) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDVB_TDT_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDVB_TDT_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDVB_TDT_Release(This) (This)->lpVtbl->Release(This)
#define IDVB_TDT_GetUTCTime(This,pmdtVal) (This)->lpVtbl->GetUTCTime(This,pmdtVal)
#define IDVB_TDT_Initialize(This,pSectionList) (This)->lpVtbl->Initialize(This,pSectionList)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDVB_TOT
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDVB_TOT,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDVB_TOT methods */
    STDMETHOD_(HRESULT,GetCountOfTableDescriptors)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetTableDescriptorByIndex)(THIS_ DWORD dwIndex,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetTableDescriptorByTag)(THIS_ BYTE bTag,DWORD *pdwCookie,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetUTCTime)(THIS_ MPEG_DATE_AND_TIME *pmdtVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ISectionList *pSectionList) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDVB_TOT_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDVB_TOT_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDVB_TOT_Release(This) (This)->lpVtbl->Release(This)
#define IDVB_TOT_GetCountOfTableDescriptors(This,pdwVal) (This)->lpVtbl->GetCountOfTableDescriptors(This,pdwVal)
#define IDVB_TOT_GetTableDescriptorByIndex(This,dwIndex,ppDescriptor) (This)->lpVtbl->GetTableDescriptorByIndex(This,dwIndex,ppDescriptor)
#define IDVB_TOT_GetTableDescriptorByTag(This,bTag,pdwCookie,ppDescriptor) (This)->lpVtbl->GetTableDescriptorByTag(This,bTag,pdwCookie,ppDescriptor)
#define IDVB_TOT_GetUTCTime(This,pmdtVal) (This)->lpVtbl->GetUTCTime(This,pmdtVal)
#define IDVB_TOT_Initialize(This,pSectionList) (This)->lpVtbl->Initialize(This,pSectionList)
#endif /*COBJMACROS*/

/* Fixme: Possibly F6B96EDA-1A94-4476-A85F-4D3DC7B39C3F */
#undef  INTERFACE
#define INTERFACE IDvbSiParser2
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbSiParser2,IDvbSiParser)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbSiParser methods */
    STDMETHOD_(HRESULT,GetBAT)(THIS_ WORD *pwBouquetId,IDVB_BAT **ppBAT) PURE;
    STDMETHOD_(HRESULT,GetCAT)(THIS_ DWORD dwTimeout,ICAT **ppCAT) PURE;
    STDMETHOD_(HRESULT,GetDIT)(THIS_ DWORD dwTimeout,IDVB_DIT **ppDIT) PURE;
    STDMETHOD_(HRESULT,GetEIT)(THIS_ TID tableId,WORD *pwServiceId,IDVB_EIT **ppEIT) PURE;
    STDMETHOD_(HRESULT,GetNIT)(THIS_ TID tableId,WORD *pwNetworkId,IDVB_NIT **ppNIT) PURE;
    STDMETHOD_(HRESULT,GetPAT)(THIS_ IPAT **ppPAT) PURE;
    STDMETHOD_(HRESULT,GetPMT)(THIS_ PID pid,WORD *pwProgramNumber,IPMT **ppPMT) PURE;
    STDMETHOD_(HRESULT,GetRST)(THIS_ DWORD dwTimeout,IDVB_RST **ppRST) PURE;
    STDMETHOD_(HRESULT,GetSDT)(THIS_ TID tableId,WORD *pwTransportStreamId,IDVB_SDT **ppSDT) PURE;
    STDMETHOD_(HRESULT,GetSIT)(THIS_ DWORD dwTimeout,IDVB_SIT **ppSIT) PURE;
    STDMETHOD_(HRESULT,GetST)(THIS_ PID pid,DWORD dwTimeout,IDVB_ST **ppST) PURE;
    STDMETHOD_(HRESULT,GetTDT)(THIS_ IDVB_TDT **ppTDT) PURE;
    STDMETHOD_(HRESULT,GetTOT)(THIS_ IDVB_TOT **ppTOT) PURE;
    STDMETHOD_(HRESULT,GetTSDT)(THIS_ ITSDT **ppTSDT) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ IUnknown *punkMpeg2Data) PURE;

    /* IDvbSiParser2 methods */
    STDMETHOD_(HRESULT,GetEIT2)(THIS_ TID tableId,WORD *pwServiceId,BYTE *pbSegment,IDVB_EIT2 **ppEIT) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbSiParser2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbSiParser2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbSiParser2_Release(This) (This)->lpVtbl->Release(This)
#define IDvbSiParser2_GetBAT(This,pwBouquetId,ppBAT) (This)->lpVtbl->GetBAT(This,pwBouquetId,ppBAT)
#define IDvbSiParser2_GetCAT(This,dwTimeout,ppCAT) (This)->lpVtbl->GetCAT(This,dwTimeout,ppCAT)
#define IDvbSiParser2_GetDIT(This,dwTimeout,ppDIT) (This)->lpVtbl->GetDIT(This,dwTimeout,ppDIT)
#define IDvbSiParser2_GetEIT(This,tableId,pwServiceId,ppEIT) (This)->lpVtbl->GetEIT(This,tableId,pwServiceId,ppEIT)
#define IDvbSiParser2_GetNIT(This,tableId,pwNetworkId,ppNIT) (This)->lpVtbl->GetNIT(This,tableId,pwNetworkId,ppNIT)
#define IDvbSiParser2_GetPAT(This,ppPAT) (This)->lpVtbl->GetPAT(This,ppPAT)
#define IDvbSiParser2_GetPMT(This,pid,pwProgramNumber,ppPMT) (This)->lpVtbl->GetPMT(This,pid,pwProgramNumber,ppPMT)
#define IDvbSiParser2_GetRST(This,dwTimeout,ppRST) (This)->lpVtbl->GetRST(This,dwTimeout,ppRST)
#define IDvbSiParser2_GetSDT(This,tableId,pwTransportStreamId,ppSDT) (This)->lpVtbl->GetSDT(This,tableId,pwTransportStreamId,ppSDT)
#define IDvbSiParser2_GetSIT(This,dwTimeout,ppSIT) (This)->lpVtbl->GetSIT(This,dwTimeout,ppSIT)
#define IDvbSiParser2_GetST(This,pid,dwTimeout,ppST) (This)->lpVtbl->GetST(This,pid,dwTimeout,ppST)
#define IDvbSiParser2_GetTDT(This,ppTDT) (This)->lpVtbl->GetTDT(This,ppTDT)
#define IDvbSiParser2_GetTOT(This,ppTOT) (This)->lpVtbl->GetTOT(This,ppTOT)
#define IDvbSiParser2_GetTSDT(This,ppTSDT) (This)->lpVtbl->GetTSDT(This,ppTSDT)
#define IDvbSiParser2_Initialize(This,punkMpeg2Data) (This)->lpVtbl->Initialize(This,punkMpeg2Data)
#define IDvbSiParser2_GetEIT2(This,tableId,pwServiceId,pbSegment,ppEIT) (This)->lpVtbl->GetEIT2(This,tableId,pwServiceId,pbSegment,ppEIT)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbSubtitlingDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbSubtitlingDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbSubtitlingDescriptor methods */
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordAncillaryPageID)(THIS_ BYTE bRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordCompositionPageID)(THIS_ BYTE bRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordLangId)(THIS_ BYTE bRecordIndex,ULONG *pulVal) PURE;
    STDMETHOD_(HRESULT,GetRecordSubtitlingType)(THIS_ BYTE bRecordIndex,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbSubtitlingDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbSubtitlingDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbSubtitlingDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbSubtitlingDescriptor_GetCountOfRecords(This,pbVal) (This)->lpVtbl->GetCountOfRecords(This,pbVal)
#define IDvbSubtitlingDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbSubtitlingDescriptor_GetRecordAncillaryPageID(This,bRecordIndex,pwVal) (This)->lpVtbl->GetRecordAncillaryPageID(This,bRecordIndex,pwVal)
#define IDvbSubtitlingDescriptor_GetRecordCompositionPageID(This,bRecordIndex,pwVal) (This)->lpVtbl->GetRecordCompositionPageID(This,bRecordIndex,pwVal)
#define IDvbSubtitlingDescriptor_GetRecordLangId(This,bRecordIndex,pulVal) (This)->lpVtbl->GetRecordLangId(This,bRecordIndex,pulVal)
#define IDvbSubtitlingDescriptor_GetRecordSubtitlingType(This,bRecordIndex,pbVal) (This)->lpVtbl->GetRecordSubtitlingType(This,bRecordIndex,pbVal)
#define IDvbSubtitlingDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbServiceListDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbServiceListDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbServiceListDescriptor methods */
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordServiceId)(THIS_ BYTE bRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordServiceType)(THIS_ BYTE bRecordIndex,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbServiceListDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbServiceListDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbServiceListDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbServiceListDescriptor_GetCountOfRecords(This,pbVal) (This)->lpVtbl->GetCountOfRecords(This,pbVal)
#define IDvbServiceListDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbServiceListDescriptor_GetRecordServiceId(This,bRecordIndex,pwVal) (This)->lpVtbl->GetRecordServiceId(This,bRecordIndex,pwVal)
#define IDvbServiceListDescriptor_GetRecordServiceType(This,bRecordIndex,pbVal) (This)->lpVtbl->GetRecordServiceType(This,bRecordIndex,pbVal)
#define IDvbServiceListDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDvbTeletextDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDvbTeletextDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDvbTeletextDescriptor methods */
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordLangId)(THIS_ BYTE bRecordIndex,ULONG *pulVal) PURE;
    STDMETHOD_(HRESULT,GetRecordMagazineNumber)(THIS_ BYTE bRecordIndex,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordPageNumber)(THIS_ BYTE bRecordIndex,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordTeletextType)(THIS_ BYTE bRecordIndex,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDvbTeletextDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDvbTeletextDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDvbTeletextDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IDvbTeletextDescriptor_GetCountOfRecords(This,pbVal) (This)->lpVtbl->GetCountOfRecords(This,pbVal)
#define IDvbTeletextDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IDvbTeletextDescriptor_GetRecordLangId(This,bRecordIndex,pulVal) (This)->lpVtbl->GetRecordLangId(This,bRecordIndex,pulVal)
#define IDvbTeletextDescriptor_GetRecordMagazineNumber(This,bRecordIndex,pbVal) (This)->lpVtbl->GetRecordMagazineNumber(This,bRecordIndex,pbVal)
#define IDvbTeletextDescriptor_GetRecordPageNumber(This,bRecordIndex,pbVal) (This)->lpVtbl->GetRecordPageNumber(This,bRecordIndex,pbVal)
#define IDvbTeletextDescriptor_GetRecordTeletextType(This,bRecordIndex,pbVal) (This)->lpVtbl->GetRecordTeletextType(This,bRecordIndex,pbVal)
#define IDvbTeletextDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDVB_BAT
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDVB_BAT,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDVB_BAT methods */
    STDMETHOD_(HRESULT,ConvertNextToCurrent)(THIS) PURE;
    STDMETHOD_(HRESULT,GetBouquetId)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetCountOfTableDescriptors)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetNextTable)(THIS_ IDVB_BAT **ppBAT) PURE;
    STDMETHOD_(HRESULT,GetRecordCountOfDescriptors)(THIS_ DWORD dwRecordIndex,DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordDescriptorByIndex)(THIS_ DWORD dwRecordIndex,DWORD dwIndex,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetRecordDescriptorByTag)(THIS_ DWORD dwRecordIndex,BYTE bTag,DWORD *pdwCookie,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetRecordOriginalNetworkId)(THIS_ DWORD dwRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordTransportStreamId)(THIS_ DWORD dwRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetTableDescriptorByIndex)(THIS_ DWORD dwIndex,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetTableDescriptorByTag)(THIS_ BYTE bTag,DWORD *pdwCookie,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetVersionNumber)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ISectionList *pSectionList,IMpeg2Data *pMPEGData) PURE;
    STDMETHOD_(HRESULT,RegisterForNextTable)(THIS_ HANDLE hNextTableAvailable) PURE;
    STDMETHOD_(HRESULT,RegisterForWhenCurrent)(THIS_ HANDLE hNextTableIsCurrent) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDVB_BAT_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDVB_BAT_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDVB_BAT_Release(This) (This)->lpVtbl->Release(This)
#define IDVB_BAT_ConvertNextToCurrent() (This)->lpVtbl->ConvertNextToCurrent(This)
#define IDVB_BAT_GetBouquetId(This,pwVal) (This)->lpVtbl->GetBouquetId(This,pwVal)
#define IDVB_BAT_GetCountOfRecords(This,pdwVal) (This)->lpVtbl->GetCountOfRecords(This,pdwVal)
#define IDVB_BAT_GetCountOfTableDescriptors(This,pdwVal) (This)->lpVtbl->GetCountOfTableDescriptors(This,pdwVal)
#define IDVB_BAT_GetNextTable(This,ppBAT) (This)->lpVtbl->GetNextTable(This,ppBAT)
#define IDVB_BAT_GetRecordCountOfDescriptors(This,dwRecordIndex,pdwVal) (This)->lpVtbl->GetRecordCountOfDescriptors(This,dwRecordIndex,pdwVal)
#define IDVB_BAT_GetRecordDescriptorByIndex(This,dwRecordIndex,dwIndex,ppDescriptor) (This)->lpVtbl->GetRecordDescriptorByIndex(This,dwRecordIndex,dwIndex,ppDescriptor)
#define IDVB_BAT_GetRecordDescriptorByTag(This,dwRecordIndex,bTag,pdwCookie,ppDescriptor) (This)->lpVtbl->GetRecordDescriptorByTag(This,dwRecordIndex,bTag,pdwCookie,ppDescriptor)
#define IDVB_BAT_GetRecordOriginalNetworkId(This,dwRecordIndex,pwVal) (This)->lpVtbl->GetRecordOriginalNetworkId(This,dwRecordIndex,pwVal)
#define IDVB_BAT_GetRecordTransportStreamId(This,dwRecordIndex,pwVal) (This)->lpVtbl->GetRecordTransportStreamId(This,dwRecordIndex,pwVal)
#define IDVB_BAT_GetTableDescriptorByIndex(This,dwIndex,ppDescriptor) (This)->lpVtbl->GetTableDescriptorByIndex(This,dwIndex,ppDescriptor)
#define IDVB_BAT_GetTableDescriptorByTag(This,bTag,pdwCookie,ppDescriptor) (This)->lpVtbl->GetTableDescriptorByTag(This,bTag,pdwCookie,ppDescriptor)
#define IDVB_BAT_GetVersionNumber(This,pbVal) (This)->lpVtbl->GetVersionNumber(This,pbVal)
#define IDVB_BAT_Initialize(This,pSectionList,pMPEGData) (This)->lpVtbl->Initialize(This,pSectionList,pMPEGData)
#define IDVB_BAT_RegisterForNextTable(This,hNextTableAvailable) (This)->lpVtbl->RegisterForNextTable(This,hNextTableAvailable)
#define IDVB_BAT_RegisterForWhenCurrent(This,hNextTableIsCurrent) (This)->lpVtbl->RegisterForWhenCurrent(This,hNextTableIsCurrent)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDVB_DIT
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDVB_DIT,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDVB_DIT methods */
    STDMETHOD_(HRESULT,GetTransitionFlag)(THIS_ WINBOOL *pfVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ISectionList *pSectionList) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDVB_DIT_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDVB_DIT_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDVB_DIT_Release(This) (This)->lpVtbl->Release(This)
#define IDVB_DIT_GetTransitionFlag(This,pfVal) (This)->lpVtbl->GetTransitionFlag(This,pfVal)
#define IDVB_DIT_Initialize(This,pSectionList) (This)->lpVtbl->Initialize(This,pSectionList)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDVB_NIT
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDVB_NIT,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDVB_NIT methods */
    STDMETHOD_(HRESULT,ConvertNextToCurrent)(THIS) PURE;
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetCountOfTableDescriptors)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetNetworkId)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetNextTable)(THIS_ IDVB_NIT **ppNIT) PURE;
    STDMETHOD_(HRESULT,GetRecordCountOfDescriptors)(THIS_ DWORD dwRecordIndex,DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordDescriptorByIndex)(THIS_ DWORD dwRecordIndex,DWORD dwIndex,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetRecordDescriptorByTag)(THIS_ DWORD dwRecordIndex,BYTE bTag,DWORD *pdwCookie,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetRecordOriginalNetworkId)(THIS_ DWORD dwRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordTransportStreamId)(THIS_ DWORD dwRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetTableDescriptorByIndex)(THIS_ DWORD dwIndex,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetTableDescriptorByTag)(THIS_ BYTE bTag,DWORD *pdwCookie,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetVersionHash)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetVersionNumber)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ISectionList *pSectionList,IMpeg2Data *pMPEGData) PURE;
    STDMETHOD_(HRESULT,RegisterForNextTable)(THIS_ HANDLE hNextTableAvailable) PURE;
    STDMETHOD_(HRESULT,RegisterForWhenCurrent)(THIS_ HANDLE hNextTableIsCurrent) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDVB_NIT_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDVB_NIT_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDVB_NIT_Release(This) (This)->lpVtbl->Release(This)
#define IDVB_NIT_ConvertNextToCurrent() (This)->lpVtbl->ConvertNextToCurrent(This)
#define IDVB_NIT_GetCountOfRecords(This,pdwVal) (This)->lpVtbl->GetCountOfRecords(This,pdwVal)
#define IDVB_NIT_GetCountOfTableDescriptors(This,pdwVal) (This)->lpVtbl->GetCountOfTableDescriptors(This,pdwVal)
#define IDVB_NIT_GetNetworkId(This,pwVal) (This)->lpVtbl->GetNetworkId(This,pwVal)
#define IDVB_NIT_GetNextTable(This,ppNIT) (This)->lpVtbl->GetNextTable(This,ppNIT)
#define IDVB_NIT_GetRecordCountOfDescriptors(This,dwRecordIndex,pdwVal) (This)->lpVtbl->GetRecordCountOfDescriptors(This,dwRecordIndex,pdwVal)
#define IDVB_NIT_GetRecordDescriptorByIndex(This,dwRecordIndex,dwIndex,ppDescriptor) (This)->lpVtbl->GetRecordDescriptorByIndex(This,dwRecordIndex,dwIndex,ppDescriptor)
#define IDVB_NIT_GetRecordDescriptorByTag(This,dwRecordIndex,bTag,pdwCookie,ppDescriptor) (This)->lpVtbl->GetRecordDescriptorByTag(This,dwRecordIndex,bTag,pdwCookie,ppDescriptor)
#define IDVB_NIT_GetRecordOriginalNetworkId(This,dwRecordIndex,pwVal) (This)->lpVtbl->GetRecordOriginalNetworkId(This,dwRecordIndex,pwVal)
#define IDVB_NIT_GetRecordTransportStreamId(This,dwRecordIndex,pwVal) (This)->lpVtbl->GetRecordTransportStreamId(This,dwRecordIndex,pwVal)
#define IDVB_NIT_GetTableDescriptorByIndex(This,dwIndex,ppDescriptor) (This)->lpVtbl->GetTableDescriptorByIndex(This,dwIndex,ppDescriptor)
#define IDVB_NIT_GetTableDescriptorByTag(This,bTag,pdwCookie,ppDescriptor) (This)->lpVtbl->GetTableDescriptorByTag(This,bTag,pdwCookie,ppDescriptor)
#define IDVB_NIT_GetVersionHash(This,pbVal) (This)->lpVtbl->GetVersionHash(This,pbVal)
#define IDVB_NIT_GetVersionNumber(This,pbVal) (This)->lpVtbl->GetVersionNumber(This,pbVal)
#define IDVB_NIT_Initialize(This,pSectionList,pMPEGData) (This)->lpVtbl->Initialize(This,pSectionList,pMPEGData)
#define IDVB_NIT_RegisterForNextTable(This,hNextTableAvailable) (This)->lpVtbl->RegisterForNextTable(This,hNextTableAvailable)
#define IDVB_NIT_RegisterForWhenCurrent(This,hNextTableIsCurrent) (This)->lpVtbl->RegisterForWhenCurrent(This,hNextTableIsCurrent)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IDVB_SDT
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IDVB_SDT,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDVB_SDT methods */
    STDMETHOD_(HRESULT,ConvertNextToCurrent)(THIS) PURE;
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetNextTable)(THIS_ IDVB_SDT **ppSDT) PURE;
    STDMETHOD_(HRESULT,GetOriginalNetworkId)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordCountOfDescriptors)(THIS_ DWORD dwRecordIndex,DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordDescriptorByIndex)(THIS_ DWORD dwRecordIndex,DWORD dwIndex,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetRecordDescriptorByTag)(THIS_ DWORD dwRecordIndex,BYTE bTag,DWORD *pdwCookie,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetRecordEITPresentFollowingFlag)(THIS_ DWORD dwRecordIndex,WINBOOL *pfVal) PURE;
    STDMETHOD_(HRESULT,GetRecordEITScheduleFlag)(THIS_ DWORD dwRecordIndex,WINBOOL *pfVal) PURE;
    STDMETHOD_(HRESULT,GetRecordFreeCAMode)(THIS_ DWORD dwRecordIndex,WINBOOL *pfVal) PURE;
    STDMETHOD_(HRESULT,GetRecordRunningStatus)(THIS_ DWORD dwRecordIndex,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetRecordServiceId)(THIS_ DWORD dwRecordIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetTransportStreamId)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetVersionHash)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetVersionNumber)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ISectionList *pSectionList,IMpeg2Data *pMPEGData) PURE;
    STDMETHOD_(HRESULT,RegisterForNextTable)(THIS_ HANDLE hNextTableAvailable) PURE;
    STDMETHOD_(HRESULT,RegisterForWhenCurrent)(THIS_ HANDLE hNextTableIsCurrent) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IDVB_SDT_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDVB_SDT_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDVB_SDT_Release(This) (This)->lpVtbl->Release(This)
#define IDVB_SDT_ConvertNextToCurrent() (This)->lpVtbl->ConvertNextToCurrent(This)
#define IDVB_SDT_GetCountOfRecords(This,pdwVal) (This)->lpVtbl->GetCountOfRecords(This,pdwVal)
#define IDVB_SDT_GetNextTable(This,ppSDT) (This)->lpVtbl->GetNextTable(This,ppSDT)
#define IDVB_SDT_GetOriginalNetworkId(This,pwVal) (This)->lpVtbl->GetOriginalNetworkId(This,pwVal)
#define IDVB_SDT_GetRecordCountOfDescriptors(This,dwRecordIndex,pdwVal) (This)->lpVtbl->GetRecordCountOfDescriptors(This,dwRecordIndex,pdwVal)
#define IDVB_SDT_GetRecordDescriptorByIndex(This,dwRecordIndex,dwIndex,ppDescriptor) (This)->lpVtbl->GetRecordDescriptorByIndex(This,dwRecordIndex,dwIndex,ppDescriptor)
#define IDVB_SDT_GetRecordDescriptorByTag(This,dwRecordIndex,bTag,pdwCookie,ppDescriptor) (This)->lpVtbl->GetRecordDescriptorByTag(This,dwRecordIndex,bTag,pdwCookie,ppDescriptor)
#define IDVB_SDT_GetRecordEITPresentFollowingFlag(This,dwRecordIndex,pfVal) (This)->lpVtbl->GetRecordEITPresentFollowingFlag(This,dwRecordIndex,pfVal)
#define IDVB_SDT_GetRecordEITScheduleFlag(This,dwRecordIndex,pfVal) (This)->lpVtbl->GetRecordEITScheduleFlag(This,dwRecordIndex,pfVal)
#define IDVB_SDT_GetRecordFreeCAMode(This,dwRecordIndex,pfVal) (This)->lpVtbl->GetRecordFreeCAMode(This,dwRecordIndex,pfVal)
#define IDVB_SDT_GetRecordRunningStatus(This,dwRecordIndex,pbVal) (This)->lpVtbl->GetRecordRunningStatus(This,dwRecordIndex,pbVal)
#define IDVB_SDT_GetRecordServiceId(This,dwRecordIndex,pwVal) (This)->lpVtbl->GetRecordServiceId(This,dwRecordIndex,pwVal)
#define IDVB_SDT_GetTransportStreamId(This,pwVal) (This)->lpVtbl->GetTransportStreamId(This,pwVal)
#define IDVB_SDT_GetVersionHash(This,pbVal) (This)->lpVtbl->GetVersionHash(This,pbVal)
#define IDVB_SDT_GetVersionNumber(This,pbVal) (This)->lpVtbl->GetVersionNumber(This,pbVal)
#define IDVB_SDT_Initialize(This,pSectionList,pMPEGData) (This)->lpVtbl->Initialize(This,pSectionList,pMPEGData)
#define IDVB_SDT_RegisterForNextTable(This,hNextTableAvailable) (This)->lpVtbl->RegisterForNextTable(This,hNextTableAvailable)
#define IDVB_SDT_RegisterForWhenCurrent(This,hNextTableIsCurrent) (This)->lpVtbl->RegisterForWhenCurrent(This,hNextTableIsCurrent)
#endif /*COBJMACROS*/

#endif /*__DVBSIPARSER_H__*/
