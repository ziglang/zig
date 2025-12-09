/*
 *
 * Copyright (c) 2015 Mark Johnston <markj@FreeBSD.org>
 * Copyright (c) 2025 Kyle Evans <kevans@FreeBSD.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 */

#ifndef _SYS_UCOREDUMP_H_
#define _SYS_UCOREDUMP_H_

#ifdef _KERNEL

#include <sys/_uio.h>
#include <sys/blockcount.h>
#include <sys/queue.h>

/* Coredump output parameters. */
struct coredump_params;
struct coredump_writer;
struct thread;
struct ucred;

typedef int coredump_init_fn(const struct coredump_writer *,
    const struct coredump_params *);
typedef int coredump_write_fn(const struct coredump_writer *, const void *, size_t,
    off_t, enum uio_seg, struct ucred *, size_t *, struct thread *);
typedef int coredump_extend_fn(const struct coredump_writer *, off_t,
    struct ucred *);

struct coredump_vnode_ctx {
	struct vnode	*vp;
	struct ucred	*fcred;
};

coredump_write_fn core_vn_write;
coredump_extend_fn core_vn_extend;

struct coredump_writer {
	void			*ctx;
	coredump_init_fn	*init_fn;
	coredump_write_fn	*write_fn;
	coredump_extend_fn	*extend_fn;
};

struct coredump_params {
	off_t		offset;
	struct ucred	*active_cred;
	struct thread	*td;
	const struct coredump_writer	*cdw;
	struct compressor *comp;
};

#define   CORE_BUF_SIZE   (16 * 1024)

int core_write(struct coredump_params *, const void *, size_t, off_t,
    enum uio_seg, size_t *);
int core_output(char *, size_t, off_t, struct coredump_params *, void *);
int sbuf_drain_core_output(void *, const char *, int);

extern int coredump_pack_fileinfo;
extern int coredump_pack_vmmapinfo;

extern int compress_user_cores;
extern int compress_user_cores_level;

typedef int coredumper_probe_fn(struct thread *);

/*
 * Some arbitrary values for coredumper probes to return.  The highest priority
 * we can find wins.  It's somewhat expected that a coredumper may want to bid
 * differently based on the process in question.  Note that probe functions will
 * be called with the proc lock held, so they must not sleep.
 */
#define	COREDUMPER_NOMATCH		(-1)	/* Decline to touch it */
#define	COREDUMPER_GENERIC		(0)	/* I handle coredumps */
#define	COREDUMPER_SPECIAL		(50)	/* Special handler */
#define	COREDUMPER_HIGH_PRIORITY	(100)	/* High-priority handler */

/*
 * The handle functions will be called with the proc lock held, and should
 * return with the proc lock dropped.
 */
typedef int coredumper_handle_fn(struct thread *, off_t);

struct coredumper {
	SLIST_ENTRY(coredumper)	 cd_entry;
	const char		*cd_name;
	coredumper_probe_fn	*cd_probe;
	coredumper_handle_fn	*cd_handle;
	blockcount_t		 cd_refcount;
};

void coredumper_register(struct coredumper *);
void coredumper_unregister(struct coredumper *);

#endif	/* _KERNEL */
#endif	/* _SYS_UCOREDUMP_H_ */