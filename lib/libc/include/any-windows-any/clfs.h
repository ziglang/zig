/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_CLFS
#define _INC_CLFS
#if (_WIN32_WINNT >= 0x0600)
#ifdef __cplusplus
extern "C" {
#endif

typedef enum  {
  ClfsContextNone       = 0x00,
  ClfsContextUndoNext,
  ClfsContextPrevious,
  ClfsContextForward 
} CLFS_CONTEXT_MODE, *PCLFS_CONTEXT_MODE, **PPCLFS_CONTEXT_MODE;

typedef enum _CLFS_IOSTATS_CLASS {
  ClfsIoStatsDefault   = 0x0000,
  ClfsIoStatsMax       = 0xFFFF 
} CLFS_IOSTATS_CLASS, *PCLFS_IOSTATS_CLASS, **PPCLFS_IOSTATS_CLASS;

typedef enum _CLFS_LOG_ARCHIVE_MODE {
  ClfsLogArchiveEnabled    = 0x01,
  ClfsLogArchiveDisabled   = 0x02 
} CLFS_LOG_ARCHIVE_MODE, *PCLFS_LOG_ARCHIVE_MODE;

typedef enum _CLFS_RECORD_TYPE {
  ClfsDataRecord = 0x01,
  ClfsRestartRecord = 0x02,
  ClfsClientRecord = 0x3F 
} CLFS_RECORD_TYPE, *PCLFS_RECORD_TYPE;

typedef union _CLFS_LSN {
  ULONGLONG Internal;
} CLFS_LSN, *PCLFS_LSN;

/*http://msdn.microsoft.com/en-us/library/bb540355%28VS.85%29.aspx*/
typedef enum _CLFS_SCAN_MODE {
  CLFS_SCAN_INIT = 0x01,
  CLFS_SCAN_FORWARD = 0x02,
  CLFS_SCAN_BACKWARD = 0x04,
  CLFS_SCAN_CLOSE = 0x08,
  CLFS_SCAN_INITIALIZED = 0x10,
  CLFS_SCAN_BUFFERED = 0x20
} CLFS_SCAN_MODE;

/* enum guessed from http://msdn.microsoft.com/en-us/library/bb540336%28VS.85%29.aspx */
typedef enum _CLFS_CONTAINER_STATE {
  ClfsContainerInitializing = 0x01,
  ClfsContainerInactive = 0x02,
  ClfsContainerActive = 0x04,
  ClfsContainerActivePendingDelete = 0x08,
  ClfsContainerPendingArchive = 0x10,
  ClfsContainerPendingArchiveAndDelete = 0x20
} CLFS_CONTAINER_STATE;

typedef DWORD CLFS_CONTAINER_ID;

/* Goes in wdm.h */
typedef struct _CLFS_CONTAINER_INFORMATION {
  ULONG                FileAttributes;
  ULONGLONG            CreationTime;
  ULONGLONG            LastAccessTime;
  ULONGLONG            LastWriteTime;
  LONGLONG             ContainerSize;
  ULONG                FileNameActualLength;
  ULONG                FileNameLength;
  WCHAR                FileName[MAX_PATH];
  CLFS_CONTAINER_STATE State;
  CLFS_CONTAINER_ID    PhysicalContainerId;
  CLFS_CONTAINER_ID    LogicalContainerId;
} CLFS_CONTAINER_INFORMATION, *PCLFS_CONTAINER_INFORMATION, **PPCLFS_CONTAINER_INFORMATION;
/**/

typedef struct _CLFS_IO_STATISTICS_HEADER {
  UCHAR              ubMajorVersion;
  UCHAR              ubMinorVersion;
  CLFS_IOSTATS_CLASS eStatsClass;
  USHORT             cbLength;
  ULONG              coffData;
} CLFS_IO_STATISTICS_HEADER, *PCLFS_IO_STATISTICS_HEADER, **PPCLFS_IO_STATISTICS_HEADER;

typedef struct _CLFS_ARCHIVE_DESCRIPTOR {
  ULONGLONG                  coffLow;
  ULONGLONG                  coffHigh;
  CLFS_CONTAINER_INFORMATION infoContainer;
} CLFS_ARCHIVE_DESCRIPTOR, *PCLFS_ARCHIVE_DESCRIPTOR, **PPCLFS_ARCHIVE_DESCRIPTOR;

typedef struct _CLFS_INFORMATION {
  LONGLONG  TotalAvailable;
  LONGLONG  CurrentAvailable;
  LONGLONG  TotalReservation;
  ULONGLONG BaseFileSize;
  ULONGLONG ContainerSize;
  ULONG     TotalContainers;
  ULONG     FreeContainers;
  ULONG     TotalClients;
  ULONG     Attributes;
  ULONG     FlushThreshold;
  ULONG     SectorSize;
  CLFS_LSN  MinArchiveTailLsn;
  CLFS_LSN  BaseLsn;
  CLFS_LSN  LastFlushedLsn;
  CLFS_LSN  LastLsn;
  CLFS_LSN  RestartLsn;
  GUID      Identity;
} CLFS_INFORMATION, *PCLFS_INFORMATION, **PPCLFS_INFORMATION;

typedef struct _CLFS_IO_STATISTICS {
  CLFS_IO_STATISTICS_HEADER hdrIoStats;
  ULONGLONG                 cFlush;
  ULONGLONG                 cbFlush;
  ULONGLONG                 cMetaFlush;
  ULONGLONG                 cbMetaFlush;
} CLFS_IO_STATISTICS, *PCLFS_IO_STATISTICS, **PPCLFS_IO_STATISTICS;

typedef struct _CLFS_NODE_ID {
  ULONG cType;
  ULONG cbNode;
} CLFS_NODE_ID, *PCLFS_NODE_ID;

typedef struct _CLFS_SCAN_CONTEXT {
  CLFS_NODE_ID                cidNode;
  HANDLE                      hLog;
  ULONG                       cIndex;
  ULONG                       cContainers;
  ULONG                       cContainersReturned;
  CLFS_SCAN_MODE              eScanMode;
  PCLFS_CONTAINER_INFORMATION pinfoContainer;
} CLFS_SCAN_CONTEXT, *PCLFS_SCAN_CONTEXT;

typedef struct _CLFS_WRITE_ENTRY {
  PVOID Buffer;
  ULONG ByteLength;
} CLFS_WRITE_ENTRY, *PCLFS_WRITE_ENTRY;

WINBOOL WINAPI LsnEqual(
  const CLFS_LSN *plsn1,
  const CLFS_LSN *plsn2
);

WINBOOL WINAPI LsnGreater(
  const CLFS_LSN *plsn1,
  const CLFS_LSN *plsn2
);

WINBOOL WINAPI LsnLess(
  const CLFS_LSN *plsn1,
  const CLFS_LSN *plsn2
);

WINBOOL WINAPI LsnNull(
  const CLFS_LSN *plsn
);

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_CLFS*/
