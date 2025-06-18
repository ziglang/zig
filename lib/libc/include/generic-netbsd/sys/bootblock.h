/*	$NetBSD: bootblock.h,v 1.58.40.1 2024/06/22 10:57:11 martin Exp $	*/

/*-
 * Copyright (c) 2002-2004 The NetBSD Foundation, Inc.
 * All rights reserved.
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
/*-
 * Copyright (C) 1993	Allen K. Briggs, Chris P. Caputo,
 *			Michael L. Finch, Bradley A. Grantham, and
 *			Lawrence A. Kesteloot
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the Alice Group.
 * 4. The names of the Alice Group or any of its members may not be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE ALICE GROUP ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE ALICE GROUP BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */
/*
 * Copyright (c) 1994, 1999 Christopher G. Demetriou
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by Christopher G. Demetriou
 *      for the NetBSD Project.
 * 4. The name of the author may not be used to endorse or promote products
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
/*
 * Copyright (c) 1994 Rolf Grossmann
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by Rolf Grossmann.
 * 4. The name of the author may not be used to endorse or promote products
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

#ifndef _SYS_BOOTBLOCK_H
#define	_SYS_BOOTBLOCK_H

#if !defined(__ASSEMBLER__)
#include <sys/cdefs.h>
#if defined(_KERNEL) || defined(_STANDALONE)
#include <sys/stdint.h>
#else
#include <stdint.h>
#endif
#endif	/* !defined(__ASSEMBLER__) */

/* ------------------------------------------
 * MBR (Master Boot Record) --
 *	definitions for systems that use MBRs
 */

/*
 * Layout of boot records:
 *
 *	Byte range	Use	Description
 *	----------	---	-----------
 *
 *	0 - 2		FMP	JMP xxx, NOP
 *	3 - 10		FP	OEM Name
 *
 *	11 - 61		FMP	FAT12/16 BPB
 *				Whilst not strictly necessary for MBR,
 *				GRUB reserves this area
 *
 *	11 - 89		P	FAT32 BPB
 *				(are we ever going to boot off this?)
 *
 *
 *	62 - 217	FMP	Boot code
 *
 *	90 - 217	P	FAT32 boot code
 *
 *	218 - 223	M	Win95b/98/me "drive time"
 *		http://www.geocities.com/thestarman3/asm/mbr/95BMEMBR.htm#MYST
 *				only changed if all 6 bytes are 0
 *
 *	224 - 436	FMP	boot code (continued)
 *
 *	437 - 439	M	WinNT/2K/XP MBR "boot language"
 *		http://www.geocities.com/thestarman3/asm/mbr/Win2kmbr.htm
 *				not needed by us
 *
 *	400 - 439	MP	NetBSD: mbr_bootsel
 *
 *	424 - 439	M	NetBSD: bootptn_guid (in GPT PMBR only)
 *
 *	440 - 443	M	WinNT/2K/XP Drive Serial Number (NT DSN)
 *		http://www.geocities.com/thestarman3/asm/mbr/Win2kmbr.htm
 *
 *	444 - 445	FMP	bootcode or unused
 *				NetBSD: mbr_bootsel_magic
 *
 *	446 - 509	M	partition table
 *
 *	510 - 511	FMP	magic number (0xAA55)
 *
 *	Use:
 *	----
 *	F	Floppy boot sector
 *	M	Master Boot Record
 *	P	Partition Boot record
 *
 */

/*
 * MBR (Master Boot Record)
 */
#define	MBR_BBSECTOR		0	/* MBR relative sector # */
#define	MBR_BPB_OFFSET		11	/* offsetof(mbr_sector, mbr_bpb) */
#define	MBR_BOOTCODE_OFFSET	90	/* offsetof(mbr_sector, mbr_bootcode) */
#define	MBR_BS_OFFSET		400	/* offsetof(mbr_sector, mbr_bootsel) */
#define	MBR_BS_OLD_OFFSET	404	/* where mbr_bootsel used to be */
#define	MBR_GPT_GUID_OFFSET	424	/* location of partition GUID to boot */
#define	MBR_GPT_GUID_DEFAULT		/* default uninitialized GUID */ \
	{0xeee69d04,0x02f4,0x11e0,0x8f,0x5d,{0x00,0xe0,0x81,0x52,0x9a,0x6b}}
#define	MBR_DSN_OFFSET		440	/* offsetof(mbr_sector, mbr_dsn) */
#define	MBR_BS_MAGIC_OFFSET	444	/* offsetof(mbr_sector, mbr_bootsel_magic) */
#define	MBR_PART_OFFSET		446	/* offsetof(mbr_sector, mbr_part[0]) */
#define	MBR_MAGIC_OFFSET	510	/* offsetof(mbr_sector, mbr_magic) */
#define	MBR_MAGIC		0xaa55	/* MBR magic number */
#define	MBR_BS_MAGIC		0xb5e1	/* mbr_bootsel magic number */
#define	MBR_PART_COUNT		4	/* Number of partitions in MBR */
#define	MBR_BS_PARTNAMESIZE	8	/* Size of name mbr_bootsel nametab */
					/* (excluding trailing NUL) */

		/* values for mbr_partition.mbrp_flag */
#define	MBR_PFLAG_ACTIVE	0x80	/* The active partition */

		/* values for mbr_partition.mbrp_type */
#define	MBR_PTYPE_UNUSED	0x00	/* Unused */
#define	MBR_PTYPE_FAT12		0x01	/* 12-bit FAT */
#define	MBR_PTYPE_XENIX_ROOT	0x02	/* XENIX / */
#define	MBR_PTYPE_XENIX_USR	0x03	/* XENIX /usr */
#define	MBR_PTYPE_FAT16S	0x04	/* 16-bit FAT, less than 32M */
#define	MBR_PTYPE_EXT		0x05	/* extended partition */
#define	MBR_PTYPE_FAT16B	0x06	/* 16-bit FAT, more than 32M */
#define	MBR_PTYPE_NTFS		0x07	/* OS/2 HPFS, NTFS, QNX2, Adv. UNIX */
#define	MBR_PTYPE_DELL		0x08	/* AIX or os, or etc. */
#define MBR_PTYPE_AIX_BOOT	0x09	/* AIX boot partition or Coherent */
#define MBR_PTYPE_OS2_BOOT	0x0a	/* O/2 boot manager or Coherent swap */
#define	MBR_PTYPE_FAT32		0x0b	/* 32-bit FAT */
#define	MBR_PTYPE_FAT32L	0x0c	/* 32-bit FAT, LBA-mapped */
#define	MBR_PTYPE_7XXX		0x0d	/* 7XXX, LBA-mapped */
#define	MBR_PTYPE_FAT16L	0x0e	/* 16-bit FAT, LBA-mapped */
#define	MBR_PTYPE_EXT_LBA	0x0f	/* extended partition, LBA-mapped */
#define	MBR_PTYPE_OPUS		0x10	/* OPUS */
#define MBR_PTYPE_OS2_DOS12	0x11 	/* OS/2 DOS 12-bit FAT */
#define MBR_PTYPE_COMPAQ_DIAG	0x12 	/* Compaq diagnostics */
#define MBR_PTYPE_OS2_DOS16S	0x14 	/* OS/2 DOS 16-bit FAT <32M */
#define MBR_PTYPE_OS2_DOS16B	0x16 	/* OS/2 DOS 16-bit FAT >=32M */
#define MBR_PTYPE_OS2_IFS	0x17 	/* OS/2 hidden IFS */
#define MBR_PTYPE_AST_SWAP	0x18 	/* AST Windows swapfile */
#define MBR_PTYPE_WILLOWTECH	0x19 	/* Willowtech Photon coS */
#define MBR_PTYPE_HID_FAT32	0x1b 	/* hidden win95 fat 32 */
#define MBR_PTYPE_HID_FAT32_LBA	0x1c 	/* hidden win95 fat 32 lba */
#define MBR_PTYPE_HID_FAT16_LBA	0x1d	/* hidden win95 fat 16 lba */
#define MBR_PTYPE_WILLOWSOFT	0x20 	/* Willowsoft OFS1 */
#define MBR_PTYPE_RESERVED_x21	0x21 	/* reserved */
#define MBR_PTYPE_RESERVED_x23	0x23 	/* reserved */
#define MBR_PTYPE_RESERVED_x24	0x24	/* NEC DOS */
#define MBR_PTYPE_RESERVED_x26	0x26 	/* reserved */
#define MBR_PTYPE_RESERVED_x31	0x31 	/* reserved */
#define MBR_PTYPE_NOS		0x32	/* Alien Internet Services NOS */
#define MBR_PTYPE_RESERVED_x33	0x33 	/* reserved */
#define MBR_PTYPE_RESERVED_x34	0x34 	/* reserved */
#define MBR_PTYPE_OS2_JFS	0x35 	/* JFS on OS2 */
#define MBR_PTYPE_RESERVED_x36	0x36 	/* reserved */
#define MBR_PTYPE_THEOS		0x38 	/* Theos */
#define MBR_PTYPE_PLAN9		0x39 	/* Plan 9, or Theos spanned */
#define MBR_PTYPE_THEOS_4GB	0x3a 	/* Theos ver 4 4gb partition */
#define MBR_PTYPE_THEOS_EXT	0x3b 	/* Theos ve 4 extended partition */
#define MBR_PTYPE_PMRECOVERY	0x3c 	/* PartitionMagic recovery */
#define MBR_PTYPE_HID_NETWARE	0x3d 	/* Hidden Netware */
#define MBR_PTYPE_VENIX		0x40 	/* VENIX 286 or LynxOS */
#define	MBR_PTYPE_PREP		0x41	/* PReP */
#define	MBR_PTYPE_DRDOS_LSWAP	0x42	/* linux swap sharing DRDOS disk */
#define	MBR_PTYPE_DRDOS_LINUX	0x43	/* linux sharing DRDOS disk */
#define	MBR_PTYPE_GOBACK	0x44	/* GoBack change utility */
#define	MBR_PTYPE_BOOT_US	0x45	/* Boot US Boot manager */
#define	MBR_PTYPE_EUMEL_x46	0x46	/* EUMEL/Elan or Ergos 3 */
#define	MBR_PTYPE_EUMEL_x47	0x47	/* EUMEL/Elan or Ergos 3 */
#define	MBR_PTYPE_EUMEL_x48	0x48	/* EUMEL/Elan or Ergos 3 */
#define	MBR_PTYPE_ALFS_THIN	0x4a	/* ALFX/THIN filesystem for DOS */
#define	MBR_PTYPE_OBERON	0x4c	/* Oberon partition */
#define MBR_PTYPE_QNX4X		0x4d 	/* QNX4.x */
#define MBR_PTYPE_QNX4X_2	0x4e 	/* QNX4.x 2nd part */
#define MBR_PTYPE_QNX4X_3	0x4f 	/* QNX4.x 3rd part */
#define MBR_PTYPE_DM		0x50 	/* DM (disk manager) */
#define MBR_PTYPE_DM6_AUX1	0x51 	/* DM6 Aux1 (or Novell) */
#define MBR_PTYPE_CPM		0x52 	/* CP/M or Microport SysV/AT */
#define MBR_PTYPE_DM6_AUX3	0x53 	/* DM6 Aux3 */
#define	MBR_PTYPE_DM6_DDO	0x54	/* DM6 DDO */
#define MBR_PTYPE_EZDRIVE	0x55	/* EZ-Drive (disk manager) */
#define MBR_PTYPE_GOLDEN_BOW	0x56	/* Golden Bow (disk manager) */
#define MBR_PTYPE_DRIVE_PRO	0x57	/* Drive PRO */
#define MBR_PTYPE_PRIAM_EDISK	0x5c	/* Priam Edisk (disk manager) */
#define MBR_PTYPE_SPEEDSTOR	0x61	/* SpeedStor */
#define MBR_PTYPE_HURD		0x63	/* GNU HURD or Mach or Sys V/386 */
#define MBR_PTYPE_NOVELL_2XX	0x64	/* Novell Netware 2.xx or Speedstore */
#define MBR_PTYPE_NOVELL_3XX	0x65	/* Novell Netware 3.xx */
#define MBR_PTYPE_NOVELL_386	0x66	/* Novell 386 Netware */
#define MBR_PTYPE_NOVELL_x67	0x67	/* Novell */
#define MBR_PTYPE_NOVELL_x68	0x68	/* Novell */
#define MBR_PTYPE_NOVELL_x69	0x69	/* Novell */
#define MBR_PTYPE_DISKSECURE	0x70	/* DiskSecure Multi-Boot */
#define MBR_PTYPE_RESERVED_x71	0x71	/* reserved */
#define MBR_PTYPE_RESERVED_x73	0x73	/* reserved */
#define MBR_PTYPE_RESERVED_x74	0x74	/* reserved */
#define MBR_PTYPE_PCIX		0x75	/* PC/IX */
#define MBR_PTYPE_RESERVED_x76	0x76	/* reserved */
#define MBR_PTYPE_M2FS_M2CS	0x77	/* M2FS/M2CS partition */
#define MBR_PTYPE_XOSL_FS	0x78	/* XOSL boot loader filesystem */
#define MBR_PTYPE_MINIX_14A	0x80	/* MINIX until 1.4a */
#define MBR_PTYPE_MINIX_14B	0x81	/* MINIX since 1.4b */
#define	MBR_PTYPE_LNXSWAP	0x82	/* Linux swap or Solaris */
#define	MBR_PTYPE_LNXEXT2	0x83	/* Linux native */
#define MBR_PTYPE_OS2_C		0x84	/* OS/2 hidden C: drive */
#define	MBR_PTYPE_EXT_LNX	0x85	/* Linux extended partition */
#define	MBR_PTYPE_NTFATVOL 	0x86	/* NT FAT volume set */
#define	MBR_PTYPE_NTFSVOL	0x87	/* NTFS volume set or HPFS mirrored */
#define	MBR_PTYPE_LNX_KERNEL	0x8a	/* Linux Kernel AiR-BOOT partition */
#define	MBR_PTYPE_FT_FAT32	0x8b	/* Legacy Fault tolerant FAT32 */
#define	MBR_PTYPE_FT_FAT32_EXT	0x8c	/* Legacy Fault tolerant FAT32 ext */
#define	MBR_PTYPE_HID_FR_FD_12	0x8d	/* Hidden free FDISK FAT12 */
#define	MBR_PTYPE_LNX_LVM	0x8e	/* Linux Logical Volume Manager */
#define	MBR_PTYPE_HID_FR_FD_16	0x90	/* Hidden free FDISK FAT16 */
#define	MBR_PTYPE_HID_FR_FD_EXT	0x91	/* Hidden free FDISK DOS EXT */
#define	MBR_PTYPE_HID_FR_FD_16B	0x92	/* Hidden free FDISK FAT16 Big */
#define MBR_PTYPE_AMOEBA_FS 	0x93	/* Amoeba filesystem */
#define MBR_PTYPE_AMOEBA_BAD 	0x94	/* Amoeba bad block table */
#define MBR_PTYPE_MIT_EXOPC 	0x95	/* MIT EXOPC native partitions */
#define	MBR_PTYPE_HID_FR_FD_32	0x97	/* Hidden free FDISK FAT32 */
#define	MBR_PTYPE_DATALIGHT	0x98	/* Datalight ROM-DOS Super-Boot */
#define MBR_PTYPE_MYLEX 	0x99	/* Mylex EISA SCSI */
#define	MBR_PTYPE_HID_FR_FD_16L	0x9a	/* Hidden free FDISK FAT16 LBA */
#define	MBR_PTYPE_HID_FR_FD_EXL	0x9b	/* Hidden free FDISK EXT LBA */
#define MBR_PTYPE_BSDI	 	0x9f	/* BSDI? */
#define MBR_PTYPE_IBM_HIB	0xa0	/* IBM Thinkpad hibernation */
#define MBR_PTYPE_HP_VOL_xA1	0xa1	/* HP Volume expansion (SpeedStor) */
#define MBR_PTYPE_HP_VOL_xA3	0xa3	/* HP Volume expansion (SpeedStor) */
#define MBR_PTYPE_HP_VOL_xA4	0xa4	/* HP Volume expansion (SpeedStor) */
#define	MBR_PTYPE_386BSD	0xa5	/* 386BSD partition type */
#define	MBR_PTYPE_OPENBSD	0xa6	/* OpenBSD partition type */
#define	MBR_PTYPE_NEXTSTEP_486 	0xa7	/* NeXTSTEP 486 */
#define	MBR_PTYPE_APPLE_UFS 	0xa8	/* Apple UFS */
#define	MBR_PTYPE_NETBSD	0xa9	/* NetBSD partition type */
#define MBR_PTYPE_OLIVETTI	0xaa	/* Olivetty Fat12 1.44MB Service part */
#define MBR_PTYPE_APPLE_BOOT	0xab	/* Apple Boot */
#define MBR_PTYPE_SHAG_OS	0xae	/* SHAG OS filesystem */
#define MBR_PTYPE_APPLE_HFS	0xaf	/* Apple HFS */
#define MBR_PTYPE_BOOTSTAR_DUM	0xb0	/* BootStar Dummy */
#define MBR_PTYPE_RESERVED_xB1	0xb1	/* reserved */
#define MBR_PTYPE_RESERVED_xB3	0xb3	/* reserved */
#define MBR_PTYPE_RESERVED_xB4	0xb4	/* reserved */
#define MBR_PTYPE_RESERVED_xB6	0xb6	/* reserved */
#define MBR_PTYPE_BSDI_386	0xb7	/* BSDI BSD/386 filesystem */
#define MBR_PTYPE_BSDI_SWAP	0xb8	/* BSDI BSD/386 swap */
#define	MBR_PTYPE_BOOT_WIZARD	0xbb	/* Boot Wizard Hidden */
#define	MBR_PTYPE_SOLARIS_8	0xbe	/* Solaris 8 partition type */
#define	MBR_PTYPE_SOLARIS	0xbf	/* Solaris partition type */
#define MBR_PTYPE_CTOS		0xc0 	/* CTOS */
#define MBR_PTYPE_DRDOS_FAT12	0xc1 	/* DRDOS/sec (FAT-12) */
#define MBR_PTYPE_HID_LNX	0xc2 	/* Hidden Linux */
#define MBR_PTYPE_HID_LNX_SWAP	0xc3 	/* Hidden Linux swap */
#define MBR_PTYPE_DRDOS_FAT16S	0xc4 	/* DRDOS/sec (FAT-16, < 32M) */
#define MBR_PTYPE_DRDOS_EXT	0xc5 	/* DRDOS/sec (EXT) */
#define MBR_PTYPE_DRDOS_FAT16B	0xc6 	/* DRDOS/sec (FAT-16, >= 32M) */
#define MBR_PTYPE_SYRINX	0xc7 	/* Syrinx (Cyrnix?) or HPFS disabled */
#define MBR_PTYPE_DRDOS_8_xC8	0xc8 	/* Reserved for DR-DOS 8.0+ */
#define MBR_PTYPE_DRDOS_8_xC9	0xc9 	/* Reserved for DR-DOS 8.0+ */
#define MBR_PTYPE_DRDOS_8_xCA	0xca 	/* Reserved for DR-DOS 8.0+ */
#define MBR_PTYPE_DRDOS_74_CHS	0xcb 	/* DR-DOS 7.04+ Secured FAT32 CHS */
#define MBR_PTYPE_DRDOS_74_LBA	0xcc 	/* DR-DOS 7.04+ Secured FAT32 LBA */
#define MBR_PTYPE_CTOS_MEMDUMP	0xcd	/* CTOS Memdump */
#define MBR_PTYPE_DRDOS_74_16X	0xce 	/* DR-DOS 7.04+ FAT16X LBA */
#define MBR_PTYPE_DRDOS_74_EXT	0xcf 	/* DR-DOS 7.04+ EXT LBA */
#define MBR_PTYPE_REAL32	0xd0 	/* REAL/32 secure big partition */
#define MBR_PTYPE_MDOS_FAT12	0xd1 	/* Old Multiuser DOS FAT12 */
#define MBR_PTYPE_MDOS_FAT16S	0xd4 	/* Old Multiuser DOS FAT16 Small */
#define MBR_PTYPE_MDOS_EXT	0xd5 	/* Old Multiuser DOS Extended */
#define MBR_PTYPE_MDOS_FAT16B	0xd6 	/* Old Multiuser DOS FAT16 Big */
#define MBR_PTYPE_CPM_86	0xd8 	/* CP/M 86 */
#define MBR_PTYPE_CONCURRENT	0xdb 	/* CP/M or Concurrent CP/M */
#define MBR_PTYPE_HID_CTOS_MEM	0xdd 	/* Hidden CTOS Memdump */
#define MBR_PTYPE_DELL_UTIL	0xde 	/* Dell PowerEdge Server utilities */
#define MBR_PTYPE_DGUX_VIRTUAL	0xdf 	/* DG/UX virtual disk manager */
#define MBR_PTYPE_STMICROELEC	0xe0 	/* STMicroelectronics ST AVFS */
#define MBR_PTYPE_DOS_ACCESS	0xe1 	/* DOS access or SpeedStor 12-bit */
#define MBR_PTYPE_STORDIM	0xe3 	/* DOS R/O or Storage Dimensions */
#define MBR_PTYPE_SPEEDSTOR_16S	0xe4 	/* SpeedStor 16-bit FAT < 1024 cyl. */
#define MBR_PTYPE_RESERVED_xE5	0xe5	/* reserved */
#define MBR_PTYPE_RESERVED_xE6	0xe6	/* reserved */
#define MBR_PTYPE_BEOS		0xeb 	/* BeOS */
#define	MBR_PTYPE_PMBR		0xee	/* GPT Protective MBR */
#define	MBR_PTYPE_EFI		0xef	/* EFI system partition */
#define MBR_PTYPE_LNX_PA_RISC	0xf0 	/* Linux PA-RISC boot loader */
#define MBR_PTYPE_SPEEDSTOR_X	0xf1 	/* SpeedStor or Storage Dimensions */
#define MBR_PTYPE_DOS33_SEC	0xf2 	/* DOS 3.3+ Secondary */
#define MBR_PTYPE_RESERVED_xF3	0xf3	/* reserved */
#define MBR_PTYPE_SPEEDSTOR_L	0xf4	/* SpeedStor large partition */
#define MBR_PTYPE_PROLOGUE	0xf5	/* Prologue multi-volumen partition */
#define MBR_PTYPE_RESERVED_xF6	0xf6 	/* reserved */
#define MBR_PTYPE_PCACHE	0xf9 	/* pCache: ext2/ext3 persistent cache */
#define MBR_PTYPE_BOCHS		0xfa 	/* Bochs x86 emulator */
#define MBR_PTYPE_VMWARE	0xfb 	/* VMware File System */
#define MBR_PTYPE_VMWARE_SWAP	0xfc 	/* VMware Swap */
#define MBR_PTYPE_LNX_RAID	0xfd 	/* Linux RAID partition persistent sb */
#define MBR_PTYPE_LANSTEP	0xfe	/* LANstep or IBM PS/2 IML */
#define MBR_PTYPE_XENIX_BAD	0xff 	/* Xenix Bad Block Table */

#ifdef MBRPTYPENAMES
static const struct mbr_ptype {
	int id;
	const char *name;
} mbr_ptypes[] = {
	{ MBR_PTYPE_UNUSED, "<UNUSED>" },
	{ MBR_PTYPE_FAT12, "Primary DOS with 12 bit FAT" },
	{ MBR_PTYPE_XENIX_ROOT, "XENIX / filesystem" },
	{ MBR_PTYPE_XENIX_USR, "XENIX /usr filesystem" },
	{ MBR_PTYPE_FAT16S, "Primary DOS with 16 bit FAT <32M" },
	{ MBR_PTYPE_EXT, "Extended partition" },
	{ MBR_PTYPE_FAT16B, "Primary 'big' DOS, 16-bit FAT (> 32MB)" },
	{ MBR_PTYPE_NTFS, "NTFS, OS/2 HPFS, QNX2 or Advanced UNIX" },
	{ MBR_PTYPE_DELL, "AIX filesystem or OS/2 (thru v1.3) or DELL "
			  "multiple drives or Commodore DOS or SplitDrive" },
	{ MBR_PTYPE_AIX_BOOT, "AIX boot partition or Coherent" },
	{ MBR_PTYPE_OS2_BOOT, "OS/2 Boot Manager or Coherent swap or OPUS" },
	{ MBR_PTYPE_FAT32, "Primary DOS with 32 bit FAT" },
	{ MBR_PTYPE_FAT32L, "Primary DOS with 32 bit FAT - LBA" },
	{ MBR_PTYPE_7XXX, "Type 7??? - LBA" },
	{ MBR_PTYPE_FAT16L, "DOS (16-bit FAT) - LBA" },
	{ MBR_PTYPE_EXT_LBA, "Ext. partition - LBA" },
	{ MBR_PTYPE_OPUS, "OPUS" },
	{ MBR_PTYPE_OS2_DOS12, "OS/2 BM: hidden DOS 12-bit FAT" },
	{ MBR_PTYPE_COMPAQ_DIAG, "Compaq diagnostics" },
	{ MBR_PTYPE_OS2_DOS16S, "OS/2 BM: hidden DOS 16-bit FAT <32M "
				"or Novell DOS 7.0 bug" },
	{ MBR_PTYPE_OS2_DOS16B, "OS/2 BM: hidden DOS 16-bit FAT >=32M" },
	{ MBR_PTYPE_OS2_IFS, "OS/2 BM: hidden IFS" },
	{ MBR_PTYPE_AST_SWAP, "AST Windows swapfile" },
	{ MBR_PTYPE_WILLOWTECH, "Willowtech Photon coS" },
	{ MBR_PTYPE_HID_FAT32, "hidden Windows/95 FAT32" },
	{ MBR_PTYPE_HID_FAT32_LBA, "hidden Windows/95 FAT32 LBA" },
	{ MBR_PTYPE_HID_FAT16_LBA, "hidden Windows/95 FAT16 LBA" },
	{ MBR_PTYPE_WILLOWSOFT, "Willowsoft OFS1" },
	{ MBR_PTYPE_RESERVED_x21, "reserved" },
	{ MBR_PTYPE_RESERVED_x23, "reserved" },
	{ MBR_PTYPE_RESERVED_x24, "NEC DOS"},
	{ MBR_PTYPE_RESERVED_x26, "reserved" },
	{ MBR_PTYPE_RESERVED_x31, "reserved" },
	{ MBR_PTYPE_NOS, "Alien Internet Services NOS" },
	{ MBR_PTYPE_RESERVED_x33, "reserved" },
	{ MBR_PTYPE_RESERVED_x34, "reserved" },
	{ MBR_PTYPE_OS2_JFS, "JFS on OS2" },
	{ MBR_PTYPE_RESERVED_x36, "reserved" },
	{ MBR_PTYPE_THEOS, "Theos" },
	{ MBR_PTYPE_PLAN9, "Plan 9" },
	{ MBR_PTYPE_PLAN9, "Plan 9, or Theos spanned" },
	{ MBR_PTYPE_THEOS_4GB,	"Theos ver 4 4gb partition" },
	{ MBR_PTYPE_THEOS_EXT,	"Theos ve 4 extended partition" },
	{ MBR_PTYPE_PMRECOVERY, "PartitionMagic recovery" },
	{ MBR_PTYPE_HID_NETWARE, "Hidden Netware" },
	{ MBR_PTYPE_VENIX, "VENIX 286 or LynxOS" },
	{ MBR_PTYPE_PREP, "Linux/MINIX (sharing disk with DRDOS) "
			  "or Personal RISC boot" },
	{ MBR_PTYPE_DRDOS_LSWAP, "SFS or Linux swap "
				 "(sharing disk with DRDOS)" },
	{ MBR_PTYPE_DRDOS_LINUX, "Linux native (sharing disk with DRDOS)" },
	{ MBR_PTYPE_GOBACK, "GoBack change utility" },
	{ MBR_PTYPE_BOOT_US, "Boot US Boot manager" },
	{ MBR_PTYPE_EUMEL_x46, "EUMEL/Elan or Ergos 3" },
	{ MBR_PTYPE_EUMEL_x47, "EUMEL/Elan or Ergos 3" },
	{ MBR_PTYPE_EUMEL_x48, "EUMEL/Elan or Ergos 3" },
	{ MBR_PTYPE_ALFS_THIN, "ALFX/THIN filesystem for DOS" },
	{ MBR_PTYPE_OBERON, "Oberon partition" },
	{ MBR_PTYPE_QNX4X, "QNX4.x" },
	{ MBR_PTYPE_QNX4X_2, "QNX4.x 2nd part" },
	{ MBR_PTYPE_QNX4X_3, "QNX4.x 3rd part" },
	{ MBR_PTYPE_DM, "DM (disk manager)" },
	{ MBR_PTYPE_DM6_AUX1, "DM6 Aux1 (or Novell)" },
	{ MBR_PTYPE_CPM, "CP/M or Microport SysV/AT" },
	{ MBR_PTYPE_DM6_AUX3, "DM6 Aux3" },
	{ MBR_PTYPE_DM6_DDO, "DM6 DDO" },
	{ MBR_PTYPE_EZDRIVE, "EZ-Drive (disk manager)" },
	{ MBR_PTYPE_GOLDEN_BOW, "Golden Bow (disk manager)" },
	{ MBR_PTYPE_DRIVE_PRO, "Drive PRO" },
	{ MBR_PTYPE_PRIAM_EDISK, "Priam Edisk (disk manager)" },
	{ MBR_PTYPE_SPEEDSTOR, "SpeedStor" },
	{ MBR_PTYPE_HURD, "GNU HURD or Mach or Sys V/386 "
			  "(such as ISC UNIX) or MtXinu" },
	{ MBR_PTYPE_NOVELL_2XX, "Novell Netware 2.xx or Speedstore" },
	{ MBR_PTYPE_NOVELL_3XX, "Novell Netware 3.xx" },
	{ MBR_PTYPE_NOVELL_386, "Novell 386 Netware" },
	{ MBR_PTYPE_NOVELL_x67, "Novell" },
	{ MBR_PTYPE_NOVELL_x68, "Novell" },
	{ MBR_PTYPE_NOVELL_x69, "Novell" },
	{ MBR_PTYPE_DISKSECURE, "DiskSecure Multi-Boot" },
	{ MBR_PTYPE_RESERVED_x71, "reserved" },
	{ MBR_PTYPE_RESERVED_x73, "reserved" },
	{ MBR_PTYPE_RESERVED_x74, "reserved" },
	{ MBR_PTYPE_PCIX, "PC/IX" },
	{ MBR_PTYPE_RESERVED_x76, "reserved" },
	{ MBR_PTYPE_M2FS_M2CS,	"M2FS/M2CS partition" },
	{ MBR_PTYPE_XOSL_FS, "XOSL boot loader filesystem" },
	{ MBR_PTYPE_MINIX_14A, "MINIX until 1.4a" },
	{ MBR_PTYPE_MINIX_14B, "MINIX since 1.4b, early Linux, Mitac dmgr" },
	{ MBR_PTYPE_LNXSWAP, "Linux swap or Prime or Solaris" },
	{ MBR_PTYPE_LNXEXT2, "Linux native" },
	{ MBR_PTYPE_OS2_C, "OS/2 hidden C: drive" },
	{ MBR_PTYPE_EXT_LNX, "Linux extended" },
	{ MBR_PTYPE_NTFATVOL, "NT FAT volume set" },
	{ MBR_PTYPE_NTFSVOL, "NTFS volume set or HPFS mirrored" },
	{ MBR_PTYPE_LNX_KERNEL,	"Linux Kernel AiR-BOOT partition" },
	{ MBR_PTYPE_FT_FAT32, "Legacy Fault tolerant FAT32" },
	{ MBR_PTYPE_FT_FAT32_EXT, "Legacy Fault tolerant FAT32 ext" },
	{ MBR_PTYPE_HID_FR_FD_12, "Hidden free FDISK FAT12" },
	{ MBR_PTYPE_LNX_LVM, "Linux Logical Volume Manager" },
	{ MBR_PTYPE_HID_FR_FD_16, "Hidden free FDISK FAT16" },
	{ MBR_PTYPE_HID_FR_FD_EXT, "Hidden free FDISK DOS EXT" },
	{ MBR_PTYPE_HID_FR_FD_16L, "Hidden free FDISK FAT16 Large" },
	{ MBR_PTYPE_AMOEBA_FS, "Amoeba filesystem" },
	{ MBR_PTYPE_AMOEBA_BAD, "Amoeba bad block table" },
	{ MBR_PTYPE_MIT_EXOPC, "MIT EXOPC native partitions" },
	{ MBR_PTYPE_HID_FR_FD_32, "Hidden free FDISK FAT32" },
	{ MBR_PTYPE_DATALIGHT, "Datalight ROM-DOS Super-Boot" },
	{ MBR_PTYPE_MYLEX, "Mylex EISA SCSI" },
	{ MBR_PTYPE_HID_FR_FD_16L, "Hidden free FDISK FAT16 LBA" },
	{ MBR_PTYPE_HID_FR_FD_EXL, "Hidden free FDISK EXT LBA" },
	{ MBR_PTYPE_BSDI, "BSDI?" },
	{ MBR_PTYPE_IBM_HIB, "IBM Thinkpad hibernation" },
	{ MBR_PTYPE_HP_VOL_xA1, "HP Volume expansion (SpeedStor)" },
	{ MBR_PTYPE_HP_VOL_xA3, "HP Volume expansion (SpeedStor)" },
	{ MBR_PTYPE_HP_VOL_xA4, "HP Volume expansion (SpeedStor)" },
	{ MBR_PTYPE_386BSD, "FreeBSD or 386BSD or old NetBSD" },
	{ MBR_PTYPE_OPENBSD, "OpenBSD" },
	{ MBR_PTYPE_NEXTSTEP_486, "NeXTSTEP 486" },
	{ MBR_PTYPE_APPLE_UFS, "Apple UFS" },
	{ MBR_PTYPE_NETBSD, "NetBSD" },
	{ MBR_PTYPE_OLIVETTI, "Olivetty Fat12 1.44MB Service part" },
	{ MBR_PTYPE_SHAG_OS, "SHAG OS filesystem" },
	{ MBR_PTYPE_BOOTSTAR_DUM, "BootStar Dummy" },
	{ MBR_PTYPE_BOOT_WIZARD, "Boot Wizard Hidden" },
	{ MBR_PTYPE_APPLE_BOOT, "Apple Boot" },
	{ MBR_PTYPE_APPLE_HFS, "Apple HFS" },
	{ MBR_PTYPE_RESERVED_xB6, "reserved" },
	{ MBR_PTYPE_RESERVED_xB6, "reserved" },
	{ MBR_PTYPE_RESERVED_xB6, "reserved" },
	{ MBR_PTYPE_RESERVED_xB6, "reserved" },
	{ MBR_PTYPE_BSDI_386, "BSDI BSD/386 filesystem" },
	{ MBR_PTYPE_BSDI_SWAP, "BSDI BSD/386 swap" },
	{ MBR_PTYPE_SOLARIS_8, "Solaris 8 boot partition" },
	{ MBR_PTYPE_SOLARIS, "Solaris boot partition" },
	{ MBR_PTYPE_CTOS, "CTOS" },
	{ MBR_PTYPE_DRDOS_FAT12, "DRDOS/sec (FAT-12)" },
	{ MBR_PTYPE_HID_LNX, "Hidden Linux" },
	{ MBR_PTYPE_HID_LNX_SWAP, "Hidden Linux Swap" },
	{ MBR_PTYPE_DRDOS_FAT16S, "DRDOS/sec (FAT-16, < 32M)" },
	{ MBR_PTYPE_DRDOS_EXT, "DRDOS/sec (EXT)" },
	{ MBR_PTYPE_DRDOS_FAT16B, "DRDOS/sec (FAT-16, >= 32M)" },
	{ MBR_PTYPE_SYRINX, "Syrinx (Cyrnix?) or HPFS disabled" },
	{ MBR_PTYPE_DRDOS_8_xC8, "Reserved for DR-DOS 8.0+" },
	{ MBR_PTYPE_DRDOS_8_xC9, "Reserved for DR-DOS 8.0+" },
	{ MBR_PTYPE_DRDOS_8_xCA, "Reserved for DR-DOS 8.0+" },
	{ MBR_PTYPE_DRDOS_74_CHS, "DR-DOS 7.04+ Secured FAT32 CHS" },
	{ MBR_PTYPE_DRDOS_74_LBA, "DR-DOS 7.04+ Secured FAT32 LBA" },
	{ MBR_PTYPE_CTOS_MEMDUMP, "CTOS Memdump" },
	{ MBR_PTYPE_DRDOS_74_16X, "DR-DOS 7.04+ FAT16X LBA" },
	{ MBR_PTYPE_DRDOS_74_EXT, "DR-DOS 7.04+ EXT LBA" },
	{ MBR_PTYPE_REAL32, "REAL/32 secure big partition" },
	{ MBR_PTYPE_MDOS_FAT12, "Old Multiuser DOS FAT12" },
	{ MBR_PTYPE_MDOS_FAT16S, "Old Multiuser DOS FAT16 Small" },
	{ MBR_PTYPE_MDOS_EXT, "Old Multiuser DOS Extended" },
	{ MBR_PTYPE_MDOS_FAT16B, "Old Multiuser DOS FAT16 Big" },
	{ MBR_PTYPE_CPM_86, "CP/M 86" },
	{ MBR_PTYPE_CONCURRENT, "CP/M or Concurrent CP/M or Concurrent DOS "
				"or CTOS" },
	{ MBR_PTYPE_HID_CTOS_MEM, "Hidden CTOS Memdump" },
	{ MBR_PTYPE_DELL_UTIL, "Dell PowerEdge Server utilities" },
	{ MBR_PTYPE_DGUX_VIRTUAL, "DG/UX virtual disk manager" },
	{ MBR_PTYPE_STMICROELEC, "STMicroelectronics ST AVFS" },
	{ MBR_PTYPE_DOS_ACCESS, "DOS access or SpeedStor 12-bit FAT "
				"extended partition" },
	{ MBR_PTYPE_STORDIM, "DOS R/O or SpeedStor or Storage Dimensions" },
	{ MBR_PTYPE_SPEEDSTOR_16S, "SpeedStor 16-bit FAT extended partition "
				   "< 1024 cyl." },
	{ MBR_PTYPE_RESERVED_xE5, "reserved" },
	{ MBR_PTYPE_RESERVED_xE6, "reserved" },
	{ MBR_PTYPE_BEOS, "BeOS" },
	{ MBR_PTYPE_PMBR, "GPT Protective MBR" },
	{ MBR_PTYPE_EFI, "EFI system partition" },
	{ MBR_PTYPE_LNX_PA_RISC, "Linux PA-RISC boot loader" },
	{ MBR_PTYPE_SPEEDSTOR_X, "SpeedStor or Storage Dimensions" },
	{ MBR_PTYPE_DOS33_SEC, "DOS 3.3+ Secondary" },
	{ MBR_PTYPE_RESERVED_xF3, "reserved" },
	{ MBR_PTYPE_SPEEDSTOR_L, "SpeedStor large partition or "
				 "Storage Dimensions" },
	{ MBR_PTYPE_PROLOGUE, "Prologue multi-volumen partition" },
	{ MBR_PTYPE_RESERVED_xF6, "reserved" },
	{ MBR_PTYPE_PCACHE, "pCache: ext2/ext3 persistent cache" },
	{ MBR_PTYPE_BOCHS, "Bochs x86 emulator" },
	{ MBR_PTYPE_VMWARE, "VMware File System" },
	{ MBR_PTYPE_VMWARE_SWAP, "VMware Swap" },
	{ MBR_PTYPE_LNX_RAID, "Linux RAID partition persistent sb" },
	{ MBR_PTYPE_LANSTEP, "SpeedStor >1024 cyl. or LANstep "
			     "or IBM PS/2 IML" },
	{ MBR_PTYPE_XENIX_BAD, "Xenix Bad Block Table" },
};
#endif

#define	MBR_PSECT(s)		((s) & 0x3f)
#define	MBR_PCYL(c, s)		((c) + (((s) & 0xc0) << 2))

#define	MBR_IS_EXTENDED(x)	((x) == MBR_PTYPE_EXT || \
				 (x) == MBR_PTYPE_EXT_LBA || \
				 (x) == MBR_PTYPE_EXT_LNX)

		/* values for mbr_bootsel.mbrbs_flags */
#define	MBR_BS_ACTIVE	0x01	/* Bootselector active (or code present) */
#define	MBR_BS_EXTINT13	0x02	/* Set by fdisk if LBA needed (deprecated) */
#define	MBR_BS_READ_LBA	0x04	/* Force LBA reads (deprecated) */
#define	MBR_BS_EXTLBA	0x08	/* Extended ptn capable (LBA reads) */
#define	MBR_BS_ASCII	0x10	/* Bootselect code needs ascii key code */
/* This is always set, the bootsel is located using the magic number...  */
#define	MBR_BS_NEWMBR	0x80	/* New bootsel at offset 440 */

#if !defined(__ASSEMBLER__)					/* { */

/*
 * (x86) BIOS Parameter Block for FAT12
 */
struct mbr_bpbFAT12 {
	uint16_t	bpbBytesPerSec;	/* bytes per sector */
	uint8_t		bpbSecPerClust;	/* sectors per cluster */
	uint16_t	bpbResSectors;	/* number of reserved sectors */
	uint8_t		bpbFATs;	/* number of FATs */
	uint16_t	bpbRootDirEnts;	/* number of root directory entries */
	uint16_t	bpbSectors;	/* total number of sectors */
	uint8_t		bpbMedia;	/* media descriptor */
	uint16_t	bpbFATsecs;	/* number of sectors per FAT */
	uint16_t	bpbSecPerTrack;	/* sectors per track */
	uint16_t	bpbHeads;	/* number of heads */
	uint16_t	bpbHiddenSecs;	/* # of hidden sectors */
} __packed;

/*
 * (x86) BIOS Parameter Block for FAT16
 */
struct mbr_bpbFAT16 {
	uint16_t	bpbBytesPerSec;	/* bytes per sector */
	uint8_t		bpbSecPerClust;	/* sectors per cluster */
	uint16_t	bpbResSectors;	/* number of reserved sectors */
	uint8_t		bpbFATs;	/* number of FATs */
	uint16_t	bpbRootDirEnts;	/* number of root directory entries */
	uint16_t	bpbSectors;	/* total number of sectors */
	uint8_t		bpbMedia;	/* media descriptor */
	uint16_t	bpbFATsecs;	/* number of sectors per FAT */
	uint16_t	bpbSecPerTrack;	/* sectors per track */
	uint16_t	bpbHeads;	/* number of heads */
	uint32_t	bpbHiddenSecs;	/* # of hidden sectors */
	uint32_t	bpbHugeSectors;	/* # of sectors if bpbSectors == 0 */
	uint8_t		bsDrvNum;	/* Int 0x13 drive number (e.g. 0x80) */
	uint8_t		bsReserved1;	/* Reserved; set to 0 */
	uint8_t		bsBootSig;	/* 0x29 if next 3 fields are present */
	uint8_t		bsVolID[4];	/* Volume serial number */
	uint8_t		bsVolLab[11];	/* Volume label */
	uint8_t		bsFileSysType[8];
					/* "FAT12   ", "FAT16   ", "FAT     " */
} __packed;

/*
 * (x86) BIOS Parameter Block for FAT32
 */
struct mbr_bpbFAT32 {
	uint16_t	bpbBytesPerSec;	/* bytes per sector */
	uint8_t		bpbSecPerClust;	/* sectors per cluster */
	uint16_t	bpbResSectors;	/* number of reserved sectors */
	uint8_t		bpbFATs;	/* number of FATs */
	uint16_t	bpbRootDirEnts;	/* number of root directory entries */
	uint16_t	bpbSectors;	/* total number of sectors */
	uint8_t		bpbMedia;	/* media descriptor */
	uint16_t	bpbFATsecs;	/* number of sectors per FAT */
	uint16_t	bpbSecPerTrack;	/* sectors per track */
	uint16_t	bpbHeads;	/* number of heads */
	uint32_t	bpbHiddenSecs;	/* # of hidden sectors */
	uint32_t	bpbHugeSectors;	/* # of sectors if bpbSectors == 0 */
	uint32_t	bpbBigFATsecs;	/* like bpbFATsecs for FAT32 */
	uint16_t	bpbExtFlags;	/* extended flags: */
#define	MBR_FAT32_FATNUM	0x0F	/*   mask for numbering active FAT */
#define	MBR_FAT32_FATMIRROR	0x80	/*   FAT is mirrored (as previously) */
	uint16_t	bpbFSVers;	/* filesystem version */
#define	MBR_FAT32_FSVERS	0	/*   currently only 0 is understood */
	uint32_t	bpbRootClust;	/* start cluster for root directory */
	uint16_t	bpbFSInfo;	/* filesystem info structure sector */
	uint16_t	bpbBackup;	/* backup boot sector */
	uint8_t		bsReserved[12];	/* Reserved for future expansion */
	uint8_t		bsDrvNum;	/* Int 0x13 drive number (e.g. 0x80) */
	uint8_t		bsReserved1;	/* Reserved; set to 0 */
	uint8_t		bsBootSig;	/* 0x29 if next 3 fields are present */
	uint8_t		bsVolID[4];	/* Volume serial number */
	uint8_t		bsVolLab[11];	/* Volume label */
	uint8_t		bsFileSysType[8]; /* "FAT32   " */
} __packed;

/*
 * (x86) MBR boot selector
 */
struct mbr_bootsel {
	uint8_t		mbrbs_defkey;
	uint8_t		mbrbs_flags;
	uint16_t	mbrbs_timeo;
	char		mbrbs_nametab[MBR_PART_COUNT][MBR_BS_PARTNAMESIZE + 1];
} __packed;

/*
 * MBR partition
 */
struct mbr_partition {
	uint8_t		mbrp_flag;	/* MBR partition flags */
	uint8_t		mbrp_shd;	/* Starting head */
	uint8_t		mbrp_ssect;	/* Starting sector */
	uint8_t		mbrp_scyl;	/* Starting cylinder */
	uint8_t		mbrp_type;	/* Partition type (see below) */
	uint8_t		mbrp_ehd;	/* End head */
	uint8_t		mbrp_esect;	/* End sector */
	uint8_t		mbrp_ecyl;	/* End cylinder */
	uint32_t	mbrp_start;	/* Absolute starting sector number */
	uint32_t	mbrp_size;	/* Partition size in sectors */
} __packed;

int xlat_mbr_fstype(int);	/* in sys/lib/libkern/xlat_mbr_fstype.c */

/*
 * MBR boot sector.
 * This is used by both the MBR (Master Boot Record) in sector 0 of the disk
 * and the PBR (Partition Boot Record) in sector 0 of an MBR partition.
 */
struct mbr_sector {
					/* Jump instruction to boot code.  */
					/* Usually 0xE9nnnn or 0xEBnn90 */
	uint8_t			mbr_jmpboot[3];
					/* OEM name and version */
	uint8_t			mbr_oemname[8];
	union {				/* BIOS Parameter Block */
		struct mbr_bpbFAT12	bpb12;
		struct mbr_bpbFAT16	bpb16;
		struct mbr_bpbFAT32	bpb32;
	} mbr_bpb;
					/* Boot code */
	uint8_t			mbr_bootcode[310];
					/* Config for /usr/mdec/mbr_bootsel */
	struct mbr_bootsel	mbr_bootsel;
					/* NT Drive Serial Number */
	uint32_t		mbr_dsn;
					/* mbr_bootsel magic */
	uint16_t		mbr_bootsel_magic;
					/* MBR partition table */
	struct mbr_partition	mbr_parts[MBR_PART_COUNT];
					/* MBR magic (0xaa55) */
	uint16_t		mbr_magic;
} __packed;

#endif	/* !defined(__ASSEMBLER__) */				/* } */


/* ------------------------------------------
 * shared --
 *	definitions shared by many platforms
 */

#if !defined(__ASSEMBLER__)					/* { */

	/* Maximum # of blocks in bbi_block_table, each bbi_block_size long */
#define	SHARED_BBINFO_MAXBLOCKS	118	/* so sizeof(shared_bbinfo) == 512 */

struct shared_bbinfo {
	uint8_t bbi_magic[32];
	int32_t bbi_block_size;
	int32_t bbi_block_count;
	int32_t bbi_block_table[SHARED_BBINFO_MAXBLOCKS];
};

/* ------------------------------------------
 * alpha --
 *	Alpha (disk, but also tape) Boot Block.
 *
 *	See Section (III) 3.6.1 of the Alpha Architecture Reference Manual.
 */

struct alpha_boot_block {
	uint64_t bb_data[63];		/* data (disklabel, also as below) */
	uint64_t bb_cksum;		/* checksum of the boot block,
					 * taken as uint64_t's
					 */
};
#define	bb_secsize	bb_data[60]	/* secondary size (blocks) */
#define	bb_secstart	bb_data[61]	/* secondary start (blocks) */
#define	bb_flags	bb_data[62]	/* unknown flags (set to zero) */

#define	ALPHA_BOOT_BLOCK_OFFSET		0	/* offset of boot block. */
#define	ALPHA_BOOT_BLOCK_BLOCKSIZE	512	/* block size for sector
						 * size/start, and for boot
						 * block itself.
						 */

#define	ALPHA_BOOT_BLOCK_CKSUM(bb,cksum)				\
	do {								\
		const struct alpha_boot_block *_bb = (bb);		\
		uint64_t _cksum;					\
		size_t _i;						\
									\
		_cksum = 0;						\
		for (_i = 0;						\
		    _i < (sizeof _bb->bb_data / sizeof _bb->bb_data[0]); \
		    _i++)						\
			_cksum += le64toh(_bb->bb_data[_i]);		\
		*(cksum) = htole64(_cksum);				\
	} while (/*CONSTCOND*/ 0)

/* ------------------------------------------
 * apple --
 *	Apple computers boot block related information
 */

/*
 *	Driver Descriptor Map, from Inside Macintosh: Devices, SCSI Manager
 *	pp 12-13.  The driver descriptor map always resides on physical block 0.
 */
struct apple_drvr_descriptor {
	uint32_t	descBlock;	/* first block of driver */
	uint16_t	descSize;	/* driver size in blocks */
	uint16_t	descType;	/* system type */
} __packed;

/*
 *	system types; Apple reserves 0-15
 */
#define	APPLE_DRVR_TYPE_MACINTOSH	1

#define	APPLE_DRVR_MAP_MAGIC		0x4552
#define	APPLE_DRVR_MAP_MAX_DESCRIPTORS	61

struct apple_drvr_map {
	uint16_t	sbSig;		/* map signature */
	uint16_t	sbBlockSize;	/* block size of device */
	uint32_t	sbBlkCount;	/* number of blocks on device */
	uint16_t	sbDevType;	/* (used internally by ROM) */
	uint16_t	sbDevID;	/* (used internally by ROM) */
	uint32_t	sbData;		/* (used internally by ROM) */
	uint16_t	sbDrvrCount;	/* number of driver descriptors */
	struct apple_drvr_descriptor sb_dd[APPLE_DRVR_MAP_MAX_DESCRIPTORS];
	uint16_t	pad[3];
} __packed;

/*
 *	Partition map structure from Inside Macintosh: Devices, SCSI Manager
 *	pp. 13-14.  The partition map always begins on physical block 1.
 *
 *	With the exception of block 0, all blocks on the disk must belong to
 *	exactly one partition.  The partition map itself belongs to a partition
 *	of type `APPLE_PARTITION_MAP', and is not limited in size by anything
 *	other than available disk space.  The partition map is not necessarily
 *	the first partition listed.
 */
#define	APPLE_PART_MAP_ENTRY_MAGIC	0x504d

struct apple_part_map_entry {
	uint16_t	pmSig;		/* partition signature */
	uint16_t	pmSigPad;	/* (reserved) */
	uint32_t	pmMapBlkCnt;	/* number of blocks in partition map */
	uint32_t	pmPyPartStart;	/* first physical block of partition */
	uint32_t	pmPartBlkCnt;	/* number of blocks in partition */
	uint8_t		pmPartName[32];	/* partition name */
	uint8_t		pmPartType[32];	/* partition type */
	uint32_t	pmLgDataStart;	/* first logical block of data area */
	uint32_t	pmDataCnt;	/* number of blocks in data area */
	uint32_t	pmPartStatus;	/* partition status information */
/*
 * Partition Status Information from Apple Tech Note 1189
 */
#define	APPLE_PS_VALID		0x00000001	/* Entry is valid */
#define	APPLE_PS_ALLOCATED	0x00000002	/* Entry is allocated */
#define	APPLE_PS_IN_USE		0x00000004	/* Entry in use */
#define	APPLE_PS_BOOT_INFO	0x00000008	/* Entry contains boot info */
#define	APPLE_PS_READABLE	0x00000010	/* Entry is readable */
#define	APPLE_PS_WRITABLE	0x00000020	/* Entry is writable */
#define	APPLE_PS_BOOT_CODE_PIC	0x00000040	/* Boot code has position
						 * independent code */
#define	APPLE_PS_CC_DRVR	0x00000100	/* Partition contains chain-
						 * compatible driver */
#define	APPLE_PS_RL_DRVR	0x00000200	/* Partition contains real
						 * driver */
#define	APPLE_PS_CH_DRVR	0x00000400	/* Partition contains chain
						 * driver */
#define	APPLE_PS_AUTO_MOUNT	0x40000000	/* Mount automatically at
						 * startup */
#define	APPLE_PS_STARTUP	0x80000000	/* Is the startup partition */
	uint32_t	pmLgBootStart;	/* first logical block of boot code */
	uint32_t	pmBootSize;	/* size of boot code, in bytes */
	uint32_t	pmBootLoad;	/* boot code load address */
	uint32_t	pmBootLoad2;	/* (reserved) */
	uint32_t	pmBootEntry;	/* boot code entry point */
	uint32_t	pmBootEntry2;	/* (reserved) */
	uint32_t	pmBootCksum;	/* boot code checksum */
	int8_t		pmProcessor[16]; /* processor type (e.g. "68020") */
	uint8_t		pmBootArgs[128]; /* A/UX boot arguments */
	uint8_t		pad[248];	/* pad to end of block */
};

#define	APPLE_PART_TYPE_DRIVER		"APPLE_DRIVER"
#define	APPLE_PART_TYPE_DRIVER43	"APPLE_DRIVER43"
#define	APPLE_PART_TYPE_DRIVERATA	"APPLE_DRIVER_ATA"
#define	APPLE_PART_TYPE_DRIVERIOKIT	"APPLE_DRIVER_IOKIT"
#define	APPLE_PART_TYPE_FWDRIVER	"APPLE_FWDRIVER"
#define	APPLE_PART_TYPE_FWB_COMPONENT	"FWB DRIVER COMPONENTS"
#define	APPLE_PART_TYPE_FREE		"APPLE_FREE"
#define	APPLE_PART_TYPE_MAC		"APPLE_HFS"
#define	APPLE_PART_TYPE_NETBSD		"NETBSD"
#define	APPLE_PART_TYPE_NBSD_PPCBOOT	"NETBSD/MACPPC"
#define	APPLE_PART_TYPE_NBSD_68KBOOT	"NETBSD/MAC68K"
#define	APPLE_PART_TYPE_PATCHES		"APPLE_PATCHES"
#define	APPLE_PART_TYPE_PARTMAP		"APPLE_PARTITION_MAP"
#define	APPLE_PART_TYPE_PATCHES		"APPLE_PATCHES"
#define	APPLE_PART_TYPE_SCRATCH		"APPLE_SCRATCH"
#define	APPLE_PART_TYPE_UNIX		"APPLE_UNIX_SVR2"

/*
 * "pmBootArgs" for APPLE_UNIX_SVR2 partition.
 * NetBSD/mac68k only uses Magic, Cluster, Type, and Flags.
 */
struct apple_blockzeroblock {
	uint32_t       bzbMagic;
	uint8_t        bzbCluster;
	uint8_t        bzbType;
	uint16_t       bzbBadBlockInode;
	uint16_t       bzbFlags;
	uint16_t       bzbReserved;
	uint32_t       bzbCreationTime;
	uint32_t       bzbMountTime;
	uint32_t       bzbUMountTime;
};

#define	APPLE_BZB_MAGIC		0xABADBABE
#define	APPLE_BZB_TYPEFS	1
#define	APPLE_BZB_TYPESWAP	3
#define	APPLE_BZB_ROOTFS	0x8000
#define	APPLE_BZB_USRFS		0x4000

/* ------------------------------------------
 * ews4800mips
 *
 */

#define	EWS4800MIPS_BBINFO_MAGIC		"NetBSD/ews4800mips     20040611"
#define	EWS4800MIPS_BOOT_BLOCK_OFFSET		0
#define	EWS4800MIPS_BOOT_BLOCK_BLOCKSIZE	512
#define	EWS4800MIPS_BOOT_BLOCK_MAX_SIZE		(512 * 8)

/* ------------------------------------------
 * hp300
 *
 */

/* volume header for "LIF" format volumes */

struct	hp300_lifvol {
	uint16_t	vol_id;
	char		vol_label[6];
	uint32_t	vol_addr;
	uint16_t	vol_oct;
	uint16_t	vol_dummy;
	uint32_t	vol_dirsize;
	uint16_t	vol_version;
	uint16_t	vol_zero;
	uint32_t	vol_huh1;
	uint32_t	vol_huh2;
	uint32_t	vol_length;
};

/* LIF directory entry format */

struct	hp300_lifdir {
	char		dir_name[10];
	uint16_t	dir_type;
	uint32_t	dir_addr;
	uint32_t	dir_length;
	char		dir_toc[6];
	uint16_t	dir_flag;
	uint32_t	dir_exec;
};

/* load header for boot rom */
struct hp300_load {
	uint32_t	address;
	uint32_t	count;
};

#define	HP300_VOL_ID		0x8000	/* always $8000 */
#define	HP300_VOL_OCT		4096
#define	HP300_DIR_TYPE		0xe942	/* "SYS9k Series 9000" */
#define	HP300_DIR_FLAG		0x8001	/* don't ask me! */
#define	HP300_SECTSIZE		256


/* ------------------------------------------
 * hppa
 *
 */

/*
 * volume header for "LIF" format volumes
 */
struct	hppa_lifvol {
	uint16_t	vol_id;
	uint8_t		vol_label[6];
	uint32_t	vol_addr;
	uint16_t	vol_oct;
	uint16_t	vol_dummy;

	uint32_t	vol_dirsize;
	uint16_t	vol_version;
	uint16_t	vol_zero;
	uint32_t	vol_number;
	uint32_t	vol_lastvol;

	uint32_t	vol_length;
	uint8_t		vol_toc[6];
	uint8_t		vol_dummy1[198];

	uint32_t	ipl_addr;
	uint32_t	ipl_size;
	uint32_t	ipl_entry;

	uint32_t	vol_dummy2;
};

struct	hppa_lifdir {
	uint8_t		dir_name[10];
	uint16_t	dir_type;
	uint32_t	dir_addr;
	uint32_t	dir_length;
	uint8_t		dir_toc[6];
	uint16_t	dir_flag;
	uint32_t	dir_implement;
};

struct hppa_lifload {
	int address;
	int count;
};

#define	HPPA_LIF_VOL_ID	0x8000
#define	HPPA_LIF_VOL_OCT	0x1000
#define	HPPA_LIF_DIR_SWAP	0x5243
#define	HPPA_LIF_DIR_FS	0xcd38
#define	HPPA_LIF_DIR_IOMAP	0xcd60
#define	HPPA_LIF_DIR_HPUX	0xcd80
#define	HPPA_LIF_DIR_ISL	0xce00
#define	HPPA_LIF_DIR_PAD	0xcffe
#define	HPPA_LIF_DIR_AUTO	0xcfff
#define	HPPA_LIF_DIR_EST	0xd001
#define	HPPA_LIF_DIR_TYPE	0xe942

#define	HPPA_LIF_DIR_FLAG	0x8001	/* dont ask me! */
#define	HPPA_LIF_SECTSIZE	256

#define	HPPA_LIF_NUMDIR	8

#define	HPPA_LIF_VOLSTART	0
#define	HPPA_LIF_VOLSIZE	sizeof(struct hppa_lifvol)
#define	HPPA_LIF_DIRSTART	2048
#define	HPPA_LIF_DIRSIZE	(HPPA_LIF_NUMDIR * sizeof(struct hppa_lifdir))
#define	HPPA_LIF_FILESTART	4096

#define	hppa_btolifs(b)	(((b) + (HPPA_LIF_SECTSIZE - 1)) / HPPA_LIF_SECTSIZE)
#define	hppa_lifstob(s)	((s) * HPPA_LIF_SECTSIZE)
#define	hppa_lifstodb(s)	((s) * HPPA_LIF_SECTSIZE / DEV_BSIZE)


/* ------------------------------------------
 * x86
 *
 */

/*
 * Parameters for NetBSD /boot written to start of pbr code by installboot
 */

struct x86_boot_params {
	uint32_t	bp_length;	/* length of patchable data */
	uint32_t	bp_flags;
	uint32_t	bp_timeout;	/* boot timeout in seconds */
	uint32_t	bp_consdev;
	uint32_t	bp_conspeed;
	uint8_t		bp_password[16];	/* md5 hash of password */
	char		bp_keymap[64];	/* keyboard translation map */
	uint32_t	bp_consaddr;	/* ioaddr for console */
};

#endif	/* !defined(__ASSEMBLER__) */				/* } */

#define	X86_BOOT_MAGIC(n)	('x' << 24 | 0x86b << 12 | 'm' << 4 | (n))
#define	X86_BOOT_MAGIC_1	X86_BOOT_MAGIC(1)	/* pbr.S */
#define	X86_BOOT_MAGIC_2	X86_BOOT_MAGIC(2)	/* bootxx.S */
#define	X86_BOOT_MAGIC_PXE	X86_BOOT_MAGIC(3)	/* start_pxe.S */
#define	X86_BOOT_MAGIC_FAT	X86_BOOT_MAGIC(4)	/* fatboot.S */
#define	X86_BOOT_MAGIC_EFI	X86_BOOT_MAGIC(5)	/* efiboot/start.S */
#define	X86_MBR_GPT_MAGIC	0xedb88320		/* gpt.S */

		/* values for bp_flags */
#define	X86_BP_FLAGS_RESET_VIDEO	1
#define	X86_BP_FLAGS_PASSWORD		2
#define	X86_BP_FLAGS_NOMODULES		4
#define	X86_BP_FLAGS_NOBOOTCONF		8
#define	X86_BP_FLAGS_LBA64VALID		0x10

		/* values for bp_consdev */
#define	X86_BP_CONSDEV_PC	0
#define	X86_BP_CONSDEV_COM0	1
#define	X86_BP_CONSDEV_COM1	2
#define	X86_BP_CONSDEV_COM2	3
#define	X86_BP_CONSDEV_COM3	4
#define	X86_BP_CONSDEV_COM0KBD	5
#define	X86_BP_CONSDEV_COM1KBD	6
#define	X86_BP_CONSDEV_COM2KBD	7
#define	X86_BP_CONSDEV_COM3KBD	8

/* ------------------------------------------
 * landisk
 */

#if !defined(__ASSEMBLER__)					/* { */

/*
 * Parameters for NetBSD /boot written to start of pbr code by installboot
 */
struct landisk_boot_params {
	uint32_t	bp_length;	/* length of patchable data */
	uint32_t	bp_flags;
	uint32_t	bp_timeout;	/* boot timeout in seconds */
	uint32_t	bp_consdev;
	uint32_t	bp_conspeed;
};

#endif	/* !defined(__ASSEMBLER__) */				/* } */

#define	LANDISK_BOOT_MAGIC_1	0x20031125
#define	LANDISK_BOOT_MAGIC_2	0x20041110

#if !defined(__ASSEMBLER__)					/* { */

/* ------------------------------------------
 * macppc
 */

#define	MACPPC_BOOT_BLOCK_OFFSET	2048
#define	MACPPC_BOOT_BLOCK_BLOCKSIZE	512
#define	MACPPC_BOOT_BLOCK_MAX_SIZE	2048	/* XXX: could be up to 6144 */
	/* Magic string -- 32 bytes long (including the NUL) */
#define	MACPPC_BBINFO_MAGIC		"NetBSD/macppc bootxx   20020515"

/* ------------------------------------------
 * news68k, newsmips
 */

#define	NEWS_BOOT_BLOCK_LABELOFFSET	64 /* XXX from <machine/disklabel.h> */
#define	NEWS_BOOT_BLOCK_OFFSET		0
#define	NEWS_BOOT_BLOCK_BLOCKSIZE	512
#define	NEWS_BOOT_BLOCK_MAX_SIZE	(512 * 16)

	/* Magic string -- 32 bytes long (including the NUL) */
#define	NEWS68K_BBINFO_MAGIC		"NetBSD/news68k bootxx  20020518"
#define	NEWSMIPS_BBINFO_MAGIC		"NetBSD/newsmips bootxx 20020518"

/* ------------------------------------------
 * next68k
 */

#define	NEXT68K_LABEL_MAXPARTITIONS	8	/* number of partitions in next68k_disklabel */
#define	NEXT68K_LABEL_CPULBLLEN		24
#define	NEXT68K_LABEL_MAXDNMLEN		24
#define	NEXT68K_LABEL_MAXTYPLEN		24
#define	NEXT68K_LABEL_MAXBFLEN		24
#define	NEXT68K_LABEL_MAXHNLEN		32
#define	NEXT68K_LABEL_MAXMPTLEN		16
#define	NEXT68K_LABEL_MAXFSTLEN		8
#define	NEXT68K_LABEL_NBAD		1670	/* sized to make label ~= 8KB */

struct next68k_partition {
	int32_t	cp_offset;		/* starting sector */
	int32_t	cp_size;		/* number of sectors in partition */
	int16_t	cp_bsize;		/* block size in bytes */
	int16_t	cp_fsize;		/* filesystem basic fragment size */
	char	cp_opt;			/* optimization type: 's'pace/'t'ime */
	char	cp_pad1;
	int16_t	cp_cpg;			/* filesystem cylinders per group */
	int16_t	cp_density;		/* bytes per inode density */
	int8_t	cp_minfree;		/* minfree (%) */
	int8_t	cp_newfs;		/* run newfs during init */
	char	cp_mountpt[NEXT68K_LABEL_MAXMPTLEN];
					/* default/standard mount point */
	int8_t	cp_automnt;		/* auto-mount when inserted */
	char	cp_type[NEXT68K_LABEL_MAXFSTLEN]; /* file system type name */
	char	cp_pad2;
} __packed;

/* The disklabel the way it is on the disk */
struct next68k_disklabel {
	int32_t	cd_version;		/* label version */
	int32_t	cd_label_blkno;		/* block # of this label */
	int32_t	cd_size;		/* size of media area (sectors) */
	char	cd_label[NEXT68K_LABEL_CPULBLLEN]; /* disk name (label) */
	uint32_t cd_flags;		/* flags */
	uint32_t cd_tag;		/* volume tag */
	char	cd_name[NEXT68K_LABEL_MAXDNMLEN]; /* drive (hardware) name */
	char	cd_type[NEXT68K_LABEL_MAXTYPLEN]; /* drive type */
	int32_t	cd_secsize;		/* # of bytes per sector */
	int32_t	cd_ntracks;		/* # of tracks per cylinder */
	int32_t	cd_nsectors;		/* # of data sectors per track */
	int32_t	cd_ncylinders;		/* # of data cylinders per unit */
	int32_t	cd_rpm;			/* rotational speed */
	int16_t	cd_front;		/* # of sectors in "front porch" */
	int16_t	cd_back;		/* # of sectors in "back porch" */
	int16_t	cd_ngroups;		/* # of alt groups */
	int16_t	cd_ag_size;		/* alt group size (sectors) */
	int16_t	cd_ag_alts;		/* alternate sectors / alt group */
	int16_t	cd_ag_off;		/* sector offset to first alternate */
	int32_t	cd_boot_blkno[2];	/* boot program locations */
	char	cd_kernel[NEXT68K_LABEL_MAXBFLEN]; /* default kernel name */
	char	cd_hostname[NEXT68K_LABEL_MAXHNLEN];
				/* host name (usu. where disk was labeled) */
	char	cd_rootpartition;	/* root partition letter e.g. 'a' */
	char	cd_rwpartition;		/* r/w partition letter e.g. 'b' */
	struct next68k_partition cd_partitions[NEXT68K_LABEL_MAXPARTITIONS];

	union {
		uint16_t CD_v3_checksum; /* label version 3 checksum */
		int32_t	CD_bad[NEXT68K_LABEL_NBAD];
					/* block number that is bad */
	} cd_un;
	uint16_t cd_checksum;		/* label version 1 or 2 checksum */
} __packed;

#define	NEXT68K_LABEL_cd_checksum	cd_checksum
#define	NEXT68K_LABEL_cd_v3_checksum	cd_un.CD_v3_checksum
#define	NEXT68K_LABEL_cd_bad		cd_un.CD_bad

#define	NEXT68K_LABEL_SECTOR		0	/* sector containing label */
#define	NEXT68K_LABEL_OFFSET		0	/* offset of label in sector */
#define	NEXT68K_LABEL_SIZE		8192	/* size of label */
#define	NEXT68K_LABEL_CD_V1		0x4e655854 /* version #1: "NeXT" */
#define	NEXT68K_LABEL_CD_V2		0x646c5632 /* version #2: "dlV2" */
#define	NEXT68K_LABEL_CD_V3		0x646c5633 /* version #3: "dlV3" */
#define	NEXT68K_LABEL_DEFAULTFRONTPORCH	(160 * 2)
#define	NEXT68K_LABEL_DEFAULTBOOT0_1	(32 * 2)
#define	NEXT68K_LABEL_DEFAULTBOOT0_2	(96 * 2)

/* ------------------------------------------
 * pmax --
 *	PMAX (DECstation / MIPS) boot block information
 */

/*
 * If mode is 0, there is just one sequence of blocks and one Dec_BootMap
 * is used.  If mode is 1, there are multiple sequences of blocks
 * and multiple Dec_BootMaps are used, the last with numBlocks = 0.
 */
struct pmax_boot_map {
	int32_t	num_blocks;		/* Number of blocks to read. */
	int32_t	start_block;		/* Starting block on disk. */
};

/*
 * This is the structure of a disk or tape boot block.  The boot_map
 * can either be a single boot count and start block (contiguous mode)
 * or a list of up to 61 (to fill a 512 byte sector) block count and
 * start block pairs.  Under NetBSD, contiguous mode is always used.
 */
struct pmax_boot_block {
	uint8_t		pad[8];
	int32_t		magic;			/* PMAX_BOOT_MAGIC */
	int32_t		mode;			/* Mode for boot info. */
	uint32_t	load_addr;		/* Address to start loading. */
	uint32_t	exec_addr;		/* Address to start execing. */
	struct		pmax_boot_map map[61];	/* boot program section(s). */
} __packed;

#define	PMAX_BOOT_MAGIC			0x0002757a
#define	PMAX_BOOTMODE_CONTIGUOUS	0
#define	PMAX_BOOTMODE_SCATTERED		1

#define	PMAX_BOOT_BLOCK_OFFSET		0
#define	PMAX_BOOT_BLOCK_BLOCKSIZE	512


/* ------------------------------------------
 * sgimips
 */

/*
 * Some IRIX man pages refer to the size being a multiple of whole cylinders.
 * Later ones only refer to the size being "typically" 2MB.  IRIX fx(1)
 * uses a default drive geometry if one can't be determined, suggesting
 * that "whole cylinder" multiples are not required.
 */

#define SGI_BOOT_BLOCK_SIZE_VOLHDR	3135
#define SGI_BOOT_BLOCK_MAGIC		0xbe5a941
#define SGI_BOOT_BLOCK_MAXPARTITIONS	16
#define SGI_BOOT_BLOCK_MAXVOLDIRS	15
#define SGI_BOOT_BLOCK_BLOCKSIZE	512

/*
 * SGI partition conventions:
 *
 * Partition 0 - root
 * Partition 1 - swap
 * Partition 6 - usr
 * Partition 7 - volume body
 * Partition 8 - volume header
 * Partition 10 - whole disk
 */

struct sgi_boot_devparms {
	uint8_t		dp_skew;
	uint8_t		dp_gap1;
	uint8_t		dp_gap2;
	uint8_t		dp_spares_cyl;
	uint16_t	dp_cyls;
	uint16_t	dp_shd0;
	uint16_t	dp_trks0;
	uint8_t		dp_ctq_depth;
	uint8_t		dp_cylshi;
	uint16_t	dp_unused;
	uint16_t	dp_secs;
	uint16_t	dp_secbytes;
	uint16_t	dp_interleave;
	uint32_t	dp_flags;
	uint32_t	dp_datarate;
	uint32_t	dp_nretries;
	uint32_t	dp_mspw;
	uint16_t	dp_xgap1;
	uint16_t	dp_xsync;
	uint16_t	dp_xrdly;
	uint16_t	dp_xgap2;
	uint16_t	dp_xrgate;
	uint16_t	dp_xwcont;
} __packed;

struct sgi_boot_block {
	uint32_t	magic;
	int16_t		root;
	int16_t		swap;
	char		bootfile[16];
	struct sgi_boot_devparms dp;
	struct {
		char		name[8];
		int32_t		block;
		int32_t		bytes;
	}		voldir[SGI_BOOT_BLOCK_MAXVOLDIRS];
	struct {
		int32_t		blocks;
		int32_t		first;
		int32_t		type;
	}		partitions[SGI_BOOT_BLOCK_MAXPARTITIONS];
	int32_t		checksum;
	int32_t		_pad;
} __packed;

#define SGI_PTYPE_VOLHDR	0
#define SGI_PTYPE_TRKREPL	1
#define SGI_PTYPE_SECREPL	2
#define SGI_PTYPE_RAW		3
#define SGI_PTYPE_BSD		4
#define SGI_PTYPE_SYSV		5
#define SGI_PTYPE_VOLUME	6
#define SGI_PTYPE_EFS		7
#define SGI_PTYPE_LVOL		8
#define SGI_PTYPE_RLVOL		9
#define SGI_PTYPE_XFS		10
#define SGI_PTYPE_XFSLOG	11
#define SGI_PTYPE_XLV		12
#define SGI_PTYPE_XVM		13

/* ------------------------------------------
 * sparc
 */

#define	SPARC_BOOT_BLOCK_OFFSET		512
#define	SPARC_BOOT_BLOCK_BLOCKSIZE	512
#define	SPARC_BOOT_BLOCK_MAX_SIZE	(512 * 15)
	/* Magic string -- 32 bytes long (including the NUL) */
#define	SPARC_BBINFO_MAGIC		"NetBSD/sparc bootxx    20020515"


/* ------------------------------------------
 * sparc64
 */

#define	SPARC64_BOOT_BLOCK_OFFSET	512
#define	SPARC64_BOOT_BLOCK_BLOCKSIZE	512
#define	SPARC64_BOOT_BLOCK_MAX_SIZE	(512 * 15)


/* ------------------------------------------
 * sun68k (sun2, sun3)
 */

#define	SUN68K_BOOT_BLOCK_OFFSET	512
#define	SUN68K_BOOT_BLOCK_BLOCKSIZE	512
#define	SUN68K_BOOT_BLOCK_MAX_SIZE	(512 * 15)
	/* Magic string -- 32 bytes long (including the NUL) */
#define	SUN68K_BBINFO_MAGIC		"NetBSD/sun68k bootxx   20020515"


/* ------------------------------------------
 * vax --
 *	VAX boot block information
 */

struct vax_boot_block {
/* Note that these don't overlap any of the pmax boot block */
	uint8_t		pad0[2];
	uint8_t		bb_id_offset;	/* offset in words to id (magic1)*/
	uint8_t		bb_mbone;	/* must be one */
	uint16_t	bb_lbn_hi;	/* lbn (hi word) of bootstrap */
	uint16_t	bb_lbn_low;	/* lbn (low word) of bootstrap */
	uint8_t		pad1[406];
	/* disklabel offset is 64 from base, or 56 from start of pad1 */

	/* The rest of these fields are identification area and describe
	 * the secondary block for uVAX VMB.
	 */
	uint8_t		bb_magic1;	/* magic number */
	uint8_t		bb_mbz1;	/* must be zero */
	uint8_t		bb_pad1;	/* any value */
	uint8_t		bb_sum1;	/* ~(magic1 + mbz1 + pad1) */

	uint8_t		bb_mbz2;	/* must be zero */
	uint8_t		bb_volinfo;	/* volinfo */
	uint8_t		bb_pad2a;	/* any value */
	uint8_t		bb_pad2b;	/* any value */

	uint32_t	bb_size;	/* size in blocks of bootstrap */
	uint32_t	bb_load;	/* load offset to bootstrap */
	uint32_t	bb_entry;	/* byte offset in bootstrap */
	uint32_t	bb_sum3;	/* sum of previous 3 fields */

	/* The rest is unused.
	 */
	uint8_t		pad2[74];
} __packed;

#define	VAX_BOOT_MAGIC1			0x18	/* size of BB info? */
#define	VAX_BOOT_VOLINFO_NONE		0x00	/* no special info */
#define	VAX_BOOT_VOLINFO_SS		0x01	/* single sided */
#define	VAX_BOOT_VOLINFO_DS		0x81	/* double sided */

#define	VAX_BOOT_SIZE			15	/* 15 blocks */
#define	VAX_BOOT_LOAD			0	/* no load offset */
#define	VAX_BOOT_ENTRY			0x200	/* one block in */

#define	VAX_BOOT_BLOCK_OFFSET		0
#define	VAX_BOOT_BLOCK_BLOCKSIZE	512


/* ------------------------------------------
 * x68k
 */

#define	X68K_BOOT_BLOCK_OFFSET		0
#define	X68K_BOOT_BLOCK_BLOCKSIZE	512
#define	X68K_BOOT_BLOCK_MAX_SIZE	(512 * 16)
	/* Magic string -- 32 bytes long (including the NUL) */
#define	X68K_BBINFO_MAGIC		"NetBSD/x68k bootxx     20020601"

#endif	/* !defined(__ASSEMBLER__) */				/* } */

#endif	/* !_SYS_BOOTBLOCK_H */