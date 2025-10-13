/*     $NetBSD: scsiio.h,v 1.13 2020/05/18 09:52:30 rkujawa Exp $        */

#ifndef _SYS_SCSIIO_H_
#define _SYS_SCSIIO_H_


#include <sys/types.h>
#include <sys/ioctl.h>

#define	SENSEBUFLEN 48

typedef struct	scsireq {
	u_long	flags;		/* info about the request status and type */
	u_long	timeout;
	u_char	cmd[16];
	u_char	cmdlen;
	void *	databuf;	/* address in user space of buffer */
	u_long	datalen;	/* size of user buffer (request) */
	u_long	datalen_used;	/* size of user buffer (used)*/
	u_char	sense[SENSEBUFLEN]; /* returned sense will be in here */
	u_char	senselen;	/* sensedata request size (MAX of SENSEBUFLEN)*/
	u_char	senselen_used;	/* return value only */
	u_char	status;		/* what the scsi status was from the adapter */
	u_char	retsts;		/* the return status for the command */
	int	error;		/* error bits */
} scsireq_t;

/* bit definitions for flags */
#define SCCMD_READ		0x00000001
#define SCCMD_WRITE		0x00000002
#define SCCMD_IOV		0x00000004
#define SCCMD_ESCAPE		0x00000010
#define SCCMD_TARGET		0x00000020


/* definitions for the return status (retsts) */
#define SCCMD_OK	0x00
#define SCCMD_TIMEOUT	0x01
#define SCCMD_BUSY	0x02
#define SCCMD_SENSE	0x03
#define SCCMD_UNKNOWN	0x04

#define SCIOCCOMMAND	_IOWR('Q', 1, scsireq_t)

#define SC_DB_CMDS	0x00000001	/* show all scsi cmds and errors */
#define SC_DB_FLOW	0x00000002	/* show routines entered	*/
#define SC_DB_FLOW2	0x00000004	/* show path INSIDE routines	*/
#define SC_DB_DMA	0x00000008	/* show DMA segments etc	*/
#define SCIOCDEBUG	_IOW('Q', 2, int)	/* from 0 to 15 */

struct	oscsi_addr {
	int	scbus;		/* -1 if wildcard */
	int	target;		/* -1 if wildcard */
	int	lun;		/* -1 if wildcard */
};

struct	scsi_addr {
	int type;       /* bus type */
#define TYPE_SCSI 0
#define TYPE_ATAPI 1
	union {
		struct oscsi_addr scsi;
		struct _atapi {
			int atbus;  /* -1 if wildcard */
			int drive;  /* -1 if wildcard */
		} atapi;
	} addr;
};

/*
 * SCSI device ioctls
 */

#define SCIOCIDENTIFY	_IOR('Q', 4, struct scsi_addr) /* where are you? */
#define  OSCIOCIDENTIFY	_IOR('Q', 4, struct oscsi_addr)
#define SCIOCDECONFIG	_IO('Q', 5)	/* please disappear */
#define SCIOCRECONFIG	_IO('Q', 6)	/* please check again */
#define SCIOCRESET	_IO('Q', 7)	/* reset the device */

/*
 * SCSI bus ioctls
 */

/* Scan bus for new devices. */
struct scbusioscan_args {
	int	sa_target;	/* target to scan; -1 for wildcard */
	int	sa_lun;		/* lun to scan; -1 for wildcard */
};
#define	SCBUSIOSCAN	_IOW('U', 0, struct scbusioscan_args)

#define	SCBUSIORESET	_IO('U', 1)	/* reset SCSI bus */

struct scbusiodetach_args {
	int	sa_target;	/* target to scan; -1 for wildcard */
	int	sa_lun;		/* lun to scan; -1 for wildcard */
};
#define	SCBUSIODETACH	_IOW('U', 2, struct scbusiodetach_args)

/* enable/disable device properties */
struct scbusaccel_args {
	int	sa_target;	/* target to set property on */
	int	sa_lun;		/* lun to set property on */
	int	sa_flags;	/* flags to set or clear */
};
#define	SC_ACCEL_SYNC	0x01	/* enable sync mode */
#define	SC_ACCEL_WIDE	0x02	/* enable wide transfers */
#define	SC_ACCEL_TAGS	0x04	/* enable tagged queuing */
#define	SCBUSACCEL	_IOW('U', 2, struct scbusaccel_args)

#define	SCBUSIOLLSCAN	_IO('U', 3)	/* perform low-level scan */

#endif /* _SYS_SCSIIO_H_ */