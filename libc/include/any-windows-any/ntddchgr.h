/*
 * ntddchgr.h
 *
 * Media changer IOCTL interface.
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

#pragma once

#include "ntddstor.h"

#ifdef __cplusplus
extern "C" {
#endif

#define DD_CHANGER_DEVICE_NAME            "\\Device\\Changer"
#define DD_CHANGER_DEVICE_NAME_U          L"\\Device\\Changer"

#define IOCTL_CHANGER_BASE                FILE_DEVICE_CHANGER

#define IOCTL_CHANGER_EXCHANGE_MEDIUM \
  CTL_CODE(IOCTL_CHANGER_BASE, 0x0008, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_CHANGER_GET_ELEMENT_STATUS \
  CTL_CODE(IOCTL_CHANGER_BASE, 0x0005, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS)

#define IOCTL_CHANGER_GET_PARAMETERS \
  CTL_CODE(IOCTL_CHANGER_BASE, 0x0000, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_CHANGER_GET_PRODUCT_DATA \
  CTL_CODE(IOCTL_CHANGER_BASE, 0x0002, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_CHANGER_GET_STATUS \
  CTL_CODE(IOCTL_CHANGER_BASE, 0x0001, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_CHANGER_INITIALIZE_ELEMENT_STATUS \
  CTL_CODE(IOCTL_CHANGER_BASE, 0x0006, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_CHANGER_MOVE_MEDIUM \
  CTL_CODE(IOCTL_CHANGER_BASE, 0x0009, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_CHANGER_QUERY_VOLUME_TAGS \
  CTL_CODE(IOCTL_CHANGER_BASE, 0x000B, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS)

#define IOCTL_CHANGER_REINITIALIZE_TRANSPORT \
  CTL_CODE(IOCTL_CHANGER_BASE, 0x000A, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_CHANGER_SET_ACCESS \
  CTL_CODE(IOCTL_CHANGER_BASE, 0x0004, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS)

#define IOCTL_CHANGER_SET_POSITION \
  CTL_CODE(IOCTL_CHANGER_BASE, 0x0007, METHOD_BUFFERED, FILE_READ_ACCESS)

#define MAX_VOLUME_ID_SIZE                36
#define MAX_VOLUME_TEMPLATE_SIZE          40

#define VENDOR_ID_LENGTH                  8
#define PRODUCT_ID_LENGTH                 16
#define REVISION_LENGTH                   4
#define SERIAL_NUMBER_LENGTH              32

/* GET_CHANGER_PARAMETERS.Features0 constants */
#define CHANGER_BAR_CODE_SCANNER_INSTALLED  0x00000001
#define CHANGER_INIT_ELEM_STAT_WITH_RANGE   0x00000002
#define CHANGER_CLOSE_IEPORT                0x00000004
#define CHANGER_OPEN_IEPORT                 0x00000008
#define CHANGER_STATUS_NON_VOLATILE         0x00000010
#define CHANGER_EXCHANGE_MEDIA              0x00000020
#define CHANGER_CLEANER_SLOT                0x00000040
#define CHANGER_LOCK_UNLOCK                 0x00000080
#define CHANGER_CARTRIDGE_MAGAZINE          0x00000100
#define CHANGER_MEDIUM_FLIP                 0x00000200
#define CHANGER_POSITION_TO_ELEMENT         0x00000400
#define CHANGER_REPORT_IEPORT_STATE         0x00000800
#define CHANGER_STORAGE_DRIVE               0x00001000
#define CHANGER_STORAGE_IEPORT              0x00002000
#define CHANGER_STORAGE_SLOT                0x00004000
#define CHANGER_STORAGE_TRANSPORT           0x00008000
#define CHANGER_DRIVE_CLEANING_REQUIRED     0x00010000
#define CHANGER_PREDISMOUNT_EJECT_REQUIRED  0x00020000
#define CHANGER_CLEANER_ACCESS_NOT_VALID    0x00040000
#define CHANGER_PREMOUNT_EJECT_REQUIRED     0x00080000
#define CHANGER_VOLUME_IDENTIFICATION       0x00100000
#define CHANGER_VOLUME_SEARCH               0x00200000
#define CHANGER_VOLUME_ASSERT               0x00400000
#define CHANGER_VOLUME_REPLACE              0x00800000
#define CHANGER_VOLUME_UNDEFINE             0x01000000
#define CHANGER_SERIAL_NUMBER_VALID         0x04000000
#define CHANGER_DEVICE_REINITIALIZE_CAPABLE 0x08000000
#define CHANGER_KEYPAD_ENABLE_DISABLE       0x10000000
#define CHANGER_DRIVE_EMPTY_ON_DOOR_ACCESS  0x20000000
#define CHANGER_RESERVED_BIT                0x80000000

/* GET_CHANGER_PARAMETERS.Features1 constants */
#define CHANGER_PREDISMOUNT_ALIGN_TO_SLOT   0x80000001
#define CHANGER_PREDISMOUNT_ALIGN_TO_DRIVE  0x80000002
#define CHANGER_CLEANER_AUTODISMOUNT        0x80000004
#define CHANGER_TRUE_EXCHANGE_CAPABLE       0x80000008
#define CHANGER_SLOTS_USE_TRAYS             0x80000010
#define CHANGER_RTN_MEDIA_TO_ORIGINAL_ADDR  0x80000020
#define CHANGER_CLEANER_OPS_NOT_SUPPORTED   0x80000040
#define CHANGER_IEPORT_USER_CONTROL_OPEN    0x80000080
#define CHANGER_IEPORT_USER_CONTROL_CLOSE   0x80000100
#define CHANGER_MOVE_EXTENDS_IEPORT         0x80000200
#define CHANGER_MOVE_RETRACTS_IEPORT        0x80000400

/* GET_CHANGER_PARAMETERS.MoveFrom,ExchangeFrom,PositionCapabilities constants */
#define CHANGER_TO_TRANSPORT              0x01
#define CHANGER_TO_SLOT                   0x02
#define CHANGER_TO_IEPORT                 0x04
#define CHANGER_TO_DRIVE                  0x08

/* GET_CHANGER_PARAMETERS.LockUnlockCapabilities constants */
#define LOCK_UNLOCK_IEPORT                0x01
#define LOCK_UNLOCK_DOOR                  0x02
#define LOCK_UNLOCK_KEYPAD                0x04

/* CHANGER_SET_ACCESS.Control constants */
#define LOCK_ELEMENT                      0
#define UNLOCK_ELEMENT                    1
#define EXTEND_IEPORT                     2
#define RETRACT_IEPORT                    3

/* CHANGER_ELEMENT_STATUS(_EX).Flags constants */
#define ELEMENT_STATUS_FULL               0x00000001
#define ELEMENT_STATUS_IMPEXP             0x00000002
#define ELEMENT_STATUS_EXCEPT             0x00000004
#define ELEMENT_STATUS_ACCESS             0x00000008
#define ELEMENT_STATUS_EXENAB             0x00000010
#define ELEMENT_STATUS_INENAB             0x00000020
#define ELEMENT_STATUS_PRODUCT_DATA       0x00000040
#define ELEMENT_STATUS_LUN_VALID          0x00001000
#define ELEMENT_STATUS_ID_VALID           0x00002000
#define ELEMENT_STATUS_NOT_BUS            0x00008000
#define ELEMENT_STATUS_INVERT             0x00400000
#define ELEMENT_STATUS_SVALID             0x00800000
#define ELEMENT_STATUS_PVOLTAG            0x10000000
#define ELEMENT_STATUS_AVOLTAG            0x20000000

/* CHANGER_ELEMENT_STATUS(_EX).ExceptionCode constants */
#define ERROR_LABEL_UNREADABLE            0x00000001
#define ERROR_LABEL_QUESTIONABLE          0x00000002
#define ERROR_SLOT_NOT_PRESENT            0x00000004
#define ERROR_DRIVE_NOT_INSTALLED         0x00000008
#define ERROR_TRAY_MALFUNCTION            0x00000010
#define ERROR_INIT_STATUS_NEEDED          0x00000011
#define ERROR_UNHANDLED_ERROR             0xFFFFFFFF

/* CHANGER_SEND_VOLUME_TAG_INFORMATION.ActionCode constants */
#define SEARCH_ALL                        0x0
#define SEARCH_PRIMARY                    0x1
#define SEARCH_ALTERNATE                  0x2
#define SEARCH_ALL_NO_SEQ                 0x4
#define SEARCH_PRI_NO_SEQ                 0x5
#define SEARCH_ALT_NO_SEQ                 0x6
#define ASSERT_PRIMARY                    0x8
#define ASSERT_ALTERNATE                  0x9
#define REPLACE_PRIMARY                   0xA
#define REPLACE_ALTERNATE                 0xB
#define UNDEFINE_PRIMARY                  0xC
#define UNDEFINE_ALTERNATE                0xD

typedef enum _ELEMENT_TYPE {
  AllElements,
  ChangerTransport,
  ChangerSlot,
  ChangerIEPort,
  ChangerDrive,
  ChangerDoor,
  ChangerKeypad,
  ChangerMaxElement
} ELEMENT_TYPE, *PELEMENT_TYPE;

typedef struct _CHANGER_ELEMENT {
  ELEMENT_TYPE ElementType;
  ULONG ElementAddress;
} CHANGER_ELEMENT, *PCHANGER_ELEMENT;

typedef struct _CHANGER_ELEMENT_LIST {
  CHANGER_ELEMENT Element;
  ULONG NumberOfElements;
} CHANGER_ELEMENT_LIST, *PCHANGER_ELEMENT_LIST;

typedef struct _GET_CHANGER_PARAMETERS {
  ULONG  Size;
  USHORT  NumberTransportElements;
  USHORT  NumberStorageElements;
  USHORT  NumberCleanerSlots;
  USHORT  NumberIEElements;
  USHORT  NumberDataTransferElements;
  USHORT  NumberOfDoors;
  USHORT  FirstSlotNumber;
  USHORT  FirstDriveNumber;
  USHORT  FirstTransportNumber;
  USHORT  FirstIEPortNumber;
  USHORT  FirstCleanerSlotAddress;
  USHORT  MagazineSize;
  ULONG  DriveCleanTimeout;
  ULONG  Features0;
  ULONG  Features1;
  UCHAR  MoveFromTransport;
  UCHAR  MoveFromSlot;
  UCHAR  MoveFromIePort;
  UCHAR  MoveFromDrive;
  UCHAR  ExchangeFromTransport;
  UCHAR  ExchangeFromSlot;
  UCHAR  ExchangeFromIePort;
  UCHAR  ExchangeFromDrive;
  UCHAR  LockUnlockCapabilities;
  UCHAR  PositionCapabilities;
  UCHAR  Reserved1[2];
  ULONG  Reserved2[2];
} GET_CHANGER_PARAMETERS, * PGET_CHANGER_PARAMETERS;

typedef  struct _CHANGER_PRODUCT_DATA {
	UCHAR  VendorId[VENDOR_ID_LENGTH];
	UCHAR  ProductId[PRODUCT_ID_LENGTH];
	UCHAR  Revision[REVISION_LENGTH];
	UCHAR  SerialNumber[SERIAL_NUMBER_LENGTH];
	UCHAR  DeviceType;
} CHANGER_PRODUCT_DATA, *PCHANGER_PRODUCT_DATA;

typedef struct _CHANGER_SET_ACCESS {
  CHANGER_ELEMENT  Element;
  ULONG  Control;
} CHANGER_SET_ACCESS, *PCHANGER_SET_ACCESS;

typedef struct _CHANGER_READ_ELEMENT_STATUS {
  CHANGER_ELEMENT_LIST  ElementList;
  BOOLEAN  VolumeTagInfo;
} CHANGER_READ_ELEMENT_STATUS, *PCHANGER_READ_ELEMENT_STATUS;

typedef struct _CHANGER_ELEMENT_STATUS {
  CHANGER_ELEMENT  Element;
  CHANGER_ELEMENT  SrcElementAddress;
  ULONG  Flags;
  ULONG  ExceptionCode;
  UCHAR  TargetId;
  UCHAR  Lun;
  USHORT  Reserved;
  UCHAR  PrimaryVolumeID[MAX_VOLUME_ID_SIZE];
  UCHAR  AlternateVolumeID[MAX_VOLUME_ID_SIZE];
} CHANGER_ELEMENT_STATUS, *PCHANGER_ELEMENT_STATUS;

typedef  struct _CHANGER_ELEMENT_STATUS_EX {
  CHANGER_ELEMENT  Element;
  CHANGER_ELEMENT  SrcElementAddress;
  ULONG  Flags;
  ULONG  ExceptionCode;
  UCHAR  TargetId;
  UCHAR  Lun;
  USHORT  Reserved;
  UCHAR  PrimaryVolumeID[MAX_VOLUME_ID_SIZE];
  UCHAR  AlternateVolumeID[MAX_VOLUME_ID_SIZE];
  UCHAR  VendorIdentification[VENDOR_ID_LENGTH];
  UCHAR  ProductIdentification[PRODUCT_ID_LENGTH];
  UCHAR  SerialNumber[SERIAL_NUMBER_LENGTH];
} CHANGER_ELEMENT_STATUS_EX, *PCHANGER_ELEMENT_STATUS_EX;

typedef struct _CHANGER_INITIALIZE_ELEMENT_STATUS {
  CHANGER_ELEMENT_LIST  ElementList;
  BOOLEAN  BarCodeScan;
} CHANGER_INITIALIZE_ELEMENT_STATUS, *PCHANGER_INITIALIZE_ELEMENT_STATUS;

typedef struct _CHANGER_SET_POSITION {
	CHANGER_ELEMENT  Transport;
	CHANGER_ELEMENT  Destination;
	BOOLEAN  Flip;
} CHANGER_SET_POSITION, *PCHANGER_SET_POSITION;

typedef struct _CHANGER_EXCHANGE_MEDIUM {
	CHANGER_ELEMENT  Transport;
	CHANGER_ELEMENT  Source;
	CHANGER_ELEMENT  Destination1;
	CHANGER_ELEMENT  Destination2;
	BOOLEAN  Flip1;
	BOOLEAN  Flip2;
} CHANGER_EXCHANGE_MEDIUM, *PCHANGER_EXCHANGE_MEDIUM;

typedef struct _CHANGER_MOVE_MEDIUM {
  CHANGER_ELEMENT  Transport;
  CHANGER_ELEMENT  Source;
  CHANGER_ELEMENT  Destination;
  BOOLEAN  Flip;
} CHANGER_MOVE_MEDIUM, *PCHANGER_MOVE_MEDIUM;

typedef struct _CHANGER_SEND_VOLUME_TAG_INFORMATION {
  CHANGER_ELEMENT StartingElement;
  ULONG  ActionCode;
  UCHAR  VolumeIDTemplate[MAX_VOLUME_TEMPLATE_SIZE];
} CHANGER_SEND_VOLUME_TAG_INFORMATION, *PCHANGER_SEND_VOLUME_TAG_INFORMATION;

typedef struct READ_ELEMENT_ADDRESS_INFO {
  ULONG  NumberOfElements;
  CHANGER_ELEMENT_STATUS  ElementStatus[1];
} READ_ELEMENT_ADDRESS_INFO, *PREAD_ELEMENT_ADDRESS_INFO;

typedef enum _CHANGER_DEVICE_PROBLEM_TYPE {
  DeviceProblemNone,
  DeviceProblemHardware,
  DeviceProblemCHMError,
  DeviceProblemDoorOpen,
  DeviceProblemCalibrationError,
  DeviceProblemTargetFailure,
  DeviceProblemCHMMoveError,
  DeviceProblemCHMZeroError,
  DeviceProblemCartridgeInsertError,
  DeviceProblemPositionError,
  DeviceProblemSensorError,
  DeviceProblemCartridgeEjectError,
  DeviceProblemGripperError,
  DeviceProblemDriveError
} CHANGER_DEVICE_PROBLEM_TYPE, *PCHANGER_DEVICE_PROBLEM_TYPE;

#ifdef __cplusplus
}
#endif
