/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_MSRDC
#define _INC_MSRDC

#if (_WIN32_WINNT >= 0x0600)

typedef UINT SimilarityFileIndexT;

typedef enum _GeneratorParametersType {
  RDCGENTYPE_Unused      = 0,
  RDCGENTYPE_FilterMax   = 1 
} GeneratorParametersType;

typedef enum _RdcCreatedTables {
  RDCTABLE_InvalidOrUnknown   = 0,
  RDCTABLE_Existing           = 1,
  RDCTABLE_New                = 2 
} RdcCreatedTables;

typedef enum _RdcMappingAccessMode {
  RDCMAPPING_Undefined   = 0,
  RDCMAPPING_ReadOnly    = 1,
  RDCMAPPING_ReadWrite   = 2 
} RdcMappingAccessMode;

typedef enum _RDC_ErrorCode {
  RDC_NoError                  = 0,
  RDC_HeaderVersionNewer       = 1,
  RDC_HeaderVersionOlder       = 2,
  RDC_HeaderMissingOrCorrupt   = 3,
  RDC_HeaderWrongType          = 4,
  RDC_DataMissingOrCorrupt     = 5,
  RDC_DataTooManyRecords       = 6,
  RDC_FileChecksumMismatch     = 7,
  RDC_ApplicationError         = 8,
  RDC_Aborted                  = 9,
  RDC_Win32Error               = 10 
} RDC_ErrorCode;

typedef enum _RdcNeedType {
  RDCNEED_SOURCE     = 0,
  RDCNEED_TARGET     = 1,
  RDCNEED_SEED       = 2,
  RDCNEED_SEED_MAX   = 255 
} RdcNeedType;

typedef struct _FindSimilarFileIndexResults {
  SimilarityFileIndexT m_FileIndex;
  unsigned             m_MatchCount;
} FindSimilarFileIndexResults;

typedef struct _RdcBufferPointer {
  ULONG m_Size;
  ULONG m_Used;
  BYTE  *m_Data;
} RdcBufferPointer;

typedef struct _RdcNeed {
  RdcNeedType      m_BlockType;
  unsigned __int64 m_FileOffset;
  unsigned __int64 m_BlockLength;
} RdcNeed;

typedef struct _RdcNeedPointer {
  ULONG   m_Size;
  ULONG   m_Used;
  RdcNeed *m_Data;
} RdcNeedPointer;

typedef struct _RdcSignature {
  BYTE   m_Signature[MSRDC_SIGNATURE_HASHSIZE];
  USHORT m_BlockLength;
} RdcSignature;

typedef struct _RdcSignaturePointer {
  ULONG        m_Size;
  ULONG        m_Used;
  RdcSignature *m_Data;
} RdcSignaturePointer;

typedef struct _SimilarityData {
  unsigned char m_Data[16];
} SimilarityData;

typedef struct _SimilarityDumpData {
  SimilarityFileIndexT m_FileIndex;
  SimilarityData       m_Data;
} SimilarityDumpData;

typedef struct _SimilarityFileId {
  byte m_FileId[SimilarityFileIdMaxSize];
} SimilarityFileId;

struct SimilarityMappedViewInfo {
  unsigned char *m_Data;
  DWORD         m_Length;
};

#undef  INTERFACE
#define INTERFACE IRdcFileWriter
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IRdcFileWriter,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IRdcFileWriter methods */
    STDMETHOD_(HRESULT,Write)(THIS_ ULONGLONG offsetFileStart,ULONG bytesToWrite,BYTE *buffer) PURE;
    STDMETHOD_(HRESULT,Truncate)(THIS) PURE;
    STDMETHOD_(HRESULT,DeleteOnClose)(THIS) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IRdcFileWriter_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRdcFileWriter_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRdcFileWriter_Release(This) (This)->lpVtbl->Release(This)
#define IRdcFileWriter_Write(This,offsetFileStart,bytesToWrite,buffer) (This)->lpVtbl->Write(This,offsetFileStart,bytesToWrite,buffer)
#define IRdcFileWriter_Truncate() (This)->lpVtbl->Truncate(This)
#define IRdcFileWriter_DeleteOnClose() (This)->lpVtbl->DeleteOnClose(This)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE ISimilarityFileIdTable
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(ISimilarityFileIdTable,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ISimilarityFileIdTable methods */
    STDMETHOD_(HRESULT,CreateTable)(THIS_ wchar_t *path,WINBOOL truncate,BYTE *securityDescriptor,DWORD recordSize,RdcCreatedTables *isNew) PURE;
    STDMETHOD_(HRESULT,CreateTableIndirect)(THIS_ IRdcFileWriter *fileIdFile,WINBOOL truncate,DWORD recordSize,RdcCreatedTables *isNew) PURE;
    STDMETHOD_(HRESULT,CloseTable)(THIS_ WINBOOL isValid) PURE;
    STDMETHOD_(HRESULT,Append)(THIS_ SimilarityFileId *similarityFileId,SimilarityFileIndexT *similarityFileIndex) PURE;
    STDMETHOD_(HRESULT,Lookup)(THIS_ SimilarityFileIndexT similarityFileIndex,SimilarityFileId *similarityFileId) PURE;
    STDMETHOD_(HRESULT,Invalidate)(THIS_ SimilarityFileIndexT similarityFileIndex) PURE;
    STDMETHOD_(HRESULT,GetRecordCount)(THIS_ DWORD *recordCount) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define ISimilarityFileIdTable_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISimilarityFileIdTable_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISimilarityFileIdTable_Release(This) (This)->lpVtbl->Release(This)
#define ISimilarityFileIdTable_CreateTable(This,path,truncate,securityDescriptor,recordSize,isNew) (This)->lpVtbl->CreateTable(This,path,truncate,securityDescriptor,recordSize,isNew)
#define ISimilarityFileIdTable_CreateTableIndirect(This,fileIdFile,truncate,recordSize,isNew) (This)->lpVtbl->CreateTableIndirect(This,fileIdFile,truncate,recordSize,isNew)
#define ISimilarityFileIdTable_CloseTable(This,isValid) (This)->lpVtbl->CloseTable(This,isValid)
#define ISimilarityFileIdTable_Append(This,similarityFileId,similarityFileIndex) (This)->lpVtbl->Append(This,similarityFileId,similarityFileIndex)
#define ISimilarityFileIdTable_Lookup(This,similarityFileIndex,similarityFileId) (This)->lpVtbl->Lookup(This,similarityFileIndex,similarityFileId)
#define ISimilarityFileIdTable_Invalidate(This,similarityFileIndex) (This)->lpVtbl->Invalidate(This,similarityFileIndex)
#define ISimilarityFileIdTable_GetRecordCount(This,recordCount) (This)->lpVtbl->GetRecordCount(This,recordCount)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE ISimilarityTraitsMappedView
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(ISimilarityTraitsMappedView,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ISimilarityTraitsMappedView methods */
    STDMETHOD_(HRESULT,Flush)(THIS) PURE;
    STDMETHOD_(HRESULT,Unmap)(THIS) PURE;
    STDMETHOD_(HRESULT,Get)(THIS_ unsigned __int64 fileOffset,WINBOOL dirty,DWORD numElements,SimilarityMappedViewInfo *viewInfo) PURE;
    STDMETHOD(GetView)(THIS_ unsigned char const **mappedPageBegin,unsigned char const **mappedPageEnd) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define ISimilarityTraitsMappedView_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISimilarityTraitsMappedView_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISimilarityTraitsMappedView_Release(This) (This)->lpVtbl->Release(This)
#define ISimilarityTraitsMappedView_Flush() (This)->lpVtbl->Flush(This)
#define ISimilarityTraitsMappedView_Unmap() (This)->lpVtbl->Unmap(This)
#define ISimilarityTraitsMappedView_Get(This,fileOffset,dirty,numElements,viewInfo) (This)->lpVtbl->Get(This,fileOffset,dirty,numElements,viewInfo)
#define ISimilarityTraitsMappedView_GetView(This,mappedPageBegin,mappedPageEnd) (This)->lpVtbl->GetView(This,mappedPageBegin,mappedPageEnd)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IFindSimilarResults
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IFindSimilarResults,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IFindSimilarResults methods */
    STDMETHOD_(HRESULT,GetSize)(THIS_ DWORD *size) PURE;
    STDMETHOD_(HRESULT,GetNextFileId)(THIS_ DWORD *numTraitsMatched,SimilarityFileId *similarityFileId) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IFindSimilarResults_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IFindSimilarResults_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IFindSimilarResults_Release(This) (This)->lpVtbl->Release(This)
#define IFindSimilarResults_GetSize(This,size) (This)->lpVtbl->GetSize(This,size)
#define IFindSimilarResults_GetNextFileId(This,numTraitsMatched,similarityFileId) (This)->lpVtbl->GetNextFileId(This,numTraitsMatched,similarityFileId)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE ISimilarityTraitsMapping
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(ISimilarityTraitsMapping,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ISimilarityTraitsMapping methods */
    STDMETHOD(CloseMapping)(THIS) PURE;
    STDMETHOD_(HRESULT,SetFileSize)(THIS_ unsigned __int64 *fileSize) PURE;
    STDMETHOD_(HRESULT,GetFileSize)(THIS_ unsigned __int64 *fileSize) PURE;
    STDMETHOD_(HRESULT,OpenMapping)(THIS_ RdcMappingAccessMode accessMode,unsigned __int64 begin,unsigned __int64 end,unsigned __int64 *actualEnd) PURE;
    STDMETHOD_(HRESULT,ResizeMapping)(THIS_ RdcMappingAccessMode accessMode,unsigned __int64 begin,unsigned __int64 end,unsigned __int64 *actualEnd) PURE;
    STDMETHOD(GetPageSize)(THIS_ DWORD *pageSize) PURE;
    STDMETHOD_(HRESULT,CreateView)(THIS_ DWORD minimumMappedPages,RdcMappingAccessMode accessMode,ISimilarityTraitsMappedView **mappedView) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define ISimilarityTraitsMapping_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISimilarityTraitsMapping_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISimilarityTraitsMapping_Release(This) (This)->lpVtbl->Release(This)
#define ISimilarityTraitsMapping_CloseMapping() (This)->lpVtbl->CloseMapping(This)
#define ISimilarityTraitsMapping_SetFileSize(This,fileSize) (This)->lpVtbl->SetFileSize(This,fileSize)
#define ISimilarityTraitsMapping_GetFileSize(This,fileSize) (This)->lpVtbl->GetFileSize(This,fileSize)
#define ISimilarityTraitsMapping_OpenMapping(This,accessMode,begin,end,actualEnd) (This)->lpVtbl->OpenMapping(This,accessMode,begin,end,actualEnd)
#define ISimilarityTraitsMapping_ResizeMapping(This,accessMode,begin,end,actualEnd) (This)->lpVtbl->ResizeMapping(This,accessMode,begin,end,actualEnd)
#define ISimilarityTraitsMapping_GetPageSize(This,pageSize) (This)->lpVtbl->GetPageSize(This,pageSize)
#define ISimilarityTraitsMapping_CreateView(This,minimumMappedPages,accessMode,mappedView) (This)->lpVtbl->CreateView(This,minimumMappedPages,accessMode,mappedView)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE ISimilarityReportProgress
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(ISimilarityReportProgress,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ISimilarityReportProgress methods */
    STDMETHOD_(HRESULT,ReportProgress)(THIS_ DWORD percentCompleted) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define ISimilarityReportProgress_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISimilarityReportProgress_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISimilarityReportProgress_Release(This) (This)->lpVtbl->Release(This)
#define ISimilarityReportProgress_ReportProgress(This,percentCompleted) (This)->lpVtbl->ReportProgress(This,percentCompleted)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE ISimilarity
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(ISimilarity,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ISimilarity methods */
    STDMETHOD_(HRESULT,CreateTable)(THIS_ wchar_t *path,WINBOOL truncate,BYTE *securityDescriptor,DWORD recordSize,RdcCreatedTables *isNew) PURE;
    STDMETHOD_(HRESULT,CreateTableIndirect)(THIS_ ISimilarityTraitsMapping *mapping,IRdcFileWriter *fileIdFile,WINBOOL truncate,DWORD recordSize,RdcCreatedTables *isNew) PURE;
    STDMETHOD_(HRESULT,CloseTable)(THIS_ WINBOOL isValid) PURE;
    STDMETHOD_(HRESULT,Append)(THIS_ SimilarityFileId *similarityFileId,SimilarityData *similarityData) PURE;
    STDMETHOD_(HRESULT,FindSimilarFileId)(THIS_ SimilarityData *similarityData,DWORD resultsSize,IFindSimilarResults **findSimilarResults) PURE;
    STDMETHOD_(HRESULT,CopyAndSwap)(THIS_ ISimilarityReportProgress *reportProgress) PURE;
    STDMETHOD_(HRESULT,GetRecordCount)(THIS_ DWORD *recordCount) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define ISimilarity_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISimilarity_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISimilarity_Release(This) (This)->lpVtbl->Release(This)
#define ISimilarity_CreateTable(This,path,truncate,securityDescriptor,recordSize,isNew) (This)->lpVtbl->CreateTable(This,path,truncate,securityDescriptor,recordSize,isNew)
#define ISimilarity_CreateTableIndirect(This,mapping,fileIdFile,truncate,recordSize,isNew) (This)->lpVtbl->CreateTableIndirect(This,mapping,fileIdFile,truncate,recordSize,isNew)
#define ISimilarity_CloseTable(This,isValid) (This)->lpVtbl->CloseTable(This,isValid)
#define ISimilarity_Append(This,similarityFileId,similarityData) (This)->lpVtbl->Append(This,similarityFileId,similarityData)
#define ISimilarity_FindSimilarFileId(This,similarityData,resultsSize,findSimilarResults) (This)->lpVtbl->FindSimilarFileId(This,similarityData,resultsSize,findSimilarResults)
#define ISimilarity_CopyAndSwap(This,reportProgress) (This)->lpVtbl->CopyAndSwap(This,reportProgress)
#define ISimilarity_GetRecordCount(This,recordCount) (This)->lpVtbl->GetRecordCount(This,recordCount)
#endif /*COBJMACROS*/

#endif /*(_WIN32_WINNT >= 0x0600)*/

#endif /* _INC_MSRDC */

