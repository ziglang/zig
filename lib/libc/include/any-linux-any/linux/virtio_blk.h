#ifndef _LINUX_VIRTIO_BLK_H
#define _LINUX_VIRTIO_BLK_H
/* This header is BSD licensed so anyone can use the definitions to implement
 * compatible drivers/servers.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of IBM nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL IBM OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE. */
#include <linux/types.h>
#include <linux/virtio_ids.h>
#include <linux/virtio_config.h>
#include <linux/virtio_types.h>

/* Feature bits */
#define VIRTIO_BLK_F_SIZE_MAX	1	/* Indicates maximum segment size */
#define VIRTIO_BLK_F_SEG_MAX	2	/* Indicates maximum # of segments */
#define VIRTIO_BLK_F_GEOMETRY	4	/* Legacy geometry available  */
#define VIRTIO_BLK_F_RO		5	/* Disk is read-only */
#define VIRTIO_BLK_F_BLK_SIZE	6	/* Block size of disk is available*/
#define VIRTIO_BLK_F_TOPOLOGY	10	/* Topology information is available */
#define VIRTIO_BLK_F_MQ		12	/* support more than one vq */
#define VIRTIO_BLK_F_DISCARD	13	/* DISCARD is supported */
#define VIRTIO_BLK_F_WRITE_ZEROES	14	/* WRITE ZEROES is supported */
#define VIRTIO_BLK_F_SECURE_ERASE	16 /* Secure Erase is supported */
#define VIRTIO_BLK_F_ZONED		17	/* Zoned block device */

/* Legacy feature bits */
#ifndef VIRTIO_BLK_NO_LEGACY
#define VIRTIO_BLK_F_BARRIER	0	/* Does host support barriers? */
#define VIRTIO_BLK_F_SCSI	7	/* Supports scsi command passthru */
#define VIRTIO_BLK_F_FLUSH	9	/* Flush command supported */
#define VIRTIO_BLK_F_CONFIG_WCE	11	/* Writeback mode available in config */
/* Old (deprecated) name for VIRTIO_BLK_F_FLUSH. */
#define VIRTIO_BLK_F_WCE VIRTIO_BLK_F_FLUSH
#endif /* !VIRTIO_BLK_NO_LEGACY */

#define VIRTIO_BLK_ID_BYTES	20	/* ID string length */

struct virtio_blk_config {
	/* The capacity (in 512-byte sectors). */
	__virtio64 capacity;
	/* The maximum segment size (if VIRTIO_BLK_F_SIZE_MAX) */
	__virtio32 size_max;
	/* The maximum number of segments (if VIRTIO_BLK_F_SEG_MAX) */
	__virtio32 seg_max;
	/* geometry of the device (if VIRTIO_BLK_F_GEOMETRY) */
	struct virtio_blk_geometry {
		__virtio16 cylinders;
		__u8 heads;
		__u8 sectors;
	} geometry;

	/* block size of device (if VIRTIO_BLK_F_BLK_SIZE) */
	__virtio32 blk_size;

	/* the next 4 entries are guarded by VIRTIO_BLK_F_TOPOLOGY  */
	/* exponent for physical block per logical block. */
	__u8 physical_block_exp;
	/* alignment offset in logical blocks. */
	__u8 alignment_offset;
	/* minimum I/O size without performance penalty in logical blocks. */
	__virtio16 min_io_size;
	/* optimal sustained I/O size in logical blocks. */
	__virtio32 opt_io_size;

	/* writeback mode (if VIRTIO_BLK_F_CONFIG_WCE) */
	__u8 wce;
	__u8 unused;

	/* number of vqs, only available when VIRTIO_BLK_F_MQ is set */
	__virtio16 num_queues;

	/* the next 3 entries are guarded by VIRTIO_BLK_F_DISCARD */
	/*
	 * The maximum discard sectors (in 512-byte sectors) for
	 * one segment.
	 */
	__virtio32 max_discard_sectors;
	/*
	 * The maximum number of discard segments in a
	 * discard command.
	 */
	__virtio32 max_discard_seg;
	/* Discard commands must be aligned to this number of sectors. */
	__virtio32 discard_sector_alignment;

	/* the next 3 entries are guarded by VIRTIO_BLK_F_WRITE_ZEROES */
	/*
	 * The maximum number of write zeroes sectors (in 512-byte sectors) in
	 * one segment.
	 */
	__virtio32 max_write_zeroes_sectors;
	/*
	 * The maximum number of segments in a write zeroes
	 * command.
	 */
	__virtio32 max_write_zeroes_seg;
	/*
	 * Set if a VIRTIO_BLK_T_WRITE_ZEROES request may result in the
	 * deallocation of one or more of the sectors.
	 */
	__u8 write_zeroes_may_unmap;

	__u8 unused1[3];

	/* the next 3 entries are guarded by VIRTIO_BLK_F_SECURE_ERASE */
	/*
	 * The maximum secure erase sectors (in 512-byte sectors) for
	 * one segment.
	 */
	__virtio32 max_secure_erase_sectors;
	/*
	 * The maximum number of secure erase segments in a
	 * secure erase command.
	 */
	__virtio32 max_secure_erase_seg;
	/* Secure erase commands must be aligned to this number of sectors. */
	__virtio32 secure_erase_sector_alignment;

	/* Zoned block device characteristics (if VIRTIO_BLK_F_ZONED) */
	struct virtio_blk_zoned_characteristics {
		__virtio32 zone_sectors;
		__virtio32 max_open_zones;
		__virtio32 max_active_zones;
		__virtio32 max_append_sectors;
		__virtio32 write_granularity;
		__u8 model;
		__u8 unused2[3];
	} zoned;
} __attribute__((packed));

/*
 * Command types
 *
 * Usage is a bit tricky as some bits are used as flags and some are not.
 *
 * Rules:
 *   VIRTIO_BLK_T_OUT may be combined with VIRTIO_BLK_T_SCSI_CMD or
 *   VIRTIO_BLK_T_BARRIER.  VIRTIO_BLK_T_FLUSH is a command of its own
 *   and may not be combined with any of the other flags.
 */

/* These two define direction. */
#define VIRTIO_BLK_T_IN		0
#define VIRTIO_BLK_T_OUT	1

#ifndef VIRTIO_BLK_NO_LEGACY
/* This bit says it's a scsi command, not an actual read or write. */
#define VIRTIO_BLK_T_SCSI_CMD	2
#endif /* VIRTIO_BLK_NO_LEGACY */

/* Cache flush command */
#define VIRTIO_BLK_T_FLUSH	4

/* Get device ID command */
#define VIRTIO_BLK_T_GET_ID    8

/* Discard command */
#define VIRTIO_BLK_T_DISCARD	11

/* Write zeroes command */
#define VIRTIO_BLK_T_WRITE_ZEROES	13

/* Secure erase command */
#define VIRTIO_BLK_T_SECURE_ERASE	14

/* Zone append command */
#define VIRTIO_BLK_T_ZONE_APPEND    15

/* Report zones command */
#define VIRTIO_BLK_T_ZONE_REPORT    16

/* Open zone command */
#define VIRTIO_BLK_T_ZONE_OPEN      18

/* Close zone command */
#define VIRTIO_BLK_T_ZONE_CLOSE     20

/* Finish zone command */
#define VIRTIO_BLK_T_ZONE_FINISH    22

/* Reset zone command */
#define VIRTIO_BLK_T_ZONE_RESET     24

/* Reset All zones command */
#define VIRTIO_BLK_T_ZONE_RESET_ALL 26

#ifndef VIRTIO_BLK_NO_LEGACY
/* Barrier before this op. */
#define VIRTIO_BLK_T_BARRIER	0x80000000
#endif /* !VIRTIO_BLK_NO_LEGACY */

/*
 * This comes first in the read scatter-gather list.
 * For legacy virtio, if VIRTIO_F_ANY_LAYOUT is not negotiated,
 * this is the first element of the read scatter-gather list.
 */
struct virtio_blk_outhdr {
	/* VIRTIO_BLK_T* */
	__virtio32 type;
	/* io priority. */
	__virtio32 ioprio;
	/* Sector (ie. 512 byte offset) */
	__virtio64 sector;
};

/*
 * Supported zoned device models.
 */

/* Regular block device */
#define VIRTIO_BLK_Z_NONE      0
/* Host-managed zoned device */
#define VIRTIO_BLK_Z_HM        1
/* Host-aware zoned device */
#define VIRTIO_BLK_Z_HA        2

/*
 * Zone descriptor. A part of VIRTIO_BLK_T_ZONE_REPORT command reply.
 */
struct virtio_blk_zone_descriptor {
	/* Zone capacity */
	__virtio64 z_cap;
	/* The starting sector of the zone */
	__virtio64 z_start;
	/* Zone write pointer position in sectors */
	__virtio64 z_wp;
	/* Zone type */
	__u8 z_type;
	/* Zone state */
	__u8 z_state;
	__u8 reserved[38];
};

struct virtio_blk_zone_report {
	__virtio64 nr_zones;
	__u8 reserved[56];
	struct virtio_blk_zone_descriptor zones[];
};

/*
 * Supported zone types.
 */

/* Conventional zone */
#define VIRTIO_BLK_ZT_CONV         1
/* Sequential Write Required zone */
#define VIRTIO_BLK_ZT_SWR          2
/* Sequential Write Preferred zone */
#define VIRTIO_BLK_ZT_SWP          3

/*
 * Zone states that are available for zones of all types.
 */

/* Not a write pointer (conventional zones only) */
#define VIRTIO_BLK_ZS_NOT_WP       0
/* Empty */
#define VIRTIO_BLK_ZS_EMPTY        1
/* Implicitly Open */
#define VIRTIO_BLK_ZS_IOPEN        2
/* Explicitly Open */
#define VIRTIO_BLK_ZS_EOPEN        3
/* Closed */
#define VIRTIO_BLK_ZS_CLOSED       4
/* Read-Only */
#define VIRTIO_BLK_ZS_RDONLY       13
/* Full */
#define VIRTIO_BLK_ZS_FULL         14
/* Offline */
#define VIRTIO_BLK_ZS_OFFLINE      15

/* Unmap this range (only valid for write zeroes command) */
#define VIRTIO_BLK_WRITE_ZEROES_FLAG_UNMAP	0x00000001

/* Discard/write zeroes range for each request. */
struct virtio_blk_discard_write_zeroes {
	/* discard/write zeroes start sector */
	__le64 sector;
	/* number of discard/write zeroes sectors */
	__le32 num_sectors;
	/* flags for this range */
	__le32 flags;
};

#ifndef VIRTIO_BLK_NO_LEGACY
struct virtio_scsi_inhdr {
	__virtio32 errors;
	__virtio32 data_len;
	__virtio32 sense_len;
	__virtio32 residual;
};
#endif /* !VIRTIO_BLK_NO_LEGACY */

/* And this is the final byte of the write scatter-gather list. */
#define VIRTIO_BLK_S_OK		0
#define VIRTIO_BLK_S_IOERR	1
#define VIRTIO_BLK_S_UNSUPP	2

/* Error codes that are specific to zoned block devices */
#define VIRTIO_BLK_S_ZONE_INVALID_CMD     3
#define VIRTIO_BLK_S_ZONE_UNALIGNED_WP    4
#define VIRTIO_BLK_S_ZONE_OPEN_RESOURCE   5
#define VIRTIO_BLK_S_ZONE_ACTIVE_RESOURCE 6

#endif /* _LINUX_VIRTIO_BLK_H */