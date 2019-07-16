/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _FILEHC_H_
#define _FILEHC_H_
#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#ifndef WINAPI
#if defined(_ARM_)
#define WINAPI
#else
#define WINAPI __stdcall
#endif
#endif

#ifdef _FILEHC_IMPLEMENTATION_
#define FILEHC_EXPORT __declspec (dllexport)
#else
#define FILEHC_EXPORT __declspec (dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif

  typedef VOID (*PFN_IO_COMPLETION) (struct FIO_CONTEXT *pContext, struct FH_OVERLAPPED *lpo, DWORD cb, DWORD dwCompletionStatus);

  struct FH_OVERLAPPED {
    UINT_PTR Internal;
    UINT_PTR InternalHigh;
    DWORD Offset;
    DWORD OffsetHigh;
    HANDLE hEvent;
    PFN_IO_COMPLETION pfnCompletion;
    UINT_PTR Reserved1;
    UINT_PTR Reserved2;
    UINT_PTR Reserved3;
    UINT_PTR Reserved4;
  };

  typedef struct FH_OVERLAPPED *PFH_OVERLAPPED;

  struct FIO_CONTEXT {
    DWORD m_dwTempHack;
    DWORD m_dwSignature;
    HANDLE m_hFile;
    DWORD m_dwLinesOffset;
    DWORD m_dwHeaderLength;
  };

  typedef FIO_CONTEXT *PFIO_CONTEXT;

  struct NAME_CACHE_CONTEXT {
    DWORD m_dwSignature;
  };

  typedef struct NAME_CACHE_CONTEXT *PNAME_CACHE_CONTEXT;

  typedef HANDLE (WINAPI *FCACHE_CREATE_CALLBACK) (LPSTR lpstrName, LPVOID lpvData, DWORD *cbFileSize, DWORD *cbFileSizeHigh);
  typedef HANDLE (WINAPI *FCACHE_RICHCREATE_CALLBACK) (LPSTR lpstrName, LPVOID lpvData, DWORD *cbFileSize, DWORD *cbFileSizeHigh, WINBOOL *pfDidWeScanIt, WINBOOL *pfIsStuffed, WINBOOL *pfStoredWithDots, WINBOOL *pfStoredWithTerminatingDot);
  typedef int (WINAPI *CACHE_KEY_COMPARE) (DWORD cbKey1, LPBYTE lpbKey1, DWORD cbKey2, LPBYTE lpbKey2);
  typedef DWORD (WINAPI *CACHE_KEY_HASH) (LPBYTE lpbKey, DWORD cbKey);
  typedef WINBOOL (WINAPI *CACHE_READ_CALLBACK) (DWORD cb, LPBYTE lpb, LPVOID lpvContext);
  typedef void (WINAPI *CACHE_DESTROY_CALLBACK) (DWORD cb, LPBYTE lpb);
  typedef WINBOOL (WINAPI *CACHE_ACCESS_CHECK) (PSECURITY_DESCRIPTOR pSecurityDescriptor, HANDLE hClientToken, DWORD dwDesiredAccess, PGENERIC_MAPPING GenericMapping, PRIVILEGE_SET *PrivilegeSet, LPDWORD PrivilegeSetLength, LPDWORD GrantedAccess, LPBOOL AccessStatus);

  FILEHC_EXPORT WINBOOL WINAPI FIOInitialize (DWORD dwFlags);
  FILEHC_EXPORT WINBOOL WINAPI FIOTerminate (VOID);
  FILEHC_EXPORT WINBOOL WINAPI FIOReadFile (PFIO_CONTEXT pContext, LPVOID lpBuffer, DWORD BytesToRead, FH_OVERLAPPED *lpo);
  FILEHC_EXPORT WINBOOL WINAPI FIOReadFileEx (PFIO_CONTEXT pContext, LPVOID lpBuffer, DWORD BytesToRead, DWORD BytesAvailable, FH_OVERLAPPED *lpo, WINBOOL fFinalWrite, WINBOOL fIncludeTerminator);
  FILEHC_EXPORT WINBOOL WINAPI FIOWriteFile (PFIO_CONTEXT pContext, LPCVOID lpBuffer, DWORD BytesToWrite, FH_OVERLAPPED *lpo);
  FILEHC_EXPORT WINBOOL WINAPI FIOWriteFileEx (PFIO_CONTEXT pContext, LPVOID lpBuffer, DWORD BytesToWrite, DWORD BytesAvailable, FH_OVERLAPPED *lpo, WINBOOL fFinalWrite, WINBOOL fIncludeTerminator);
  FILEHC_EXPORT WINBOOL WINAPI InitializeCache ();
  FILEHC_EXPORT WINBOOL WINAPI TerminateCache ();
  FILEHC_EXPORT PFIO_CONTEXT WINAPI AssociateFile (HANDLE hFile);
  FILEHC_EXPORT PFIO_CONTEXT WINAPI AssociateFileEx (HANDLE hFile, WINBOOL fStoreWithDots, WINBOOL fStoredWithTerminatingDot);
  FILEHC_EXPORT void WINAPI AddRefContext (PFIO_CONTEXT);
  FILEHC_EXPORT void WINAPI ReleaseContext (PFIO_CONTEXT);
  FILEHC_EXPORT WINBOOL WINAPI CloseNonCachedFile (PFIO_CONTEXT);
  FILEHC_EXPORT FIO_CONTEXT * WINAPI CacheCreateFile (LPSTR lpstrName, FCACHE_CREATE_CALLBACK pfnCallBack, LPVOID lpv, WINBOOL fAsyncContext);
  FILEHC_EXPORT FIO_CONTEXT * WINAPI CacheRichCreateFile (LPSTR lpstrName, FCACHE_RICHCREATE_CALLBACK pfnCallBack, LPVOID lpv, WINBOOL fAsyncContext);
  FILEHC_EXPORT void WINAPI CacheRemoveFiles (LPSTR lpstrName, WINBOOL fAllPrefixes);
  FILEHC_EXPORT WINBOOL WINAPI InsertFile (LPSTR lpstrName, FIO_CONTEXT *pContext, WINBOOL fKeepReference);
  FILEHC_EXPORT DWORD WINAPI GetFileSizeFromContext (FIO_CONTEXT *pContext, DWORD *pcbFileSizeHigh);
  FILEHC_EXPORT PNAME_CACHE_CONTEXT WINAPI FindOrCreateNameCache (LPSTR lpstrName, CACHE_KEY_COMPARE pfnKeyCompare, CACHE_KEY_HASH pfnKeyHash, CACHE_DESTROY_CALLBACK pfnKeyDestroy, CACHE_DESTROY_CALLBACK pfnDataDestroy);
  FILEHC_EXPORT __LONG32 WINAPI ReleaseNameCache (PNAME_CACHE_CONTEXT pNameCache);
  FILEHC_EXPORT WINBOOL WINAPI SetNameCacheSecurityFunction (PNAME_CACHE_CONTEXT pNameCache, CACHE_ACCESS_CHECK pfnAccessCheck);
  FILEHC_EXPORT WINBOOL WINAPI FindContextFromName (PNAME_CACHE_CONTEXT pNameCache, LPBYTE lpbName, DWORD cbName, CACHE_READ_CALLBACK pfnCallback, LPVOID lpvClientContext, HANDLE hToken, ACCESS_MASK accessMask, FIO_CONTEXT **ppContext);
  FILEHC_EXPORT WINBOOL WINAPI FindSyncContextFromName (PNAME_CACHE_CONTEXT pNameCache, LPBYTE lpbName, DWORD cbName, CACHE_READ_CALLBACK pfnCallback, LPVOID lpvClientContext, HANDLE hToken, ACCESS_MASK accessMask, FIO_CONTEXT **ppContext);
  FILEHC_EXPORT WINBOOL WINAPI AssociateContextWithName (PNAME_CACHE_CONTEXT pNameCache, LPBYTE lpbName, DWORD cbName, LPBYTE lpbData, DWORD cbData, PGENERIC_MAPPING pGenericMapping, PSECURITY_DESCRIPTOR pSecurityDescriptor, FIO_CONTEXT *pContext, WINBOOL fKeepReference);
  FILEHC_EXPORT WINBOOL WINAPI InvalidateName (PNAME_CACHE_CONTEXT pNameCache, LPBYTE lpbName, DWORD cbName);
  FILEHC_EXPORT FIO_CONTEXT * WINAPI ProduceDotStuffedContext (FIO_CONTEXT *pContext, LPSTR lpstrName, WINBOOL fWantItDotStuffed);
  FILEHC_EXPORT WINBOOL WINAPI ProduceDotStuffedContextInContext (FIO_CONTEXT *pContextSource, FIO_CONTEXT *pContextDestination, WINBOOL fWantItDotStuffed, WINBOOL *pfModified);
  FILEHC_EXPORT WINBOOL WINAPI GetIsFileDotTerminated (FIO_CONTEXT *pContext);
  FILEHC_EXPORT void WINAPI SetIsFileDotTerminated (FIO_CONTEXT *pContext, WINBOOL fIsDotTerminated);
  FILEHC_EXPORT WINBOOL WINAPI SetDotStuffingOnWrites (FIO_CONTEXT *pContext, WINBOOL fEnable, WINBOOL fStripDots);
  FILEHC_EXPORT WINBOOL WINAPI SetDotScanningOnWrites (FIO_CONTEXT *pContext, WINBOOL fEnable);
  FILEHC_EXPORT void WINAPI CompleteDotStuffingOnWrites (FIO_CONTEXT *pContext, WINBOOL fStripDots);
  FILEHC_EXPORT WINBOOL WINAPI SetDotScanningOnReads (FIO_CONTEXT *pContext, WINBOOL fEnable);
  FILEHC_EXPORT WINBOOL WINAPI GetDotStuffState (FIO_CONTEXT *pContext, WINBOOL fReads, WINBOOL *pfStuffed, WINBOOL *pfStoredWithDots);
  FILEHC_EXPORT void WINAPI SetDotStuffState (FIO_CONTEXT *pContext, WINBOOL fKnown, WINBOOL fRequiresStuffing);

#ifdef __cplusplus
}
#endif

#endif
#endif
