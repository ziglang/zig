#ifndef _MSPORTS_
#define _MSPORTS_

#ifdef __cplusplus
extern "C" {
#endif

DECLARE_HANDLE(HCOMDB);
typedef HCOMDB *PHCOMDB;
#define HCOMDB_INVALID_HANDLE_VALUE ((HCOMDB)INVALID_HANDLE_VALUE)

/* Limits for ComDBResizeDatabase NewSize */
#define COMDB_MIN_PORTS_ARBITRATED 256
#define COMDB_MAX_PORTS_ARBITRATED 4096

/* ReportType flags for ComDBGetCurrentPortUsage */
#define CDB_REPORT_BITS  0x0
#define CDB_REPORT_BYTES 0x1

LONG
WINAPI
ComDBClaimNextFreePort(IN HCOMDB hComDB,
                       OUT LPDWORD ComNumber);

LONG
WINAPI
ComDBClaimPort(IN HCOMDB hComDB,
               IN DWORD ComNumber,
               IN BOOL ForceClaim,
               OUT PBOOL Forced);

LONG
WINAPI
ComDBClose(IN HCOMDB hComDB);

LONG
WINAPI
ComDBGetCurrentPortUsage(IN HCOMDB hComDB,
                         OUT PBYTE Buffer,
                         IN DWORD BufferSize,
                         IN DWORD ReportType,
                         OUT LPDWORD MaxPortsReported);

LONG
WINAPI
ComDBOpen(OUT HCOMDB *phComDB);

LONG
WINAPI
ComDBReleasePort(IN HCOMDB hComDB,
                 IN DWORD ComNumber);

LONG
WINAPI
ComDBResizeDatabase(IN HCOMDB hComDB,
                    IN DWORD NewSize);

#ifdef __cplusplus
}
#endif

#endif /* _MSPORTS_ */
