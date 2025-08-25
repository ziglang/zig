/*
 * tdiinfo.h
 *
 * TDI set and query information interface
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

#ifndef __TDIINFO_H
#define __TDIINFO_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _TDIEntityID {
  ULONG  tei_entity;
  ULONG  tei_instance;
} TDIEntityID;

#define	MAX_TDI_ENTITIES				4096
#define	INVALID_ENTITY_INSTANCE				-1
#define	GENERIC_ENTITY					0
#define	ENTITY_LIST_ID					0
#define	ENTITY_TYPE_ID					1

#define	AT_ENTITY					0x280
#define	CL_NL_ENTITY					0x301
#define	CL_TL_ENTITY					0x401
#define	CO_NL_ENTITY					0x300
#define	CO_TL_ENTITY					0x400
#define	ER_ENTITY					0x380
#define	IF_ENTITY					0x200

#define	AT_ARP						0x280
#define	AT_NULL						0x282
#define	CL_TL_NBF					0x401
#define	CL_TL_UDP					0x403
#define	CL_NL_IPX					0x301
#define	CL_NL_IP					0x303
#define	CO_TL_NBF					0x400
#define	CO_TL_SPX					0x402
#define	CO_TL_TCP					0x404
#define	CO_TL_SPP					0x406
#define	ER_ICMP						0x380
#define	IF_GENERIC					0x200
#define	IF_MIB						0x202

/* TDIObjectID.toi_class constants */
#define	INFO_CLASS_GENERIC				0x100
#define	INFO_CLASS_PROTOCOL				0x200
#define	INFO_CLASS_IMPLEMENTATION			0x300

/* TDIObjectID.toi_type constants */
#define	INFO_TYPE_PROVIDER				0x100
#define	INFO_TYPE_ADDRESS_OBJECT			0x200
#define	INFO_TYPE_CONNECTION				0x300

typedef struct _TDIObjectID {
	TDIEntityID  toi_entity;
	ULONG  toi_class;
	ULONG  toi_type;
	ULONG  toi_id;
} TDIObjectID;

#define	CONTEXT_SIZE					16

typedef struct _TCP_REQUEST_QUERY_INFORMATION_EX {
  TDIObjectID  ID;
  ULONG_PTR  Context[CONTEXT_SIZE / sizeof(ULONG_PTR)];
} TCP_REQUEST_QUERY_INFORMATION_EX, *PTCP_REQUEST_QUERY_INFORMATION_EX;

#if defined(_WIN64)
typedef struct _TCP_REQUEST_QUERY_INFORMATION_EX32 {
  TDIObjectID  ID;
  ULONG32  Context[CONTEXT_SIZE / sizeof(ULONG32)];
} TCP_REQUEST_QUERY_INFORMATION_EX32, *PTCP_REQUEST_QUERY_INFORMATION_EX32;
#endif /* _WIN64 */

typedef struct _TCP_REQUEST_SET_INFORMATION_EX {
  TDIObjectID  ID;
  unsigned int BufferSize;
  unsigned char Buffer[1];
} TCP_REQUEST_SET_INFORMATION_EX, *PTCP_REQUEST_SET_INFORMATION_EX;

#ifdef __cplusplus
}
#endif

#endif /* __TDIINFO_H */
