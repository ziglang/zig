/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _SCHEDULE_H_
#define _SCHEDULE_H_

#ifdef __cplusplus
extern "C" {
#endif

#define SCHEDULE_INTERVAL 0
#define SCHEDULE_BANDWIDTH 1
#define SCHEDULE_PRIORITY 2

  typedef struct _SCHEDULE_HEADER {
    ULONG Type;
    ULONG Offset;
  } SCHEDULE_HEADER,*PSCHEDULE_HEADER;

  typedef struct _SCHEDULE {
    ULONG Size;
    ULONG Bandwidth;
    ULONG NumberOfSchedules;
    SCHEDULE_HEADER Schedules[1];
  } SCHEDULE,*PSCHEDULE;

#define SCHEDULE_DATA_ENTRIES (7*24)

#ifdef __cplusplus
}
#endif
#endif
