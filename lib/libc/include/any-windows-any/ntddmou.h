/*
 * ntddmou.h
 *
 * Mouse device IOCTL interface.
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

#ifdef __cplusplus
extern "C" {
#endif

#define DD_MOUSE_DEVICE_NAME              "\\Device\\PointerClass"
#define DD_MOUSE_DEVICE_NAME_U            L"\\Device\\PointerClass"

#define IOCTL_MOUSE_QUERY_ATTRIBUTES \
  CTL_CODE(FILE_DEVICE_MOUSE, 0, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define IOCTL_MOUSE_INSERT_DATA \
  CTL_CODE(FILE_DEVICE_MOUSE, 1, METHOD_BUFFERED, FILE_ANY_ACCESS)

DEFINE_GUID(GUID_DEVINTERFACE_MOUSE, \
  0x378de44c, 0x56ef, 0x11d1, 0xbc, 0x8c, 0x00, 0xa0, 0xc9, 0x14, 0x05, 0xdd);

#define GUID_CLASS_MOUSE GUID_DEVINTERFACE_MOUSE /* Obsolete */

#define MOUSE_ERROR_VALUE_BASE            20000

/* MOUSE_INPUT_DATA.ButtonFlags constants */
#define MOUSE_LEFT_BUTTON_DOWN            0x0001
#define MOUSE_LEFT_BUTTON_UP              0x0002
#define MOUSE_RIGHT_BUTTON_DOWN           0x0004
#define MOUSE_RIGHT_BUTTON_UP             0x0008
#define MOUSE_MIDDLE_BUTTON_DOWN          0x0010
#define MOUSE_MIDDLE_BUTTON_UP            0x0020
#define MOUSE_BUTTON_4_DOWN               0x0040
#define MOUSE_BUTTON_4_UP                 0x0080
#define MOUSE_BUTTON_5_DOWN               0x0100
#define MOUSE_BUTTON_5_UP                 0x0200
#define MOUSE_WHEEL                       0x0400
#define MOUSE_HWHEEL                      0x0800

#define MOUSE_BUTTON_1_DOWN               MOUSE_LEFT_BUTTON_DOWN
#define MOUSE_BUTTON_1_UP                 MOUSE_LEFT_BUTTON_UP
#define MOUSE_BUTTON_2_DOWN               MOUSE_RIGHT_BUTTON_DOWN
#define MOUSE_BUTTON_2_UP                 MOUSE_RIGHT_BUTTON_UP
#define MOUSE_BUTTON_3_DOWN               MOUSE_MIDDLE_BUTTON_DOWN
#define MOUSE_BUTTON_3_UP                 MOUSE_MIDDLE_BUTTON_UP

/* MOUSE_INPUT_DATA.Flags constants */
#define MOUSE_MOVE_RELATIVE               0
#define MOUSE_MOVE_ABSOLUTE               1
#define MOUSE_VIRTUAL_DESKTOP             0x02
#define MOUSE_ATTRIBUTES_CHANGED          0x04
#if(_WIN32_WINNT >= 0x0600)
#define MOUSE_MOVE_NOCOALESCE             0x08
#endif
#define MOUSE_TERMSRV_SRC_SHADOW          0x100

typedef struct _MOUSE_INPUT_DATA {
  USHORT UnitId;
  USHORT Flags;
  __C89_NAMELESS union {
    ULONG Buttons;
    __C89_NAMELESS struct {
      USHORT ButtonFlags;
      USHORT ButtonData;
    } DUMMYSTRUCTNAME;
  } DUMMYUNIONNAME;
  ULONG RawButtons;
  LONG LastX;
  LONG LastY;
  ULONG ExtraInformation;
} MOUSE_INPUT_DATA, *PMOUSE_INPUT_DATA;

typedef struct _MOUSE_UNIT_ID_PARAMETER {
  USHORT UnitId;
} MOUSE_UNIT_ID_PARAMETER, *PMOUSE_UNIT_ID_PARAMETER;

/* MOUSE_ATTRIBUTES.MouseIdentifier constants */
#define MOUSE_INPORT_HARDWARE             0x0001
#define MOUSE_I8042_HARDWARE              0x0002
#define MOUSE_SERIAL_HARDWARE             0x0004
#define BALLPOINT_I8042_HARDWARE          0x0008
#define BALLPOINT_SERIAL_HARDWARE         0x0010
#define WHEELMOUSE_I8042_HARDWARE         0x0020
#define WHEELMOUSE_SERIAL_HARDWARE        0x0040
#define MOUSE_HID_HARDWARE                0x0080
#define WHEELMOUSE_HID_HARDWARE           0x0100
#define HORIZONTAL_WHEEL_PRESENT          0x8000

typedef struct _MOUSE_ATTRIBUTES {
  USHORT MouseIdentifier;
  USHORT NumberOfButtons;
  USHORT SampleRate;
  ULONG InputDataQueueLength;
} MOUSE_ATTRIBUTES, *PMOUSE_ATTRIBUTES;

#ifdef __cplusplus
}
#endif
