#include <assert.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>

#define RNG_RESERVE_LEN 512

#define CHACHA20_KEYBYTES 32
#define CHACHA20_BLOCKBYTES 64

#define ROTL32(x, b) (uint32_t)(((x) << (b)) | ((x) >> (32 - (b))))

#define CHACHA20_QUARTERROUND(A, B, C, D) \
    A += B;                               \
    D = ROTL32(D ^ A, 16);                \
    C += D;                               \
    B = ROTL32(B ^ C, 12);                \
    A += B;                               \
    D = ROTL32(D ^ A, 8);                 \
    C += D;                               \
    B = ROTL32(B ^ C, 7)

static void CHACHA20_ROUNDS(uint32_t st[16])
{
    int i;

    for (i = 0; i < 20; i += 2) {
        CHACHA20_QUARTERROUND(st[0], st[4], st[8], st[12]);
        CHACHA20_QUARTERROUND(st[1], st[5], st[9], st[13]);
        CHACHA20_QUARTERROUND(st[2], st[6], st[10], st[14]);
        CHACHA20_QUARTERROUND(st[3], st[7], st[11], st[15]);
        CHACHA20_QUARTERROUND(st[0], st[5], st[10], st[15]);
        CHACHA20_QUARTERROUND(st[1], st[6], st[11], st[12]);
        CHACHA20_QUARTERROUND(st[2], st[7], st[8], st[13]);
        CHACHA20_QUARTERROUND(st[3], st[4], st[9], st[14]);
    }
}

static void chacha20_update(uint8_t out[CHACHA20_BLOCKBYTES], uint32_t st[16])
{
    uint32_t ks[16];
    int i;

    memcpy(ks, st, 4 * 16);
    CHACHA20_ROUNDS(st);
    for (i = 0; i < 16; i++) {
        ks[i] += st[i];
    }
    memcpy(out, ks, CHACHA20_BLOCKBYTES);
    st[12]++;
}

static void chacha20_init(uint32_t st[16], const uint8_t key[CHACHA20_KEYBYTES])
{
    static const uint32_t constants[4] = { 0x61707865, 0x3320646e, 0x79622d32, 0x6b206574 };
    memcpy(&st[0], constants, 4 * 4);
    memcpy(&st[4], key, CHACHA20_KEYBYTES);
    memset(&st[12], 0, 4 * 4);
}

static int chacha20_rng(uint8_t* out, size_t len, uint8_t key[CHACHA20_KEYBYTES])
{
    uint32_t st[16];
    size_t off;

    chacha20_init(st, key);
    chacha20_update(&out[0], st);
    memcpy(key, out, CHACHA20_KEYBYTES);
    off = 0;
    while (len >= CHACHA20_BLOCKBYTES) {
        chacha20_update(&out[off], st);
        len -= CHACHA20_BLOCKBYTES;
        off += CHACHA20_BLOCKBYTES;
    }
    if (len > 0) {
        uint8_t tmp[CHACHA20_BLOCKBYTES];
        chacha20_update(tmp, st);
        memcpy(&out[off], tmp, len);
    }
    return 0;
}

struct rng_state {
    int initialized;
    size_t off;
    uint8_t key[CHACHA20_KEYBYTES];
    uint8_t reserve[RNG_RESERVE_LEN];
};

void arc4random_buf(void* buffer, size_t len)
{
    static _Thread_local struct rng_state rng_state;

    unsigned char* buffer_ = (unsigned char*)buffer;
    size_t off;
    size_t remaining;
    size_t partial;

    if (!rng_state.initialized) {
        if (getentropy(rng_state.key, sizeof rng_state.key) != 0) {
            assert(0);
        }
        rng_state.off = RNG_RESERVE_LEN;
        rng_state.initialized = 1;
    }
    off = 0;
    remaining = len;
    while (remaining > 0) {
        if (rng_state.off == RNG_RESERVE_LEN) {
            while (remaining >= RNG_RESERVE_LEN) {
                chacha20_rng(&buffer_[off], RNG_RESERVE_LEN, rng_state.key);
                off += RNG_RESERVE_LEN;
                remaining -= RNG_RESERVE_LEN;
            }
            if (remaining == 0) {
                break;
            }
            chacha20_rng(&rng_state.reserve[0], RNG_RESERVE_LEN, rng_state.key);
            rng_state.off = 0;
        }
        partial = RNG_RESERVE_LEN - rng_state.off;
        if (remaining < partial) {
            partial = remaining;
        }
        memcpy(&buffer_[off], &rng_state.reserve[rng_state.off], partial);
        memset(&rng_state.reserve[rng_state.off], 0, partial);
        rng_state.off += partial;
        remaining -= partial;
        off += partial;
    }
}

uint32_t arc4random(void)
{
    uint32_t v;

    arc4random_buf(&v, sizeof v);

    return v;
}

uint32_t arc4random_uniform(const uint32_t upper_bound)
{
    uint32_t min;
    uint32_t r;

    if (upper_bound < 2U) {
        return 0;
    }
    min = (1U + ~upper_bound) % upper_bound; // = 2**32 mod upper_bound
    do {
        r = arc4random();
    } while (r < min);

    // r is now clamped to a set whose size mod upper_bound == 0.
    // The worst case (2**31+1) requires 2 attempts on average.

    return r % upper_bound;
}
