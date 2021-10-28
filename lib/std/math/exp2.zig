// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/exp2f.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/exp2.c

const std = @import("../std.zig");
const math = std.math;
const inf_f32 = math.inf_f32;
const inf_f64 = math.inf_f64;
const inf_f128 = math.inf_f128;
const nan_f32 = math.nan_f32;
const nan_f64 = math.nan_f64;
const nan_f128 = math.nan_f128;
const expect = std.testing.expect;

/// Returns 2 raised to the power of x (2^x).
///
/// Special Cases:
///  - exp2(+inf) = +inf
///  - exp2(nan)  = nan
pub fn exp2(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => exp2_32(x),
        f64 => exp2_64(x),
        f128 => exp2_128(x),
        else => @compileError("exp2 not implemented for " ++ @typeName(T)),
    };
}

const exp2_32_table = [_]f64{
    0x1.6a09e667f3bcdp-1,
    0x1.7a11473eb0187p-1,
    0x1.8ace5422aa0dbp-1,
    0x1.9c49182a3f090p-1,
    0x1.ae89f995ad3adp-1,
    0x1.c199bdd85529cp-1,
    0x1.d5818dcfba487p-1,
    0x1.ea4afa2a490dap-1,
    0x1.0000000000000p+0,
    0x1.0b5586cf9890fp+0,
    0x1.172b83c7d517bp+0,
    0x1.2387a6e756238p+0,
    0x1.306fe0a31b715p+0,
    0x1.3dea64c123422p+0,
    0x1.4bfdad5362a27p+0,
    0x1.5ab07dd485429p+0,
};

fn exp2_32(x: f32) f32 {
    const tblsiz = @intCast(u32, exp2_32_table.len);
    const redux: f32 = 0x1.8p23 / @intToFloat(f32, tblsiz);
    const P1: f32 = 0x1.62e430p-1;
    const P2: f32 = 0x1.ebfbe0p-3;
    const P3: f32 = 0x1.c6b348p-5;
    const P4: f32 = 0x1.3b2c9cp-7;

    // Return canonical NaN for any NaN input.
    if (math.isNan(x)) {
        return math.nan(f32);
    }

    var u = @bitCast(u32, x);
    const ix = u & 0x7FFFFFFF;

    // |x| > 126
    if (ix > 0x42FC0000) {
        // nan
        if (ix > 0x7F800000) {
            return x;
        }
        // x >= 128
        if (u >= 0x43000000 and u < 0x80000000) {
            return x * 0x1.0p127;
        }
        // x < -126
        if (u >= 0x80000000) {
            if (u >= 0xC3160000 or u & 0x000FFFF != 0) {
                math.doNotOptimizeAway(-0x1.0p-149 / x);
            }
            // x <= -150
            if (u >= 0xC3160000) {
                return 0;
            }
        }
    }
    // |x| <= 0x1p-25
    else if (ix <= 0x33000000) {
        return 1.0 + x;
    }

    // NOTE: musl relies on unsafe behaviours which are replicated below
    // (addition/bit-shift overflow). Appears that this produces the
    // intended result but should confirm how GCC/Clang handle this to ensure.

    var uf = x + redux;
    var i_0 = @bitCast(u32, uf);
    i_0 +%= tblsiz / 2;

    const k = i_0 / tblsiz;
    const uk = @bitCast(f64, @as(u64, 0x3FF + k) << 52);
    i_0 &= tblsiz - 1;
    uf -= redux;

    const z: f64 = x - uf;
    var r: f64 = exp2_32_table[@intCast(usize, i_0)];
    const t: f64 = r * z;
    r = r + t * (P1 + z * P2) + t * (z * z) * (P3 + z * P4);
    return @floatCast(f32, r * uk);
}

const exp2_64_table = [_]f64{
    //  exp2(z + eps)          eps
    0x1.6a09e667f3d5dp-1, 0x1.9880p-44,
    0x1.6b052fa751744p-1, 0x1.8000p-50,
    0x1.6c012750bd9fep-1, -0x1.8780p-45,
    0x1.6cfdcddd476bfp-1, 0x1.ec00p-46,
    0x1.6dfb23c651a29p-1, -0x1.8000p-50,
    0x1.6ef9298593ae3p-1, -0x1.c000p-52,
    0x1.6ff7df9519386p-1, -0x1.fd80p-45,
    0x1.70f7466f42da3p-1, -0x1.c880p-45,
    0x1.71f75e8ec5fc3p-1, 0x1.3c00p-46,
    0x1.72f8286eacf05p-1, -0x1.8300p-44,
    0x1.73f9a48a58152p-1, -0x1.0c00p-47,
    0x1.74fbd35d7ccfcp-1, 0x1.f880p-45,
    0x1.75feb564267f1p-1, 0x1.3e00p-47,
    0x1.77024b1ab6d48p-1, -0x1.7d00p-45,
    0x1.780694fde5d38p-1, -0x1.d000p-50,
    0x1.790b938ac1d00p-1, 0x1.3000p-49,
    0x1.7a11473eb0178p-1, -0x1.d000p-49,
    0x1.7b17b0976d060p-1, 0x1.0400p-45,
    0x1.7c1ed0130c133p-1, 0x1.0000p-53,
    0x1.7d26a62ff8636p-1, -0x1.6900p-45,
    0x1.7e2f336cf4e3bp-1, -0x1.2e00p-47,
    0x1.7f3878491c3e8p-1, -0x1.4580p-45,
    0x1.80427543e1b4ep-1, 0x1.3000p-44,
    0x1.814d2add1071ap-1, 0x1.f000p-47,
    0x1.82589994ccd7ep-1, -0x1.1c00p-45,
    0x1.8364c1eb942d0p-1, 0x1.9d00p-45,
    0x1.8471a4623cab5p-1, 0x1.7100p-43,
    0x1.857f4179f5bbcp-1, 0x1.2600p-45,
    0x1.868d99b4491afp-1, -0x1.2c40p-44,
    0x1.879cad931a395p-1, -0x1.3000p-45,
    0x1.88ac7d98a65b8p-1, -0x1.a800p-45,
    0x1.89bd0a4785800p-1, -0x1.d000p-49,
    0x1.8ace5422aa223p-1, 0x1.3280p-44,
    0x1.8be05bad619fap-1, 0x1.2b40p-43,
    0x1.8cf3216b54383p-1, -0x1.ed00p-45,
    0x1.8e06a5e08664cp-1, -0x1.0500p-45,
    0x1.8f1ae99157807p-1, 0x1.8280p-45,
    0x1.902fed0282c0ep-1, -0x1.cb00p-46,
    0x1.9145b0b91ff96p-1, -0x1.5e00p-47,
    0x1.925c353aa2ff9p-1, 0x1.5400p-48,
    0x1.93737b0cdc64ap-1, 0x1.7200p-46,
    0x1.948b82b5f98aep-1, -0x1.9000p-47,
    0x1.95a44cbc852cbp-1, 0x1.5680p-45,
    0x1.96bdd9a766f21p-1, -0x1.6d00p-44,
    0x1.97d829fde4e2ap-1, -0x1.1000p-47,
    0x1.98f33e47a23a3p-1, 0x1.d000p-45,
    0x1.9a0f170ca0604p-1, -0x1.8a40p-44,
    0x1.9b2bb4d53ff89p-1, 0x1.55c0p-44,
    0x1.9c49182a3f15bp-1, 0x1.6b80p-45,
    0x1.9d674194bb8c5p-1, -0x1.c000p-49,
    0x1.9e86319e3238ep-1, 0x1.7d00p-46,
    0x1.9fa5e8d07f302p-1, 0x1.6400p-46,
    0x1.a0c667b5de54dp-1, -0x1.5000p-48,
    0x1.a1e7aed8eb8f6p-1, 0x1.9e00p-47,
    0x1.a309bec4a2e27p-1, 0x1.ad80p-45,
    0x1.a42c980460a5dp-1, -0x1.af00p-46,
    0x1.a5503b23e259bp-1, 0x1.b600p-47,
    0x1.a674a8af46213p-1, 0x1.8880p-44,
    0x1.a799e1330b3a7p-1, 0x1.1200p-46,
    0x1.a8bfe53c12e8dp-1, 0x1.6c00p-47,
    0x1.a9e6b5579fcd2p-1, -0x1.9b80p-45,
    0x1.ab0e521356fb8p-1, 0x1.b700p-45,
    0x1.ac36bbfd3f381p-1, 0x1.9000p-50,
    0x1.ad5ff3a3c2780p-1, 0x1.4000p-49,
    0x1.ae89f995ad2a3p-1, -0x1.c900p-45,
    0x1.afb4ce622f367p-1, 0x1.6500p-46,
    0x1.b0e07298db790p-1, 0x1.fd40p-45,
    0x1.b20ce6c9a89a9p-1, 0x1.2700p-46,
    0x1.b33a2b84f1a4bp-1, 0x1.d470p-43,
    0x1.b468415b747e7p-1, -0x1.8380p-44,
    0x1.b59728de5593ap-1, 0x1.8000p-54,
    0x1.b6c6e29f1c56ap-1, 0x1.ad00p-47,
    0x1.b7f76f2fb5e50p-1, 0x1.e800p-50,
    0x1.b928cf22749b2p-1, -0x1.4c00p-47,
    0x1.ba5b030a10603p-1, -0x1.d700p-47,
    0x1.bb8e0b79a6f66p-1, 0x1.d900p-47,
    0x1.bcc1e904bc1ffp-1, 0x1.2a00p-47,
    0x1.bdf69c3f3a16fp-1, -0x1.f780p-46,
    0x1.bf2c25bd71db8p-1, -0x1.0a00p-46,
    0x1.c06286141b2e9p-1, -0x1.1400p-46,
    0x1.c199bdd8552e0p-1, 0x1.be00p-47,
    0x1.c2d1cd9fa64eep-1, -0x1.9400p-47,
    0x1.c40ab5fffd02fp-1, -0x1.ed00p-47,
    0x1.c544778fafd15p-1, 0x1.9660p-44,
    0x1.c67f12e57d0cbp-1, -0x1.a100p-46,
    0x1.c7ba88988c1b6p-1, -0x1.8458p-42,
    0x1.c8f6d9406e733p-1, -0x1.a480p-46,
    0x1.ca3405751c4dfp-1, 0x1.b000p-51,
    0x1.cb720dcef9094p-1, 0x1.1400p-47,
    0x1.ccb0f2e6d1689p-1, 0x1.0200p-48,
    0x1.cdf0b555dc412p-1, 0x1.3600p-48,
    0x1.cf3155b5bab3bp-1, -0x1.6900p-47,
    0x1.d072d4a0789bcp-1, 0x1.9a00p-47,
    0x1.d1b532b08c8fap-1, -0x1.5e00p-46,
    0x1.d2f87080d8a85p-1, 0x1.d280p-46,
    0x1.d43c8eacaa203p-1, 0x1.1a00p-47,
    0x1.d5818dcfba491p-1, 0x1.f000p-50,
    0x1.d6c76e862e6a1p-1, -0x1.3a00p-47,
    0x1.d80e316c9834ep-1, -0x1.cd80p-47,
    0x1.d955d71ff6090p-1, 0x1.4c00p-48,
    0x1.da9e603db32aep-1, 0x1.f900p-48,
    0x1.dbe7cd63a8325p-1, 0x1.9800p-49,
    0x1.dd321f301b445p-1, -0x1.5200p-48,
    0x1.de7d5641c05bfp-1, -0x1.d700p-46,
    0x1.dfc97337b9aecp-1, -0x1.6140p-46,
    0x1.e11676b197d5ep-1, 0x1.b480p-47,
    0x1.e264614f5a3e7p-1, 0x1.0ce0p-43,
    0x1.e3b333b16ee5cp-1, 0x1.c680p-47,
    0x1.e502ee78b3fb4p-1, -0x1.9300p-47,
    0x1.e653924676d68p-1, -0x1.5000p-49,
    0x1.e7a51fbc74c44p-1, -0x1.7f80p-47,
    0x1.e8f7977cdb726p-1, -0x1.3700p-48,
    0x1.ea4afa2a490e8p-1, 0x1.5d00p-49,
    0x1.eb9f4867ccae4p-1, 0x1.61a0p-46,
    0x1.ecf482d8e680dp-1, 0x1.5500p-48,
    0x1.ee4aaa2188514p-1, 0x1.6400p-51,
    0x1.efa1bee615a13p-1, -0x1.e800p-49,
    0x1.f0f9c1cb64106p-1, -0x1.a880p-48,
    0x1.f252b376bb963p-1, -0x1.c900p-45,
    0x1.f3ac948dd7275p-1, 0x1.a000p-53,
    0x1.f50765b6e4524p-1, -0x1.4f00p-48,
    0x1.f6632798844fdp-1, 0x1.a800p-51,
    0x1.f7bfdad9cbe38p-1, 0x1.abc0p-48,
    0x1.f91d802243c82p-1, -0x1.4600p-50,
    0x1.fa7c1819e908ep-1, -0x1.b0c0p-47,
    0x1.fbdba3692d511p-1, -0x1.0e00p-51,
    0x1.fd3c22b8f7194p-1, -0x1.0de8p-46,
    0x1.fe9d96b2a23eep-1, 0x1.e430p-49,
    0x1.0000000000000p+0, 0x0.0000p+0,
    0x1.00b1afa5abcbep+0, -0x1.3400p-52,
    0x1.0163da9fb3303p+0, -0x1.2170p-46,
    0x1.02168143b0282p+0, 0x1.a400p-52,
    0x1.02c9a3e77806cp+0, 0x1.f980p-49,
    0x1.037d42e11bbcap+0, -0x1.7400p-51,
    0x1.04315e86e7f89p+0, 0x1.8300p-50,
    0x1.04e5f72f65467p+0, -0x1.a3f0p-46,
    0x1.059b0d315855ap+0, -0x1.2840p-47,
    0x1.0650a0e3c1f95p+0, 0x1.1600p-48,
    0x1.0706b29ddf71ap+0, 0x1.5240p-46,
    0x1.07bd42b72a82dp+0, -0x1.9a00p-49,
    0x1.0874518759bd0p+0, 0x1.6400p-49,
    0x1.092bdf66607c8p+0, -0x1.0780p-47,
    0x1.09e3ecac6f383p+0, -0x1.8000p-54,
    0x1.0a9c79b1f3930p+0, 0x1.fa00p-48,
    0x1.0b5586cf988fcp+0, -0x1.ac80p-48,
    0x1.0c0f145e46c8ap+0, 0x1.9c00p-50,
    0x1.0cc922b724816p+0, 0x1.5200p-47,
    0x1.0d83b23395dd8p+0, -0x1.ad00p-48,
    0x1.0e3ec32d3d1f3p+0, 0x1.bac0p-46,
    0x1.0efa55fdfa9a6p+0, -0x1.4e80p-47,
    0x1.0fb66affed2f0p+0, -0x1.d300p-47,
    0x1.1073028d7234bp+0, 0x1.1500p-48,
    0x1.11301d0125b5bp+0, 0x1.c000p-49,
    0x1.11edbab5e2af9p+0, 0x1.6bc0p-46,
    0x1.12abdc06c31d5p+0, 0x1.8400p-49,
    0x1.136a814f2047dp+0, -0x1.ed00p-47,
    0x1.1429aaea92de9p+0, 0x1.8e00p-49,
    0x1.14e95934f3138p+0, 0x1.b400p-49,
    0x1.15a98c8a58e71p+0, 0x1.5300p-47,
    0x1.166a45471c3dfp+0, 0x1.3380p-47,
    0x1.172b83c7d5211p+0, 0x1.8d40p-45,
    0x1.17ed48695bb9fp+0, -0x1.5d00p-47,
    0x1.18af9388c8d93p+0, -0x1.c880p-46,
    0x1.1972658375d66p+0, 0x1.1f00p-46,
    0x1.1a35beb6fcba7p+0, 0x1.0480p-46,
    0x1.1af99f81387e3p+0, -0x1.7390p-43,
    0x1.1bbe084045d54p+0, 0x1.4e40p-45,
    0x1.1c82f95281c43p+0, -0x1.a200p-47,
    0x1.1d4873168b9b2p+0, 0x1.3800p-49,
    0x1.1e0e75eb44031p+0, 0x1.ac00p-49,
    0x1.1ed5022fcd938p+0, 0x1.1900p-47,
    0x1.1f9c18438cdf7p+0, -0x1.b780p-46,
    0x1.2063b88628d8fp+0, 0x1.d940p-45,
    0x1.212be3578a81ep+0, 0x1.8000p-50,
    0x1.21f49917ddd41p+0, 0x1.b340p-45,
    0x1.22bdda2791323p+0, 0x1.9f80p-46,
    0x1.2387a6e7561e7p+0, -0x1.9c80p-46,
    0x1.2451ffb821427p+0, 0x1.2300p-47,
    0x1.251ce4fb2a602p+0, -0x1.3480p-46,
    0x1.25e85711eceb0p+0, 0x1.2700p-46,
    0x1.26b4565e27d16p+0, 0x1.1d00p-46,
    0x1.2780e341de00fp+0, 0x1.1ee0p-44,
    0x1.284dfe1f5633ep+0, -0x1.4c00p-46,
    0x1.291ba7591bb30p+0, -0x1.3d80p-46,
    0x1.29e9df51fdf09p+0, 0x1.8b00p-47,
    0x1.2ab8a66d10e9bp+0, -0x1.27c0p-45,
    0x1.2b87fd0dada3ap+0, 0x1.a340p-45,
    0x1.2c57e39771af9p+0, -0x1.0800p-46,
    0x1.2d285a6e402d9p+0, -0x1.ed00p-47,
    0x1.2df961f641579p+0, -0x1.4200p-48,
    0x1.2ecafa93e2ecfp+0, -0x1.4980p-45,
    0x1.2f9d24abd8822p+0, -0x1.6300p-46,
    0x1.306fe0a31b625p+0, -0x1.2360p-44,
    0x1.31432edeea50bp+0, -0x1.0df8p-40,
    0x1.32170fc4cd7b8p+0, -0x1.2480p-45,
    0x1.32eb83ba8e9a2p+0, -0x1.5980p-45,
    0x1.33c08b2641766p+0, 0x1.ed00p-46,
    0x1.3496266e3fa27p+0, -0x1.c000p-50,
    0x1.356c55f929f0fp+0, -0x1.0d80p-44,
    0x1.36431a2de88b9p+0, 0x1.2c80p-45,
    0x1.371a7373aaa39p+0, 0x1.0600p-45,
    0x1.37f26231e74fep+0, -0x1.6600p-46,
    0x1.38cae6d05d838p+0, -0x1.ae00p-47,
    0x1.39a401b713ec3p+0, -0x1.4720p-43,
    0x1.3a7db34e5a020p+0, 0x1.8200p-47,
    0x1.3b57fbfec6e95p+0, 0x1.e800p-44,
    0x1.3c32dc313a8f2p+0, 0x1.f800p-49,
    0x1.3d0e544ede122p+0, -0x1.7a00p-46,
    0x1.3dea64c1234bbp+0, 0x1.6300p-45,
    0x1.3ec70df1c4eccp+0, -0x1.8a60p-43,
    0x1.3fa4504ac7e8cp+0, -0x1.cdc0p-44,
    0x1.40822c367a0bbp+0, 0x1.5b80p-45,
    0x1.4160a21f72e95p+0, 0x1.ec00p-46,
    0x1.423fb27094646p+0, -0x1.3600p-46,
    0x1.431f5d950a920p+0, 0x1.3980p-45,
    0x1.43ffa3f84b9ebp+0, 0x1.a000p-48,
    0x1.44e0860618919p+0, -0x1.6c00p-48,
    0x1.45c2042a7d201p+0, -0x1.bc00p-47,
    0x1.46a41ed1d0016p+0, -0x1.2800p-46,
    0x1.4786d668b3326p+0, 0x1.0e00p-44,
    0x1.486a2b5c13c00p+0, -0x1.d400p-45,
    0x1.494e1e192af04p+0, 0x1.c200p-47,
    0x1.4a32af0d7d372p+0, -0x1.e500p-46,
    0x1.4b17dea6db801p+0, 0x1.7800p-47,
    0x1.4bfdad53629e1p+0, -0x1.3800p-46,
    0x1.4ce41b817c132p+0, 0x1.0800p-47,
    0x1.4dcb299fddddbp+0, 0x1.c700p-45,
    0x1.4eb2d81d8ab96p+0, -0x1.ce00p-46,
    0x1.4f9b2769d2d02p+0, 0x1.9200p-46,
    0x1.508417f4531c1p+0, -0x1.8c00p-47,
    0x1.516daa2cf662ap+0, -0x1.a000p-48,
    0x1.5257de83f51eap+0, 0x1.a080p-43,
    0x1.5342b569d4edap+0, -0x1.6d80p-45,
    0x1.542e2f4f6ac1ap+0, -0x1.2440p-44,
    0x1.551a4ca5d94dbp+0, 0x1.83c0p-43,
    0x1.56070dde9116bp+0, 0x1.4b00p-45,
    0x1.56f4736b529dep+0, 0x1.15a0p-43,
    0x1.57e27dbe2c40ep+0, -0x1.9e00p-45,
    0x1.58d12d497c76fp+0, -0x1.3080p-45,
    0x1.59c0827ff0b4cp+0, 0x1.dec0p-43,
    0x1.5ab07dd485427p+0, -0x1.4000p-51,
    0x1.5ba11fba87af4p+0, 0x1.0080p-44,
    0x1.5c9268a59460bp+0, -0x1.6c80p-45,
    0x1.5d84590998e3fp+0, 0x1.69a0p-43,
    0x1.5e76f15ad20e1p+0, -0x1.b400p-46,
    0x1.5f6a320dcebcap+0, 0x1.7700p-46,
    0x1.605e1b976dcb8p+0, 0x1.6f80p-45,
    0x1.6152ae6cdf715p+0, 0x1.1000p-47,
    0x1.6247eb03a5531p+0, -0x1.5d00p-46,
    0x1.633dd1d1929b5p+0, -0x1.2d00p-46,
    0x1.6434634ccc313p+0, -0x1.a800p-49,
    0x1.652b9febc8efap+0, -0x1.8600p-45,
    0x1.6623882553397p+0, 0x1.1fe0p-40,
    0x1.671c1c708328ep+0, -0x1.7200p-44,
    0x1.68155d44ca97ep+0, 0x1.6800p-49,
    0x1.690f4b19e9471p+0, -0x1.9780p-45,
};

fn exp2_64(x: f64) f64 {
    const tblsiz: u32 = @intCast(u32, exp2_64_table.len / 2);
    const redux: f64 = 0x1.8p52 / @intToFloat(f64, tblsiz);
    const P1: f64 = 0x1.62e42fefa39efp-1;
    const P2: f64 = 0x1.ebfbdff82c575p-3;
    const P3: f64 = 0x1.c6b08d704a0a6p-5;
    const P4: f64 = 0x1.3b2ab88f70400p-7;
    const P5: f64 = 0x1.5d88003875c74p-10;

    // Return canonical NaN for any NaN input.
    if (math.isNan(x)) {
        return math.nan(f64);
    }

    const ux = @bitCast(u64, x);
    const ix = @intCast(u32, ux >> 32) & 0x7FFFFFFF;

    // |x| >= 1022 or nan
    if (ix >= 0x408FF000) {
        // x >= 1024 or nan
        if (ix >= 0x40900000 and ux >> 63 == 0) {
            math.raiseOverflow();
            return math.inf(f64);
        }
        // -inf or nan
        if (ix >= 0x7FF00000) {
            return -1 / x;
        }
        // x <= -1022
        if (ux >> 63 != 0) {
            // underflow
            if (x <= -1075 or x - 0x1.0p52 + 0x1.0p52 != x) {
                math.doNotOptimizeAway(@floatCast(f32, -0x1.0p-149 / x));
            }
            if (x <= -1075) {
                return 0;
            }
        }
    }
    // |x| < 0x1p-54
    else if (ix < 0x3C900000) {
        return 1.0 + x;
    }

    // NOTE: musl relies on unsafe behaviours which are replicated below
    // (addition overflow, division truncation, casting). Appears that this
    // produces the intended result but should confirm how GCC/Clang handle this
    // to ensure.

    // reduce x
    var uf: f64 = x + redux;
    var i_0: u32 = @truncate(u32, @bitCast(u64, uf));
    i_0 +%= tblsiz / 2;

    const k: u32 = i_0 / tblsiz * tblsiz;
    const ik: i32 = @divTrunc(@bitCast(i32, k), tblsiz);
    i_0 %= tblsiz;
    uf -= redux;

    // r = exp2(y) = exp2t[i_0] * p(z - eps[i])
    var z: f64 = x - uf;
    const t: f64 = exp2_64_table[@intCast(usize, 2 * i_0)];
    z -= exp2_64_table[@intCast(usize, 2 * i_0 + 1)];
    const r: f64 = t + t * z * (P1 + z * (P2 + z * (P3 + z * (P4 + z * P5))));

    return math.scalbn(r, ik);
}

const exp2_128_table = [_]f128{
    0x1.6a09e667f3bcc908b2fb1366dfeap-1,
    0x1.6c012750bdabeed76a99800f4edep-1,
    0x1.6dfb23c651a2ef220e2cbe1bc0d4p-1,
    0x1.6ff7df9519483cf87e1b4f3e1e98p-1,
    0x1.71f75e8ec5f73dd2370f2ef0b148p-1,
    0x1.73f9a48a58173bd5c9a4e68ab074p-1,
    0x1.75feb564267c8bf6e9aa33a489a8p-1,
    0x1.780694fde5d3f619ae02808592a4p-1,
    0x1.7a11473eb0186d7d51023f6ccb1ap-1,
    0x1.7c1ed0130c1327c49334459378dep-1,
    0x1.7e2f336cf4e62105d02ba1579756p-1,
    0x1.80427543e1a11b60de67649a3842p-1,
    0x1.82589994cce128acf88afab34928p-1,
    0x1.8471a4623c7acce52f6b97c6444cp-1,
    0x1.868d99b4492ec80e41d90ac2556ap-1,
    0x1.88ac7d98a669966530bcdf2d4cc0p-1,
    0x1.8ace5422aa0db5ba7c55a192c648p-1,
    0x1.8cf3216b5448bef2aa1cd161c57ap-1,
    0x1.8f1ae991577362b982745c72eddap-1,
    0x1.9145b0b91ffc588a61b469f6b6a0p-1,
    0x1.93737b0cdc5e4f4501c3f2540ae8p-1,
    0x1.95a44cbc8520ee9b483695a0e7fep-1,
    0x1.97d829fde4e4f8b9e920f91e8eb6p-1,
    0x1.9a0f170ca07b9ba3109b8c467844p-1,
    0x1.9c49182a3f0901c7c46b071f28dep-1,
    0x1.9e86319e323231824ca78e64c462p-1,
    0x1.a0c667b5de564b29ada8b8cabbacp-1,
    0x1.a309bec4a2d3358c171f770db1f4p-1,
    0x1.a5503b23e255c8b424491caf88ccp-1,
    0x1.a799e1330b3586f2dfb2b158f31ep-1,
    0x1.a9e6b5579fdbf43eb243bdff53a2p-1,
    0x1.ac36bbfd3f379c0db966a3126988p-1,
    0x1.ae89f995ad3ad5e8734d17731c80p-1,
    0x1.b0e07298db66590842acdfc6fb4ep-1,
    0x1.b33a2b84f15faf6bfd0e7bd941b0p-1,
    0x1.b59728de559398e3881111648738p-1,
    0x1.b7f76f2fb5e46eaa7b081ab53ff6p-1,
    0x1.ba5b030a10649840cb3c6af5b74cp-1,
    0x1.bcc1e904bc1d2247ba0f45b3d06cp-1,
    0x1.bf2c25bd71e088408d7025190cd0p-1,
    0x1.c199bdd85529c2220cb12a0916bap-1,
    0x1.c40ab5fffd07a6d14df820f17deap-1,
    0x1.c67f12e57d14b4a2137fd20f2a26p-1,
    0x1.c8f6d9406e7b511acbc48805c3f6p-1,
    0x1.cb720dcef90691503cbd1e949d0ap-1,
    0x1.cdf0b555dc3f9c44f8958fac4f12p-1,
    0x1.d072d4a07897b8d0f22f21a13792p-1,
    0x1.d2f87080d89f18ade123989ea50ep-1,
    0x1.d5818dcfba48725da05aeb66dff8p-1,
    0x1.d80e316c98397bb84f9d048807a0p-1,
    0x1.da9e603db3285708c01a5b6d480cp-1,
    0x1.dd321f301b4604b695de3c0630c0p-1,
    0x1.dfc97337b9b5eb968cac39ed284cp-1,
    0x1.e264614f5a128a12761fa17adc74p-1,
    0x1.e502ee78b3ff6273d130153992d0p-1,
    0x1.e7a51fbc74c834b548b2832378a4p-1,
    0x1.ea4afa2a490d9858f73a18f5dab4p-1,
    0x1.ecf482d8e67f08db0312fb949d50p-1,
    0x1.efa1bee615a27771fd21a92dabb6p-1,
    0x1.f252b376bba974e8696fc3638f24p-1,
    0x1.f50765b6e4540674f84b762861a6p-1,
    0x1.f7bfdad9cbe138913b4bfe72bd78p-1,
    0x1.fa7c1819e90d82e90a7e74b26360p-1,
    0x1.fd3c22b8f71f10975ba4b32bd006p-1,
    0x1.0000000000000000000000000000p+0,
    0x1.0163da9fb33356d84a66ae336e98p+0,
    0x1.02c9a3e778060ee6f7caca4f7a18p+0,
    0x1.04315e86e7f84bd738f9a20da442p+0,
    0x1.059b0d31585743ae7c548eb68c6ap+0,
    0x1.0706b29ddf6ddc6dc403a9d87b1ep+0,
    0x1.0874518759bc808c35f25d942856p+0,
    0x1.09e3ecac6f3834521e060c584d5cp+0,
    0x1.0b5586cf9890f6298b92b7184200p+0,
    0x1.0cc922b7247f7407b705b893dbdep+0,
    0x1.0e3ec32d3d1a2020742e4f8af794p+0,
    0x1.0fb66affed31af232091dd8a169ep+0,
    0x1.11301d0125b50a4ebbf1aed9321cp+0,
    0x1.12abdc06c31cbfb92bad324d6f84p+0,
    0x1.1429aaea92ddfb34101943b2588ep+0,
    0x1.15a98c8a58e512480d573dd562aep+0,
    0x1.172b83c7d517adcdf7c8c50eb162p+0,
    0x1.18af9388c8de9bbbf70b9a3c269cp+0,
    0x1.1a35beb6fcb753cb698f692d2038p+0,
    0x1.1bbe084045cd39ab1e72b442810ep+0,
    0x1.1d4873168b9aa7805b8028990be8p+0,
    0x1.1ed5022fcd91cb8819ff61121fbep+0,
    0x1.2063b88628cd63b8eeb0295093f6p+0,
    0x1.21f49917ddc962552fd29294bc20p+0,
    0x1.2387a6e75623866c1fadb1c159c0p+0,
    0x1.251ce4fb2a63f3582ab7de9e9562p+0,
    0x1.26b4565e27cdd257a673281d3068p+0,
    0x1.284dfe1f5638096cf15cf03c9fa0p+0,
    0x1.29e9df51fdee12c25d15f5a25022p+0,
    0x1.2b87fd0dad98ffddea46538fca24p+0,
    0x1.2d285a6e4030b40091d536d0733ep+0,
    0x1.2ecafa93e2f5611ca0f45d5239a4p+0,
    0x1.306fe0a31b7152de8d5a463063bep+0,
    0x1.32170fc4cd8313539cf1c3009330p+0,
    0x1.33c08b26416ff4c9c8610d96680ep+0,
    0x1.356c55f929ff0c94623476373be4p+0,
    0x1.371a7373aa9caa7145502f45452ap+0,
    0x1.38cae6d05d86585a9cb0d9bed530p+0,
    0x1.3a7db34e59ff6ea1bc9299e0a1fep+0,
    0x1.3c32dc313a8e484001f228b58cf0p+0,
    0x1.3dea64c12342235b41223e13d7eep+0,
    0x1.3fa4504ac801ba0bf701aa417b9cp+0,
    0x1.4160a21f72e29f84325b8f3dbacap+0,
    0x1.431f5d950a896dc704439410b628p+0,
    0x1.44e086061892d03136f409df0724p+0,
    0x1.46a41ed1d005772512f459229f0ap+0,
    0x1.486a2b5c13cd013c1a3b69062f26p+0,
    0x1.4a32af0d7d3de672d8bcf46f99b4p+0,
    0x1.4bfdad5362a271d4397afec42e36p+0,
    0x1.4dcb299fddd0d63b36ef1a9e19dep+0,
    0x1.4f9b2769d2ca6ad33d8b69aa0b8cp+0,
    0x1.516daa2cf6641c112f52c84d6066p+0,
    0x1.5342b569d4f81df0a83c49d86bf4p+0,
    0x1.551a4ca5d920ec52ec620243540cp+0,
    0x1.56f4736b527da66ecb004764e61ep+0,
    0x1.58d12d497c7fd252bc2b7343d554p+0,
    0x1.5ab07dd48542958c93015191e9a8p+0,
    0x1.5c9268a5946b701c4b1b81697ed4p+0,
    0x1.5e76f15ad21486e9be4c20399d12p+0,
    0x1.605e1b976dc08b076f592a487066p+0,
    0x1.6247eb03a5584b1f0fa06fd2d9eap+0,
    0x1.6434634ccc31fc76f8714c4ee122p+0,
    0x1.66238825522249127d9e29b92ea2p+0,
    0x1.68155d44ca973081c57227b9f69ep+0,
};

// Use a separate table since these values are only 32-bit floats.
const exp2_128_eps_table = [exp2_128_table.len]f32{
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

fn exp2_128(x: f128) f128 {
    const tblsiz: u32 = @intCast(u32, exp2_128_table.len);
    const redux: f128 = 0x1.8p112 / @intToFloat(f128, tblsiz);

    const P1: f128 = 0x1.62e42fefa39ef35793c7673007e6p-1;
    const P2: f128 = 0x1.ebfbdff82c58ea86f16b06ec9736p-3;
    const P3: f128 = 0x1.c6b08d704a0bf8b33a762bad3459p-5;
    const P4: f128 = 0x1.3b2ab6fba4e7729ccbbe0b4f3fc2p-7;
    const P5: f128 = 0x1.5d87fe78a67311071dee13fd11d9p-10;
    const P6: f128 = 0x1.430912f86c7876f4b663b23c5fe5p-13;
    const P7: f64 = 0x1.ffcbfc588b041p-17;
    const P8: f64 = 0x1.62c0223a5c7c7p-20;
    const P9: f64 = 0x1.b52541ff59713p-24;
    const P10: f64 = 0x1.e4cf56a391e22p-28;

    // Return canonical NaN for any NaN input.
    if (math.isNan(x)) {
        return math.nan(f128);
    }

    const ux = @bitCast(u128, x);
    const e: u16 = @intCast(u16, ux >> 112) & 0x7FFF; // exponent

    // |x| >= 16384 or nan
    if (e >= 0x3FFF + 14) {
        // x >= 16384
        if (e >= 0x3FFF + 15 and ux >> 127 == 0) {
            math.raiseOverflow();
            return math.inf(f128);
        }
        // -inf or nan
        if (e == 0x7FFF) {
            return -1 / x;
        }
        // x <= -1022
        if (x < -16382) {
            // underflow
            if (x <= -16495 or x - 0x1p112 + 0x1p112 != x) {
                math.doNotOptimizeAway(@floatCast(f32, -0x1.0p-149 / x));
            }
            if (x <= -16495) {
                return 0;
            }
        }
    }
    // |x| < 0x1p-114
    else if (e < 0x3FFF - 114) {
        return 1.0 + x;
    }

    // NOTE: musl relies on unsafe behaviours which are replicated below
    // (addition overflow, division truncation, casting). Appears that this
    // produces the intended result but should confirm how GCC/Clang handle this
    // to ensure.

    // reduce x
    var u_f: f128 = x + redux;
    var i_0: u32 = @truncate(u32, @bitCast(u128, u_f));
    _ = @addWithOverflow(u32, i_0, tblsiz / 2, &i_0);

    const k_u: u32 = i_0 / tblsiz * tblsiz;
    const k_i: i32 = @divTrunc(@bitCast(i32, k_u), tblsiz);
    i_0 %= tblsiz;
    u_f -= redux;
    var z: f128 = x - u_f;

    // r = exp2(y) = exp2t[i_0] * p(z - eps[i])
    const t: f128 = exp2_128_table[@intCast(usize, i_0)];
    z -= exp2_128_eps_table[@intCast(usize, i_0)];
    // zig fmt: off
    const r: f128 = t + t * z * (P1 + z * (P2 + z * (P3 + z * (P4 + z * (P5
        + z * (P6 + z * (P7 + z * (P8 + z * (P9 + z * P10)))))))));
    // zig fmt: on

    return math.scalbn(r, k_i);
}

test "math.exp2() delegation" {
    try expect(exp2(@as(f32, 0.8923)) == exp2_32(0.8923));
    try expect(exp2(@as(f64, 0.8923)) == exp2_64(0.8923));
    try expect(exp2(@as(f128, 0.8923)) == exp2_128(0.8923));
}

test "math.exp2_32() basic" {
    const epsilon = 0.000001;

    try expect(exp2_32(0.0) == 1.0);
    try expect(math.approxEqAbs(f32, exp2_32(0.2), 1.148698, epsilon));
    try expect(math.approxEqAbs(f32, exp2_32(0.8923), 1.856133, epsilon));
    try expect(math.approxEqAbs(f32, exp2_32(1.5), 2.828427, epsilon));
    try expect(math.approxEqAbs(f32, exp2_32(37.45), 187747237888, epsilon));
    try expect(math.approxEqAbs(f32, exp2_32(-1), 0.5, epsilon));
}

test "math.exp2_64() basic" {
    const epsilon = 0.000001;

    try expect(exp2_64(0.0) == 1.0);
    try expect(math.approxEqAbs(f64, exp2_64(0.2), 1.148698, epsilon));
    try expect(math.approxEqAbs(f64, exp2_64(0.8923), 1.856133, epsilon));
    try expect(math.approxEqAbs(f64, exp2_64(1.5), 2.828427, epsilon));
    try expect(math.approxEqAbs(f64, exp2_64(-1), 0.5, epsilon));
}

test "math.exp2_128() basic" {
    const epsilon = 0.000001;

    try expect(exp2_128(0.0) == 1.0);
    try expect(math.approxEqAbs(f128, exp2_128(0.2), 1.148698, epsilon));
    try expect(math.approxEqAbs(f128, exp2_128(0.8923), 1.856133, epsilon));
    try expect(math.approxEqAbs(f128, exp2_128(1.5), 2.828427, epsilon));
    try expect(math.approxEqAbs(f128, exp2_128(-1), 0.5, epsilon));
}

const Testcase32 = struct {
    input: f32,
    exp_output: f32,

    pub fn run(tc: @This()) !void {
        const output = exp2_32(tc.input);
        // Compare bits rather than values so that NaN compares correctly.
        if (@bitCast(u32, output) != @bitCast(u32, tc.exp_output)) {
            std.debug.print(
                "expected exp2_32({x})->{x}, got {x}\n",
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
        const output = exp2_64(tc.input);
        // Compare bits rather than values so that NaN compares correctly.
        if (@bitCast(u64, output) != @bitCast(u64, tc.exp_output)) {
            std.debug.print(
                "expected exp2_64({x})->{x}, got {x}\n",
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
        const output = exp2_128(tc.input);
        // Compare bits rather than values so that NaN compares correctly.
        if (@bitCast(u128, output) != @bitCast(u128, tc.exp_output)) {
            std.debug.print(
                "expected exp2_128({x})->{x}, got {x}\n",
                .{ tc.input, tc.exp_output, output },
            );
            return error.TestExpectedEqual;
        }
    }
};

fn tc128(input: f128, exp_output: f128) Testcase128 {
    return .{ .input = input, .exp_output = exp_output };
}

test "math.exp2_32() sanity" {
    const cases = [_]Testcase32{
        // zig fmt: off
        tc32(-0x1.0223a0p+3, 0x1.e8d134p-9),
        tc32( 0x1.161868p+2, 0x1.453672p+4),
        tc32(-0x1.0c34b4p+3, 0x1.890ca0p-9),
        tc32(-0x1.a206f0p+2, 0x1.622d4ep-7),
        tc32( 0x1.288bbcp+3, 0x1.340ecep+9),
        tc32( 0x1.52efd0p-1, 0x1.950eeep+0),
        tc32(-0x1.a05cc8p-2, 0x1.824056p-1),
        tc32( 0x1.1f9efap-1, 0x1.79dfa2p+0),
        tc32( 0x1.8c5db0p-1, 0x1.b5ceacp+0),
        tc32(-0x1.5b86eap-1, 0x1.3fd8bap-1),
        // zig fmt: on
    };
    for (cases) |tc| {
        try tc.run();
    }
}

test "math.exp2_32() special" {
    const cases = [_]Testcase32{
        // zig fmt: off
        tc32( 0x0p+0,  0x1p+0 ),
        tc32(-0x0p+0,  0x1p+0 ),
        tc32( 0x1p+0,  0x1p+1 ),
        tc32(-0x1p+0,  0x1p-1 ),
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

test "math.exp2_32() boundary" {
    const cases = [_]Testcase32{
        // zig fmt: off
        tc32( 0x1.fffffep+6, 0x1.ffff4ep+127), // The last value before the exp gets infinite
        tc32( 0x1p+7,        inf_f32        ), // The first value that gives infinite exp
        tc32(-0x1.2ap+7,     0x1p-149       ), // The last value before the exp flushes to zero
        // TODO: Failing to flush to zero.
        // tc32(-0x1.2a0002p+7, 0x0p+0         ), // The first value at which the exp flushes to zero
        tc32(-0x1.f8p+6,     0x1p-126       ), // The last value before the exp flushes to subnormal
        tc32(-0x1.f80002p+6, 0x1.ffff5p-127 ), // The first value for which exp flushes to subnormal
        tc32(-0x1.fcp+6,     0x1p-127       ),
        // zig fmt: on
    };
    for (cases) |tc| {
        try tc.run();
    }
}

test "math.exp2_64() sanity" {
    const cases = [_]Testcase64{
        // zig fmt: off
        tc64(-0x1.02239f3c6a8f1p+3, 0x1.e8d13c396f452p-9),
        tc64( 0x1.161868e18bc67p+2, 0x1.4536746bb6f12p+4),
        tc64(-0x1.0c34b3e01e6e7p+3, 0x1.890ca0c00b9a2p-9),
        tc64(-0x1.a206f0a19dcc4p+2, 0x1.622d4b0ebc6c1p-7),
        tc64( 0x1.288bbb0d6a1e6p+3, 0x1.340ec7f3e607ep+9),
        tc64( 0x1.52efd0cd80497p-1, 0x1.950eef4bc5451p+0),
        tc64(-0x1.a05cc754481d1p-2, 0x1.824056efc687cp-1),
        tc64( 0x1.1f9ef934745cbp-1, 0x1.79dfa14ab121ep+0),
        tc64( 0x1.8c5db097f7442p-1, 0x1.b5cead2247372p+0),
        tc64(-0x1.5b86ea8118a0ep-1, 0x1.3fd8ba33216b9p-1),
        // zig fmt: on
    };
    for (cases) |tc| {
        try tc.run();
    }
}

test "math.exp2_64() special" {
    const cases = [_]Testcase64{
        // zig fmt: off
        tc64( 0x0p+0,  0x1p+0 ),
        tc64(-0x0p+0,  0x1p+0 ),
        tc64( 0x1p+0,  0x1p+1 ),
        tc64(-0x1p+0,  0x1p-1 ),
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

test "math.exp2_64() boundary" {
    const cases = [_]Testcase64{
        // zig fmt: off
        tc64( 0x1.fffffffffffffp+9,  0x1.ffffffffffd3ap+1023), // The last value before the exp gets infinite
        tc64( 0x1p+10,               inf_f64                ), // The first value that gives infinite exp
        tc64(-0x1.0c8p+10,           0x1p-1074              ), // The last value before the exp flushes to zero
        // TODO: Failing to flush to zero.
        // tc64(-0x1.0c80000000001p+10, 0x0p+0                 ), // The first value at which the exp flushes to zero
        tc64(-0x1.ffp+9,             0x1p-1022              ), // The last value before the exp flushes to subnormal
        tc64(-0x1.ff00000000001p+9,  0x1.ffffffffffd3ap-1023), // The first value for which exp flushes to subnormal
        tc64(-0x1.ff8p+9,            0x1p-1023              ),
        // zig fmt: on
    };
    for (cases) |tc| {
        try tc.run();
    }
}

test "math.exp2_128() sanity" {
    const cases = [_]Testcase128{
        // zig fmt: off
        tc128(-0x1.02239f3c6a8f13dep+3, 0x1.e8d13c396f44f500bfc7cefe1304p-9),
        tc128( 0x1.161868e18bc67782p+2, 0x1.4536746bb6f139f3c05f40f3758dp+4),
        tc128(-0x1.0c34b3e01e6e682cp+3, 0x1.890ca0c00b9a679b66a1cc43e168p-9),
        tc128(-0x1.a206f0a19dcc3948p+2, 0x1.622d4b0ebc6c2e5980cda14724e4p-7),
        tc128( 0x1.288bbb0d6a1e5bdap+3, 0x1.340ec7f3e607c5bd584d33ade9aep+9),
        tc128( 0x1.52efd0cd80496a5ap-1, 0x1.950eef4bc5450eeabc992d9ba86ap+0),
        tc128(-0x1.a05cc754481d0bd0p-2, 0x1.824056efc687c4f8b3c7e1f4f9fbp-1),
        tc128( 0x1.1f9ef934745cad60p-1, 0x1.79dfa14ab121da4f38057c8f9f2ep+0),
        tc128( 0x1.8c5db097f744257ep-1, 0x1.b5cead22473723958363b617f84ep+0),
        tc128(-0x1.5b86ea8118a0e2bcp-1, 0x1.3fd8ba33216b93ceab3a5697c480p-1),
        // zig fmt: on
    };
    for (cases) |tc| {
        try tc.run();
    }
}

test "math.exp2_128() special" {
    const cases = [_]Testcase128{
        // zig fmt: off
        tc128( 0x0p+0,   0x1p+0  ),
        tc128(-0x0p+0,   0x1p+0  ),
        tc128( 0x1p+0,   0x1p+1  ),
        tc128(-0x1p+0,   0x1p-1  ),
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

test "math.exp2_128() boundary" {
    const cases = [_]Testcase128{
        // zig fmt: off
        tc128( 0x1p+14 - 0x1p-99,      0x1.ffffffffffffffffffffffffd3a3p+16383), // The last value before the exp gets infinite
        tc128( 0x1p+14,                inf_f128                               ), // The first value that gives infinite exp
        tc128(-0x1.01b8p+14,           0x1p-16494                             ), // The last value before the exp flushes to zero
        // TODO: Failing to flush to zero.
        // tc128(-0x1.01b8p+14 - 0x1p-98, 0x0p+0                                 ), // The first value at which the exp flushes to zero
        tc128(-0x1.fffp+13,            0x1p-16382                             ), // The last value before the exp flushes to subnormal
        tc128(-0x1.fffp+13 - 0x1p-99,  0x0.ffffffffffffffffffffffffe9d2p-16382), // The first value for which exp flushes to subnormal
        tc128(-0x1.fff8p+13,           0x1p-16383                             ),
        // zig fmt: on
    };
    for (cases) |tc| {
        try tc.run();
    }
}
