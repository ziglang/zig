/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_PLA
#define _INC_PLA
#if (_WIN32_WINNT >= 0x0600)

typedef enum _AutoPathFormat {
  plaNone                 = 0x0000,
  plaPattern              = 0x0001,
  plaComputer             = 0x0002,
  plaMonthDayHour         = 0x0100,
  plaSerialNumber         = 0x0200,
  plaYearDayOfYear        = 0x0400,
  plaYearMonth            = 0x0800,
  plaYearMonthDay         = 0x1000,
  plaYearMonthDayHour     = 0x2000,
  plaMonthDayHourMinute   = 0x4000 
} AutoPathFormat;

typedef enum _ClockType {
  plaTimeStamp     = 0,
  plaPerformance   = 1,
  plaSystem        = 2,
  plaCycle         = 3 
} ClockType;

typedef enum _CommitMode {
  plaCreateNew               = 0x0001,
  plaModify                  = 0x0002,
  plaCreateOrModify          = 0x0003,
  plaUpdateRunningInstance   = 0x0010,
  plaFlushTrace              = 0x0020,
  plaValidateOnly            = 0x1000 
} CommitMode;

typedef enum _FileFormat {
  plaCommaSeparated   = 0,
  plaTabSeparated     = 1,
  plaSql              = 2,
  plaBinary           = 3 
} FileFormat;

typedef enum _FolderActionSteps {
  plaCreateCab      = 0x01,
  plaDeleteData     = 0x02,
  plaSendCab        = 0x04,
  plaDeleteCab      = 0x08,
  plaDeleteReport   = 0x10 
} FolderActionSteps;

typedef enum _ResourcePolicy {
  plaDeleteLargest   = 0,
  plaDeleteOldest    = 1 
} ResourcePolicy;

typedef enum _StreamMode {
  plaFile        = 0x0001,
  plaRealTime    = 0x0002,
  plaBoth        = 0x0003,
  plaBuffering   = 0x0004 
} StreamMode;

typedef enum _ValueMapType {
  plaIndex        = 1,
  plaFlag         = 2,
  plaFlagArray    = 3,
  plaValidation   = 4 
} ValueMapType;

typedef enum _WeekDays {
  plaRunOnce     = 0x00,
  plaSunday      = 0x01,
  plaMonday      = 0x02,
  plaTuesday     = 0x04,
  plaWednesday   = 0x08,
  plaThursday    = 0x10,
  plaFriday      = 0x20,
  plaSaturday    = 0x40,
  plaEveryday    = 0x7F 
} WeekDays;

#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_PLA*/
