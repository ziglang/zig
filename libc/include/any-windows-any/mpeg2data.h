/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __INC_MPEG2DATA__
#define __INC_MPEG2DATA__

#include <objbase.h>

typedef WORD PID;
typedef BYTE TID;

typedef struct _ATSC_FILTER_OPTIONS {
  WINBOOL fSpecifyEtmId;
  DWORD   EtmId;
} ATSC_FILTER_OPTIONS;

#include <mpeg2structs.h>

#ifndef __ISectionList_FWD_DEFINED__
#define __ISectionList_FWD_DEFINED__
typedef struct ISectionList ISectionList;
#endif

#ifndef __IMpeg2Data_FWD_DEFINED__
#define __IMpeg2Data_FWD_DEFINED__
typedef struct IMpeg2Data IMpeg2Data;
#endif

#ifndef __IMpeg2Stream_FWD_DEFINED__
#define __IMpeg2Stream_FWD_DEFINED__
typedef struct IMpeg2Stream IMpeg2Stream;
#endif

#undef  INTERFACE
#define INTERFACE ISectionList
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(ISectionList,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ISectionList methods */
    STDMETHOD_(HRESULT,CancelPendingRequest)(THIS) PURE;
    STDMETHOD_(HRESULT,GetNumberOfSections)(THIS_ WORD *pCount) PURE;
    STDMETHOD_(HRESULT,GetProgramIdentifier)(THIS_ PID *pPid) PURE;
    STDMETHOD_(HRESULT,GetSectionData)(THIS_ WORD sectionNumber,DWORD *pdwRawPacketLength,PSECTION *ppSection) PURE;
    STDMETHOD_(HRESULT,GetTableIdentifier)(THIS_ TID *pTableId) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ MPEG_REQUEST_TYPE requestType,IMpeg2Data *pMpeg2Data,PMPEG_CONTEXT pContext,PID pid,TID tid,PMPEG2_FILTER pFilter,DWORD timeout,HANDLE hDoneEvent) PURE;
    STDMETHOD_(HRESULT,InitializeWithRawSections)(THIS_ PMPEG_PACKET_LIST pmplSections) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define ISectionList_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISectionList_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISectionList_Release(This) (This)->lpVtbl->Release(This)
#define ISectionList_CancelPendingRequest() (This)->lpVtbl->CancelPendingRequest(This)
#define ISectionList_GetNumberOfSections(This,pCount) (This)->lpVtbl->GetNumberOfSections(This,pCount)
#define ISectionList_GetProgramIdentifier(This,pPid) (This)->lpVtbl->GetProgramIdentifier(This,pPid)
#define ISectionList_GetSectionData(This,sectionNumber,pdwRawPacketLength,ppSection) (This)->lpVtbl->GetSectionData(This,sectionNumber,pdwRawPacketLength,ppSection)
#define ISectionList_GetTableIdentifier(This,pTableId) (This)->lpVtbl->GetTableIdentifier(This,pTableId)
#define ISectionList_Initialize(This,requestType,pMpeg2Data,pContext,pid,tid,pFilter,timeout,hDoneEvent) (This)->lpVtbl->Initialize(This,requestType,pMpeg2Data,pContext,pid,tid,pFilter,timeout,hDoneEvent)
#define ISectionList_InitializeWithRawSections(This,pmplSections) (This)->lpVtbl->InitializeWithRawSections(This,pmplSections)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IMpeg2Data
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IMpeg2Data,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IMpeg2Data methods */
    STDMETHOD_(HRESULT,GetSection)(THIS_ PID pid,TID tid,PMPEG2_FILTER pFilter,DWORD dwTimeout,ISectionList **ppSectionList) PURE;
    STDMETHOD_(HRESULT,GetStreamOfSections)(THIS_ PID pid,TID tid,PMPEG2_FILTER pFilter,HANDLE hDataReadyEvent,IMpeg2Stream **ppMpegStream) PURE;
    STDMETHOD_(HRESULT,GetTable)(THIS_ PID pid,TID tid,PMPEG2_FILTER pFilter,DWORD dwTimeout,ISectionList **ppSectionList) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IMpeg2Data_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMpeg2Data_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMpeg2Data_Release(This) (This)->lpVtbl->Release(This)
#define IMpeg2Data_GetSection(This,pid,tid,pFilter,dwTimeout,ppSectionList) (This)->lpVtbl->GetSection(This,pid,tid,pFilter,dwTimeout,ppSectionList)
#define IMpeg2Data_GetStreamOfSections(This,pid,tid,pFilter,hDataReadyEvent,ppMpegStream) (This)->lpVtbl->GetStreamOfSections(This,pid,tid,pFilter,hDataReadyEvent,ppMpegStream)
#define IMpeg2Data_GetTable(This,pid,tid,pFilter,dwTimeout,ppSectionList) (This)->lpVtbl->GetTable(This,pid,tid,pFilter,dwTimeout,ppSectionList)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IMpeg2Stream
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IMpeg2Stream,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IMpeg2Stream methods */
    STDMETHOD_(HRESULT,Initialize)(THIS_ MPEG_REQUEST_TYPE requestType,IMpeg2Data *pMpeg2Data,PMPEG_CONTEXT pContext,PID pid,TID tid,PMPEG2_FILTER pFilter,HANDLE hDataReadyEvent) PURE;
    STDMETHOD_(HRESULT,SupplyDataBuffer)(THIS_ PMPEG_STREAM_BUFFER pStreamBuffer) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IMpeg2Stream_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMpeg2Stream_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMpeg2Stream_Release(This) (This)->lpVtbl->Release(This)
#define IMpeg2Stream_Initialize(This,requestType,pMpeg2Data,pContext,pid,tid,pFilter,hDataReadyEvent) (This)->lpVtbl->Initialize(This,requestType,pMpeg2Data,pContext,pid,tid,pFilter,hDataReadyEvent)
#define IMpeg2Stream_SupplyDataBuffer(This,pStreamBuffer) (This)->lpVtbl->SupplyDataBuffer(This,pStreamBuffer)
#endif /*COBJMACROS*/

#endif /*__INC_MPEG2DATA__*/
