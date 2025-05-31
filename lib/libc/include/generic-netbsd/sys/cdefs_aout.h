/*	$NetBSD: cdefs_aout.h,v 1.20 2006/05/18 17:55:38 christos Exp $	*/

/*
 * Written by J.T. Conklin <jtc@wimsey.com> 01/17/95.
 * Public domain.
 */

#ifndef _SYS_CDEFS_AOUT_H_
#define	_SYS_CDEFS_AOUT_H_

#define	_C_LABEL(x)		__CONCAT(_,x)
#define	_C_LABEL_STRING(x)	"_"x

#if __STDC__
#define	___RENAME(x)	__asm(___STRING(_C_LABEL(x)))
#else
#define	___RENAME(x)	____RENAME(_/**/x)
#define	____RENAME(x)	__asm(___STRING(x))
#endif

#define	__indr_reference(sym,alias)	/* nada, since we do weak refs */

#ifdef __GNUC__
#if __STDC__
#define	__strong_alias(alias,sym)	       				\
    __asm(".global " _C_LABEL_STRING(#alias) "\n"			\
	    _C_LABEL_STRING(#alias) " = " _C_LABEL_STRING(#sym));
#define	__weak_alias(alias,sym)						\
    __asm(".weak " _C_LABEL_STRING(#alias) "\n"			\
	    _C_LABEL_STRING(#alias) " = " _C_LABEL_STRING(#sym));

/* Do not use __weak_extern, use __weak_reference instead */
#define	__weak_extern(sym)						\
    __asm(".weak " _C_LABEL_STRING(#sym));

#if __GNUC_PREREQ__(4, 0)
#define	__weak_reference(sym)	__attribute__((__weakref__))
#else
#define	__weak_reference(sym)	; __asm(".weak " _C_LABEL_STRING(#sym))
#endif

#define	__warn_references(sym,msg)					\
	__asm(".stabs \"" msg "\",30,0,0,0");				\
	__asm(".stabs \"_" #sym "\",1,0,0,0");
#else /* __STDC__ */
#define	__weak_alias(alias,sym) ___weak_alias(_/**/alias,_/**/sym)
#define	___weak_alias(alias,sym)					\
    __asm(".weak alias\nalias = sym");
/* Do not use __weak_extern, use __weak_reference instead */
#define	__weak_extern(sym) ___weak_extern(_/**/sym)
#define	___weak_extern(sym)						\
    __asm(".weak sym");

#if __GNUC_PREREQ__(4, 0)
#define	__weak_reference(sym)	__attribute__((__weakref__))
#else
#define	___weak_reference(sym)	; __asm(".weak sym");
#define	__weak_reference(sym)	___weak_reference(_/**/sym)
#endif

#define	__warn_references(sym,msg)					\
	__asm(".stabs msg,30,0,0,0");					\
	__asm(".stabs \"_/**/sym\",1,0,0,0");
#endif /* __STDC__ */
#else /* __GNUC__ */
#define	__warn_references(sym,msg)
#endif /* __GNUC__ */

#if defined(__sh__)		/* XXX SH COFF */
#undef __indr_reference(sym,alias)
#undef __warn_references(sym,msg)
#define	__warn_references(sym,msg)
#endif

#define	__IDSTRING(_n,_s)						\
	__asm(".data ; .asciz \"" _s "\" ; .text")

#undef __KERNEL_RCSID

#define	__RCSID(_s)	__IDSTRING(rcsid,_s)
#define	__SCCSID(_s)
#define	__SCCSID2(_s)
#if 0	/* XXX userland __COPYRIGHTs have \ns in them */
#define	__COPYRIGHT(_s)	__IDSTRING(copyright,_s)
#else
#define	__COPYRIGHT(_s)							\
	static const char copyright[] __attribute__((__unused__)) = _s
#endif

#if defined(USE_KERNEL_RCSIDS) || !defined(_KERNEL)
#define	__KERNEL_RCSID(_n,_s) __IDSTRING(__CONCAT(rcsid,_n),_s)
#else
#define	__KERNEL_RCSID(_n,_s)
#endif
#define	__KERNEL_SCCSID(_n,_s)
#define	__KERNEL_COPYRIGHT(_n, _s) __IDSTRING(__CONCAT(copyright,_n),_s)

#ifndef __lint__
#define	__link_set_make_entry(set, sym, type)				\
	static void const * const					\
	    __link_set_##set##_sym_##sym __used = &sym;		\
	__asm(".stabs \"___link_set_" #set "\", " #type ", 0, 0, _" #sym)
#else
#define	__link_set_make_entry(set, sym, type)				\
	extern void const * const __link_set_##set##_sym_##sym
#endif /* __lint__ */

#define	__link_set_add_text(set, sym)	__link_set_make_entry(set, sym, 23)
#define	__link_set_add_rodata(set, sym)	__link_set_make_entry(set, sym, 23)
#define	__link_set_add_data(set, sym)	__link_set_make_entry(set, sym, 25)
#define	__link_set_add_bss(set, sym)	__link_set_make_entry(set, sym, 27)

#define	__link_set_decl(set, ptype)					\
extern struct {								\
	int	__ls_length;						\
	ptype	*__ls_items[1];						\
} __link_set_##set

#define	__link_set_start(set)	(&(__link_set_##set).__ls_items[0])
#define	__link_set_end(set)						\
	(&(__link_set_##set).__ls_items[(__link_set_##set).__ls_length])

#define	__link_set_count(set)	((__link_set_##set).__ls_length)

#endif /* !_SYS_CDEFS_AOUT_H_ */