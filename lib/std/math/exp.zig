// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/expf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/exp.c

const std = @import("../std.zig");
const math = std.math;
const inf_f32 = math.inf_f32;
const inf_f64 = math.inf_f64;
const inf_f128 = math.inf_f128;
const nan_f32 = math.nan_f32;
const nan_f64 = math.nan_f64;
const nan_f128 = math.nan_f128;
const expect = std.testing.expect;

/// Returns e raised to the power of x (e^x).
///
/// Special Cases:
///  - exp(+inf) = +inf
///  - exp(nan)  = nan
pub fn exp(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => exp32(x),
        f64 => exp64(x),
        f128 => exp128(x),
        else => @compileError("exp not implemented for " ++ @typeName(T)),
    };
}

fn exp32(x_: f32) f32 {
    const half = [_]f32{ 0.5, -0.5 };
    const ln2hi = 6.9314575195e-1;
    const ln2lo = 1.4286067653e-6;
    const invln2 = 1.4426950216e+0;
    const P1 = 1.6666625440e-1;
    const P2 = -2.7667332906e-3;

    var x = x_;
    var hx = @bitCast(u32, x);
    const sign = @intCast(i32, hx >> 31);
    hx &= 0x7FFFFFFF;

    if (math.isNan(x)) {
        return math.nan(f32);
    }

    // |x| >= -87.33655 or nan
    if (hx >= 0x42AEAC50) {
        // nan
        if (hx > 0x7F800000) {
            return x;
        }
        // x >= 88.722839
        if (hx >= 0x42b17218 and sign == 0) {
            return x * 0x1.0p127;
        }
        if (sign != 0) {
            math.doNotOptimizeAway(-0x1.0p-149 / x); // overflow
            // x <= -103.972084
            if (hx >= 0x42CFF1B5) {
                return 0;
            }
        }
    }

    var k: i32 = undefined;
    var hi: f32 = undefined;
    var lo: f32 = undefined;

    // |x| > 0.5 * ln2
    if (hx > 0x3EB17218) {
        // |x| > 1.5 * ln2
        if (hx > 0x3F851592) {
            k = @floatToInt(i32, invln2 * x + half[@intCast(usize, sign)]);
        } else {
            k = 1 - sign - sign;
        }

        const fk = @intToFloat(f32, k);
        hi = x - fk * ln2hi;
        lo = fk * ln2lo;
        x = hi - lo;
    }
    // |x| > 2^(-14)
    else if (hx > 0x39000000) {
        k = 0;
        hi = x;
        lo = 0;
    } else {
        math.doNotOptimizeAway(0x1.0p127 + x); // inexact
        return 1 + x;
    }

    const xx = x * x;
    const c = x - xx * (P1 + xx * P2);
    const y = 1 + (x * c / (2 - c) - lo + hi);

    if (k == 0) {
        return y;
    } else {
        return math.scalbn(y, k);
    }
}

fn exp64(x_: f64) f64 {
    const half = [_]f64{ 0.5, -0.5 };
    const ln2hi: f64 = 6.93147180369123816490e-01;
    const ln2lo: f64 = 1.90821492927058770002e-10;
    const invln2: f64 = 1.44269504088896338700e+00;
    const P1: f64 = 1.66666666666666019037e-01;
    const P2: f64 = -2.77777777770155933842e-03;
    const P3: f64 = 6.61375632143793436117e-05;
    const P4: f64 = -1.65339022054652515390e-06;
    const P5: f64 = 4.13813679705723846039e-08;

    var x = x_;
    var ux = @bitCast(u64, x);
    var hx = ux >> 32;
    const sign = @intCast(i32, hx >> 31);
    hx &= 0x7FFFFFFF;

    if (math.isNan(x)) {
        return math.nan(f64);
    }

    // |x| >= 708.39 or nan
    if (hx >= 0x4086232B) {
        // nan
        if (hx > 0x7FF00000) {
            return x;
        }
        if (x > 709.782712893383973096) {
            // overflow if x != inf
            if (!math.isInf(x)) {
                math.raiseOverflow();
            }
            return math.inf(f64);
        }
        if (x < -708.39641853226410622) {
            // underflow if x != -inf
            // math.doNotOptimizeAway(@as(f32, -0x1.0p-149 / x));
            if (x < -745.13321910194110842) {
                return 0;
            }
        }
    }

    // argument reduction
    var k: i32 = undefined;
    var hi: f64 = undefined;
    var lo: f64 = undefined;

    // |x| > 0.5 * ln2
    if (hx > 0x3EB17218) {
        // |x| >= 1.5 * ln2
        if (hx > 0x3FF0A2B2) {
            k = @floatToInt(i32, invln2 * x + half[@intCast(usize, sign)]);
        } else {
            k = 1 - sign - sign;
        }

        const dk = @intToFloat(f64, k);
        hi = x - dk * ln2hi;
        lo = dk * ln2lo;
        x = hi - lo;
    }
    // |x| > 2^(-28)
    else if (hx > 0x3E300000) {
        k = 0;
        hi = x;
        lo = 0;
    } else {
        // inexact if x != 0
        // math.doNotOptimizeAway(0x1.0p1023 + x);
        return 1 + x;
    }

    const xx = x * x;
    const c = x - xx * (P1 + xx * (P2 + xx * (P3 + xx * (P4 + xx * P5))));
    const y = 1 + (x * c / (2 - c) - lo + hi);

    if (k == 0) {
        return y;
    } else {
        return math.scalbn(y, k);
    }
}

// from: FreeBSD: head/lib/msun/ld128/s_expl.c 251345 2013-06-03 20:09:22Z kargl

// SPDX-License-Identifier: BSD-2-Clause-FreeBSD
//
// Copyright (c) 2009-2013 Steven G. Kargl
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice unmodified, this list of conditions, and the following
//    disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
// OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
// THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Optimized by Bruce D. Evans.

const INTERVALS = 128;
const LOG2_INTERVALS = 7;

const exp_128_table = [INTERVALS]struct { hi: f128, lo: f128 }{
    .{ .hi = 0x1p0, .lo = 0x0p0 },
    .{ .hi = 0x1.0163da9fb33356d84a66aep0, .lo = 0x3.36dcdfa4003ec04c360be2404078p-92 },
    .{ .hi = 0x1.02c9a3e778060ee6f7cacap0, .lo = 0x4.f7a29bde93d70a2cabc5cb89ba10p-92 },
    .{ .hi = 0x1.04315e86e7f84bd738f9a2p0, .lo = 0xd.a47e6ed040bb4bfc05af6455e9b8p-96 },
    .{ .hi = 0x1.059b0d31585743ae7c548ep0, .lo = 0xb.68ca417fe53e3495f7df4baf84a0p-92 },
    .{ .hi = 0x1.0706b29ddf6ddc6dc403a8p0, .lo = 0x1.d87b27ed07cb8b092ac75e311753p-88 },
    .{ .hi = 0x1.0874518759bc808c35f25cp0, .lo = 0x1.9427fa2b041b2d6829d8993a0d01p-88 },
    .{ .hi = 0x1.09e3ecac6f3834521e060cp0, .lo = 0x5.84d6b74ba2e023da730e7fccb758p-92 },
    .{ .hi = 0x1.0b5586cf9890f6298b92b6p0, .lo = 0x1.1842a98364291408b3ceb0a2a2bbp-88 },
    .{ .hi = 0x1.0cc922b7247f7407b705b8p0, .lo = 0x9.3dc5e8aac564e6fe2ef1d431fd98p-92 },
    .{ .hi = 0x1.0e3ec32d3d1a2020742e4ep0, .lo = 0x1.8af6a552ac4b358b1129e9f966a4p-88 },
    .{ .hi = 0x1.0fb66affed31af232091dcp0, .lo = 0x1.8a1426514e0b627bda694a400a27p-88 },
    .{ .hi = 0x1.11301d0125b50a4ebbf1aep0, .lo = 0xd.9318ceac5cc47ab166ee57427178p-92 },
    .{ .hi = 0x1.12abdc06c31cbfb92bad32p0, .lo = 0x4.d68e2f7270bdf7cedf94eb1cb818p-92 },
    .{ .hi = 0x1.1429aaea92ddfb34101942p0, .lo = 0x1.b2586d01844b389bea7aedd221d4p-88 },
    .{ .hi = 0x1.15a98c8a58e512480d573cp0, .lo = 0x1.d5613bf92a2b618ee31b376c2689p-88 },
    .{ .hi = 0x1.172b83c7d517adcdf7c8c4p0, .lo = 0x1.0eb14a792035509ff7d758693f24p-88 },
    .{ .hi = 0x1.18af9388c8de9bbbf70b9ap0, .lo = 0x3.c2505c97c0102e5f1211941d2840p-92 },
    .{ .hi = 0x1.1a35beb6fcb753cb698f68p0, .lo = 0x1.2d1c835a6c30724d5cfae31b84e5p-88 },
    .{ .hi = 0x1.1bbe084045cd39ab1e72b4p0, .lo = 0x4.27e35f9acb57e473915519a1b448p-92 },
    .{ .hi = 0x1.1d4873168b9aa7805b8028p0, .lo = 0x9.90f07a98b42206e46166cf051d70p-92 },
    .{ .hi = 0x1.1ed5022fcd91cb8819ff60p0, .lo = 0x1.121d1e504d36c47474c9b7de6067p-88 },
    .{ .hi = 0x1.2063b88628cd63b8eeb028p0, .lo = 0x1.50929d0fc487d21c2b84004264dep-88 },
    .{ .hi = 0x1.21f49917ddc962552fd292p0, .lo = 0x9.4bdb4b61ea62477caa1dce823ba0p-92 },
    .{ .hi = 0x1.2387a6e75623866c1fadb0p0, .lo = 0x1.c15cb593b0328566902df69e4de2p-88 },
    .{ .hi = 0x1.251ce4fb2a63f3582ab7dep0, .lo = 0x9.e94811a9c8afdcf796934bc652d0p-92 },
    .{ .hi = 0x1.26b4565e27cdd257a67328p0, .lo = 0x1.d3b249dce4e9186ddd5ff44e6b08p-92 },
    .{ .hi = 0x1.284dfe1f5638096cf15cf0p0, .lo = 0x3.ca0967fdaa2e52d7c8106f2e262cp-92 },
    .{ .hi = 0x1.29e9df51fdee12c25d15f4p0, .lo = 0x1.a24aa3bca890ac08d203fed80a07p-88 },
    .{ .hi = 0x1.2b87fd0dad98ffddea4652p0, .lo = 0x1.8fcab88442fdc3cb6de4519165edp-88 },
    .{ .hi = 0x1.2d285a6e4030b40091d536p0, .lo = 0xd.075384589c1cd1b3e4018a6b1348p-92 },
    .{ .hi = 0x1.2ecafa93e2f5611ca0f45cp0, .lo = 0x1.523833af611bdcda253c554cf278p-88 },
    .{ .hi = 0x1.306fe0a31b7152de8d5a46p0, .lo = 0x3.05c85edecbc27343629f502f1af2p-92 },
    .{ .hi = 0x1.32170fc4cd8313539cf1c2p0, .lo = 0x1.008f86dde3220ae17a005b6412bep-88 },
    .{ .hi = 0x1.33c08b26416ff4c9c8610cp0, .lo = 0x1.96696bf95d1593039539d94d662bp-88 },
    .{ .hi = 0x1.356c55f929ff0c94623476p0, .lo = 0x3.73af38d6d8d6f9506c9bbc93cbc0p-92 },
    .{ .hi = 0x1.371a7373aa9caa7145502ep0, .lo = 0x1.4547987e3e12516bf9c699be432fp-88 },
    .{ .hi = 0x1.38cae6d05d86585a9cb0d8p0, .lo = 0x1.bed0c853bd30a02790931eb2e8f0p-88 },
    .{ .hi = 0x1.3a7db34e59ff6ea1bc9298p0, .lo = 0x1.e0a1d336163fe2f852ceeb134067p-88 },
    .{ .hi = 0x1.3c32dc313a8e484001f228p0, .lo = 0xb.58f3775e06ab66353001fae9fca0p-92 },
    .{ .hi = 0x1.3dea64c12342235b41223ep0, .lo = 0x1.3d773fba2cb82b8244267c54443fp-92 },
    .{ .hi = 0x1.3fa4504ac801ba0bf701aap0, .lo = 0x4.1832fb8c1c8dbdff2c49909e6c60p-92 },
    .{ .hi = 0x1.4160a21f72e29f84325b8ep0, .lo = 0x1.3db61fb352f0540e6ba05634413ep-88 },
    .{ .hi = 0x1.431f5d950a896dc7044394p0, .lo = 0x1.0ccec81e24b0caff7581ef4127f7p-92 },
    .{ .hi = 0x1.44e086061892d03136f408p0, .lo = 0x1.df019fbd4f3b48709b78591d5cb5p-88 },
    .{ .hi = 0x1.46a41ed1d005772512f458p0, .lo = 0x1.229d97df404ff21f39c1b594d3a8p-88 },
    .{ .hi = 0x1.486a2b5c13cd013c1a3b68p0, .lo = 0x1.062f03c3dd75ce8757f780e6ec99p-88 },
    .{ .hi = 0x1.4a32af0d7d3de672d8bcf4p0, .lo = 0x6.f9586461db1d878b1d148bd3ccb8p-92 },
    .{ .hi = 0x1.4bfdad5362a271d4397afep0, .lo = 0xc.42e20e0363ba2e159c579f82e4b0p-92 },
    .{ .hi = 0x1.4dcb299fddd0d63b36ef1ap0, .lo = 0x9.e0cc484b25a5566d0bd5f58ad238p-92 },
    .{ .hi = 0x1.4f9b2769d2ca6ad33d8b68p0, .lo = 0x1.aa073ee55e028497a329a7333dbap-88 },
    .{ .hi = 0x1.516daa2cf6641c112f52c8p0, .lo = 0x4.d822190e718226177d7608d20038p-92 },
    .{ .hi = 0x1.5342b569d4f81df0a83c48p0, .lo = 0x1.d86a63f4e672a3e429805b049465p-88 },
    .{ .hi = 0x1.551a4ca5d920ec52ec6202p0, .lo = 0x4.34ca672645dc6c124d6619a87574p-92 },
    .{ .hi = 0x1.56f4736b527da66ecb0046p0, .lo = 0x1.64eb3c00f2f5ab3d801d7cc7272dp-88 },
    .{ .hi = 0x1.58d12d497c7fd252bc2b72p0, .lo = 0x1.43bcf2ec936a970d9cc266f0072fp-88 },
    .{ .hi = 0x1.5ab07dd48542958c930150p0, .lo = 0x1.91eb345d88d7c81280e069fbdb63p-88 },
    .{ .hi = 0x1.5c9268a5946b701c4b1b80p0, .lo = 0x1.6986a203d84e6a4a92f179e71889p-88 },
    .{ .hi = 0x1.5e76f15ad21486e9be4c20p0, .lo = 0x3.99766a06548a05829e853bdb2b52p-92 },
    .{ .hi = 0x1.605e1b976dc08b076f592ap0, .lo = 0x4.86e3b34ead1b4769df867b9c89ccp-92 },
    .{ .hi = 0x1.6247eb03a5584b1f0fa06ep0, .lo = 0x1.d2da42bb1ceaf9f732275b8aef30p-88 },
    .{ .hi = 0x1.6434634ccc31fc76f8714cp0, .lo = 0x4.ed9a4e41000307103a18cf7a6e08p-92 },
    .{ .hi = 0x1.66238825522249127d9e28p0, .lo = 0x1.b8f314a337f4dc0a3adf1787ff74p-88 },
    .{ .hi = 0x1.68155d44ca973081c57226p0, .lo = 0x1.b9f32706bfe4e627d809a85dcc66p-88 },
    .{ .hi = 0x1.6a09e667f3bcc908b2fb12p0, .lo = 0x1.66ea957d3e3adec17512775099dap-88 },
    .{ .hi = 0x1.6c012750bdabeed76a9980p0, .lo = 0xf.4f33fdeb8b0ecd831106f57b3d00p-96 },
    .{ .hi = 0x1.6dfb23c651a2ef220e2cbep0, .lo = 0x1.bbaa834b3f11577ceefbe6c1c411p-92 },
    .{ .hi = 0x1.6ff7df9519483cf87e1b4ep0, .lo = 0x1.3e213bff9b702d5aa477c12523cep-88 },
    .{ .hi = 0x1.71f75e8ec5f73dd2370f2ep0, .lo = 0xf.0acd6cb434b562d9e8a20adda648p-92 },
    .{ .hi = 0x1.73f9a48a58173bd5c9a4e6p0, .lo = 0x8.ab1182ae217f3a7681759553e840p-92 },
    .{ .hi = 0x1.75feb564267c8bf6e9aa32p0, .lo = 0x1.a48b27071805e61a17b954a2dad8p-88 },
    .{ .hi = 0x1.780694fde5d3f619ae0280p0, .lo = 0x8.58b2bb2bdcf86cd08e35fb04c0f0p-92 },
    .{ .hi = 0x1.7a11473eb0186d7d51023ep0, .lo = 0x1.6cda1f5ef42b66977960531e821bp-88 },
    .{ .hi = 0x1.7c1ed0130c1327c4933444p0, .lo = 0x1.937562b2dc933d44fc828efd4c9cp-88 },
    .{ .hi = 0x1.7e2f336cf4e62105d02ba0p0, .lo = 0x1.5797e170a1427f8fcdf5f3906108p-88 },
    .{ .hi = 0x1.80427543e1a11b60de6764p0, .lo = 0x9.a354ea706b8e4d8b718a672bf7c8p-92 },
    .{ .hi = 0x1.82589994cce128acf88afap0, .lo = 0xb.34a010f6ad65cbbac0f532d39be0p-92 },
    .{ .hi = 0x1.8471a4623c7acce52f6b96p0, .lo = 0x1.c64095370f51f48817914dd78665p-88 },
    .{ .hi = 0x1.868d99b4492ec80e41d90ap0, .lo = 0xc.251707484d73f136fb5779656b70p-92 },
    .{ .hi = 0x1.88ac7d98a669966530bcdep0, .lo = 0x1.2d4e9d61283ef385de170ab20f96p-88 },
    .{ .hi = 0x1.8ace5422aa0db5ba7c55a0p0, .lo = 0x1.92c9bb3e6ed61f2733304a346d8fp-88 },
    .{ .hi = 0x1.8cf3216b5448bef2aa1cd0p0, .lo = 0x1.61c55d84a9848f8c453b3ca8c946p-88 },
    .{ .hi = 0x1.8f1ae991577362b982745cp0, .lo = 0x7.2ed804efc9b4ae1458ae946099d4p-92 },
    .{ .hi = 0x1.9145b0b91ffc588a61b468p0, .lo = 0x1.f6b70e01c2a90229a4c4309ea719p-88 },
    .{ .hi = 0x1.93737b0cdc5e4f4501c3f2p0, .lo = 0x5.40a22d2fc4af581b63e8326efe9cp-92 },
    .{ .hi = 0x1.95a44cbc8520ee9b483694p0, .lo = 0x1.a0fc6f7c7d61b2b3a22a0eab2cadp-88 },
    .{ .hi = 0x1.97d829fde4e4f8b9e920f8p0, .lo = 0x1.1e8bd7edb9d7144b6f6818084cc7p-88 },
    .{ .hi = 0x1.9a0f170ca07b9ba3109b8cp0, .lo = 0x4.6737beb19e1eada6825d3c557428p-92 },
    .{ .hi = 0x1.9c49182a3f0901c7c46b06p0, .lo = 0x1.1f2be58ddade50c217186c90b457p-88 },
    .{ .hi = 0x1.9e86319e323231824ca78ep0, .lo = 0x6.4c6e010f92c082bbadfaf605cfd4p-92 },
    .{ .hi = 0x1.a0c667b5de564b29ada8b8p0, .lo = 0xc.ab349aa0422a8da7d4512edac548p-92 },
    .{ .hi = 0x1.a309bec4a2d3358c171f76p0, .lo = 0x1.0daad547fa22c26d168ea762d854p-88 },
    .{ .hi = 0x1.a5503b23e255c8b424491cp0, .lo = 0xa.f87bc8050a405381703ef7caff50p-92 },
    .{ .hi = 0x1.a799e1330b3586f2dfb2b0p0, .lo = 0x1.58f1a98796ce8908ae852236ca94p-88 },
    .{ .hi = 0x1.a9e6b5579fdbf43eb243bcp0, .lo = 0x1.ff4c4c58b571cf465caf07b4b9f5p-88 },
    .{ .hi = 0x1.ac36bbfd3f379c0db966a2p0, .lo = 0x1.1265fc73e480712d20f8597a8e7bp-88 },
    .{ .hi = 0x1.ae89f995ad3ad5e8734d16p0, .lo = 0x1.73205a7fbc3ae675ea440b162d6cp-88 },
    .{ .hi = 0x1.b0e07298db66590842acdep0, .lo = 0x1.c6f6ca0e5dcae2aafffa7a0554cbp-88 },
    .{ .hi = 0x1.b33a2b84f15faf6bfd0e7ap0, .lo = 0x1.d947c2575781dbb49b1237c87b6ep-88 },
    .{ .hi = 0x1.b59728de559398e3881110p0, .lo = 0x1.64873c7171fefc410416be0a6525p-88 },
    .{ .hi = 0x1.b7f76f2fb5e46eaa7b081ap0, .lo = 0xb.53c5354c8903c356e4b625aacc28p-92 },
    .{ .hi = 0x1.ba5b030a10649840cb3c6ap0, .lo = 0xf.5b47f297203757e1cc6eadc8bad0p-92 },
    .{ .hi = 0x1.bcc1e904bc1d2247ba0f44p0, .lo = 0x1.b3d08cd0b20287092bd59be4ad98p-88 },
    .{ .hi = 0x1.bf2c25bd71e088408d7024p0, .lo = 0x1.18e3449fa073b356766dfb568ff4p-88 },
    .{ .hi = 0x1.c199bdd85529c2220cb12ap0, .lo = 0x9.1ba6679444964a36661240043970p-96 },
    .{ .hi = 0x1.c40ab5fffd07a6d14df820p0, .lo = 0xf.1828a5366fd387a7bdd54cdf7300p-92 },
    .{ .hi = 0x1.c67f12e57d14b4a2137fd2p0, .lo = 0xf.2b301dd9e6b151a6d1f9d5d5f520p-96 },
    .{ .hi = 0x1.c8f6d9406e7b511acbc488p0, .lo = 0x5.c442ddb55820171f319d9e5076a8p-96 },
    .{ .hi = 0x1.cb720dcef90691503cbd1ep0, .lo = 0x9.49db761d9559ac0cb6dd3ed599e0p-92 },
    .{ .hi = 0x1.cdf0b555dc3f9c44f8958ep0, .lo = 0x1.ac51be515f8c58bdfb6f5740a3a4p-88 },
    .{ .hi = 0x1.d072d4a07897b8d0f22f20p0, .lo = 0x1.a158e18fbbfc625f09f4cca40874p-88 },
    .{ .hi = 0x1.d2f87080d89f18ade12398p0, .lo = 0x9.ea2025b4c56553f5cdee4c924728p-92 },
    .{ .hi = 0x1.d5818dcfba48725da05aeap0, .lo = 0x1.66e0dca9f589f559c0876ff23830p-88 },
    .{ .hi = 0x1.d80e316c98397bb84f9d04p0, .lo = 0x8.805f84bec614de269900ddf98d28p-92 },
    .{ .hi = 0x1.da9e603db3285708c01a5ap0, .lo = 0x1.6d4c97f6246f0ec614ec95c99392p-88 },
    .{ .hi = 0x1.dd321f301b4604b695de3cp0, .lo = 0x6.30a393215299e30d4fb73503c348p-96 },
    .{ .hi = 0x1.dfc97337b9b5eb968cac38p0, .lo = 0x1.ed291b7225a944efd5bb5524b927p-88 },
    .{ .hi = 0x1.e264614f5a128a12761fa0p0, .lo = 0x1.7ada6467e77f73bf65e04c95e29dp-88 },
    .{ .hi = 0x1.e502ee78b3ff6273d13014p0, .lo = 0x1.3991e8f49659e1693be17ae1d2f9p-88 },
    .{ .hi = 0x1.e7a51fbc74c834b548b282p0, .lo = 0x1.23786758a84f4956354634a416cep-88 },
    .{ .hi = 0x1.ea4afa2a490d9858f73a18p0, .lo = 0xf.5db301f86dea20610ceee13eb7b8p-92 },
    .{ .hi = 0x1.ecf482d8e67f08db0312fap0, .lo = 0x1.949cef462010bb4bc4ce72a900dfp-88 },
    .{ .hi = 0x1.efa1bee615a27771fd21a8p0, .lo = 0x1.2dac1f6dd5d229ff68e46f27e3dfp-88 },
    .{ .hi = 0x1.f252b376bba974e8696fc2p0, .lo = 0x1.6390d4c6ad5476b5162f40e1d9a9p-88 },
    .{ .hi = 0x1.f50765b6e4540674f84b76p0, .lo = 0x2.862baff99000dfc4352ba29b8908p-92 },
    .{ .hi = 0x1.f7bfdad9cbe138913b4bfep0, .lo = 0x7.2bd95c5ce7280fa4d2344a3f5618p-92 },
    .{ .hi = 0x1.fa7c1819e90d82e90a7e74p0, .lo = 0xb.263c1dc060c36f7650b4c0f233a8p-92 },
    .{ .hi = 0x1.fd3c22b8f71f10975ba4b2p0, .lo = 0x1.2bcf3a5e12d269d8ad7c1a4a8875p-88 },
};

fn exp128(x: f128) f128 {
    const L1: f128 = 5.41521234812457272982212595914567508e-3;
    const L2: f64 = -1.0253670638894731e-29; // -0x1.9ff0342542fc3p-97
    const inv_L: f64 = 1.8466496523378731e+2; // 0x1.71547652b82fep+7

    const A2: f128 = 0.5;
    const A3: f128 = 1.66666666666666666666666666651085500e-1;
    const A4: f128 = 4.16666666666666666666666666425885320e-2;
    const A5: f128 = 8.33333333333333333334522877160175842e-3;
    const A6: f128 = 1.38888888888888888889971139751596836e-3;
    const A7: f64 = 1.9841269841269470e-4; // 0x1.a01a01a019f91p-13
    const A8: f64 = 2.4801587301585286e-5; // 0x1.71de3ec75a967p-19
    const A9: f64 = 2.7557324277411235e-6; // 0x1.71de3ec75a967p-19
    const A10: f64 = 2.7557333722375069e-7; // 0x1.27e505ab56259p-22

    // Last values before overflow/underflow/subnormal.
    const o_threshold = 11356.523406294143949491931077970763428; // 0x1.62e42fefa39ef35793c7673007e5p+13
    const u_threshold = -11433.462743336297878837243843452621503; // -0x1.654bb3b2c73ebb059fabb506ff33p+13
    const s_threshold = -11355.137111933024058873096613727848253; // -0x1.62d918ce2421d65ff90ac8f4ce65p+13

    const ux: u128 = @bitCast(u128, x);
    var hx: u32 = @intCast(u32, ux >> 96);
    hx &= 0x7FFFFFFF;

    if (math.isNan(x)) {
        return math.nan(f128);
    }

    // |x| >= 11355.1371... or NaN
    if (hx >= 0x400C62D9) {
        // NaN
        if (hx > 0x7FFF0000) {
            return x;
        }
        if (x > o_threshold) {
            // overflow if x != inf
            if (!math.isInf(x)) {
                math.raiseOverflow();
            }
            return math.inf(f128);
        }
        if (x < s_threshold) {
            // underflow if x != -inf
            // math.doNotOptimizeAway(@as(f32, -0x1.0p-149 / x));
            if (!math.isInf(x)) {
                math.raiseUnderflow();
            }
            if (x < u_threshold) {
                return 0;
            }
        }
    }

    const fn_: f64 = (@floatCast(f64, x) * inv_L + 0x1.8p52) - 0x1.8p52;
    const n: i32 = @floatToInt(i32, fn_);
    const n2: u32 = @bitCast(u32, n) % INTERVALS;
    const k: i32 = n >> LOG2_INTERVALS;
    const r1: f128 = x - fn_ * L1;
    const r2: f64 = fn_ * -L2;
    const r: f128 = r1 + r2;

    const dr: f64 = @floatCast(f64, r);
    // zig fmt: off
    const q: f128 = r2 + r * r * (A2 + r * (A3 + r * (A4 + r * (A5 + r * (A6 +
        dr * (A7 + dr * (A8 + dr * (A9 + dr * A10))))))));
    // zig fmt: on
    var t: f128 = exp_128_table[n2].lo + exp_128_table[n2].hi;
    const hi: f128 = exp_128_table[n2].hi;
    const lo: f128 = exp_128_table[n2].lo + t * (q + r1);
    t = hi + lo;

    if (k == 0) {
        return t;
    } else {
        return math.scalbn(t, k);
    }
}

test "math.exp() delegation" {
    try expect(exp(@as(f32, 0.0)) == exp32(0.0));
    try expect(exp(@as(f64, 0.0)) == exp64(0.0));
    try expect(exp(@as(f128, 0.0)) == exp128(0.0));
}

test "math.exp32() basic" {
    const epsilon = 0.000001;

    try expect(exp32(0.0) == 1.0);
    try expect(math.approxEqAbs(f32, exp32(0.0), 1.0, epsilon));
    try expect(math.approxEqAbs(f32, exp32(0.2), 1.221403, epsilon));
    try expect(math.approxEqAbs(f32, exp32(0.8923), 2.440737, epsilon));
    try expect(math.approxEqAbs(f32, exp32(1.5), 4.481689, epsilon));
}

test "math.exp64() basic" {
    const epsilon = 0.000001;

    try expect(exp64(0.0) == 1.0);
    try expect(math.approxEqAbs(f64, exp64(0.0), 1.0, epsilon));
    try expect(math.approxEqAbs(f64, exp64(0.2), 1.221403, epsilon));
    try expect(math.approxEqAbs(f64, exp64(0.8923), 2.440737, epsilon));
    try expect(math.approxEqAbs(f64, exp64(1.5), 4.481689, epsilon));
}

test "math.exp128() basic" {
    const epsilon = 0.000001;

    try expect(exp128(0.0) == 1.0);
    try expect(math.approxEqAbs(f128, exp128(0.0), 1.0, epsilon));
    try expect(math.approxEqAbs(f128, exp128(0.2), 1.221403, epsilon));
    try expect(math.approxEqAbs(f128, exp128(0.8923), 2.440737, epsilon));
    try expect(math.approxEqAbs(f128, exp128(1.5), 4.481689, epsilon));
}

const Testcase32 = struct {
    input: f32,
    exp_output: f32,

    pub fn run(tc: @This()) !void {
        const output = exp32(tc.input);
        // Compare bits rather than values so that NaN compares correctly.
        if (@bitCast(u32, output) != @bitCast(u32, tc.exp_output)) {
            std.debug.print(
                "expected exp32({x})->{x}, got {x}\n",
                .{ tc.input, tc.exp_output, output },
            );
            return error.TestExpectedEqual;
        }
    }
};

fn tc32(input: f32, exp_output: f32) Testcase32 {
    return .{ .input = input, .exp_output = exp_output };
}

const Testcase64 = struct {
    input: f64,
    exp_output: f64,

    pub fn run(tc: @This()) !void {
        const output = exp64(tc.input);
        // Compare bits rather than values so that NaN compares correctly.
        if (@bitCast(u64, output) != @bitCast(u64, tc.exp_output)) {
            std.debug.print(
                "expected exp64({x})->{x}, got {x}\n",
                .{ tc.input, tc.exp_output, output },
            );
            return error.TestExpectedEqual;
        }
    }
};

fn tc64(input: f64, exp_output: f64) Testcase64 {
    return .{ .input = input, .exp_output = exp_output };
}

const Testcase128 = struct {
    input: f128,
    exp_output: f128,

    pub fn run(tc: @This()) !void {
        const output = exp128(tc.input);
        // Compare bits rather than values so that NaN compares correctly.
        if (@bitCast(u128, output) != @bitCast(u128, tc.exp_output)) {
            std.debug.print(
                "expected exp128({x})->{x}, got {x}\n",
                .{ tc.input, tc.exp_output, output },
            );
            return error.TestExpectedEqual;
        }
    }
};

fn tc128(input: f128, exp_output: f128) Testcase128 {
    return .{ .input = input, .exp_output = exp_output };
}

test "math.exp32() sanity" {
    const cases = [_]Testcase32{
        // zig fmt: off
        tc32(-0x1.0223a0p+3, 0x1.490320p-12),
        tc32( 0x1.161868p+2, 0x1.34712ap+6 ),
        tc32(-0x1.0c34b4p+3, 0x1.e06b1ap-13),
        tc32(-0x1.a206f0p+2, 0x1.7dd484p-10),
        tc32( 0x1.288bbcp+3, 0x1.4abc80p+13),
        tc32( 0x1.52efd0p-1, 0x1.f04a9cp+0 ),
        tc32(-0x1.a05cc8p-2, 0x1.54f1e0p-1 ),
        tc32( 0x1.1f9efap-1, 0x1.c0f628p+0 ),
        tc32( 0x1.8c5db0p-1, 0x1.1599b2p+1 ),
        tc32(-0x1.5b86eap-1, 0x1.03b572p-1 ),
        tc32(-0x1.57f25cp+2, 0x1.2fbea2p-8 ),
        tc32( 0x1.c7d310p+3, 0x1.76eefp+20 ),
        tc32( 0x1.19be70p+4, 0x1.52d3dep+25),
        tc32(-0x1.ab6d70p+3, 0x1.a88adep-20),
        tc32(-0x1.5ac18ep+2, 0x1.22b328p-8 ),
        tc32(-0x1.925982p-1, 0x1.d2acc0p-2 ),
        tc32( 0x1.7221cep+3, 0x1.9c2ceap+16),
        tc32( 0x1.11a0d4p+4, 0x1.980ee6p+24),
        tc32(-0x1.ae41a2p+1, 0x1.1c28d0p-5 ),
        tc32(-0x1.329154p+4, 0x1.47ef94p-28),
        // zig fmt: on
    };
    for (cases) |tc| {
        try tc.run();
    }
}

test "math.exp32() special" {
    const cases = [_]Testcase32{
        // zig fmt: off
        tc32( 0x0p+0,  0x1p+0 ),
        tc32(-0x0p+0,  0x1p+0 ),
        tc32( inf_f32, inf_f32),
        tc32(-inf_f32, 0x0p+0 ),
        tc32( nan_f32, nan_f32),
        tc32(-nan_f32, nan_f32),
        tc32(@bitCast(f32, @as(u32, 0x7ff01234)), nan_f32),
        tc32(@bitCast(f32, @as(u32, 0xfff01234)), nan_f32),
        // zig fmt: on
    };
    for (cases) |tc| {
        try tc.run();
    }
}

test "math.exp32() boundary" {
    const cases = [_]Testcase32{
        // zig fmt: off
        tc32( 0x1.62e42ep+6,   0x1.ffff08p+127), // The last value before the exp gets infinite
        tc32( 0x1.62e430p+6,   inf_f32        ), // The first value that gives infinite exp
        tc32( 0x1.fffffep+127, inf_f32        ), // Max input value
        tc32( 0x1p-149,        0x1p+0         ), // Tiny input values
        tc32(-0x1p-149,        0x1p+0         ),
        tc32( 0x1p-126,        0x1p+0         ),
        tc32(-0x1p-126,        0x1p+0         ),
        tc32(-0x1.9fe368p+6,   0x1p-149       ), // The last value before the exp flushes to zero
        tc32(-0x1.9fe36ap+6,   0x0p+0         ), // The first value at which the exp flushes to zero
        tc32(-0x1.5d589ep+6,   0x1.00004cp-126), // The last value before the exp flushes to subnormal
        tc32(-0x1.5d58a0p+6,   0x1.ffff98p-127), // The first value for which exp flushes to subnormal
        // zig fmt: on
    };
    for (cases) |tc| {
        try tc.run();
    }
}

test "math.exp64() sanity" {
    const cases = [_]Testcase64{
        // zig fmt: off
        tc64(-0x1.02239f3c6a8f1p+3, 0x1.490327ea61235p-12),
        tc64( 0x1.161868e18bc67p+2, 0x1.34712ed238c04p+6 ),
        tc64(-0x1.0c34b3e01e6e7p+3, 0x1.e06b1b6c18e64p-13),
        tc64(-0x1.a206f0a19dcc4p+2, 0x1.7dd47f810e68cp-10),
        tc64( 0x1.288bbb0d6a1e6p+3, 0x1.4abc77496e07ep+13),
        tc64( 0x1.52efd0cd80497p-1, 0x1.f04a9c1080500p+0 ),
        tc64(-0x1.a05cc754481d1p-2, 0x1.54f1e0fd3ea0dp-1 ),
        tc64( 0x1.1f9ef934745cbp-1, 0x1.c0f6266a6a547p+0 ),
        tc64( 0x1.8c5db097f7442p-1, 0x1.1599b1d4a25fbp+1 ),
        tc64(-0x1.5b86ea8118a0ep-1, 0x1.03b5728a00229p-1 ),
        tc64(-0x1.57f25b2b5006dp+2, 0x1.2fbea6a01cab9p-8 ),
        tc64( 0x1.c7d30fb825911p+3, 0x1.76eeed45a0634p+20),
        tc64( 0x1.19be709de7505p+4, 0x1.52d3eb7be6844p+25),
        tc64(-0x1.ab6d6fba96889p+3, 0x1.a88ae12f985d6p-20),
        tc64(-0x1.5ac18e27084ddp+2, 0x1.22b327da9cca6p-8 ),
        tc64(-0x1.925981b093c41p-1, 0x1.d2acc046b55f7p-2 ),
        tc64( 0x1.7221cd18455f5p+3, 0x1.9c2cde8699cfbp+16),
        tc64( 0x1.11a0d4a51b239p+4, 0x1.980ef612ff182p+24),
        tc64(-0x1.ae41a1079de4dp+1, 0x1.1c28d16bb3222p-5 ),
        tc64(-0x1.329153103b871p+4, 0x1.47efa6ddd0d22p-28),
        // zig fmt: on
    };
    for (cases) |tc| {
        try tc.run();
    }
}

test "math.exp64() special" {
    const cases = [_]Testcase64{
        // zig fmt: off
        tc64( 0x0p+0,  0x1p+0 ),
        tc64(-0x0p+0,  0x1p+0 ),
        tc64( inf_f64, inf_f64),
        tc64(-inf_f64, 0x0p+0 ),
        tc64( nan_f64, nan_f64),
        tc64(-nan_f64, nan_f64),
        tc64(@bitCast(f64, @as(u64, 0x7ff0123400000000)), nan_f64),
        tc64(@bitCast(f64, @as(u64, 0xfff0123400000000)), nan_f64),
        // zig fmt: on
    };
    for (cases) |tc| {
        try tc.run();
    }
}

test "math.exp64() boundary" {
    const cases = [_]Testcase64{
        // zig fmt: off
        tc64( 0x1.62e42fefa39efp+9,   0x1.fffffffffff2ap+1023), // The last value before the exp gets infinite
        tc64( 0x1.62e42fefa39f0p+9,   inf_f64                ), // The first value that gives infinite exp
        tc64( 0x1.fffffffffffffp+127, inf_f64                ), // Max input value
        tc64( 0x1p-1074,              0x1p+0                 ), // Tiny input values
        tc64(-0x1p-1074,              0x1p+0                 ),
        tc64( 0x1p-1022,              0x1p+0                 ),
        tc64(-0x1p-1022,              0x1p+0                 ),
        tc64(-0x1.74910d52d3051p+9,   0x1p-1074              ), // The last value before the exp flushes to zero
        tc64(-0x1.74910d52d3052p+9,   0x0p+0                 ), // The first value at which the exp flushes to zero
        tc64(-0x1.6232bdd7abcd2p+9,   0x1.000000000007cp-1022), // The last value before the exp flushes to subnormal
        tc64(-0x1.6232bdd7abcd3p+9,   0x1.ffffffffffcf8p-1023), // The first value for which exp flushes to subnormal
        // zig fmt: on
    };
    for (cases) |tc| {
        try tc.run();
    }
}

test "math.exp128() sanity" {
    const cases = [_]Testcase128{
        // zig fmt: off
        tc128(-0x1.02239f3c6a8f13dep+3, 0x1.490327ea61232c65cff53beed777p-12),
        tc128( 0x1.161868e18bc67782p+2, 0x1.34712ed238c064a14a59ddb90119p+6 ),
        tc128(-0x1.0c34b3e01e6e682cp+3, 0x1.e06b1b6c18e6b9852676f1295765p-13),
        tc128(-0x1.a206f0a19dcc3948p+2, 0x1.7dd47f810e68efcaa7504b9387d0p-10),
        tc128( 0x1.288bbb0d6a1e5bdap+3, 0x1.4abc77496e07b24ad548e9379bcap+13),
        tc128( 0x1.52efd0cd80496a5ap-1, 0x1.f04a9c1080500277b844a5191ca4p+0 ),
        tc128(-0x1.a05cc754481d0bd0p-2, 0x1.54f1e0fd3ea0d31771802892d4e9p-1 ),
        tc128( 0x1.1f9ef934745cad60p-1, 0x1.c0f6266a6a5473f6d16e0140d987p+0 ),
        tc128( 0x1.8c5db097f744257ep-1, 0x1.1599b1d4a25fb7c587a30b9ea597p+1 ),
        tc128(-0x1.5b86ea8118a0e2bcp-1, 0x1.03b5728a0022870d16a9c4217353p-1 ),
        // zig fmt: on
    };
    for (cases) |tc| {
        try tc.run();
    }
}

test "math.exp128() special" {
    const cases = [_]Testcase128{
        // zig fmt: off
        tc128( 0x0p+0,   0x1p+0  ),
        tc128(-0x0p+0,   0x1p+0  ),
        tc128( inf_f128, inf_f128),
        tc128(-inf_f128, 0x0p+0  ),
        tc128( nan_f128, nan_f128),
        tc128(-nan_f128, nan_f128),
        tc128(@bitCast(f128, @as(u128, 0x7fff1234000000000000000000000000)), nan_f128),
        tc128(@bitCast(f128, @as(u128, 0xffff1234000000000000000000000000)), nan_f128),
        // zig fmt: on
    };
    for (cases) |tc| {
        try tc.run();
    }
}

test "math.exp128() boundary" {
    const cases = [_]Testcase128{
        // zig fmt: off
        tc128( 0x1.62e42fefa39ef35793c7673007e5p+13, 0x1.ffffffffffffffffffffffffc4a8p+16383), // The last value before the exp gets infinite
        tc128( 0x1.62e42fefa39ef35793c7673007e6p+13, inf_f128                               ), // The first value that gives infinite exp
        tc128(-0x1.654bb3b2c73ebb059fabb506ff33p+13, 0x1p-16494                             ), // The last value before the exp flushes to zero
        tc128(-0x1.654bb3b2c73ebb059fabb506ff34p+13, 0x0p+0                                 ), // The first value at which the exp flushes to zero
        tc128(-0x1.62d918ce2421d65ff90ac8f4ce65p+13, 0x1.00000000000000000000000015c6p-16382), // The last value before the exp flushes to subnormal
        tc128(-0x1.62d918ce2421d65ff90ac8f4ce66p+13, 0x1.ffffffffffffffffffffffffeb8cp-16383), // The first value for which exp flushes to subnormal
        // zig fmt: on
    };
    for (cases) |tc| {
        try tc.run();
    }
}
