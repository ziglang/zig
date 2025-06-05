/*-
 *  COPYRIGHT (C) 1986 Gary S. Brown.  You may use this program, or
 *  code or tables extracted from it, as desired without restriction.
 */

#ifndef _SYS_GSB_CRC32_H_
#define _SYS_GSB_CRC32_H_

#include <sys/types.h>

#ifdef _KERNEL

extern const uint32_t crc32_tab[];

static __inline uint32_t
crc32_raw(const void *buf, size_t size, uint32_t crc)
{
	const uint8_t *p = (const uint8_t *)buf;

	while (size--)
		crc = crc32_tab[(crc ^ *p++) & 0xFF] ^ (crc >> 8);
	return (crc);
}

static __inline uint32_t
crc32(const void *buf, size_t size)
{
	uint32_t crc;

	crc = crc32_raw(buf, size, ~0U);
	return (crc ^ ~0U);
}
#endif

uint32_t calculate_crc32c(uint32_t crc32c, const unsigned char *buffer,
    unsigned int length);

#if defined(__amd64__) || defined(__i386__)
uint32_t sse42_crc32c(uint32_t, const unsigned char *, unsigned);
#endif
#if defined(__aarch64__)
uint32_t armv8_crc32c(uint32_t, const unsigned char *, unsigned int);
#endif

#ifdef TESTING
uint32_t singletable_crc32c(uint32_t, const void *, size_t);
uint32_t multitable_crc32c(uint32_t, const void *, size_t);
#endif

#endif /* !_SYS_GSB_CRC32_H_ */