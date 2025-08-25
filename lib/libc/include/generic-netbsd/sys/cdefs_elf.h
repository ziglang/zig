/*	$NetBSD: cdefs_elf.h,v 1.58 2021/06/04 01:58:02 thorpej Exp $	*/

/*
 * Copyright (c) 1995, 1996 Carnegie-Mellon University.
 * All rights reserved.
 *
 * Author: Chris G. Demetriou
 *
 * Permission to use, copy, modify and distribute this software and
 * its documentation is hereby granted, provided that both the copyright
 * notice and this permission notice appear in all copies of the
 * software, derivative works or modified versions, and any portions
 * thereof, and that both notices appear in supporting documentation.
 *
 * CARNEGIE MELLON ALLOWS FREE USE OF THIS SOFTWARE IN ITS "AS IS"
 * CONDITION.  CARNEGIE MELLON DISCLAIMS ANY LIABILITY OF ANY KIND
 * FOR ANY DAMAGES WHATSOEVER RESULTING FROM THE USE OF THIS SOFTWARE.
 *
 * Carnegie Mellon requests users of this software to return to
 *
 *  Software Distribution Coordinator  or  Software.Distribution@CS.CMU.EDU
 *  School of Computer Science
 *  Carnegie Mellon University
 *  Pittsburgh PA 15213-3890
 *
 * any improvements or extensions that they make and grant Carnegie the
 * rights to redistribute these changes.
 */

#ifndef _SYS_CDEFS_ELF_H_
#define	_SYS_CDEFS_ELF_H_

#ifdef __LEADING_UNDERSCORE
#define	_C_LABEL(x)		__CONCAT(_,x)
#define _C_LABEL_STRING(x)	"_"x
#else
#define	_C_LABEL(x)		x
#define _C_LABEL_STRING(x)	x
#endif

#if __STDC__
#define	___RENAME(x)	__asm(___STRING(_C_LABEL(x)))
#else
#ifdef __LEADING_UNDERSCORE
#define	___RENAME(x)	____RENAME(_/**/x)
#define	____RENAME(x)	__asm(___STRING(x))
#else
#define	___RENAME(x)	__asm(___STRING(x))
#endif
#endif

#define	__indr_reference(sym,alias)	/* nada, since we do weak refs */

#if __STDC__
#define	__strong_alias(alias,sym)	       				\
    __asm(".global " _C_LABEL_STRING(#alias) "\n"			\
	    _C_LABEL_STRING(#alias) " = " _C_LABEL_STRING(#sym));

#define	__weak_alias(alias,sym)						\
    __asm(".weak " _C_LABEL_STRING(#alias) "\n"				\
	    _C_LABEL_STRING(#alias) " = " _C_LABEL_STRING(#sym));

/* Do not use __weak_extern, use __weak_reference instead */
#define	__weak_extern(sym)						\
    __asm(".weak " _C_LABEL_STRING(#sym));

#if __GNUC_PREREQ__(4, 0)
#define	__weak	__attribute__((__weak__))
#else
#define	__weak
#endif

#if __GNUC_PREREQ__(4, 0)
#define	__weak_reference(sym)	__attribute__((__weakref__(#sym)))
#else
#define	__weak_reference(sym)	; __asm(".weak " _C_LABEL_STRING(#sym))
#endif

#if __GNUC_PREREQ__(4, 2)
#define	__weakref_visible	static
#else
#define	__weakref_visible	extern
#endif

#define	__warn_references(sym,msg)					\
    __asm(".pushsection .gnu.warning." #sym "\n"			\
	  ".ascii \"" msg "\"\n"					\
	  ".popsection");

#else /* !__STDC__ */

#ifdef __LEADING_UNDERSCORE
#define __weak_alias(alias,sym) ___weak_alias(_/**/alias,_/**/sym)
#define	___weak_alias(alias,sym)					\
    __asm(".weak alias\nalias = sym");
#else
#define	__weak_alias(alias,sym)						\
    __asm(".weak alias\nalias = sym");
#endif
#ifdef __LEADING_UNDERSCORE
#define __weak_extern(sym) ___weak_extern(_/**/sym)
#define	___weak_extern(sym)						\
    __asm(".weak sym");
#else
#define	__weak_extern(sym)						\
    __asm(".weak sym");
#endif
#define	__warn_references(sym,msg)					\
    __asm(".pushsection .gnu.warning.sym\n"				\
	  ".ascii \"" msg "\"\n"					\
	  ".popsection");

#endif /* !__STDC__ */

#if __arm__
#define __ifunc(name, resolver) \
	__asm(".globl	" _C_LABEL_STRING(#name) "\n" \
	      ".type	" _C_LABEL_STRING(#name) ", %gnu_indirect_function\n" \
	       _C_LABEL_STRING(#name) " = " _C_LABEL_STRING(#resolver))
#define __hidden_ifunc(name, resolver) \
	__asm(".globl	" _C_LABEL_STRING(#name) "\n" \
	      ".hidden	" _C_LABEL_STRING(#name) "\n" \
	      ".type	" _C_LABEL_STRING(#name) ", %gnu_indirect_function\n" \
	       _C_LABEL_STRING(#name) " = " _C_LABEL_STRING(#resolver))
#else
#define __ifunc(name, resolver) \
	__asm(".globl	" _C_LABEL_STRING(#name) "\n" \
	      ".type	" _C_LABEL_STRING(#name) ", @gnu_indirect_function\n" \
	      _C_LABEL_STRING(#name) " = " _C_LABEL_STRING(#resolver))
#define __hidden_ifunc(name, resolver) \
	__asm(".globl	" _C_LABEL_STRING(#name) "\n" \
	      ".hidden	" _C_LABEL_STRING(#name) "\n" \
	      ".type	" _C_LABEL_STRING(#name) ", @gnu_indirect_function\n" \
	      _C_LABEL_STRING(#name) " = " _C_LABEL_STRING(#resolver))
#endif

#ifdef __arm__
#if __STDC__
#  define	__SECTIONSTRING(_sec, _str)				\
	__asm(".pushsection " #_sec ",\"MS\",%progbits,1\n"		\
	      ".asciz \"" _str "\"\n"					\
	      ".popsection")
#else
#  define	__SECTIONSTRING(_sec, _str)				\
	__asm(".pushsection " _sec ",\"MS\",%progbits,1\n"		\
	      ".asciz \"" _str "\"\n"					\
	      ".popsection")
#  endif
#else
#  if __STDC__
#  define	__SECTIONSTRING(_sec, _str)					\
	__asm(".pushsection " #_sec ",\"MS\",@progbits,1\n"		\
	      ".asciz \"" _str "\"\n"					\
	      ".popsection")
#  else
#  define	__SECTIONSTRING(_sec, _str)					\
	__asm(".pushsection " _sec ",\"MS\",@progbits,1\n"		\
	      ".asciz \"" _str "\"\n"					\
	      ".popsection")
#  endif
#endif

#define	__IDSTRING(_n,_s)		__SECTIONSTRING(.ident,_s)

#define	__RCSID(_s)			__IDSTRING(rcsid,_s)
#define	__SCCSID(_s)
#define __SCCSID2(_s)
#define	__COPYRIGHT(_s)			__SECTIONSTRING(.copyright,_s)

#define	__KERNEL_RCSID(_n, _s)		__RCSID(_s)
#define	__KERNEL_SCCSID(_n, _s)
#define	__KERNEL_COPYRIGHT(_n, _s)	__COPYRIGHT(_s)

#ifndef __lint__
#define	__link_set_make_entry(set, sym)					\
	static void const * const __link_set_##set##_sym_##sym		\
	    __section("link_set_" #set) __used = (const void *)&sym
#define	__link_set_make_entry2(set, sym, n)				\
	static void const * const __link_set_##set##_sym_##sym##_##n	\
	    __section("link_set_" #set) __used = (const void *)&sym[n]
#else
#define	__link_set_make_entry(set, sym)					\
	extern void const * const __link_set_##set##_sym_##sym
#define	__link_set_make_entry2(set, sym, n)				\
	extern void const * const __link_set_##set##_sym_##sym##_##n
#endif /* __lint__ */

#define	__link_set_add_text(set, sym)	__link_set_make_entry(set, sym)
#define	__link_set_add_rodata(set, sym)	__link_set_make_entry(set, sym)
#define	__link_set_add_data(set, sym)	__link_set_make_entry(set, sym)
#define	__link_set_add_bss(set, sym)	__link_set_make_entry(set, sym)
#define	__link_set_add_text2(set, sym, n)   __link_set_make_entry2(set, sym, n)
#define	__link_set_add_rodata2(set, sym, n) __link_set_make_entry2(set, sym, n)
#define	__link_set_add_data2(set, sym, n)   __link_set_make_entry2(set, sym, n)
#define	__link_set_add_bss2(set, sym, n)    __link_set_make_entry2(set, sym, n)

#define	__link_set_start(set)	(__start_link_set_##set)
#define	__link_set_end(set)	(__stop_link_set_##set)

#define	__link_set_decl(set, ptype)					\
	extern ptype * const __link_set_start(set)[] __dso_hidden;	\
	__asm__(".hidden " __STRING(__stop_link_set_##set)); \
	extern ptype * const __link_set_end(set)[] __weak __dso_hidden

#define	__link_set_count(set)						\
	(__link_set_end(set) - __link_set_start(set))


#ifdef _KERNEL

/*
 * On multiprocessor systems we can gain an improvement in performance
 * by being mindful of which cachelines data is placed in.
 *
 * __read_mostly:
 *
 *	It makes sense to ensure that rarely modified data is not
 *	placed in the same cacheline as frequently modified data.
 *	To mitigate the phenomenon known as "false-sharing" we
 *	can annotate rarely modified variables with __read_mostly.
 *	All such variables are placed into the .data.read_mostly
 *	section in the kernel ELF.
 *
 *	Prime candidates for __read_mostly annotation are variables
 *	which are hardly ever modified and which are used in code
 *	hot-paths, e.g. pmap_initialized.
 *
 * __cacheline_aligned:
 *
 *	Some data structures (mainly locks) benefit from being aligned
 *	on a cacheline boundary, and having a cacheline to themselves.
 *	This way, the modification of other data items cannot adversely
 *	affect the lock and vice versa.
 *
 *	Any variables annotated with __cacheline_aligned will be
 *	placed into the .data.cacheline_aligned ELF section.
 */
#define	__read_mostly						\
    __attribute__((__section__(".data.read_mostly")))

#define	__cacheline_aligned					\
    __attribute__((__aligned__(COHERENCY_UNIT),			\
		 __section__(".data.cacheline_aligned")))

#endif /* _KERNEL */

#endif /* !_SYS_CDEFS_ELF_H_ */