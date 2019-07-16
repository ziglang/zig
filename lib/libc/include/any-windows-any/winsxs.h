/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_WINSXS
#define _INC_WINSXS
#if (_WIN32_WINNT >= 0x0600)

typedef enum ASM_CMP_FLAGS {
  ASM_CMPF_NAME               = 0x1,
  ASM_CMPF_MAJOR_VERSION      = 0x2,
  ASM_CMPF_MINOR_VERSION      = 0x4,
  ASM_CMPF_BUILD_NUMBER       = 0x8,
  ASM_CMPF_REVISION_NUMBER    = 0x10,
  ASM_CMPF_PUBLIC_KEY_TOKEN   = 0x20,
  ASM_CMPF_CULTURE            = 0x40,
  ASM_CMPF_CUSTOM             = 0x80,
  ASM_CMPF_ALL,
  ASM_CMPF_DEFAULT            = 0x100 
} ASM_CMP_FLAGS;

typedef enum ASM_NAME {
  ASM_NAME_PUBLIC_KEY,
  ASM_NAME_PUBLIC_KEY_TOKEN,
  ASM_NAME_HASH_VALUE,
  ASM_NAME_NAME,
  ASM_NAME_MAJOR_VERSION,
  ASM_NAME_MINOR_VERSION,
  ASM_NAME_BUILD_NUMBER,
  ASM_NAME_REVISION_NUMBER,
  ASM_NAME_CULTURE,
  ASM_NAME_PROCESSOR_ID_ARRAY,
  ASM_NAME_OSINFO_ARRAY,
  ASM_NAME_HASH_ALGID,
  ASM_NAME_ALIAS,
  ASM_NAME_CODEBASE_URL,
  ASM_NAME_CODEBASE_LASTMOD,
  ASM_NAME_NULL_PUBLIC_KEY,
  ASM_NAME_NULL_PUBLIC_KEY_TOKEN,
  ASM_NAME_CUSTOM,
  ASM_NAME_NULL_CUSTOM,
  ASM_NAME_MVID,
  ASM_NAME_MAX_PARAMS 
} ASM_NAME;

typedef enum _CREATE_ASM_NAME_OBJ_FLAGS {
  CANOF_PARSE_DISPLAY_NAME   = 0x1,
  CANOF_SET_DEFAULT_VALUES   = 0x2 
} CREATE_ASM_NAME_OBJ_FLAGS;

typedef struct _ASSEMBLY_INFO  {
  ULONG          cbAssemblyInfo;
  DWORD          dwAssemblyFlags;
  ULARGE_INTEGER uliAssemblySizeInKB;
  LPWSTR         pszCurrentAssemblyPathBuf;
  ULONG          cchBuf;
} ASSEMBLY_INFO;

typedef enum  {
  ASM_DISPLAYF_VERSION                 = 0x1,
  ASM_DISPLAYF_CULTURE                 = 0x2,
  ASM_DISPLAYF_PUBLIC_KEY_TOKEN        = 0x4,
  ASM_DISPLAYF_PUBLIC_KEY              = 0x8,
  ASM_DISPLAYF_CUSTOM                  = 0x10,
  ASM_DISPLAYF_PROCESSORARCHITECTURE   = 0x20,
  ASM_DISPLAYF_LANGUAGEID              = 0x40 
} ASM_DISPLAY_FLAGS;

typedef struct _FUSION_INSTALL_REFERENCE  {
  DWORD   cbSize;
  DWORD   dwFlags;
  GUID    guidScheme;
  LPCWSTR szIdentifier;
  LPCWSTR szNonCannonicalData;
} FUSION_INSTALL_REFERENCE , *LPFUSION_INSTALL_REFERENCE;

/* in sxs.dll but not in any headers
HRESULT STDAPI CreateAssemblyCache(
    IAssemblyCache **ppAsmCache,
    DWORD dwReserved
);

HRESULT STDAPI CreateAssemblyNameObject(
    LPASSEMBLYNAME **ppAssemblyNameObj,
    LPCWSTR szAssemblyName,
    DWORD dwFlags,
    LPVOID pvReserved
);

*/

#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_WINSXS*/
