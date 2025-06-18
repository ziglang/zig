#ifndef _IP_CARP_NL_H
#define _IP_CARP_NL_H

#include <net/if.h>

#include <netinet/ip_carp.h>
#include <netlink/netlink_generic.h>

/*
 * Netlink interface to carp(4).
 */

#define CARP_NL_FAMILY_NAME	"carp"

/* commands */
enum {
	CARP_NL_CMD_UNSPEC	= 0,
	CARP_NL_CMD_GET		= 1,
	CARP_NL_CMD_SET		= 2,
	__CARP_NL_CMD_MAX,
};
#define	CARP_NL_CMD_MAX	(__CARP_NL_CMD_MAX - 1)

enum carp_nl_type_t {
	CARP_NL_UNSPEC,
	CARP_NL_VHID		= 1,	/* u32 */
	CARP_NL_STATE		= 2,	/* u32 */
	CARP_NL_ADVBASE		= 3,	/* s32 */
	CARP_NL_ADVSKEW		= 4,	/* s32 */
	CARP_NL_KEY		= 5,	/* byte array */
	CARP_NL_IFINDEX		= 6,	/* u32 */
	CARP_NL_ADDR		= 7,	/* in_addr_t */
	CARP_NL_ADDR6		= 8,	/* in6_addr_t */
	CARP_NL_IFNAME		= 9,	/* string */
};

#endif