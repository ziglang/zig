/*	$NetBSD: bootinfo.h,v 1.31 2022/08/20 23:12:00 riastradh Exp $	*/

/*
 * Copyright (c) 1997
 *	Matthias Drochner.  All rights reserved.
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
 *
 */

#ifndef	_X86_BOOTINFO_H_
#define	_X86_BOOTINFO_H_

#define BTINFO_BOOTPATH		0
#define BTINFO_ROOTDEVICE	1
#define BTINFO_BOOTDISK		3
#define BTINFO_NETIF		4
#define BTINFO_CONSOLE		6
#define BTINFO_BIOSGEOM		7
#define BTINFO_SYMTAB		8
#define BTINFO_MEMMAP		9
#define	BTINFO_BOOTWEDGE	10
#define BTINFO_MODULELIST	11
#define BTINFO_FRAMEBUFFER	12
#define BTINFO_USERCONFCOMMANDS	13
#define BTINFO_EFI		14
#define BTINFO_EFIMEMMAP	15
#define BTINFO_PREKERN		16

#define BTINFO_STR "bootpath", "rootdevice", "bootdisk", "netif", \
    "console", "biosgeom", "symtab", "memmap", "bootwedge", "modulelist", \
    "framebuffer", "userconfcommands", "efi", "efimemmap", "prekern",

#ifndef _LOCORE

struct btinfo_common {
	int len;
	int type;
};

struct btinfo_bootpath {
	struct btinfo_common common;
	char bootpath[80];
};

struct btinfo_rootdevice {
	struct btinfo_common common;
	char devname[16];
};

struct btinfo_bootdisk {
	struct btinfo_common common;
	int labelsector; /* label valid if != -1 */
	struct {
		uint16_t type, checksum;
		char packname[16];
	} label;
	int biosdev;
	int partition;
};

struct btinfo_bootwedge {
	struct btinfo_common common;
	int biosdev;
	daddr_t startblk;
	uint64_t nblks;
	daddr_t matchblk;
	uint64_t matchnblks;
	uint8_t matchhash[16];	/* MD5 hash */
} __packed;

struct btinfo_netif {
	struct btinfo_common common;
	char ifname[16];
	int bus;
#define BI_BUS_ISA 0
#define BI_BUS_PCI 1
	union {
		unsigned int iobase; /* ISA */
		unsigned int tag; /* PCI, BIOS format */
	} addr;
};

struct btinfo_console {
	struct btinfo_common common;
	char devname[16];
	int addr;
	int speed;
};

struct btinfo_symtab {
	struct btinfo_common common;
	int nsym;
	int ssym;
	int esym;
};

struct bi_memmap_entry {
	uint64_t addr;		/* beginning of block */	/* 8 */
	uint64_t size;		/* size of block */		/* 8 */
	uint32_t type;		/* type of block */		/* 4 */
} __packed;				/*	== 20 */

#define	BIM_Memory	1	/* available RAM usable by OS */
#define	BIM_Reserved	2	/* in use or reserved by the system */
#define	BIM_ACPI	3	/* ACPI Reclaim memory */
#define	BIM_NVS		4	/* ACPI NVS memory */
#define	BIM_Unusable	5	/* errors have been detected */
#define	BIM_Disabled	6	/* not enabled */
#define	BIM_PMEM	7	/* Persistent memory */
#define	BIM_PRAM	12	/* legacy NVDIMM (OEM defined) */

struct btinfo_memmap {
	struct btinfo_common common;
	int num;
	struct bi_memmap_entry entry[1]; /* var len */
};

#if HAVE_NBTOOL_CONFIG_H
#include <nbinclude/sys/bootblock.h>
#else
#include <sys/bootblock.h>
#endif /* HAVE_NBTOOL_CONFIG_H */

/*
 * Structure describing disk info as seen by the BIOS.
 */
struct bi_biosgeom_entry {
	int		sec, head, cyl;		/* geometry */
	uint64_t	totsec;			/* LBA sectors from ext int13 */
	int		flags, dev;		/* flags, BIOS device # */
#define BI_GEOM_INVALID		0x000001
#define BI_GEOM_EXTINT13	0x000002
#ifdef BIOSDISK_EXTINFO_V3
#define BI_GEOM_BADCKSUM	0x000004	/* v3.x checksum invalid */
#define BI_GEOM_BUS_MASK	0x00ff00	/* connecting bus type */
#define BI_GEOM_BUS_ISA		0x000100
#define BI_GEOM_BUS_PCI		0x000200
#define BI_GEOM_BUS_OTHER	0x00ff00
#define BI_GEOM_IFACE_MASK	0xff0000	/* interface type */
#define BI_GEOM_IFACE_ATA	0x010000
#define BI_GEOM_IFACE_ATAPI	0x020000
#define BI_GEOM_IFACE_SCSI	0x030000
#define BI_GEOM_IFACE_USB	0x040000
#define BI_GEOM_IFACE_1394	0x050000	/* Firewire */
#define BI_GEOM_IFACE_FIBRE	0x060000	/* Fibre channel */
#define BI_GEOM_IFACE_OTHER	0xff0000
	unsigned int	cksum;			/* MBR checksum */
	unsigned int	interface_path;		/* ISA iobase PCI bus/dev/fun */
	uint64_t	device_path;
	int		res0;			/* future expansion; 0 now */
#else
	unsigned int	cksum;			/* MBR checksum */
	int		res0, res1, res2, res3;	/* future expansion; 0 now */
#endif
	struct mbr_partition mbrparts[MBR_PART_COUNT]; /* MBR itself */
} __packed;

struct btinfo_biosgeom {
	struct btinfo_common common;
	int num;
	struct bi_biosgeom_entry disk[1]; /* var len */
};

struct bi_modulelist_entry {
	char path[80];
	int type;
	int len;
	uint32_t base;
};
#define	BI_MODULE_NONE		0x00
#define	BI_MODULE_ELF		0x01
#define	BI_MODULE_IMAGE		0x02
#define BI_MODULE_RND		0x03
#define BI_MODULE_FS		0x04

struct btinfo_modulelist {
	struct btinfo_common common;
	int num;
	uint32_t endpa;
	/* bi_modulelist_entry list follows */
};

struct btinfo_framebuffer {
	struct btinfo_common common;
	uint64_t physaddr;
	uint32_t flags;
	uint32_t width;
	uint32_t height;
	uint16_t stride;
	uint8_t depth;
	uint8_t rnum;
	uint8_t gnum;
	uint8_t bnum;
	uint8_t rpos;
	uint8_t gpos;
	uint8_t bpos;
	uint16_t vbemode;
	uint8_t reserved[14];
};

struct bi_userconfcommand {
	char text[80];
};

struct btinfo_userconfcommands {
	struct btinfo_common common;
	int num;
	/* bi_userconfcommand list follows */
};

/* EFI Information */
struct btinfo_efi {
	struct btinfo_common common;
	uint64_t systblpa;	/* Physical address of the EFI System Table */
	uint32_t flags;
#define BI_EFI_32BIT	__BIT(0)	/* 32bit UEFI */
	uint8_t reserved[12];
};

struct btinfo_prekern {
	struct btinfo_common common;
	uint32_t kernpa_start;
	uint32_t kernpa_end;
};

struct btinfo_efimemmap {
	struct btinfo_common common;
	uint32_t num;		/* number of memory descriptor */
	uint32_t version;	/* version of memory descriptor */
	uint32_t size;		/* size of memory descriptor */
	uint8_t memmap[1];	/* whole memory descriptors */
};

#endif /* _LOCORE */

#ifdef _KERNEL

#define BOOTINFO_MAXSIZE 16384

#ifndef _LOCORE
/*
 * Structure that holds the information passed by the boot loader.
 */
struct bootinfo {
	/* Number of bootinfo_* entries in bi_data. */
	uint32_t	bi_nentries;

	/* Raw data of bootinfo entries.  The first one (if any) is
	 * found at bi_data[0] and can be casted to (bootinfo_common *).
	 * Once this is done, the following entry is found at 'len'
	 * offset as specified by the previous entry. */
	uint8_t		bi_data[BOOTINFO_MAXSIZE - sizeof(uint32_t)];
};

extern struct bootinfo bootinfo;

void *lookup_bootinfo(int);
void  aprint_bootinfo(void);
#endif /* _LOCORE */

#endif /* _KERNEL */

#endif	/* _X86_BOOTINFO_H_ */