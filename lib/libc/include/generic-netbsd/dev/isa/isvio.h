/* $NetBSD: isvio.h,v 1.1 2008/04/02 01:34:36 dyoung Exp $ */

#ifndef _DEV_ISA_ISVIO_H_
#define _DEV_ISA_ISVIO_H_

#include <sys/inttypes.h>
#include <sys/ioccom.h>

#define	ISV_WIDTH	512
#define	ISV_LINES	480

struct isv_cmd {
	uint8_t			c_cmd;
	uint8_t			c_frameno;
};

#define	ISV_CMD_READ	0

#define ISV_CMD	_IOWR('x', 0, struct isv_cmd)

#endif /* _DEV_ISA_ISVIO_H_ */