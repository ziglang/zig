#ifndef LIBC_H
#define LIBC_H

#include <stdlib.h>
#include <stdio.h>
#include <limits.h>

struct __locale_map;

struct __locale_struct {
	const struct __locale_map *cat[6];
};

struct tls_module {
	struct tls_module *next;
	void *image;
	size_t len, size, align, offset;
};

struct __libc {
#ifdef __wasilibc_unmodified_upstream
	char can_do_threads;
#endif
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
	char threaded;
#endif
#ifdef __wasilibc_unmodified_upstream // WASI doesn't currently use any code that needs "secure" mode
	char secure;
#endif
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
	volatile signed char need_locks;
	int threads_minus_1;
#endif
#ifdef __wasilibc_unmodified_upstream // WASI has no auxv
	size_t *auxv;
#endif
#ifdef __wasilibc_unmodified_upstream // WASI use different TLS implement
	struct tls_module *tls_head;
	size_t tls_size, tls_align, tls_cnt;
#endif
#ifdef __wasilibc_unmodified_upstream // WASI doesn't get the page size from auxv
	size_t page_size;
#endif
	struct __locale_struct global_locale;
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
#else
	struct __locale_struct *current_locale;
#endif
};

#ifndef PAGE_SIZE
#define PAGE_SIZE libc.page_size
#endif

extern hidden struct __libc __libc;
#define libc __libc

hidden void __init_libc(char **, char *);
hidden void __init_tls(size_t *);
hidden void __init_ssp(void *);
hidden void __libc_start_init(void);
hidden void __funcs_on_exit(void);
hidden void __funcs_on_quick_exit(void);
hidden void __libc_exit_fini(void);
hidden void __fork_handler(int);

extern hidden size_t __hwcap;
extern hidden size_t __sysinfo;
extern char *__progname, *__progname_full;

extern hidden const char __libc_version[];

hidden void __synccall(void (*)(void *), void *);
hidden int __setxid(int, int, int, int);

#endif
