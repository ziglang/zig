/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#define VOLUME_PREFIX L"\\\\?\\Volume"
#define VOLUME_PREFIX_LEN (ARRAYSIZE (VOLUME_PREFIX) - 1)

#define PATHCCH_ALLOW_LONG_PATHS 0x00000001
#define PATHCCH_MAX_CCH 0x8000

  WINPATHCCHAPI HRESULT APIENTRY PathAllocCombine (PCWSTR pszPathIn, PCWSTR pszMore, unsigned long dwFlags, PWSTR *ppszPathOut);
  WINPATHCCHAPI HRESULT APIENTRY PathAllocCanonicalize (PCWSTR pszPathIn, unsigned long dwFlags, PWSTR *ppszPathOut);
  WINPATHCCHAPI HRESULT APIENTRY PathCchAddBackslash (PWSTR pszPath, size_t cchPath);
  WINPATHCCHAPI HRESULT APIENTRY PathCchAddBackslashEx (PWSTR pszPath, size_t cchPath, PWSTR *ppszEnd, size_t *pcchRemaining);
  WINPATHCCHAPI HRESULT APIENTRY PathCchAddExtension (PWSTR pszPath, size_t cchPath, PCWSTR pszExt);
  WINPATHCCHAPI HRESULT APIENTRY PathCchAppend (PWSTR pszPath, size_t cchPath, PCWSTR pszMore);
  WINPATHCCHAPI HRESULT APIENTRY PathCchAppendEx (PWSTR pszPath, size_t cchPath, PCWSTR pszMore, unsigned long dwFlags);
  WINPATHCCHAPI HRESULT APIENTRY PathCchCanonicalize (PWSTR pszPathOut, size_t cchPathOut, PCWSTR pszPathIn);
  WINPATHCCHAPI HRESULT APIENTRY PathCchCanonicalizeEx (PWSTR pszPathOut, size_t cchPathOut, PCWSTR pszPathIn, unsigned long dwFlags);
  WINPATHCCHAPI HRESULT APIENTRY PathCchCombine (PWSTR pszPathOut, size_t cchPathOut, PCWSTR pszPathIn, PCWSTR pszMore);
  WINPATHCCHAPI HRESULT APIENTRY PathCchCombineEx (PWSTR pszPathOut, size_t cchPathOut, PCWSTR pszPathIn, PCWSTR pszMore, unsigned long dwFlags);
  WINPATHCCHAPI HRESULT APIENTRY PathCchFindExtension (PCWSTR pszPath, size_t cchPath, PCWSTR *ppszExt);
  WINPATHCCHAPI WINBOOL APIENTRY PathCchIsRoot (PCWSTR pszPath);
  WINPATHCCHAPI HRESULT APIENTRY PathCchRemoveBackslashEx (PWSTR pszPath, size_t cchPath, PWSTR *ppszEnd, size_t *pcchRemaining);
  WINPATHCCHAPI HRESULT APIENTRY PathCchRemoveBackslash (PWSTR pszPath, size_t cchPath);
  WINPATHCCHAPI HRESULT APIENTRY PathCchRemoveExtension (PWSTR pszPath, size_t cchPath);
  WINPATHCCHAPI HRESULT APIENTRY PathCchRemoveFileSpec (PWSTR pszPath, size_t cchPath);
  WINPATHCCHAPI HRESULT APIENTRY PathCchRenameExtension (PWSTR pszPath, size_t cchPath, PCWSTR pszExt);
  WINPATHCCHAPI HRESULT APIENTRY PathCchSkipRoot (PCWSTR pszPath, PCWSTR *ppszRootEnd);
  WINPATHCCHAPI HRESULT APIENTRY PathCchStripPrefix (PWSTR pszPath, size_t cchPath);
  WINPATHCCHAPI HRESULT APIENTRY PathCchStripToRoot (PWSTR pszPath, size_t cchPath);
  WINPATHCCHAPI WINBOOL APIENTRY PathIsUNCEx (PCWSTR pszPath, PCWSTR *ppszServer);

#ifndef PATHCCH_NO_DEPRECATE
#undef PathAddBackslash
#undef PathAddBackslashA
#undef PathAddBackslashW

#undef PathAddExtension
#undef PathAddExtensionA
#undef PathAddExtensionW

#undef PathAppend
#undef PathAppendA
#undef PathAppendW

#undef PathCanonicalize
#undef PathCanonicalizeA
#undef PathCanonicalizeW

#undef PathCombine
#undef PathCombineA
#undef PathCombineW

#undef PathRenameExtension
#undef PathRenameExtensionA
#undef PathRenameExtensionW

#ifndef DEPRECATE_SUPPORTED
#define PathIsRelativeWorker PathIsRelativeWorker_is_internal_to_pathcch;
#define StrIsEqualWorker StrIsEqualWorker_is_internal_to_pathcch;
#define FindPreviousBackslashWorker FindPreviousBackslashWorker_is_internal_to_pathcch;
#define IsHexDigitWorker IsHexDigitWorker_is_internal_to_pathcch;
#define StringIsGUIDWorker StringIsGUIDWorker_is_internal_to_pathcch;
#define PathIsVolumeGUIDWorker PathIsVolumeGUIDWorker_is_internal_to_pathcch;
#define IsValidExtensionWorker IsValidExtensionWorker_is_internal_to_pathcch;

#define PathAddBackslash PathAddBackslash_instead_use_PathCchAddBackslash;
#define PathAddBackslashA PathAddBackslash_instead_use_PathCchAddBackslash;
#define PathAddBackslashW PathAddBackslash_instead_use_PathCchAddBackslash;

#define PathAddExtension PathAddExtension_instead_use_PathCchAddExtension;
#define PathAddExtensionA PathAddExtension_instead_use_PathCchAddExtension;
#define PathAddExtensionW PathAddExtension_instead_use_PathCchAddExtension;

#define PathAppend PathAppend_instead_use_PathCchAppend;
#define PathAppendA PathAppend_instead_use_PathCchAppend;
#define PathAppendW PathAppend_instead_use_PathCchAppend;

#define PathCanonicalize PathCanonicalize_instead_use_PathCchCanonicalize;
#define PathCanonicalizeA PathCanonicalize_instead_use_PathCchCanonicalize;
#define PathCanonicalizeW PathCanonicalize_instead_use_PathCchCanonicalize;

#define PathCombine PathCombine_instead_use_PathCchCombine;
#define PathCombineA PathCombine_instead_use_PathCchCombine;
#define PathCombineW PathCombine_instead_use_PathCchCombine;

#define PathRenameExtension PathRenameExtension_instead_use_PathCchRenameExtension;
#define PathRenameExtensionA PathRenameExtension_instead_use_PathCchRenameExtension;
#define PathRenameExtensionW PathRenameExtension_instead_use_PathCchRenameExtension;
#endif
#endif
#endif

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  __CRT_INLINE WINBOOL PathIsUNCEx (PWSTR path, PWSTR *pserver) {
    return PathIsUNCEx (const_cast<PCWSTR> (path), const_cast<PCWSTR *> (pserver));
  }

  __CRT_INLINE HRESULT PathCchSkipRoot (PWSTR path, PWSTR *prootend) {
    return PathCchSkipRoot (const_cast<PCWSTR> (path), const_cast<PCWSTR *> (prootend));
  }

  __CRT_INLINE HRESULT PathCchFindExtension (PWSTR path, size_t n, PWSTR *pext) {
    return PathCchFindExtension (const_cast<PCWSTR> (path), n, const_cast<PCWSTR *> (pext));
}
#endif
#endif
