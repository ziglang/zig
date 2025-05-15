/*-
 * SPDX-License-Identifier: Beerware
 *
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <phk@FreeBSD.ORG> wrote this file.  As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return.   Poul-Henning Kamp
 * ----------------------------------------------------------------------------
 *
 */

#ifndef _SYS_DISK_H_
#define	_SYS_DISK_H_

#include <sys/ioccom.h>
#include <sys/kerneldump.h>
#include <sys/types.h>
#include <sys/disk_zone.h>
#include <sys/socket.h>

#ifdef _KERNEL

void disk_err(struct bio *bp, const char *what, int blkdone, int nl);

#endif

#define	DIOCGSECTORSIZE	_IOR('d', 128, u_int)
	/*
	 * Get the sector size of the device in bytes.  The sector size is the
	 * smallest unit of data which can be transferred from this device.
	 * Usually this is a power of 2 but it might not be (i.e. CDROM audio).
	 */

#define	DIOCGMEDIASIZE	_IOR('d', 129, off_t)	/* Get media size in bytes */
	/*
	 * Get the size of the entire device in bytes.  This should be a
	 * multiple of the sector size.
	 */

#define	DIOCGFWSECTORS	_IOR('d', 130, u_int)	/* Get firmware's sectorcount */
	/*
	 * Get the firmware's notion of number of sectors per track.  This
	 * value is mostly used for compatibility with various ill designed
	 * disk label formats.  Don't use it unless you have to.
	 */

#define	DIOCGFWHEADS	_IOR('d', 131, u_int)	/* Get firmware's headcount */
	/*
	 * Get the firmwares notion of number of heads per cylinder.  This
	 * value is mostly used for compatibility with various ill designed
	 * disk label formats.  Don't use it unless you have to.
	 */

#define	DIOCGFLUSH _IO('d', 135)		/* Flush write cache */
	/*
	 * Flush write cache of the device.
	 */

#define	DIOCGDELETE _IOW('d', 136, off_t[2])	/* Delete data */
	/*
	 * Mark data on the device as unused.
	 */

#define	DISK_IDENT_SIZE	256
#define	DIOCGIDENT _IOR('d', 137, char[DISK_IDENT_SIZE])
	/*-
	 * Get the ident of the given provider. Ident is (most of the time)
	 * a uniqe and fixed provider's identifier. Ident's properties are as
	 * follow:
	 * - ident value is preserved between reboots,
	 * - provider can be detached/attached and ident is preserved,
	 * - provider's name can change - ident can't,
	 * - ident value should not be based on on-disk metadata; in other
	 *   words copying whole data from one disk to another should not
	 *   yield the same ident for the other disk,
	 * - there could be more than one provider with the same ident, but
	 *   only if they point at exactly the same physical storage, this is
	 *   the case for multipathing for example,
	 * - GEOM classes that consumes single providers and provide single
	 *   providers, like geli, gbde, should just attach class name to the
	 *   ident of the underlying provider,
	 * - ident is an ASCII string (is printable),
	 * - ident is optional and applications can't relay on its presence.
	 */

#define	DIOCGPROVIDERNAME _IOR('d', 138, char[MAXPATHLEN])
	/*
	 * Store the provider name, given a device path, in a buffer. The buffer
	 * must be at least MAXPATHLEN bytes long.
	 */

#define	DIOCGSTRIPESIZE	_IOR('d', 139, off_t)	/* Get stripe size in bytes */
	/*
	 * Get the size of the device's optimal access block in bytes.
	 * This should be a multiple of the sector size.
	 */

#define	DIOCGSTRIPEOFFSET _IOR('d', 140, off_t)	/* Get stripe offset in bytes */
	/*
	 * Get the offset of the first device's optimal access block in bytes.
	 * This should be a multiple of the sector size.
	 */

#define	DIOCGPHYSPATH _IOR('d', 141, char[MAXPATHLEN])
	/*
	 * Get a string defining the physical path for a given provider.
	 * This has similar rules to ident, but is intended to uniquely
	 * identify the physical location of the device, not the current
	 * occupant of that location.
	 */

struct diocgattr_arg {
	char name[64];
	int len;
	union {
		char str[DISK_IDENT_SIZE];
		off_t off;
		int i;
		uint16_t u16;
	} value;
};
#define	DIOCGATTR _IOWR('d', 142, struct diocgattr_arg)

#define	DIOCZONECMD	_IOWR('d', 143, struct disk_zone_args)

#ifndef WITHOUT_NETDUMP
#include <net/if.h>
#include <netinet/in.h>

union kd_ip {
	struct in_addr	in4;
	struct in6_addr	in6;
};

/*
 * Sentinel values for kda_index.
 *
 * If kda_index is KDA_REMOVE_ALL, all dump configurations are cleared.
 *
 * If kda_index is KDA_REMOVE_DEV, all dump configurations for the specified
 * device are cleared.
 *
 * If kda_index is KDA_REMOVE, only the specified dump configuration for the
 * given device is removed from the list of fallback dump configurations.
 *
 * If kda_index is KDA_APPEND, the dump configuration is added after all
 * existing dump configurations.
 *
 * Otherwise, the new configuration is inserted into the fallback dump list at
 * index 'kda_index'.
 */
#define	KDA_REMOVE		UINT8_MAX
#define	KDA_REMOVE_ALL		(UINT8_MAX - 1)
#define	KDA_REMOVE_DEV		(UINT8_MAX - 2)
#define	KDA_APPEND		(UINT8_MAX - 3)
struct diocskerneldump_arg {
	uint8_t		 kda_index;
	uint8_t		 kda_compression;
	uint8_t		 kda_encryption;
	uint8_t		 kda_key[KERNELDUMP_KEY_MAX_SIZE];
	uint32_t	 kda_encryptedkeysize;
	uint8_t		*kda_encryptedkey;
	char		 kda_iface[IFNAMSIZ];
	union kd_ip	 kda_server;
	union kd_ip	 kda_client;
	union kd_ip	 kda_gateway;
	uint8_t		 kda_af;
};
#define	DIOCSKERNELDUMP _IOW('d', 145, struct diocskerneldump_arg)
	/*
	 * Enable/Disable the device for kernel core dumps.
	 */

#define	DIOCGKERNELDUMP _IOWR('d', 146, struct diocskerneldump_arg)
	/*
	 * Get current kernel netdump configuration details for a given index.
	 */
#endif

#endif /* _SYS_DISK_H_ */