/*	$NetBSD: chio.h,v 1.13 2015/09/06 06:01:02 dholland Exp $	*/

/*-
 * Copyright (c) 1996, 1999 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe of the Numerical Aerospace Simulation Facility,
 * NASA Ames Research Center.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _SYS_CHIO_H_
#define _SYS_CHIO_H_

#include <sys/ioccom.h>

/*
 * Element types.  Used as "to" and "from" type indicators in move
 * and exchange operations.
 *
 * Note that code in sys/dev/scsipi/ch.c relies on these values (uses
 * them as offsets in an array, and other evil), so don't muck with them
 * unless you know what you're doing.
 */
#define CHET_MT		0	/* medium transport (picker) */
#define CHET_ST		1	/* storage transport (slot) */
#define CHET_IE		2	/* import/export (portal) */
#define CHET_DT		3	/* data transfer (drive) */

/*
 * Structure used to execute a MOVE MEDIUM command.
 */
struct changer_move_request {
	int	cm_fromtype;	/* element type to move from */
	int	cm_fromunit;	/* logical unit of from element */
	int	cm_totype;	/* element type to move to */
	int	cm_tounit;	/* logical unit of to element */
	int	cm_flags;	/* misc. flags */
};

/* cm_flags */
#define CM_INVERT	0x01	/* invert media */

/*
 * Structure used to execute an EXCHANGE MEDIUM command.  In an
 * exchange operation, the following steps occur:
 *
 *	- media from source is moved to first destination.
 *
 *	- media previously occupying first destination is moved
 *	  to the second destination.
 *
 * The second destination may or may not be the same as the source.
 * In the case of a simple exchange, the source and second destination
 * are the same.
 */
struct changer_exchange_request {
	int	ce_srctype;	/* element type of source */
	int	ce_srcunit;	/* logical unit of source */
	int	ce_fdsttype;	/* element type of first destination */
	int	ce_fdstunit;	/* logical unit of first destination */
	int	ce_sdsttype;	/* element type of second destination */
	int	ce_sdstunit;	/* logical unit of second destination */
	int	ce_flags;	/* misc. flags */
};

/* ce_flags */
#define CE_INVERT1	0x01	/* invert media 1 */
#define CE_INVERT2	0x02	/* invert media 2 */

/*
 * Structure used to execute a POSITION TO ELEMENT command.  This
 * moves the current picker in front of the specified element.
 */
struct changer_position_request {
	int	cp_type;	/* element type */
	int	cp_unit;	/* logical unit of element */
	int	cp_flags;	/* misc. flags */
};

/* cp_flags */
#define CP_INVERT	0x01	/* invert picker */

/*
 * Data returned by CHIOGPARAMS.
 */
struct changer_params {
	int	cp_curpicker;	/* current picker */
	int	cp_npickers;	/* number of pickers */
	int	cp_nslots;	/* number of slots */
	int	cp_nportals;	/* number of import/export portals */
	int	cp_ndrives;	/* number of drives */
};

/*
 * Old-style command used to get element status.
 */
struct ochanger_element_status_request {
	int	cesr_type;	/* element type */
	uint8_t *cesr_data;	/* pre-allocated data storage */
};

/*
 * Structure of a changer volume tag.
 */
#define	CHANGER_VOLTAG_SIZE	32	/* same as SCSI voltag size */
struct changer_voltag {
	char	cv_tag[CHANGER_VOLTAG_SIZE + 1];	/* ASCII tag */
	uint16_t cv_serial;				/* serial number */
};

/*
 * Data returned by CHIOGSTATUS.
 */
struct changer_element_status {
	int	ces_flags;	/* CESTATUS_* flags; see below */

	/*
	 * The following is only valid on Data Transport elements (drives).
	 */
	char	ces_xname[16];	/* external name of drive device */

	/*
	 * The following fieds indicate the element the medium was
	 * moved from in order to arrive in this element.
	 */
	int	ces_from_type;	/* type of element */
	int	ces_from_unit;	/* logical unit of element */

	/*
	 * Volume tag information.
	 */
	struct changer_voltag ces_pvoltag;	/* primary volume tag */
	struct changer_voltag ces_avoltag;	/* alternate volume tag */

	size_t	ces_vendor_len;	/* length of any vendor-specific data */

	/*
	 * These two fields are only valid if CESTATUS_EXCEPT is
	 * set in ces_flags, and are only valid on SCSI changers.
	 */
	uint8_t ces_asc;	/* Additional Sense Code */
	uint8_t ces_ascq;	/* Additional Sense Code Qualifier */

	/*
	 * These two fields may be useful if ces_xname is not valid.
	 * They indicate the target and lun of a drive element.  These
	 * are only valid on SCSI changers.
	 */
	uint8_t ces_target;	/* SCSI target of drive */
	uint8_t ces_lun;	/* SCSI LUN of drive */
};

/*
 * Flags for changer_element_status.  These are flags that are returned
 * by hardware.  Not all flags have meaning for all element types.
 */
#define CESTATUS_FULL		0x0001	/* element is full */
#define CESTATUS_IMPEXP		0x0002	/* media deposited by operator */
#define CESTATUS_EXCEPT		0x0004	/* element in abnormal state */
#define CESTATUS_ACCESS		0x0008	/* media accessible by picker */
#define CESTATUS_EXENAB		0x0010	/* element supports exporting */
#define CESTATUS_INENAB		0x0020	/* element supports importing */

#define CESTATUS_PICKER_MASK	0x0005	/* flags valid for pickers */
#define CESTATUS_SLOT_MASK	0x000c	/* flags valid for slots */
#define CESTATUS_PORTAL_MASK	0x003f	/* flags valid for portals */
#define CESTATUS_DRIVE_MASK	0x000c	/* flags valid for drives */

#define	CESTATUS_INVERTED	0x0040	/* medium inverted from storage */
#define	CESTATUS_NOTBUS		0x0080	/* drive not on same bus as changer */

/*
 * These changer_element_status flags indicate the validity of fields
 * in the returned data.
 */
#define	CESTATUS_STATUS_VALID	0x0100	/* entire structure valid */
#define	CESTATUS_XNAME_VALID	0x0200	/* ces_xname valid */
#define	CESTATUS_FROM_VALID	0x0400	/* ces_from_* valid */
#define	CESTATUS_PVOL_VALID	0x0800	/* ces_pvoltag valid */
#define	CESTATUS_AVOL_VALID	0x1000	/* ces_avoltag valid */
#define	CESTATUS_TARGET_VALID	0x2000	/* ces_target valid */
#define	CESTATUS_LUN_VALID	0x4000	/* ces_lun valid */

#define CESTATUS_BITS	\
	"\20\6INEAB\5EXENAB\4ACCESS\3EXCEPT\2IMPEXP\1FULL"

/*
 * Command used to get element status.
 */
struct changer_element_status_request {
	int	cesr_type;	/* element type */
	int	cesr_unit;	/* start at this unit */
	int	cesr_count;	/* for this many units */
	int	cesr_flags;	/* flags; see below */
				/* pre-allocated data storage */
	/*
	 * These fields point to the data to be returned to the
	 * user:
	 *
	 *	cesr_deta: pointer to array of cesr_count status descriptors
	 *
	 *	cesr_vendor_data: pointer to array of void *'s which point
	 *	to pre-allocated areas for vendor-specific data.  Optional.
	 */
	struct changer_element_status *cesr_data;
	void	**cesr_vendor_data;
};

#define	CESR_VOLTAGS		0x01	/* request volume tags */

/*
 * Command used to modify a media element's volume tag.
 */
struct changer_set_voltag_request {
	int	csvr_type;	/* element type */
	int	csvr_unit;	/* unit to modify */
	int	csvr_flags;	/* flags; see below */
				/* the actual volume tag; ignored if clearing
				   the tag */
	struct changer_voltag csvr_voltag;
};

#define	CSVR_MODE_SET		0x00	/* set volume tag if not set */
#define	CSVR_MODE_REPLACE	0x01	/* unconditionally replace volume tag */
#define	CSVR_MODE_CLEAR		0x02	/* clear volume tag */
#define	CSVR_MODE_MASK		0x0f
#define	CSVR_ALTERNATE		0x10	/* modify alternate volume tag */

/*
 * Changer events.
 *
 * When certain events occur, the kernel can indicate this by setting
 * a bit in a bitmask.
 *
 * When a read is issued to the changer, the kernel returns this event
 * bitmask.  The read never blocks; if no events are pending, the bitmask
 * will be all-clear.
 *
 * A process may select for read to wait for an event to occur.
 *
 * The event mask is cleared when the changer is closed.
 */
#define	CHANGER_EVENT_SIZE		sizeof(u_int)
#define	CHEV_ELEMENT_STATUS_CHANGED	0x00000001

/*
 * ioctls applicable to changers.
 */
#define CHIOMOVE	_IOW('c', 0x01, struct changer_move_request)
#define CHIOEXCHANGE	_IOW('c', 0x02, struct changer_exchange_request)
#define CHIOPOSITION	_IOW('c', 0x03, struct changer_position_request)
#define CHIOGPICKER	_IOR('c', 0x04, int)
#define CHIOSPICKER	_IOW('c', 0x05, int)
#define CHIOGPARAMS	_IOR('c', 0x06, struct changer_params)
#define CHIOIELEM	 _IO('c', 0x07)
#define OCHIOGSTATUS	_IOW('c', 0x08, struct ochanger_element_status_request)
#define	CHIOGSTATUS	_IOW('c', 0x09, struct changer_element_status_request)
#define	CHIOSVOLTAG	_IOW('c', 0x0a, struct changer_set_voltag_request)

#endif /* _SYS_CHIO_H_ */