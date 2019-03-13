#ifndef CRYPT_DES_H
#define CRYPT_DES_H

#include <stdint.h>

struct expanded_key {
	uint32_t l[16], r[16];
};

hidden void __des_setkey(const unsigned char *, struct expanded_key *);
hidden void __do_des(uint32_t, uint32_t, uint32_t *, uint32_t *,
                     uint32_t, uint32_t, const struct expanded_key *);

#endif
