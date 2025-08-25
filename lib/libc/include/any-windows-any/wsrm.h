/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _WSRM_H_
#define _WSRM_H_

#define IPPROTO_RM 113
#define MAX_MCAST_TTL 255

#define RM_OPTIONSBASE 1000
#define RM_RATE_WINDOW_SIZE (RM_OPTIONSBASE + 1)
#define RM_SET_MESSAGE_BOUNDARY (RM_OPTIONSBASE + 2)
#define RM_FLUSHCACHE (RM_OPTIONSBASE + 3)
#define RM_SENDER_WINDOW_ADVANCE_METHOD (RM_OPTIONSBASE + 4)
#define RM_SENDER_STATISTICS (RM_OPTIONSBASE + 5)
#define RM_LATEJOIN (RM_OPTIONSBASE + 6)
#define RM_SET_SEND_IF (RM_OPTIONSBASE + 7)
#define RM_ADD_RECEIVE_IF (RM_OPTIONSBASE + 8)
#define RM_DEL_RECEIVE_IF (RM_OPTIONSBASE + 9)
#define RM_SEND_WINDOW_ADV_RATE (RM_OPTIONSBASE + 10)
#define RM_USE_FEC (RM_OPTIONSBASE + 11)
#define RM_SET_MCAST_TTL (RM_OPTIONSBASE + 12)
#define RM_RECEIVER_STATISTICS (RM_OPTIONSBASE + 13)
#define RM_HIGH_SPEED_INTRANET_OPT (RM_OPTIONSBASE + 14)

#define SENDER_DEFAULT_RATE_KBITS_PER_SEC 56
#define SENDER_DEFAULT_WINDOW_SIZE_BYTES 10 *1000*1000
#define SENDER_DEFAULT_WINDOW_ADV_PERCENTAGE 15

#define MAX_WINDOW_INCREMENT_PERCENTAGE 25
#define SENDER_DEFAULT_LATE_JOINER_PERCENTAGE 0
#define SENDER_MAX_LATE_JOINER_PERCENTAGE 75

#define BITS_PER_BYTE 8
#define LOG2_BITS_PER_BYTE 3

enum eWINDOW_ADVANCE_METHOD {
  E_WINDOW_ADVANCE_BY_TIME = 1,E_WINDOW_USE_AS_DATA_CACHE
};

typedef struct _RM_SEND_WINDOW {
  ULONG RateKbitsPerSec;
  ULONG WindowSizeInMSecs;
  ULONG WindowSizeInBytes;
} RM_SEND_WINDOW;

typedef struct _RM_SENDER_STATS {
  ULONGLONG DataBytesSent;
  ULONGLONG TotalBytesSent;
  ULONGLONG NaksReceived;
  ULONGLONG NaksReceivedTooLate;
  ULONGLONG NumOutstandingNaks;
  ULONGLONG NumNaksAfterRData;
  ULONGLONG RepairPacketsSent;
  ULONGLONG BufferSpaceAvailable;
  ULONGLONG TrailingEdgeSeqId;
  ULONGLONG LeadingEdgeSeqId;
  ULONGLONG RateKBitsPerSecOverall;
  ULONGLONG RateKBitsPerSecLast;
  ULONGLONG TotalODataPacketsSent;
} RM_SENDER_STATS;

typedef struct _RM_RECEIVER_STATS {
  ULONGLONG NumODataPacketsReceived;
  ULONGLONG NumRDataPacketsReceived;
  ULONGLONG NumDuplicateDataPackets;
  ULONGLONG DataBytesReceived;
  ULONGLONG TotalBytesReceived;
  ULONGLONG RateKBitsPerSecOverall;
  ULONGLONG RateKBitsPerSecLast;
  ULONGLONG TrailingEdgeSeqId;
  ULONGLONG LeadingEdgeSeqId;
  ULONGLONG AverageSequencesInWindow;
  ULONGLONG MinSequencesInWindow;
  ULONGLONG MaxSequencesInWindow;
  ULONGLONG FirstNakSequenceNumber;
  ULONGLONG NumPendingNaks;
  ULONGLONG NumOutstandingNaks;
  ULONGLONG NumDataPacketsBuffered;
  ULONGLONG TotalSelectiveNaksSent;
  ULONGLONG TotalParityNaksSent;
} RM_RECEIVER_STATS;

typedef struct _RM_FEC_INFO {
  USHORT FECBlockSize;
  USHORT FECProActivePackets;
  UCHAR FECGroupSize;
  BOOLEAN fFECOnDemandParityEnabled;
} RM_FEC_INFO;

#endif
