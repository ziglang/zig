/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_TXFW32
#define _INC_TXFW32
#include <clfs.h>
#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _TXF_ID {
  __C89_NAMELESS struct {
    LONGLONG LowPart;
    LONGLONG HighPart;
  } DUMMYSTRUCTNAME;
} TXF_ID, *PTXF_ID;

typedef struct _TXF_LOG_RECORD_AFFECTED_FILE {
  USHORT Version;
  ULONG  RecordLength;
  ULONG  Flags;
  TXF_ID TxfFileId;
  UUID   KtmGuid;
  ULONG  FileNameLength;
  ULONG  FileNameByteOffsetInStructure;
} TXF_LOG_RECORD_AFFECTED_FILE, *PTXF_LOG_RECORD_AFFECTED_FILE;

typedef struct _TXF_LOG_RECORD_TRUNCATE {
  USHORT   Version;
  USHORT   RecordType;
  ULONG    RecordLength;
  ULONG    Flags;
  TXF_ID   TxfFileId;
  UUID     KtmGuid;
  LONGLONG NewFileSize;
  ULONG    FileNameLength;
  ULONG    FileNameByteOffsetInStructure;
} TXF_LOG_RECORD_TRUNCATE, *PTXF_LOG_RECORD_TRUNCATE;

typedef struct _TXF_LOG_RECORD_WRITE {
  USHORT   Version;
  USHORT   RecordType;
  ULONG    RecordLength;
  ULONG    Flags;
  TXF_ID   TxfFileId;
  UUID     KtmGuid;
  LONGLONG ByteOffsetInFile;
  ULONG    NumBytesWritten;
  ULONG    ByteOffsetInStructure;
  ULONG    FileNameLength;
  ULONG    FileNameByteOffsetInStructure;
} TXF_LOG_RECORD_WRITE, *PTXF_LOG_RECORD_WRITE;

#define TXF_LOG_RECORD_TYPE_WRITE 1
#define TXF_LOG_RECORD_TYPE_TRUNCATE 2
#define TXF_LOG_RECORD_TYPE_AFFECTED_FILE 4

typedef struct _TXF_LOG_RECORD_BASE {
  USHORT Version;
  USHORT RecordType;
  ULONG  RecordLength;
} TXF_LOG_RECORD_BASE, *PTXF_LOG_RECORD_BASE;

WINBOOL WINAPI TxfLogCreateFileReadContext(
  LPCWSTR LogPath,
  CLFS_LSN BeginningLsn,
  CLFS_LSN EndingLSN,
  PTXF_ID TxfFileId,
  PVOID *TxfLogContext
);

WINBOOL WINAPI TxfLogDestroyReadContext(
  PVOID TxfLogContext
);

WINBOOL WINAPI TxfLogReadRecords(
  PVOID TxfLogContext,
  ULONG BufferLength,
  PVOID Buffer,
  PULONG BytesUsed,
  PULONG RecordCount
);

#ifdef __cplusplus
}
#endif
#endif /* (_WIN32_WINNT >= 0x0600) */
#endif /*_INC_TXFW32*/
