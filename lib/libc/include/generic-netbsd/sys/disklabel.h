/*	$NetBSD: disklabel.h,v 1.127 2022/11/01 06:47:41 simonb Exp $	*/

/*
 * Copyright (c) 1987, 1988, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)disklabel.h	8.2 (Berkeley) 7/10/94
 */

#ifndef _SYS_DISKLABEL_H_
#define	_SYS_DISKLABEL_H_

/*
 * We need <machine/types.h> for __HAVE_OLD_DISKLABEL
 */
#ifndef _LOCORE
#include <sys/types.h>
#endif

/*
 * Each disk has a label which includes information about the hardware
 * disk geometry, filesystem partitions, and drive specific information.
 * The location of the label, as well as the number of partitions the
 * label can describe and the number of the "whole disk" (raw)
 * partition are machine dependent.
 */
#if HAVE_NBTOOL_CONFIG_H
#undef MAXPARTITIONS
#define MAXPARTITIONS		MAXMAXPARTITIONS
#else
#include <machine/disklabel.h>
#endif /* HAVE_NBTOOL_CONFIG_H */

/*
 * The absolute maximum number of disk partitions allowed.
 * This is the maximum value of MAXPARTITIONS for which 'struct disklabel'
 * is <= DEV_BSIZE bytes long.  If MAXPARTITIONS is greater than this, beware.
 */
#define	MAXMAXPARTITIONS	22
#if MAXPARTITIONS > MAXMAXPARTITIONS
#warning beware: MAXPARTITIONS bigger than MAXMAXPARTITIONS
#endif

/*
 * Ports can switch their MAXPARTITIONS once, as follows:
 *
 * - define OLDMAXPARTITIONS in <machine/disklabel.h> as the old number
 * - define MAXPARTITIONS as the new number
 * - define DISKUNIT, DISKPART and DISKMINOR macros in <machine/disklabel.h>
 *   as appropriate for the port (see the i386 one for an example).
 * - define __HAVE_OLD_DISKLABEL in <machine/types.h>
 */

#if defined(_KERNEL) && defined(__HAVE_OLD_DISKLABEL) && \
	   (MAXPARTITIONS < OLDMAXPARTITIONS)
#error "can only grow disklabel size"
#endif


/*
 * Translate between device numbers and major/disk unit/disk partition.
 */
#ifndef __HAVE_OLD_DISKLABEL
#if !HAVE_NBTOOL_CONFIG_H
#define	DISKUNIT(dev)	(minor(dev) / MAXPARTITIONS)
#define	DISKPART(dev)	(minor(dev) % MAXPARTITIONS)
#define	DISKMINOR(unit, part) \
    (((unit) * MAXPARTITIONS) + (part))
#endif /* !HAVE_NBTOOL_CONFIG_H */
#endif
#define	MAKEDISKDEV(maj, unit, part) \
    (makedev((maj), DISKMINOR((unit), (part))))

#define	DISKMAGIC	((uint32_t)0x82564557)	/* The disk magic number */

#ifndef _LOCORE
struct	partition {		/* the partition table */
	uint32_t p_size;	/* number of sectors in partition */
	uint32_t p_offset;	/* starting sector */
	union {
		uint32_t fsize; /* FFS, ADOS: filesystem basic fragment size */
		uint32_t cdsession; /* ISO9660: session offset */
	} __partition_u2;
#define	p_fsize		__partition_u2.fsize
#define	p_cdsession	__partition_u2.cdsession
	uint8_t p_fstype;	/* filesystem type, see below */
	uint8_t p_frag;	/* filesystem fragments per block */
	union {
		uint16_t cpg;	/* UFS: FS cylinders per group */
		uint16_t sgs;	/* LFS: FS segment shift */
	} __partition_u1;
#define	p_cpg	__partition_u1.cpg
#define	p_sgs	__partition_u1.sgs
};

/*
 * We'd rather have disklabel be the same size on 32 and 64 bit systems
 * but it really isn't. In revision 108 matt@ tried to do that by adding
 * un_d_pad as a uint64_t. This was really smart because the net effect
 * was to grow the struct by 4 bytes on most LP32 machines and make it
 * the same as LP64 without changing the layout (which is a nono because
 * it is stored on existing disks). The easy way would have been to add
 * padding at the end, but that would have been confusing (although that
 * is what actually happens), because the partitions structure is supposed
 * to be variable size and putting a padding uint32_t would be weird.
 * Unfornately mips32 and i386 align uint64_t standalone at an 8 byte
 * boundary, but in structures at a 4 byte boundary so matt's
 * change did not affect them.
 *
 * We also prefer to have the structure 4 byte aligned so that the
 * subr_disk_mbr.c code that scans for label does not trigger ubsan
 * when comparing magic (without making the code ugly). To do this
 * we can unexpose the d_boot{0,1} pointers in the kernel (so that
 * LP64 systems can become 4 byte aligned) and at the same time
 * remove the un_d_pad member and add padding at the end. The d_boot{0,1}
 * fields are only used in userland in getdiskbyname(3), filled with
 * the names of the primary and secondary bootstrap from /etc/disktab.
 *
 * While this is a way forward, it is not clear that it is the best
 * way forward. The ubsan warning is incorrect and the code
 * will always work since d_magic is always 4 byte aligned even
 * when structure disklabel is not 8 byte aligned, so what we do
 * now is ignore it. Another way would be to do offset arithmetic
 * on the pointer and use it as a char *. That would not prevent
 * other misaligned accesses in the future. Finally one could
 * copy the unaligned structure to an aligned one, but that eats
 * up space on the stack.
 */
struct disklabel {
	uint32_t d_magic;		/* the magic number */
	uint16_t d_type;		/* drive type */
	uint16_t d_subtype;		/* controller/d_type specific */
	char	  d_typename[16];	/* type name, e.g. "eagle" */

	/*
	 * d_packname contains the pack identifier and is returned when
	 * the disklabel is read off the disk or in-core copy.
	 * d_boot0 and d_boot1 are the (optional) names of the
	 * primary (block 0) and secondary (block 1-15) bootstraps
	 * as found in /usr/mdec.  These are returned when using
	 * getdiskbyname(3) to retrieve the values from /etc/disktab.
	 */
	union {
		char	un_d_packname[16];	/* pack identifier */
		struct {
			char *un_d_boot0;	/* primary bootstrap name */
			char *un_d_boot1;	/* secondary bootstrap name */
		} un_b;
		uint64_t un_d_pad;		/* force 8 byte alignment */
	} d_un;
#define	d_packname	d_un.un_d_packname
#define	d_boot0		d_un.un_b.un_d_boot0
#define	d_boot1		d_un.un_b.un_d_boot1

			/* disk geometry: */
	uint32_t d_secsize;		/* # of bytes per sector */
	uint32_t d_nsectors;		/* # of data sectors per track */
	uint32_t d_ntracks;		/* # of tracks per cylinder */
	uint32_t d_ncylinders;		/* # of data cylinders per unit */
	uint32_t d_secpercyl;		/* # of data sectors per cylinder */
	uint32_t d_secperunit;		/* # of data sectors per unit */

	/*
	 * Spares (bad sector replacements) below are not counted in
	 * d_nsectors or d_secpercyl.  Spare sectors are assumed to
	 * be physical sectors which occupy space at the end of each
	 * track and/or cylinder.
	 */
	uint16_t d_sparespertrack;	/* # of spare sectors per track */
	uint16_t d_sparespercyl;	/* # of spare sectors per cylinder */
	/*
	 * Alternative cylinders include maintenance, replacement,
	 * configuration description areas, etc.
	 */
	uint32_t d_acylinders;		/* # of alt. cylinders per unit */

			/* hardware characteristics: */
	/*
	 * d_interleave, d_trackskew and d_cylskew describe perturbations
	 * in the media format used to compensate for a slow controller.
	 * Interleave is physical sector interleave, set up by the
	 * formatter or controller when formatting.  When interleaving is
	 * in use, logically adjacent sectors are not physically
	 * contiguous, but instead are separated by some number of
	 * sectors.  It is specified as the ratio of physical sectors
	 * traversed per logical sector.  Thus an interleave of 1:1
	 * implies contiguous layout, while 2:1 implies that logical
	 * sector 0 is separated by one sector from logical sector 1.
	 * d_trackskew is the offset of sector 0 on track N relative to
	 * sector 0 on track N-1 on the same cylinder.  Finally, d_cylskew
	 * is the offset of sector 0 on cylinder N relative to sector 0
	 * on cylinder N-1.
	 */
	uint16_t d_rpm;		/* rotational speed */
	uint16_t d_interleave;		/* hardware sector interleave */
	uint16_t d_trackskew;		/* sector 0 skew, per track */
	uint16_t d_cylskew;		/* sector 0 skew, per cylinder */
	uint32_t d_headswitch;		/* head switch time, usec */
	uint32_t d_trkseek;		/* track-to-track seek, usec */
	uint32_t d_flags;		/* generic flags */
#define	NDDATA 5
	uint32_t d_drivedata[NDDATA];	/* drive-type specific information */
#define	NSPARE 5
	uint32_t d_spare[NSPARE];	/* reserved for future use */
	uint32_t d_magic2;		/* the magic number (again) */
	uint16_t d_checksum;		/* xor of data incl. partitions */

			/* filesystem and partition information: */
	uint16_t d_npartitions;	/* number of partitions in following */
	uint32_t d_bbsize;		/* size of boot area at sn0, bytes */
	uint32_t d_sbsize;		/* max size of fs superblock, bytes */
	struct	partition  d_partitions[MAXPARTITIONS];
			/* the partition table, actually may be more */
};

#if defined(__HAVE_OLD_DISKLABEL) && !HAVE_NBTOOL_CONFIG_H
/*
 * Same as above, but with OLDMAXPARTITIONS partitions. For use in
 * the old DIOC* ioctl calls.
 */
struct olddisklabel {
	uint32_t d_magic;
	uint16_t d_type;
	uint16_t d_subtype;
	char	  d_typename[16];
	union {
		char	un_d_packname[16];
		struct {
			char *un_d_boot0;
			char *un_d_boot1;
		} un_b;
	} d_un;
	uint32_t d_secsize;
	uint32_t d_nsectors;
	uint32_t d_ntracks;
	uint32_t d_ncylinders;
	uint32_t d_secpercyl;
	uint32_t d_secperunit;
	uint16_t d_sparespertrack;
	uint16_t d_sparespercyl;
	uint32_t d_acylinders;
	uint16_t d_rpm;
	uint16_t d_interleave;
	uint16_t d_trackskew;
	uint16_t d_cylskew;
	uint32_t d_headswitch;
	uint32_t d_trkseek;
	uint32_t d_flags;
	uint32_t d_drivedata[NDDATA];
	uint32_t d_spare[NSPARE];
	uint32_t d_magic2;
	uint16_t d_checksum;
	uint16_t d_npartitions;
	uint32_t d_bbsize;
	uint32_t d_sbsize;
	struct	opartition {
		uint32_t p_size;
		uint32_t p_offset;
		union {
			uint32_t fsize;
			uint32_t cdsession;
		} __partition_u2;
		uint8_t p_fstype;
		uint8_t p_frag;
		union {
			uint16_t cpg;
			uint16_t sgs;
		} __partition_u1;
	} d_partitions[OLDMAXPARTITIONS];
};
#endif /* __HAVE_OLD_DISKLABEL */
#else /* _LOCORE */
	/*
	 * offsets for asm boot files.
	 */
	.set	d_secsize,40
	.set	d_nsectors,44
	.set	d_ntracks,48
	.set	d_ncylinders,52
	.set	d_secpercyl,56
	.set	d_secperunit,60
	.set	d_end_,148+(MAXPARTITIONS*16)
#endif /* _LOCORE */

/*
 * We normally use C99 initialisers (just in case the lists below are out
 * of sequence, or have gaps), but lint doesn't grok them.
 * Maybe some host compilers don't either, but many have for quite some time.
 */

#ifndef lint
#define ARRAY_INIT(element,value) [element]=value
#else
#define ARRAY_INIT(element,value) value
#endif

/* Use pre-processor magic to get all the parameters one one line... */

/* d_type values: */
#define DKTYPE_DEFN(x) \
x(UNKNOWN,	0,	"unknown") \
x(SMD,		1,	"SMD")		/* SMD, XSMD; VAX hp/up */ \
x(MSCP,		2,	"MSCP")		/* MSCP */ \
x(DEC,		3,	"old DEC")	/* other DEC (rk, rl) */ \
x(SCSI,		4,	"SCSI")		/* SCSI */ \
x(ESDI,		5,	"ESDI")		/* ESDI interface */ \
x(ST506,	6,	"ST506")	/* ST506 etc. */ \
x(HPIB,		7,	"HP-IB")	/* CS/80 on HP-IB */ \
x(HPFL,		8,	"HP-FL")	/* HP Fiber-link */ \
x(TYPE_9,	9,	"type 9") \
x(FLOPPY,	10,	"floppy")	/* floppy */ \
x(CCD,		11,	"ccd")		/* concatenated disk device */ \
x(VND,		12,	"vnd")		/* uvnode pseudo-disk */ \
x(ATAPI,	13,	"ATAPI")	/* ATAPI */ \
x(RAID,		14,	"RAID")		/* RAIDframe */ \
x(LD,		15,	"ld")		/* logical disk */ \
x(JFS2,		16,	"jfs")		/* IBM JFS2 */ \
x(CGD,		17,	"cgd")		/* cryptographic pseudo-disk */ \
x(VINUM,	18,	"vinum")	/* vinum volume */ \
x(FLASH,	19,	"flash")	/* flash memory devices */ \
x(DM,		20,	"dm")		/* device-mapper pseudo-disk devices */\
x(RUMPD,	21,	"rumpd")	/* rump virtual disk */ \
x(MD,		22,	"md")		/* memory disk */ \
    
#ifndef _LOCORE
#define DKTYPE_NUMS(tag, number, name) __CONCAT(DKTYPE_,tag=number),
#ifndef DKTYPE_ENUMNAME
#define DKTYPE_ENUMNAME
#endif
enum DKTYPE_ENUMNAME { DKTYPE_DEFN(DKTYPE_NUMS) DKMAXTYPES };
#undef	DKTYPE_NUMS
#endif

#ifdef DKTYPENAMES
#define	DKTYPE_NAMES(tag, number, name) ARRAY_INIT(number,name),
static const char *const dktypenames[] = { DKTYPE_DEFN(DKTYPE_NAMES) NULL };
#undef	DKTYPE_NAMES
#endif

/*
 * Partition type names, numbers, label-names, fsck prog, and mount prog
 */
#define	FSTYPE_DEFN(x) \
x(UNUSED,   0, "unused",     NULL,    NULL)   /* unused */ \
x(SWAP,     1, "swap",       NULL,    NULL)   /* swap */ \
x(V6,       2, "Version 6",  NULL,    NULL)   /* Sixth Edition */ \
x(V7,       3, "Version 7", "v7fs",  "v7fs")  /* Seventh Edition */ \
x(SYSV,     4, "System V",   NULL,    NULL)   /* System V */ \
x(V71K,     5, "4.1BSD",     NULL,    NULL)   /* V7, 1K blocks (4.1, 2.9) */ \
x(V8,    6, "Eighth Edition",NULL,    NULL)   /* Eighth Edition, 4K blocks */ \
x(BSDFFS,   7, "4.2BSD",    "ffs",   "ffs")   /* 4.2BSD fast file system */ \
x(MSDOS,    8, "MSDOS",     "msdos", "msdos") /* MSDOS file system */ \
x(BSDLFS,   9, "4.4LFS",    "lfs",   "lfs")   /* 4.4BSD log-structured FS */ \
x(OTHER,   10, "unknown",    NULL,    NULL)   /* in use, unknown/unsupported */\
x(HPFS,    11, "HPFS",       NULL,    NULL)   /* OS/2 high-performance FS */ \
x(ISO9660, 12, "ISO9660",    NULL,   "cd9660")/* ISO 9660, normally CD-ROM */ \
x(BOOT,    13, "boot",       NULL,    NULL)   /* bootstrap code in partition */\
x(ADOS,    14, "ADOS",       NULL,   "ados")  /* AmigaDOS fast file system */ \
x(HFS,     15, "HFS",        NULL,    NULL)   /* Macintosh HFS */ \
x(FILECORE,16, "FILECORE",   NULL, "filecore")/* Acorn Filecore FS */ \
x(EX2FS,   17, "Linux Ext2","ext2fs","ext2fs")/* Linux Extended 2 FS */ \
x(NTFS,    18, "NTFS",       NULL,   "ntfs")  /* Windows/NT file system */ \
x(RAID,    19, "RAID",       NULL,    NULL)   /* RAIDframe component */ \
x(CCD,     20, "ccd",        NULL,    NULL)   /* concatenated disk component */\
x(JFS2,    21, "jfs",        NULL,    NULL)   /* IBM JFS2 */ \
x(APPLEUFS,22, "Apple UFS", "ffs",   "ffs")   /* Apple UFS */ \
/* XXX this is not the same as FreeBSD.  How to solve? */ \
x(VINUM,   23, "vinum",      NULL,    NULL)   /* Vinum */ \
x(UDF,     24, "UDF",        NULL,   "udf")   /* UDF */ \
x(SYSVBFS, 25, "SysVBFS",    NULL,  "sysvbfs")/* System V boot file system */ \
x(EFS,     26, "EFS",        NULL,   "efs")   /* SGI's Extent Filesystem */ \
x(NILFS,   27, "NiLFS",      NULL,   "nilfs") /* NTT's NiLFS(2) */ \
x(CGD,     28, "cgd",	     NULL,   NULL)    /* Cryptographic disk */ \
x(MINIXFS3,29, "MINIX FSv3", NULL,   NULL)    /* MINIX file system v3 */ \
x(VMKCORE, 30, "VMware vmkcore", NULL, NULL)  /* VMware vmkcore */ \
x(VMFS,    31, "VMware VMFS", NULL,  NULL)    /* VMware VMFS */ \
x(VMWRESV, 32, "VMware Reserved", NULL, NULL) /* VMware reserved */ \
x(ZFS,     33, "ZFS",        NULL,   "zfs")   /* ZFS */


#ifndef _LOCORE
#define	FS_TYPENUMS(tag, number, name, fsck, mount) __CONCAT(FS_,tag=number),
#ifndef FSTYPE_ENUMNAME
#define FSTYPE_ENUMNAME
#endif
enum FSTYPE_ENUMNAME { FSTYPE_DEFN(FS_TYPENUMS) FSMAXTYPES };
#undef	FS_TYPENUMS
#endif

#ifdef	FSTYPENAMES
#define	FS_TYPENAMES(tag, number, name, fsck, mount) ARRAY_INIT(number,name),
static const char *const fstypenames[] = { FSTYPE_DEFN(FS_TYPENAMES) NULL };
#undef	FS_TYPENAMES
#endif

#ifdef FSCKNAMES
/* These are the names MOUNT_XXX from <sys/mount.h> */
#define	FS_FSCKNAMES(tag, number, name, fsck, mount) ARRAY_INIT(number,fsck),
static const char *const fscknames[] = { FSTYPE_DEFN(FS_FSCKNAMES) NULL };
#undef	FS_FSCKNAMES
#define	FSMAXNAMES	FSMAXTYPES
#endif

#ifdef MOUNTNAMES
/* These are the names MOUNT_XXX from <sys/mount.h> */
#define	FS_MOUNTNAMES(tag, number, name, fsck, mount) ARRAY_INIT(number,mount),
static const char *const mountnames[] = { FSTYPE_DEFN(FS_MOUNTNAMES) NULL };
#undef	FS_MOUNTNAMES
#define	FSMAXMOUNTNAMES	FSMAXTYPES
#endif

/*
 * flags shared by various drives:
 */
#define		D_REMOVABLE	0x01		/* removable media */
#define		D_ECC		0x02		/* supports ECC */
#define		D_BADSECT	0x04		/* supports bad sector forw. */
#define		D_RAMDISK	0x08		/* disk emulator */
#define		D_CHAIN		0x10		/* can do back-back transfers */
#define		D_SCSI_MMC	0x20		/* SCSI MMC sessioned media */

/*
 * Drive data for SMD.
 */
#define	d_smdflags	d_drivedata[0]
#define		D_SSE		0x1		/* supports skip sectoring */
#define	d_mindist	d_drivedata[1]
#define	d_maxdist	d_drivedata[2]
#define	d_sdist		d_drivedata[3]

/*
 * Drive data for ST506.
 */
#define	d_precompcyl	d_drivedata[0]
#define	d_gap3		d_drivedata[1]		/* used only when formatting */

/*
 * Drive data for SCSI.
 */
#define	d_blind		d_drivedata[0]

#ifndef _LOCORE
/*
 * Structure used to perform a format or other raw operation,
 * returning data and/or register values.  Register identification
 * and format are device- and driver-dependent. Currently unused.
 */
struct format_op {
	char	*df_buf;
	int	 df_count;		/* value-result */
	daddr_t	 df_startblk;
	int	 df_reg[8];		/* result */
};

#ifdef _KERNEL
/*
 * Structure used internally to retrieve information about a partition
 * on a disk.
 */
struct partinfo {
	uint64_t pi_offset;
	uint64_t pi_size;
	uint32_t pi_secsize;
	uint32_t pi_bsize;
	uint8_t	 pi_fstype;
	uint8_t  pi_frag;
	uint16_t pi_cpg;
	uint32_t pi_fsize;
};

struct disk;

int disk_read_sectors(void (*)(struct buf *), const struct disklabel *,
    struct buf *, unsigned int, int);
void	 diskerr(const struct buf *, const char *, const char *, int,
	    int, const struct disklabel *);
int	 setdisklabel(struct disklabel *, struct disklabel *, u_long,
	    struct cpu_disklabel *);
const char *readdisklabel(dev_t, void (*)(struct buf *),
	    struct disklabel *, struct cpu_disklabel *);
int	 writedisklabel(dev_t, void (*)(struct buf *), struct disklabel *,
	    struct cpu_disklabel *);
const char *convertdisklabel(struct disklabel *, void (*)(struct buf *),
    struct buf *, uint32_t);
int	 bounds_check_with_label(struct disk *, struct buf *, int);
int	 bounds_check_with_mediasize(struct buf *, int, uint64_t);
const char *getfstypename(int);
int	disklabel_dev_unit(dev_t);
#endif
#endif /* _LOCORE */

#if !defined(_KERNEL) && !defined(_LOCORE)

#include <sys/cdefs.h>

#endif

#endif /* !_SYS_DISKLABEL_H_ */