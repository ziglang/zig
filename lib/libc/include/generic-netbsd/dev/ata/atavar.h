/*	$NetBSD: atavar.h,v 1.109 2021/10/05 08:01:05 rin Exp $	*/

/*
 * Copyright (c) 1998, 2001 Manuel Bouyer.
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

#ifndef _DEV_ATA_ATAVAR_H_
#define	_DEV_ATA_ATAVAR_H_

#include <sys/lock.h>
#include <sys/queue.h>

#include <dev/ata/ataconf.h>

/* XXX For scsipi_adapter and scsipi_channel. */
#include <dev/scsipi/scsipi_all.h>
#include <dev/scsipi/atapiconf.h>

/*
 * Parameters/state needed by the controller to perform an ATA bio.
 */
struct ata_bio {
	volatile uint16_t flags;/* cmd flags */
/* 			0x0001	free, was ATA_NOSLEEP */
#define	ATA_POLL	0x0002	/* poll for completion */
#define	ATA_ITSDONE	0x0004	/* the transfer is as done as it gets */
#define	ATA_SINGLE	0x0008	/* transfer must be done in singlesector mode */
#define	ATA_LBA		0x0010	/* transfer uses LBA addressing */
#define	ATA_READ	0x0020	/* transfer is a read (otherwise a write) */
#define	ATA_CORR	0x0040	/* transfer had a corrected error */
#define	ATA_LBA48	0x0080	/* transfer uses 48-bit LBA addressing */
#define	ATA_FUA		0x0100	/* transfer uses FUA */
#define	ATA_PRIO_HIGH	0x0200	/* transfer has high priority */
	daddr_t		blkno;	/* block addr */
	daddr_t		blkdone;/* number of blks transferred */
	daddr_t		nblks;	/* number of block currently transferring */
	int		nbytes;	/* number of bytes currently transferring */
	long		bcount;	/* total number of bytes */
	char		*databuf;/* data buffer address */
	volatile int	error;
#define	NOERROR 	0	/* There was no error (r_error invalid) */
#define	ERROR		1	/* check r_error */
#define	ERR_DF		2	/* Drive fault */
#define	ERR_DMA		3	/* DMA error */
#define	TIMEOUT		4	/* device timed out */
#define	ERR_NODEV	5	/* device has been gone */
#define ERR_RESET	6	/* command was terminated by channel reset */
#define REQUEUE		7	/* different xfer failed, requeue command */
	uint8_t		r_error;/* copy of error register */
	struct buf	*bp;
};

/*
 * ATA/ATAPI commands description
 *
 * This structure defines the interface between the ATA/ATAPI device driver
 * and the controller for short commands. It contains the command's parameter,
 * the length of data to read/write (if any), and a function to call upon
 * completion.
 * If no sleep is allowed, the driver can poll for command completion.
 * Once the command completed, if the error registered is valid, the flag
 * AT_ERROR is set and the error register value is copied to r_error .
 * A separate interface is needed for read/write or ATAPI packet commands
 * (which need multiple interrupts per commands).
 */
struct ata_command {
	/* ATA parameters */
	uint64_t r_lba;		/* before & after */
	uint16_t r_count;	/* before & after */
	union {
		uint16_t r_features; /* before */
		uint8_t r_error; /* after */
	};
	union {
		uint8_t r_command; /* before */
		uint8_t r_status; /* after */
	};
	uint8_t r_device;	/* before & after */

	uint8_t r_st_bmask;	/* status register mask to wait for before
				   command */
	uint8_t r_st_pmask;	/* status register mask to wait for after
				   command */
	volatile uint16_t flags;

#define AT_READ     	0x0001 /* There is data to read */
#define AT_WRITE    	0x0002 /* There is data to write (excl. with AT_READ) */
#define AT_WAIT     	0x0008 /* wait in controller for command completion */
#define AT_POLL     	0x0010 /* poll for command completion (no interrupts) */
#define AT_DONE     	0x0020 /* command is done */
#define AT_XFDONE   	0x0040 /* data xfer is done */
#define AT_ERROR    	0x0080 /* command is done with error */
#define AT_TIMEOU   	0x0100 /* command timed out */
#define AT_DF       	0x0200 /* Drive fault */
#define AT_RESET    	0x0400 /* command terminated by channel reset */
#define AT_GONE     	0x0800 /* command terminated because device is gone */
#define AT_READREG  	0x1000 /* Read registers on completion */
#define AT_LBA      	0x2000 /* LBA28 */
#define AT_LBA48   	0x4000 /* LBA48 */

	int timeout;		/* timeout (in ms) */
	void *data;		/* Data buffer address */
	int bcount;		/* number of bytes to transfer */
};

/* Forward declaration for ata_xfer */
struct scsipi_xfer;
struct ata_xfer_ops;

/*
 * Description of a command to be handled by an ATA controller.  These
 * commands are queued in a list.
 */
struct ata_xfer {
	int8_t c_slot;			/* queue slot # */

	/* Channel and drive that are to process the request. */
	struct ata_channel *c_chp;
	uint16_t	c_drive;
	uint16_t	c_retries;	/* number of xfer retry */

	volatile u_int c_flags;		/* command state flags */
	void	*c_databuf;		/* pointer to data buffer */
	int	c_bcount;		/* byte count left */
	int	c_skip;			/* bytes already transferred */
#define ATACH_ERR_ST(error, status)	((error) << 8 | (status))
#define ATACH_ERR(val)			(((val) >> 8) & 0xff)
#define ATACH_ST(val)			(((val) >> 0) & 0xff)

	union {
		struct ata_bio	c_bio;		/* ATA transfer */
		struct ata_command c_ata_c;	/* ATA command */ 
		struct {
			struct scsipi_xfer *c_scsipi;	/* SCSI transfer */
			int	c_dscpoll; /* counter for dsc polling (ATAPI) */
			int	c_lenoff;  /* offset to c_bcount (ATAPI) */
		} atapi;
	} u;
#define c_bio	u.c_bio
#define c_ata_c	u.c_ata_c
#define c_atapi u.atapi
#define c_scsipi c_atapi.c_scsipi

	/* Link on the command queue. */
	SIMPLEQ_ENTRY(ata_xfer) c_xferchain;
	TAILQ_ENTRY(ata_xfer) c_activechain;

	/* Links for error handling */
	SLIST_ENTRY(ata_xfer) c_retrychain;

	/* Low-level protocol handlers. */
	const struct ata_xfer_ops *ops;
};

struct ata_xfer_ops {
	int	(*c_start)(struct ata_channel *, struct ata_xfer *);
#define ATASTART_STARTED	0	/* xfer started, waiting for intr */
#define ATASTART_TH		1	/* xfer needs to be run in thread */
#define ATASTART_POLL		2	/* xfer needs to be polled */
#define ATASTART_ABORT		3	/* error occurred, abort xfer */
	int	(*c_poll)(struct ata_channel *, struct ata_xfer *);
#define	ATAPOLL_DONE		0
#define	ATAPOLL_AGAIN		1
	void	(*c_abort)(struct ata_channel *, struct ata_xfer *);
	int	(*c_intr)(struct ata_channel *, struct ata_xfer *, int);
	void	(*c_kill_xfer)(struct ata_channel *, struct ata_xfer *, int);
};

/* flags in c_flags */
#define	C_ATAPI		0x0001		/* xfer is ATAPI request */
#define	C_TIMEOU	0x0002		/* xfer processing timed out */
#define	C_POLL		0x0004		/* command is polled */
#define	C_DMA		0x0008		/* command uses DMA */
#define C_WAIT		0x0010		/* can use kpause */
#define C_WAITACT	0x0020		/* wakeup when active */
#define C_FREE		0x0040		/* call ata_free_xfer() asap */
#define C_PIOBM		0x0080		/* command uses busmastering PIO */
#define	C_NCQ		0x0100		/* command is queued  */
#define C_SKIP_QUEUE	0x0200		/* skip xfer queue */
#define C_WAITTIMO	0x0400		/* race vs. timeout */
#define C_CHAOS		0x0800		/* forced error xfer */
#define C_RECOVERED	0x1000		/* error recovered, no need for reset */
#define C_PRIVATE_ALLOC	0x2000		/* private alloc, skip pool_put() */

/* reasons for c_kill_xfer() */
#define KILL_GONE 1		/* device is gone while xfer was active */
#define KILL_RESET 2		/* xfer was reset */
#define KILL_GONE_INACTIVE 3	/* device is gone while xfer was pending */
#define KILL_REQUEUE	4	/* xfer must be reissued to device, no err */

/*
 * While hw supports up to 32 tags, in practice we must never
 * allow 32 active commands, since that would signal same as
 * channel error. We use slot 32 only for error recovery if available.
 */
#define ATA_MAX_OPENINGS	32
#define ATA_REAL_OPENINGS(op)	((op) > 1 ? (op) - 1 : 1)

#define ATA_BSIZE		512	/* Standard ATA block size (bytes) */

/* Per-channel queue of ata_xfers */
#ifndef ATABUS_PRIVATE
struct ata_queue;
#else
struct ata_queue {
	int8_t queue_flags;		/* flags for this queue */
#define QF_IDLE_WAIT	0x01    	/* someone wants the controller idle */
#define QF_NEED_XFER	0x02    	/* someone wants xfer */
	int8_t queue_active; 		/* number of active transfers */
	uint8_t queue_openings;			/* max number of active xfers */
	SIMPLEQ_HEAD(, ata_xfer) queue_xfer; 	/* queue of pending commands */
	int queue_freeze; 			/* freeze count for the queue */
	kcondvar_t queue_drain;			/* c: waiting of queue drain */
	kcondvar_t queue_idle;			/* c: waiting of queue idle */
	TAILQ_HEAD(, ata_xfer) active_xfers; 	/* active commands */
	uint32_t active_xfers_used;		/* mask of active commands */
	uint32_t queue_xfers_avail;		/* available xfers mask */
	uint32_t queue_hold;			/* slots held during recovery */
	kcondvar_t c_active;		/* somebody actively waiting for xfer */
	kcondvar_t c_cmd_finish;	/* somebody waiting for cmd finish */
};
#endif

/* ATA bus instance state information. */
struct atabus_softc {
	device_t sc_dev;
	struct ata_channel *sc_chan;
	int sc_flags;
#define ATABUSCF_OPEN	0x01
};

/*
 * A queue of atabus instances, used to ensure the same bus probe order
 * for a given hardware configuration at each boot.
 */
struct atabus_initq {
	TAILQ_ENTRY(atabus_initq) atabus_initq;
	struct atabus_softc *atabus_sc;
};

/* High-level functions and structures used by both ATA and ATAPI devices */
struct ataparams;

/* Datas common to drives and controller drivers */
struct ata_drive_datas {
	uint8_t drive;		/* drive number */
	int8_t ata_vers;	/* ATA version supported */
	uint16_t drive_flags;	/* bitmask for drives present/absent and cap */
#define	ATA_DRIVE_CAP32		0x0001	/* 32-bit transfer capable */
#define	ATA_DRIVE_DMA		0x0002
#define	ATA_DRIVE_UDMA		0x0004
#define	ATA_DRIVE_MODE		0x0008	/* the drive reported its mode */
#define	ATA_DRIVE_RESET		0x0010	/* reset the drive state at next xfer */
#define	ATA_DRIVE_WAITDRAIN	0x0020	/* device is waiting for the queue to drain */
#define	ATA_DRIVE_NOSTREAM	0x0040	/* no stream methods on this drive */
#define ATA_DRIVE_ATAPIDSCW	0x0080	/* needs to wait for DSC in phase_complete */
#define ATA_DRIVE_WFUA		0x0100	/* drive supports WRITE DMA FUA EXT */
#define ATA_DRIVE_NCQ		0x0200	/* drive supports NCQ feature set */
#define ATA_DRIVE_NCQ_PRIO	0x0400	/* drive supports NCQ PRIO field */
#define ATA_DRIVE_TH_RESET	0x0800	/* drive waits for thread drive reset */

	uint8_t drive_type;
#define	ATA_DRIVET_NONE		0
#define	ATA_DRIVET_ATA		1
#define	ATA_DRIVET_ATAPI	2
#define	ATA_DRIVET_OLD		3
#define	ATA_DRIVET_PM		4

	/*
	 * Current setting of drive's PIO, DMA and UDMA modes.
	 * Is initialised by the disks drivers at attach time, and may be
	 * changed later by the controller's code if needed
	 */
	uint8_t PIO_mode;	/* Current setting of drive's PIO mode */
#if NATA_DMA
	uint8_t DMA_mode;	/* Current setting of drive's DMA mode */
#if NATA_UDMA
	uint8_t UDMA_mode;	/* Current setting of drive's UDMA mode */
#endif
#endif

	/* Supported modes for this drive */
	uint8_t PIO_cap;	/* supported drive's PIO mode */
#if NATA_DMA
	uint8_t DMA_cap;	/* supported drive's DMA mode */
#if NATA_UDMA
	uint8_t UDMA_cap;	/* supported drive's UDMA mode */
#endif
#endif

	/*
	 * Drive state.
	 * This is reset to 0 after a channel reset.
	 */
	uint8_t state;

#define RESET          0
#define READY          1

	uint8_t drv_openings;		/* # of command tags */

#if NATA_DMA
	/* numbers of xfers and DMA errs. Used by ata_dmaerr() */
	uint8_t n_dmaerrs;
	uint32_t n_xfers;

	/* Downgrade after NERRS_MAX errors in at most NXFER xfers */
#define NERRS_MAX 4
#define NXFER 4000
#endif

	/* Callbacks into the drive's driver. */
	void	(*drv_done)(device_t, struct ata_xfer *); /* xfer is done */

	device_t drv_softc;		/* ATA drives softc, if any */
	struct ata_channel *chnl_softc;	/* channel softc */

	/* Context used for I/O */
	struct disklabel *lp;	/* pointer to drive's label info */
	uint8_t		multi;	/* # of blocks to transfer in multi-mode */
	daddr_t	badsect[127];	/* 126 plus trailing -1 marker */
};

/* User config flags that force (or disable) the use of a mode */
#define ATA_CONFIG_PIO_MODES	0x0007
#define ATA_CONFIG_PIO_SET	0x0008
#define ATA_CONFIG_PIO_OFF	0
#define ATA_CONFIG_DMA_MODES	0x0070
#define ATA_CONFIG_DMA_SET	0x0080
#define ATA_CONFIG_DMA_DISABLE	0x0070
#define ATA_CONFIG_DMA_OFF	4
#define ATA_CONFIG_UDMA_MODES	0x0700
#define ATA_CONFIG_UDMA_SET	0x0800
#define ATA_CONFIG_UDMA_DISABLE	0x0700
#define ATA_CONFIG_UDMA_OFF	8

/*
 * ata_bustype.  The first field must be compatible with scsipi_bustype,
 * as it's used for autoconfig by both ata and atapi drivers.
 */
struct ata_bustype {
	int	bustype_type;	/* symbolic name of type */
	void	(*ata_bio)(struct ata_drive_datas *, struct ata_xfer *);
	void	(*ata_reset_drive)(struct ata_drive_datas *, int, uint32_t *);
	void	(*ata_reset_channel)(struct ata_channel *, int);
	void	(*ata_exec_command)(struct ata_drive_datas *,
				    struct ata_xfer *);

#define	ATACMD_COMPLETE		0x01
#define	ATACMD_QUEUED		0x02
#define	ATACMD_TRY_AGAIN	0x03

	int	(*ata_get_params)(struct ata_drive_datas *, uint8_t,
				  struct ataparams *);
	int	(*ata_addref)(struct ata_drive_datas *);
	void	(*ata_delref)(struct ata_drive_datas *);
	void	(*ata_killpending)(struct ata_drive_datas *);
	void	(*ata_recovery)(struct ata_channel *, int, uint32_t);
};

/* bustype_type */	/* XXX XXX XXX */
/* #define SCSIPI_BUSTYPE_SCSI	0 */
/* #define SCSIPI_BUSTYPE_ATAPI	1 */
#define	SCSIPI_BUSTYPE_ATA	2

/*
 * Describe an ATA device.  Has to be compatible with scsipi_channel, so
 * start with a pointer to ata_bustype.
 */
struct ata_device {
	const struct ata_bustype *adev_bustype;
	int adev_channel;
	struct ata_drive_datas *adev_drv_data;
};

/*
 * Per-channel data
 */
struct ata_channel {
	int ch_channel;			/* location */
	struct atac_softc *ch_atac;	/* ATA controller softc */
	kmutex_t ch_lock;		/* channel lock - queue */

	/* Our state */
	volatile int ch_flags;
#define ATACH_SHUTDOWN 0x02	/* channel is shutting down */
#define ATACH_IRQ_WAIT 0x10	/* controller is waiting for irq */
#define ATACH_DMA_WAIT 0x20	/* controller is waiting for DMA */
#define ATACH_PIOBM_WAIT 0x40	/* controller is waiting for busmastering PIO */
#define	ATACH_DISABLED 0x80	/* channel is disabled */
#define ATACH_TH_RESET 0x200	/* someone ask the thread to reset */
#define ATACH_TH_RESCAN 0x400	/* rescan requested */
#define ATACH_NCQ	0x800	/* channel executing NCQ commands */
#define ATACH_DMA_BEFORE_CMD	0x01000	/* start DMA first */
#define ATACH_TH_DRIVE_RESET	0x02000	/* asked thread to drive(s) reset */
#define ATACH_RECOVERING	0x04000	/* channel is recovering */
#define ATACH_TH_RECOVERY	0x08000	/* asked thread to run recovery */
#define ATACH_DETACHED		0x10000 /* channel was destroyed */

#define ATACH_NODRIVE	0xff	/* no drive selected for reset */

	/* for the timeout callout */
	struct callout c_timo_callout;	/* timeout callout handle */

	/* per-drive info */
	int ch_ndrives; /* number of entries in ch_drive[] */
	struct ata_drive_datas *ch_drive; /* array of ata_drive_datas */

	device_t atabus;	/* self */

	/* ATAPI children */
	device_t atapibus;
	struct scsipi_channel ch_atapi_channel;

	/*
	 * Channel queues.  May be the same for all channels, if hw
	 * channels are not independent.
	 */
	struct ata_queue *ch_queue;

	/* The channel kernel thread */
	struct lwp *ch_thread;
	kcondvar_t ch_thr_idle;		/* thread waiting for work */

	/* Number of sata PMP ports, if any */
	int ch_satapmp_nports;

	/* Recovery buffer */
	struct ata_xfer recovery_xfer;
	uint8_t recovery_blk[ATA_BSIZE];
	uint32_t recovery_tfd;		/* status/err encoded ATACH_ERR_ST() */
};

/*
 * ATA controller softc.
 *
 * This contains a bunch of generic info that all ATA controllers need
 * to have.
 *
 * XXX There is still some lingering wdc-centricity here.
 */
struct atac_softc {
	device_t atac_dev;		/* generic device info */

	int	atac_cap;		/* controller capabilities */

#define	ATAC_CAP_DATA16	0x0001		/* can do 16-bit data access */
#define	ATAC_CAP_DATA32	0x0002		/* can do 32-bit data access */
#define	ATAC_CAP_DMA	0x0008		/* can do ATA DMA modes */
#define	ATAC_CAP_UDMA	0x0010		/* can do ATA Ultra DMA modes */
#define	ATAC_CAP_PIOBM	0x0020		/* can do busmastering PIO transfer */
#define	ATAC_CAP_ATA_NOSTREAM 0x0040	/* don't use stream funcs on ATA */
#define	ATAC_CAP_ATAPI_NOSTREAM 0x0080	/* don't use stream funcs on ATAPI */
#define	ATAC_CAP_NOIRQ	0x1000		/* controller never interrupts */
#define	ATAC_CAP_RAID	0x4000		/* controller "supports" RAID */
#define ATAC_CAP_NCQ	0x8000		/* controller supports NCQ */

	uint8_t	atac_pio_cap;		/* highest PIO mode supported */
#if NATA_DMA
	uint8_t	atac_dma_cap;		/* highest DMA mode supported */
#if NATA_UDMA
	uint8_t	atac_udma_cap;		/* highest UDMA mode supported */
#endif
#endif

	/* Array of pointers to channel-specific data. */
	struct ata_channel **atac_channels;
	int		     atac_nchannels;

	const struct ata_bustype *atac_bustype_ata;

	/*
	 * Glue between ATA and SCSIPI for the benefit of ATAPI.
	 *
	 * Note: The reference count here is used for both ATA and ATAPI
	 * devices.
	 */
	struct atapi_adapter atac_atapi_adapter;
	void (*atac_atapibus_attach)(struct atabus_softc *);

	/* Driver callback to probe for drives. */
	void (*atac_probe)(struct ata_channel *);

	/*
	 * Optional callbacks to lock/unlock hardware.
	 * Called with channel mutex held.
	 */
	int  (*atac_claim_hw)(struct ata_channel *, int);
	void (*atac_free_hw)(struct ata_channel *);

	/*
	 * Optional callbacks to set drive mode.  Required for anything
	 * but basic PIO operation.
	 */
	void (*atac_set_modes)(struct ata_channel *);
};

#ifdef _KERNEL
void	ata_channel_attach(struct ata_channel *);
void	ata_channel_init(struct ata_channel *);
void	ata_channel_detach(struct ata_channel *);
void	ata_channel_destroy(struct ata_channel *);
int	atabusprint(void *aux, const char *);
int	ataprint(void *aux, const char *);

int	atabus_alloc_drives(struct ata_channel *, int);
void	atabus_free_drives(struct ata_channel *);

struct ataparams;
int	ata_get_params(struct ata_drive_datas *, uint8_t, struct ataparams *);
int	ata_set_mode(struct ata_drive_datas *, uint8_t, uint8_t);
int	ata_read_log_ext_ncq(struct ata_drive_datas *, uint8_t, uint8_t *,
    uint8_t *, uint8_t *);
void	ata_recovery_resume(struct ata_channel *, int, int, int);

/* return code for these cmds */
#define CMD_OK    0
#define CMD_ERR   1
#define CMD_AGAIN 2

struct ata_xfer *ata_get_xfer(struct ata_channel *, bool);
void	ata_free_xfer(struct ata_channel *, struct ata_xfer *);
void	ata_deactivate_xfer(struct ata_channel *, struct ata_xfer *);
void	ata_exec_xfer(struct ata_channel *, struct ata_xfer *);
int	ata_xfer_start(struct ata_xfer *xfer);
void	ata_wait_cmd(struct ata_channel *, struct ata_xfer *xfer);

void	ata_timeout(void *);
bool	ata_timo_xfer_check(struct ata_xfer *);
void	ata_kill_pending(struct ata_drive_datas *);
void	ata_kill_active(struct ata_channel *, int, int);
void	ata_thread_run(struct ata_channel *, int, int, int);
bool	ata_is_thread_run(struct ata_channel *);
void	ata_channel_freeze(struct ata_channel *);
void	ata_channel_thaw_locked(struct ata_channel *);
void	ata_channel_lock(struct ata_channel *);
void	ata_channel_unlock(struct ata_channel *);
void	ata_channel_lock_owned(struct ata_channel *);

int	ata_addref(struct ata_channel *);
void	ata_delref(struct ata_channel *);
void	atastart(struct ata_channel *);
void	ata_print_modes(struct ata_channel *);
void	ata_probe_caps(struct ata_drive_datas *);

#if NATA_DMA
void	ata_dmaerr(struct ata_drive_datas *, int);
#endif
struct ata_queue *
	ata_queue_alloc(uint8_t openings);
void	ata_queue_free(struct ata_queue *);
struct ata_xfer *
	ata_queue_hwslot_to_xfer(struct ata_channel *, int);
struct ata_xfer *
	ata_queue_get_active_xfer(struct ata_channel *);
struct ata_xfer *
	ata_queue_get_active_xfer_locked(struct ata_channel *);
struct ata_xfer *
	ata_queue_drive_active_xfer(struct ata_channel *, int);
bool	ata_queue_alloc_slot(struct ata_channel *, uint8_t *, uint8_t);
void	ata_queue_free_slot(struct ata_channel *, uint8_t);
uint32_t	ata_queue_active(struct ata_channel *);
uint8_t	ata_queue_openings(struct ata_channel *);
void	ata_queue_hold(struct ata_channel *);
void	ata_queue_unhold(struct ata_channel *);

void	ata_delay(struct ata_channel *, int, const char *, int);

bool	ata_waitdrain_xfer_check(struct ata_channel *, struct ata_xfer *);

void	atacmd_toncq(struct ata_xfer *, uint8_t *, uint16_t *, uint16_t *,
	    uint8_t *);

#ifdef ATADEBUG
void	atachannel_debug(struct ata_channel *);
#endif

#endif /* _KERNEL */

#endif /* _DEV_ATA_ATAVAR_H_ */