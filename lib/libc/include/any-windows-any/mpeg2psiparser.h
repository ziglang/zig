/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <mpeg2data.h>

#ifndef __MPEG2PSIPARSER_H__
#define __MPEG2PSIPARSER_H__

#ifndef __IPAT_FWD_DEFINED__
#define __IPAT_FWD_DEFINED__
typedef struct IPAT IPAT;
#endif

#ifndef __IPSITables_FWD_DEFINED__
#define __IPSITables_FWD_DEFINED__
typedef struct IPSITables  IPSITables ;
#endif

#ifndef __IPMT_FWD_DEFINED__
#define __IPMT_FWD_DEFINED__
typedef struct IPMT IPMT;
#endif

#ifndef __IGenericDescriptor_FWD_DEFINED__
#define __IGenericDescriptor_FWD_DEFINED__
typedef struct IGenericDescriptor IGenericDescriptor;
#endif

#ifndef __ITSDT_FWD_DEFINED__
#define __ITSDT_FWD_DEFINED__
typedef struct ITSDT ITSDT;
#endif

#ifndef __ICAT_FWD_DEFINED__
#define __ICAT_FWD_DEFINED__
typedef struct ICAT ICAT;
#endif

#undef  INTERFACE
#define INTERFACE IPAT
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IPAT,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IPAT methods */
    STDMETHOD_(HRESULT,ConvertNextToCurrent)(THIS) PURE;
    STDMETHOD_(HRESULT,FindRecordProgramMapPid)(THIS_ WORD wProgramNumber,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetNextTable)(THIS_ IPAT **ppPAT) PURE;
    STDMETHOD_(HRESULT,GetRecordProgramMapPid)(THIS_ DWORD dwIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordProgramNumber)(THIS_ DWORD dwIndex,WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetTransportStreamId)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetVersionNumber)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ISectionList *pSectionList,IMpeg2Data *pMPEGData) PURE;
    STDMETHOD_(HRESULT,RegisterForNextTable)(THIS_ HANDLE hNextTableAvailable) PURE;
    STDMETHOD_(HRESULT,RegisterForWhenCurrent)(THIS_ HANDLE hNextTableIsCurrent) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IPAT_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IPAT_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IPAT_Release(This) (This)->lpVtbl->Release(This)
#define IPAT_ConvertNextToCurrent() (This)->lpVtbl->ConvertNextToCurrent(This)
#define IPAT_FindRecordProgramMapPid(This,wProgramNumber,pwVal) (This)->lpVtbl->FindRecordProgramMapPid(This,wProgramNumber,pwVal)
#define IPAT_GetCountOfRecords(This,pdwVal) (This)->lpVtbl->GetCountOfRecords(This,pdwVal)
#define IPAT_GetNextTable(This,ppPAT) (This)->lpVtbl->GetNextTable(This,ppPAT)
#define IPAT_GetRecordProgramMapPid(This,dwIndex,pwVal) (This)->lpVtbl->GetRecordProgramMapPid(This,dwIndex,pwVal)
#define IPAT_GetRecordProgramNumber(This,dwIndex,pwVal) (This)->lpVtbl->GetRecordProgramNumber(This,dwIndex,pwVal)
#define IPAT_GetTransportStreamId(This,pwVal) (This)->lpVtbl->GetTransportStreamId(This,pwVal)
#define IPAT_GetVersionNumber(This,pbVal) (This)->lpVtbl->GetVersionNumber(This,pbVal)
#define IPAT_Initialize(This,pSectionList,pMPEGData) (This)->lpVtbl->Initialize(This,pSectionList,pMPEGData)
#define IPAT_RegisterForNextTable(This,hNextTableAvailable) (This)->lpVtbl->RegisterForNextTable(This,hNextTableAvailable)
#define IPAT_RegisterForWhenCurrent(This,hNextTableIsCurrent) (This)->lpVtbl->RegisterForWhenCurrent(This,hNextTableIsCurrent)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IPSITables
DECLARE_INTERFACE_(IPSITables,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IPSITables methods */
    STDMETHOD_(HRESULT,GetTable)(THIS_ DWORD dwTSID,DWORD dwTID_PID,DWORD dwHashedVer,DWORD dwPara4,IUnknown **ppIUnknown) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IPSITables_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IPSITables_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IPSITables_Release(This) (This)->lpVtbl->Release(This)
#define IPSITables_GetTable(This,dwTSID,dwTID_PID,dwHashedVer,dwPara4,ppIUnknown) (This)->lpVtbl->GetTable(This,dwTSID,dwTID_PID,dwHashedVer,dwPara4,ppIUnknown)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IPMT
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IPMT,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IPMT methods */
    STDMETHOD_(HRESULT,ConvertNextToCurrent)(THIS) PURE;
    STDMETHOD_(HRESULT,GetCountOfRecords)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetCountOfTableDescriptors)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetNextTable)(THIS_ IPMT **ppPMT) PURE;
    STDMETHOD_(HRESULT,GetPcrPid)(THIS_ PID *pPidVal) PURE;
    STDMETHOD_(HRESULT,GetProgramNumber)(THIS_ WORD *pwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordCountOfDescriptors)(THIS_ DWORD dwRecordIndex,DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetRecordDescriptorByIndex)(THIS_ DWORD dwRecordIndex,DWORD dwDescIndex,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetRecordDescriptorByTag)(THIS_ DWORD dwRecordIndex,BYTE bTag,DWORD *pdwCookie,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetRecordElementaryPid)(THIS_ DWORD dwRecordIndex,PID *pPidVal) PURE;
    STDMETHOD_(HRESULT,GetRecordStreamType)(THIS_ DWORD dwRecordIndex,BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTableDescriptorByIndex)(THIS_ DWORD dwIndex,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetTableDescriptorByTag)(THIS_ BYTE bTag,DWORD *pdwCookie,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetVersionNumber)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ISectionList *pSectionList,IMpeg2Data *pMPEGData) PURE;
    STDMETHOD_(HRESULT,QueryMPEInfo)(THIS_ MPE_ELEMENT **ppMPEList,UINT *puiCount) PURE;
    STDMETHOD_(HRESULT,QueryServiceGatewayInfo)(THIS_ DSMCC_ELEMENT **ppDSMCCList,UINT *puiCount) PURE;
    STDMETHOD_(HRESULT,RegisterForNextTable)(THIS_ HANDLE hNextTableAvailable) PURE;
    STDMETHOD_(HRESULT,RegisterForWhenCurrent)(THIS_ HANDLE hNextTableIsCurrent) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IPMT_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IPMT_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IPMT_Release(This) (This)->lpVtbl->Release(This)
#define IPMT_ConvertNextToCurrent() (This)->lpVtbl->ConvertNextToCurrent(This)
#define IPMT_GetCountOfRecords(This,pwVal) (This)->lpVtbl->GetCountOfRecords(This,pwVal)
#define IPMT_GetCountOfTableDescriptors(This,pdwVal) (This)->lpVtbl->GetCountOfTableDescriptors(This,pdwVal)
#define IPMT_GetNextTable(This,ppPMT) (This)->lpVtbl->GetNextTable(This,ppPMT)
#define IPMT_GetPcrPid(This,pPidVal) (This)->lpVtbl->GetPcrPid(This,pPidVal)
#define IPMT_GetProgramNumber(This,pwVal) (This)->lpVtbl->GetProgramNumber(This,pwVal)
#define IPMT_GetRecordCountOfDescriptors(This,dwRecordIndex,pdwVal) (This)->lpVtbl->GetRecordCountOfDescriptors(This,dwRecordIndex,pdwVal)
#define IPMT_GetRecordDescriptorByIndex(This,dwRecordIndex,dwDescIndex,ppDescriptor) (This)->lpVtbl->GetRecordDescriptorByIndex(This,dwRecordIndex,dwDescIndex,ppDescriptor)
#define IPMT_GetRecordDescriptorByTag(This,dwRecordIndex,bTag,pdwCookie,ppDescriptor) (This)->lpVtbl->GetRecordDescriptorByTag(This,dwRecordIndex,bTag,pdwCookie,ppDescriptor)
#define IPMT_GetRecordElementaryPid(This,dwRecordIndex,pPidVal) (This)->lpVtbl->GetRecordElementaryPid(This,dwRecordIndex,pPidVal)
#define IPMT_GetRecordStreamType(This,dwRecordIndex,pbVal) (This)->lpVtbl->GetRecordStreamType(This,dwRecordIndex,pbVal)
#define IPMT_GetTableDescriptorByIndex(This,dwIndex,ppDescriptor) (This)->lpVtbl->GetTableDescriptorByIndex(This,dwIndex,ppDescriptor)
#define IPMT_GetTableDescriptorByTag(This,bTag,pdwCookie,ppDescriptor) (This)->lpVtbl->GetTableDescriptorByTag(This,bTag,pdwCookie,ppDescriptor)
#define IPMT_GetVersionNumber(This,pbVal) (This)->lpVtbl->GetVersionNumber(This,pbVal)
#define IPMT_Initialize(This,pSectionList,pMPEGData) (This)->lpVtbl->Initialize(This,pSectionList,pMPEGData)
#define IPMT_QueryMPEInfo(This,ppMPEList,puiCount) (This)->lpVtbl->QueryMPEInfo(This,ppMPEList,puiCount)
#define IPMT_QueryServiceGatewayInfo(This,ppDSMCCList,puiCount) (This)->lpVtbl->QueryServiceGatewayInfo(This,ppDSMCCList,puiCount)
#define IPMT_RegisterForNextTable(This,hNextTableAvailable) (This)->lpVtbl->RegisterForNextTable(This,hNextTableAvailable)
#define IPMT_RegisterForWhenCurrent(This,hNextTableIsCurrent) (This)->lpVtbl->RegisterForWhenCurrent(This,hNextTableIsCurrent)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IGenericDescriptor
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IGenericDescriptor,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IGenericDescriptor methods */
    STDMETHOD_(HRESULT,GetBody)(THIS_ BYTE **ppbVal) PURE;
    STDMETHOD_(HRESULT,GetLength)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,GetTag)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ BYTE *pbDesc,BYTE bCount) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IGenericDescriptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IGenericDescriptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IGenericDescriptor_Release(This) (This)->lpVtbl->Release(This)
#define IGenericDescriptor_GetBody(This,ppbVal) (This)->lpVtbl->GetBody(This,ppbVal)
#define IGenericDescriptor_GetLength(This,pbVal) (This)->lpVtbl->GetLength(This,pbVal)
#define IGenericDescriptor_GetTag(This,pbVal) (This)->lpVtbl->GetTag(This,pbVal)
#define IGenericDescriptor_Initialize(This,pbDesc,bCount) (This)->lpVtbl->Initialize(This,pbDesc,bCount)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE ITSDT
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(ITSDT,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ITSDT methods */
    STDMETHOD_(HRESULT,ConvertNextToCurrent)(THIS) PURE;
    STDMETHOD_(HRESULT,GetCountOfTableDescriptors)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetNextTable)(THIS_ ITSDT **ppTSDT) PURE;
    STDMETHOD_(HRESULT,GetTableDescriptorByIndex)(THIS_ DWORD dwIndex,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetTableDescriptorByTag)(THIS_ BYTE bTag,DWORD *pdwCookie,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetVersionNumber)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ISectionList *pSectionList,IMpeg2Data *pMPEGData) PURE;
    STDMETHOD_(HRESULT,RegisterForNextTable)(THIS_ HANDLE hNextTableAvailable) PURE;
    STDMETHOD_(HRESULT,RegisterForWhenCurrent)(THIS_ HANDLE hNextTableIsCurrent) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define ITSDT_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITSDT_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITSDT_Release(This) (This)->lpVtbl->Release(This)
#define ITSDT_ConvertNextToCurrent() (This)->lpVtbl->ConvertNextToCurrent(This)
#define ITSDT_GetCountOfTableDescriptors(This,pdwVal) (This)->lpVtbl->GetCountOfTableDescriptors(This,pdwVal)
#define ITSDT_GetNextTable(This,ppTSDT) (This)->lpVtbl->GetNextTable(This,ppTSDT)
#define ITSDT_GetTableDescriptorByIndex(This,dwIndex,ppDescriptor) (This)->lpVtbl->GetTableDescriptorByIndex(This,dwIndex,ppDescriptor)
#define ITSDT_GetTableDescriptorByTag(This,bTag,pdwCookie,ppDescriptor) (This)->lpVtbl->GetTableDescriptorByTag(This,bTag,pdwCookie,ppDescriptor)
#define ITSDT_GetVersionNumber(This,pbVal) (This)->lpVtbl->GetVersionNumber(This,pbVal)
#define ITSDT_Initialize(This,pSectionList,pMPEGData) (This)->lpVtbl->Initialize(This,pSectionList,pMPEGData)
#define ITSDT_RegisterForNextTable(This,hNextTableAvailable) (This)->lpVtbl->RegisterForNextTable(This,hNextTableAvailable)
#define ITSDT_RegisterForWhenCurrent(This,hNextTableIsCurrent) (This)->lpVtbl->RegisterForWhenCurrent(This,hNextTableIsCurrent)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE ICAT
DECLARE_INTERFACE_(ICAT,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ICAT methods */
    STDMETHOD_(HRESULT,ConvertNextToCurrent)(THIS) PURE;
    STDMETHOD_(HRESULT,GetCountOfTableDescriptors)(THIS_ DWORD *pdwVal) PURE;
    STDMETHOD_(HRESULT,GetNextTable)(THIS_ DWORD dwTimeout,ICAT **ppCAT) PURE;
    STDMETHOD_(HRESULT,GetTableDescriptorByIndex)(THIS_ DWORD dwIndex,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetTableDescriptorByTag)(THIS_ BYTE bTag,DWORD *pdwCookie,IGenericDescriptor **ppDescriptor) PURE;
    STDMETHOD_(HRESULT,GetVersionNumber)(THIS_ BYTE *pbVal) PURE;
    STDMETHOD_(HRESULT,Initialize)(THIS_ ISectionList *pSectionList,IMpeg2Data *pMPEGData) PURE;
    STDMETHOD_(HRESULT,RegisterForNextTable)(THIS_ HANDLE hNextTableAvailable) PURE;
    STDMETHOD_(HRESULT,RegisterForWhenCurrent)(THIS_ HANDLE hNextTableIsCurrent) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define ICAT_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICAT_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICAT_Release(This) (This)->lpVtbl->Release(This)
#define ICAT_ConvertNextToCurrent() (This)->lpVtbl->ConvertNextToCurrent(This)
#define ICAT_GetCountOfTableDescriptors(This,pdwVal) (This)->lpVtbl->GetCountOfTableDescriptors(This,pdwVal)
#define ICAT_GetNextTable(This,dwTimeout,ppCAT) (This)->lpVtbl->GetNextTable(This,dwTimeout,ppCAT)
#define ICAT_GetTableDescriptorByIndex(This,dwIndex,ppDescriptor) (This)->lpVtbl->GetTableDescriptorByIndex(This,dwIndex,ppDescriptor)
#define ICAT_GetTableDescriptorByTag(This,bTag,pdwCookie,ppDescriptor) (This)->lpVtbl->GetTableDescriptorByTag(This,bTag,pdwCookie,ppDescriptor)
#define ICAT_GetVersionNumber(This,pbVal) (This)->lpVtbl->GetVersionNumber(This,pbVal)
#define ICAT_Initialize(This,pSectionList,pMPEGData) (This)->lpVtbl->Initialize(This,pSectionList,pMPEGData)
#define ICAT_RegisterForNextTable(This,hNextTableAvailable) (This)->lpVtbl->RegisterForNextTable(This,hNextTableAvailable)
#define ICAT_RegisterForWhenCurrent(This,hNextTableIsCurrent) (This)->lpVtbl->RegisterForWhenCurrent(This,hNextTableIsCurrent)
#endif /*COBJMACROS*/

#endif /*__MPEG2PSIPARSER_H__*/
