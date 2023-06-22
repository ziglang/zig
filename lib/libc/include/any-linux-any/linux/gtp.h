/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _LINUX_GTP_H_
#define _LINUX_GTP_H_

#define GTP_GENL_MCGRP_NAME	"gtp"

enum gtp_genl_cmds {
	GTP_CMD_NEWPDP,
	GTP_CMD_DELPDP,
	GTP_CMD_GETPDP,
	GTP_CMD_ECHOREQ,

	GTP_CMD_MAX,
};

enum gtp_version {
	GTP_V0 = 0,
	GTP_V1,
};

enum gtp_attrs {
	GTPA_UNSPEC = 0,
	GTPA_LINK,
	GTPA_VERSION,
	GTPA_TID,	/* for GTPv0 only */
	GTPA_PEER_ADDRESS,	/* Remote GSN peer, either SGSN or GGSN */
#define GTPA_SGSN_ADDRESS GTPA_PEER_ADDRESS /* maintain legacy attr name */
	GTPA_MS_ADDRESS,
	GTPA_FLOW,
	GTPA_NET_NS_FD,
	GTPA_I_TEI,	/* for GTPv1 only */
	GTPA_O_TEI,	/* for GTPv1 only */
	GTPA_PAD,
	__GTPA_MAX,
};
#define GTPA_MAX (__GTPA_MAX + 1)

#endif /* _LINUX_GTP_H_ */