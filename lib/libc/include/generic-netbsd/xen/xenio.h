/*	$NetBSD: xenio.h,v 1.12 2020/05/26 10:11:56 bouyer Exp $	*/

/******************************************************************************
 * privcmd.h
 * 
 * Copyright (c) 2003-2004, K A Fraser
 * 
 * This file may be distributed separately from the Linux kernel, or
 * incorporated into other software packages, subject to the following license:
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this source file (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy, modify,
 * merge, publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

#ifndef __XEN_XENIO_H__
#define __XEN_XENIO_H__

/* Interface to /proc/xen/privcmd */

#include <sys/ioccom.h>


typedef struct privcmd_hypercall
{
    unsigned long op;
    unsigned long arg[5];
    long retval;
} privcmd_hypercall_t;

typedef struct privcmd_mmap_entry {
    unsigned long va;
    unsigned long mfn;
    unsigned long npages;
} privcmd_mmap_entry_t;

typedef struct privcmd_mmap {
    int num;
    domid_t dom; /* target domain */
    privcmd_mmap_entry_t *entry;
} privcmd_mmap_t;

typedef struct privcmd_mmapbatch {
    int num;     /* number of pages to populate */
    domid_t dom; /* target domain */
    unsigned long addr;  /* virtual address */
    unsigned long *arr; /* array of mfns - top nibble set on err */
} privcmd_mmapbatch_t;

typedef struct privcmd_mmapbatch_v2 {
    int num;     /* number of pages to populate */
    domid_t dom; /* target domain */
    uint64_t addr;  /* virtual address */
    const xen_pfn_t *arr; /* array of mfns */
    int *err; /* array of error codes */
} privcmd_mmapbatch_v2_t;

typedef struct privcmd_blkmsg
{
    unsigned long op;
    void         *buf;
    int           buf_size;
} privcmd_blkmsg_t;

/*
 * @cmd: IOCTL_PRIVCMD_HYPERCALL
 * @arg: &privcmd_hypercall_t
 * Return: Value returned from execution of the specified hypercall.
 */
#define IOCTL_PRIVCMD_HYPERCALL         \
    _IOWR('P', 0, privcmd_hypercall_t)

#if defined(_KERNEL)
/* compat */
#define IOCTL_PRIVCMD_INITDOMAIN_EVTCHN_OLD \
    _IO('P', 1)

typedef struct oprivcmd_hypercall
{
    unsigned long op;
    unsigned long arg[5];
} oprivcmd_hypercall_t;

#define IOCTL_PRIVCMD_HYPERCALL_OLD       \
    _IOWR('P', 0, oprivcmd_hypercall_t)
#endif /* defined(_KERNEL) */
    
#define IOCTL_PRIVCMD_MMAP             \
    _IOW('P', 2, privcmd_mmap_t)
#define IOCTL_PRIVCMD_MMAPBATCH        \
    _IOW('P', 3, privcmd_mmapbatch_t)
#define IOCTL_PRIVCMD_GET_MACH2PHYS_START_MFN \
    _IOR('P', 4, unsigned long)

/*
 * @cmd: IOCTL_PRIVCMD_INITDOMAIN_EVTCHN
 * @arg: n/a
 * Return: Port associated with domain-controller end of control event channel
 *         for the initial domain.
 */
#define IOCTL_PRIVCMD_INITDOMAIN_EVTCHN \
    _IOR('P', 5, int)

#define IOCTL_PRIVCMD_MMAPBATCH_V2      \
    _IOW('P', 6, privcmd_mmapbatch_v2_t)

/*
 * @cmd: IOCTL_PRIVCMD_MMAP_RESOURCE
 * @arg &privcmd_mmap_resource_t
 * Return: 
 * map the specified resource at the provided virtual address
 */ 

typedef struct privcmd_mmap_resource {
        domid_t dom;
	uint32_t type;
	uint32_t id;
	uint32_t idx; 
	uint64_t num; 
	uint64_t addr;
} privcmd_mmap_resource_t;

#define IOCTL_PRIVCMD_MMAP_RESOURCE      \
    _IOW('P', 7, privcmd_mmap_resource_t)

/*
 * @cmd: IOCTL_GNTDEV_MMAP_GRANT_REF
 * @arg &ioctl_gntdev_mmap_grant_ref
 * Return: 
 * map the grant references at the virtual address provided by caller
 * The grant ref already exists (e.g. comes from a remote domain)
 */ 
struct ioctl_gntdev_grant_ref {
	/* The domain ID of the grant to be mapped. */
	uint32_t domid;
	/* The grant reference of the grant to be mapped. */
	uint32_t ref;
};

struct ioctl_gntdev_grant_notify {
	ssize_t offset;
	uint32_t action;
	uint32_t event_channel_port;
};
#define UNMAP_NOTIFY_CLEAR_BYTE 0x1
#define UNMAP_NOTIFY_SEND_EVENT 0x2

struct ioctl_gntdev_mmap_grant_ref {
	/* The number of grants to be mapped. */
	uint32_t count;
	uint32_t pad;
	/* The virtual address where they should be mapped */
	void *va;
	/* notify action */
	struct ioctl_gntdev_grant_notify notify;
	/* Array of grant references, of size @count. */
	struct ioctl_gntdev_grant_ref *refs;
};

#define IOCTL_GNTDEV_MMAP_GRANT_REF \
    _IOW('P', 8, struct ioctl_gntdev_mmap_grant_ref)

/*
 * @cmd: IOCTL_GNTDEV_ALLOC_GRANT_REF
 * @arg &ioctl_gntdev_alloc_grant_ref
 * Return: 
 * Allocate local memory and grant it to a remote domain.
 * local memory is mmaped at the virtual address provided by caller
 */ 

struct ioctl_gntdev_alloc_grant_ref {
	/* IN parameters */ 
	uint16_t domid;
	uint16_t flags;
	uint32_t count;
	void *va;
	/* notify action */
	struct ioctl_gntdev_grant_notify notify;
	/* Variable OUT parameter */  
	uint32_t *gref_ids; 
};

#define IOCTL_GNTDEV_ALLOC_GRANT_REF \
    _IOW('P', 9, struct ioctl_gntdev_alloc_grant_ref)

#define GNTDEV_ALLOC_FLAG_WRITABLE 0x01


/* Interface to /dev/xenevt */
/* EVTCHN_RESET: Clear and reinit the event buffer. Clear error condition. */
#define EVTCHN_RESET  _IO('E', 1)
/* EVTCHN_BIND: Bind to the specified event-channel port. */
#define EVTCHN_BIND   _IOW('E', 2, unsigned long)
/* EVTCHN_UNBIND: Unbind from the specified event-channel port. */
#define EVTCHN_UNBIND _IOW('E', 3, unsigned long)

#endif /* __XEN_XENIO_H__ */