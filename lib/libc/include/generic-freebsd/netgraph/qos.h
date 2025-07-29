/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Lutz Donnerhacke <lutz@donnerhacke.de>
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
 * THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _NETGRAPH_QOS_H_
#define _NETGRAPH_QOS_H_

#include <sys/mbuf.h>

/* ABI cookie */
#define M_QOS_COOKIE		1571268051
#define MTAG_SIZE(X)	( sizeof(struct X) - sizeof(struct m_tag) )

/*
 * Definition of types within this ABI:
 *  - Choose a type (16bit) by i.e. "echo $((1000+$(date +%s)%64536))"
 *  - Retry if the type is already in use
 *  - Define the structure for the type according to mbuf_tags(9)
 *      struct m_qos_foo {
 *          struct m_tag    tag;
 *          ...
 *      };
 * Preferred usage:
 *      struct m_qos_foo *p = (void *)m_tag_locate(m,
 *          M_QOS_COOKIE, M_QOS_FOO, ...);
 *    or
 *      p = (void *)m_tag_alloc(
 *          M_QOS_COOKIE, M_QOS_FOO, MTAG_SIZE(foo), ...);
        m_tag_prepend(m, &p->tag);
 */

/* Color marking type */
#define M_QOS_COLOR		23568
/* Keep colors ordered semantically in order to allow use of "<=" or ">="  */
enum qos_color {
	QOS_COLOR_GREEN,
	QOS_COLOR_YELLOW,
	QOS_COLOR_RED
};
struct m_qos_color {
	struct m_tag	tag;
	enum qos_color	color;
};

/*
 * Priority class
 * 
 * Processing per priority requires an overhead, which should
 * be static (i.e. for alloctating queues) and small (for memory)
 * So keep your chosen range limited.
 */
#define M_QOS_PRIORITY		28858
struct m_qos_priority {
	struct m_tag	tag;
	uint8_t		priority;	/* 0 - lowest */
};

#endif /* _NETGRAPH_QOS_H_ */