/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <mpeg2data.h>
#include <mpeg2bits.h>

#ifndef __INC_MPEG2STRUCTS__
#define __INC_MPEG2STRUCTS__

typedef enum _MPEG_CONTEXT_TYPE {
  MPEG_CONTEXT_BCS_DEMUX = 0,
  MPEG_CONTEXT_WINSOCK 
} MPEG_CONTEXT_TYPE;

typedef enum _MPEG_CURRENT_NEXT_BIT {
  MPEG_SECTION_IS_NEXT      = 0,
  MPEG_SECTION_IS_CURRENT   = 1 
} MPEG_CURRENT_NEXT_BIT;

typedef enum _MPEG_REQUEST_TYPE {
  MPEG_RQST_UNKNOWN               = 0,
  MPEG_RQST_GET_SECTION,
  MPEG_RQST_GET_SECTION_ASYNC,
  MPEG_RQST_GET_TABLE,
  MPEG_RQST_GET_TABLE_ASYNC,
  MPEG_RQST_GET_SECTIONS_STREAM,
  MPEG_RQST_GET_PES_STREAM,
  MPEG_RQST_GET_TS_STREAM,
  MPEG_RQST_START_MPE_STREAM 
} MPEG_REQUEST_TYPE;

typedef struct _DSMCC_ELEMENT {
  PID                   pid;
  BYTE                  bComponentTag;
  DWORD                 dwCarouselId;
  DWORD                 dwTransactionId;
  struct _DSMCC_ELEMENT *pNext;
} DSMCC_ELEMENT, *PDSMCC_ELEMENT;

typedef struct {
  WINBOOL  fSpecifyProtocol;
  BYTE  Protocol;
  WINBOOL  fSpecifyType;
  BYTE  Type;
  WINBOOL  fSpecifyMessageId;
  WORD  MessageId;
  WINBOOL  fSpecifyTransactionId;
  WINBOOL  fUseTrxIdMessageIdMask;
  DWORD TransactionId;
  WINBOOL  fSpecifyModuleVersion;
  BYTE  ModuleVersion;
  WINBOOL  fSpecifyBlockNumber;
  WORD  BlockNumber;
  WINBOOL  fGetModuleCall;
  WORD  NumberOfBlocksInModule;
} DSMCC_FILTER_OPTIONS;

typedef struct _MPEG_HEADER_BITS_MIDL {
  WORD Bits;
} MPEG_HEADER_BITS_MIDL;

typedef struct _MPEG_HEADER_VERSION_BITS_MIDL {
    BYTE Bits;
} MPEG_HEADER_VERSION_BITS_MIDL;

typedef struct _DSMCC_SECTION {
  TID   TableId;
  __C89_NAMELESS union {
    MPEG_HEADER_BITS_MIDL S;
    WORD                  W;
  } Header;
  WORD  TableIdExtension;
  __C89_NAMELESS union {
    MPEG_HEADER_VERSION_BITS_MIDL S;
    BYTE                          B;
  } Version;
  BYTE  SectionNumber;
  BYTE  LastSectionNumber;
  BYTE  ProtocolDiscriminator;
  BYTE  DsmccType;
  WORD  MessageId;
  DWORD TransactionId;
  BYTE  Reserved;
  BYTE  AdaptationLength;
  WORD  MessageLength;
  BYTE  RemainingData[1];
} DSMCC_SECTION, *PDSMCC_SECTION;

typedef struct _DVB_EIT_FILTER_OPTIONS {
  WINBOOL fSpecifySegment;
  BYTE bSegment;
} DVB_EIT_FILTER_OPTIONS, *PDVB_EIT_FILTER_OPTIONS;

typedef struct {
  TID   TableId;
  __C89_NAMELESS union {
    MPEG_HEADER_BITS_MIDL S;
    WORD                  W;
  } Header;
  WORD  TableIdExtension;
  __C89_NAMELESS union {
    MPEG_HEADER_VERSION_BITS_MIDL S;
    BYTE                          B;
  } Version;
  BYTE  SectionNumber;
  BYTE  LastSectionNumber;
  BYTE  RemainingData[1];
} LONG_SECTION, *PLONG_SECTION;

typedef struct _MPE_ELEMENT {
  PID                 pid;
  BYTE                bComponentTag;
  struct _MPE_ELEMENT *pNext;
} MPE_ELEMENT, *PMPE_ELEMENT;

typedef struct _MPEG2_FILTER {
  BYTE                 bVersionNumber;
  WORD                 wFilterSize;
  WINBOOL              fUseRawFilteringBits;
  BYTE                 Filter[16];
  BYTE                 Mask[16];
  WINBOOL              fSpecifyTableIdExtension;
  WORD                 TableIdExtension;
  WINBOOL              fSpecifyVersion;
  BYTE                 Version;
  WINBOOL              fSpecifySectionNumber;
  BYTE                 SectionNumber;
  WINBOOL              fSpecifyCurrentNext;
  WINBOOL              fNext;
  WINBOOL              fSpecifyDsmccOptions;
  DSMCC_FILTER_OPTIONS Dsmcc;
  WINBOOL              fSpecifyAtscOptions;
  ATSC_FILTER_OPTIONS  Atsc;
} MPEG2_FILTER, *PMPEG2_FILTER;

typedef struct {
  BYTE                   bVersionNumber;
  WORD                   wFilterSize;
  WINBOOL                fUseRawFilteringBits;
  BYTE                   Filter[16];
  BYTE                   Mask[16];
  WINBOOL                fSpecifyTableIdExtension;
  WORD                   TableIdExtension;
  WINBOOL                fSpecifyVersion;
  BYTE                   Version;
  WINBOOL                fSpecifySectionNumber;
  BYTE                   SectionNumber;
  WINBOOL                fSpecifyCurrentNext;
  WINBOOL                fNext;
  WINBOOL                fSpecifyDsmccOptions;
  DSMCC_FILTER_OPTIONS   Dsmcc;
  WINBOOL                fSpecifyAtscOptions;
  ATSC_FILTER_OPTIONS    Atsc;
  WINBOOL                 fSpecifyDvbEitOptions;
  DVB_EIT_FILTER_OPTIONS Dvb_Eit;
} MPEG2_FILTER2, *PMPEG2_FILTER2;

typedef struct _MPEG_BCS_DEMUX {
  DWORD AVMGraphId;
} MPEG_BCS_DEMUX;

typedef struct _MPEG_WINSOCK {
  DWORD AVMGraphId;
} MPEG_WINSOCK;

typedef struct _MPEG_CONTEXT {
  MPEG_CONTEXT_TYPE Type;
  __C89_NAMELESS union {
    MPEG_BCS_DEMUX Demux;
    MPEG_WINSOCK   Winsock;
  } U;
} MPEG_CONTEXT, *PMPEG_CONTEXT;

typedef struct _MPEG_DATE {
  BYTE Date;
  BYTE Month;
  WORD Year;
} MPEG_DATE;

typedef struct _MPEG_TIME {
  BYTE Hours;
  BYTE Minutes;
  BYTE Seconds;
} MPEG_TIME;

typedef struct _MPEG_DATE_AND_TIME {
  MPEG_DATE D;
  MPEG_TIME T;
} MPEG_DATE_AND_TIME;

typedef MPEG_TIME MPEG_DURATION;

typedef struct {
  TID   TableId;
  __C89_NAMELESS union {
    MPEG_HEADER_BITS_MIDL S;
    WORD                  W;
  } Header;
  BYTE  SectionData[1];
} SECTION, *PSECTION;

typedef struct _MPEG_RQST_PACKET {
  DWORD    dwLength;
  PSECTION pSection;
} MPEG_RQST_PACKET, *PMPEG_RQST_PACKET;

typedef struct _MPEG_PACKET_LIST {
  WORD              wPacketCount;
  PMPEG_RQST_PACKET PacketList[1];
} MPEG_PACKET_LIST, *PMPEG_PACKET_LIST;

typedef struct _MPEG_STREAM_BUFFER {
  HRESULT hr;
  DWORD   dwDataBufferSize;
  DWORD   dwSizeOfDataRead;
  BYTE    *pDataBuffer;
} MPEG_STREAM_BUFFER, *PMPEG_STREAM_BUFFER;

#endif /*__INC_MPEG2STRUCTS__*/
