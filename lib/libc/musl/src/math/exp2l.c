/* origin: FreeBSD /usr/src/lib/msun/ld80/s_exp2l.c and /usr/src/lib/msun/ld128/s_exp2l.c */
/*-
 * Copyright (c) 2005-2008 David Schultz <das@FreeBSD.ORG>
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

#include "libm.h"

#if LDBL_MANT_DIG == 53 && LDBL_MAX_EXP == 1024
long double exp2l(long double x)
{
	return exp2(x);
}
#elif LDBL_MANT_DIG == 64 && LDBL_MAX_EXP == 16384
#define TBLBITS 7
#define TBLSIZE (1 << TBLBITS)

static const double
redux = 0x1.8p63 / TBLSIZE,
P1    = 0x1.62e42fefa39efp-1,
P2    = 0x1.ebfbdff82c58fp-3,
P3    = 0x1.c6b08d7049fap-5,
P4    = 0x1.3b2ab6fba4da5p-7,
P5    = 0x1.5d8804780a736p-10,
P6    = 0x1.430918835e33dp-13;

static const double tbl[TBLSIZE * 2] = {
	0x1.6a09e667f3bcdp-1,   -0x1.bdd3413b2648p-55,
	0x1.6c012750bdabfp-1,   -0x1.2895667ff0cp-57,
	0x1.6dfb23c651a2fp-1,   -0x1.bbe3a683c88p-58,
	0x1.6ff7df9519484p-1,   -0x1.83c0f25860fp-56,
	0x1.71f75e8ec5f74p-1,   -0x1.16e4786887bp-56,
	0x1.73f9a48a58174p-1,   -0x1.0a8d96c65d5p-55,
	0x1.75feb564267c9p-1,   -0x1.0245957316ep-55,
	0x1.780694fde5d3fp-1,    0x1.866b80a0216p-55,
	0x1.7a11473eb0187p-1,   -0x1.41577ee0499p-56,
	0x1.7c1ed0130c132p-1,    0x1.f124cd1164ep-55,
	0x1.7e2f336cf4e62p-1,    0x1.05d02ba157ap-57,
	0x1.80427543e1a12p-1,   -0x1.27c86626d97p-55,
	0x1.82589994cce13p-1,   -0x1.d4c1dd41533p-55,
	0x1.8471a4623c7adp-1,   -0x1.8d684a341cep-56,
	0x1.868d99b4492edp-1,   -0x1.fc6f89bd4f68p-55,
	0x1.88ac7d98a6699p-1,    0x1.994c2f37cb5p-55,
	0x1.8ace5422aa0dbp-1,    0x1.6e9f156864bp-55,
	0x1.8cf3216b5448cp-1,   -0x1.0d55e32e9e4p-57,
	0x1.8f1ae99157736p-1,    0x1.5cc13a2e397p-56,
	0x1.9145b0b91ffc6p-1,   -0x1.dd6792e5825p-55,
	0x1.93737b0cdc5e5p-1,   -0x1.75fc781b58p-58,
	0x1.95a44cbc8520fp-1,   -0x1.64b7c96a5fp-57,
	0x1.97d829fde4e5p-1,    -0x1.d185b7c1b86p-55,
	0x1.9a0f170ca07bap-1,   -0x1.173bd91cee6p-55,
	0x1.9c49182a3f09p-1,     0x1.c7c46b071f2p-57,
	0x1.9e86319e32323p-1,    0x1.824ca78e64cp-57,
	0x1.a0c667b5de565p-1,   -0x1.359495d1cd5p-55,
	0x1.a309bec4a2d33p-1,    0x1.6305c7ddc368p-55,
	0x1.a5503b23e255dp-1,   -0x1.d2f6edb8d42p-55,
	0x1.a799e1330b358p-1,    0x1.bcb7ecac564p-55,
	0x1.a9e6b5579fdbfp-1,    0x1.0fac90ef7fdp-55,
	0x1.ac36bbfd3f37ap-1,   -0x1.f9234cae76dp-56,
	0x1.ae89f995ad3adp-1,    0x1.7a1cd345dcc8p-55,
	0x1.b0e07298db666p-1,   -0x1.bdef54c80e4p-55,
	0x1.b33a2b84f15fbp-1,   -0x1.2805e3084d8p-58,
	0x1.b59728de5593ap-1,   -0x1.c71dfbbba6ep-55,
	0x1.b7f76f2fb5e47p-1,   -0x1.5584f7e54acp-57,
	0x1.ba5b030a1064ap-1,   -0x1.efcd30e5429p-55,
	0x1.bcc1e904bc1d2p-1,    0x1.23dd07a2d9fp-56,
	0x1.bf2c25bd71e09p-1,   -0x1.efdca3f6b9c8p-55,
	0x1.c199bdd85529cp-1,    0x1.11065895049p-56,
	0x1.c40ab5fffd07ap-1,    0x1.b4537e083c6p-55,
	0x1.c67f12e57d14bp-1,    0x1.2884dff483c8p-55,
	0x1.c8f6d9406e7b5p-1,    0x1.1acbc48805cp-57,
	0x1.cb720dcef9069p-1,    0x1.503cbd1e94ap-57,
	0x1.cdf0b555dc3fap-1,   -0x1.dd83b53829dp-56,
	0x1.d072d4a07897cp-1,   -0x1.cbc3743797a8p-55,
	0x1.d2f87080d89f2p-1,   -0x1.d487b719d858p-55,
	0x1.d5818dcfba487p-1,    0x1.2ed02d75b37p-56,
	0x1.d80e316c98398p-1,   -0x1.11ec18bedep-55,
	0x1.da9e603db3285p-1,    0x1.c2300696db5p-55,
	0x1.dd321f301b46p-1,     0x1.2da5778f019p-55,
	0x1.dfc97337b9b5fp-1,   -0x1.1a5cd4f184b8p-55,
	0x1.e264614f5a129p-1,   -0x1.7b627817a148p-55,
	0x1.e502ee78b3ff6p-1,    0x1.39e8980a9cdp-56,
	0x1.e7a51fbc74c83p-1,    0x1.2d522ca0c8ep-55,
	0x1.ea4afa2a490dap-1,   -0x1.e9c23179c288p-55,
	0x1.ecf482d8e67f1p-1,   -0x1.c93f3b411ad8p-55,
	0x1.efa1bee615a27p-1,    0x1.dc7f486a4b68p-55,
	0x1.f252b376bba97p-1,    0x1.3a1a5bf0d8e8p-55,
	0x1.f50765b6e454p-1,     0x1.9d3e12dd8a18p-55,
	0x1.f7bfdad9cbe14p-1,   -0x1.dbb12d00635p-55,
	0x1.fa7c1819e90d8p-1,    0x1.74853f3a593p-56,
	0x1.fd3c22b8f71f1p-1,    0x1.2eb74966578p-58,
	0x1p+0,                  0x0p+0,
	0x1.0163da9fb3335p+0,    0x1.b61299ab8cd8p-54,
	0x1.02c9a3e778061p+0,   -0x1.19083535b08p-56,
	0x1.04315e86e7f85p+0,   -0x1.0a31c1977c98p-54,
	0x1.059b0d3158574p+0,    0x1.d73e2a475b4p-55,
	0x1.0706b29ddf6dep+0,   -0x1.c91dfe2b13cp-55,
	0x1.0874518759bc8p+0,    0x1.186be4bb284p-57,
	0x1.09e3ecac6f383p+0,    0x1.14878183161p-54,
	0x1.0b5586cf9890fp+0,    0x1.8a62e4adc61p-54,
	0x1.0cc922b7247f7p+0,    0x1.01edc16e24f8p-54,
	0x1.0e3ec32d3d1a2p+0,    0x1.03a1727c58p-59,
	0x1.0fb66affed31bp+0,   -0x1.b9bedc44ebcp-57,
	0x1.11301d0125b51p+0,   -0x1.6c51039449bp-54,
	0x1.12abdc06c31ccp+0,   -0x1.1b514b36ca8p-58,
	0x1.1429aaea92dep+0,    -0x1.32fbf9af1368p-54,
	0x1.15a98c8a58e51p+0,    0x1.2406ab9eeabp-55,
	0x1.172b83c7d517bp+0,   -0x1.19041b9d78ap-55,
	0x1.18af9388c8deap+0,   -0x1.11023d1970f8p-54,
	0x1.1a35beb6fcb75p+0,    0x1.e5b4c7b4969p-55,
	0x1.1bbe084045cd4p+0,   -0x1.95386352ef6p-54,
	0x1.1d4873168b9aap+0,    0x1.e016e00a264p-54,
	0x1.1ed5022fcd91dp+0,   -0x1.1df98027bb78p-54,
	0x1.2063b88628cd6p+0,    0x1.dc775814a85p-55,
	0x1.21f49917ddc96p+0,    0x1.2a97e9494a6p-55,
	0x1.2387a6e756238p+0,    0x1.9b07eb6c7058p-54,
	0x1.251ce4fb2a63fp+0,    0x1.ac155bef4f5p-55,
	0x1.26b4565e27cddp+0,    0x1.2bd339940eap-55,
	0x1.284dfe1f56381p+0,   -0x1.a4c3a8c3f0d8p-54,
	0x1.29e9df51fdee1p+0,    0x1.612e8afad12p-55,
	0x1.2b87fd0dad99p+0,    -0x1.10adcd6382p-59,
	0x1.2d285a6e4030bp+0,    0x1.0024754db42p-54,
	0x1.2ecafa93e2f56p+0,    0x1.1ca0f45d524p-56,
	0x1.306fe0a31b715p+0,    0x1.6f46ad23183p-55,
	0x1.32170fc4cd831p+0,    0x1.a9ce78e1804p-55,
	0x1.33c08b26416ffp+0,    0x1.327218436598p-54,
	0x1.356c55f929ff1p+0,   -0x1.b5cee5c4e46p-55,
	0x1.371a7373aa9cbp+0,   -0x1.63aeabf42ebp-54,
	0x1.38cae6d05d866p+0,   -0x1.e958d3c99048p-54,
	0x1.3a7db34e59ff7p+0,   -0x1.5e436d661f6p-56,
	0x1.3c32dc313a8e5p+0,   -0x1.efff8375d2ap-54,
	0x1.3dea64c123422p+0,    0x1.ada0911f09fp-55,
	0x1.3fa4504ac801cp+0,   -0x1.7d023f956fap-54,
	0x1.4160a21f72e2ap+0,   -0x1.ef3691c309p-58,
	0x1.431f5d950a897p+0,   -0x1.1c7dde35f7ap-55,
	0x1.44e086061892dp+0,    0x1.89b7a04ef8p-59,
	0x1.46a41ed1d0057p+0,    0x1.c944bd1648a8p-54,
	0x1.486a2b5c13cdp+0,     0x1.3c1a3b69062p-56,
	0x1.4a32af0d7d3dep+0,    0x1.9cb62f3d1be8p-54,
	0x1.4bfdad5362a27p+0,    0x1.d4397afec42p-56,
	0x1.4dcb299fddd0dp+0,    0x1.8ecdbbc6a78p-54,
	0x1.4f9b2769d2ca7p+0,   -0x1.4b309d25958p-54,
	0x1.516daa2cf6642p+0,   -0x1.f768569bd94p-55,
	0x1.5342b569d4f82p+0,   -0x1.07abe1db13dp-55,
	0x1.551a4ca5d920fp+0,   -0x1.d689cefede6p-55,
	0x1.56f4736b527dap+0,    0x1.9bb2c011d938p-54,
	0x1.58d12d497c7fdp+0,    0x1.295e15b9a1ep-55,
	0x1.5ab07dd485429p+0,    0x1.6324c0546478p-54,
	0x1.5c9268a5946b7p+0,    0x1.c4b1b81698p-60,
	0x1.5e76f15ad2148p+0,    0x1.ba6f93080e68p-54,
	0x1.605e1b976dc09p+0,   -0x1.3e2429b56de8p-54,
	0x1.6247eb03a5585p+0,   -0x1.383c17e40b48p-54,
	0x1.6434634ccc32p+0,    -0x1.c483c759d89p-55,
	0x1.6623882552225p+0,   -0x1.bb60987591cp-54,
	0x1.68155d44ca973p+0,    0x1.038ae44f74p-57,
};

/*
 * exp2l(x): compute the base 2 exponential of x
 *
 * Accuracy: Peak error < 0.511 ulp.
 *
 * Method: (equally-spaced tables)
 *
 *   Reduce x:
 *     x = 2**k + y, for integer k and |y| <= 1/2.
 *     Thus we have exp2l(x) = 2**k * exp2(y).
 *
 *   Reduce y:
 *     y = i/TBLSIZE + z for integer i near y * TBLSIZE.
 *     Thus we have exp2(y) = exp2(i/TBLSIZE) * exp2(z),
 *     with |z| <= 2**-(TBLBITS+1).
 *
 *   We compute exp2(i/TBLSIZE) via table lookup and exp2(z) via a
 *   degree-6 minimax polynomial with maximum error under 2**-69.
 *   The table entries each have 104 bits of accuracy, encoded as
 *   a pair of double precision values.
 */
long double exp2l(long double x)
{
	union ldshape u = {x};
	int e = u.i.se & 0x7fff;
	long double r, z;
	uint32_t i0;
	union {uint32_t u; int32_t i;} k;

	/* Filter out exceptional cases. */
	if (e >= 0x3fff + 13) {  /* |x| >= 8192 or x is NaN */
		if (u.i.se >= 0x3fff + 14 && u.i.se >> 15 == 0)
			/* overflow */
			return x * 0x1p16383L;
		if (e == 0x7fff)  /* -inf or -nan */
			return -1/x;
		if (x < -16382) {
			if (x <= -16446 || x - 0x1p63 + 0x1p63 != x)
				/* underflow */
				FORCE_EVAL((float)(-0x1p-149/x));
			if (x <= -16446)
				return 0;
		}
	} else if (e < 0x3fff - 64) {
		return 1 + x;
	}

	/*
	 * Reduce x, computing z, i0, and k. The low bits of x + redux
	 * contain the 16-bit integer part of the exponent (k) followed by
	 * TBLBITS fractional bits (i0). We use bit tricks to extract these
	 * as integers, then set z to the remainder.
	 *
	 * Example: Suppose x is 0xabc.123456p0 and TBLBITS is 8.
	 * Then the low-order word of x + redux is 0x000abc12,
	 * We split this into k = 0xabc and i0 = 0x12 (adjusted to
	 * index into the table), then we compute z = 0x0.003456p0.
	 */
	u.f = x + redux;
	i0 = u.i.m + TBLSIZE / 2;
	k.u = i0 / TBLSIZE * TBLSIZE;
	k.i /= TBLSIZE;
	i0 %= TBLSIZE;
	u.f -= redux;
	z = x - u.f;

	/* Compute r = exp2l(y) = exp2lt[i0] * p(z). */
	long double t_hi = tbl[2*i0];
	long double t_lo = tbl[2*i0 + 1];
	/* XXX This gives > 1 ulp errors outside of FE_TONEAREST mode */
	r = t_lo + (t_hi + t_lo) * z * (P1 + z * (P2 + z * (P3 + z * (P4
	     + z * (P5 + z * P6))))) + t_hi;

	return scalbnl(r, k.i);
}
#elif LDBL_MANT_DIG == 113 && LDBL_MAX_EXP == 16384
#define TBLBITS 7
#define TBLSIZE (1 << TBLBITS)

static const long double
    P1        = 0x1.62e42fefa39ef35793c7673007e6p-1L,
    P2        = 0x1.ebfbdff82c58ea86f16b06ec9736p-3L,
    P3        = 0x1.c6b08d704a0bf8b33a762bad3459p-5L,
    P4        = 0x1.3b2ab6fba4e7729ccbbe0b4f3fc2p-7L,
    P5        = 0x1.5d87fe78a67311071dee13fd11d9p-10L,
    P6        = 0x1.430912f86c7876f4b663b23c5fe5p-13L;

static const double
    P7        = 0x1.ffcbfc588b041p-17,
    P8        = 0x1.62c0223a5c7c7p-20,
    P9        = 0x1.b52541ff59713p-24,
    P10       = 0x1.e4cf56a391e22p-28,
    redux     = 0x1.8p112 / TBLSIZE;

static const long double tbl[TBLSIZE] = {
	0x1.6a09e667f3bcc908b2fb1366dfeap-1L,
	0x1.6c012750bdabeed76a99800f4edep-1L,
	0x1.6dfb23c651a2ef220e2cbe1bc0d4p-1L,
	0x1.6ff7df9519483cf87e1b4f3e1e98p-1L,
	0x1.71f75e8ec5f73dd2370f2ef0b148p-1L,
	0x1.73f9a48a58173bd5c9a4e68ab074p-1L,
	0x1.75feb564267c8bf6e9aa33a489a8p-1L,
	0x1.780694fde5d3f619ae02808592a4p-1L,
	0x1.7a11473eb0186d7d51023f6ccb1ap-1L,
	0x1.7c1ed0130c1327c49334459378dep-1L,
	0x1.7e2f336cf4e62105d02ba1579756p-1L,
	0x1.80427543e1a11b60de67649a3842p-1L,
	0x1.82589994cce128acf88afab34928p-1L,
	0x1.8471a4623c7acce52f6b97c6444cp-1L,
	0x1.868d99b4492ec80e41d90ac2556ap-1L,
	0x1.88ac7d98a669966530bcdf2d4cc0p-1L,
	0x1.8ace5422aa0db5ba7c55a192c648p-1L,
	0x1.8cf3216b5448bef2aa1cd161c57ap-1L,
	0x1.8f1ae991577362b982745c72eddap-1L,
	0x1.9145b0b91ffc588a61b469f6b6a0p-1L,
	0x1.93737b0cdc5e4f4501c3f2540ae8p-1L,
	0x1.95a44cbc8520ee9b483695a0e7fep-1L,
	0x1.97d829fde4e4f8b9e920f91e8eb6p-1L,
	0x1.9a0f170ca07b9ba3109b8c467844p-1L,
	0x1.9c49182a3f0901c7c46b071f28dep-1L,
	0x1.9e86319e323231824ca78e64c462p-1L,
	0x1.a0c667b5de564b29ada8b8cabbacp-1L,
	0x1.a309bec4a2d3358c171f770db1f4p-1L,
	0x1.a5503b23e255c8b424491caf88ccp-1L,
	0x1.a799e1330b3586f2dfb2b158f31ep-1L,
	0x1.a9e6b5579fdbf43eb243bdff53a2p-1L,
	0x1.ac36bbfd3f379c0db966a3126988p-1L,
	0x1.ae89f995ad3ad5e8734d17731c80p-1L,
	0x1.b0e07298db66590842acdfc6fb4ep-1L,
	0x1.b33a2b84f15faf6bfd0e7bd941b0p-1L,
	0x1.b59728de559398e3881111648738p-1L,
	0x1.b7f76f2fb5e46eaa7b081ab53ff6p-1L,
	0x1.ba5b030a10649840cb3c6af5b74cp-1L,
	0x1.bcc1e904bc1d2247ba0f45b3d06cp-1L,
	0x1.bf2c25bd71e088408d7025190cd0p-1L,
	0x1.c199bdd85529c2220cb12a0916bap-1L,
	0x1.c40ab5fffd07a6d14df820f17deap-1L,
	0x1.c67f12e57d14b4a2137fd20f2a26p-1L,
	0x1.c8f6d9406e7b511acbc48805c3f6p-1L,
	0x1.cb720dcef90691503cbd1e949d0ap-1L,
	0x1.cdf0b555dc3f9c44f8958fac4f12p-1L,
	0x1.d072d4a07897b8d0f22f21a13792p-1L,
	0x1.d2f87080d89f18ade123989ea50ep-1L,
	0x1.d5818dcfba48725da05aeb66dff8p-1L,
	0x1.d80e316c98397bb84f9d048807a0p-1L,
	0x1.da9e603db3285708c01a5b6d480cp-1L,
	0x1.dd321f301b4604b695de3c0630c0p-1L,
	0x1.dfc97337b9b5eb968cac39ed284cp-1L,
	0x1.e264614f5a128a12761fa17adc74p-1L,
	0x1.e502ee78b3ff6273d130153992d0p-1L,
	0x1.e7a51fbc74c834b548b2832378a4p-1L,
	0x1.ea4afa2a490d9858f73a18f5dab4p-1L,
	0x1.ecf482d8e67f08db0312fb949d50p-1L,
	0x1.efa1bee615a27771fd21a92dabb6p-1L,
	0x1.f252b376bba974e8696fc3638f24p-1L,
	0x1.f50765b6e4540674f84b762861a6p-1L,
	0x1.f7bfdad9cbe138913b4bfe72bd78p-1L,
	0x1.fa7c1819e90d82e90a7e74b26360p-1L,
	0x1.fd3c22b8f71f10975ba4b32bd006p-1L,
	0x1.0000000000000000000000000000p+0L,
	0x1.0163da9fb33356d84a66ae336e98p+0L,
	0x1.02c9a3e778060ee6f7caca4f7a18p+0L,
	0x1.04315e86e7f84bd738f9a20da442p+0L,
	0x1.059b0d31585743ae7c548eb68c6ap+0L,
	0x1.0706b29ddf6ddc6dc403a9d87b1ep+0L,
	0x1.0874518759bc808c35f25d942856p+0L,
	0x1.09e3ecac6f3834521e060c584d5cp+0L,
	0x1.0b5586cf9890f6298b92b7184200p+0L,
	0x1.0cc922b7247f7407b705b893dbdep+0L,
	0x1.0e3ec32d3d1a2020742e4f8af794p+0L,
	0x1.0fb66affed31af232091dd8a169ep+0L,
	0x1.11301d0125b50a4ebbf1aed9321cp+0L,
	0x1.12abdc06c31cbfb92bad324d6f84p+0L,
	0x1.1429aaea92ddfb34101943b2588ep+0L,
	0x1.15a98c8a58e512480d573dd562aep+0L,
	0x1.172b83c7d517adcdf7c8c50eb162p+0L,
	0x1.18af9388c8de9bbbf70b9a3c269cp+0L,
	0x1.1a35beb6fcb753cb698f692d2038p+0L,
	0x1.1bbe084045cd39ab1e72b442810ep+0L,
	0x1.1d4873168b9aa7805b8028990be8p+0L,
	0x1.1ed5022fcd91cb8819ff61121fbep+0L,
	0x1.2063b88628cd63b8eeb0295093f6p+0L,
	0x1.21f49917ddc962552fd29294bc20p+0L,
	0x1.2387a6e75623866c1fadb1c159c0p+0L,
	0x1.251ce4fb2a63f3582ab7de9e9562p+0L,
	0x1.26b4565e27cdd257a673281d3068p+0L,
	0x1.284dfe1f5638096cf15cf03c9fa0p+0L,
	0x1.29e9df51fdee12c25d15f5a25022p+0L,
	0x1.2b87fd0dad98ffddea46538fca24p+0L,
	0x1.2d285a6e4030b40091d536d0733ep+0L,
	0x1.2ecafa93e2f5611ca0f45d5239a4p+0L,
	0x1.306fe0a31b7152de8d5a463063bep+0L,
	0x1.32170fc4cd8313539cf1c3009330p+0L,
	0x1.33c08b26416ff4c9c8610d96680ep+0L,
	0x1.356c55f929ff0c94623476373be4p+0L,
	0x1.371a7373aa9caa7145502f45452ap+0L,
	0x1.38cae6d05d86585a9cb0d9bed530p+0L,
	0x1.3a7db34e59ff6ea1bc9299e0a1fep+0L,
	0x1.3c32dc313a8e484001f228b58cf0p+0L,
	0x1.3dea64c12342235b41223e13d7eep+0L,
	0x1.3fa4504ac801ba0bf701aa417b9cp+0L,
	0x1.4160a21f72e29f84325b8f3dbacap+0L,
	0x1.431f5d950a896dc704439410b628p+0L,
	0x1.44e086061892d03136f409df0724p+0L,
	0x1.46a41ed1d005772512f459229f0ap+0L,
	0x1.486a2b5c13cd013c1a3b69062f26p+0L,
	0x1.4a32af0d7d3de672d8bcf46f99b4p+0L,
	0x1.4bfdad5362a271d4397afec42e36p+0L,
	0x1.4dcb299fddd0d63b36ef1a9e19dep+0L,
	0x1.4f9b2769d2ca6ad33d8b69aa0b8cp+0L,
	0x1.516daa2cf6641c112f52c84d6066p+0L,
	0x1.5342b569d4f81df0a83c49d86bf4p+0L,
	0x1.551a4ca5d920ec52ec620243540cp+0L,
	0x1.56f4736b527da66ecb004764e61ep+0L,
	0x1.58d12d497c7fd252bc2b7343d554p+0L,
	0x1.5ab07dd48542958c93015191e9a8p+0L,
	0x1.5c9268a5946b701c4b1b81697ed4p+0L,
	0x1.5e76f15ad21486e9be4c20399d12p+0L,
	0x1.605e1b976dc08b076f592a487066p+0L,
	0x1.6247eb03a5584b1f0fa06fd2d9eap+0L,
	0x1.6434634ccc31fc76f8714c4ee122p+0L,
	0x1.66238825522249127d9e29b92ea2p+0L,
	0x1.68155d44ca973081c57227b9f69ep+0L,
};

static const float eps[TBLSIZE] = {
	-0x1.5c50p-101,
	-0x1.5d00p-106,
	 0x1.8e90p-102,
	-0x1.5340p-103,
	 0x1.1bd0p-102,
	-0x1.4600p-105,
	-0x1.7a40p-104,
	 0x1.d590p-102,
	-0x1.d590p-101,
	 0x1.b100p-103,
	-0x1.0d80p-105,
	 0x1.6b00p-103,
	-0x1.9f00p-105,
	 0x1.c400p-103,
	 0x1.e120p-103,
	-0x1.c100p-104,
	-0x1.9d20p-103,
	 0x1.a800p-108,
	 0x1.4c00p-106,
	-0x1.9500p-106,
	 0x1.6900p-105,
	-0x1.29d0p-100,
	 0x1.4c60p-103,
	 0x1.13a0p-102,
	-0x1.5b60p-103,
	-0x1.1c40p-103,
	 0x1.db80p-102,
	 0x1.91a0p-102,
	 0x1.dc00p-105,
	 0x1.44c0p-104,
	 0x1.9710p-102,
	 0x1.8760p-103,
	-0x1.a720p-103,
	 0x1.ed20p-103,
	-0x1.49c0p-102,
	-0x1.e000p-111,
	 0x1.86a0p-103,
	 0x1.2b40p-103,
	-0x1.b400p-108,
	 0x1.1280p-99,
	-0x1.02d8p-102,
	-0x1.e3d0p-103,
	-0x1.b080p-105,
	-0x1.f100p-107,
	-0x1.16c0p-105,
	-0x1.1190p-103,
	-0x1.a7d2p-100,
	 0x1.3450p-103,
	-0x1.67c0p-105,
	 0x1.4b80p-104,
	-0x1.c4e0p-103,
	 0x1.6000p-108,
	-0x1.3f60p-105,
	 0x1.93f0p-104,
	 0x1.5fe0p-105,
	 0x1.6f80p-107,
	-0x1.7600p-106,
	 0x1.21e0p-106,
	-0x1.3a40p-106,
	-0x1.40c0p-104,
	-0x1.9860p-105,
	-0x1.5d40p-108,
	-0x1.1d70p-106,
	 0x1.2760p-105,
	 0x0.0000p+0,
	 0x1.21e2p-104,
	-0x1.9520p-108,
	-0x1.5720p-106,
	-0x1.4810p-106,
	-0x1.be00p-109,
	 0x1.0080p-105,
	-0x1.5780p-108,
	-0x1.d460p-105,
	-0x1.6140p-105,
	 0x1.4630p-104,
	 0x1.ad50p-103,
	 0x1.82e0p-105,
	 0x1.1d3cp-101,
	 0x1.6100p-107,
	 0x1.ec30p-104,
	 0x1.f200p-108,
	 0x1.0b40p-103,
	 0x1.3660p-102,
	 0x1.d9d0p-103,
	-0x1.02d0p-102,
	 0x1.b070p-103,
	 0x1.b9c0p-104,
	-0x1.01c0p-103,
	-0x1.dfe0p-103,
	 0x1.1b60p-104,
	-0x1.ae94p-101,
	-0x1.3340p-104,
	 0x1.b3d8p-102,
	-0x1.6e40p-105,
	-0x1.3670p-103,
	 0x1.c140p-104,
	 0x1.1840p-101,
	 0x1.1ab0p-102,
	-0x1.a400p-104,
	 0x1.1f00p-104,
	-0x1.7180p-103,
	 0x1.4ce0p-102,
	 0x1.9200p-107,
	-0x1.54c0p-103,
	 0x1.1b80p-105,
	-0x1.1828p-101,
	 0x1.5720p-102,
	-0x1.a060p-100,
	 0x1.9160p-102,
	 0x1.a280p-104,
	 0x1.3400p-107,
	 0x1.2b20p-102,
	 0x1.7800p-108,
	 0x1.cfd0p-101,
	 0x1.2ef0p-102,
	-0x1.2760p-99,
	 0x1.b380p-104,
	 0x1.0048p-101,
	-0x1.60b0p-102,
	 0x1.a1ccp-100,
	-0x1.a640p-104,
	-0x1.08a0p-101,
	 0x1.7e60p-102,
	 0x1.22c0p-103,
	-0x1.7200p-106,
	 0x1.f0f0p-102,
	 0x1.eb4ep-99,
	 0x1.c6e0p-103,
};

/*
 * exp2l(x): compute the base 2 exponential of x
 *
 * Accuracy: Peak error < 0.502 ulp.
 *
 * Method: (accurate tables)
 *
 *   Reduce x:
 *     x = 2**k + y, for integer k and |y| <= 1/2.
 *     Thus we have exp2(x) = 2**k * exp2(y).
 *
 *   Reduce y:
 *     y = i/TBLSIZE + z - eps[i] for integer i near y * TBLSIZE.
 *     Thus we have exp2(y) = exp2(i/TBLSIZE) * exp2(z - eps[i]),
 *     with |z - eps[i]| <= 2**-8 + 2**-98 for the table used.
 *
 *   We compute exp2(i/TBLSIZE) via table lookup and exp2(z - eps[i]) via
 *   a degree-10 minimax polynomial with maximum error under 2**-120.
 *   The values in exp2t[] and eps[] are chosen such that
 *   exp2t[i] = exp2(i/TBLSIZE + eps[i]), and eps[i] is a small offset such
 *   that exp2t[i] is accurate to 2**-122.
 *
 *   Note that the range of i is +-TBLSIZE/2, so we actually index the tables
 *   by i0 = i + TBLSIZE/2.
 *
 *   This method is due to Gal, with many details due to Gal and Bachelis:
 *
 *	Gal, S. and Bachelis, B.  An Accurate Elementary Mathematical Library
 *	for the IEEE Floating Point Standard.  TOMS 17(1), 26-46 (1991).
 */
long double
exp2l(long double x)
{
	union ldshape u = {x};
	int e = u.i.se & 0x7fff;
	long double r, z, t;
	uint32_t i0;
	union {uint32_t u; int32_t i;} k;

	/* Filter out exceptional cases. */
	if (e >= 0x3fff + 14) {  /* |x| >= 16384 or x is NaN */
		if (u.i.se >= 0x3fff + 15 && u.i.se >> 15 == 0)
			/* overflow */
			return x * 0x1p16383L;
		if (e == 0x7fff)  /* -inf or -nan */
			return -1/x;
		if (x < -16382) {
			if (x <= -16495 || x - 0x1p112 + 0x1p112 != x)
				/* underflow */
				FORCE_EVAL((float)(-0x1p-149/x));
			if (x <= -16446)
				return 0;
		}
	} else if (e < 0x3fff - 114) {
		return 1 + x;
	}

	/*
	 * Reduce x, computing z, i0, and k. The low bits of x + redux
	 * contain the 16-bit integer part of the exponent (k) followed by
	 * TBLBITS fractional bits (i0). We use bit tricks to extract these
	 * as integers, then set z to the remainder.
	 *
	 * Example: Suppose x is 0xabc.123456p0 and TBLBITS is 8.
	 * Then the low-order word of x + redux is 0x000abc12,
	 * We split this into k = 0xabc and i0 = 0x12 (adjusted to
	 * index into the table), then we compute z = 0x0.003456p0.
	 */
	u.f = x + redux;
	i0 = u.i2.lo + TBLSIZE / 2;
	k.u = i0 / TBLSIZE * TBLSIZE;
	k.i /= TBLSIZE;
	i0 %= TBLSIZE;
	u.f -= redux;
	z = x - u.f;

	/* Compute r = exp2(y) = exp2t[i0] * p(z - eps[i]). */
	t = tbl[i0];
	z -= eps[i0];
	r = t + t * z * (P1 + z * (P2 + z * (P3 + z * (P4 + z * (P5 + z * (P6
	    + z * (P7 + z * (P8 + z * (P9 + z * P10)))))))));

	return scalbnl(r, k.i);
}
#endif
