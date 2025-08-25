/*
 * nettypes.h
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

#define HARDWARE_ADDRESS_LENGTH             6
#define NETMAN_VARTYPE_ULONG                0
#define NETMAN_VARTYPE_HARDWARE_ADDRESS     1
#define NETMAN_VARTYPE_STRING               2

typedef ULONG OFFSET;

typedef struct _FLAT_STRING {
  SHORT MaximumLength;
  SHORT Length;
  char Buffer [1];
} FLAT_STRING, *PFLAT_STRING;

typedef struct _NETWORK_NAME {
  FLAT_STRING Name;
} NETWORK_NAME, *PNETWORK_NAME;

typedef struct _HARDWARE_ADDRESS {
  UCHAR Address [HARDWARE_ADDRESS_LENGTH];
} HARDWARE_ADDRESS, *PHARDWARE_ADDRESS;
