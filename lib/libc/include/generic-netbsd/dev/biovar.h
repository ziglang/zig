/*	$NetBSD: biovar.h,v 1.11 2022/05/10 14:13:09 msaitoh Exp $ */
/*	$OpenBSD: biovar.h,v 1.26 2007/03/19 03:02:08 marco Exp $	*/

/*
 * Copyright (c) 2002 Niklas Hallqvist.  All rights reserved.
 * Copyright (c) 2005 Marco Peereboom.  All rights reserved.
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

/*
 * Devices getting ioctls through this interface should use ioctl class 'B'
 * and command numbers starting from 32, lower ones are reserved for generic
 * ioctls.  All ioctl data must be structures which start with a void *
 * cookie.
 */

#ifndef _DEV_BIOVAR_H_
#define _DEV_BIOVAR_H_

#include <sys/types.h>
#include <sys/device.h>
#include <sys/ioccom.h>

#ifndef _KERNEL
#include <stdbool.h>
#endif

struct bio_common {
	void		*bc_cookie;
};

/* convert name to a cookie */
#define BIOCLOCATE _IOWR('B', 0, struct bio_locate)
struct bio_locate {
	void		*bl_cookie;
	char		*bl_name;
};

#ifdef _KERNEL
int	bio_register(device_t, int (*)(device_t, u_long, void *));
void	bio_unregister(device_t);
#endif

#define BIOCINQ _IOWR('B', 32, struct bioc_inq)
struct bioc_inq {
	void		*bi_cookie;

	char		bi_dev[16];	/* controller device */
	int		bi_novol;	/* nr of volumes */
	int		bi_nodisk;	/* nr of total disks */
};

#define BIOCDISK_NOVOL 	_IOWR('b', 38, struct bioc_disk)
#define BIOCDISK 	_IOWR('B', 33, struct bioc_disk)
/* structure that represents a disk in a RAID volume */
struct bioc_disk {
	void		*bd_cookie;

	uint16_t	bd_channel;
	uint16_t	bd_target;
	uint16_t	bd_lun;
	uint16_t	bd_other_id;	/* unused for now  */

	int		bd_volid;	/* associate with volume */
	int		bd_diskid;	/* virtual disk */
	int		bd_status;	/* current status */
#define BIOC_SDONLINE		0x00
#define BIOC_SDONLINE_S		"Online"
#define BIOC_SDOFFLINE		0x01
#define BIOC_SDOFFLINE_S	"Offline"
#define BIOC_SDFAILED		0x02
#define BIOC_SDFAILED_S 	"Failed"
#define BIOC_SDREBUILD		0x03
#define BIOC_SDREBUILD_S	"Rebuild"
#define BIOC_SDHOTSPARE		0x04
#define BIOC_SDHOTSPARE_S	"Hot spare"
#define BIOC_SDUNUSED		0x05
#define BIOC_SDUNUSED_S		"Unused"
#define BIOC_SDSCRUB		0x06
#define BIOC_SDSCRUB_S		"Scrubbing"
#define BIOC_SDPASSTHRU 	0x07
#define BIOC_SDPASSTHRU_S 	"Pass through"
#define BIOC_SDINVALID		0xff
#define BIOC_SDINVALID_S	"Invalid"
	uint64_t	bd_size;	/* size of the disk */

	char		bd_vendor[32];	/* scsi string */
	char		bd_serial[32];	/* serial number */
	char		bd_procdev[16];	/* processor device */
	
	bool		bd_disknovol;	/* disk not associated with volumes */
};

/* COMPATIBILITY */
#ifdef _KERNEL
#define OBIOCDISK	_IOWR('B', 33, struct obioc_disk)
/* structure that represents a disk in a RAID volume (compat) */
struct obioc_disk {
	void 		*bd_cookie;
	uint16_t	bd_channel;
	uint16_t 	bd_target;
	uint16_t 	bd_lun;
	uint16_t 	bd_other_id;
	int 		bd_volid;
	int 		bd_diskid;
	int 		bd_status;
	uint64_t 	bd_size;
	char 		bd_vendor[32];
	char 		bd_serial[32];
	char 		bd_procdev[16];
};
#endif

#define BIOCVOL _IOWR('B', 34, struct bioc_vol)
/* structure that represents a RAID volume */
struct bioc_vol {
	void		*bv_cookie;
	int		bv_volid;	/* volume id */

	int16_t		bv_percent;	/* percent done operation */
	uint16_t	bv_seconds;	/* seconds of progress so far */

	int		bv_status;	/* current status */
#define BIOC_SVONLINE		0x00
#define BIOC_SVONLINE_S		"Online"
#define BIOC_SVOFFLINE		0x01
#define BIOC_SVOFFLINE_S	"Offline"
#define BIOC_SVDEGRADED		0x02
#define BIOC_SVDEGRADED_S	"Degraded"
#define BIOC_SVBUILDING		0x03
#define BIOC_SVBUILDING_S	"Building"
#define BIOC_SVSCRUB		0x04
#define BIOC_SVSCRUB_S		"Scrubbing"
#define BIOC_SVREBUILD		0x05
#define BIOC_SVREBUILD_S	"Rebuild"
#define BIOC_SVMIGRATING	0x06
#define BIOC_SVMIGRATING_S	"Migrating"
#define BIOC_SVCHECKING 	0x07
#define BIOC_SVCHECKING_S	"Checking"
#define BIOC_SVINVALID		0xff
#define BIOC_SVINVALID_S	"Invalid"
	uint64_t	bv_size;	/* size of the disk */
	int		bv_level;	/* raid level */
#define BIOC_SVOL_RAID01	0x0e
#define BIOC_SVOL_RAID10	0x1e
#define BIOC_SVOL_UNUSED	0xaa
#define BIOC_SVOL_HOTSPARE	0xbb
#define BIOC_SVOL_PASSTHRU	0xcc

	int		bv_nodisk;	/* nr of drives */

	char		bv_dev[16];	/* device */
	char		bv_vendor[32];	/* scsi string */

	uint16_t	bv_stripe_size;	/* stripe size in KB */
};

/* COMPATIBILITY */
#ifdef _KERNEL
#define OBIOCVOL _IOWR('B', 34, struct obioc_vol)
/* structure that represents a RAID volume */
struct obioc_vol {
	void 		*bv_cookie;
	int 		bv_volid;
	int16_t 	bv_percent;
	uint16_t 	bv_seconds;
	int 		bv_status;
	uint64_t 	bv_size;
	int 		bv_level;
	int 		bv_nodisk;
	char 		bv_dev[16];
	char 		bv_vendor[32];
};
#endif

#define BIOCALARM _IOWR('B', 35, struct bioc_alarm)
struct bioc_alarm {
	void		*ba_cookie;
	int		ba_opcode;

	int		ba_status;	/* only used with get state */
#define BIOC_SADISABLE		0x00	/* disable alarm */
#define BIOC_SAENABLE		0x01	/* enable alarm */
#define BIOC_SASILENCE		0x02	/* silence alarm */
#define BIOC_GASTATUS		0x03	/* get status */
#define BIOC_SATEST		0x04	/* test alarm */
};

#define BIOCBLINK _IOWR('B', 36, struct bioc_blink)
struct bioc_blink {
	void		*bb_cookie;
	uint16_t	bb_channel;
	uint16_t	bb_target;

	int		bb_status;	/* current status */
#define BIOC_SBUNBLINK		0x00	/* disable blinking */
#define BIOC_SBBLINK		0x01	/* enable blink */
#define BIOC_SBALARM		0x02	/* enable alarm blink */
};

#define BIOCSETSTATE _IOWR('B', 37, struct bioc_setstate)
struct bioc_setstate {
	void		*bs_cookie;
	uint16_t	bs_channel;
	uint16_t	bs_target;
	uint16_t	bs_lun;
	uint16_t	bs_other_id;	/* unused for now  */

	int		bs_status;	/* change to this status */
#define BIOC_SSONLINE		0x00	/* online disk */
#define BIOC_SSOFFLINE		0x01	/* offline disk */
#define BIOC_SSHOTSPARE		0x02	/* mark as hotspare */
#define BIOC_SSREBUILD		0x03	/* rebuild on this disk */
#define BIOC_SSDELHOTSPARE	0x04	/* unmark as hotspare */
#define BIOC_SSPASSTHRU 	0x05	/* mark as pass-through */
#define BIOC_SSDELPASSTHRU	0x06	/* unmark as pass-through */
#define BIOC_SSCHECKSTART_VOL	0x07	/* start consistency check in vol# */
#define BIOC_SSCHECKSTOP_VOL	0x08	/* stop consistency check in vol# */
	int		bs_volid;	/* volume id for rebuild */
};

#define BIOCVOLOPS _IOWR('B', 39, struct bioc_volops)
struct bioc_volops {
	void		*bc_cookie;
	uint64_t	bc_size;	/* size of the volume set */
	uint64_t	bc_other_id;	/* unused for now */
	uint32_t	bc_devmask;	/* device mask for the volume set */	
	
	uint16_t	bc_channel;
	uint16_t	bc_target;
	uint16_t	bc_lun;
	uint16_t 	bc_stripe;	/* stripe size */
	uint16_t	bc_level;	/* RAID level requested */

	int 		bc_opcode;
#define BIOC_VCREATE_VOLUME	0x00	/* create new volume */
#define BIOC_VREMOVE_VOLUME	0x01	/* remove volume */
	int 		bc_volid;	/* volume id to be created/removed */
};

struct envsys_data;
void bio_disk_to_envsys(struct envsys_data *, const struct bioc_disk *);
void bio_vol_to_envsys(struct envsys_data *, const struct bioc_vol *) ;

#endif /* ! _DEV_BIOVAR_H_ */