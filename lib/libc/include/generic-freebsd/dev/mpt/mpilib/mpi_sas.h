/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 2000-2010, LSI Logic Corporation and its contributors.
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce at minimum a disclaimer
 *    substantially similar to the "NO WARRANTY" disclaimer below
 *    ("Disclaimer") and any redistribution must be conditioned upon including
 *    a substantially similar Disclaimer requirement for further binary
 *    redistribution.
 * 3. Neither the name of the LSI Logic Corporation nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF THE COPYRIGHT
 * OWNER OR CONTRIBUTOR IS ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *           Name:  mpi_sas.h
 *          Title:  MPI Serial Attached SCSI structures and definitions
 *  Creation Date:  August 19, 2004
 *
 *    mpi_sas.h Version:  01.05.05
 *
 *  Version History
 *  ---------------
 *
 *  Date      Version   Description
 *  --------  --------  ------------------------------------------------------
 *  08-19-04  01.05.01  Original release.
 *  08-30-05  01.05.02  Added DeviceInfo bit for SEP.
 *                      Added PrimFlags and Primitive field to SAS IO Unit
 *                      Control request, and added a new operation code.
 *  03-27-06  01.05.03  Added Force Full Discovery, Transmit Port Select Signal,
 *                      and Remove Device operations to SAS IO Unit Control.
 *                      Added DevHandle field to SAS IO Unit Control request and
 *                      reply.
 *  10-11-06  01.05.04  Fixed the name of a define for Operation field of SAS IO
 *                      Unit Control request.
 *  01-15-08  01.05.05  Added support for MPI_SAS_OP_SET_IOC_PARAMETER,
 *                      including adding IOCParameter and IOCParameter value
 *                      fields to SAS IO Unit Control Request.
 *                      Added MPI_SAS_DEVICE_INFO_PRODUCT_SPECIFIC define.
 *  --------------------------------------------------------------------------
 */

#ifndef MPI_SAS_H
#define MPI_SAS_H

/*
 * Values for SASStatus.
 */
#define MPI_SASSTATUS_SUCCESS                           (0x00)
#define MPI_SASSTATUS_UNKNOWN_ERROR                     (0x01)
#define MPI_SASSTATUS_INVALID_FRAME                     (0x02)
#define MPI_SASSTATUS_UTC_BAD_DEST                      (0x03)
#define MPI_SASSTATUS_UTC_BREAK_RECEIVED                (0x04)
#define MPI_SASSTATUS_UTC_CONNECT_RATE_NOT_SUPPORTED    (0x05)
#define MPI_SASSTATUS_UTC_PORT_LAYER_REQUEST            (0x06)
#define MPI_SASSTATUS_UTC_PROTOCOL_NOT_SUPPORTED        (0x07)
#define MPI_SASSTATUS_UTC_STP_RESOURCES_BUSY            (0x08)
#define MPI_SASSTATUS_UTC_WRONG_DESTINATION             (0x09)
#define MPI_SASSTATUS_SHORT_INFORMATION_UNIT            (0x0A)
#define MPI_SASSTATUS_LONG_INFORMATION_UNIT             (0x0B)
#define MPI_SASSTATUS_XFER_RDY_INCORRECT_WRITE_DATA     (0x0C)
#define MPI_SASSTATUS_XFER_RDY_REQUEST_OFFSET_ERROR     (0x0D)
#define MPI_SASSTATUS_XFER_RDY_NOT_EXPECTED             (0x0E)
#define MPI_SASSTATUS_DATA_INCORRECT_DATA_LENGTH        (0x0F)
#define MPI_SASSTATUS_DATA_TOO_MUCH_READ_DATA           (0x10)
#define MPI_SASSTATUS_DATA_OFFSET_ERROR                 (0x11)
#define MPI_SASSTATUS_SDSF_NAK_RECEIVED                 (0x12)
#define MPI_SASSTATUS_SDSF_CONNECTION_FAILED            (0x13)
#define MPI_SASSTATUS_INITIATOR_RESPONSE_TIMEOUT        (0x14)

/*
 * Values for the SAS DeviceInfo field used in SAS Device Status Change Event
 * data and SAS IO Unit Configuration pages.
 */
#define MPI_SAS_DEVICE_INFO_PRODUCT_SPECIFIC    (0xF0000000)

#define MPI_SAS_DEVICE_INFO_SEP                 (0x00004000)
#define MPI_SAS_DEVICE_INFO_ATAPI_DEVICE        (0x00002000)
#define MPI_SAS_DEVICE_INFO_LSI_DEVICE          (0x00001000)
#define MPI_SAS_DEVICE_INFO_DIRECT_ATTACH       (0x00000800)
#define MPI_SAS_DEVICE_INFO_SSP_TARGET          (0x00000400)
#define MPI_SAS_DEVICE_INFO_STP_TARGET          (0x00000200)
#define MPI_SAS_DEVICE_INFO_SMP_TARGET          (0x00000100)
#define MPI_SAS_DEVICE_INFO_SATA_DEVICE         (0x00000080)
#define MPI_SAS_DEVICE_INFO_SSP_INITIATOR       (0x00000040)
#define MPI_SAS_DEVICE_INFO_STP_INITIATOR       (0x00000020)
#define MPI_SAS_DEVICE_INFO_SMP_INITIATOR       (0x00000010)
#define MPI_SAS_DEVICE_INFO_SATA_HOST           (0x00000008)

#define MPI_SAS_DEVICE_INFO_MASK_DEVICE_TYPE    (0x00000007)
#define MPI_SAS_DEVICE_INFO_NO_DEVICE           (0x00000000)
#define MPI_SAS_DEVICE_INFO_END_DEVICE          (0x00000001)
#define MPI_SAS_DEVICE_INFO_EDGE_EXPANDER       (0x00000002)
#define MPI_SAS_DEVICE_INFO_FANOUT_EXPANDER     (0x00000003)

/*****************************************************************************
*
*        S e r i a l    A t t a c h e d    S C S I     M e s s a g e s
*
*****************************************************************************/

/****************************************************************************/
/* Serial Management Protocol Passthrough Request                           */
/****************************************************************************/

typedef struct _MSG_SMP_PASSTHROUGH_REQUEST
{
    U8                      PassthroughFlags;   /* 00h */
    U8                      PhysicalPort;       /* 01h */
    U8                      ChainOffset;        /* 02h */
    U8                      Function;           /* 03h */
    U16                     RequestDataLength;  /* 04h */
    U8                      ConnectionRate;     /* 06h */
    U8                      MsgFlags;           /* 07h */
    U32                     MsgContext;         /* 08h */
    U32                     Reserved1;          /* 0Ch */
    U64                     SASAddress;         /* 10h */
    U32                     Reserved2;          /* 18h */
    U32                     Reserved3;          /* 1Ch */
    SGE_SIMPLE_UNION        SGL;                /* 20h */
} MSG_SMP_PASSTHROUGH_REQUEST, MPI_POINTER PTR_MSG_SMP_PASSTHROUGH_REQUEST,
  SmpPassthroughRequest_t, MPI_POINTER pSmpPassthroughRequest_t;

/* values for PassthroughFlags field */
#define MPI_SMP_PT_REQ_PT_FLAGS_IMMEDIATE       (0x80)

/* values for ConnectionRate field */
#define MPI_SMP_PT_REQ_CONNECT_RATE_NEGOTIATED  (0x00)
#define MPI_SMP_PT_REQ_CONNECT_RATE_1_5         (0x08)
#define MPI_SMP_PT_REQ_CONNECT_RATE_3_0         (0x09)

/* Serial Management Protocol Passthrough Reply */
typedef struct _MSG_SMP_PASSTHROUGH_REPLY
{
    U8                      PassthroughFlags;   /* 00h */
    U8                      PhysicalPort;       /* 01h */
    U8                      MsgLength;          /* 02h */
    U8                      Function;           /* 03h */
    U16                     ResponseDataLength; /* 04h */
    U8                      Reserved1;          /* 06h */
    U8                      MsgFlags;           /* 07h */
    U32                     MsgContext;         /* 08h */
    U8                      Reserved2;          /* 0Ch */
    U8                      SASStatus;          /* 0Dh */
    U16                     IOCStatus;          /* 0Eh */
    U32                     IOCLogInfo;         /* 10h */
    U32                     Reserved3;          /* 14h */
    U8                      ResponseData[4];    /* 18h */
} MSG_SMP_PASSTHROUGH_REPLY, MPI_POINTER PTR_MSG_SMP_PASSTHROUGH_REPLY,
  SmpPassthroughReply_t, MPI_POINTER pSmpPassthroughReply_t;

#define MPI_SMP_PT_REPLY_PT_FLAGS_IMMEDIATE     (0x80)

/****************************************************************************/
/* SATA Passthrough Request                                                 */
/****************************************************************************/

typedef struct _MSG_SATA_PASSTHROUGH_REQUEST
{
    U8                      TargetID;           /* 00h */
    U8                      Bus;                /* 01h */
    U8                      ChainOffset;        /* 02h */
    U8                      Function;           /* 03h */
    U16                     PassthroughFlags;   /* 04h */
    U8                      ConnectionRate;     /* 06h */
    U8                      MsgFlags;           /* 07h */
    U32                     MsgContext;         /* 08h */
    U32                     Reserved1;          /* 0Ch */
    U32                     Reserved2;          /* 10h */
    U32                     Reserved3;          /* 14h */
    U32                     DataLength;         /* 18h */
    U8                      CommandFIS[20];     /* 1Ch */
    SGE_SIMPLE_UNION        SGL;                /* 30h */
} MSG_SATA_PASSTHROUGH_REQUEST, MPI_POINTER PTR_MSG_SATA_PASSTHROUGH_REQUEST,
  SataPassthroughRequest_t, MPI_POINTER pSataPassthroughRequest_t;

/* values for PassthroughFlags field */
#define MPI_SATA_PT_REQ_PT_FLAGS_RESET_DEVICE   (0x0200)
#define MPI_SATA_PT_REQ_PT_FLAGS_EXECUTE_DIAG   (0x0100)
#define MPI_SATA_PT_REQ_PT_FLAGS_DMA_QUEUED     (0x0080)
#define MPI_SATA_PT_REQ_PT_FLAGS_PACKET_COMMAND (0x0040)
#define MPI_SATA_PT_REQ_PT_FLAGS_DMA            (0x0020)
#define MPI_SATA_PT_REQ_PT_FLAGS_PIO            (0x0010)
#define MPI_SATA_PT_REQ_PT_FLAGS_UNSPECIFIED_VU (0x0004)
#define MPI_SATA_PT_REQ_PT_FLAGS_WRITE          (0x0002)
#define MPI_SATA_PT_REQ_PT_FLAGS_READ           (0x0001)

/* values for ConnectionRate field */
#define MPI_SATA_PT_REQ_CONNECT_RATE_NEGOTIATED (0x00)
#define MPI_SATA_PT_REQ_CONNECT_RATE_1_5        (0x08)
#define MPI_SATA_PT_REQ_CONNECT_RATE_3_0        (0x09)

/* SATA Passthrough Reply */
typedef struct _MSG_SATA_PASSTHROUGH_REPLY
{
    U8                      TargetID;           /* 00h */
    U8                      Bus;                /* 01h */
    U8                      MsgLength;          /* 02h */
    U8                      Function;           /* 03h */
    U16                     PassthroughFlags;   /* 04h */
    U8                      Reserved1;          /* 06h */
    U8                      MsgFlags;           /* 07h */
    U32                     MsgContext;         /* 08h */
    U8                      Reserved2;          /* 0Ch */
    U8                      SASStatus;          /* 0Dh */
    U16                     IOCStatus;          /* 0Eh */
    U32                     IOCLogInfo;         /* 10h */
    U8                      StatusFIS[20];      /* 14h */
    U32                     StatusControlRegisters; /* 28h */
    U32                     TransferCount;      /* 2Ch */
} MSG_SATA_PASSTHROUGH_REPLY, MPI_POINTER PTR_MSG_SATA_PASSTHROUGH_REPLY,
  SataPassthroughReply_t, MPI_POINTER pSataPassthroughReply_t;

/****************************************************************************/
/* SAS IO Unit Control Request                                              */
/****************************************************************************/

typedef struct _MSG_SAS_IOUNIT_CONTROL_REQUEST
{
    U8                      Operation;          /* 00h */
    U8                      Reserved1;          /* 01h */
    U8                      ChainOffset;        /* 02h */
    U8                      Function;           /* 03h */
    U16                     DevHandle;          /* 04h */
    U8                      IOCParameter;       /* 06h */
    U8                      MsgFlags;           /* 07h */
    U32                     MsgContext;         /* 08h */
    U8                      TargetID;           /* 0Ch */
    U8                      Bus;                /* 0Dh */
    U8                      PhyNum;             /* 0Eh */
    U8                      PrimFlags;          /* 0Fh */
    U32                     Primitive;          /* 10h */
    U64                     SASAddress;         /* 14h */
    U32                     IOCParameterValue;  /* 1Ch */
} MSG_SAS_IOUNIT_CONTROL_REQUEST, MPI_POINTER PTR_MSG_SAS_IOUNIT_CONTROL_REQUEST,
  SasIoUnitControlRequest_t, MPI_POINTER pSasIoUnitControlRequest_t;

/* values for the Operation field */
#define MPI_SAS_OP_CLEAR_NOT_PRESENT            (0x01)
#define MPI_SAS_OP_CLEAR_ALL_PERSISTENT         (0x02)
#define MPI_SAS_OP_PHY_LINK_RESET               (0x06)
#define MPI_SAS_OP_PHY_HARD_RESET               (0x07)
#define MPI_SAS_OP_PHY_CLEAR_ERROR_LOG          (0x08)
#define MPI_SAS_OP_MAP_CURRENT                  (0x09)
#define MPI_SAS_OP_SEND_PRIMITIVE               (0x0A)
#define MPI_SAS_OP_FORCE_FULL_DISCOVERY         (0x0B)
#define MPI_SAS_OP_TRANSMIT_PORT_SELECT_SIGNAL  (0x0C)
#define MPI_SAS_OP_TRANSMIT_REMOVE_DEVICE       (0x0D)  /* obsolete name */
#define MPI_SAS_OP_REMOVE_DEVICE                (0x0D)
#define MPI_SAS_OP_SET_IOC_PARAMETER            (0x0E)
#define MPI_SAS_OP_PRODUCT_SPECIFIC_MIN         (0x80)

/* values for the PrimFlags field */
#define MPI_SAS_PRIMFLAGS_SINGLE                (0x08)
#define MPI_SAS_PRIMFLAGS_TRIPLE                (0x02)
#define MPI_SAS_PRIMFLAGS_REDUNDANT             (0x01)

/* SAS IO Unit Control Reply */
typedef struct _MSG_SAS_IOUNIT_CONTROL_REPLY
{
    U8                      Operation;          /* 00h */
    U8                      Reserved1;          /* 01h */
    U8                      MsgLength;          /* 02h */
    U8                      Function;           /* 03h */
    U16                     DevHandle;          /* 04h */
    U8                      IOCParameter;       /* 06h */
    U8                      MsgFlags;           /* 07h */
    U32                     MsgContext;         /* 08h */
    U16                     Reserved4;          /* 0Ch */
    U16                     IOCStatus;          /* 0Eh */
    U32                     IOCLogInfo;         /* 10h */
} MSG_SAS_IOUNIT_CONTROL_REPLY, MPI_POINTER PTR_MSG_SAS_IOUNIT_CONTROL_REPLY,
  SasIoUnitControlReply_t, MPI_POINTER pSasIoUnitControlReply_t;

#endif