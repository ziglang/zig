/*
 * kbdmou.h
 *
 * Structures and definitions for Keyboard/Mouse class and port drivers.
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Filip Navara <xnavara@volny.cz>
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

#define _KBDMOU_

#include <ntddkbd.h>
#include <ntddmou.h>

#define DD_KEYBOARD_PORT_DEVICE_NAME      "\\Device\\KeyboardPort"
#define DD_KEYBOARD_PORT_DEVICE_NAME_U    L"\\Device\\KeyboardPort"
#define DD_KEYBOARD_PORT_BASE_NAME_U      L"KeyboardPort"
#define DD_POINTER_PORT_DEVICE_NAME       "\\Device\\PointerPort"
#define DD_POINTER_PORT_DEVICE_NAME_U     L"\\Device\\PointerPort"
#define DD_POINTER_PORT_BASE_NAME_U       L"PointerPort"

#define DD_KEYBOARD_CLASS_BASE_NAME_U     L"KeyboardClass"
#define DD_POINTER_CLASS_BASE_NAME_U      L"PointerClass"

#define DD_KEYBOARD_RESOURCE_CLASS_NAME_U             L"Keyboard"
#define DD_POINTER_RESOURCE_CLASS_NAME_U              L"Pointer"
#define DD_KEYBOARD_MOUSE_COMBO_RESOURCE_CLASS_NAME_U L"Keyboard/Pointer"

#define POINTER_PORTS_MAXIMUM             8
#define KEYBOARD_PORTS_MAXIMUM            8

#define KBDMOU_COULD_NOT_SEND_COMMAND     0x0000
#define KBDMOU_COULD_NOT_SEND_PARAM       0x0001
#define KBDMOU_NO_RESPONSE                0x0002
#define KBDMOU_INCORRECT_RESPONSE         0x0004

#define I8042_ERROR_VALUE_BASE            1000
#define INPORT_ERROR_VALUE_BASE           2000
#define SERIAL_MOUSE_ERROR_VALUE_BASE     3000

#define IOCTL_INTERNAL_KEYBOARD_CONNECT \
  CTL_CODE(FILE_DEVICE_KEYBOARD, 0x0080, METHOD_NEITHER, FILE_ANY_ACCESS)

#define IOCTL_INTERNAL_KEYBOARD_DISCONNECT \
  CTL_CODE(FILE_DEVICE_KEYBOARD,0x0100, METHOD_NEITHER, FILE_ANY_ACCESS)

#define IOCTL_INTERNAL_KEYBOARD_ENABLE \
  CTL_CODE(FILE_DEVICE_KEYBOARD, 0x0200, METHOD_NEITHER, FILE_ANY_ACCESS)

#define IOCTL_INTERNAL_KEYBOARD_DISABLE \
  CTL_CODE(FILE_DEVICE_KEYBOARD, 0x0400, METHOD_NEITHER, FILE_ANY_ACCESS)

#define IOCTL_INTERNAL_MOUSE_CONNECT \
  CTL_CODE(FILE_DEVICE_MOUSE, 0x0080, METHOD_NEITHER, FILE_ANY_ACCESS)

#define IOCTL_INTERNAL_MOUSE_DISCONNECT \
  CTL_CODE(FILE_DEVICE_MOUSE, 0x0100, METHOD_NEITHER, FILE_ANY_ACCESS)

#define IOCTL_INTERNAL_MOUSE_ENABLE \
  CTL_CODE(FILE_DEVICE_MOUSE, 0x0200, METHOD_NEITHER, FILE_ANY_ACCESS)

#define IOCTL_INTERNAL_MOUSE_DISABLE \
  CTL_CODE(FILE_DEVICE_MOUSE, 0x0400, METHOD_NEITHER, FILE_ANY_ACCESS)

typedef struct _CONNECT_DATA {
  PDEVICE_OBJECT ClassDeviceObject;
  PVOID ClassService;
} CONNECT_DATA, *PCONNECT_DATA;

typedef VOID
(STDAPICALLTYPE *PSERVICE_CALLBACK_ROUTINE)(
  IN PVOID NormalContext,
  IN PVOID SystemArgument1,
  IN PVOID SystemArgument2,
  IN OUT PVOID SystemArgument3);

#include <wmidata.h>
