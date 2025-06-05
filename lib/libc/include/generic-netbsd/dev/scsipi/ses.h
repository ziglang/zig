/* $NetBSD: ses.h,v 1.4 2015/09/06 06:01:01 dholland Exp $ */
/*
 * Copyright (C) 2000 National Aeronautics & Space Administration
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <sys/ioccom.h>

#define	SESIOC			(('s' - 040) << 8)
#define	SESIOC_GETNOBJ		_IO(SESIOC, 1)
#define	SESIOC_GETOBJMAP	_IO(SESIOC, 2)
#define	SESIOC_GETENCSTAT	_IO(SESIOC, 3)
#define	SESIOC_SETENCSTAT	_IO(SESIOC, 4)
#define	SESIOC_GETOBJSTAT	_IO(SESIOC, 5)
#define	SESIOC_SETOBJSTAT	_IO(SESIOC, 6)
#define	SESIOC_GETTEXT		_IO(SESIOC, 7)
#define	SESIOC_INIT		_IO(SESIOC, 8)

/*
 * Platform Independent Definitions for SES devices.
 */
/*
 * SCSI Based Environmental Services Application Defines
 *
 * Based almost entirely on SCSI-3 SES Revision 8A specification,
 * but slightly abstracted as the underlying device may in fact
 * be a SAF-TE or vendor unique device.
 */
/*
 * SES Driver Operations:
 * (The defines themselves are platform and access method specific)
 *
 * SESIOC_GETNOBJ
 * SESIOC_GETOBJMAP
 * SESIOC_GETENCSTAT
 * SESIOC_SETENCSTAT
 * SESIOC_GETOBJSTAT
 * SESIOC_SETOBJSTAT
 * SESIOC_INIT
 *
 *
 * An application finds out how many objects an SES instance
 * is managing by performing a SESIOC_GETNOBJ operation. It then
 * performs a SESIOC_GETOBJMAP to get the map that contains the
 * object identifiers for all objects (see ses_object below).
 * This information is static.
 *
 * The application may perform SESIOC_GETOBJSTAT operations to retrieve
 * status on an object (see the ses_objstat structure below), SESIOC_SETOBJSTAT
 * operations to set status for an object.
 *
 * Similarly overall enclosure status me be fetched or set via
 * SESIOC_GETENCSTAT or  SESIOC_SETENCSTAT operations (see ses_encstat below).
 *
 * Readers should note that there is nothing that requires either a set
 * or a clear operation to actually latch and do anything in the target.
 *
 * A SESIOC_INIT operation causes the enclosure to be initialized.
 */

typedef struct {
	unsigned int	obj_id;		/* Object Identifier */
	unsigned char	subencid;	/* SubEnclosure ID */
	unsigned char	object_type;	/* Object Type */
} ses_object;

/* Object Types */
#define	SESTYP_UNSPECIFIED	0x00
#define	SESTYP_DEVICE		0x01
#define	SESTYP_POWER		0x02
#define	SESTYP_FAN		0x03
#define	SESTYP_THERM		0x04
#define	SESTYP_DOORLOCK		0x05
#define	SESTYP_ALARM		0x06
#define	SESTYP_ESCC		0x07	/* Enclosure SCC */
#define	SESTYP_SCC		0x08	/* SCC */
#define	SESTYP_NVRAM		0x09
#define	SESTYP_UPS		0x0b
#define	SESTYP_DISPLAY		0x0c
#define	SESTYP_KEYPAD		0x0d
#define	SESTYP_SCSIXVR		0x0f
#define	SESTYP_LANGUAGE		0x10
#define	SESTYP_COMPORT		0x11
#define	SESTYP_VOM		0x12
#define	SESTYP_AMMETER		0x13
#define	SESTYP_SCSI_TGT		0x14
#define	SESTYP_SCSI_INI		0x15
#define	SESTYP_SUBENC		0x16

/*
 * Overall Enclosure Status
 */
typedef unsigned char ses_encstat;
#define	SES_ENCSTAT_UNRECOV		0x1
#define	SES_ENCSTAT_CRITICAL		0x2
#define	SES_ENCSTAT_NONCRITICAL		0x4
#define	SES_ENCSTAT_INFO		0x8

/*
 * Object Status
 */
typedef struct {
	unsigned int	obj_id;
	unsigned char	cstat[4];
} ses_objstat;

/* Summary SES Status Defines, Common Status Codes */
#define	SES_OBJSTAT_UNSUPPORTED		0
#define	SES_OBJSTAT_OK			1
#define	SES_OBJSTAT_CRIT		2
#define	SES_OBJSTAT_NONCRIT		3
#define	SES_OBJSTAT_UNRECOV		4
#define	SES_OBJSTAT_NOTINSTALLED	5
#define	SES_OBJSTAT_UNKNOWN		6
#define	SES_OBJSTAT_NOTAVAIL		7

/*
 * For control pages, cstat[0] is the same for the
 * enclosure and is common across all device types.
 *
 * If SESCTL_CSEL is set, then PRDFAIL, DISABLE and RSTSWAP
 * are checked, otherwise bits that are specific to the device
 * type in the other 3 bytes of cstat or checked.
 */
#define	SESCTL_CSEL		0x80
#define	SESCTL_PRDFAIL		0x40
#define	SESCTL_DISABLE		0x20
#define	SESCTL_RSTSWAP		0x10


/* Control bits, Device Elements, byte 2 */
#define	SESCTL_DRVLCK	0x40	/* "DO NOT REMOVE" */
#define	SESCTL_RQSINS	0x08	/* RQST INSERT */
#define	SESCTL_RQSRMV	0x04	/* RQST REMOVE */
#define	SESCTL_RQSID	0x02	/* RQST IDENT */
/* Control bits, Device Elements, byte 3 */
#define	SESCTL_RQSFLT	0x20	/* RQST FAULT */
#define	SESCTL_DEVOFF	0x10	/* DEVICE OFF */

/* Control bits, Generic, byte 3 */
#define	SESCTL_RQSTFAIL	0x40
#define	SESCTL_RQSTON	0x20

/*
 * Getting text for an object type is a little
 * trickier because it's string data that can
 * go up to 64 KBytes. Build this union and
 * fill the obj_id with the id of the object who's
 * help text you want, and if text is available,
 * obj_text will be filled in, null terminated.
 */

typedef union {
	unsigned int obj_id;
	char obj_text[1];
} ses_hlptxt;