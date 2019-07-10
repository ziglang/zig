/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _COMPRESSAPI_
#define _COMPRESSAPI_

#include <windef.h>

#if NTDDI_VERSION >= 0x06020000

#define COMPRESS_ALGORITHM_INVALID 0
#define COMPRESS_ALGORITHM_NULL 1
#define COMPRESS_ALGORITHM_MSZIP 2
#define COMPRESS_ALGORITHM_XPRESS 3
#define COMPRESS_ALGORITHM_XPRESS_HUFF 4
#define COMPRESS_ALGORITHM_LZMS 5
#define COMPRESS_ALGORITHM_MAX 6

#define COMPRESS_RAW (1 << 29)

#ifdef __cplusplus
extern "C" {
#endif

  typedef enum {
    COMPRESS_INFORMATION_CLASS_INVALID = 0,
    COMPRESS_INFORMATION_CLASS_BLOCK_SIZE,
    COMPRESS_INFORMATION_CLASS_LEVEL
  } COMPRESS_INFORMATION_CLASS;

  DECLARE_HANDLE (COMPRESSOR_HANDLE);

  typedef COMPRESSOR_HANDLE *PCOMPRESSOR_HANDLE;
  typedef COMPRESSOR_HANDLE DECOMPRESSOR_HANDLE;
  typedef COMPRESSOR_HANDLE *PDECOMPRESSOR_HANDLE;
  typedef PVOID (__cdecl *PFN_COMPRESS_ALLOCATE) (PVOID UserContext, SIZE_T Size);
  typedef VOID (__cdecl *PFN_COMPRESS_FREE) (PVOID UserContext, PVOID Memory);

  typedef struct _COMPRESS_ALLOCATION_ROUTINES {
    PFN_COMPRESS_ALLOCATE Allocate;
    PFN_COMPRESS_FREE Free;
    PVOID UserContext;
  } COMPRESS_ALLOCATION_ROUTINES,*PCOMPRESS_ALLOCATION_ROUTINES;

  WINBOOL WINAPI CloseCompressor (COMPRESSOR_HANDLE CompressorHandle);
  WINBOOL WINAPI CloseDecompressor (DECOMPRESSOR_HANDLE DecompressorHandle);
  WINBOOL WINAPI Compress (COMPRESSOR_HANDLE CompressorHandle, PVOID UncompressedData, SIZE_T UncompressedDataSize, PVOID CompressedBuffer, SIZE_T CompressedBufferSize, PSIZE_T CompressedDataSize);
  WINBOOL WINAPI CreateCompressor (DWORD Algorithm, PCOMPRESS_ALLOCATION_ROUTINES AllocationRoutines, PCOMPRESSOR_HANDLE CompressorHandle);
  WINBOOL WINAPI CreateDecompressor (DWORD Algorithm, PCOMPRESS_ALLOCATION_ROUTINES AllocationRoutines, PDECOMPRESSOR_HANDLE DecompressorHandle);
  WINBOOL WINAPI Decompress (DECOMPRESSOR_HANDLE DecompressorHandle, PVOID CompressedData, SIZE_T CompressedDataSize, PVOID UncompressedBuffer, SIZE_T UncompressedBufferSize, PSIZE_T UncompressedDataSize);
  WINBOOL WINAPI QueryCompressorInformation (COMPRESSOR_HANDLE CompressorHandle, COMPRESS_INFORMATION_CLASS CompressInformationClass, PVOID CompressInformation, SIZE_T CompressInformationSize);
  WINBOOL WINAPI QueryDecompressorInformation (DECOMPRESSOR_HANDLE DecompressorHandle, COMPRESS_INFORMATION_CLASS CompressInformationClass, PVOID CompressInformation, SIZE_T CompressInformationSize);
  WINBOOL WINAPI ResetCompressor (COMPRESSOR_HANDLE CompressorHandle);
  WINBOOL WINAPI ResetDecompressor (DECOMPRESSOR_HANDLE DecompressorHandle);
  WINBOOL WINAPI SetCompressorInformation (COMPRESSOR_HANDLE CompressorHandle, COMPRESS_INFORMATION_CLASS CompressInformationClass, PVOID CompressInformation, SIZE_T CompressInformationSize);
  WINBOOL WINAPI SetDecompressorInformation (DECOMPRESSOR_HANDLE DecompressorHandle, COMPRESS_INFORMATION_CLASS CompressInformationClass, PVOID CompressInformation, SIZE_T CompressInformationSize);

#ifdef __cplusplus
}
#endif

#endif
#endif
