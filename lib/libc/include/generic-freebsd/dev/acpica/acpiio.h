/*-
 * Copyright (c) 1999 Takanori Watanabe <takawata@jp.freebsd.org>
 * Copyright (c) 1999 Mitsuru IWASAKI <iwasaki@FreeBSD.org>
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _ACPIIO_H_
#define _ACPIIO_H_

/*
 * Core ACPI subsystem ioctls
 */
#define ACPIIO_SETSLPSTATE	_IOW('P', 3, int) /* DEPRECATED */

/* Request S1-5 sleep state. User is notified and then sleep proceeds. */
#define ACPIIO_REQSLPSTATE	_IOW('P', 4, int)

/* Allow suspend to continue (0) or abort it (errno). */
#define ACPIIO_ACKSLPSTATE	_IOW('P', 5, int)

struct acpi_battinfo {
    int	 cap;				/* percent */
    int	 min;				/* remaining time (in minutes) */
    int	 state;				/* battery state */
    int	 rate;				/* emptying rate */
};

/*
 * Battery Information object.  Note that this object is deprecated in
 * ACPI 4.0
 */
#define ACPI_CMBAT_MAXSTRLEN 32
struct acpi_bif {
    uint32_t units;			/* Power Unit (mW or mA). */
#define ACPI_BIF_UNITS_MW	0	/* Capacity in mWh, rate in mW. */
#define ACPI_BIF_UNITS_MA	1	/* Capacity in mAh, rate in mA. */
    uint32_t dcap;			/* Design Capacity */
    uint32_t lfcap;			/* Last Full capacity */
    uint32_t btech;			/* Battery Technology */
    uint32_t dvol;			/* Design voltage (mV) */
    uint32_t wcap;			/* WARN capacity */
    uint32_t lcap;			/* Low capacity */
    uint32_t gra1;			/* Granularity 1 (Warn to Low) */
    uint32_t gra2;			/* Granularity 2 (Full to Warn) */
    char model[ACPI_CMBAT_MAXSTRLEN];	/* model identifier */
    char serial[ACPI_CMBAT_MAXSTRLEN];	/* Serial number */
    char type[ACPI_CMBAT_MAXSTRLEN];	/* Type */
    char oeminfo[ACPI_CMBAT_MAXSTRLEN];	/* OEM information */
};

/*
 * Members in acpi_bix are reordered so that the first part is compatible
 * with acpi_bif.
 */
struct acpi_bix {
/* _BIF-compatible */
    uint32_t units;			/* Power Unit (mW or mA). */
#define ACPI_BIX_UNITS_MW	0	/* Capacity in mWh, rate in mW. */
#define ACPI_BIX_UNITS_MA	1	/* Capacity in mAh, rate in mA. */
    uint32_t dcap;			/* Design Capacity */
    uint32_t lfcap;			/* Last Full capacity */
    uint32_t btech;			/* Battery Technology */
    uint32_t dvol;			/* Design voltage (mV) */
    uint32_t wcap;			/* WARN capacity */
    uint32_t lcap;			/* Low capacity */
    uint32_t gra1;			/* Granularity 1 (Warn to Low) */
    uint32_t gra2;			/* Granularity 2 (Full to Warn) */
    char model[ACPI_CMBAT_MAXSTRLEN];	/* model identifier */
    char serial[ACPI_CMBAT_MAXSTRLEN];	/* Serial number */
    char type[ACPI_CMBAT_MAXSTRLEN];	/* Type */
    char oeminfo[ACPI_CMBAT_MAXSTRLEN];	/* OEM information */
    /* ACPI 4.0 or later */
    uint16_t rev;			/* Revision */
#define	ACPI_BIX_REV_0		0	/* ACPI 4.0 _BIX */
#define	ACPI_BIX_REV_1		1	/* ACPI 6.0 _BIX */
#define	ACPI_BIX_REV_BIF	0xffff	/* _BIF */
#define	ACPI_BIX_REV_MIN_CHECK(x, min)	\
	(((min) == ACPI_BIX_REV_BIF) ? ((x) == ACPI_BIX_REV_BIF) : \
	    (((x) == ACPI_BIX_REV_BIF) ? 0 : ((x) >= (min))))
    uint32_t cycles;			/* Cycle Count */
    uint32_t accuracy;			/* Measurement Accuracy */
    uint32_t stmax;			/* Max Sampling Time */
    uint32_t stmin;			/* Min Sampling Time */
    uint32_t aimax;			/* Max Average Interval */
    uint32_t aimin;			/* Min Average Interval */
    /* ACPI 6.0 or later */
    uint32_t scap;			/* Battery Swapping Capability */
#define	ACPI_BIX_SCAP_NO	0x00000000
#define	ACPI_BIX_SCAP_COLD	0x00000001
#define	ACPI_BIX_SCAP_HOT	0x00000010
    uint8_t bix_reserved[58];		/* padding */
};

#if 0
/* acpi_bix in the original order just for reference */
struct acpi_bix {
    uint16_t rev;			/* Revision */
    uint32_t units;			/* Power Unit (mW or mA). */
    uint32_t dcap;			/* Design Capacity */
    uint32_t lfcap;			/* Last Full capacity */
    uint32_t btech;			/* Battery Technology */
    uint32_t dvol;			/* Design voltage (mV) */
    uint32_t wcap;			/* Design Capacity of Warning */
    uint32_t lcap;			/* Design Capacity of Low */
    uint32_t cycles;			/* Cycle Count */
    uint32_t accuracy;			/* Measurement Accuracy */
    uint32_t stmax;			/* Max Sampling Time */
    uint32_t stmin;			/* Min Sampling Time */
    uint32_t aimax;			/* Max Average Interval */
    uint32_t aimin;			/* Min Average Interval */
    uint32_t gra1;			/* Granularity 1 (Warn to Low) */
    uint32_t gra2;			/* Granularity 2 (Full to Warn) */
    char model[ACPI_CMBAT_MAXSTRLEN];	/* model identifier */
    char serial[ACPI_CMBAT_MAXSTRLEN];	/* Serial number */
    char type[ACPI_CMBAT_MAXSTRLEN];	/* Type */
    char oeminfo[ACPI_CMBAT_MAXSTRLEN];	/* OEM information */
    uint32_t scap;			/* Battery Swapping Capability */
};
#endif

struct acpi_bst {
    uint32_t state;			/* Battery State */
    uint32_t rate;			/* Present Rate */
    uint32_t cap;			/* Remaining Capacity */
    uint32_t volt;			/* Present Voltage */
};

/*
 * Note that the following definitions represent status bits for internal
 * driver state.  The first three of them (charging, discharging and critical)
 * conveninetly conform to ACPI specification of status returned by _BST
 * method.  Other definitions (not present, etc) are synthetic.
 * Also note that according to the specification the charging and discharging
 * status bits must not be set at the same time.
 */
#define ACPI_BATT_STAT_DISCHARG		0x0001
#define ACPI_BATT_STAT_CHARGING		0x0002
#define ACPI_BATT_STAT_CRITICAL		0x0004
#define ACPI_BATT_STAT_INVALID					\
    (ACPI_BATT_STAT_DISCHARG | ACPI_BATT_STAT_CHARGING)
#define ACPI_BATT_STAT_BST_MASK					\
    (ACPI_BATT_STAT_INVALID | ACPI_BATT_STAT_CRITICAL)
#define ACPI_BATT_STAT_NOT_PRESENT	ACPI_BATT_STAT_BST_MASK

/* For backward compatibility */
union acpi_battery_ioctl_arg_v1 {
    int			 unit;	/* Device unit or ACPI_BATTERY_ALL_UNITS. */

    struct acpi_battinfo battinfo;

    struct acpi_bif	 bif;
    struct acpi_bst	 bst;
};
union acpi_battery_ioctl_arg {
    int			 unit;	/* Device unit or ACPI_BATTERY_ALL_UNITS. */

    struct acpi_battinfo battinfo;

    struct acpi_bix	 bix;
    struct acpi_bif	 bif;
    struct acpi_bst	 bst;
};

#define ACPI_BATTERY_ALL_UNITS 	(-1)
#define ACPI_BATT_UNKNOWN 	0xffffffff /* _BST or _BI[FX] value unknown. */

/* Common battery ioctls */
#define ACPIIO_BATT_GET_UNITS	  _IOR('B', 0x01, int)
#define ACPIIO_BATT_GET_BATTINFO _IOWR('B', 0x03, union acpi_battery_ioctl_arg)
#define ACPIIO_BATT_GET_BATTINFO_V1 _IOWR('B', 0x03, union acpi_battery_ioctl_arg_v1)
#define ACPIIO_BATT_GET_BIF	 _IOWR('B', 0x10, union acpi_battery_ioctl_arg_v1)
#define ACPIIO_BATT_GET_BIX	 _IOWR('B', 0x10, union acpi_battery_ioctl_arg)
#define ACPIIO_BATT_GET_BST	 _IOWR('B', 0x11, union acpi_battery_ioctl_arg)
#define ACPIIO_BATT_GET_BST_V1	 _IOWR('B', 0x11, union acpi_battery_ioctl_arg_v1)

/* Control Method battery ioctls (deprecated) */
#define ACPIIO_CMBAT_GET_BIF	 ACPIIO_BATT_GET_BIF
#define ACPIIO_CMBAT_GET_BST	 ACPIIO_BATT_GET_BST

/* Get AC adapter status. */
#define ACPIIO_ACAD_GET_STATUS	  _IOR('A', 1, int)

#ifdef _KERNEL
typedef int	(*acpi_ioctl_fn)(u_long cmd, caddr_t addr, void *arg);
extern int	acpi_register_ioctl(u_long cmd, acpi_ioctl_fn fn, void *arg);
extern void	acpi_deregister_ioctl(u_long cmd, acpi_ioctl_fn fn);
#endif

#endif /* !_ACPIIO_H_ */