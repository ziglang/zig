/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _PATCHAPI_H_
#define _PATCHAPI_H_

#include <_mingw_unicode.h>
#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#ifdef __cplusplus
extern "C" {
#endif

#ifdef IMPORTING_PATCHAPI_DLL
#define PATCHAPI WINAPI __declspec(dllimport)
#else
#define PATCHAPI WINAPI
#endif

#define PATCH_OPTION_USE_BEST               0x0
#define PATCH_OPTION_USE_LZX_A              0x1
#define PATCH_OPTION_USE_LZX_B              0x2
#define PATCH_OPTION_USE_LZX_BEST           0x3
#define PATCH_OPTION_USE_LZX_LARGE          0x4

#define PATCH_OPTION_NO_BINDFIX 0x00010000
#define PATCH_OPTION_NO_LOCKFIX 0x00020000
#define PATCH_OPTION_NO_REBASE 0x00040000
#define PATCH_OPTION_FAIL_IF_SAME_FILE 0x00080000
#define PATCH_OPTION_FAIL_IF_BIGGER 0x00100000
#define PATCH_OPTION_NO_CHECKSUM 0x00200000
#define PATCH_OPTION_NO_RESTIMEFIX 0x00400000
#define PATCH_OPTION_NO_TIMESTAMP 0x00800000
#define PATCH_OPTION_SIGNATURE_MD5 0x01000000
#define PATCH_OPTION_INTERLEAVE_FILES 0x40000000
#define PATCH_OPTION_RESERVED1 0x80000000

#define PATCH_OPTION_VALID_FLAGS 0xc0ff0007

#define PATCH_SYMBOL_NO_IMAGEHLP 0x00000001
#define PATCH_SYMBOL_NO_FAILURES 0x00000002
#define PATCH_SYMBOL_UNDECORATED_TOO 0x00000004
#define PATCH_SYMBOL_RESERVED1 0x80000000

#define PATCH_TRANSFORM_PE_RESOURCE_2 0x00000100
#define PATCH_TRANSFORM_PE_IRELOC_2 0x00000200

#define APPLY_OPTION_FAIL_IF_EXACT 0x00000001
#define APPLY_OPTION_FAIL_IF_CLOSE 0x00000002
#define APPLY_OPTION_TEST_ONLY 0x00000004
#define APPLY_OPTION_VALID_FLAGS 0x00000007

#define ERROR_PATCH_ENCODE_FAILURE 0xC00E3101
#define ERROR_PATCH_INVALID_OPTIONS 0xC00E3102
#define ERROR_PATCH_SAME_FILE 0xC00E3103
#define ERROR_PATCH_RETAIN_RANGES_DIFFER 0xC00E3104
#define ERROR_PATCH_BIGGER_THAN_COMPRESSED 0xC00E3105
#define ERROR_PATCH_IMAGEHLP_FAILURE 0xC00E3106

#define ERROR_PATCH_DECODE_FAILURE 0xC00E4101
#define ERROR_PATCH_CORRUPT 0xC00E4102
#define ERROR_PATCH_NEWER_FORMAT 0xC00E4103
#define ERROR_PATCH_WRONG_FILE 0xC00E4104
#define ERROR_PATCH_NOT_NECESSARY 0xC00E4105
#define ERROR_PATCH_NOT_AVAILABLE 0xC00E4106

  typedef WINBOOL (CALLBACK PATCH_PROGRESS_CALLBACK)(PVOID CallbackContext,ULONG CurrentPosition,ULONG MaximumPosition);
  typedef PATCH_PROGRESS_CALLBACK *PPATCH_PROGRESS_CALLBACK;
  typedef WINBOOL (CALLBACK PATCH_SYMLOAD_CALLBACK)(ULONG WhichFile,LPCSTR SymbolFileName,ULONG SymType,ULONG SymbolFileCheckSum,ULONG SymbolFileTimeDate,ULONG ImageFileCheckSum,ULONG ImageFileTimeDate,PVOID CallbackContext);
  typedef PATCH_SYMLOAD_CALLBACK *PPATCH_SYMLOAD_CALLBACK;

  typedef struct _PATCH_IGNORE_RANGE {
    ULONG OffsetInOldFile;
    ULONG LengthInBytes;
  } PATCH_IGNORE_RANGE,*PPATCH_IGNORE_RANGE;

  typedef struct _PATCH_RETAIN_RANGE {
    ULONG OffsetInOldFile;
    ULONG LengthInBytes;
    ULONG OffsetInNewFile;
  } PATCH_RETAIN_RANGE,*PPATCH_RETAIN_RANGE;

  typedef struct _PATCH_OLD_FILE_INFO_A {
    ULONG SizeOfThisStruct;
    LPCSTR OldFileName;
    ULONG IgnoreRangeCount;
    PPATCH_IGNORE_RANGE IgnoreRangeArray;
    ULONG RetainRangeCount;
    PPATCH_RETAIN_RANGE RetainRangeArray;
  } PATCH_OLD_FILE_INFO_A,*PPATCH_OLD_FILE_INFO_A;

  typedef struct _PATCH_OLD_FILE_INFO_W {
    ULONG SizeOfThisStruct;
    LPCWSTR OldFileName;
    ULONG IgnoreRangeCount;
    PPATCH_IGNORE_RANGE IgnoreRangeArray;
    ULONG RetainRangeCount;
    PPATCH_RETAIN_RANGE RetainRangeArray;
  } PATCH_OLD_FILE_INFO_W,*PPATCH_OLD_FILE_INFO_W;

  typedef struct _PATCH_OLD_FILE_INFO_H {
    ULONG SizeOfThisStruct;
    HANDLE OldFileHandle;
    ULONG IgnoreRangeCount;
    PPATCH_IGNORE_RANGE IgnoreRangeArray;
    ULONG RetainRangeCount;
    PPATCH_RETAIN_RANGE RetainRangeArray;
  } PATCH_OLD_FILE_INFO_H,*PPATCH_OLD_FILE_INFO_H;

  typedef struct _PATCH_OLD_FILE_INFO {
    ULONG SizeOfThisStruct;
    __C89_NAMELESS union {
      LPCSTR OldFileNameA;
      LPCWSTR OldFileNameW;
      HANDLE OldFileHandle;
    };
    ULONG IgnoreRangeCount;
    PPATCH_IGNORE_RANGE IgnoreRangeArray;
    ULONG RetainRangeCount;
    PPATCH_RETAIN_RANGE RetainRangeArray;
  } PATCH_OLD_FILE_INFO,*PPATCH_OLD_FILE_INFO;

  typedef struct _PATCH_INTERLEAVE_MAP {
    ULONG CountRanges;
    struct {
      ULONG OldOffset;
      ULONG OldLength;
      ULONG NewLength;
    } Range[1];
  } PATCH_INTERLEAVE_MAP, *PPATCH_INTERLEAVE_MAP;

  typedef struct _PATCH_OPTION_DATA {
    ULONG SizeOfThisStruct;
    ULONG SymbolOptionFlags;
    LPCSTR NewFileSymbolPath;
    LPCSTR *OldFileSymbolPathArray;
    ULONG ExtendedOptionFlags;
    PPATCH_SYMLOAD_CALLBACK SymLoadCallback;
    PVOID SymLoadContext;
    PPATCH_INTERLEAVE_MAP *InterleaveMapArray;
    ULONG MaxLzxWindowSize;
  } PATCH_OPTION_DATA,*PPATCH_OPTION_DATA;

  WINBOOL PATCHAPI CreatePatchFileA(LPCSTR OldFileName,LPCSTR NewFileName,LPCSTR PatchFileName,ULONG OptionFlags,PPATCH_OPTION_DATA OptionData);
  WINBOOL PATCHAPI CreatePatchFileW(LPCWSTR OldFileName,LPCWSTR NewFileName,LPCWSTR PatchFileName,ULONG OptionFlags,PPATCH_OPTION_DATA OptionData);
#define CreatePatchFile __MINGW_NAME_AW(CreatePatchFile)

  WINBOOL PATCHAPI CreatePatchFileExA(ULONG OldFileCount,PPATCH_OLD_FILE_INFO_A OldFileInfoArray,LPCSTR NewFileName,LPCSTR PatchFileName,ULONG OptionFlags,PPATCH_OPTION_DATA OptionData,PPATCH_PROGRESS_CALLBACK ProgressCallback,PVOID CallbackContext);
  WINBOOL PATCHAPI CreatePatchFileExW(ULONG OldFileCount,PPATCH_OLD_FILE_INFO_W OldFileInfoArray,LPCWSTR NewFileName,LPCWSTR PatchFileName,ULONG OptionFlags,PPATCH_OPTION_DATA OptionData,PPATCH_PROGRESS_CALLBACK ProgressCallback,PVOID CallbackContext);
#define CreatePatchFileEx __MINGW_NAME_AW(CreatePatchFileEx)

  WINBOOL PATCHAPI ExtractPatchHeaderToFileA(LPCSTR PatchFileName,LPCSTR PatchHeaderFileName);
  WINBOOL PATCHAPI ExtractPatchHeaderToFileW(LPCWSTR PatchFileName,LPCWSTR PatchHeaderFileName);
#define ExtractPatchHeaderToFile __MINGW_NAME_AW(ExtractPatchHeaderToFile)

  WINBOOL PATCHAPI TestApplyPatchToFileA(LPCSTR PatchFileName,LPCSTR OldFileName,ULONG ApplyOptionFlags);
  WINBOOL PATCHAPI TestApplyPatchToFileW(LPCWSTR PatchFileName,LPCWSTR OldFileName,ULONG ApplyOptionFlags);
#define TestApplyPatchToFile __MINGW_NAME_AW(TestApplyPatchToFile)

  WINBOOL PATCHAPI ApplyPatchToFileA(LPCSTR PatchFileName,LPCSTR OldFileName,LPCSTR NewFileName,ULONG ApplyOptionFlags);
  WINBOOL PATCHAPI ApplyPatchToFileW(LPCWSTR PatchFileName,LPCWSTR OldFileName,LPCWSTR NewFileName,ULONG ApplyOptionFlags);
#define ApplyPatchToFile __MINGW_NAME_AW(ApplyPatchToFile)

  WINBOOL PATCHAPI ApplyPatchToFileExA(LPCSTR PatchFileName,LPCSTR OldFileName,LPCSTR NewFileName,ULONG ApplyOptionFlags,PPATCH_PROGRESS_CALLBACK ProgressCallback,PVOID CallbackContext);
  WINBOOL PATCHAPI ApplyPatchToFileExW(LPCWSTR PatchFileName,LPCWSTR OldFileName,LPCWSTR NewFileName,ULONG ApplyOptionFlags,PPATCH_PROGRESS_CALLBACK ProgressCallback,PVOID CallbackContext);
#define ApplyPatchToFileEx __MINGW_NAME_AW(ApplyPatchToFileEx)

  WINBOOL PATCHAPI GetFilePatchSignatureA(LPCSTR FileName,ULONG OptionFlags,PVOID OptionData,ULONG IgnoreRangeCount,PPATCH_IGNORE_RANGE IgnoreRangeArray,ULONG RetainRangeCount,PPATCH_RETAIN_RANGE RetainRangeArray,ULONG SignatureBufferSize,PVOID SignatureBuffer);
  WINBOOL PATCHAPI GetFilePatchSignatureW(LPCWSTR FileName,ULONG OptionFlags,PVOID OptionData,ULONG IgnoreRangeCount,PPATCH_IGNORE_RANGE IgnoreRangeArray,ULONG RetainRangeCount,PPATCH_RETAIN_RANGE RetainRangeArray,ULONG SignatureBufferSizeInBytes,PVOID SignatureBuffer);
#define GetFilePatchSignature __MINGW_NAME_AW(GetFilePatchSignature)

  WINBOOL PATCHAPI GetFilePatchSignatureByHandle(HANDLE FileHandle,ULONG OptionFlags,PVOID OptionData,ULONG IgnoreRangeCount,PPATCH_IGNORE_RANGE IgnoreRangeArray,ULONG RetainRangeCount,PPATCH_RETAIN_RANGE RetainRangeArray,ULONG SignatureBufferSize,PVOID SignatureBuffer);
  WINBOOL PATCHAPI CreatePatchFileByHandles(HANDLE OldFileHandle,HANDLE NewFileHandle,HANDLE PatchFileHandle,ULONG OptionFlags,PPATCH_OPTION_DATA OptionData);
  WINBOOL PATCHAPI CreatePatchFileByHandlesEx(ULONG OldFileCount,PPATCH_OLD_FILE_INFO_H OldFileInfoArray,HANDLE NewFileHandle,HANDLE PatchFileHandle,ULONG OptionFlags,PPATCH_OPTION_DATA OptionData,PPATCH_PROGRESS_CALLBACK ProgressCallback,PVOID CallbackContext);
  WINBOOL PATCHAPI ExtractPatchHeaderToFileByHandles(HANDLE PatchFileHandle,HANDLE PatchHeaderFileHandle);
  WINBOOL PATCHAPI TestApplyPatchToFileByHandles(HANDLE PatchFileHandle,HANDLE OldFileHandle,ULONG ApplyOptionFlags);
  WINBOOL PATCHAPI ApplyPatchToFileByHandles(HANDLE PatchFileHandle,HANDLE OldFileHandle,HANDLE NewFileHandle,ULONG ApplyOptionFlags);
  WINBOOL PATCHAPI ApplyPatchToFileByHandlesEx(HANDLE PatchFileHandle,HANDLE OldFileHandle,HANDLE NewFileHandle,ULONG ApplyOptionFlags,PPATCH_PROGRESS_CALLBACK ProgressCallback,PVOID CallbackContext);

WINBOOL PATCHAPI GetFilePatchSignatureByBuffer(PBYTE FileBufferWritable, ULONG FileSize, ULONG OptionFlags, PVOID OptionData, ULONG IgnoreRangeCount, PPATCH_IGNORE_RANGE IgnoreRangeArray, ULONG RetainRangeCount, PPATCH_RETAIN_RANGE RetainRangeArray, ULONG SignatureBufferSize, LPSTR SignatureBuffer);
WINBOOL PATCHAPI ApplyPatchToFileByBuffers(PBYTE PatchFileMapped, ULONG PatchFileSize, PBYTE OldFileMapped, ULONG OldFileSize, PBYTE *NewFileBuffer, ULONG NewFileBufferSize, ULONG *NewFileActualSize, FILETIME *NewFileTime, ULONG ApplyOptionFlags, PPATCH_PROGRESS_CALLBACK ProgressCallback, PVOID CallbackContext);
WINBOOL PATCHAPI TestApplyPatchToFileByBuffers(PBYTE PatchFileBuffer, ULONG PatchFileSize, PBYTE OldFileBuffer, ULONG OldFileSize, ULONG *NewFileSize, ULONG ApplyOptionFlags);

#ifdef __cplusplus
}
#endif

#endif
#endif
