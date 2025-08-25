/*	$NetBSD: scsi_all.h,v 1.25 2012/02/25 10:17:14 shattered Exp $	*/

/*
 * SCSI-specific interface description.
 */

/*
 * Largely written by Julian Elischer (julian@tfs.com)
 * for TRW Financial Systems.
 *
 * TRW Financial Systems, in accordance with their agreement with Carnegie
 * Mellon University, makes this software available to CMU to distribute
 * or use in any manner that they see fit as long as this message is kept with
 * the software. For this reason TFS also grants any other persons or
 * organisations permission to use or modify this software.
 *
 * TFS supplies this software to be publicly redistributed
 * on the understanding that TFS is not responsible for the correct
 * functioning of this software in any circumstances.
 *
 * Ported to run under 386BSD by Julian Elischer (julian@tfs.com) Sept 1992
 */

#ifndef _DEV_SCSIPI_SCSI_ALL_H_
#define _DEV_SCSIPI_SCSI_ALL_H_

/*
 * Define some bits that are in ALL (or a lot of) scsi commands
 */
#define	SCSI_CTL_LINK		0x01
#define	SCSI_CTL_FLAG		0x02
#define	SCSI_CTL_VENDOR		0xC0


/*
 * Some old SCSI devices need the LUN to be set in the top 3 bits of the
 * second byte of the CDB.
 */
#define	SCSI_CMD_LUN_MASK	0xe0
#define	SCSI_CMD_LUN_SHIFT	5

#define	SCSI_CHANGE_DEFINITION	0x40
struct scsi_changedef {
	u_int8_t opcode;
	u_int8_t byte2;
	u_int8_t unused1;
	u_int8_t how;
	u_int8_t unused[4];
	u_int8_t datalen;
	u_int8_t control;
};
#define	SC_SCSI_1 0x01
#define	SC_SCSI_2 0x03

/*
 * Status Byte
 */
#define	SCSI_OK			0x00
#define	SCSI_CHECK		0x02
#define	SCSI_BUSY		0x08
#define	SCSI_INTERM		0x10
#define	SCSI_RESV_CONFLICT	0x18
#define	SCSI_TERMINATED		0x22
#define	SCSI_QUEUE_FULL		0x28
#define	SCSI_ACA_ACTIVE		0x30

#endif /* _DEV_SCSIPI_SCSI_ALL_H_ */