/*-
 * Copyright (c) 2004 Marcel Moolenaar
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
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

#ifndef _SYS_EFI_H_
#define _SYS_EFI_H_

#include <sys/uuid.h>
#include <machine/efi.h>

#define	EFI_PAGE_SHIFT		12
#define	EFI_PAGE_SIZE		(1 << EFI_PAGE_SHIFT)
#define	EFI_PAGE_MASK		(EFI_PAGE_SIZE - 1)

#define	EFI_TABLE_SMBIOS				\
	{0xeb9d2d31,0x2d88,0x11d3,0x9a,0x16,{0x00,0x90,0x27,0x3f,0xc1,0x4d}}
#define	EFI_TABLE_SMBIOS3				\
	{0xf2fd1544,0x9794,0x4a2c,0x99,0x2e,{0xe5,0xbb,0xcf,0x20,0xe3,0x94}}
#define	EFI_TABLE_ESRT					\
	{0xb122a263,0x3661,0x4f68,0x99,0x29,{0x78,0xf8,0xb0,0xd6,0x21,0x80}}
#define	EFI_PROPERTIES_TABLE			\
	{0x880aaca3,0x4adc,0x4a04,0x90,0x79,{0xb7,0x47,0x34,0x08,0x25,0xe5}}
#define LINUX_EFI_MEMRESERVE_TABLE			\
	{0x888eb0c6,0x8ede,0x4ff5,0xa8,0xf0,{0x9a,0xee,0x5c,0xb9,0x77,0xc2}}

enum efi_reset {
	EFI_RESET_COLD = 0,
	EFI_RESET_WARM = 1,
	EFI_RESET_SHUTDOWN = 2,
};

typedef uint16_t	efi_char;
typedef unsigned long efi_status;

struct efi_cfgtbl {
	struct uuid	ct_uuid;
	void		*ct_data;
};

#define EFI_MEMORY_DESCRIPTOR_VERSION 1

struct efi_md {
	uint32_t	md_type;
#define	EFI_MD_TYPE_NULL	0
#define	EFI_MD_TYPE_CODE	1	/* Loader text. */
#define	EFI_MD_TYPE_DATA	2	/* Loader data. */
#define	EFI_MD_TYPE_BS_CODE	3	/* Boot services text. */
#define	EFI_MD_TYPE_BS_DATA	4	/* Boot services data. */
#define	EFI_MD_TYPE_RT_CODE	5	/* Runtime services text. */
#define	EFI_MD_TYPE_RT_DATA	6	/* Runtime services data. */
#define	EFI_MD_TYPE_FREE	7	/* Unused/free memory. */
#define	EFI_MD_TYPE_BAD		8	/* Bad memory */
#define	EFI_MD_TYPE_RECLAIM	9	/* ACPI reclaimable memory. */
#define	EFI_MD_TYPE_FIRMWARE	10	/* ACPI NV memory */
#define	EFI_MD_TYPE_IOMEM	11	/* Memory-mapped I/O. */
#define	EFI_MD_TYPE_IOPORT	12	/* I/O port space. */
#define	EFI_MD_TYPE_PALCODE	13	/* PAL */
#define	EFI_MD_TYPE_PERSISTENT	14	/* Persistent memory. */
	uint32_t	__pad;
	uint64_t	md_phys;
	uint64_t	md_virt;
	uint64_t	md_pages;
	uint64_t	md_attr;
#define	EFI_MD_ATTR_UC		0x0000000000000001UL
#define	EFI_MD_ATTR_WC		0x0000000000000002UL
#define	EFI_MD_ATTR_WT		0x0000000000000004UL
#define	EFI_MD_ATTR_WB		0x0000000000000008UL
#define	EFI_MD_ATTR_UCE		0x0000000000000010UL
#define	EFI_MD_ATTR_WP		0x0000000000001000UL
#define	EFI_MD_ATTR_RP		0x0000000000002000UL
#define	EFI_MD_ATTR_XP		0x0000000000004000UL
#define	EFI_MD_ATTR_NV		0x0000000000008000UL
#define	EFI_MD_ATTR_MORE_RELIABLE \
				0x0000000000010000UL
#define	EFI_MD_ATTR_RO		0x0000000000020000UL
#define	EFI_MD_ATTR_RT		0x8000000000000000UL
};

#define efi_next_descriptor(ptr, size) \
    ((struct efi_md *)(((uint8_t *)(ptr)) + (size)))

struct efi_tm {
	uint16_t	tm_year;		/* 1998 - 20XX */
	uint8_t		tm_mon;			/* 1 - 12 */
	uint8_t		tm_mday;		/* 1 - 31 */
	uint8_t		tm_hour;		/* 0 - 23 */
	uint8_t		tm_min;			/* 0 - 59 */
	uint8_t		tm_sec;			/* 0 - 59 */
	uint8_t		__pad1;
	uint32_t	tm_nsec;		/* 0 - 999,999,999 */
	int16_t		tm_tz;			/* -1440 to 1440 or 2047 */
	uint8_t		tm_dst;
	uint8_t		__pad2;
};

struct efi_tmcap {
	uint32_t	tc_res;		/* 1e-6 parts per million */
	uint32_t	tc_prec;	/* hertz */
	uint8_t		tc_stz;		/* Set clears sub-second time */
};

struct efi_tblhdr {
	uint64_t	th_sig;
	uint32_t	th_rev;
	uint32_t	th_hdrsz;
	uint32_t	th_crc32;
	uint32_t	__res;
};

#define ESRT_FIRMWARE_RESOURCE_VERSION 1

struct efi_esrt_table {
	uint32_t	fw_resource_count;
	uint32_t	fw_resource_count_max;
	uint64_t	fw_resource_version;
	uint8_t		entries[];
};

struct efi_esrt_entry_v1 {
	struct uuid	fw_class;
	uint32_t 	fw_type;
	uint32_t	fw_version;
	uint32_t	lowest_supported_fw_version;
	uint32_t	capsule_flags;
	uint32_t	last_attempt_version;
	uint32_t	last_attempt_status;
};

struct efi_prop_table {
	uint32_t	version;
	uint32_t	length;
	uint64_t	memory_protection_attribute;
};

#ifdef _KERNEL

#ifdef EFIABI_ATTR
struct efi_rt {
	struct efi_tblhdr rt_hdr;
	efi_status	(*rt_gettime)(struct efi_tm *, struct efi_tmcap *)
	    EFIABI_ATTR;
	efi_status	(*rt_settime)(struct efi_tm *) EFIABI_ATTR;
	efi_status	(*rt_getwaketime)(uint8_t *, uint8_t *,
	    struct efi_tm *) EFIABI_ATTR;
	efi_status	(*rt_setwaketime)(uint8_t, struct efi_tm *)
	    EFIABI_ATTR;
	efi_status	(*rt_setvirtual)(u_long, u_long, uint32_t,
	    struct efi_md *) EFIABI_ATTR;
	efi_status	(*rt_cvtptr)(u_long, void **) EFIABI_ATTR;
	efi_status	(*rt_getvar)(efi_char *, struct uuid *, uint32_t *,
	    u_long *, void *) EFIABI_ATTR;
	efi_status	(*rt_scanvar)(u_long *, efi_char *, struct uuid *)
	    EFIABI_ATTR;
	efi_status	(*rt_setvar)(efi_char *, struct uuid *, uint32_t,
	    u_long, void *) EFIABI_ATTR;
	efi_status	(*rt_gethicnt)(uint32_t *) EFIABI_ATTR;
	efi_status	(*rt_reset)(enum efi_reset, efi_status, u_long,
	    efi_char *) EFIABI_ATTR;
};
#endif

struct efi_systbl {
	struct efi_tblhdr st_hdr;
#define	EFI_SYSTBL_SIG	0x5453595320494249UL
	efi_char	*st_fwvendor;
	uint32_t	st_fwrev;
	uint32_t	__pad;
	void		*st_cin;
	void		*st_cinif;
	void		*st_cout;
	void		*st_coutif;
	void		*st_cerr;
	void		*st_cerrif;
	uint64_t	st_rt;
	void		*st_bs;
	u_long		st_entries;
	uint64_t	st_cfgtbl;
};

extern vm_paddr_t efi_systbl_phys;

/*
 * When memory is reserved for some use, Linux will add a
 * LINUX_EFI_MEMSERVE_TABLE to the cfgtbl array of tables to communicate
 * this. At present, Linux only uses this as part of its workaround for a GICv3
 * issue where you can't stop the controller long enough to move it's config and
 * pending vectors. When the LinuxBoot environment kexec's a new kernel, the new
 * kernel needs to use this old memory (and not use it for any other purpose).
 *
 * Linux stores the PA of this table in the cfgtbl. And all the addresses are
 * the physical address of 'reserved' memory. The mr_next field creates a linked
 * list of these tables, and all must be walked. If mr_count is 0, that entry
 * should be ignored. There is no checksum for these tables, nor do they have
 * a efi_tblhdr.
 *
 * This table is only documented in the Linux code in drivers/firmware/efi/efi.c.
 */
struct linux_efi_memreserve_entry {
	vm_offset_t	mre_base;	/* PA of reserved area */
	vm_offset_t	mre_size;	/* Size of area */
};

struct linux_efi_memreserve {
	uint32_t	mr_size;	/* Total size of table in bytes */
	uint32_t	mr_count;	/* Count of entries used */
	vm_offset_t	mr_next;	/* Next in chain (though unused?) */
	struct linux_efi_memreserve_entry mr_entry[];
};

struct efirt_callinfo;

/* Internal MD EFI functions */
int efi_arch_enter(void);
void efi_arch_leave(void);
vm_offset_t efi_phys_to_kva(vm_paddr_t);
int efi_rt_arch_call(struct efirt_callinfo *);
bool efi_create_1t1_map(struct efi_md *, int, int);
void efi_destroy_1t1_map(void);

struct efi_ops {
	/*
	 * The EFI calls might be virtualized in some environments, requiring
	 * FreeBSD to use a different interface (ie: hypercalls) in order to
	 * access them.
	 */
	int	(*rt_ok)(void);
	int 	(*get_table)(struct uuid *, void **);
	int 	(*copy_table)(struct uuid *, void **, size_t, size_t *);
	int 	(*get_time)(struct efi_tm *);
	int 	(*get_time_capabilities)(struct efi_tmcap *);
	int	(*reset_system)(enum efi_reset);
	int 	(*set_time)(struct efi_tm *);
	int 	(*get_waketime)(uint8_t *enabled, uint8_t *pending,
	    struct efi_tm *tm);
	int 	(*set_waketime)(uint8_t enable, struct efi_tm *tm);
	int 	(*var_get)(uint16_t *, struct uuid *, uint32_t *, size_t *,
    void *);
	int 	(*var_nextname)(size_t *, uint16_t *, struct uuid *);
	int 	(*var_set)(uint16_t *, struct uuid *, uint32_t, size_t, void *);
};
extern const struct efi_ops *active_efi_ops;

/* Public MI EFI functions */
static inline int efi_rt_ok(void)
{

	if (active_efi_ops->rt_ok == NULL)
		return (ENXIO);
	return (active_efi_ops->rt_ok());
}

static inline int efi_get_table(struct uuid *uuid, void **ptr)
{

        if (active_efi_ops->get_table == NULL)
		return (ENXIO);
	return (active_efi_ops->get_table(uuid, ptr));
}

static inline int efi_copy_table(struct uuid *uuid, void **buf,
    size_t buf_len, size_t *table_len)
{

	if (active_efi_ops->copy_table == NULL)
		return (ENXIO);
	return (active_efi_ops->copy_table(uuid, buf, buf_len, table_len));
}

static inline int efi_get_time(struct efi_tm *tm)
{

	if (active_efi_ops->get_time == NULL)
		return (ENXIO);
	return (active_efi_ops->get_time(tm));
}

static inline int efi_get_time_capabilities(struct efi_tmcap *tmcap)
{

	if (active_efi_ops->get_time_capabilities == NULL)
		return (ENXIO);
	return (active_efi_ops->get_time_capabilities(tmcap));
}

static inline int efi_reset_system(enum efi_reset type)
{

	if (active_efi_ops->reset_system == NULL)
		return (ENXIO);
	return (active_efi_ops->reset_system(type));
}

static inline int efi_set_time(struct efi_tm *tm)
{

	if (active_efi_ops->set_time == NULL)
		return (ENXIO);
	return (active_efi_ops->set_time(tm));
}

static inline int efi_get_waketime(uint8_t *enabled, uint8_t *pending,
    struct efi_tm *tm)
{
	if (active_efi_ops->get_waketime == NULL)
		return (ENXIO);
	return (active_efi_ops->get_waketime(enabled, pending, tm));
}

static inline int efi_set_waketime(uint8_t enable, struct efi_tm *tm)
{
	if (active_efi_ops->set_waketime == NULL)
		return (ENXIO);
	return (active_efi_ops->set_waketime(enable, tm));
}

static inline int efi_var_get(uint16_t *name, struct uuid *vendor,
    uint32_t *attrib, size_t *datasize, void *data)
{

	if (active_efi_ops->var_get == NULL)
		return (ENXIO);
	return (active_efi_ops->var_get(name, vendor, attrib, datasize, data));
}

static inline int efi_var_nextname(size_t *namesize, uint16_t *name,
    struct uuid *vendor)
{

	if (active_efi_ops->var_nextname == NULL)
		return (ENXIO);
	return (active_efi_ops->var_nextname(namesize, name, vendor));
}

static inline int efi_var_set(uint16_t *name, struct uuid *vendor,
    uint32_t attrib, size_t datasize, void *data)
{

	if (active_efi_ops->var_set == NULL)
		return (ENXIO);
	return (active_efi_ops->var_set(name, vendor, attrib, datasize, data));
}

int efi_status_to_errno(efi_status status);

#endif	/* _KERNEL */

#endif /* _SYS_EFI_H_ */