/*
 * ntdd8042.h
 *
 * i8042 IOCTL interface.
 *
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 *
 * Initial contributor is Casper S. Hornstrup <chorns@users.sourceforge.net>
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

#ifndef _NTDD8042_
#define _NTDD8042_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include "ntddkbd.h"
#include "ntddmou.h"

#ifdef __cplusplus
extern "C" {
#endif

#define IOCTL_INTERNAL_I8042_CONTROLLER_WRITE_BUFFER \
  CTL_CODE(FILE_DEVICE_KEYBOARD, 0x0FF2, METHOD_NEITHER, FILE_ANY_ACCESS)

#define IOCTL_INTERNAL_I8042_HOOK_KEYBOARD \
  CTL_CODE(FILE_DEVICE_KEYBOARD, 0x0FF0, METHOD_NEITHER, FILE_ANY_ACCESS)

#define IOCTL_INTERNAL_I8042_KEYBOARD_START_INFORMATION \
  CTL_CODE(FILE_DEVICE_KEYBOARD, 0x0FF3, METHOD_NEITHER, FILE_ANY_ACCESS)

#define IOCTL_INTERNAL_I8042_KEYBOARD_WRITE_BUFFER \
  CTL_CODE(FILE_DEVICE_KEYBOARD, 0x0FF1, METHOD_NEITHER, FILE_ANY_ACCESS)

#define IOCTL_INTERNAL_I8042_HOOK_MOUSE \
  CTL_CODE(FILE_DEVICE_MOUSE, 0x0FF0, METHOD_NEITHER, FILE_ANY_ACCESS)

#define IOCTL_INTERNAL_I8042_MOUSE_START_INFORMATION \
  CTL_CODE(FILE_DEVICE_MOUSE, 0x0FF3, METHOD_NEITHER, FILE_ANY_ACCESS)

#define IOCTL_INTERNAL_I8042_MOUSE_WRITE_BUFFER \
  CTL_CODE(FILE_DEVICE_MOUSE, 0x0FF1, METHOD_NEITHER, FILE_ANY_ACCESS)

#define I8042_POWER_SYS_BUTTON            0x0001
#define I8042_SLEEP_SYS_BUTTON            0x0002
#define I8042_WAKE_SYS_BUTTON             0x0004
#define I8042_SYS_BUTTONS                 (I8042_POWER_SYS_BUTTON | \
                                           I8042_SLEEP_SYS_BUTTON | \
                                           I8042_WAKE_SYS_BUTTON)

typedef enum _TRANSMIT_STATE {
  Idle = 0,
  SendingBytes
} TRANSMIT_STATE;

typedef struct _OUTPUT_PACKET {
  PUCHAR  Bytes;
  ULONG  CurrentByte;
  ULONG  ByteCount;
  TRANSMIT_STATE  State;
} OUTPUT_PACKET, *POUTPUT_PACKET;

typedef enum _KEYBOARD_SCAN_STATE {
  Normal,
  GotE0,
  GotE1
} KEYBOARD_SCAN_STATE, *PKEYBOARD_SCAN_STATE;

typedef enum _MOUSE_STATE {
  MouseIdle,
  XMovement,
  YMovement,
  ZMovement,
  MouseExpectingACK,
  MouseResetting
} MOUSE_STATE, *PMOUSE_STATE;

typedef enum _MOUSE_RESET_SUBSTATE {
	ExpectingReset,
	ExpectingResetId,
	ExpectingGetDeviceIdACK,
	ExpectingGetDeviceIdValue,
	ExpectingSetResolutionDefaultACK,
	ExpectingSetResolutionDefaultValueACK,
	ExpectingSetResolutionACK,
	ExpectingSetResolutionValueACK,
	ExpectingSetScaling1to1ACK,
	ExpectingSetScaling1to1ACK2,
	ExpectingSetScaling1to1ACK3,
	ExpectingReadMouseStatusACK,
	ExpectingReadMouseStatusByte1,
	ExpectingReadMouseStatusByte2,
	ExpectingReadMouseStatusByte3,
	StartPnPIdDetection,
	ExpectingLoopSetSamplingRateACK,
	ExpectingLoopSetSamplingRateValueACK,
	ExpectingPnpIdByte1,
	ExpectingPnpIdByte2,
	ExpectingPnpIdByte3,
	ExpectingPnpIdByte4,
	ExpectingPnpIdByte5,
	ExpectingPnpIdByte6,
	ExpectingPnpIdByte7,
	EnableWheel,
	Enable5Buttons,
	ExpectingGetDeviceId2ACK,
	ExpectingGetDeviceId2Value,
	ExpectingSetSamplingRateACK,
	ExpectingSetSamplingRateValueACK,
	ExpectingEnableACK,
	ExpectingFinalResolutionACK,
	ExpectingFinalResolutionValueACK,
	ExpectingGetDeviceIdDetectACK,
	ExpectingGetDeviceIdDetectValue,
	CustomHookStateMinimum = 100,
	CustomHookStateMaximum = 999,
	I8042ReservedMinimum = 1000
} MOUSE_RESET_SUBSTATE, *PMOUSE_RESET_SUBSTATE;

typedef struct _INTERNAL_I8042_START_INFORMATION {
  ULONG  Size;
  PKINTERRUPT  InterruptObject;
  ULONG  Reserved[8];
} INTERNAL_I8042_START_INFORMATION, *PINTERNAL_I8042_START_INFORMATION;

typedef VOID
(NTAPI *PI8042_ISR_WRITE_PORT)(
  PVOID  Context,
  UCHAR  Value);

typedef VOID
(NTAPI *PI8042_QUEUE_PACKET)(
  PVOID  Context);

typedef NTSTATUS
(NTAPI *PI8042_SYNCH_READ_PORT) (
  PVOID  Context,
  PUCHAR  Value,
  BOOLEAN  WaitForACK);

typedef NTSTATUS
(NTAPI *PI8042_SYNCH_WRITE_PORT)(
  PVOID  Context,
  UCHAR  Value,
  BOOLEAN  WaitForACK);


typedef NTSTATUS
(NTAPI *PI8042_KEYBOARD_INITIALIZATION_ROUTINE)(
  PVOID  InitializationContext,
  PVOID  SynchFuncContext,
  PI8042_SYNCH_READ_PORT  ReadPort,
  PI8042_SYNCH_WRITE_PORT  WritePort,
  PBOOLEAN  TurnTranslationOn);

typedef BOOLEAN
(NTAPI *PI8042_KEYBOARD_ISR)(
  PVOID  IsrContext,
  PKEYBOARD_INPUT_DATA  CurrentInput,
  POUTPUT_PACKET  CurrentOutput,
  UCHAR  StatusByte,
  PUCHAR  Byte,
  PBOOLEAN  ContinueProcessing,
  PKEYBOARD_SCAN_STATE  ScanState);

typedef struct _INTERNAL_I8042_HOOK_KEYBOARD {
	PVOID  Context;
	PI8042_KEYBOARD_INITIALIZATION_ROUTINE  InitializationRoutine;
	PI8042_KEYBOARD_ISR  IsrRoutine;
	PI8042_ISR_WRITE_PORT  IsrWritePort;
	PI8042_QUEUE_PACKET  QueueKeyboardPacket;
	PVOID  CallContext;
} INTERNAL_I8042_HOOK_KEYBOARD, *PINTERNAL_I8042_HOOK_KEYBOARD;

typedef BOOLEAN
(NTAPI *PI8042_MOUSE_ISR)(
  PVOID  IsrContext,
  PMOUSE_INPUT_DATA  CurrentInput,
  POUTPUT_PACKET  CurrentOutput,
  UCHAR  StatusByte,
  PUCHAR  Byte,
  PBOOLEAN  ContinueProcessing,
  PMOUSE_STATE  MouseState,
  PMOUSE_RESET_SUBSTATE  ResetSubState);

typedef struct _INTERNAL_I8042_HOOK_MOUSE {
  PVOID  Context;
  PI8042_MOUSE_ISR  IsrRoutine;
  PI8042_ISR_WRITE_PORT  IsrWritePort;
  PI8042_QUEUE_PACKET  QueueMousePacket;
  PVOID  CallContext;
} INTERNAL_I8042_HOOK_MOUSE, *PINTERNAL_I8042_HOOK_MOUSE;

#ifdef __cplusplus
}
#endif

#endif

#endif /* _NTDD8042_ */
