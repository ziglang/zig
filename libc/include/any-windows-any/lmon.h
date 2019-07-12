/*
 * lmon.h
 *
 * This file is part of the ReactOS PSDK package.
 *
 * Contributors:
 *   Created by Magnus Olsen.
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

#ifdef UNICODE
#define PORT_INFO_FF PORT_INFO_FFW
#define PPORT_INFO_FF PPORT_INFO_FFW
#define LPPORT_INFO_FF LPPORT_INFO_FFW
#else
#define PORT_INFO_FF PORT_INFO_FFA
#define PPORT_INFO_FF PPORT_INFO_FFA
#define LPPORT_INFO_FF LPPORT_INFO_FFA
#endif

typedef struct _PORT_INFO_FFW {
  LPWSTR pName;
  DWORD cbMonitorData;
  LPBYTE pMonitorData;
} PORT_INFO_FFW, *PPORT_INFO_FFW, *LPPORT_INFO_FFW;

typedef struct _PORT_INFO_FFA {
  LPSTR pName;
  DWORD cbMonitorData;
  LPBYTE pMonitorData;
} PORT_INFO_FFA, *PPORT_INFO_FFA, *LPPORT_INFO_FFA;

