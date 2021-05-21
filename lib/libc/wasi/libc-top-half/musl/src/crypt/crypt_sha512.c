/*
 * public domain sha512 crypt implementation
 *
 * original sha crypt design: http://people.redhat.com/drepper/SHA-crypt.txt
 * in this implementation at least 32bit int is assumed,
 * key length is limited, the $6$ prefix is mandatory, '\n' and ':' is rejected
 * in the salt and rounds= setting must contain a valid iteration count,
 * on error "*" is returned.
 */
#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>

/* public domain sha512 implementation based on fips180-3 */
/* >=2^64 bits messages are not supported (about 2000 peta bytes) */

struct sha512 {
	uint64_t len;     /* processed message length */
	uint64_t h[8];    /* hash state */
	uint8_t buf[128]; /* message block buffer */
};

static uint64_t ror(uint64_t n, int k) { return (n >> k) | (n << (64-k)); }
#define Ch(x,y,z)  (z ^ (x & (y ^ z)))
#define Maj(x,y,z) ((x & y) | (z & (x | y)))
#define S0(x)      (ror(x,28) ^ ror(x,34) ^ ror(x,39))
#define S1(x)      (ror(x,14) ^ ror(x,18) ^ ror(x,41))
#define R0(x)      (ror(x,1) ^ ror(x,8) ^ (x>>7))
#define R1(x)      (ror(x,19) ^ ror(x,61) ^ (x>>6))

static const uint64_t K[80] = {
0x428a2f98d728ae22ULL, 0x7137449123ef65cdULL, 0xb5c0fbcfec4d3b2fULL, 0xe9b5dba58189dbbcULL,
0x3956c25bf348b538ULL, 0x59f111f1b605d019ULL, 0x923f82a4af194f9bULL, 0xab1c5ed5da6d8118ULL,
0xd807aa98a3030242ULL, 0x12835b0145706fbeULL, 0x243185be4ee4b28cULL, 0x550c7dc3d5ffb4e2ULL,
0x72be5d74f27b896fULL, 0x80deb1fe3b1696b1ULL, 0x9bdc06a725c71235ULL, 0xc19bf174cf692694ULL,
0xe49b69c19ef14ad2ULL, 0xefbe4786384f25e3ULL, 0x0fc19dc68b8cd5b5ULL, 0x240ca1cc77ac9c65ULL,
0x2de92c6f592b0275ULL, 0x4a7484aa6ea6e483ULL, 0x5cb0a9dcbd41fbd4ULL, 0x76f988da831153b5ULL,
0x983e5152ee66dfabULL, 0xa831c66d2db43210ULL, 0xb00327c898fb213fULL, 0xbf597fc7beef0ee4ULL,
0xc6e00bf33da88fc2ULL, 0xd5a79147930aa725ULL, 0x06ca6351e003826fULL, 0x142929670a0e6e70ULL,
0x27b70a8546d22ffcULL, 0x2e1b21385c26c926ULL, 0x4d2c6dfc5ac42aedULL, 0x53380d139d95b3dfULL,
0x650a73548baf63deULL, 0x766a0abb3c77b2a8ULL, 0x81c2c92e47edaee6ULL, 0x92722c851482353bULL,
0xa2bfe8a14cf10364ULL, 0xa81a664bbc423001ULL, 0xc24b8b70d0f89791ULL, 0xc76c51a30654be30ULL,
0xd192e819d6ef5218ULL, 0xd69906245565a910ULL, 0xf40e35855771202aULL, 0x106aa07032bbd1b8ULL,
0x19a4c116b8d2d0c8ULL, 0x1e376c085141ab53ULL, 0x2748774cdf8eeb99ULL, 0x34b0bcb5e19b48a8ULL,
0x391c0cb3c5c95a63ULL, 0x4ed8aa4ae3418acbULL, 0x5b9cca4f7763e373ULL, 0x682e6ff3d6b2b8a3ULL,
0x748f82ee5defb2fcULL, 0x78a5636f43172f60ULL, 0x84c87814a1f0ab72ULL, 0x8cc702081a6439ecULL,
0x90befffa23631e28ULL, 0xa4506cebde82bde9ULL, 0xbef9a3f7b2c67915ULL, 0xc67178f2e372532bULL,
0xca273eceea26619cULL, 0xd186b8c721c0c207ULL, 0xeada7dd6cde0eb1eULL, 0xf57d4f7fee6ed178ULL,
0x06f067aa72176fbaULL, 0x0a637dc5a2c898a6ULL, 0x113f9804bef90daeULL, 0x1b710b35131c471bULL,
0x28db77f523047d84ULL, 0x32caab7b40c72493ULL, 0x3c9ebe0a15c9bebcULL, 0x431d67c49c100d4cULL,
0x4cc5d4becb3e42b6ULL, 0x597f299cfc657e2aULL, 0x5fcb6fab3ad6faecULL, 0x6c44198c4a475817ULL
};

static void processblock(struct sha512 *s, const uint8_t *buf)
{
	uint64_t W[80], t1, t2, a, b, c, d, e, f, g, h;
	int i;

	for (i = 0; i < 16; i++) {
		W[i] = (uint64_t)buf[8*i]<<56;
		W[i] |= (uint64_t)buf[8*i+1]<<48;
		W[i] |= (uint64_t)buf[8*i+2]<<40;
		W[i] |= (uint64_t)buf[8*i+3]<<32;
		W[i] |= (uint64_t)buf[8*i+4]<<24;
		W[i] |= (uint64_t)buf[8*i+5]<<16;
		W[i] |= (uint64_t)buf[8*i+6]<<8;
		W[i] |= buf[8*i+7];
	}
	for (; i < 80; i++)
		W[i] = R1(W[i-2]) + W[i-7] + R0(W[i-15]) + W[i-16];
	a = s->h[0];
	b = s->h[1];
	c = s->h[2];
	d = s->h[3];
	e = s->h[4];
	f = s->h[5];
	g = s->h[6];
	h = s->h[7];
	for (i = 0; i < 80; i++) {
		t1 = h + S1(e) + Ch(e,f,g) + K[i] + W[i];
		t2 = S0(a) + Maj(a,b,c);
		h = g;
		g = f;
		f = e;
		e = d + t1;
		d = c;
		c = b;
		b = a;
		a = t1 + t2;
	}
	s->h[0] += a;
	s->h[1] += b;
	s->h[2] += c;
	s->h[3] += d;
	s->h[4] += e;
	s->h[5] += f;
	s->h[6] += g;
	s->h[7] += h;
}

static void pad(struct sha512 *s)
{
	unsigned r = s->len % 128;

	s->buf[r++] = 0x80;
	if (r > 112) {
		memset(s->buf + r, 0, 128 - r);
		r = 0;
		processblock(s, s->buf);
	}
	memset(s->buf + r, 0, 120 - r);
	s->len *= 8;
	s->buf[120] = s->len >> 56;
	s->buf[121] = s->len >> 48;
	s->buf[122] = s->len >> 40;
	s->buf[123] = s->len >> 32;
	s->buf[124] = s->len >> 24;
	s->buf[125] = s->len >> 16;
	s->buf[126] = s->len >> 8;
	s->buf[127] = s->len;
	processblock(s, s->buf);
}

static void sha512_init(struct sha512 *s)
{
	s->len = 0;
	s->h[0] = 0x6a09e667f3bcc908ULL;
	s->h[1] = 0xbb67ae8584caa73bULL;
	s->h[2] = 0x3c6ef372fe94f82bULL;
	s->h[3] = 0xa54ff53a5f1d36f1ULL;
	s->h[4] = 0x510e527fade682d1ULL;
	s->h[5] = 0x9b05688c2b3e6c1fULL;
	s->h[6] = 0x1f83d9abfb41bd6bULL;
	s->h[7] = 0x5be0cd19137e2179ULL;
}

static void sha512_sum(struct sha512 *s, uint8_t *md)
{
	int i;

	pad(s);
	for (i = 0; i < 8; i++) {
		md[8*i] = s->h[i] >> 56;
		md[8*i+1] = s->h[i] >> 48;
		md[8*i+2] = s->h[i] >> 40;
		md[8*i+3] = s->h[i] >> 32;
		md[8*i+4] = s->h[i] >> 24;
		md[8*i+5] = s->h[i] >> 16;
		md[8*i+6] = s->h[i] >> 8;
		md[8*i+7] = s->h[i];
	}
}

static void sha512_update(struct sha512 *s, const void *m, unsigned long len)
{
	const uint8_t *p = m;
	unsigned r = s->len % 128;

	s->len += len;
	if (r) {
		if (len < 128 - r) {
			memcpy(s->buf + r, p, len);
			return;
		}
		memcpy(s->buf + r, p, 128 - r);
		len -= 128 - r;
		p += 128 - r;
		processblock(s, s->buf);
	}
	for (; len >= 128; len -= 128, p += 128)
		processblock(s, p);
	memcpy(s->buf, p, len);
}

static const unsigned char b64[] =
"./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

static char *to64(char *s, unsigned int u, int n)
{
	while (--n >= 0) {
		*s++ = b64[u % 64];
		u /= 64;
	}
	return s;
}

/* key limit is not part of the original design, added for DoS protection.
 * rounds limit has been lowered (versus the reference/spec), also for DoS
 * protection. runtime is O(klen^2 + klen*rounds) */
#define KEY_MAX 256
#define SALT_MAX 16
#define ROUNDS_DEFAULT 5000
#define ROUNDS_MIN 1000
#define ROUNDS_MAX 9999999

/* hash n bytes of the repeated md message digest */
static void hashmd(struct sha512 *s, unsigned int n, const void *md)
{
	unsigned int i;

	for (i = n; i > 64; i -= 64)
		sha512_update(s, md, 64);
	sha512_update(s, md, i);
}

static char *sha512crypt(const char *key, const char *setting, char *output)
{
	struct sha512 ctx;
	unsigned char md[64], kmd[64], smd[64];
	unsigned int i, r, klen, slen;
	char rounds[20] = "";
	const char *salt;
	char *p;

	/* reject large keys */
	for (i = 0; i <= KEY_MAX && key[i]; i++);
	if (i > KEY_MAX)
		return 0;
	klen = i;

	/* setting: $6$rounds=n$salt$ (rounds=n$ and closing $ are optional) */
	if (strncmp(setting, "$6$", 3) != 0)
		return 0;
	salt = setting + 3;

	r = ROUNDS_DEFAULT;
	if (strncmp(salt, "rounds=", sizeof "rounds=" - 1) == 0) {
		unsigned long u;
		char *end;

		/*
		 * this is a deviation from the reference:
		 * bad rounds setting is rejected if it is
		 * - empty
		 * - unterminated (missing '$')
		 * - begins with anything but a decimal digit
		 * the reference implementation treats these bad
		 * rounds as part of the salt or parse them with
		 * strtoul semantics which may cause problems
		 * including non-portable hashes that depend on
		 * the host's value of ULONG_MAX.
		 */
		salt += sizeof "rounds=" - 1;
		if (!isdigit(*salt))
			return 0;
		u = strtoul(salt, &end, 10);
		if (*end != '$')
			return 0;
		salt = end+1;
		if (u < ROUNDS_MIN)
			r = ROUNDS_MIN;
		else if (u > ROUNDS_MAX)
			return 0;
		else
			r = u;
		/* needed when rounds is zero prefixed or out of bounds */
		sprintf(rounds, "rounds=%u$", r);
	}

	for (i = 0; i < SALT_MAX && salt[i] && salt[i] != '$'; i++)
		/* reject characters that interfere with /etc/shadow parsing */
		if (salt[i] == '\n' || salt[i] == ':')
			return 0;
	slen = i;

	/* B = sha(key salt key) */
	sha512_init(&ctx);
	sha512_update(&ctx, key, klen);
	sha512_update(&ctx, salt, slen);
	sha512_update(&ctx, key, klen);
	sha512_sum(&ctx, md);

	/* A = sha(key salt repeat-B alternate-B-key) */
	sha512_init(&ctx);
	sha512_update(&ctx, key, klen);
	sha512_update(&ctx, salt, slen);
	hashmd(&ctx, klen, md);
	for (i = klen; i > 0; i >>= 1)
		if (i & 1)
			sha512_update(&ctx, md, sizeof md);
		else
			sha512_update(&ctx, key, klen);
	sha512_sum(&ctx, md);

	/* DP = sha(repeat-key), this step takes O(klen^2) time */
	sha512_init(&ctx);
	for (i = 0; i < klen; i++)
		sha512_update(&ctx, key, klen);
	sha512_sum(&ctx, kmd);

	/* DS = sha(repeat-salt) */
	sha512_init(&ctx);
	for (i = 0; i < 16 + md[0]; i++)
		sha512_update(&ctx, salt, slen);
	sha512_sum(&ctx, smd);

	/* iterate A = f(A,DP,DS), this step takes O(rounds*klen) time */
	for (i = 0; i < r; i++) {
		sha512_init(&ctx);
		if (i % 2)
			hashmd(&ctx, klen, kmd);
		else
			sha512_update(&ctx, md, sizeof md);
		if (i % 3)
			sha512_update(&ctx, smd, slen);
		if (i % 7)
			hashmd(&ctx, klen, kmd);
		if (i % 2)
			sha512_update(&ctx, md, sizeof md);
		else
			hashmd(&ctx, klen, kmd);
		sha512_sum(&ctx, md);
	}

	/* output is $6$rounds=n$salt$hash */
	p = output;
	p += sprintf(p, "$6$%s%.*s$", rounds, slen, salt);
#if 1
	static const unsigned char perm[][3] = {
		0,21,42,22,43,1,44,2,23,3,24,45,25,46,4,
		47,5,26,6,27,48,28,49,7,50,8,29,9,30,51,
		31,52,10,53,11,32,12,33,54,34,55,13,56,14,35,
		15,36,57,37,58,16,59,17,38,18,39,60,40,61,19,
		62,20,41 };
	for (i=0; i<21; i++) p = to64(p,
		(md[perm[i][0]]<<16)|(md[perm[i][1]]<<8)|md[perm[i][2]], 4);
#else
	p = to64(p, (md[0]<<16)|(md[21]<<8)|md[42], 4);
	p = to64(p, (md[22]<<16)|(md[43]<<8)|md[1], 4);
	p = to64(p, (md[44]<<16)|(md[2]<<8)|md[23], 4);
	p = to64(p, (md[3]<<16)|(md[24]<<8)|md[45], 4);
	p = to64(p, (md[25]<<16)|(md[46]<<8)|md[4], 4);
	p = to64(p, (md[47]<<16)|(md[5]<<8)|md[26], 4);
	p = to64(p, (md[6]<<16)|(md[27]<<8)|md[48], 4);
	p = to64(p, (md[28]<<16)|(md[49]<<8)|md[7], 4);
	p = to64(p, (md[50]<<16)|(md[8]<<8)|md[29], 4);
	p = to64(p, (md[9]<<16)|(md[30]<<8)|md[51], 4);
	p = to64(p, (md[31]<<16)|(md[52]<<8)|md[10], 4);
	p = to64(p, (md[53]<<16)|(md[11]<<8)|md[32], 4);
	p = to64(p, (md[12]<<16)|(md[33]<<8)|md[54], 4);
	p = to64(p, (md[34]<<16)|(md[55]<<8)|md[13], 4);
	p = to64(p, (md[56]<<16)|(md[14]<<8)|md[35], 4);
	p = to64(p, (md[15]<<16)|(md[36]<<8)|md[57], 4);
	p = to64(p, (md[37]<<16)|(md[58]<<8)|md[16], 4);
	p = to64(p, (md[59]<<16)|(md[17]<<8)|md[38], 4);
	p = to64(p, (md[18]<<16)|(md[39]<<8)|md[60], 4);
	p = to64(p, (md[40]<<16)|(md[61]<<8)|md[19], 4);
	p = to64(p, (md[62]<<16)|(md[20]<<8)|md[41], 4);
#endif
	p = to64(p, md[63], 2);
	*p = 0;
	return output;
}

char *__crypt_sha512(const char *key, const char *setting, char *output)
{
	static const char testkey[] = "Xy01@#\x01\x02\x80\x7f\xff\r\n\x81\t !";
	static const char testsetting[] = "$6$rounds=1234$abc0123456789$";
	static const char testhash[] = "$6$rounds=1234$abc0123456789$BCpt8zLrc/RcyuXmCDOE1ALqMXB2MH6n1g891HhFj8.w7LxGv.FTkqq6Vxc/km3Y0jE0j24jY5PIv/oOu6reg1";
	char testbuf[128];
	char *p, *q;

	p = sha512crypt(key, setting, output);
	/* self test and stack cleanup */
	q = sha512crypt(testkey, testsetting, testbuf);
	if (!p || q != testbuf || memcmp(testbuf, testhash, sizeof testhash))
		return "*";
	return p;
}
