#ifndef __alink_h__
#define __alink_h__

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

typedef enum _AssemblyOptions {
  optAssemTitle = 0,
  optAssemDescription,
  optAssemConfig,
  optAssemOS,
  optAssemProcessor,
  optAssemLocale,
  optAssemVersion,
  optAssemCompany,
  optAssemProduct,
  optAssemProductVersion,
  optAssemCopyright,
  optAssemTrademark,
  optAssemKeyFile,
  optAssemKeyName,
  optAssemAlgID,
  optAssemFlags,
  optAssemHalfSign,
  optAssemFileVersion,
  optAssemSatelliteVer,
  optAssemSignaturePublicKey,
  optLastAssemOption
} AssemblyOptions;

typedef enum _AssemblyFlags {
  afNone = 0x00000000,
  afInMemory = 0x00000001,
  afCleanModules = 0x00000002,
  afNoRefHash = 0x00000004,
  afNoDupTypeCheck = 0x00000008,
  afDupeCheckTypeFwds = 0x00000010,
} AssemblyFlags;

EXTERN_GUID (CLSID_AssemblyLinker, 0xf7e02368, 0xa7f4, 0x471f, 0x8c, 0x5e, 0x98, 0x39, 0xed, 0x57, 0xcb, 0x5e);

EXTERN_GUID (IID_IALink, 0xc8e77f39, 0x3604, 0x4fd4, 0x85, 0xcf, 0x38, 0xbd, 0xeb, 0x23, 0x3a, 0xd4);
EXTERN_GUID (IID_IALink2, 0xc8e77f39, 0x3604, 0x4fd4, 0x85, 0xcf, 0x38, 0xbd, 0xeb, 0x23, 0x3a, 0xd5);
EXTERN_GUID (IID_IALink3, 0x22d4f7a0, 0x65, 0x43dd, 0x8e, 0xaf, 0xb9, 0xfb, 0x90, 0x1d, 0x82, 0x23);

#define AssemblyIsUBM ((mdAssembly) mdAssemblyNil)
#define MAX_IDENT_LEN 2048

#ifndef HALINKENUM
#define HALINKENUM void *
#endif

#undef INTERFACE
#define INTERFACE IALink

DECLARE_INTERFACE_ (IALink, IUnknown) {
  BEGIN_INTERFACE
#ifndef __cplusplus
   /* IUnknown methods */
   STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
   STDMETHOD_(ULONG, AddRef)(THIS) PURE;
   STDMETHOD_(ULONG, Release)(THIS) PURE;
#endif  
  STDMETHOD (Init) (IMetaDataDispenserEx *pDispenser, IMetaDataError *pErrorHandler) PURE;
  STDMETHOD (ImportFile) (LPCWSTR pszFilename, LPCWSTR pszTargetName, WINBOOL fSmartImport, mdToken *pImportToken, IMetaDataAssemblyImport **ppAssemblyScope, DWORD *pdwCountOfScopes) PURE;
  STDMETHOD (SetAssemblyFile) (LPCWSTR pszFilename, IMetaDataEmit *pEmitter, AssemblyFlags afFlags, mdAssembly *pAssemblyID) PURE;
  STDMETHOD (AddFile) (mdAssembly AssemblyID, LPCWSTR pszFilename, DWORD dwFlags, IMetaDataEmit *pEmitter, mdFile *pFileToken) PURE;
  STDMETHOD (AddImport) (mdAssembly AssemblyID, mdToken ImportToken, DWORD dwFlags, mdFile *pFileToken) PURE;
  STDMETHOD (GetScope) (mdAssembly AssemblyID, mdToken FileToken, DWORD dwScope, IMetaDataImport **ppImportScope) PURE;
  STDMETHOD (GetAssemblyRefHash) (mdToken FileToken, const void **ppvHash, DWORD *pcbHash) PURE;
  STDMETHOD (ImportTypes) (mdAssembly AssemblyID, mdToken FileToken, DWORD dwScope, HALINKENUM *phEnum, IMetaDataImport **ppImportScope, DWORD *pdwCountOfTypes) PURE;
  STDMETHOD (EnumCustomAttributes) (HALINKENUM hEnum, mdToken tkType, mdCustomAttribute rCustomValues[], ULONG cMax, ULONG *pcCustomValues) PURE;
  STDMETHOD (EnumImportTypes) (HALINKENUM hEnum, DWORD dwMax, mdTypeDef aTypeDefs[], DWORD *pdwCount) PURE;
  STDMETHOD (CloseEnum) (HALINKENUM hEnum) PURE;
  STDMETHOD (ExportType) (mdAssembly AssemblyID, mdToken FileToken, mdTypeDef TypeToken, LPCWSTR pszTypename, DWORD dwFlags, mdExportedType *pType) PURE;
  STDMETHOD (ExportNestedType) (mdAssembly AssemblyID, mdToken FileToken, mdTypeDef TypeToken, mdExportedType ParentType, LPCWSTR pszTypename, DWORD dwFlags, mdExportedType *pType) PURE;
  STDMETHOD (EmbedResource) (mdAssembly AssemblyID, mdToken FileToken, LPCWSTR pszResourceName, DWORD dwOffset, DWORD dwFlags) PURE;
  STDMETHOD (LinkResource) (mdAssembly AssemblyID, LPCWSTR pszFileName, LPCWSTR pszNewLocation, LPCWSTR pszResourceName, DWORD dwFlags) PURE;
  STDMETHOD (GetResolutionScope) (mdAssembly AssemblyID, mdToken FileToken, mdToken TargetFile, mdToken *pScope) PURE;
  STDMETHOD (SetAssemblyProps) (mdAssembly AssemblyID, mdToken FileToken, AssemblyOptions Option, VARIANT Value) PURE;
  STDMETHOD (EmitAssemblyCustomAttribute) (mdAssembly AssemblyID, mdToken FileToken, mdToken tkType, void const *pCustomValue, DWORD cbCustomValue, WINBOOL bSecurity, WINBOOL bAllowMulti) PURE;
  STDMETHOD (GetWin32ResBlob) (mdAssembly AssemblyID, mdToken FileToken, WINBOOL fDll, LPCWSTR pszIconFile, const void **ppResBlob, DWORD *pcbResBlob) PURE;
  STDMETHOD (FreeWin32ResBlob) (const void **ppResBlob) PURE;
  STDMETHOD (EmitManifest) (mdAssembly AssemblyID, DWORD *pdwReserveSize, mdAssembly *ptkManifest) PURE;
  STDMETHOD (PreCloseAssembly) (mdAssembly AssemblyID) PURE;
  STDMETHOD (CloseAssembly) (mdAssembly AssemblyID) PURE;
  STDMETHOD (EndMerge) (mdAssembly AssemblyID) PURE;
  STDMETHOD (SetNonAssemblyFlags) (AssemblyFlags afFlags) PURE;
  STDMETHOD (ImportFile2) (LPCWSTR pszFilename, LPCWSTR pszTargetName, IMetaDataAssemblyImport *pAssemblyScopeIn, WINBOOL fSmartImport, mdToken *pImportToken, IMetaDataAssemblyImport **ppAssemblyScope, DWORD *pdwCountOfScopes) PURE;
  STDMETHOD (ExportTypeForwarder) (mdAssemblyRef tkAssemblyRef, LPCWSTR pszTypename, DWORD dwFlags, mdExportedType *pType) PURE;
  STDMETHOD (ExportNestedTypeForwarder) (mdAssembly AssemblyID, mdToken FileToken, mdTypeDef TypeToken, mdExportedType ParentType, LPCWSTR pszTypename, DWORD dwFlags, mdExportedType *pType) PURE;
  END_INTERFACE
};
__CRT_UUID_DECL (IALink, 0xc8e77f39, 0x3604, 0x4fd4, 0x85, 0xcf, 0x38, 0xbd, 0xeb, 0x23, 0x3a, 0xd4);

#undef INTERFACE
#define INTERFACE IALink2
DECLARE_INTERFACE_ (IALink2, IALink) {
#ifndef __cplusplus
   /* IUnknown methods */
   STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
   STDMETHOD_(ULONG, AddRef)(THIS) PURE;
   STDMETHOD_(ULONG, Release)(THIS) PURE;
  /* IALink */
  STDMETHOD (Init) (IMetaDataDispenserEx *pDispenser, IMetaDataError *pErrorHandler) PURE;
  STDMETHOD (ImportFile) (LPCWSTR pszFilename, LPCWSTR pszTargetName, WINBOOL fSmartImport, mdToken *pImportToken, IMetaDataAssemblyImport **ppAssemblyScope, DWORD *pdwCountOfScopes) PURE;
  STDMETHOD (SetAssemblyFile) (LPCWSTR pszFilename, IMetaDataEmit *pEmitter, AssemblyFlags afFlags, mdAssembly *pAssemblyID) PURE;
  STDMETHOD (AddFile) (mdAssembly AssemblyID, LPCWSTR pszFilename, DWORD dwFlags, IMetaDataEmit *pEmitter, mdFile *pFileToken) PURE;
  STDMETHOD (AddImport) (mdAssembly AssemblyID, mdToken ImportToken, DWORD dwFlags, mdFile *pFileToken) PURE;
  STDMETHOD (GetScope) (mdAssembly AssemblyID, mdToken FileToken, DWORD dwScope, IMetaDataImport **ppImportScope) PURE;
  STDMETHOD (GetAssemblyRefHash) (mdToken FileToken, const void **ppvHash, DWORD *pcbHash) PURE;
  STDMETHOD (ImportTypes) (mdAssembly AssemblyID, mdToken FileToken, DWORD dwScope, HALINKENUM *phEnum, IMetaDataImport **ppImportScope, DWORD *pdwCountOfTypes) PURE;
  STDMETHOD (EnumCustomAttributes) (HALINKENUM hEnum, mdToken tkType, mdCustomAttribute rCustomValues[], ULONG cMax, ULONG *pcCustomValues) PURE;
  STDMETHOD (EnumImportTypes) (HALINKENUM hEnum, DWORD dwMax, mdTypeDef aTypeDefs[], DWORD *pdwCount) PURE;
  STDMETHOD (CloseEnum) (HALINKENUM hEnum) PURE;
  STDMETHOD (ExportType) (mdAssembly AssemblyID, mdToken FileToken, mdTypeDef TypeToken, LPCWSTR pszTypename, DWORD dwFlags, mdExportedType *pType) PURE;
  STDMETHOD (ExportNestedType) (mdAssembly AssemblyID, mdToken FileToken, mdTypeDef TypeToken, mdExportedType ParentType, LPCWSTR pszTypename, DWORD dwFlags, mdExportedType *pType) PURE;
  STDMETHOD (EmbedResource) (mdAssembly AssemblyID, mdToken FileToken, LPCWSTR pszResourceName, DWORD dwOffset, DWORD dwFlags) PURE;
  STDMETHOD (LinkResource) (mdAssembly AssemblyID, LPCWSTR pszFileName, LPCWSTR pszNewLocation, LPCWSTR pszResourceName, DWORD dwFlags) PURE;
  STDMETHOD (GetResolutionScope) (mdAssembly AssemblyID, mdToken FileToken, mdToken TargetFile, mdToken *pScope) PURE;
  STDMETHOD (SetAssemblyProps) (mdAssembly AssemblyID, mdToken FileToken, AssemblyOptions Option, VARIANT Value) PURE;
  STDMETHOD (EmitAssemblyCustomAttribute) (mdAssembly AssemblyID, mdToken FileToken, mdToken tkType, void const *pCustomValue, DWORD cbCustomValue, WINBOOL bSecurity, WINBOOL bAllowMulti) PURE;
  STDMETHOD (GetWin32ResBlob) (mdAssembly AssemblyID, mdToken FileToken, WINBOOL fDll, LPCWSTR pszIconFile, const void **ppResBlob, DWORD *pcbResBlob) PURE;
  STDMETHOD (FreeWin32ResBlob) (const void **ppResBlob) PURE;
  STDMETHOD (EmitManifest) (mdAssembly AssemblyID, DWORD *pdwReserveSize, mdAssembly *ptkManifest) PURE;
  STDMETHOD (PreCloseAssembly) (mdAssembly AssemblyID) PURE;
  STDMETHOD (CloseAssembly) (mdAssembly AssemblyID) PURE;
  STDMETHOD (EndMerge) (mdAssembly AssemblyID) PURE;
  STDMETHOD (SetNonAssemblyFlags) (AssemblyFlags afFlags) PURE;
  STDMETHOD (ImportFile2) (LPCWSTR pszFilename, LPCWSTR pszTargetName, IMetaDataAssemblyImport *pAssemblyScopeIn, WINBOOL fSmartImport, mdToken *pImportToken, IMetaDataAssemblyImport **ppAssemblyScope, DWORD *pdwCountOfScopes) PURE;
  STDMETHOD (ExportTypeForwarder) (mdAssemblyRef tkAssemblyRef, LPCWSTR pszTypename, DWORD dwFlags, mdExportedType *pType) PURE;
  STDMETHOD (ExportNestedTypeForwarder) (mdAssembly AssemblyID, mdToken FileToken, mdTypeDef TypeToken, mdExportedType ParentType, LPCWSTR pszTypename, DWORD dwFlags, mdExportedType *pType) PURE;
#endif
  STDMETHOD (SetAssemblyFile2) (LPCWSTR pszFilename, IMetaDataEmit2 *pEmitter, AssemblyFlags afFlags, mdAssembly *pAssemblyID) PURE;
  STDMETHOD (AddFile2) (mdAssembly AssemblyID, LPCWSTR pszFilename, DWORD dwFlags, IMetaDataEmit2 *pEmitter, mdFile *pFileToken) PURE;
  STDMETHOD (GetScope2) (mdAssembly AssemblyID, mdToken FileToken, DWORD dwScope, IMetaDataImport2 **ppImportScope) PURE;
  STDMETHOD (ImportTypes2) (mdAssembly AssemblyID, mdToken FileToken, DWORD dwScope, HALINKENUM *phEnum, IMetaDataImport2 **ppImportScope, DWORD *pdwCountOfTypes) PURE;
  STDMETHOD (GetFileDef) (mdAssembly AssemblyID, mdFile TargetFile, mdFile *pScope) PURE;
  STDMETHOD (GetPublicKeyToken) (LPCWSTR pszKeyFile, LPCWSTR pszKeyContainer, void *pvPublicKeyToken, DWORD *pcbPublicKeyToken) PURE;
  STDMETHOD (EmitInternalExportedTypes) (mdAssembly AssemblyID) PURE;
  STDMETHOD (ImportFileEx) (LPCWSTR pszFilename, LPCWSTR pszTargetName, WINBOOL fSmartImport, DWORD dwOpenFlags, mdToken *pImportToken, IMetaDataAssemblyImport **ppAssemblyScope, DWORD *pdwCountOfScopes) PURE;
  STDMETHOD (ImportFileEx2) (LPCWSTR pszFilename, LPCWSTR pszTargetName, IMetaDataAssemblyImport *pAssemblyScopeIn, WINBOOL fSmartImport, DWORD dwOpenFlags, mdToken *pImportToken, IMetaDataAssemblyImport **ppAssemblyScope, DWORD *pdwCountOfScopes) PURE;
  STDMETHOD (SetPEKind) (mdAssembly AssemblyID, mdToken FileToken, DWORD dwPEKind, DWORD dwMachine) PURE;
  STDMETHOD (EmitAssembly) (mdAssembly AssemblyID) PURE;
};
__CRT_UUID_DECL (IALink2, 0xc8e77f39, 0x3604, 0x4fd4, 0x85, 0xcf, 0x38, 0xbd, 0xeb, 0x23, 0x3a, 0xd5);

#undef INTERFACE
#define INTERFACE IALink3
DECLARE_INTERFACE_ (IALink3, IALink2) {
#ifndef __cplusplus
   /* IUnknown methods */
   STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
   STDMETHOD_(ULONG, AddRef)(THIS) PURE;
   STDMETHOD_(ULONG, Release)(THIS) PURE;
  /* IALink */
  STDMETHOD (Init) (IMetaDataDispenserEx *pDispenser, IMetaDataError *pErrorHandler) PURE;
  STDMETHOD (ImportFile) (LPCWSTR pszFilename, LPCWSTR pszTargetName, WINBOOL fSmartImport, mdToken *pImportToken, IMetaDataAssemblyImport **ppAssemblyScope, DWORD *pdwCountOfScopes) PURE;
  STDMETHOD (SetAssemblyFile) (LPCWSTR pszFilename, IMetaDataEmit *pEmitter, AssemblyFlags afFlags, mdAssembly *pAssemblyID) PURE;
  STDMETHOD (AddFile) (mdAssembly AssemblyID, LPCWSTR pszFilename, DWORD dwFlags, IMetaDataEmit *pEmitter, mdFile *pFileToken) PURE;
  STDMETHOD (AddImport) (mdAssembly AssemblyID, mdToken ImportToken, DWORD dwFlags, mdFile *pFileToken) PURE;
  STDMETHOD (GetScope) (mdAssembly AssemblyID, mdToken FileToken, DWORD dwScope, IMetaDataImport **ppImportScope) PURE;
  STDMETHOD (GetAssemblyRefHash) (mdToken FileToken, const void **ppvHash, DWORD *pcbHash) PURE;
  STDMETHOD (ImportTypes) (mdAssembly AssemblyID, mdToken FileToken, DWORD dwScope, HALINKENUM *phEnum, IMetaDataImport **ppImportScope, DWORD *pdwCountOfTypes) PURE;
  STDMETHOD (EnumCustomAttributes) (HALINKENUM hEnum, mdToken tkType, mdCustomAttribute rCustomValues[], ULONG cMax, ULONG *pcCustomValues) PURE;
  STDMETHOD (EnumImportTypes) (HALINKENUM hEnum, DWORD dwMax, mdTypeDef aTypeDefs[], DWORD *pdwCount) PURE;
  STDMETHOD (CloseEnum) (HALINKENUM hEnum) PURE;
  STDMETHOD (ExportType) (mdAssembly AssemblyID, mdToken FileToken, mdTypeDef TypeToken, LPCWSTR pszTypename, DWORD dwFlags, mdExportedType *pType) PURE;
  STDMETHOD (ExportNestedType) (mdAssembly AssemblyID, mdToken FileToken, mdTypeDef TypeToken, mdExportedType ParentType, LPCWSTR pszTypename, DWORD dwFlags, mdExportedType *pType) PURE;
  STDMETHOD (EmbedResource) (mdAssembly AssemblyID, mdToken FileToken, LPCWSTR pszResourceName, DWORD dwOffset, DWORD dwFlags) PURE;
  STDMETHOD (LinkResource) (mdAssembly AssemblyID, LPCWSTR pszFileName, LPCWSTR pszNewLocation, LPCWSTR pszResourceName, DWORD dwFlags) PURE;
  STDMETHOD (GetResolutionScope) (mdAssembly AssemblyID, mdToken FileToken, mdToken TargetFile, mdToken *pScope) PURE;
  STDMETHOD (SetAssemblyProps) (mdAssembly AssemblyID, mdToken FileToken, AssemblyOptions Option, VARIANT Value) PURE;
  STDMETHOD (EmitAssemblyCustomAttribute) (mdAssembly AssemblyID, mdToken FileToken, mdToken tkType, void const *pCustomValue, DWORD cbCustomValue, WINBOOL bSecurity, WINBOOL bAllowMulti) PURE;
  STDMETHOD (GetWin32ResBlob) (mdAssembly AssemblyID, mdToken FileToken, WINBOOL fDll, LPCWSTR pszIconFile, const void **ppResBlob, DWORD *pcbResBlob) PURE;
  STDMETHOD (FreeWin32ResBlob) (const void **ppResBlob) PURE;
  STDMETHOD (EmitManifest) (mdAssembly AssemblyID, DWORD *pdwReserveSize, mdAssembly *ptkManifest) PURE;
  STDMETHOD (PreCloseAssembly) (mdAssembly AssemblyID) PURE;
  STDMETHOD (CloseAssembly) (mdAssembly AssemblyID) PURE;
  STDMETHOD (EndMerge) (mdAssembly AssemblyID) PURE;
  STDMETHOD (SetNonAssemblyFlags) (AssemblyFlags afFlags) PURE;
  STDMETHOD (ImportFile2) (LPCWSTR pszFilename, LPCWSTR pszTargetName, IMetaDataAssemblyImport *pAssemblyScopeIn, WINBOOL fSmartImport, mdToken *pImportToken, IMetaDataAssemblyImport **ppAssemblyScope, DWORD *pdwCountOfScopes) PURE;
  STDMETHOD (ExportTypeForwarder) (mdAssemblyRef tkAssemblyRef, LPCWSTR pszTypename, DWORD dwFlags, mdExportedType *pType) PURE;
  STDMETHOD (ExportNestedTypeForwarder) (mdAssembly AssemblyID, mdToken FileToken, mdTypeDef TypeToken, mdExportedType ParentType, LPCWSTR pszTypename, DWORD dwFlags, mdExportedType *pType) PURE;
  /* IALink2 */
  STDMETHOD (SetAssemblyFile2) (LPCWSTR pszFilename, IMetaDataEmit2 *pEmitter, AssemblyFlags afFlags, mdAssembly *pAssemblyID) PURE;
  STDMETHOD (AddFile2) (mdAssembly AssemblyID, LPCWSTR pszFilename, DWORD dwFlags, IMetaDataEmit2 *pEmitter, mdFile *pFileToken) PURE;
  STDMETHOD (GetScope2) (mdAssembly AssemblyID, mdToken FileToken, DWORD dwScope, IMetaDataImport2 **ppImportScope) PURE;
  STDMETHOD (ImportTypes2) (mdAssembly AssemblyID, mdToken FileToken, DWORD dwScope, HALINKENUM *phEnum, IMetaDataImport2 **ppImportScope, DWORD *pdwCountOfTypes) PURE;
  STDMETHOD (GetFileDef) (mdAssembly AssemblyID, mdFile TargetFile, mdFile *pScope) PURE;
  STDMETHOD (GetPublicKeyToken) (LPCWSTR pszKeyFile, LPCWSTR pszKeyContainer, void *pvPublicKeyToken, DWORD *pcbPublicKeyToken) PURE;
  STDMETHOD (EmitInternalExportedTypes) (mdAssembly AssemblyID) PURE;
  STDMETHOD (ImportFileEx) (LPCWSTR pszFilename, LPCWSTR pszTargetName, WINBOOL fSmartImport, DWORD dwOpenFlags, mdToken *pImportToken, IMetaDataAssemblyImport **ppAssemblyScope, DWORD *pdwCountOfScopes) PURE;
  STDMETHOD (ImportFileEx2) (LPCWSTR pszFilename, LPCWSTR pszTargetName, IMetaDataAssemblyImport *pAssemblyScopeIn, WINBOOL fSmartImport, DWORD dwOpenFlags, mdToken *pImportToken, IMetaDataAssemblyImport **ppAssemblyScope, DWORD *pdwCountOfScopes) PURE;
  STDMETHOD (SetPEKind) (mdAssembly AssemblyID, mdToken FileToken, DWORD dwPEKind, DWORD dwMachine) PURE;
  STDMETHOD (EmitAssembly) (mdAssembly AssemblyID) PURE;
#endif
  STDMETHOD (SetManifestFile) (LPCWSTR pszFile) PURE;
};
__CRT_UUID_DECL (IALink3, 0x22d4f7a0, 0x65, 0x43dd, 0x8e, 0xaf, 0xb9, 0xfb, 0x90, 0x1d, 0x82, 0x23);

#undef INTERFACE

#ifdef __cplusplus
extern "C" {
#endif

  HRESULT WINAPI CreateALink (REFIID riid, IUnknown **ppInterface);
  HINSTANCE WINAPI GetALinkMessageDll ();

#ifdef __cplusplus
}
#endif

#endif
#endif
