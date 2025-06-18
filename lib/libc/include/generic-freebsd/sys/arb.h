/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright 2002 Niels Provos <provos@citi.umich.edu>
 * Copyright 2018-2019 Netflix, Inc.
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

#ifndef	_SYS_ARB_H_
#define	_SYS_ARB_H_

#include <sys/cdefs.h>

/* Array-based red-black trees. */

#define	ARB_NULLIDX	-1
#define	ARB_NULLCOL	-1

#define ARB_BLACK	0
#define ARB_RED		1

#define ARB_NEGINF	-1
#define ARB_INF		1

#define	ARB_HEAD(name, type, idxbits)					\
struct name {								\
	int##idxbits##_t	arb_curnodes;				\
	int##idxbits##_t	arb_maxnodes;				\
	int##idxbits##_t	arb_root_idx;				\
	int##idxbits##_t	arb_free_idx;				\
	int##idxbits##_t	arb_min_idx;				\
	int##idxbits##_t	arb_max_idx;				\
	struct type		arb_nodes[];				\
}
#define	ARB8_HEAD(name, type)	ARB_HEAD(name, type, 8)
#define	ARB16_HEAD(name, type)	ARB_HEAD(name, type, 16)
#define	ARB32_HEAD(name, type)	ARB_HEAD(name, type, 32)

#define	ARB_ALLOCSIZE(head, maxn, x)					\
	(sizeof(*head) + (maxn) * sizeof(*x))

#define	ARB_INITIALIZER(name, maxn)					\
	((struct name){ 0, maxn, ARB_NULLIDX, ARB_NULLIDX,		\
	    ARB_NULLIDX, ARB_NULLIDX })

#define	ARB_INIT(x, field, head, maxn)					\
	(head)->arb_curnodes = 0;					\
	(head)->arb_maxnodes = (maxn);					\
	(head)->arb_root_idx = (head)->arb_free_idx =			\
	    (head)->arb_min_idx = (head)->arb_max_idx = ARB_NULLIDX;	\
	/* The ARB_RETURNFREE() puts all entries on the free list. */	\
	ARB_ARRFOREACH_REVWCOND(x, field, head,				\
	    ARB_RETURNFREE(head, x, field))

#define	ARB_ENTRY(idxbits)						\
struct {								\
	int##idxbits##_t	arbe_parent_idx;			\
	int##idxbits##_t	arbe_left_idx;				\
	int##idxbits##_t	arbe_right_idx;				\
	int8_t			arbe_color;				\
}
#define	ARB8_ENTRY()		ARB_ENTRY(8)
#define	ARB16_ENTRY()		ARB_ENTRY(16)
#define	ARB32_ENTRY()		ARB_ENTRY(32)

#define	ARB_ENTRYINIT(elm, field) do {					\
	(elm)->field.arbe_parent_idx =					\
	    (elm)->field.arbe_left_idx =				\
	    (elm)->field.arbe_right_idx = ARB_NULLIDX;			\
	    (elm)->field.arbe_color = ARB_NULLCOL;			\
} while (/*CONSTCOND*/ 0)

#define	ARB_ELMTYPE(head)		__typeof(&(head)->arb_nodes[0])
#define	ARB_NODES(head)			(head)->arb_nodes
#define	ARB_MAXNODES(head)		(head)->arb_maxnodes
#define	ARB_CURNODES(head)		(head)->arb_curnodes
#define	ARB_EMPTY(head)			((head)->arb_curnodes == 0)
#define	ARB_FULL(head)			((head)->arb_curnodes >= (head)->arb_maxnodes)
#define	ARB_CNODE(head, idx) \
    ((((intptr_t)(idx) <= ARB_NULLIDX) || ((idx) >= ARB_MAXNODES(head))) ? \
    NULL : ((const ARB_ELMTYPE(head))(ARB_NODES(head) + (idx))))
#define	ARB_NODE(head, idx) \
    (__DECONST(ARB_ELMTYPE(head), ARB_CNODE(head, idx)))
#define	ARB_ROOT(head)			ARB_NODE(head, ARB_ROOTIDX(head))
#define	ARB_LEFT(head, elm, field)	ARB_NODE(head, ARB_LEFTIDX(elm, field))
#define	ARB_RIGHT(head, elm, field)	ARB_NODE(head, ARB_RIGHTIDX(elm, field))
#define	ARB_PARENT(head, elm, field)	ARB_NODE(head, ARB_PARENTIDX(elm, field))
#define	ARB_FREEIDX(head)		(head)->arb_free_idx
#define	ARB_ROOTIDX(head)		(head)->arb_root_idx
#define	ARB_MINIDX(head)		(head)->arb_min_idx
#define	ARB_MAXIDX(head)		(head)->arb_max_idx
#define	ARB_SELFIDX(head, elm)						\
    ((elm) ? ((intptr_t)((((const uint8_t *)(elm)) -			\
    ((const uint8_t *)ARB_NODES(head))) / sizeof(*(elm)))) :		\
    (intptr_t)ARB_NULLIDX)
#define	ARB_LEFTIDX(elm, field)		(elm)->field.arbe_left_idx
#define	ARB_RIGHTIDX(elm, field)	(elm)->field.arbe_right_idx
#define	ARB_PARENTIDX(elm, field)	(elm)->field.arbe_parent_idx
#define	ARB_COLOR(elm, field)		(elm)->field.arbe_color
#define	ARB_PREVFREE(head, elm, field) \
    ARB_NODE(head, ARB_PREVFREEIDX(elm, field))
#define	ARB_PREVFREEIDX(elm, field)	ARB_LEFTIDX(elm, field)
#define	ARB_NEXTFREE(head, elm, field) \
    ARB_NODE(head, ARB_NEXTFREEIDX(elm, field))
#define	ARB_NEXTFREEIDX(elm, field)	ARB_RIGHTIDX(elm, field)
#define	ARB_ISFREE(elm, field)		(ARB_COLOR(elm, field) == ARB_NULLCOL)

#define	ARB_SET(head, elm, parent, field) do {				\
	ARB_PARENTIDX(elm, field) =					\
	    parent ? ARB_SELFIDX(head, parent) : ARB_NULLIDX;		\
	ARB_LEFTIDX(elm, field) = ARB_RIGHTIDX(elm, field) = ARB_NULLIDX; \
	ARB_COLOR(elm, field) = ARB_RED;					\
} while (/*CONSTCOND*/ 0)

#define	ARB_SET_BLACKRED(black, red, field) do {			\
	ARB_COLOR(black, field) = ARB_BLACK;				\
	ARB_COLOR(red, field) = ARB_RED;					\
} while (/*CONSTCOND*/ 0)

#ifndef ARB_AUGMENT
#define	ARB_AUGMENT(x)	do {} while (0)
#endif

#define	ARB_ROTATE_LEFT(head, elm, tmp, field) do {			\
	__typeof(ARB_RIGHTIDX(elm, field)) _tmpidx;			\
	(tmp) = ARB_RIGHT(head, elm, field);				\
	_tmpidx = ARB_RIGHTIDX(elm, field);				\
	ARB_RIGHTIDX(elm, field) = ARB_LEFTIDX(tmp, field);		\
	if (ARB_RIGHTIDX(elm, field) != ARB_NULLIDX) {			\
		ARB_PARENTIDX(ARB_LEFT(head, tmp, field), field) =	\
		    ARB_SELFIDX(head, elm);				\
	}								\
	ARB_AUGMENT(elm);						\
	ARB_PARENTIDX(tmp, field) = ARB_PARENTIDX(elm, field);		\
	if (ARB_PARENTIDX(tmp, field) != ARB_NULLIDX) {			\
		if (ARB_SELFIDX(head, elm) ==				\
		    ARB_LEFTIDX(ARB_PARENT(head, elm, field), field))	\
			ARB_LEFTIDX(ARB_PARENT(head, elm, field),	\
			    field) = _tmpidx;				\
		else							\
			ARB_RIGHTIDX(ARB_PARENT(head, elm, field),	\
			    field) = _tmpidx;				\
	} else								\
		ARB_ROOTIDX(head) = _tmpidx;				\
	ARB_LEFTIDX(tmp, field) = ARB_SELFIDX(head, elm);		\
	ARB_PARENTIDX(elm, field) = _tmpidx;				\
	ARB_AUGMENT(tmp);						\
	if (ARB_PARENTIDX(tmp, field) != ARB_NULLIDX)			\
		ARB_AUGMENT(ARB_PARENT(head, tmp, field));		\
} while (/*CONSTCOND*/ 0)

#define	ARB_ROTATE_RIGHT(head, elm, tmp, field) do {			\
	__typeof(ARB_LEFTIDX(elm, field)) _tmpidx;			\
	(tmp) = ARB_LEFT(head, elm, field);				\
	_tmpidx = ARB_LEFTIDX(elm, field);				\
	ARB_LEFTIDX(elm, field) = ARB_RIGHTIDX(tmp, field);		\
	if (ARB_LEFTIDX(elm, field) != ARB_NULLIDX) {			\
		ARB_PARENTIDX(ARB_RIGHT(head, tmp, field), field) =	\
		    ARB_SELFIDX(head, elm);				\
	}								\
	ARB_AUGMENT(elm);						\
	ARB_PARENTIDX(tmp, field) = ARB_PARENTIDX(elm, field);		\
	if (ARB_PARENTIDX(tmp, field) != ARB_NULLIDX) {			\
		if (ARB_SELFIDX(head, elm) ==				\
		    ARB_LEFTIDX(ARB_PARENT(head, elm, field), field))	\
			ARB_LEFTIDX(ARB_PARENT(head, elm, field),	\
			    field) = _tmpidx;				\
		else							\
			ARB_RIGHTIDX(ARB_PARENT(head, elm, field),	\
			    field) = _tmpidx;				\
	} else								\
		ARB_ROOTIDX(head) = _tmpidx;				\
	ARB_RIGHTIDX(tmp, field) = ARB_SELFIDX(head, elm);		\
	ARB_PARENTIDX(elm, field) = _tmpidx;				\
	ARB_AUGMENT(tmp);						\
	if (ARB_PARENTIDX(tmp, field) != ARB_NULLIDX)			\
		ARB_AUGMENT(ARB_PARENT(head, tmp, field));		\
} while (/*CONSTCOND*/ 0)

#define	ARB_RETURNFREE(head, elm, field)				\
({									\
	ARB_COLOR(elm, field) = ARB_NULLCOL;				\
	ARB_NEXTFREEIDX(elm, field) = ARB_FREEIDX(head);		\
	ARB_FREEIDX(head) = ARB_SELFIDX(head, elm);			\
	elm;								\
})

#define	ARB_GETFREEAT(head, field, fidx)				\
({									\
	__typeof(ARB_NODE(head, 0)) _elm, _prevelm;			\
	int _idx = fidx;							\
	if (ARB_FREEIDX(head) == ARB_NULLIDX && !ARB_FULL(head)) {	\
		/* Populate the free list. */				\
		ARB_ARRFOREACH_REVERSE(_elm, field, head) {		\
			if (ARB_ISFREE(_elm, field))			\
				ARB_RETURNFREE(head, _elm, field);	\
		}							\
	}								\
	_elm = _prevelm = ARB_NODE(head, ARB_FREEIDX(head));		\
	for (; _idx > 0 && _elm != NULL; _idx--, _prevelm = _elm)	\
		_elm = ARB_NODE(head, ARB_NEXTFREEIDX(_elm, field));	\
	if (_elm) {							\
		if (fidx == 0)						\
			ARB_FREEIDX(head) =				\
			    ARB_NEXTFREEIDX(_elm, field);		\
		else							\
			ARB_NEXTFREEIDX(_prevelm, field) =		\
			    ARB_NEXTFREEIDX(_elm, field);		\
	}								\
	_elm;								\
})
#define	ARB_GETFREE(head, field) ARB_GETFREEAT(head, field, 0)

/* Generates prototypes and inline functions */
#define	ARB_PROTOTYPE(name, type, field, cmp)				\
	ARB_PROTOTYPE_INTERNAL(name, type, field, cmp,)
#define	ARB_PROTOTYPE_STATIC(name, type, field, cmp)			\
	ARB_PROTOTYPE_INTERNAL(name, type, field, cmp, __unused static)
#define	ARB_PROTOTYPE_INTERNAL(name, type, field, cmp, attr)		\
	ARB_PROTOTYPE_INSERT_COLOR(name, type, attr);			\
	ARB_PROTOTYPE_REMOVE_COLOR(name, type, attr);			\
	ARB_PROTOTYPE_INSERT(name, type, attr);				\
	ARB_PROTOTYPE_REMOVE(name, type, attr);				\
	ARB_PROTOTYPE_CFIND(name, type, attr);				\
	ARB_PROTOTYPE_FIND(name, type, attr);				\
	ARB_PROTOTYPE_NFIND(name, type, attr);				\
	ARB_PROTOTYPE_CNEXT(name, type, attr);				\
	ARB_PROTOTYPE_NEXT(name, type, attr);				\
	ARB_PROTOTYPE_CPREV(name, type, attr);				\
	ARB_PROTOTYPE_PREV(name, type, attr);				\
	ARB_PROTOTYPE_CMINMAX(name, type, attr);			\
	ARB_PROTOTYPE_MINMAX(name, type, attr);				\
	ARB_PROTOTYPE_REINSERT(name, type, attr);
#define	ARB_PROTOTYPE_INSERT_COLOR(name, type, attr)			\
	attr void name##_ARB_INSERT_COLOR(struct name *, struct type *)
#define	ARB_PROTOTYPE_REMOVE_COLOR(name, type, attr)			\
	attr void name##_ARB_REMOVE_COLOR(struct name *, struct type *, struct type *)
#define	ARB_PROTOTYPE_REMOVE(name, type, attr)				\
	attr struct type *name##_ARB_REMOVE(struct name *, struct type *)
#define	ARB_PROTOTYPE_INSERT(name, type, attr)				\
	attr struct type *name##_ARB_INSERT(struct name *, struct type *)
#define	ARB_PROTOTYPE_CFIND(name, type, attr)				\
	attr const struct type *name##_ARB_CFIND(const struct name *,	\
	    const struct type *)
#define	ARB_PROTOTYPE_FIND(name, type, attr)				\
	attr struct type *name##_ARB_FIND(const struct name *,		\
	    const struct type *)
#define ARB_PROTOTYPE_NFIND(name, type, attr)				\
	attr struct type *name##_ARB_NFIND(struct name *, struct type *)
#define	ARB_PROTOTYPE_CNFIND(name, type, attr)				\
	attr const struct type *name##_ARB_CNFIND(const struct name *,	\
	    const struct type *)
#define	ARB_PROTOTYPE_CNEXT(name, type, attr)				\
	attr const struct type *name##_ARB_CNEXT(const struct name *head,\
	    const struct type *)
#define	ARB_PROTOTYPE_NEXT(name, type, attr)				\
	attr struct type *name##_ARB_NEXT(const struct name *,		\
	    const struct type *)
#define	ARB_PROTOTYPE_CPREV(name, type, attr)				\
	attr const struct type *name##_ARB_CPREV(const struct name *,	\
	    const struct type *)
#define	ARB_PROTOTYPE_PREV(name, type, attr)				\
	attr struct type *name##_ARB_PREV(const struct name *,		\
	    const struct type *)
#define	ARB_PROTOTYPE_CMINMAX(name, type, attr)				\
	attr const struct type *name##_ARB_CMINMAX(const struct name *, int)
#define	ARB_PROTOTYPE_MINMAX(name, type, attr)				\
	attr struct type *name##_ARB_MINMAX(const struct name *, int)
#define ARB_PROTOTYPE_REINSERT(name, type, attr)			\
	attr struct type *name##_ARB_REINSERT(struct name *, struct type *)

#define	ARB_GENERATE(name, type, field, cmp)				\
	ARB_GENERATE_INTERNAL(name, type, field, cmp,)
#define	ARB_GENERATE_STATIC(name, type, field, cmp)			\
	ARB_GENERATE_INTERNAL(name, type, field, cmp, __unused static)
#define	ARB_GENERATE_INTERNAL(name, type, field, cmp, attr)		\
	ARB_GENERATE_INSERT_COLOR(name, type, field, attr)		\
	ARB_GENERATE_REMOVE_COLOR(name, type, field, attr)		\
	ARB_GENERATE_INSERT(name, type, field, cmp, attr)		\
	ARB_GENERATE_REMOVE(name, type, field, attr)			\
	ARB_GENERATE_CFIND(name, type, field, cmp, attr)		\
	ARB_GENERATE_FIND(name, type, field, cmp, attr)			\
	ARB_GENERATE_CNEXT(name, type, field, attr)			\
	ARB_GENERATE_NEXT(name, type, field, attr)			\
	ARB_GENERATE_CPREV(name, type, field, attr)			\
	ARB_GENERATE_PREV(name, type, field, attr)			\
	ARB_GENERATE_CMINMAX(name, type, field, attr)			\
	ARB_GENERATE_MINMAX(name, type, field, attr)			\
	ARB_GENERATE_REINSERT(name, type, field, cmp, attr)

#define ARB_GENERATE_INSERT_COLOR(name, type, field, attr)		\
attr void								\
name##_ARB_INSERT_COLOR(struct name *head, struct type *elm)		\
{									\
	struct type *parent, *gparent, *tmp;				\
	while ((parent = ARB_PARENT(head, elm, field)) != NULL &&	\
	    ARB_COLOR(parent, field) == ARB_RED) {			\
		gparent = ARB_PARENT(head, parent, field);		\
		if (parent == ARB_LEFT(head, gparent, field)) {		\
			tmp = ARB_RIGHT(head, gparent, field);		\
			if (tmp && ARB_COLOR(tmp, field) == ARB_RED) {	\
				ARB_COLOR(tmp, field) = ARB_BLACK;	\
				ARB_SET_BLACKRED(parent, gparent, field); \
				elm = gparent;				\
				continue;				\
			}						\
			if (ARB_RIGHT(head, parent, field) == elm) {	\
				ARB_ROTATE_LEFT(head, parent, tmp, field); \
				tmp = parent;				\
				parent = elm;				\
				elm = tmp;				\
			}						\
			ARB_SET_BLACKRED(parent, gparent, field);	\
			ARB_ROTATE_RIGHT(head, gparent, tmp, field);	\
		} else {						\
			tmp = ARB_LEFT(head, gparent, field);		\
			if (tmp && ARB_COLOR(tmp, field) == ARB_RED) {	\
				ARB_COLOR(tmp, field) = ARB_BLACK;	\
				ARB_SET_BLACKRED(parent, gparent, field); \
				elm = gparent;				\
				continue;				\
			}						\
			if (ARB_LEFT(head, parent, field) == elm) {	\
				ARB_ROTATE_RIGHT(head, parent, tmp, field); \
				tmp = parent;				\
				parent = elm;				\
				elm = tmp;				\
			}						\
			ARB_SET_BLACKRED(parent, gparent, field);	\
			ARB_ROTATE_LEFT(head, gparent, tmp, field);	\
		}							\
	}								\
	ARB_COLOR(ARB_ROOT(head), field) = ARB_BLACK;			\
}

#define ARB_GENERATE_REMOVE_COLOR(name, type, field, attr)		\
attr void								\
name##_ARB_REMOVE_COLOR(struct name *head, struct type *parent, struct type *elm) \
{									\
	struct type *tmp;						\
	while ((elm == NULL || ARB_COLOR(elm, field) == ARB_BLACK) &&	\
	    elm != ARB_ROOT(head)) {					\
		if (ARB_LEFT(head, parent, field) == elm) {		\
			tmp = ARB_RIGHT(head, parent, field);		\
			if (ARB_COLOR(tmp, field) == ARB_RED) {		\
				ARB_SET_BLACKRED(tmp, parent, field);	\
				ARB_ROTATE_LEFT(head, parent, tmp, field); \
				tmp = ARB_RIGHT(head, parent, field);	\
			}						\
			if ((ARB_LEFT(head, tmp, field) == NULL ||	\
			    ARB_COLOR(ARB_LEFT(head, tmp, field), field) == ARB_BLACK) && \
			    (ARB_RIGHT(head, tmp, field) == NULL ||	\
			    ARB_COLOR(ARB_RIGHT(head, tmp, field), field) == ARB_BLACK)) { \
				ARB_COLOR(tmp, field) = ARB_RED;		\
				elm = parent;				\
				parent = ARB_PARENT(head, elm, field);	\
			} else {					\
				if (ARB_RIGHT(head, tmp, field) == NULL || \
				    ARB_COLOR(ARB_RIGHT(head, tmp, field), field) == ARB_BLACK) { \
					struct type *oleft;		\
					if ((oleft = ARB_LEFT(head, tmp, field)) \
					    != NULL)			\
						ARB_COLOR(oleft, field) = ARB_BLACK; \
					ARB_COLOR(tmp, field) = ARB_RED;	\
					ARB_ROTATE_RIGHT(head, tmp, oleft, field); \
					tmp = ARB_RIGHT(head, parent, field); \
				}					\
				ARB_COLOR(tmp, field) = ARB_COLOR(parent, field); \
				ARB_COLOR(parent, field) = ARB_BLACK;	\
				if (ARB_RIGHT(head, tmp, field))	\
					ARB_COLOR(ARB_RIGHT(head, tmp, field), field) = ARB_BLACK; \
				ARB_ROTATE_LEFT(head, parent, tmp, field); \
				elm = ARB_ROOT(head);			\
				break;					\
			}						\
		} else {						\
			tmp = ARB_LEFT(head, parent, field);		\
			if (ARB_COLOR(tmp, field) == ARB_RED) {		\
				ARB_SET_BLACKRED(tmp, parent, field);	\
				ARB_ROTATE_RIGHT(head, parent, tmp, field); \
				tmp = ARB_LEFT(head, parent, field);	\
			}						\
			if ((ARB_LEFT(head, tmp, field) == NULL ||	\
			    ARB_COLOR(ARB_LEFT(head, tmp, field), field) == ARB_BLACK) && \
			    (ARB_RIGHT(head, tmp, field) == NULL ||	\
			    ARB_COLOR(ARB_RIGHT(head, tmp, field), field) == ARB_BLACK)) { \
				ARB_COLOR(tmp, field) = ARB_RED;		\
				elm = parent;				\
				parent = ARB_PARENT(head, elm, field);	\
			} else {					\
				if (ARB_LEFT(head, tmp, field) == NULL || \
				    ARB_COLOR(ARB_LEFT(head, tmp, field), field) == ARB_BLACK) { \
					struct type *oright;		\
					if ((oright = ARB_RIGHT(head, tmp, field)) \
					    != NULL)			\
						ARB_COLOR(oright, field) = ARB_BLACK; \
					ARB_COLOR(tmp, field) = ARB_RED;	\
					ARB_ROTATE_LEFT(head, tmp, oright, field); \
					tmp = ARB_LEFT(head, parent, field); \
				}					\
				ARB_COLOR(tmp, field) = ARB_COLOR(parent, field); \
				ARB_COLOR(parent, field) = ARB_BLACK;	\
				if (ARB_LEFT(head, tmp, field))		\
					ARB_COLOR(ARB_LEFT(head, tmp, field), field) = ARB_BLACK; \
				ARB_ROTATE_RIGHT(head, parent, tmp, field); \
				elm = ARB_ROOT(head);			\
				break;					\
			}						\
		}							\
	}								\
	if (elm)							\
		ARB_COLOR(elm, field) = ARB_BLACK;			\
}

#define	ARB_GENERATE_REMOVE(name, type, field, attr)			\
attr struct type *							\
name##_ARB_REMOVE(struct name *head, struct type *elm)			\
{									\
	struct type *child, *parent, *old = elm;			\
	int color;							\
	if (ARB_LEFT(head, elm, field) == NULL)				\
		child = ARB_RIGHT(head, elm, field);			\
	else if (ARB_RIGHT(head, elm, field) == NULL)			\
		child = ARB_LEFT(head, elm, field);			\
	else {								\
		struct type *left;					\
		elm = ARB_RIGHT(head, elm, field);			\
		while ((left = ARB_LEFT(head, elm, field)) != NULL)	\
			elm = left;					\
		child = ARB_RIGHT(head, elm, field);			\
		parent = ARB_PARENT(head, elm, field);			\
		color = ARB_COLOR(elm, field);				\
		if (child)						\
			ARB_PARENTIDX(child, field) =			\
			    ARB_SELFIDX(head, parent);			\
		if (parent) {						\
			if (ARB_LEFT(head, parent, field) == elm)	\
				ARB_LEFTIDX(parent, field) =		\
				    ARB_SELFIDX(head, child);		\
			else						\
				ARB_RIGHTIDX(parent, field) =		\
				    ARB_SELFIDX(head, child);		\
			ARB_AUGMENT(parent);				\
		} else							\
			ARB_ROOTIDX(head) = ARB_SELFIDX(head, child);	\
		if (ARB_PARENT(head, elm, field) == old)		\
			parent = elm;					\
		(elm)->field = (old)->field;				\
		if (ARB_PARENT(head, old, field)) {			\
			if (ARB_LEFT(head, ARB_PARENT(head, old, field), \
			    field) == old)				\
				ARB_LEFTIDX(ARB_PARENT(head, old, field), \
				    field) = ARB_SELFIDX(head, elm);	\
			else						\
				ARB_RIGHTIDX(ARB_PARENT(head, old, field),\
				    field) = ARB_SELFIDX(head, elm);	\
			ARB_AUGMENT(ARB_PARENT(head, old, field));	\
		} else							\
			ARB_ROOTIDX(head) = ARB_SELFIDX(head, elm);	\
		ARB_PARENTIDX(ARB_LEFT(head, old, field), field) =	\
		    ARB_SELFIDX(head, elm);				\
		if (ARB_RIGHT(head, old, field))			\
			ARB_PARENTIDX(ARB_RIGHT(head, old, field),	\
			    field) = ARB_SELFIDX(head, elm);		\
		if (parent) {						\
			left = parent;					\
			do {						\
				ARB_AUGMENT(left);			\
			} while ((left = ARB_PARENT(head, left, field))	\
			    != NULL);					\
		}							\
		goto color;						\
	}								\
	parent = ARB_PARENT(head, elm, field);				\
	color = ARB_COLOR(elm, field);					\
	if (child)							\
		ARB_PARENTIDX(child, field) = ARB_SELFIDX(head, parent);\
	if (parent) {							\
		if (ARB_LEFT(head, parent, field) == elm)		\
			ARB_LEFTIDX(parent, field) =			\
			    ARB_SELFIDX(head, child);			\
		else							\
			ARB_RIGHTIDX(parent, field) =			\
			    ARB_SELFIDX(head, child);			\
		ARB_AUGMENT(parent);					\
	} else								\
		ARB_ROOTIDX(head) = ARB_SELFIDX(head, child);		\
color:									\
	if (color == ARB_BLACK)						\
		name##_ARB_REMOVE_COLOR(head, parent, child);		\
	ARB_CURNODES(head) -= 1;					\
	if (ARB_MINIDX(head) == ARB_SELFIDX(head, old))			\
		ARB_MINIDX(head) = ARB_PARENTIDX(old, field);		\
	if (ARB_MAXIDX(head) == ARB_SELFIDX(head, old))			\
		ARB_MAXIDX(head) = ARB_PARENTIDX(old, field);		\
	ARB_RETURNFREE(head, old, field);				\
	return (old);							\
}									\

#define ARB_GENERATE_INSERT(name, type, field, cmp, attr)		\
/* Inserts a node into the RB tree */					\
attr struct type *							\
name##_ARB_INSERT(struct name *head, struct type *elm)			\
{									\
	struct type *tmp;						\
	struct type *parent = NULL;					\
	int comp = 0;							\
	tmp = ARB_ROOT(head);						\
	while (tmp) {							\
		parent = tmp;						\
		comp = (cmp)(elm, parent);				\
		if (comp < 0)						\
			tmp = ARB_LEFT(head, tmp, field);		\
		else if (comp > 0)					\
			tmp = ARB_RIGHT(head, tmp, field);		\
		else							\
			return (tmp);					\
	}								\
	ARB_SET(head, elm, parent, field);				\
	if (parent != NULL) {						\
		if (comp < 0)						\
			ARB_LEFTIDX(parent, field) =			\
			    ARB_SELFIDX(head, elm);			\
		else							\
			ARB_RIGHTIDX(parent, field) =			\
			    ARB_SELFIDX(head, elm);			\
		ARB_AUGMENT(parent);					\
	} else								\
		ARB_ROOTIDX(head) = ARB_SELFIDX(head, elm);		\
	name##_ARB_INSERT_COLOR(head, elm);				\
	ARB_CURNODES(head) += 1;					\
	if (ARB_MINIDX(head) == ARB_NULLIDX ||				\
	    (ARB_PARENTIDX(elm, field) == ARB_MINIDX(head) &&		\
	    ARB_LEFTIDX(parent, field) == ARB_SELFIDX(head, elm)))	\
		ARB_MINIDX(head) = ARB_SELFIDX(head, elm);		\
	if (ARB_MAXIDX(head) == ARB_NULLIDX ||				\
	    (ARB_PARENTIDX(elm, field) == ARB_MAXIDX(head) &&		\
	    ARB_RIGHTIDX(parent, field) == ARB_SELFIDX(head, elm)))	\
		ARB_MAXIDX(head) = ARB_SELFIDX(head, elm);	\
	return (NULL);							\
}

#define	ARB_GENERATE_CFIND(name, type, field, cmp, attr)		\
/* Finds the node with the same key as elm */				\
attr const struct type *						\
name##_ARB_CFIND(const struct name *head, const struct type *elm)	\
{									\
	const struct type *tmp = ARB_ROOT(head);			\
	int comp;							\
	while (tmp) {							\
		comp = cmp(elm, tmp);					\
		if (comp < 0)						\
			tmp = ARB_LEFT(head, tmp, field);		\
		else if (comp > 0)					\
			tmp = ARB_RIGHT(head, tmp, field);		\
		else							\
			return (tmp);					\
	}								\
	return (NULL);							\
}

#define	ARB_GENERATE_FIND(name, type, field, cmp, attr)			\
attr struct type *							\
name##_ARB_FIND(const struct name *head, const struct type *elm)	\
{ return (__DECONST(struct type *, name##_ARB_CFIND(head, elm))); }

#define	ARB_GENERATE_CNFIND(name, type, field, cmp, attr)		\
/* Finds the first node greater than or equal to the search key */	\
attr const struct type *						\
name##_ARB_CNFIND(const struct name *head, const struct type *elm)	\
{									\
	const struct type *tmp = ARB_ROOT(head);			\
	const struct type *res = NULL;					\
	int comp;							\
	while (tmp) {							\
		comp = cmp(elm, tmp);					\
		if (comp < 0) {						\
			res = tmp;					\
			tmp = ARB_LEFT(head, tmp, field);		\
		}							\
		else if (comp > 0)					\
			tmp = ARB_RIGHT(head, tmp, field);		\
		else							\
			return (tmp);					\
	}								\
	return (res);							\
}

#define	ARB_GENERATE_NFIND(name, type, field, cmp, attr)		\
attr struct type *							\
name##_ARB_NFIND(const struct name *head, const struct type *elm)	\
{ return (__DECONST(struct type *, name##_ARB_CNFIND(head, elm))); }

#define	ARB_GENERATE_CNEXT(name, type, field, attr)			\
/* ARGSUSED */								\
attr const struct type *						\
name##_ARB_CNEXT(const struct name *head, const struct type *elm)	\
{									\
	if (ARB_RIGHT(head, elm, field)) {				\
		elm = ARB_RIGHT(head, elm, field);			\
		while (ARB_LEFT(head, elm, field))			\
			elm = ARB_LEFT(head, elm, field);		\
	} else {							\
		if (ARB_PARENT(head, elm, field) &&			\
		    (elm == ARB_LEFT(head, ARB_PARENT(head, elm, field),\
		    field)))						\
			elm = ARB_PARENT(head, elm, field);		\
		else {							\
			while (ARB_PARENT(head, elm, field) &&		\
			    (elm == ARB_RIGHT(head, ARB_PARENT(head,	\
			    elm, field), field)))			\
				elm = ARB_PARENT(head, elm, field);	\
			elm = ARB_PARENT(head, elm, field);		\
		}							\
	}								\
	return (elm);							\
}

#define	ARB_GENERATE_NEXT(name, type, field, attr)			\
attr struct type *							\
name##_ARB_NEXT(const struct name *head, const struct type *elm)	\
{ return (__DECONST(struct type *, name##_ARB_CNEXT(head, elm))); }

#define	ARB_GENERATE_CPREV(name, type, field, attr)			\
/* ARGSUSED */								\
attr const struct type *						\
name##_ARB_CPREV(const struct name *head, const struct type *elm)	\
{									\
	if (ARB_LEFT(head, elm, field)) {				\
		elm = ARB_LEFT(head, elm, field);			\
		while (ARB_RIGHT(head, elm, field))			\
			elm = ARB_RIGHT(head, elm, field);		\
	} else {							\
		if (ARB_PARENT(head, elm, field) &&			\
		    (elm == ARB_RIGHT(head, ARB_PARENT(head, elm,	\
		    field), field)))					\
			elm = ARB_PARENT(head, elm, field);		\
		else {							\
			while (ARB_PARENT(head, elm, field) &&		\
			    (elm == ARB_LEFT(head, ARB_PARENT(head, elm,\
			    field), field)))				\
				elm = ARB_PARENT(head, elm, field);	\
			elm = ARB_PARENT(head, elm, field);		\
		}							\
	}								\
	return (elm);							\
}

#define	ARB_GENERATE_PREV(name, type, field, attr)			\
attr struct type *							\
name##_ARB_PREV(const struct name *head, const struct type *elm)	\
{ return (__DECONST(struct type *, name##_ARB_CPREV(head, elm))); }

#define	ARB_GENERATE_CMINMAX(name, type, field, attr)			\
attr const struct type *						\
name##_ARB_CMINMAX(const struct name *head, int val)			\
{									\
	const struct type *tmp = ARB_EMPTY(head) ? NULL : ARB_ROOT(head);\
	const struct type *parent = NULL;				\
	while (tmp) {							\
		parent = tmp;						\
		if (val < 0)						\
			tmp = ARB_LEFT(head, tmp, field);		\
		else							\
			tmp = ARB_RIGHT(head, tmp, field);		\
	}								\
	return (__DECONST(struct type *, parent));			\
}

#define	ARB_GENERATE_MINMAX(name, type, field, attr)			\
attr struct type *							\
name##_ARB_MINMAX(const struct name *head, int val)			\
{ return (__DECONST(struct type *, name##_ARB_CMINMAX(head, val))); }

#define	ARB_GENERATE_REINSERT(name, type, field, cmp, attr)		\
attr struct type *							\
name##_ARB_REINSERT(struct name *head, struct type *elm)		\
{									\
	struct type *cmpelm;						\
	if (((cmpelm = ARB_PREV(name, head, elm)) != NULL &&		\
	    (cmp)(cmpelm, elm) >= 0) ||					\
	    ((cmpelm = ARB_NEXT(name, head, elm)) != NULL &&		\
	    (cmp)(elm, cmpelm) >= 0)) {					\
		/* XXXLAS: Remove/insert is heavy handed. */		\
		ARB_REMOVE(name, head, elm);				\
		/* Remove puts elm on the free list. */			\
		elm = ARB_GETFREE(head, field);				\
		return (ARB_INSERT(name, head, elm));			\
	}								\
	return (NULL);							\
}									\

#define	ARB_INSERT(name, x, y)	name##_ARB_INSERT(x, y)
#define	ARB_REMOVE(name, x, y)	name##_ARB_REMOVE(x, y)
#define	ARB_CFIND(name, x, y)	name##_ARB_CFIND(x, y)
#define	ARB_FIND(name, x, y)	name##_ARB_FIND(x, y)
#define	ARB_CNFIND(name, x, y)	name##_ARB_CNFIND(x, y)
#define	ARB_NFIND(name, x, y)	name##_ARB_NFIND(x, y)
#define	ARB_CNEXT(name, x, y)	name##_ARB_CNEXT(x, y)
#define	ARB_NEXT(name, x, y)	name##_ARB_NEXT(x, y)
#define	ARB_CPREV(name, x, y)	name##_ARB_CPREV(x, y)
#define	ARB_PREV(name, x, y)	name##_ARB_PREV(x, y)
#define	ARB_CMIN(name, x)	(ARB_MINIDX(x) == ARB_NULLIDX ? \
	name##_ARB_CMINMAX(x, ARB_NEGINF) : ARB_CNODE(x, ARB_MINIDX(x)))
#define	ARB_MIN(name, x)	(ARB_MINIDX(x) == ARB_NULLIDX ? \
	name##_ARB_MINMAX(x, ARB_NEGINF) : ARB_NODE(x, ARB_MINIDX(x)))
#define	ARB_CMAX(name, x)	(ARB_MAXIDX(x) == ARB_NULLIDX ? \
	name##_ARB_CMINMAX(x, ARB_INF) : ARB_CNODE(x, ARB_MAXIDX(x)))
#define	ARB_MAX(name, x)	(ARB_MAXIDX(x) == ARB_NULLIDX ? \
	name##_ARB_MINMAX(x, ARB_INF) : ARB_NODE(x, ARB_MAXIDX(x)))
#define	ARB_REINSERT(name, x, y) name##_ARB_REINSERT(x, y)

#define	ARB_FOREACH(x, name, head)					\
	for ((x) = ARB_MIN(name, head);					\
	     (x) != NULL;						\
	     (x) = name##_ARB_NEXT(head, x))

#define	ARB_FOREACH_FROM(x, name, y)					\
	for ((x) = (y);							\
	    ((x) != NULL) && ((y) = name##_ARB_NEXT(x), (x) != NULL);	\
	     (x) = (y))

#define	ARB_FOREACH_SAFE(x, name, head, y)				\
	for ((x) = ARB_MIN(name, head);					\
	    ((x) != NULL) && ((y) = name##_ARB_NEXT(x), (x) != NULL);	\
	     (x) = (y))

#define	ARB_FOREACH_REVERSE(x, name, head)				\
	for ((x) = ARB_MAX(name, head);					\
	     (x) != NULL;						\
	     (x) = name##_ARB_PREV(x))

#define	ARB_FOREACH_REVERSE_FROM(x, name, y)				\
	for ((x) = (y);							\
	    ((x) != NULL) && ((y) = name##_ARB_PREV(x), (x) != NULL);	\
	     (x) = (y))

#define	ARB_FOREACH_REVERSE_SAFE(x, name, head, y)			\
	for ((x) = ARB_MAX(name, head);					\
	    ((x) != NULL) && ((y) = name##_ARB_PREV(x), (x) != NULL);	\
	     (x) = (y))

#define	ARB_ARRFOREACH(x, field, head)					\
	for ((x) = ARB_NODES(head);					\
	    ARB_SELFIDX(head, x) < ARB_MAXNODES(head);			\
	    (x)++)

#define	ARB_ARRFOREACH_REVWCOND(x, field, head, extracond)		\
	for ((x) = ARB_NODES(head) + (ARB_MAXNODES(head) - 1);		\
	    (x) >= ARB_NODES(head) && (extracond);			\
	    (x)--)

#define	ARB_ARRFOREACH_REVERSE(x, field, head) \
	ARB_ARRFOREACH_REVWCOND(x, field, head, 1)

#define	ARB_RESET_TREE(head, name, maxn)				\
	*(head) = ARB_INITIALIZER(name, maxn)

#endif	/* _SYS_ARB_H_ */