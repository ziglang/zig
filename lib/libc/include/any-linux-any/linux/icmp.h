/* SPDX-License-Identifier: GPL-2.0+ WITH Linux-syscall-note */
/*
 * INET		An implementation of the TCP/IP protocol suite for the LINUX
 *		operating system.  INET is implemented using the  BSD Socket
 *		interface as the means of communication with the user level.
 *
 *		Definitions for the ICMP protocol.
 *
 * Version:	@(#)icmp.h	1.0.3	04/28/93
 *
 * Author:	Fred N. van Kempen, <waltje@uWalt.NL.Mugnet.ORG>
 *
 *		This program is free software; you can redistribute it and/or
 *		modify it under the terms of the GNU General Public License
 *		as published by the Free Software Foundation; either version
 *		2 of the License, or (at your option) any later version.
 */
#ifndef _LINUX_ICMP_H
#define _LINUX_ICMP_H

#include <linux/types.h>
#include <asm/byteorder.h>
#include <linux/if.h>
#include <linux/in6.h>

#define ICMP_ECHOREPLY		0	/* Echo Reply			*/
#define ICMP_DEST_UNREACH	3	/* Destination Unreachable	*/
#define ICMP_SOURCE_QUENCH	4	/* Source Quench		*/
#define ICMP_REDIRECT		5	/* Redirect (change route)	*/
#define ICMP_ECHO		8	/* Echo Request			*/
#define ICMP_TIME_EXCEEDED	11	/* Time Exceeded		*/
#define ICMP_PARAMETERPROB	12	/* Parameter Problem		*/
#define ICMP_TIMESTAMP		13	/* Timestamp Request		*/
#define ICMP_TIMESTAMPREPLY	14	/* Timestamp Reply		*/
#define ICMP_INFO_REQUEST	15	/* Information Request		*/
#define ICMP_INFO_REPLY		16	/* Information Reply		*/
#define ICMP_ADDRESS		17	/* Address Mask Request		*/
#define ICMP_ADDRESSREPLY	18	/* Address Mask Reply		*/
#define NR_ICMP_TYPES		18


/* Codes for UNREACH. */
#define ICMP_NET_UNREACH	0	/* Network Unreachable		*/
#define ICMP_HOST_UNREACH	1	/* Host Unreachable		*/
#define ICMP_PROT_UNREACH	2	/* Protocol Unreachable		*/
#define ICMP_PORT_UNREACH	3	/* Port Unreachable		*/
#define ICMP_FRAG_NEEDED	4	/* Fragmentation Needed/DF set	*/
#define ICMP_SR_FAILED		5	/* Source Route failed		*/
#define ICMP_NET_UNKNOWN	6
#define ICMP_HOST_UNKNOWN	7
#define ICMP_HOST_ISOLATED	8
#define ICMP_NET_ANO		9
#define ICMP_HOST_ANO		10
#define ICMP_NET_UNR_TOS	11
#define ICMP_HOST_UNR_TOS	12
#define ICMP_PKT_FILTERED	13	/* Packet filtered */
#define ICMP_PREC_VIOLATION	14	/* Precedence violation */
#define ICMP_PREC_CUTOFF	15	/* Precedence cut off */
#define NR_ICMP_UNREACH		15	/* instead of hardcoding immediate value */

/* Codes for REDIRECT. */
#define ICMP_REDIR_NET		0	/* Redirect Net			*/
#define ICMP_REDIR_HOST		1	/* Redirect Host		*/
#define ICMP_REDIR_NETTOS	2	/* Redirect Net for TOS		*/
#define ICMP_REDIR_HOSTTOS	3	/* Redirect Host for TOS	*/

/* Codes for TIME_EXCEEDED. */
#define ICMP_EXC_TTL		0	/* TTL count exceeded		*/
#define ICMP_EXC_FRAGTIME	1	/* Fragment Reass time exceeded	*/

/* Codes for EXT_ECHO (PROBE) */
#define ICMP_EXT_ECHO			42
#define ICMP_EXT_ECHOREPLY		43
#define ICMP_EXT_CODE_MAL_QUERY		1	/* Malformed Query */
#define ICMP_EXT_CODE_NO_IF		2	/* No such Interface */
#define ICMP_EXT_CODE_NO_TABLE_ENT	3	/* No such Table Entry */
#define ICMP_EXT_CODE_MULT_IFS		4	/* Multiple Interfaces Satisfy Query */

/* Constants for EXT_ECHO (PROBE) */
#define ICMP_EXT_ECHOREPLY_ACTIVE	(1 << 2)/* active bit in reply message */
#define ICMP_EXT_ECHOREPLY_IPV4		(1 << 1)/* ipv4 bit in reply message */
#define ICMP_EXT_ECHOREPLY_IPV6		1	/* ipv6 bit in reply message */
#define ICMP_EXT_ECHO_CTYPE_NAME	1
#define ICMP_EXT_ECHO_CTYPE_INDEX	2
#define ICMP_EXT_ECHO_CTYPE_ADDR	3
#define ICMP_AFI_IP			1	/* Address Family Identifier for ipv4 */
#define ICMP_AFI_IP6			2	/* Address Family Identifier for ipv6 */

struct icmphdr {
  __u8		type;
  __u8		code;
  __sum16	checksum;
  union {
	struct {
		__be16	id;
		__be16	sequence;
	} echo;
	__be32	gateway;
	struct {
		__be16	__unused;
		__be16	mtu;
	} frag;
	__u8	reserved[4];
  } un;
};


/*
 *	constants for (set|get)sockopt
 */

#define ICMP_FILTER			1

struct icmp_filter {
	__u32		data;
};

/* RFC 4884 extension struct: one per message */
struct icmp_ext_hdr {
#if defined(__LITTLE_ENDIAN_BITFIELD)
	__u8		reserved1:4,
			version:4;
#elif defined(__BIG_ENDIAN_BITFIELD)
	__u8		version:4,
			reserved1:4;
#else
#error	"Please fix <asm/byteorder.h>"
#endif
	__u8		reserved2;
	__sum16		checksum;
};

/* RFC 4884 extension object header: one for each object */
struct icmp_extobj_hdr {
	__be16		length;
	__u8		class_num;
	__u8		class_type;
};

/* RFC 8335: 2.1 Header for c-type 3 payload */
struct icmp_ext_echo_ctype3_hdr {
	__be16		afi;
	__u8		addrlen;
	__u8		reserved;
};

/* RFC 8335: 2.1 Interface Identification Object */
struct icmp_ext_echo_iio {
	struct icmp_extobj_hdr extobj_hdr;
	union {
		char name[IFNAMSIZ];
		__be32 ifindex;
		struct {
			struct icmp_ext_echo_ctype3_hdr ctype3_hdr;
			union {
				__be32		ipv4_addr;
				struct in6_addr	ipv6_addr;
			} ip_addr;
		} addr;
	} ident;
};
#endif /* _LINUX_ICMP_H */