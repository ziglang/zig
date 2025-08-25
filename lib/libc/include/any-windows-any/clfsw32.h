/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_CLFSW32
#define _INC_CLFSW32
#include <clfs.h>
#include <clfsmgmt.h>

#if (_WIN32_WINNT >= 0x0600)
#ifdef __cplusplus
extern "C" {
#endif

typedef PVOID (* CLFS_BLOCK_ALLOCATION) (ULONG cbBufferSize, PVOID pvUserContext);
typedef void  (* CLFS_BLOCK_DEALLOCATION) (PVOID pvBuffer, PVOID pvUserContext);
typedef FILE *PFILE;
typedef ULONG (__stdcall * CLFS_PRINT_RECORD_ROUTINE) (PFILE, CLFS_RECORD_TYPE, PVOID, ULONG);

WINBOOL WINAPI AdvanceLogBase(PVOID pvMarshal,PCLFS_LSN plsnBase,ULONG fFlags,LPOVERLAPPED pOverlapped);

WINBOOL WINAPI AlignReservedLog(PVOID pvMarshal,ULONG cReservedRecords,LONGLONG rgcbReservation,PLONGLONG pcbAlignReservation);
WINBOOL WINAPI AllocReservedLog(PVOID pvMarshal,ULONG cReservedRecords,PLONGLONG pcbAdjustment);

WINBOOL WINAPI AddLogContainer(HANDLE hLog,PULONGLONG pcbContainer,LPWSTR pwszContainerPath,LPVOID pReserved);
WINBOOL WINAPI AddLogContainerSet(HANDLE hLog,USHORT cContainers,PULONGLONG pcbContainer,LPWSTR *rgwszContainerPath,PVOID Reserved);
WINBOOL WINAPI CloseAndResetLogFile(HANDLE hLog);

WINBOOL WINAPI CreateLogContainerScanContext(
  HANDLE hLog,
  ULONG cFromContainer,
  ULONG cContainers,
  CLFS_SCAN_MODE eScanMode,
  PCLFS_SCAN_CONTEXT pcxScan,
  LPOVERLAPPED pOverlapped
);

HANDLE WINAPI CreateLogFile(
  LPCWSTR pszLogFileName,
  ACCESS_MASK fDesiredAccess,
  DWORD dwShareMode,
  LPSECURITY_ATTRIBUTES psaLogFile,
  ULONG fCreateDisposition,
  ULONG fFlagsAndAttributes
);

WINBOOL WINAPI ScanLogContainers(
  PCLFS_SCAN_CONTEXT pcxScan,
  CLFS_SCAN_MODE eScanMode,
  LPVOID pReserved
);

WINBOOL WINAPI CreateLogMarshallingArea(
  HANDLE hLog,
  CLFS_BLOCK_ALLOCATION pfnAllocBuffer,
  CLFS_BLOCK_DEALLOCATION pfnFreeBuffer,
  PVOID   pvBlockAllocContext,
  ULONG cbMarshallingBuffer,
  ULONG  cMaxWriteBuffers,
  ULONG cMaxReadBuffers,
  PVOID *ppvMarshal
);

WINBOOL WINAPI DeleteLogMarshallingArea(
  PVOID pvMarshal
);

WINBOOL WINAPI DeleteLogByHandle(
  HANDLE hLog
);

WINBOOL WINAPI DeleteLogFile(
  LPCWSTR pszLogFileName,
  PVOID pvReserved
);

WINBOOL WINAPI DeregisterManageableLogClient(
  HANDLE hLog
);

WINBOOL WINAPI DumpLogRecords(
  PWSTR pwszLogFileName,
  CLFS_RECORD_TYPE fRecordType,
  PCLFS_LSN plsnStart,
  PCLFS_LSN plsnEnd,
  PFILE pstrmOut,
  CLFS_PRINT_RECORD_ROUTINE pfnPrintRecord,
  CLFS_BLOCK_ALLOCATION pfnAllocBlock,
  CLFS_BLOCK_DEALLOCATION pfnFreeBlock,
  PVOID   pvBlockAllocContext,
  ULONG cbBlock,
  ULONG cMaxBlocks
);

WINBOOL WINAPI ReadLogRecord(
  PVOID pvMarshal,
  PCLFS_LSN plsnFirst,
  CLFS_CONTEXT_MODE eContextMode,
  PVOID *ppvReadBuffer,
  PULONG pcbReadBuffer,
  PCLFS_RECORD_TYPE peRecordType,
  PCLFS_LSN plsnUndoNext,
  PCLFS_LSN plsnPrevious,
  PVOID *ppvReadContext,
  LPOVERLAPPED pOverlapped
);

WINBOOL WINAPI ReadNextLogRecord(
  PVOID pvReadContext,
  PVOID *ppvBuffer,
  PULONG pcbBuffer,
  PCLFS_RECORD_TYPE peRecordType,
  PCLFS_LSN plsnUser,
  PCLFS_LSN plsnUndoNext,
  PCLFS_LSN plsnPrevious,
  PCLFS_LSN plsnRecord,
  LPOVERLAPPED pOverlapped
);

WINBOOL WINAPI FlushLogBuffers(
  PVOID pvMarshal,
  LPOVERLAPPED pOverlapped
);

WINBOOL WINAPI FlushLogToLsn(
  PVOID pvMarshalContext,
  PCLFS_LSN plsnFlush,
  PCLFS_LSN plsnLastFlushed,
  LPOVERLAPPED pOverlapped
);

WINBOOL WINAPI FreeReservedLog(
  PVOID pvMarshal,
  ULONG cReservedRecords,
  PLONGLONG pcbAdjustment
);

WINBOOL WINAPI GetLogContainerName(
  HANDLE hLog,
  CLFS_CONTAINER_ID cidLogicalContainer,
  LPCWSTR pwstrContainerName,
  ULONG cLenContainerName,
  PULONG pcActualLenContainerName
);

WINBOOL WINAPI GetLogFileInformation(
  HANDLE hLog,
  PCLFS_INFORMATION pinfoBuffer,
  PULONG cbBuffer
);

WINBOOL WINAPI GetLogIoStatistics(
  HANDLE hLog,
  PVOID pvStatsBuffer,
  ULONG cbStatsBuffer,
  CLFS_IOSTATS_CLASS eStatsClass,
  PULONG pcbStatsWritten
);

typedef LPVOID CLFS_LOG_ARCHIVE_CONTEXT;
typedef CLFS_LOG_ARCHIVE_CONTEXT *PCLFS_LOG_ARCHIVE_CONTEXT;

WINBOOL WINAPI GetNextLogArchiveExtent(
  CLFS_LOG_ARCHIVE_CONTEXT pvArchiveContext,
  CLFS_ARCHIVE_DESCRIPTOR rgadExtent[],
  ULONG cDescriptors,
  PULONG pcDescriptorsReturned
);

WINBOOL WINAPI PrepareLogArchive(
  HANDLE hLog,
  PWSTR pszBaseLogFileName,
  ULONG cLen,
  const PCLFS_LSN plsnLow,
  const PCLFS_LSN plsnHigh,
  PULONG pcActualLength,
  PULONGLONG poffBaseLogFileData,
  PULONGLONG pcbBaseLogFileLength,
  PCLFS_LSN plsnBase,
  PCLFS_LSN plsnLast,
  PCLFS_LSN plsnCurrentArchiveTail,
  PCLFS_LOG_ARCHIVE_CONTEXT ppvArchiveContext
);

WINBOOL WINAPI TerminateLogArchive(
  CLFS_LOG_ARCHIVE_CONTEXT pvArchiveContext
);

ULONG WINAPI LsnBlockOffset(
  const CLFS_LSN *plsn
);

CLFS_CONTAINER_ID WINAPI LsnContainer(
  const CLFS_LSN *plsn
);

CLFS_LSN WINAPI LsnCreate(
  CLFS_CONTAINER_ID cidContainer,
  ULONG offBlock,
  ULONG cRecord
);

ULONG WINAPI LsnRecordSequence(
  const CLFS_LSN *plsn
);

WINBOOL WINAPI PrepareLogArchive(
  HANDLE hLog,
  PWSTR pszBaseLogFileName,
  ULONG cLen,
  const PCLFS_LSN plsnLow,
  const PCLFS_LSN plsnHigh,
  PULONG pcActualLength,
  PULONGLONG poffBaseLogFileData,
  PULONGLONG pcbBaseLogFileLength,
  PCLFS_LSN plsnBase,
  PCLFS_LSN plsnLast,
  PCLFS_LSN plsnCurrentArchiveTail,
  PCLFS_LOG_ARCHIVE_CONTEXT ppvArchiveContext
);

WINBOOL WINAPI QueryLogPolicy(
  HANDLE hLog,
  CLFS_MGMT_POLICY_TYPE ePolicyType,
  PCLFS_MGMT_POLICY pPolicyBuffer,
  PULONG pcbPolicyBuffer
);

WINBOOL WINAPI ReadLogArchiveMetadata(
  CLFS_LOG_ARCHIVE_CONTEXT pvArchiveContext,
  ULONG cbOffset,
  ULONG cbBytesToRead,
  PBYTE pbReadBuffer,
  PULONG pcbBytesRead
);

WINBOOL WINAPI ReadLogRestartArea(
  PVOID pvMarshal,
  PVOID *ppvRestartBuffer,
  PULONG pcbRestartBuffer,
  PCLFS_LSN plsn,
  PVOID *ppvContext,
  LPOVERLAPPED pOverlapped
);

WINBOOL WINAPI ReadPreviousLogRestartArea(
  PVOID pvReadContext,
  PVOID *ppvRestartBuffer,
  PULONG pcbRestartBuffer,
  PCLFS_LSN plsnRestart,
  LPOVERLAPPED pOverlapped
);

WINBOOL WINAPI RemoveLogContainer(
  HANDLE hLog,
  LPWSTR pwszContainerPath,
  WINBOOL fForce,
  LPVOID pReserved
);

WINBOOL WINAPI RemoveLogContainerSet(
  HANDLE hLog,
  USHORT cContainers,
  LPWSTR *rgwszContainerPath,
  WINBOOL fForce,
  LPVOID pReserved
);

WINBOOL WINAPI ReserveAndAppendLog(
  PVOID pvMarshal,
  PCLFS_WRITE_ENTRY rgWriteEntries,
  ULONG cWriteEntries,
  PCLFS_LSN plsnUndoNext,
  PCLFS_LSN plsnPrevious,
  ULONG cReserveRecords,
  LONGLONG rgcbReservation[],
  ULONG fFlags,
  PCLFS_LSN plsn,
  LPOVERLAPPED pOverlapped
);

WINBOOL WINAPI ReserveAndAppendLogAligned(
  PVOID pvMarshal,
  PCLFS_WRITE_ENTRY rgWriteEntries,
  ULONG cWriteEntries,
  ULONG cbEntryAlignment,
  PCLFS_LSN plsnUndoNext,
  PCLFS_LSN plsnPrevious,
  ULONG cReserveRecords,
  LONGLONG rgcbReservation[],
  ULONG fFlags,
  PCLFS_LSN plsn,
  LPOVERLAPPED overlapped
);

WINBOOL WINAPI SetEndOfLog(
  HANDLE hLog,
  PCLFS_LSN plsnEnd,
  LPOVERLAPPED lpOverlapped
);

WINBOOL WINAPI SetLogArchiveMode(
  HANDLE hLog,
  CLFS_LOG_ARCHIVE_MODE eMode
);

WINBOOL WINAPI SetLogArchiveTail(
  HANDLE hLog,
  PCLFS_LSN plsnArchiveTail,
  LPVOID pReserved
);

WINBOOL WINAPI TerminateReadLog(
  PVOID pvCursorContext
);

WINBOOL WINAPI ValidateLog(
  LPCWSTR pszLogFileName,
  LPSECURITY_ATTRIBUTES psaLogFile,
  PCLFS_INFORMATION pinfoBuffer,
  PULONG pcbBuffer
);

#ifdef __cplusplus
}
#endif
#endif /* (_WIN32_WINNT >= 0x0600) */
#endif /*_INC_CLFSW32*/
