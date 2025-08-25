/*
 * minitape.h
 *
 * Minitape driver interface
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Casper S. Hornstrup <chorns@users.sourceforge.net>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#ifndef __MINITAPE_H
#define __MINITAPE_H

#ifdef __cplusplus
extern "C" {
#endif

#pragma pack(push,4)

#define MEDIA_ERASEABLE                   0x00000001
#define MEDIA_WRITE_ONCE                  0x00000002
#define MEDIA_READ_ONLY                   0x00000004
#define MEDIA_READ_WRITE                  0x00000008
#define MEDIA_WRITE_PROTECTED             0x00000100
#define MEDIA_CURRENTLY_MOUNTED           0x80000000

typedef enum _TAPE_STATUS {
	TAPE_STATUS_SEND_SRB_AND_CALLBACK,
	TAPE_STATUS_CALLBACK,
	TAPE_STATUS_CHECK_TEST_UNIT_READY,
	TAPE_STATUS_SUCCESS,
	TAPE_STATUS_INSUFFICIENT_RESOURCES,
	TAPE_STATUS_NOT_IMPLEMENTED,
	TAPE_STATUS_INVALID_DEVICE_REQUEST,
	TAPE_STATUS_INVALID_PARAMETER,
	TAPE_STATUS_MEDIA_CHANGED,
	TAPE_STATUS_BUS_RESET,
	TAPE_STATUS_SETMARK_DETECTED,
	TAPE_STATUS_FILEMARK_DETECTED,
	TAPE_STATUS_BEGINNING_OF_MEDIA,
	TAPE_STATUS_END_OF_MEDIA,
	TAPE_STATUS_BUFFER_OVERFLOW,
	TAPE_STATUS_NO_DATA_DETECTED,
	TAPE_STATUS_EOM_OVERFLOW,
	TAPE_STATUS_NO_MEDIA,
	TAPE_STATUS_IO_DEVICE_ERROR,
	TAPE_STATUS_UNRECOGNIZED_MEDIA,
	TAPE_STATUS_DEVICE_NOT_READY,
	TAPE_STATUS_MEDIA_WRITE_PROTECTED,
	TAPE_STATUS_DEVICE_DATA_ERROR,
	TAPE_STATUS_NO_SUCH_DEVICE,
	TAPE_STATUS_INVALID_BLOCK_LENGTH,
	TAPE_STATUS_IO_TIMEOUT,
	TAPE_STATUS_DEVICE_NOT_CONNECTED,
	TAPE_STATUS_DATA_OVERRUN,
	TAPE_STATUS_DEVICE_BUSY,
	TAPE_STATUS_REQUIRES_CLEANING,
	TAPE_STATUS_CLEANER_CARTRIDGE_INSTALLED
} TAPE_STATUS, *PTAPE_STATUS;

#define INQUIRYDATABUFFERSIZE 36
#ifndef _INQUIRYDATA_DEFINED /* also in scsi.h */
#define _INQUIRYDATA_DEFINED
typedef struct _INQUIRYDATA {
	UCHAR  DeviceType : 5;
	UCHAR  DeviceTypeQualifier : 3;
	UCHAR  DeviceTypeModifier : 7;
	UCHAR  RemovableMedia : 1;
	__GNU_EXTENSION union {
		UCHAR  Versions;
		__GNU_EXTENSION struct {
			UCHAR  ANSIVersion : 3;
			UCHAR  ECMAVersion : 3;
			UCHAR  ISOVersion : 2;
		};
	};
	UCHAR  ResponseDataFormat : 4;
	UCHAR  HiSupport : 1;
	UCHAR  NormACA : 1;
	UCHAR  TerminateTask : 1;
	UCHAR  AERC : 1;
	UCHAR  AdditionalLength;
	UCHAR  Reserved;
	UCHAR  Addr16 : 1;
	UCHAR  Addr32 : 1;
	UCHAR  AckReqQ: 1;
	UCHAR  MediumChanger : 1;
	UCHAR  MultiPort : 1;
	UCHAR  ReservedBit2 : 1;
	UCHAR  EnclosureServices : 1;
	UCHAR  ReservedBit3 : 1;
	UCHAR  SoftReset : 1;
	UCHAR  CommandQueue : 1;
	UCHAR  TransferDisable : 1;
	UCHAR  LinkedCommands : 1;
	UCHAR  Synchronous : 1;
	UCHAR  Wide16Bit : 1;
	UCHAR  Wide32Bit : 1;
	UCHAR  RelativeAddressing : 1;
	UCHAR  VendorId[8];
	UCHAR  ProductId[16];
	UCHAR  ProductRevisionLevel[4];
	UCHAR  VendorSpecific[20];
	UCHAR  Reserved3[40];
} INQUIRYDATA, *PINQUIRYDATA;
#endif

typedef struct _MODE_CAPABILITIES_PAGE {
	UCHAR PageCode : 6;
	UCHAR Reserved1 : 2;
	UCHAR PageLength;
	UCHAR Reserved2[2];
	UCHAR RO : 1;
	UCHAR Reserved3 : 4;
	UCHAR SPREV : 1;
	UCHAR Reserved4 : 2;
	UCHAR Reserved5 : 3;
	UCHAR EFMT : 1;
	UCHAR Reserved6 : 1;
	UCHAR QFA : 1;
	UCHAR Reserved7 : 2;
	UCHAR LOCK : 1;
	UCHAR LOCKED : 1;
	UCHAR PREVENT : 1;
	UCHAR UNLOAD : 1;
	UCHAR Reserved8 : 2;
	UCHAR ECC : 1;
	UCHAR CMPRS : 1;
	UCHAR Reserved9 : 1;
	UCHAR BLK512 : 1;
	UCHAR BLK1024 : 1;
	UCHAR Reserved10 : 4;
	UCHAR SLOWB : 1;
	UCHAR MaximumSpeedSupported[2];
	UCHAR MaximumStoredDefectedListEntries[2];
	UCHAR ContinuousTransferLimit[2];
	UCHAR CurrentSpeedSelected[2];
	UCHAR BufferSize[2];
	UCHAR Reserved11[2];
} MODE_CAPABILITIES_PAGE, *PMODE_CAPABILITIES_PAGE;

typedef BOOLEAN NTAPI
(*TAPE_VERIFY_INQUIRY_ROUTINE)(
	IN PINQUIRYDATA  InquiryData,
	IN PMODE_CAPABILITIES_PAGE ModeCapabilitiesPage);

typedef VOID NTAPI
(*TAPE_EXTENSION_INIT_ROUTINE)(
  IN PVOID  MinitapeExtension,
  IN PINQUIRYDATA  InquiryData,
  IN PMODE_CAPABILITIES_PAGE  ModeCapabilitiesPage);

typedef VOID NTAPI
(*TAPE_ERROR_ROUTINE)(
    IN PVOID  MinitapeExtension,
    IN PSCSI_REQUEST_BLOCK  Srb,
    IN OUT PTAPE_STATUS  TapeStatus);

typedef TAPE_STATUS NTAPI
(*TAPE_PROCESS_COMMAND_ROUTINE)(
  IN OUT PVOID  MinitapeExtension,
  IN OUT PVOID  CommandExtension,
  IN OUT PVOID  CommandParameters,
  IN OUT PSCSI_REQUEST_BLOCK  Srb,
  IN ULONG  CallNumber,
  IN TAPE_STATUS  StatusOfLastCommand,
  IN OUT PULONG  RetryFlags);

#define TAPE_RETRY_MASK                   0x0000FFFF
#define IGNORE_ERRORS                     0x00010000
#define RETURN_ERRORS                     0x00020000

typedef struct _TAPE_INIT_DATA {
  TAPE_VERIFY_INQUIRY_ROUTINE  VerifyInquiry;
  BOOLEAN  QueryModeCapabilitiesPage;
  ULONG  MinitapeExtensionSize;
  TAPE_EXTENSION_INIT_ROUTINE  ExtensionInit;
  ULONG  DefaultTimeOutValue;
  TAPE_ERROR_ROUTINE  TapeError;
  ULONG  CommandExtensionSize;
  TAPE_PROCESS_COMMAND_ROUTINE  CreatePartition;
  TAPE_PROCESS_COMMAND_ROUTINE  Erase;
  TAPE_PROCESS_COMMAND_ROUTINE  GetDriveParameters;
  TAPE_PROCESS_COMMAND_ROUTINE  GetMediaParameters;
  TAPE_PROCESS_COMMAND_ROUTINE  GetPosition;
  TAPE_PROCESS_COMMAND_ROUTINE  GetStatus;
  TAPE_PROCESS_COMMAND_ROUTINE  Prepare;
  TAPE_PROCESS_COMMAND_ROUTINE  SetDriveParameters;
  TAPE_PROCESS_COMMAND_ROUTINE  SetMediaParameters;
  TAPE_PROCESS_COMMAND_ROUTINE  SetPosition;
  TAPE_PROCESS_COMMAND_ROUTINE  WriteMarks;
  TAPE_PROCESS_COMMAND_ROUTINE  PreProcessReadWrite; /* optional */
} TAPE_INIT_DATA, *PTAPE_INIT_DATA;

typedef struct _TAPE_PHYS_POSITION {
	ULONG  SeekBlockAddress;
	ULONG  SpaceBlockCount;
} TAPE_PHYS_POSITION, PTAPE_PHYS_POSITION;

#pragma pack(pop)

#ifdef __cplusplus
}
#endif

#endif /* __MINITAPE_H */
