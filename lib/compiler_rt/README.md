If hardware lacks basic or specialized functionality, compiler-rt adds such functionality
for basic arithmetic(s).
One such example is 64-bit integer multiplication on 32-bit x86.

Goals:
1. zig as linker for object files produced by other compilers
   => `function compatibility` to compiler-rt and libgcc for same-named functions
   * compatibility conflict between compiler-rt and libgcc: prefer compiler-rt
2. `symbol-level compatibility` low-priority compared to emitted calls by llvm
   * symbol-level compatibility: libgcc even lower priority
3. add zig-specific language runtime features, see #7265
   * example: arbitrary bit width integer arithmetic
   * lower to call those functions for e.g. multiplying two i12345 numbers together
   * proper naming + documention for standardizing (allow languages to follow our exmaple)

Current status (tracking libgcc documentation):
- Integer library routines => almost implemented
- Soft float library routines => finished
- Decimal float library routines => unimplemented (~120 functions)
- Fixed-point fractional library routines => unimplemented (~300 functions)
- Exception handling routines => unclear, if supported (~32+x undocumented functions)
- Miscellaneous routines => unclear, if supported (cache control and stack function)
- No zig-specific language runtime features in compiler-rt yet

This library is automatically built as-needed for the compilation target and
then statically linked and therefore is a transparent dependency for the
programmer.
For details see `../compiler_rt.zig`.

Bugs should be solved by trying to duplicate the bug upstream, if possible.
 * If the bug exists upstream, get it fixed upstream and port the fix downstream to Zig.
 * If the bug only exists in Zig, use the corresponding C code and debug
   both implementations side by side to figure out what is wrong.

Routines with status are given below. Sources were besides
"The Art of Computer Programming" by Donald E. Knuth, "HackersDelight" by Henry S. Warren,
"Bit Twiddling Hacks" collected by Sean Eron Anderson, "Berkeley SoftFloat" by John R. Hauser,
LLVM "compiler-rt" as it was MIT-licensed, "musl libc" and thoughts + work of contributors.

The compiler-rt routines have not yet been audited.
See https://github.com/ziglang/zig/issues/1504.

From left to right the columns mean 1. if the routine is implemented (✗ or ✓),
2. the name, 3. input (`a`), 4. input (`b`), 5. return value,
6. an explanation of the functionality, .. to repeat the comment from the
column a row above and/or additional return values.
Some routines have more extensive comments supplemented with a reference text.

Integer and Float Operations

| Done   | Name          | a    | b    | Out  | Comment                        |
| ------ | ------------- | ---- | ---- | ---- | ------------------------------ |
|   |                    |      |      |      | **Integer Bit Operations**     |
| ✓ | __clzsi2           | u32  | ∅    | i32  | count leading zeros            |
| ✓ | __clzdi2           | u64  | ∅    | i32  | count leading zeros            |
| ✓ | __clzti2           | u128 | ∅    | i32  | count leading zeros            |
| ✓ | __ctzsi2           | u32  | ∅    | i32  | count trailing zeros           |
| ✓ | __ctzdi2           | u64  | ∅    | i32  | count trailing zeros           |
| ✓ | __ctzti2           | u128 | ∅    | i32  | count trailing zeros           |
| ✓ | __ffssi2           | u32  | ∅    | i32  | find least significant 1 bit   |
| ✓ | __ffsdi2           | u64  | ∅    | i32  | find least significant 1 bit   |
| ✓ | __ffsti2           | u128 | ∅    | i32  | find least significant 1 bit   |
| ✓ | __paritysi2        | u32  | ∅    | i32  | bit parity                     |
| ✓ | __paritydi2        | u64  | ∅    | i32  | bit parity                     |
| ✓ | __parityti2        | u128 | ∅    | i32  | bit parity                     |
| ✓ | __popcountsi2      | u32  | ∅    | i32  | bit population                 |
| ✓ | __popcountdi2      | u64  | ∅    | i32  | bit population                 |
| ✓ | __popcountti2      | u128 | ∅    | i32  | bit population                 |
| ✓ | __bswapsi2         | u32  | ∅    | i32  | byte swap                      |
| ✓ | __bswapdi2         | u64  | ∅    | i32  | byte swap                      |
| ✓ | __bswapti2         | u128 | ∅    | i32  | byte swap                      |
|   |                    |      |      |      | **Integer Comparison**         |
| ✓ | __cmpsi2           | i32  | i32  | i32  | `(a<b) -> 0, (a==b) -> 1, (a>b) -> 2` |
| ✓ | __cmpdi2           | i64  | i64  | i32  | ..                             |
| ✗ | __aeabi_lcmp       | i64  | i64  | i32  | .. ARM                         |
| ✓ | __cmpti2           | i128 | i128 | i32  | ..                             |
| ✓ | __ucmpsi2          | u32  | u32  | i32  | `(a<b) -> 0, (a==b) -> 1, (a>b) -> 2` |
| ✓ | __ucmpdi2          | u64  | u64  | i32  | ..                             |
| ✗ | __aeabi_ulcmp      | u64  | u64  | i32  | .. ARM                         |
| ✓ | __ucmpti2          | u128 | u128 | i32  | ..                             |
|   |                    |      |      |      | **Integer Arithmetic**         |
| ✓ | __ashlsi3          | i32  | i32  | i32  | `a << b` [^unused_rl78]        |
| ✓ | __ashldi3          | i64  | i32  | i64  | ..                             |
| ✓ | __ashlti3          | i128 | i32  | i128 | ..                             |
| ✓ | __aeabi_llsl       | i32  | i32  | i32  | .. ARM                         |
| ✓ | __ashrsi3          | i32  | i32  | i32  | `a >> b` arithmetic (sign fill) [^unused_rl78] |
| ✓ | __ashrdi3          | i64  | i32  | i64  | ..                             |
| ✓ | __ashrti3          | i128 | i32  | i128 | ..                             |
| ✓ | __aeabi_lasr       | i64  | i32  | i64  | .. ARM                         |
| ✓ | __lshrsi3          | i32  | i32  | i32  | `a >> b` logical (zero fill) [^unused_rl78] |
| ✓ | __lshrdi3          | i64  | i32  | i64  | ..                             |
| ✓ | __lshrti3          | i128 | i32  | i128 | ..                             |
| ✓ | __aeabi_llsr       | i64  | i32  | i64  | .. ARM                         |
| ✓ | __negsi2           | i32  | i32  | i32  | `-a` [^libgcc_compat]          |
| ✓ | __negdi2           | i64  | i64  | i64  | ..                             |
| ✓ | __negti2           | i128 | i128 | i128 | ..                             |
| ✓ | __mulsi3           | i32  | i32  | i32  | `a * b`                        |
| ✓ | __muldi3           | i64  | i64  | i64  | ..                             |
| ✓ | __aeabi_lmul       | i64  | i64  | i64  | .. ARM                         |
| ✓ | __multi3           | i128 | i128 | i128 | ..                             |
| ✓ | __divsi3           | i32  | i32  | i32  | `a / b`                        |
| ✓ | __divdi3           | i64  | i64  | i64  | ..                             |
| ✓ | __divti3           | i128 | i128 | i128 | ..                             |
| ✓ | __aeabi_idiv       | i32  | i32  | i32  | .. ARM                         |
| ✓ | __udivsi3          | u32  | u32  | u32  | `a / b`                        |
| ✓ | __udivdi3          | u64  | u64  | u64  | ..                             |
| ✓ | __udivti3          | u128 | u128 | u128 | ..                             |
| ✓ | __aeabi_uidiv      | i32  | i32  | i32  | .. ARM                         |
| ✓ | __modsi3           | i32  | i32  | i32  | `a % b`                        |
| ✓ | __moddi3           | i64  | i64  | i64  | ..                             |
| ✓ | __modti3           | i128 | i128 | i128 | ..                             |
| ✓ | __umodsi3          | u32  | u32  | u32  | `a % b`                        |
| ✓ | __umoddi3          | u64  | u64  | u64  | ..                             |
| ✓ | __umodti3          | u128 | u128 | u128 | ..                             |
| ✓ | __udivmodsi4       | u32  | u32  | u32  | `a / b, rem.* = a % b`         |
| ✓ | __aeabi_uidivmod   | u32  | u32  | u32  | .. ARM                         |
| ✓ | __udivmoddi4       | u64  | u64  | u64  | ..                             |
| ✓ | __aeabi_uldivmod   | u64  | u64  | u64  | .. ARM                         |
| ✓ | __udivmodti4       | u128 | u128 | u128 | ..                             |
| ✓ | __divmodsi4        | i32  | i32  | i32  | `a / b, rem.* = a % b`         |
| ✓ | __aeabi_idivmod    | i32  | i32  | i32  | .. ARM                         |
| ✓ | __divmoddi4        | i64  | i64  | i64  | ..                             |
| ✓ | __aeabi_ldivmod    | i64  | i64  | i64  | .. ARM                         |
| ✓ | __divmodti4        | i128 | i128 | i128 | .. [^libgcc_compat]            |
|   |                    |      |      |      | **Integer Arithmetic with Trapping Overflow**|
| ✓ | __absvsi2          | i32  | i32  | i32  | abs(a)                         |
| ✓ | __absvdi2          | i64  | i64  | i64  | ..                             |
| ✓ | __absvti2          | i128 | i128 | i128 | ..                             |
| ✓ | __negvsi2          | i32  | i32  | i32  | `-a` [^libgcc_compat]          |
| ✓ | __negvdi2          | i64  | i64  | i64  | ..                             |
| ✓ | __negvti2          | i128 | i128 | i128 | ..                             |
| ✗ | __addvsi3          | i32  | i32  | i32  | `a + b`                        |
| ✗ | __addvdi3          | i64  | i64  | i64  | ..                             |
| ✗ | __addvti3          | i128 | i128 | i128 | ..                             |
| ✗ | __subvsi3          | i32  | i32  | i32  | `a - b`                        |
| ✗ | __subvdi3          | i64  | i64  | i64  | ..                             |
| ✗ | __subvti3          | i128 | i128 | i128 | ..                             |
| ✗ | __mulvsi3          | i32  | i32  | i32  | `a * b`                        |
| ✗ | __mulvdi3          | i64  | i64  | i64  | ..                             |
| ✗ | __mulvti3          | i128 | i128 | i128 | ..                             |
|   |                    |      |      |      | **Integer Arithmetic which Return on Overflow** [^noptr_faster] |
| ✓ | __addosi4          | i32  | i32  | i32  | `a + b`, overflow->ov.*=1 else 0 [^perf_addition] |
| ✓ | __addodi4          | i64  | i64  | i64  | ..                             |
| ✓ | __addoti4          | i128 | i128 | i128 | ..                             |
| ✓ | __subosi4          | i32  | i32  | i32  | `a - b`, overflow->ov.*=1 else 0 [^perf_addition] |
| ✓ | __subodi4          | i64  | i64  | i64  | ..                             |
| ✓ | __suboti4          | i128 | i128 | i128 | ..                             |
| ✓ | __mulosi4          | i32  | i32  | i32  | `a * b`, overflow->ov.*=1 else 0 |
| ✓ | __mulodi4          | i64  | i64  | i64  | ..                             |
| ✓ | __muloti4          | i128 | i128 | i128 | ..                             |
|   |                    |      |      |      | **Float Conversion**           |
| ✓ | __extendhfdf2      | f16  | ∅    | f32  | ..                             |
| ✓ | __extendsfdf2      | f32  | ∅    | f64  | ..                             |
| ✓ | __aeabi_f2d        | f32  | ∅    | f64  | ..                             |
| ✓ | __extendsftf2      | f32  | ∅    | f128 | ..                             |
| ✓ | __extendsfxf2      | f32  | ∅    | f80  | ..                             |
| ✓ | __extenddftf2      | f64  | ∅    | f128 | ..                             |
| ✓ | __extenddfxf2      | f64  | ∅    | f80  | ..                             |
| ✗ | __aeabi_h2f        | f16  | ∅    | f32  | .. ARM                         |
| ✗ | __aeabi_h2f_alt    | f16  | ∅    | f32  | .. ARM alternate [^VFPv3alt]   |
| ✓ | __gnu_h2f_ieee     | f16  | ∅    | f32  | .. GNU naming convention       |
| ✓ | __truncsfhf2       | f32  | ∅    | f16  | rounding towards zero          |
| ✓ | __truncdfhf2       | f64  | ∅    | f16  | ..                             |
| ✓ | __truncdfsf2       | f64  | ∅    | f32  | ..                             |
| ✓ | __trunctfhf2       | f128 | ∅    | f16  | ..                             |
| ✓ | __trunctfsf2       | f128 | ∅    | f32  | ..                             |
| ✓ | __trunctfdf2       | f128 | ∅    | f64  | ..                             |
| ✓ | __trunctfxf2       | f128 | ∅    | f80  | ..                             |
| ✓ | __truncxfhf2       | f80  | ∅    | f16  | ..                             |
| ✓ | __truncxfsf2       | f80  | ∅    | f32  | ..                             |
| ✓ | __truncxfdf2       | f80  | ∅    | f64  | ..                             |
| ✗ | __aeabi_f2h        | f32  | ∅    | f16  | .. ARM                         |
| ✗ | __aeabi_f2h_alt    | f32  | ∅    | f16  | .. ARM alternate [^VFPv3alt]   |
| ✓ | __gnu_f2h_ieee     | f32  | ∅    | f16  | .. GNU naming convention       |
| ✓ | __aeabi_d2h        | f64  | ∅    | f16  | .. ARM                         |
| ✗ | __aeabi_d2h_alt    | f64  | ∅    | f16  | .. ARM alternate [^VFPv3alt]   |
| ✓ | __aeabi_d2f        | f64  | ∅    | f32  | .. ARM                         |
| ✓ | __trunckfsf2       | f128 | ∅    | f32  | .. PPC                         |
| ✓ | _Qp_qtos           |*f128 | ∅    | f32  | .. SPARC                       |
| ✓ | __trunckfdf2       | f128 | ∅    | f64  | .. PPC                         |
| ✓ | _Qp_qtod           |*f128 | ∅    | f64  | .. SPARC                       |
| ✓ | __fixhfsi          | f16  | ∅    | i32  | float to int, rounding towards zero |
| ✓ | __fixsfsi          | f32  | ∅    | i32  | ..                             |
| ✓ | __aeabi_f2iz       | f32  | ∅    | i32  | .. ARM                         |
| ✓ | __fixdfsi          | f64  | ∅    | i32  | ..                             |
| ✓ | __aeabi_d2iz       | f64  | ∅    | i32  | .. ARM                         |
| ✓ | __fixtfsi          | f128 | ∅    | i32  | ..                             |
| ✓ | __fixxfsi          | f80  | ∅    | i32  | ..                             |
| ✓ | __fixhfdi          | f16  | ∅    | i64  | ..                             |
| ✓ | __fixsfdi          | f32  | ∅    | i64  | ..                             |
| ✓ | __aeabi_f2lz       | f32  | ∅    | i64  | .. ARM                         |
| ✓ | __fixdfdi          | f64  | ∅    | i64  | ..                             |
| ✓ | __aeabi_d2lz       | f64  | ∅    | i64  | .. ARM                         |
| ✓ | __fixtfdi          | f128 | ∅    | i64  | ..                             |
| ✓ | __fixxfdi          | f80  | ∅    | i64  | ..                             |
| ✓ | __fixhfti          | f16  | ∅    | i128 | ..                             |
| ✓ | __fixsfti          | f32  | ∅    | i128 | ..                             |
| ✓ | __fixdfti          | f64  | ∅    | i128 | ..                             |
| ✓ | __fixtfti          | f128 | ∅    | i128 | ..                             |
| ✓ | __fixxfti          | f80  | ∅    | i128 | ..                             |
| ✓ | __fixunshfsi       | f16  | ∅    | u32  | float to uint, rounding towards zero. negative values become 0. |
| ✓ | __fixunssfsi       | f32  | ∅    | u32  | ..                             |
| ✓ | __aeabi_f2uiz      | f32  | ∅    | u32  | .. ARM                         |
| ✓ | __fixunsdfsi       | f64  | ∅    | u32  | ..                             |
| ✓ | __aeabi_d2uiz      | f64  | ∅    | u32  | .. ARM                         |
| ✓ | __fixunstfsi       | f128 | ∅    | u32  | ..                             |
| ✓ | __fixunsxfsi       | f80  | ∅    | u32  | ..                             |
| ✓ | __fixunshfdi       | f16  | ∅    | u64  | ..                             |
| ✓ | __fixunssfdi       | f32  | ∅    | u64  | ..                             |
| ✓ | __aeabi_f2ulz      | f32  | ∅    | u64  | .. ARM                         |
| ✓ | __fixunsdfdi       | f64  | ∅    | u64  | ..                             |
| ✓ | __aeabi_d2ulz      | f64  | ∅    | u64  | .. ARM                         |
| ✓ | __fixunstfdi       | f128 | ∅    | u64  | ..                             |
| ✓ | __fixunsxfdi       | f80  | ∅    | u64  | ..                             |
| ✓ | __fixunshfti       | f16  | ∅    | u128 | ..                             |
| ✓ | __fixunssfti       | f32  | ∅    | u128 | ..                             |
| ✓ | __fixunsdfti       | f64  | ∅    | u128 | ..                             |
| ✓ | __fixunstfti       | f128 | ∅    | u128 | ..                             |
| ✓ | __fixunsxfti       | f80  | ∅    | u128 | ..                             |
| ✓ | __floatsihf        | i32  | ∅    | f16  | int to float                   |
| ✓ | __floatsisf        | i32  | ∅    | f32  | ..                             |
| ✓ | __aeabi_i2f        | i32  | ∅    | f32  | .. ARM                         |
| ✓ | __floatsidf        | i32  | ∅    | f64  | ..                             |
| ✓ | __aeabi_i2d        | i32  | ∅    | f64  | .. ARM                         |
| ✓ | __floatsitf        | i32  | ∅    | f128 | ..                             |
| ✓ | __floatsixf        | i32  | ∅    | f80  | ..                             |
| ✓ | __floatdisf        | i64  | ∅    | f32  | ..                             |
| ✓ | __aeabi_l2f        | i64  | ∅    | f32  | .. ARM                         |
| ✓ | __floatdidf        | i64  | ∅    | f64  | ..                             |
| ✓ | __aeabi_l2d        | i64  | ∅    | f64  | .. ARM                         |
| ✓ | __floatditf        | i64  | ∅    | f128 | ..                             |
| ✓ | __floatdixf        | i64  | ∅    | f80  | ..                             |
| ✓ | __floattihf        | i128 | ∅    | f16  | ..                             |
| ✓ | __floattisf        | i128 | ∅    | f32  | ..                             |
| ✓ | __floattidf        | i128 | ∅    | f64  | ..                             |
| ✓ | __floattitf        | i128 | ∅    | f128 | ..                             |
| ✓ | __floattixf        | i128 | ∅    | f80  | ..                             |
| ✓ | __floatunsihf      | u32  | ∅    | f16  | uint to float                  |
| ✓ | __floatunsisf      | u32  | ∅    | f32  | ..                             |
| ✓ | __aeabi_ui2f       | u32  | ∅    | f32  | .. ARM                         |
| ✓ | __floatunsidf      | u32  | ∅    | f64  | ..                             |
| ✓ | __aeabi_ui2d       | u32  | ∅    | f64  | .. ARM                         |
| ✓ | __floatunsitf      | u32  | ∅    | f128 | ..                             |
| ✓ | __floatunsixf      | u32  | ∅    | f80  | ..                             |
| ✓ | __floatundihf      | u64  | ∅    | f16  | ..                             |
| ✓ | __floatundisf      | u64  | ∅    | f32  | ..                             |
| ✓ | __aeabi_ul2f       | u64  | ∅    | f32  | .. ARM                         |
| ✓ | __floatundidf      | u64  | ∅    | f64  | ..                             |
| ✓ | __aeabi_ul2d       | u64  | ∅    | f64  | .. ARM                         |
| ✓ | __floatunditf      | u64  | ∅    | f128 | ..                             |
| ✓ | __floatundixf      | u64  | ∅    | f80  | ..                             |
| ✓ | __floatuntihf      | u128 | ∅    | f16  | ..                             |
| ✓ | __floatuntisf      | u128 | ∅    | f32  | ..                             |
| ✓ | __floatuntidf      | u128 | ∅    | f64  | ..                             |
| ✓ | __floatuntitf      | u128 | ∅    | f128 | ..                             |
| ✓ | __floatuntixf      | u128 | ∅    | f80  | ..                             |
|   |                    |      |      |      | **Float Comparison**           |
| ✓ | __cmphf2           | f16  | f16  | i32  | `(a<b)->-1, (a==b)->0, (a>b)->1, Nan->1` |
| ✓ | __cmpsf2           | f32  | f32  | i32  | exported from __lesf2, __ledf2, __letf2 (below) |
| ✓ | __cmpdf2           | f64  | f64  | i32  | But: if NaN is a possibility, use another routine. |
| ✓ | __cmptf2           | f128 | f128 | i32  | ..                             |
| ✓ | __cmpxf2           | f80  | f80  | i32  | ..                             |
| ✓ | _Qp_cmp            |*f128 |*f128 | i32  | .. SPARC                       |
| ✓ | __unordhf2         | f16  | f16  | i32  | `(a==+-NaN or b==+-NaN) -> !=0, else -> 0` |
| ✓ | __unordsf2         | f32  | f32  | i32  | ..                             |
| ✓ | __unorddf2         | f64  | f64  | i32  | Note: only reliable for (input!=NaN) |
| ✓ | __unordtf2         | f128 | f128 | i32  | ..                             |
| ✓ | __unordxf2         | f80  | f80  | i32  | ..                             |
| ✓ | __aeabi_fcmpun     | f32  | f32  | i32  | .. ARM                         |
| ✓ | __aeabi_dcmpun     | f32  | f32  | i32  | .. ARM                         |
| ✓ | __unordkf2         | f128 | f128 | i32  | .. PPC                         |
| ✓ | __eqhf2            | f16  | f16  | i32  | `(a!=NaN) and (b!=Nan) and (a==b) -> output=0` |
| ✓ | __eqsf2            | f32  | f32  | i32  | ..                                             |
| ✓ | __eqdf2            | f64  | f64  | i32  | ..                             |
| ✓ | __eqtf2            | f128 | f128 | i32  | ..                             |
| ✓ | __eqxf2            | f80  | f80  | i32  | ..                             |
| ✓ | __aeabi_fcmpeq     | f32  | f32  | i32  | .. ARM                         |
| ✓ | __aeabi_dcmpeq     | f32  | f32  | i32  | .. ARM                         |
| ✓ | __eqkf2            | f128 | f128 | i32  | .. PPC                         |
| ✓ | _Qp_feq            |*f128 |*f128 | bool | .. SPARC                       |
| ✓ | __nehf2            | f16  | f16  | i32  | `(a==NaN) or (b==Nan) or (a!=b) -> output!=0` |
| ✓ | __nesf2            | f32  | f32  | i32  | Note: __eqXf2 and __neXf2 have same return value |
| ✓ | __nedf2            | f64  | f64  | i32  | ..                             |
| ✓ | __netf2            | f128 | f128 | i32  | ..                             |
| ✓ | __nexf2            | f80  | f80  | i32  | ..                             |
| ✓ | __nekf2            | f128 | f128 | i32  | .. PPC                         |
| ✓ | _Qp_fne            |*f128 |*f128 | bool | .. SPARC                       |
| ✓ | __gehf2            | f16  | f16  | i32  | `(a!=Nan) and (b!=Nan) and (a>=b) -> output>=0` |
| ✓ | __gesf2            | f32  | f32  | i32  | ..                             |
| ✓ | __gedf2            | f64  | f64  | i32  | ..                             |
| ✓ | __getf2            | f128 | f128 | i32  | ..                             |
| ✓ | __gexf2            | f80  | f80  | i32  | ..                             |
| ✓ | __aeabi_fcmpge     | f32  | f32  | i32  | .. ARM                         |
| ✓ | __aeabi_dcmpge     | f64  | f64  | i32  | .. ARM                         |
| ✓ | __gekf2            | f128 | f128 | i32  | .. PPC                         |
| ✓ | _Qp_fge            |*f128 |*f128 | bool | .. SPARC                       |
| ✓ | __lthf2            | f16  | f16  | i32  | `(a!=Nan) and (b!=Nan) and (a<b) -> output<0` |
| ✓ | __ltsf2            | f32  | f32  | i32  | ..                             |
| ✓ | __ltdf2            | f64  | f64  | i32  | ..                             |
| ✓ | __lttf2            | f128 | f128 | i32  | ..                             |
| ✓ | __ltxf2            | f80  | f80  | i32  | ..                             |
| ✓ | __ltkf2            | f128 | f128 | i32  | .. PPC                         |
| ✓ | __aeabi_fcmplt     | f32  | f32  | i32  | .. ARM                         |
| ✓ | __aeabi_dcmplt     | f32  | f32  | i32  | .. ARM                         |
| ✓ | _Qp_flt            |*f128 |*f128 | bool | .. SPARC                       |
| ✓ | __lehf2            | f16  | f16  | i32  | `(a!=Nan) and (b!=Nan) and (a<=b) -> output<=0` |
| ✓ | __lesf2            | f32  | f32  | i32  | ..                             |
| ✓ | __ledf2            | f64  | f64  | i32  | ..                             |
| ✓ | __letf2            | f128 | f128 | i32  | ..                             |
| ✓ | __lexf2            | f80  | f80  | i32  | ..                             |
| ✓ | __aeabi_fcmple     | f32  | f32  | i32  | .. ARM                         |
| ✓ | __aeabi_dcmple     | f32  | f32  | i32  | .. ARM                         |
| ✓ | __lekf2            | f128 | f128 | i32  | .. PPC                         |
| ✓ | _Qp_fle            |*f128 |*f128 | bool | .. SPARC                       |
| ✓ | __gthf2            | f16  | f16  | i32  | `(a!=Nan) and (b!=Nan) and (a>b) -> output>0` |
| ✓ | __gtsf2            | f32  | f32  | i32  | ..                             |
| ✓ | __gtdf2            | f64  | f64  | i32  | ..                             |
| ✓ | __gttf2            | f128 | f128 | i32  | ..                             |
| ✓ | __gtxf2            | f80  | f80  | i32  | ..                             |
| ✓ | __aeabi_fcmpgt     | f32  | f32  | i32  | .. ARM                         |
| ✓ | __aeabi_dcmpgt     | f64  | f64  | i32  | .. ARM                         |
| ✓ | __gtkf2            | f128 | f128 | i32  | .. PPC                         |
| ✓ | _Qp_fgt            |*f128 |*f128 | bool | .. SPARC                       |
|   |                    |      |      |      | **Float Arithmetic**           |
| ✓ | __addhf3           | f32  | f32  | f32  | `a + b`                        |
| ✓ | __addsf3           | f32  | f32  | f32  | ..                             |
| ✓ | __adddf3           | f64  | f64  | f64  | ..                             |
| ✓ | __addtf3           | f128 | f128 | f128 | ..                             |
| ✓ | __addxf3           | f80  | f80  | f80  | ..                             |
| ✓ | __aeabi_fadd       | f32  | f32  | f32  | .. ARM                         |
| ✓ | __aeabi_dadd       | f64  | f64  | f64  | .. ARM                         |
| ✓ | __addkf3           | f128 | f128 | f128 | .. PPC                         |
| ✓ | _Qp_add            |*f128 |*f128 | void | .. SPARC args *c,*a,*b c=a+b   |
| ✓ | __subhf3           | f32  | f32  | f32  | `a - b`                        |
| ✓ | __subsf3           | f32  | f32  | f32  | ..                             |
| ✓ | __subdf3           | f64  | f64  | f64  | ..                             |
| ✓ | __subtf3           | f128 | f128 | f128 | ..                             |
| ✓ | __subxf3           | f80  | f80  | f80  | ..                             |
| ✓ | __aeabi_fsub       | f32  | f32  | f32  | .. ARM                         |
| ✓ | __aeabi_dsub       | f64  | f64  | f64  | .. ARM                         |
| ✓ | __subkf3           | f128 | f128 | f128 | .. PPC                         |
| ✓ | _Qp_sub            |*f128 |*f128 | void | .. SPARC args *c,*a,*b c=a-b   |
| ✓ | __mulhf3           | f32  | f32  | f32  | `a * b`                        |
| ✓ | __mulsf3           | f32  | f32  | f32  | ..                             |
| ✓ | __muldf3           | f64  | f64  | f64  | ..                             |
| ✓ | __multf3           | f128 | f128 | f128 | ..                             |
| ✓ | __mulxf3           | f80  | f80  | f80  | ..                             |
| ✓ | __aeabi_fmul       | f32  | f32  | f32  | .. ARM                         |
| ✓ | __aeabi_dmul       | f64  | f64  | f64  | .. ARM                         |
| ✓ | __mulkf3           | f128 | f128 | f128 | .. PPC                         |
| ✓ | _Qp_mul            |*f128 |*f128 | void | .. SPARC args *c,*a,*b c=a*b   |
| ✓ | __divsf3           | f32  | f32  | f32  | `a / b`                        |
| ✓ | __divdf3           | f64  | f64  | f64  | ..                             |
| ✓ | __divtf3           | f128 | f128 | f128 | ..                             |
| ✓ | __divxf3           | f80  | f80  | f80  | ..                             |
| ✓ | __aeabi_fdiv       | f32  | f32  | f32  | .. ARM                         |
| ✓ | __aeabi_ddiv       | f64  | f64  | f64  | .. ARM                         |
| ✓ | __divkf3           | f128 | f128 | f128 | .. PPC                         |
| ✓ | _Qp_div            |*f128 |*f128 | void | .. SPARC args *c,*a,*b c=a*b   |
| ✓ | __negsf2           | f32  | ∅    | f32[^unused_rl78] | -a (can be lowered directly to a xor) |
| ✓ | __negdf2           | f64  | ∅    | f64  | ..                             |
| ✓ | __negtf2           | f128 | ∅    | f128 | ..                             |
| ✓ | __negxf2           | f80  | ∅    | f80  | ..                             |
|   |                    |      |      |      | **Other** |
| ✓ | __powihf2          | f16  | i32  | f16  | `a ^ b`                        |
| ✓ | __powisf2          | f32  | i32  | f32  | ..                             |
| ✓ | __powidf2          | f64  | i32  | f64  | ..                             |
| ✓ | __powitf2          | f128 | i32  | f128 | ..                             |
| ✓ | __powixf2          | f80  | i32  | f80  | ..                             |
| ✓ | __mulhc3           | all4 | f16  | f16  | `(a+ib) * (c+id)`              |
| ✓ | __mulsc3           | all4 | f32  | f32  | ..                             |
| ✓ | __muldc3           | all4 | f64  | f64  | ..                             |
| ✓ | __multc3           | all4 | f128 | f128 | ..                             |
| ✓ | __mulxc3           | all4 | f80  | f80  | ..                             |
| ✓ | __divhc3           | all4 | f16  | f16  | `(a+ib) / (c+id)`              |
| ✓ | __divsc3           | all4 | f32  | f32  | ..                             |
| ✓ | __divdc3           | all4 | f64  | f64  | ..                             |
| ✓ | __divtc3           | all4 | f128 | f128 | ..                             |
| ✓ | __divxc3           | all4 | f80  | f80  | ..                             |

[^unused_rl78]: Unused in LLVM, but used for example by rl78.
[^libgcc_compat]: Unused in backends and for symbol-level compatibility with libgcc.
[^noptr_faster]: Operations without pointer and without C struct semantics lead to better optimizations.
[^perf_addition]: Has better performance than standard method due to 2s complement semantics.
Not provided by LLVM and libgcc.
[^VFPv3alt]: Converts IEEE-format to VFPv3 alternative-format.

Decimal float library routines

BID means Binary Integer Decimal encoding, DPD means Densely Packed Decimal encoding.
BID should be only chosen for binary data, DPD for decimal data (ASCII, Unicode etc).
For example the number 0.2 is not accurately representable in binary data.

| Done   | Name          | a            | b      | Out          | Comment                                                 |
| ------ | ------------- | ------------ | ------ | ------------ | ------------------------------------------------------- |
|   |                    |              |        |              | **Decimal Float Conversion**                            |
| ✗ | __dpd_extendsddd2  |      dec32   |    ∅   |      dec64   | conversion                                              |
| ✗ | __bid_extendsddd2  |      dec32   |    ∅   |      dec64   | ..                                                      |
| ✗ | __dpd_extendsdtd2  |      dec32   |    ∅   |      dec128  | ..                                                      |
| ✗ | __bid_extendsdtd2  |      dec32   |    ∅   |      dec128  | ..                                                      |
| ✗ | __dpd_extendddtd2  |      dec64   |    ∅   |      dec128  | ..                                                      |
| ✗ | __bid_extendddtd2  |      dec64   |    ∅   |      dec128  | ..                                                      |
| ✗ | __dpd_truncddsd2   |      dec64   |    ∅   |      dec32   | ..                                                      |
| ✗ | __bid_truncddsd2   |      dec64   |    ∅   |      dec32   | ..                                                      |
| ✗ | __dpd_trunctdsd2   |      dec128  |    ∅   |      dec32   | ..                                                      |
| ✗ | __bid_trunctdsd2   |      dec128  |    ∅   |      dec32   | ..                                                      |
| ✗ | __dpd_trunctddd2   |      dec128  |    ∅   |      dec64   | ..                                                      |
| ✗ | __bid_trunctddd2   |      dec128  |    ∅   |      dec64   | ..                                                      |
| ✗ | __dpd_extendsfdd   |      f32     |    ∅   |      dec64   | ..                                                      |
| ✗ | __bid_extendsfdd   |      f32     |    ∅   |      dec64   | ..                                                      |
| ✗ | __dpd_extendsftd   |      f32     |    ∅   |      dec128  | ..                                                      |
| ✗ | __bid_extendsftd   |      f32     |    ∅   |      dec128  | ..                                                      |
| ✗ | __dpd_extenddftd   |      f64     |    ∅   |      dec128  | ..                                                      |
| ✗ | __bid_extenddftd   |      f64     |    ∅   |      dec128  | ..                                                      |
| ✗ | __dpd_extendxftd   | c_longdouble |    ∅   |      dec128  | ..                                                      |
| ✗ | __bid_extendxftd   | c_longdouble |    ∅   |      dec128  | ..                                                      |
| ✗ | __dpd_truncdfsd    |      f64     |    ∅   |      dec32   | ..                                                      |
| ✗ | __bid_truncdfsd    |      f64     |    ∅   |      dec32   | ..                                                      |
| ✗ | __dpd_truncxfsd    | c_longdouble |    ∅   |      dec32   | ..                                                      |
| ✗ | __bid_truncxfsd    | c_longdouble |    ∅   |      dec32   | ..                                                      |
| ✗ | __dpd_trunctfsd    | c_longdouble |    ∅   |      dec32   | ..                                                      |
| ✗ | __bid_trunctfsd    | c_longdouble |    ∅   |      dec32   | ..                                                      |
| ✗ | __dpd_truncxfdd    | c_longdouble |    ∅   |      dec64   | ..                                                      |
| ✗ | __bid_truncxfdd    | c_longdouble |    ∅   |      dec64   | ..                                                      |
| ✗ | __dpd_trunctfdd    | c_longdouble |    ∅   |      dec64   | ..                                                      |
| ✗ | __bid_trunctfdd    | c_longdouble |    ∅   |      dec64   | ..                                                      |
| ✗ | __dpd_truncddsf    |      dec64   |    ∅   |      f32     | ..                                                      |
| ✗ | __bid_truncddsf    |      dec64   |    ∅   |      f32     | ..                                                      |
| ✗ | __dpd_trunctdsf    |      dec128  |    ∅   |      f32     | ..                                                      |
| ✗ | __bid_trunctdsf    |      dec128  |    ∅   |      f32     | ..                                                      |
| ✗ | __dpd_extendsddf   |      dec32   |    ∅   |      f64     | ..                                                      |
| ✗ | __bid_extendsddf   |      dec32   |    ∅   |      f64     | ..                                                      |
| ✗ | __dpd_trunctddf    |      dec128  |    ∅   |      f64     | ..                                                      |
| ✗ | __bid_trunctddf    |      dec128  |    ∅   |      f64     | ..                                                      |
| ✗ | __dpd_extendsdxf   |      dec32   |    ∅   | c_longdouble | ..                                                      |
| ✗ | __bid_extendsdxf   |      dec32   |    ∅   | c_longdouble | ..                                                      |
| ✗ | __dpd_extendddxf   |      dec64   |    ∅   | c_longdouble | ..                                                      |
| ✗ | __bid_extendddxf   |      dec64   |    ∅   | c_longdouble | ..                                                      |
| ✗ | __dpd_trunctdxf    |      dec128  |    ∅   | c_longdouble | ..                                                      |
| ✗ | __bid_trunctdxf    |      dec128  |    ∅   | c_longdouble | ..                                                      |
| ✗ | __dpd_extendsdtf   |      dec32   |    ∅   | c_longdouble | ..                                                      |
| ✗ | __bid_extendsdtf   |      dec32   |    ∅   | c_longdouble | ..                                                      |
| ✗ | __dpd_extendddtf   |      dec64   |    ∅   | c_longdouble | ..                                                      |
| ✗ | __bid_extendddtf   |      dec64   |    ∅   | c_longdouble | ..                                                      |
| ✗ | __dpd_extendsfsd   |      f32     |    ∅   |      dec32   | same size conversions                                   |
| ✗ | __bid_extendsfsd   |      f32     |    ∅   |      dec32   | ..                                                      |
| ✗ | __dpd_extenddfdd   |      f64     |    ∅   |      dec64   | ..                                                      |
| ✗ | __bid_extenddfdd   |      f64     |    ∅   |      dec64   | ..                                                      |
| ✗ | __dpd_extendtftd   | c_longdouble |    ∅   |      dec128  | ..                                                      |
| ✗ | __bid_extendtftd   | c_longdouble |    ∅   |      dec128  | ..                                                      |
| ✗ | __dpd_truncsdsf    |      dec32   |    ∅   |      f32     | ..                                                      |
| ✗ | __bid_truncsdsf    |      dec32   |    ∅   |      f32     | ..                                                      |
| ✗ | __dpd_truncdddf    |      dec64   |    ∅   |      f32     | conversion                                              |
| ✗ | __bid_truncdddf    |      dec64   |    ∅   |      f32     | ..                                                      |
| ✗ | __dpd_trunctdtf    |      dec128  |    ∅   | c_longdouble | ..                                                      |
| ✗ | __bid_trunctdtf    |      dec128  |    ∅   | c_longdouble | ..                                                      |
| ✗ | __dpd_fixsdsi      |      dec32   |    ∅   |      c_int   | ..                                                      |
| ✗ | __bid_fixsdsi      |      dec32   |    ∅   |      c_int   | ..                                                      |
| ✗ | __dpd_fixddsi      |      dec64   |    ∅   |      c_int   | ..                                                      |
| ✗ | __bid_fixddsi      |      dec64   |    ∅   |      c_int   | ..                                                      |
| ✗ | __dpd_fixtdsi      |      dec128  |    ∅   |      c_int   | ..                                                      |
| ✗ | __bid_fixtdsi      |      dec128  |    ∅   |      c_int   | ..                                                      |
| ✗ | __dpd_fixsddi      |      dec32   |    ∅   |      c_long  | ..                                                      |
| ✗ | __bid_fixsddi      |      dec32   |    ∅   |      c_long  | ..                                                      |
| ✗ | __dpd_fixdddi      |      dec64   |    ∅   |      c_long  | ..                                                      |
| ✗ | __bid_fixdddi      |      dec64   |    ∅   |      c_long  | ..                                                      |
| ✗ | __dpd_fixtddi      |      dec128  |    ∅   |      c_long  | ..                                                      |
| ✗ | __bid_fixtddi      |      dec128  |    ∅   |      c_long  | ..                                                      |
| ✗ | __dpd_fixunssdsi   |      dec32   |    ∅   |      c_uint  | .. All negative values become zero.                     |
| ✗ | __bid_fixunssdsi   |      dec32   |    ∅   |      c_uint  | ..                                                      |
| ✗ | __dpd_fixunsddsi   |      dec64   |    ∅   |      c_uint  | ..                                                      |
| ✗ | __bid_fixunsddsi   |      dec64   |    ∅   |      c_uint  | ..                                                      |
| ✗ | __dpd_fixunstdsi   |      dec128  |    ∅   |      c_uint  | ..                                                      |
| ✗ | __bid_fixunstdsi   |      dec128  |    ∅   |      c_uint  | ..                                                      |
| ✗ | __dpd_fixunssddi   |      dec32   |    ∅   |      c_ulong | ..                                                      |
| ✗ | __bid_fixunssddi   |      dec32   |    ∅   |      c_ulong | ..                                                      |
| ✗ | __dpd_fixunsdddi   |      dec64   |    ∅   |      c_ulong | ..                                                      |
| ✗ | __bid_fixunsdddi   |      dec64   |    ∅   |      c_ulong | ..                                                      |
| ✗ | __dpd_fixunstddi   |      dec128  |    ∅   |      c_ulong | ..                                                      |
| ✗ | __bid_fixunstddi   |      dec128  |    ∅   |      c_ulong | ..                                                      |
| ✗ | __dpd_floatsisd    |      c_int   |    ∅   |      dec32   | ..                                                      |
| ✗ | __bid_floatsisd    |      c_int   |    ∅   |      dec32   | ..                                                      |
| ✗ | __dpd_floatsidd    |      c_int   |    ∅   |      dec64   | ..                                                      |
| ✗ | __bid_floatsidd    |      c_int   |    ∅   |      dec64   | ..                                                      |
| ✗ | __dpd_floatsitd    |      c_int   |    ∅   |      dec128  | ..                                                      |
| ✗ | __bid_floatsitd    |      c_int   |    ∅   |      dec128  | ..                                                      |
| ✗ | __dpd_floatdisd    |      c_long  |    ∅   |      dec32   | ..                                                      |
| ✗ | __bid_floatdisd    |      c_long  |    ∅   |      dec32   | ..                                                      |
| ✗ | __dpd_floatdidd    |      c_long  |    ∅   |      dec64   | ..                                                      |
| ✗ | __bid_floatdidd    |      c_long  |    ∅   |      dec64   | ..                                                      |
| ✗ | __dpd_floatditd    |      c_long  |    ∅   |      dec128  | ..                                                      |
| ✗ | __bid_floatditd    |      c_long  |    ∅   |      dec128  | ..                                                      |
| ✗ | __dpd_floatunssisd |      c_uint  |    ∅   |      dec32   | ..                                                      |
| ✗ | __bid_floatunssisd |      c_uint  |    ∅   |      dec32   | ..                                                      |
| ✗ | __dpd_floatunssidd |      c_uint  |    ∅   |      dec64   | ..                                                      |
| ✗ | __bid_floatunssidd |      c_uint  |    ∅   |      dec64   | ..                                                      |
| ✗ | __dpd_floatunssitd |      c_uint  |    ∅   |      dec128  | ..                                                      |
| ✗ | __bid_floatunssitd |      c_uint  |    ∅   |      dec128  | ..                                                      |
| ✗ | __dpd_floatunsdisd |      c_ulong |    ∅   |      dec32   | ..                                                      |
| ✗ | __bid_floatunsdisd |      c_ulong |    ∅   |      dec32   | ..                                                      |
| ✗ | __dpd_floatunsdidd |      c_ulong |    ∅   |      dec64   | ..                                                      |
| ✗ | __bid_floatunsdidd |      c_ulong |    ∅   |      dec64   | ..                                                      |
| ✗ | __dpd_floatunsditd |      c_ulong |    ∅   |      dec128  | ..                                                      |
| ✗ | __bid_floatunsditd |      c_ulong |    ∅   |      dec128  | ..                                                      |
|   |                    |              |        |              | **Decimal Float Comparison**                            |
| ✗ | __dpd_unordsd2     |      dec32   | dec32  |      c_int   | `a +-NaN or a +-NaN -> 1(nonzero), else -> 0`           |
| ✗ | __bid_unordsd2     |      dec32   | dec32  |      c_int   | ..                                                      |
| ✗ | __dpd_unorddd2     |      dec64   | dec64  |      c_int   | ..                                                      |
| ✗ | __bid_unorddd2     |      dec64   | dec64  |      c_int   | ..                                                      |
| ✗ | __dpd_unordtd2     |      dec128  | dec128 |      c_int   | ..                                                      |
| ✗ | __bid_unordtd2     |      dec128  | dec128 |      c_int   | ..                                                      |
| ✗ | __dpd_eqsd2        |      dec32   | dec32  |      c_int   |`a!=+-NaN and b!=+-Nan and a==b -> 0, else -> 1(nonzero)`|
| ✗ | __bid_eqsd2        |      dec32   | dec32  |      c_int   | ..                                                      |
| ✗ | __dpd_eqdd2        |      dec64   | dec64  |      c_int   | ..                                                      |
| ✗ | __bid_eqdd2        |      dec64   | dec64  |      c_int   | ..                                                      |
| ✗ | __dpd_eqtd2        |      dec128  | dec128 |      c_int   | ..                                                      |
| ✗ | __bid_eqtd2        |      dec128  | dec128 |      c_int   | ..                                                      |
| ✗ | __dpd_nesd2        |      dec32   | dec32  |      c_int   | `a==+-NaN or b==+-NaN or a!=b -> 1(nonzero), else -> 0` |
| ✗ | __bid_nesd2        |      dec32   | dec32  |      c_int   | ..                                                      |
| ✗ | __dpd_nedd2        |      dec64   | dec64  |      c_int   | ..                                                      |
| ✗ | __bid_nedd2        |      dec64   | dec64  |      c_int   | ..                                                      |
| ✗ | __dpd_netd2        |      dec128  | dec128 |      c_int   | ..                                                      |
| ✗ | __bid_netd2        |      dec128  | dec128 |      c_int   | ..                                                      |
| ✗ | __dpd_gesd2        |      dec32   | dec32  |      c_int   | `a!=+-NaN and b!=+-NaN and a>=b -> >=0, else -> <0`     |
| ✗ | __bid_gesd2        |      dec32   | dec32  |      c_int   | ..                                                      |
| ✗ | __dpd_gedd2        |      dec64   | dec64  |      c_int   | ..                                                      |
| ✗ | __bid_gedd2        |      dec64   | dec64  |      c_int   | ..                                                      |
| ✗ | __dpd_getd2        |      dec128  | dec128 |      c_int   | ..                                                      |
| ✗ | __bid_getd2        |      dec128  | dec128 |      c_int   | ..                                                      |
| ✗ | __dpd_ltsd2        |      dec32   | dec32  |      c_int   | `a!=+-NaN and b!=+-NaN and a<b -> <0, else -> >=0`      |
| ✗ | __bid_ltsd2        |      dec32   | dec32  |      c_int   | ..                                                      |
| ✗ | __dpd_ltdd2        |      dec64   | dec64  |      c_int   | ..                                                      |
| ✗ | __bid_ltdd2        |      dec64   | dec64  |      c_int   | ..                                                      |
| ✗ | __dpd_lttd2        |      dec128  | dec128 |      c_int   | ..                                                      |
| ✗ | __bid_lttd2        |      dec128  | dec128 |      c_int   | ..                                                      |
| ✗ | __dpd_lesd2        |      dec32   | dec32  |      c_int   | `a!=+-NaN and b!=+-NaN and a<=b -> <=0, else -> >=0`    |
| ✗ | __bid_lesd2        |      dec32   | dec32  |      c_int   | ..                                                      |
| ✗ | __dpd_ledd2        |      dec64   | dec64  |      c_int   | ..                                                      |
| ✗ | __bid_ledd2        |      dec64   | dec64  |      c_int   | ..                                                      |
| ✗ | __dpd_letd2        |      dec128  | dec128 |      c_int   | ..                                                      |
| ✗ | __bid_letd2        |      dec128  | dec128 |      c_int   | ..                                                      |
| ✗ | __dpd_gtsd2        |      dec32   | dec32  |      c_int   | `a!=+-NaN and b!=+-NaN and a>b -> >0, else -> <=0`      |
| ✗ | __bid_gtsd2        |      dec32   | dec32  |      c_int   | ..                                                      |
| ✗ | __dpd_gtdd2        |      dec64   | dec64  |      c_int   | ..                                                      |
| ✗ | __bid_gtdd2        |      dec64   | dec64  |      c_int   | ..                                                      |
| ✗ | __dpd_gttd2        |      dec128  | dec128 |      c_int   | ..                                                      |
| ✗ | __bid_gttd2        |      dec128  | dec128 |      c_int   | ..                                                      |
|   |                    |              |        |              | **Decimal Float Arithmetic**[^options]                  |
| ✗ | __dpd_addsd3       |      dec32   | dec32  |      dec32   |`a + b`                                                  |
| ✗ | __bid_addsd3       |      dec32   | dec32  |      dec32   | ..                                                      |
| ✗ | __dpd_adddd3       |      dec64   | dec64  |      dec64   | ..                                                      |
| ✗ | __bid_adddd3       |      dec64   | dec64  |      dec64   | ..                                                      |
| ✗ | __dpd_addtd3       |      dec128  | dec128 |      dec128  | ..                                                      |
| ✗ | __bid_addtd3       |      dec128  | dec128 |      dec128  | ..                                                      |
| ✗ | __dpd_subsd3       |      dec32   | dec32  |      dec32   |`a - b`                                                  |
| ✗ | __bid_subsd3       |      dec32   | dec32  |      dec32   | ..                                                      |
| ✗ | __dpd_subdd3       |      dec64   | dec64  |      dec64   | ..                                                      |
| ✗ | __bid_subdd3       |      dec64   | dec64  |      dec64   | ..                                                      |
| ✗ | __dpd_subtd3       |      dec128  | dec128 |      dec128  | ..                                                      |
| ✗ | __bid_subtd3       |      dec128  | dec128 |      dec128  | ..                                                      |
| ✗ | __dpd_mulsd3       |      dec32   | dec32  |      dec32   |`a * b`                                                  |
| ✗ | __bid_mulsd3       |      dec32   | dec32  |      dec32   | ..                                                      |
| ✗ | __dpd_muldd3       |      dec64   | dec64  |      dec64   | ..                                                      |
| ✗ | __bid_muldd3       |      dec64   | dec64  |      dec64   | ..                                                      |
| ✗ | __dpd_multd3       |      dec128  | dec128 |      dec128  | ..                                                      |
| ✗ | __bid_multd3       |      dec128  | dec128 |      dec128  | ..                                                      |
| ✗ | __dpd_divsd3       |      dec32   | dec32  |      dec32   |`a / b`                                                  |
| ✗ | __bid_divsd3       |      dec32   | dec32  |      dec32   | ..                                                      |
| ✗ | __dpd_divdd3       |      dec64   | dec64  |      dec64   | ..                                                      |
| ✗ | __bid_divdd3       |      dec64   | dec64  |      dec64   | ..                                                      |
| ✗ | __dpd_divtd3       |      dec128  | dec128 |      dec128  | ..                                                      |
| ✗ | __bid_divtd3       |      dec128  | dec128 |      dec128  | ..                                                      |
| ✗ | __dpd_negsd2       |      dec32   | dec32  |      dec32   | `-a`                                                    |
| ✗ | __bid_negsd2       |      dec32   | dec32  |      dec32   | ..                                                      |
| ✗ | __dpd_negdd2       |      dec64   | dec64  |      dec64   | ..                                                      |
| ✗ | __bid_negdd2       |      dec64   | dec64  |      dec64   | ..                                                      |
| ✗ | __dpd_negtd2       |      dec128  | dec128 |      dec128  | ..                                                      |
| ✗ | __bid_negtd2       |      dec128  | dec128 |      dec128  | ..                                                      |

[^options]: These numbers include options with routines for +-0 and +-Nan.

Fixed-point fractional library routines

Fixed-point arithmetic can use less bits in situation, where the scale of the numbers is known.
It also allows simpler error analysis and techniques based on that as it accurately
represents fractionals.
Decimal float library routines are a special case of fixed point fractional arithmetic
and typically a necessity for money-related applications (used in DPD encoding).
Finally, it enables float-like behavior on targets without floating-point unit.
All this comes at cost of more programmer care to avoid overflows in all intermediate
values and extra code to adjust the scaling factors.

See ISO/IEC DTR 18037 section "Fixed-point arithmetic" for context
like the specification of `_Fract, _Accum, _Sat`.
To keep this documentation and implementation dense, we define abbreviations:
Let `fri16`, `fri32`, `fri64`, `fri128` and `fru16`, `fru32`, `fru64`, `fru128`
be signed and unsigned fractionals.
Let `aci16`, `aci32`, `aci64`, `aci128`, `acu16`, `acu32`, `acu64`, `acu128`
be signed and unsigned accumulators.
Let `satfri16`, `satfri32`,`satfri64`,`satfri128` be the corresponding saturated
signed fractionals and likewise `satfruN`, `sataciN`, `satacuN` for
`N in {16,32,64,128}`.

| Done | Name            | a           | b           | Out         | Comment                           |
| ---- | -----------     | ----------- | ----------- | ----------- | --------------------------------- |
|   |                    |             |             |             |**Fixed-Point Conversion**         |
| ✗ | __fractqqhq2       | fri16       |     ∅       | fri32       | Fixed-Point to other              |
| ✗ | __fractqqsq2       | fri16       |     ∅       | fri64       | without saturation                |
| ✗ | __fractqqdq2       | fri16       |     ∅       | fri128      | ..                                |
| ✗ | __fractqqha        | fri16       |     ∅       | aci16       | ..                                |
| ✗ | __fractqqsa        | fri16       |     ∅       | aci32       | ..                                |
| ✗ | __fractqqda        | fri16       |     ∅       | aci64       | ..                                |
| ✗ | __fractqqta        | fri16       |     ∅       | aci128      | ..                                |
| ✗ | __fractqquqq       | fri16       |     ∅       | fru16       | ..                                |
| ✗ | __fractqquhq       | fri16       |     ∅       | fru32       | ..                                |
| ✗ | __fractqqusq       | fri16       |     ∅       | fru64       | ..                                |
| ✗ | __fractqqudq       | fri16       |     ∅       | fru128      | ..                                |
| ✗ | __fractqquha       | fri16       |     ∅       | acu16       | ..                                |
| ✗ | __fractqqusa       | fri16       |     ∅       | acu32       | ..                                |
| ✗ | __fractqquda       | fri16       |     ∅       | acu64       | ..                                |
| ✗ | __fractqquta       | fri16       |     ∅       | acu128      | ..                                |
| ✗ | __fractqqqi        | fri16       |     ∅       | i8          | ..                                |
| ✗ | __fractqqhi        | fri16       |     ∅       | c_short     | ..                                |
| ✗ | __fractqqsi        | fri16       |     ∅       | c_int       | ..                                |
| ✗ | __fractqqdi        | fri16       |     ∅       | c_long      | ..                                |
| ✗ | __fractqqti        | fri16       |     ∅       | c_longlong  | ..                                |
| ✗ | __fractqqsf        | fri16       |     ∅       | f32         | ..                                |
| ✗ | __fractqqdf        | fri16       |     ∅       | f64         | ..                                |
| ✗ | __fracthqqq2       | fri32       |     ∅       | fri16       | ..                                |
| ✗ | __fracthqsq2       | fri32       |     ∅       | fri64       | ..                                |
| ✗ | __fracthqdq2       | fri32       |     ∅       | fri128      | ..                                |
| ✗ | __fracthqha        | fri32       |     ∅       | aci16       | ..                                |
| ✗ | __fracthqsa        | fri32       |     ∅       | aci32       | ..                                |
| ✗ | __fracthqda        | fri32       |     ∅       | aci64       | ..                                |
| ✗ | __fracthqta        | fri32       |     ∅       | aci128      | ..                                |
| ✗ | __fracthquqq       | fri32       |     ∅       | fru16       | ..                                |
| ✗ | __fracthquhq       | fri32       |     ∅       | fru32       | ..                                |
| ✗ | __fracthqusq       | fri32       |     ∅       | fru64       | ..                                |
| ✗ | __fracthqudq       | fri32       |     ∅       | fru128      | ..                                |
| ✗ | __fracthquha       | fri32       |     ∅       | acu16       | ..                                |
| ✗ | __fracthqusa       | fri32       |     ∅       | acu32       | ..                                |
| ✗ | __fracthquda       | fri32       |     ∅       | acu64       | ..                                |
| ✗ | __fracthquta       | fri32       |     ∅       | acu128      | ..                                |
| ✗ | __fracthqqi        | fri32       |     ∅       | i8          | ..                                |
| ✗ | __fracthqhi        | fri32       |     ∅       | c_short     | ..                                |
| ✗ | __fracthqsi        | fri32       |     ∅       | c_int       | ..                                |
| ✗ | __fracthqdi        | fri32       |     ∅       | c_long      | ..                                |
| ✗ | __fracthqti        | fri32       |     ∅       | c_longlong  | ..                                |
| ✗ | __fracthqsf        | fri32       |     ∅       | f32         | ..                                |
| ✗ | __fracthqdf        | fri32       |     ∅       | f64         | ..                                |
| ✗ | __fractsqqq2       | fri64       |     ∅       | fri16       | ..                                |
| ✗ | __fractsqhq2       | fri64       |     ∅       | fri32       | ..                                |
| ✗ | __fractsqdq2       | fri64       |     ∅       | fri128      | ..                                |
| ✗ | __fractsqha        | fri64       |     ∅       | aci16       | ..                                |
| ✗ | __fractsqsa        | fri64       |     ∅       | aci32       | ..                                |
| ✗ | __fractsqda        | fri64       |     ∅       | aci64       | ..                                |
| ✗ | __fractsqta        | fri64       |     ∅       | aci128      | ..                                |
| ✗ | __fractsquqq       | fri64       |     ∅       | fru16       | ..                                |
| ✗ | __fractsquhq       | fri64       |     ∅       | fru32       | ..                                |
| ✗ | __fractsqusq       | fri64       |     ∅       | fru64       | ..                                |
| ✗ | __fractsqudq       | fri64       |     ∅       | fru128      | ..                                |
| ✗ | __fractsquha       | fri64       |     ∅       | acu16       | ..                                |
| ✗ | __fractsqusa       | fri64       |     ∅       | acu32       | ..                                |
| ✗ | __fractsquda       | fri64       |     ∅       | acu64       | ..                                |
| ✗ | __fractsquta       | fri64       |     ∅       | acu128      | ..                                |
| ✗ | __fractsqqi        | fri64       |     ∅       | i8          | ..                                |
| ✗ | __fractsqhi        | fri64       |     ∅       | c_short     | ..                                |
| ✗ | __fractsqsi        | fri64       |     ∅       | c_int       | ..                                |
| ✗ | __fractsqdi        | fri64       |     ∅       | c_long      | ..                                |
| ✗ | __fractsqti        | fri64       |     ∅       | c_longlong  | ..                                |
| ✗ | __fractsqsf        | fri64       |     ∅       | f32         | ..                                |
| ✗ | __fractsqdf        | fri64       |     ∅       | f64         | ..                                |
| ✗ | __fractdqqq2       | fri128      |     ∅       | fri16       | ..                                |
| ✗ | __fractdqhq2       | fri128      |     ∅       | fri32       | ..                                |
| ✗ | __fractdqsq2       | fri128      |     ∅       | fri64       | ..                                |
| ✗ | __fractdqha        | fri128      |     ∅       | aci16       | ..                                |
| ✗ | __fractdqsa        | fri128      |     ∅       | aci32       | ..                                |
| ✗ | __fractdqda        | fri128      |     ∅       | aci64       | ..                                |
| ✗ | __fractdqta        | fri128      |     ∅       | aci128      | ..                                |
| ✗ | __fractdquqq       | fri128      |     ∅       | fru16       | ..                                |
| ✗ | __fractdquhq       | fri128      |     ∅       | fru32       | ..                                |
| ✗ | __fractdqusq       | fri128      |     ∅       | fru64       | ..                                |
| ✗ | __fractdqudq       | fri128      |     ∅       | fru128      | ..                                |
| ✗ | __fractdquha       | fri128      |     ∅       | acu16       | ..                                |
| ✗ | __fractdqusa       | fri128      |     ∅       | acu32       | ..                                |
| ✗ | __fractdquda       | fri128      |     ∅       | acu64       | ..                                |
| ✗ | __fractdquta       | fri128      |     ∅       | acu128      | ..                                |
| ✗ | __fractdqqi        | fri128      |     ∅       | i8          | ..                                |
| ✗ | __fractdqhi        | fri128      |     ∅       | c_short     | ..                                |
| ✗ | __fractdqsi        | fri128      |     ∅       | c_int       | ..                                |
| ✗ | __fractdqdi        | fri128      |     ∅       | c_long      | ..                                |
| ✗ | __fractdqti        | fri128      |     ∅       | c_longlong  | ..                                |
| ✗ | __fractdqsf        | fri128      |     ∅       | f32         | ..                                |
| ✗ | __fractdqdf        | fri128      |     ∅       | f64         | ..                                |
| ✗ | __fracthaqq        | aci16       |     ∅       | fri16       | ..                                |
| ✗ | __fracthahq        | aci16       |     ∅       | fri32       | ..                                |
| ✗ | __fracthasq        | aci16       |     ∅       | fri64       | ..                                |
| ✗ | __fracthadq        | aci16       |     ∅       | fri128      | ..                                |
| ✗ | __fracthasa2       | aci16       |     ∅       | aci32       | ..                                |
| ✗ | __fracthada2       | aci16       |     ∅       | aci64       | ..                                |
| ✗ | __fracthata2       | aci16       |     ∅       | aci128      | ..                                |
| ✗ | __fracthauqq       | aci16       |     ∅       | fru16       | ..                                |
| ✗ | __fracthauhq       | aci16       |     ∅       | fru32       | ..                                |
| ✗ | __fracthausq       | aci16       |     ∅       | fru64       | ..                                |
| ✗ | __fracthaudq       | aci16       |     ∅       | fru128      | ..                                |
| ✗ | __fracthauha       | aci16       |     ∅       | acu16       | ..                                |
| ✗ | __fracthausa       | aci16       |     ∅       | acu32       | ..                                |
| ✗ | __fracthauda       | aci16       |     ∅       | acu64       | ..                                |
| ✗ | __fracthauta       | aci16       |     ∅       | acu128      | ..                                |
| ✗ | __fracthaqi        | aci16       |     ∅       | i8          | ..                                |
| ✗ | __fracthahi        | aci16       |     ∅       | c_short     | ..                                |
| ✗ | __fracthasi        | aci16       |     ∅       | c_int       | ..                                |
| ✗ | __fracthadi        | aci16       |     ∅       | c_long      | ..                                |
| ✗ | __fracthati        | aci16       |     ∅       | c_longlong  | ..                                |
| ✗ | __fracthasf        | aci16       |     ∅       | f32         | ..                                |
| ✗ | __fracthadf        | aci16       |     ∅       | f64         | ..                                |
| ✗ | __fractsaqq        | aci32       |     ∅       | fri16       | ..                                |
| ✗ | __fractsahq        | aci32       |     ∅       | fri32       | ..                                |
| ✗ | __fractsasq        | aci32       |     ∅       | fri64       | ..                                |
| ✗ | __fractsadq        | aci32       |     ∅       | fri128      | ..                                |
| ✗ | __fractsaha2       | aci32       |     ∅       | aci16       | ..                                |
| ✗ | __fractsada2       | aci32       |     ∅       | aci64       | ..                                |
| ✗ | __fractsata2       | aci32       |     ∅       | aci128      | ..                                |
| ✗ | __fractsauqq       | aci32       |     ∅       | fru16       | ..                                |
| ✗ | __fractsauhq       | aci32       |     ∅       | fru32       | ..                                |
| ✗ | __fractsausq       | aci32       |     ∅       | fru64       | ..                                |
| ✗ | __fractsaudq       | aci32       |     ∅       | fru128      | ..                                |
| ✗ | __fractsauha       | aci32       |     ∅       | acu16       | ..                                |
| ✗ | __fractsausa       | aci32       |     ∅       | acu32       | ..                                |
| ✗ | __fractsauda       | aci32       |     ∅       | acu64       | ..                                |
| ✗ | __fractsauta       | aci32       |     ∅       | acu128      | ..                                |
| ✗ | __fractsaqi        | aci32       |     ∅       | i8          | ..                                |
| ✗ | __fractsahi        | aci32       |     ∅       | c_short     | ..                                |
| ✗ | __fractsasi        | aci32       |     ∅       | c_int       | ..                                |
| ✗ | __fractsadi        | aci32       |     ∅       | c_long      | ..                                |
| ✗ | __fractsati        | aci32       |     ∅       | c_longlong  | ..                                |
| ✗ | __fractsasf        | aci32       |     ∅       | f32         | ..                                |
| ✗ | __fractsadf        | aci32       |     ∅       | f64         | ..                                |
| ✗ | __fractdaqq        | aci64       |     ∅       | fri16       | ..                                |
| ✗ | __fractdahq        | aci64       |     ∅       | fri32       | ..                                |
| ✗ | __fractdasq        | aci64       |     ∅       | fri64       | ..                                |
| ✗ | __fractdadq        | aci64       |     ∅       | fri128      | ..                                |
| ✗ | __fractdaha2       | aci64       |     ∅       | aci16       | ..                                |
| ✗ | __fractdasa2       | aci64       |     ∅       | aci32       | ..                                |
| ✗ | __fractdata2       | aci64       |     ∅       | aci128      | ..                                |
| ✗ | __fractdauqq       | aci64       |     ∅       | fru16       | ..                                |
| ✗ | __fractdauhq       | aci64       |     ∅       | fru32       | ..                                |
| ✗ | __fractdausq       | aci64       |     ∅       | fru64       | ..                                |
| ✗ | __fractdaudq       | aci64       |     ∅       | fru128      | ..                                |
| ✗ | __fractdauha       | aci64       |     ∅       | acu16       | ..                                |
| ✗ | __fractdausa       | aci64       |     ∅       | acu32       | ..                                |
| ✗ | __fractdauda       | aci64       |     ∅       | acu64       | ..                                |
| ✗ | __fractdauta       | aci64       |     ∅       | acu128      | ..                                |
| ✗ | __fractdaqi        | aci64       |     ∅       | i8          | ..                                |
| ✗ | __fractdahi        | aci64       |     ∅       | c_short     | ..                                |
| ✗ | __fractdasi        | aci64       |     ∅       | c_int       | ..                                |
| ✗ | __fractdadi        | aci64       |     ∅       | c_long      | ..                                |
| ✗ | __fractdati        | aci64       |     ∅       | c_longlong  | ..                                |
| ✗ | __fractdasf        | aci64       |     ∅       | f32         | ..                                |
| ✗ | __fractdadf        | aci64       |     ∅       | f64         | ..                                |
| ✗ | __fracttaqq        | aci128      |     ∅       | fri16       | ..                                |
| ✗ | __fracttahq        | aci128      |     ∅       | fri32       | ..                                |
| ✗ | __fracttasq        | aci128      |     ∅       | fri64       | ..                                |
| ✗ | __fracttadq        | aci128      |     ∅       | fri128      | ..                                |
| ✗ | __fracttaha2       | aci128      |     ∅       | aci16       | ..                                |
| ✗ | __fracttasa2       | aci128      |     ∅       | aci32       | ..                                |
| ✗ | __fracttada2       | aci128      |     ∅       | aci64       | ..                                |
| ✗ | __fracttauqq       | aci128      |     ∅       | fru16       | ..                                |
| ✗ | __fracttauhq       | aci128      |     ∅       | fru32       | ..                                |
| ✗ | __fracttausq       | aci128      |     ∅       | fru64       | ..                                |
| ✗ | __fracttaudq       | aci128      |     ∅       | fru128      | ..                                |
| ✗ | __fracttauha       | aci128      |     ∅       | acu16       | ..                                |
| ✗ | __fracttausa       | aci128      |     ∅       | acu32       | ..                                |
| ✗ | __fracttauda       | aci128      |     ∅       | acu64       | ..                                |
| ✗ | __fracttauta       | aci128      |     ∅       | acu128      | ..                                |
| ✗ | __fracttaqi        | aci128      |     ∅       | i8          | ..                                |
| ✗ | __fracttahi        | aci128      |     ∅       | c_short     | ..                                |
| ✗ | __fracttasi        | aci128      |     ∅       | c_int       | ..                                |
| ✗ | __fracttadi        | aci128      |     ∅       | c_long      | ..                                |
| ✗ | __fracttati        | aci128      |     ∅       | c_longlong  | ..                                |
| ✗ | __fracttasf        | aci128      |     ∅       | f32         | ..                                |
| ✗ | __fracttadf        | aci128      |     ∅       | f64         | ..                                |
| ✗ | __fractuqqqq       | fru16       |     ∅       | fri16       | ..                                |
| ✗ | __fractuqqhq       | fru16       |     ∅       | fri32       | ..                                |
| ✗ | __fractuqqsq       | fru16       |     ∅       | fri64       | ..                                |
| ✗ | __fractuqqdq       | fru16       |     ∅       | fri128      | ..                                |
| ✗ | __fractuqqha       | fru16       |     ∅       | aci16       | ..                                |
| ✗ | __fractuqqsa       | fru16       |     ∅       | aci32       | ..                                |
| ✗ | __fractuqqda       | fru16       |     ∅       | aci64       | ..                                |
| ✗ | __fractuqqta       | fru16       |     ∅       | aci128      | ..                                |
| ✗ | __fractuqquhq2     | fru16       |     ∅       | fru32       | ..                                |
| ✗ | __fractuqqusq2     | fru16       |     ∅       | fru64       | ..                                |
| ✗ | __fractuqqudq2     | fru16       |     ∅       | fru128      | ..                                |
| ✗ | __fractuqquha      | fru16       |     ∅       | acu16       | ..                                |
| ✗ | __fractuqqusa      | fru16       |     ∅       | acu32       | ..                                |
| ✗ | __fractuqquda      | fru16       |     ∅       | acu64       | ..                                |
| ✗ | __fractuqquta      | fru16       |     ∅       | acu128      | ..                                |
| ✗ | __fractuqqqi       | fru16       |     ∅       | i8          | ..                                |
| ✗ | __fractuqqhi       | fru16       |     ∅       | c_short     | ..                                |
| ✗ | __fractuqqsi       | fru16       |     ∅       | c_int       | ..                                |
| ✗ | __fractuqqdi       | fru16       |     ∅       | c_long      | ..                                |
| ✗ | __fractuqqti       | fru16       |     ∅       | c_longlong  | ..                                |
| ✗ | __fractuqqsf       | fru16       |     ∅       | f32         | ..                                |
| ✗ | __fractuqqdf       | fru16       |     ∅       | f64         | ..                                |
| ✗ | __fractuhqqq       | fru32       |     ∅       | fri16       | ..                                |
| ✗ | __fractuhqhq       | fru32       |     ∅       | fri32       | ..                                |
| ✗ | __fractuhqsq       | fru32       |     ∅       | fri64       | ..                                |
| ✗ | __fractuhqdq       | fru32       |     ∅       | fri128      | ..                                |
| ✗ | __fractuhqha       | fru32       |     ∅       | aci16       | ..                                |
| ✗ | __fractuhqsa       | fru32       |     ∅       | aci32       | ..                                |
| ✗ | __fractuhqda       | fru32       |     ∅       | aci64       | ..                                |
| ✗ | __fractuhqta       | fru32       |     ∅       | aci128      | ..                                |
| ✗ | __fractuhquqq2     | fru32       |     ∅       | fru16       | ..                                |
| ✗ | __fractuhqusq2     | fru32       |     ∅       | fru64       | ..                                |
| ✗ | __fractuhqudq2     | fru32       |     ∅       | fru128      | ..                                |
| ✗ | __fractuhquha      | fru32       |     ∅       | acu16       | ..                                |
| ✗ | __fractuhqusa      | fru32       |     ∅       | acu32       | ..                                |
| ✗ | __fractuhquda      | fru32       |     ∅       | acu64       | ..                                |
| ✗ | __fractuhquta      | fru32       |     ∅       | acu128      | ..                                |
| ✗ | __fractuhqqi       | fru32       |     ∅       | i8          | ..                                |
| ✗ | __fractuhqhi       | fru32       |     ∅       | c_short     | ..                                |
| ✗ | __fractuhqsi       | fru32       |     ∅       | c_int       | ..                                |
| ✗ | __fractuhqdi       | fru32       |     ∅       | c_long      | ..                                |
| ✗ | __fractuhqti       | fru32       |     ∅       | c_longlong  | ..                                |
| ✗ | __fractuhqsf       | fru32       |     ∅       | f32         | ..                                |
| ✗ | __fractuhqdf       | fru32       |     ∅       | f64         | ..                                |
| ✗ | __fractusqqq       | fru64       |     ∅       | fri16       | ..                                |
| ✗ | __fractusqhq       | fru64       |     ∅       | fri32       | ..                                |
| ✗ | __fractusqsq       | fru64       |     ∅       | fri64       | ..                                |
| ✗ | __fractusqdq       | fru64       |     ∅       | fri128      | ..                                |
| ✗ | __fractusqha       | fru64       |     ∅       | aci16       | ..                                |
| ✗ | __fractusqsa       | fru64       |     ∅       | aci32       | ..                                |
| ✗ | __fractusqda       | fru64       |     ∅       | aci64       | ..                                |
| ✗ | __fractusqta       | fru64       |     ∅       | aci128      | ..                                |
| ✗ | __fractusquqq2     | fru64       |     ∅       | fru16       | ..                                |
| ✗ | __fractusquhq2     | fru64       |     ∅       | fru32       | ..                                |
| ✗ | __fractusqudq2     | fru64       |     ∅       | fru128      | ..                                |
| ✗ | __fractusquha      | fru64       |     ∅       | acu16       | ..                                |
| ✗ | __fractusqusa      | fru64       |     ∅       | acu32       | ..                                |
| ✗ | __fractusquda      | fru64       |     ∅       | acu64       | ..                                |
| ✗ | __fractusquta      | fru64       |     ∅       | acu128      | ..                                |
| ✗ | __fractusqqi       | fru64       |     ∅       | i8          | ..                                |
| ✗ | __fractusqhi       | fru64       |     ∅       | c_short     | ..                                |
| ✗ | __fractusqsi       | fru64       |     ∅       | c_int       | ..                                |
| ✗ | __fractusqdi       | fru64       |     ∅       | c_long      | ..                                |
| ✗ | __fractusqti       | fru64       |     ∅       | c_longlong  | ..                                |
| ✗ | __fractusqsf       | fru64       |     ∅       | f32         | ..                                |
| ✗ | __fractusqdf       | fru64       |     ∅       | f64         | ..                                |
| ✗ | __fractudqqq       | fru128      |     ∅       | fri16       | ..                                |
| ✗ | __fractudqhq       | fru128      |     ∅       | fri32       | ..                                |
| ✗ | __fractudqsq       | fru128      |     ∅       | fri64       | ..                                |
| ✗ | __fractudqdq       | fru128      |     ∅       | fri128      | ..                                |
| ✗ | __fractudqha       | fru128      |     ∅       | aci16       | ..                                |
| ✗ | __fractudqsa       | fru128      |     ∅       | aci32       | ..                                |
| ✗ | __fractudqda       | fru128      |     ∅       | aci64       | ..                                |
| ✗ | __fractudqta       | fru128      |     ∅       | aci128      | ..                                |
| ✗ | __fractudquqq2     | fru128      |     ∅       | fru16       | ..                                |
| ✗ | __fractudquhq2     | fru128      |     ∅       | fru32       | ..                                |
| ✗ | __fractudqusq2     | fru128      |     ∅       | fru64       | ..                                |
| ✗ | __fractudquha      | fru128      |     ∅       | acu16       | ..                                |
| ✗ | __fractudqusa      | fru128      |     ∅       | acu32       | ..                                |
| ✗ | __fractudquda      | fru128      |     ∅       | acu64       | ..                                |
| ✗ | __fractudquta      | fru128      |     ∅       | acu128      | ..                                |
| ✗ | __fractudqqi       | fru128      |     ∅       | i8          | ..                                |
| ✗ | __fractudqhi       | fru128      |     ∅       | c_short     | ..                                |
| ✗ | __fractudqsi       | fru128      |     ∅       | c_int       | ..                                |
| ✗ | __fractudqdi       | fru128      |     ∅       | c_long      | ..                                |
| ✗ | __fractudqti       | fru128      |     ∅       | c_longlong  | ..                                |
| ✗ | __fractudqsf       | fru128      |     ∅       | f32         | ..                                |
| ✗ | __fractudqdf       | fru128      |     ∅       | f64         | ..                                |
| ✗ | __fractuhaqq       | acu16       |     ∅       | fri16       | ..                                |
| ✗ | __fractuhahq       | acu16       |     ∅       | fri32       | ..                                |
| ✗ | __fractuhasq       | acu16       |     ∅       | fri64       | ..                                |
| ✗ | __fractuhadq       | acu16       |     ∅       | fri128      | ..                                |
| ✗ | __fractuhaha       | acu16       |     ∅       | aci16       | ..                                |
| ✗ | __fractuhasa       | acu16       |     ∅       | aci32       | ..                                |
| ✗ | __fractuhada       | acu16       |     ∅       | aci64       | ..                                |
| ✗ | __fractuhata       | acu16       |     ∅       | aci128      | ..                                |
| ✗ | __fractuhauqq      | acu16       |     ∅       | fru16       | ..                                |
| ✗ | __fractuhauhq      | acu16       |     ∅       | fru32       | ..                                |
| ✗ | __fractuhausq      | acu16       |     ∅       | fru64       | ..                                |
| ✗ | __fractuhaudq      | acu16       |     ∅       | fru128      | ..                                |
| ✗ | __fractuhausa2     | acu16       |     ∅       | acu32       | ..                                |
| ✗ | __fractuhauda2     | acu16       |     ∅       | acu64       | ..                                |
| ✗ | __fractuhauta2     | acu16       |     ∅       | acu128      | ..                                |
| ✗ | __fractuhaqi       | acu16       |     ∅       | i8          | ..                                |
| ✗ | __fractuhahi       | acu16       |     ∅       | c_short     | ..                                |
| ✗ | __fractuhasi       | acu16       |     ∅       | c_int       | ..                                |
| ✗ | __fractuhadi       | acu16       |     ∅       | c_long      | ..                                |
| ✗ | __fractuhati       | acu16       |     ∅       | c_longlong  | ..                                |
| ✗ | __fractuhasf       | acu16       |     ∅       | f32         | ..                                |
| ✗ | __fractuhadf       | acu16       |     ∅       | f64         | ..                                |
| ✗ | __fractusaqq       | acu32       |     ∅       | fri16       | ..                                |
| ✗ | __fractusahq       | acu32       |     ∅       | fri32       | ..                                |
| ✗ | __fractusasq       | acu32       |     ∅       | fri64       | ..                                |
| ✗ | __fractusadq       | acu32       |     ∅       | fri128      | ..                                |
| ✗ | __fractusaha       | acu32       |     ∅       | aci16       | ..                                |
| ✗ | __fractusasa       | acu32       |     ∅       | aci32       | ..                                |
| ✗ | __fractusada       | acu32       |     ∅       | aci64       | ..                                |
| ✗ | __fractusata       | acu32       |     ∅       | aci128      | ..                                |
| ✗ | __fractusauqq      | acu32       |     ∅       | fru16       | ..                                |
| ✗ | __fractusauhq      | acu32       |     ∅       | fru32       | ..                                |
| ✗ | __fractusausq      | acu32       |     ∅       | fru64       | ..                                |
| ✗ | __fractusaudq      | acu32       |     ∅       | fru128      | ..                                |
| ✗ | __fractusauha2     | acu32       |     ∅       | acu16       | ..                                |
| ✗ | __fractusauda2     | acu32       |     ∅       | acu64       | ..                                |
| ✗ | __fractusauta2     | acu32       |     ∅       | acu128      | ..                                |
| ✗ | __fractusaqi       | acu32       |     ∅       | i8          | ..                                |
| ✗ | __fractusahi       | acu32       |     ∅       | c_short     | ..                                |
| ✗ | __fractusasi       | acu32       |     ∅       | c_int       | ..                                |
| ✗ | __fractusadi       | acu32       |     ∅       | c_long      | ..                                |
| ✗ | __fractusati       | acu32       |     ∅       | c_longlong  | ..                                |
| ✗ | __fractusasf       | acu32       |     ∅       | f32         | ..                                |
| ✗ | __fractusadf       | acu32       |     ∅       | f64         | ..                                |
| ✗ | __fractudaqq       | acu64       |     ∅       | fri16       | ..                                |
| ✗ | __fractudahq       | acu64       |     ∅       | fri32       | ..                                |
| ✗ | __fractudasq       | acu64       |     ∅       | fri64       | ..                                |
| ✗ | __fractudadq       | acu64       |     ∅       | fri128      | ..                                |
| ✗ | __fractudaha       | acu64       |     ∅       | aci16       | ..                                |
| ✗ | __fractudasa       | acu64       |     ∅       | aci32       | ..                                |
| ✗ | __fractudada       | acu64       |     ∅       | aci64       | ..                                |
| ✗ | __fractudata       | acu64       |     ∅       | aci128      | ..                                |
| ✗ | __fractudauqq      | acu64       |     ∅       | fru16       | ..                                |
| ✗ | __fractudauhq      | acu64       |     ∅       | fru32       | ..                                |
| ✗ | __fractudausq      | acu64       |     ∅       | fru64       | ..                                |
| ✗ | __fractudaudq      | acu64       |     ∅       | fru128      | ..                                |
| ✗ | __fractudauha2     | acu64       |     ∅       | acu16       | ..                                |
| ✗ | __fractudausa2     | acu64       |     ∅       | acu32       | ..                                |
| ✗ | __fractudauta2     | acu64       |     ∅       | acu128      | ..                                |
| ✗ | __fractudaqi       | acu64       |     ∅       | i8          | ..                                |
| ✗ | __fractudahi       | acu64       |     ∅       | c_short     | ..                                |
| ✗ | __fractudasi       | acu64       |     ∅       | c_int       | ..                                |
| ✗ | __fractudadi       | acu64       |     ∅       | c_long      | ..                                |
| ✗ | __fractudati       | acu64       |     ∅       | c_longlong  | ..                                |
| ✗ | __fractudasf       | acu64       |     ∅       | f32         | ..                                |
| ✗ | __fractudadf       | acu64       |     ∅       | f64         | ..                                |
| ✗ | __fractutaqq       | acu128      |     ∅       | fri16       | ..                                |
| ✗ | __fractutahq       | acu128      |     ∅       | fri32       | ..                                |
| ✗ | __fractutasq       | acu128      |     ∅       | fri64       | ..                                |
| ✗ | __fractutadq       | acu128      |     ∅       | fri128      | ..                                |
| ✗ | __fractutaha       | acu128      |     ∅       | aci16       | ..                                |
| ✗ | __fractutasa       | acu128      |     ∅       | aci32       | ..                                |
| ✗ | __fractutada       | acu128      |     ∅       | aci64       | ..                                |
| ✗ | __fractutata       | acu128      |     ∅       | aci128      | ..                                |
| ✗ | __fractutauqq      | acu128      |     ∅       | fru16       | ..                                |
| ✗ | __fractutauhq      | acu128      |     ∅       | fru32       | ..                                |
| ✗ | __fractutausq      | acu128      |     ∅       | fru64       | ..                                |
| ✗ | __fractutaudq      | acu128      |     ∅       | fru128      | ..                                |
| ✗ | __fractutauha2     | acu128      |     ∅       | acu16       | ..                                |
| ✗ | __fractutausa2     | acu128      |     ∅       | acu32       | ..                                |
| ✗ | __fractutauda2     | acu128      |     ∅       | acu64       | ..                                |
| ✗ | __fractutaqi       | acu128      |     ∅       | i8          | ..                                |
| ✗ | __fractutahi       | acu128      |     ∅       | c_short     | ..                                |
| ✗ | __fractutasi       | acu128      |     ∅       | c_int       | ..                                |
| ✗ | __fractutadi       | acu128      |     ∅       | c_long      | ..                                |
| ✗ | __fractutati       | acu128      |     ∅       | c_longlong  | ..                                |
| ✗ | __fractutasf       | acu128      |     ∅       | f32         | ..                                |
| ✗ | __fractutadf       | acu128      |     ∅       | f64         | ..                                |
| ✗ | __fractqiqq        | i8          |     ∅       | fri16       | Primitive to Fixed-Point without saturation|
| ✗ | __fractqihq        | i8          |     ∅       | fri32       | ..                                |
| ✗ | __fractqisq        | i8          |     ∅       | fri64       | ..                                |
| ✗ | __fractqidq        | i8          |     ∅       | fri128      | ..                                |
| ✗ | __fractqiha        | i8          |     ∅       | aci16       | ..                                |
| ✗ | __fractqisa        | i8          |     ∅       | aci32       | ..                                |
| ✗ | __fractqida        | i8          |     ∅       | aci64       | ..                                |
| ✗ | __fractqita        | i8          |     ∅       | aci128      | ..                                |
| ✗ | __fractqiuqq       | i8          |     ∅       | fru16       | ..                                |
| ✗ | __fractqiuhq       | i8          |     ∅       | fru32       | ..                                |
| ✗ | __fractqiusq       | i8          |     ∅       | fru64       | ..                                |
| ✗ | __fractqiudq       | i8          |     ∅       | fru128      | ..                                |
| ✗ | __fractqiuha       | i8          |     ∅       | acu16       | ..                                |
| ✗ | __fractqiusa       | i8          |     ∅       | acu32       | ..                                |
| ✗ | __fractqiuda       | i8          |     ∅       | acu64       | ..                                |
| ✗ | __fractqiuta       | i8          |     ∅       | acu128      | ..                                |
| ✗ | __fracthiqq        | c_short     |     ∅       | fri16       | ..                                |
| ✗ | __fracthihq        | c_short     |     ∅       | fri32       | ..                                |
| ✗ | __fracthisq        | c_short     |     ∅       | fri64       | ..                                |
| ✗ | __fracthidq        | c_short     |     ∅       | fri128      | ..                                |
| ✗ | __fracthiha        | c_short     |     ∅       | aci16       | ..                                |
| ✗ | __fracthisa        | c_short     |     ∅       | aci32       | ..                                |
| ✗ | __fracthida        | c_short     |     ∅       | aci64       | ..                                |
| ✗ | __fracthita        | c_short     |     ∅       | aci128      | ..                                |
| ✗ | __fracthiuqq       | c_short     |     ∅       | fru16       | ..                                |
| ✗ | __fracthiuhq       | c_short     |     ∅       | fru32       | ..                                |
| ✗ | __fracthiusq       | c_short     |     ∅       | fru64       | ..                                |
| ✗ | __fracthiudq       | c_short     |     ∅       | fru128      | ..                                |
| ✗ | __fracthiuha       | c_short     |     ∅       | acu16       | ..                                |
| ✗ | __fracthiusa       | c_short     |     ∅       | acu32       | ..                                |
| ✗ | __fracthiuda       | c_short     |     ∅       | acu64       | ..                                |
| ✗ | __fracthiuta       | c_short     |     ∅       | acu128      | ..                                |
| ✗ | __fractsiqq        | c_int       |     ∅       | fri16       | ..                                |
| ✗ | __fractsihq        | c_int       |     ∅       | fri32       | ..                                |
| ✗ | __fractsisq        | c_int       |     ∅       | fri64       | ..                                |
| ✗ | __fractsidq        | c_int       |     ∅       | fri128      | ..                                |
| ✗ | __fractsiha        | c_int       |     ∅       | aci16       | ..                                |
| ✗ | __fractsisa        | c_int       |     ∅       | aci32       | ..                                |
| ✗ | __fractsida        | c_int       |     ∅       | aci64       | ..                                |
| ✗ | __fractsita        | c_int       |     ∅       | aci128      | ..                                |
| ✗ | __fractsiuqq       | c_int       |     ∅       | fru16       | ..                                |
| ✗ | __fractsiuhq       | c_int       |     ∅       | fru32       | ..                                |
| ✗ | __fractsiusq       | c_int       |     ∅       | fru64       | ..                                |
| ✗ | __fractsiudq       | c_int       |     ∅       | fru128      | ..                                |
| ✗ | __fractsiuha       | c_int       |     ∅       | acu16       | ..                                |
| ✗ | __fractsiusa       | c_int       |     ∅       | acu32       | ..                                |
| ✗ | __fractsiuda       | c_int       |     ∅       | acu64       | ..                                |
| ✗ | __fractsiuta       | c_int       |     ∅       | acu128      | ..                                |
| ✗ | __fractdiqq        | c_long      |     ∅       | fri16       | ..                                |
| ✗ | __fractdihq        | c_long      |     ∅       | fri32       | ..                                |
| ✗ | __fractdisq        | c_long      |     ∅       | fri64       | ..                                |
| ✗ | __fractdidq        | c_long      |     ∅       | fri128      | ..                                |
| ✗ | __fractdiha        | c_long      |     ∅       | aci16       | ..                                |
| ✗ | __fractdisa        | c_long      |     ∅       | aci32       | ..                                |
| ✗ | __fractdida        | c_long      |     ∅       | aci64       | ..                                |
| ✗ | __fractdita        | c_long      |     ∅       | aci128      | ..                                |
| ✗ | __fractdiuqq       | c_long      |     ∅       | fru16       | ..                                |
| ✗ | __fractdiuhq       | c_long      |     ∅       | fru32       | ..                                |
| ✗ | __fractdiusq       | c_long      |     ∅       | fru64       | ..                                |
| ✗ | __fractdiudq       | c_long      |     ∅       | fru128      | ..                                |
| ✗ | __fractdiuha       | c_long      |     ∅       | acu16       | ..                                |
| ✗ | __fractdiusa       | c_long      |     ∅       | acu32       | ..                                |
| ✗ | __fractdiuda       | c_long      |     ∅       | acu64       | ..                                |
| ✗ | __fractdiuta       | c_long      |     ∅       | acu128      | ..                                |
| ✗ | __fracttiqq        | c_longlong  |     ∅       | fri16       | ..                                |
| ✗ | __fracttihq        | c_longlong  |     ∅       | fri32       | ..                                |
| ✗ | __fracttisq        | c_longlong  |     ∅       | fri64       | ..                                |
| ✗ | __fracttidq        | c_longlong  |     ∅       | fri128      | ..                                |
| ✗ | __fracttiha        | c_longlong  |     ∅       | aci16       | ..                                |
| ✗ | __fracttisa        | c_longlong  |     ∅       | aci32       | ..                                |
| ✗ | __fracttida        | c_longlong  |     ∅       | aci64       | ..                                |
| ✗ | __fracttita        | c_longlong  |     ∅       | aci128      | ..                                |
| ✗ | __fracttiuqq       | c_longlong  |     ∅       | fru16       | ..                                |
| ✗ | __fracttiuhq       | c_longlong  |     ∅       | fru32       | ..                                |
| ✗ | __fracttiusq       | c_longlong  |     ∅       | fru64       | ..                                |
| ✗ | __fracttiudq       | c_longlong  |     ∅       | fru128      | ..                                |
| ✗ | __fracttiuha       | c_longlong  |     ∅       | acu16       | ..                                |
| ✗ | __fracttiusa       | c_longlong  |     ∅       | acu32       | ..                                |
| ✗ | __fracttiuda       | c_longlong  |     ∅       | acu64       | ..                                |
| ✗ | __fracttiuta       | c_longlong  |     ∅       | acu128      | ..                                |
| ✗ | __fractsfqq        | f32         |     ∅       | fri16       | ..                                |
| ✗ | __fractsfhq        | f32         |     ∅       | fri32       | ..                                |
| ✗ | __fractsfsq        | f32         |     ∅       | fri64       | ..                                |
| ✗ | __fractsfdq        | f32         |     ∅       | fri128      | ..                                |
| ✗ | __fractsfha        | f32         |     ∅       | aci16       | ..                                |
| ✗ | __fractsfsa        | f32         |     ∅       | aci32       | ..                                |
| ✗ | __fractsfda        | f32         |     ∅       | aci64       | ..                                |
| ✗ | __fractsfta        | f32         |     ∅       | aci128      | ..                                |
| ✗ | __fractsfuqq       | f32         |     ∅       | fru16       | ..                                |
| ✗ | __fractsfuhq       | f32         |     ∅       | fru32       | ..                                |
| ✗ | __fractsfusq       | f32         |     ∅       | fru64       | ..                                |
| ✗ | __fractsfudq       | f32         |     ∅       | fru128      | ..                                |
| ✗ | __fractsfuha       | f32         |     ∅       | acu16       | ..                                |
| ✗ | __fractsfusa       | f32         |     ∅       | acu32       | ..                                |
| ✗ | __fractsfuda       | f32         |     ∅       | acu64       | ..                                |
| ✗ | __fractsfuta       | f32         |     ∅       | acu128      | ..                                |
| ✗ | __fractdfqq        | f64         |     ∅       | fri16       | ..                                |
| ✗ | __fractdfhq        | f64         |     ∅       | fri32       | ..                                |
| ✗ | __fractdfsq        | f64         |     ∅       | fri64       | ..                                |
| ✗ | __fractdfdq        | f64         |     ∅       | fri128      | ..                                |
| ✗ | __fractdfha        | f64         |     ∅       | aci16       | ..                                |
| ✗ | __fractdfsa        | f64         |     ∅       | aci32       | ..                                |
| ✗ | __fractdfda        | f64         |     ∅       | aci64       | ..                                |
| ✗ | __fractdfta        | f64         |     ∅       | aci128      | ..                                |
| ✗ | __fractdfuqq       | f64         |     ∅       | fru16       | ..                                |
| ✗ | __fractdfuhq       | f64         |     ∅       | fru32       | ..                                |
| ✗ | __fractdfusq       | f64         |     ∅       | fru64       | ..                                |
| ✗ | __fractdfudq       | f64         |     ∅       | fru128      | ..                                |
| ✗ | __fractdfuha       | f64         |     ∅       | acu16       | ..                                |
| ✗ | __fractdfusa       | f64         |     ∅       | acu32       | ..                                |
| ✗ | __fractdfuda       | f64         |     ∅       | acu64       | ..                                |
| ✗ | __fractdfuta       | f64         |     ∅       | acu128      | ..                                |
| ✗ | __satfractqqhq2    | fri16       |     ∅       | fri32       | Fixed-Point to other with saturation |
| ✗ | __satfractqqsq2    | fri16       |     ∅       | fri64       | ..                                |
| ✗ | __satfractqqdq2    | fri16       |     ∅       | fri128      | ..                                |
| ✗ | __satfractqqha     | fri16       |     ∅       | aci16       | ..                                |
| ✗ | __satfractqqsa     | fri16       |     ∅       | aci32       | ..                                |
| ✗ | __satfractqqda     | fri16       |     ∅       | aci64       | ..                                |
| ✗ | __satfractqqta     | fri16       |     ∅       | aci128      | ..                                |
| ✗ | __satfractqquqq    | fri16       |     ∅       | fru16       | ..                                |
| ✗ | __satfractqquhq    | fri16       |     ∅       | fru32       | ..                                |
| ✗ | __satfractqqusq    | fri16       |     ∅       | fru64       | ..                                |
| ✗ | __satfractqqudq    | fri16       |     ∅       | fru128      | ..                                |
| ✗ | __satfractqquha    | fri16       |     ∅       | acu16       | ..                                |
| ✗ | __satfractqqusa    | fri16       |     ∅       | acu32       | ..                                |
| ✗ | __satfractqquda    | fri16       |     ∅       | acu64       | ..                                |
| ✗ | __satfractqquta    | fri16       |     ∅       | acu128      | ..                                |
| ✗ | __satfracthqqq2    | fri32       |     ∅       | fri16       | ..                                |
| ✗ | __satfracthqsq2    | fri32       |     ∅       | fri64       | ..                                |
| ✗ | __satfracthqdq2    | fri32       |     ∅       | fri128      | ..                                |
| ✗ | __satfracthqha     | fri32       |     ∅       | aci16       | ..                                |
| ✗ | __satfracthqsa     | fri32       |     ∅       | aci32       | ..                                |
| ✗ | __satfracthqda     | fri32       |     ∅       | aci64       | ..                                |
| ✗ | __satfracthqta     | fri32       |     ∅       | aci128      | ..                                |
| ✗ | __satfracthquqq    | fri32       |     ∅       | fru16       | ..                                |
| ✗ | __satfracthquhq    | fri32       |     ∅       | fru32       | ..                                |
| ✗ | __satfracthqusq    | fri32       |     ∅       | fru64       | ..                                |
| ✗ | __satfracthqudq    | fri32       |     ∅       | fru128      | ..                                |
| ✗ | __satfracthquha    | fri32       |     ∅       | acu16       | ..                                |
| ✗ | __satfracthqusa    | fri32       |     ∅       | acu32       | ..                                |
| ✗ | __satfracthquda    | fri32       |     ∅       | acu64       | ..                                |
| ✗ | __satfracthquta    | fri32       |     ∅       | acu128      | ..                                |
| ✗ | __satfractsqqq2    | fri64       |     ∅       | fri16       | ..                                |
| ✗ | __satfractsqhq2    | fri64       |     ∅       | fri32       | ..                                |
| ✗ | __satfractsqdq2    | fri64       |     ∅       | fri128      | ..                                |
| ✗ | __satfractsqha     | fri64       |     ∅       | aci16       | ..                                |
| ✗ | __satfractsqsa     | fri64       |     ∅       | aci32       | ..                                |
| ✗ | __satfractsqda     | fri64       |     ∅       | aci64       | ..                                |
| ✗ | __satfractsqta     | fri64       |     ∅       | aci128      | ..                                |
| ✗ | __satfractsquqq    | fri64       |     ∅       | fru16       | ..                                |
| ✗ | __satfractsquhq    | fri64       |     ∅       | fru32       | ..                                |
| ✗ | __satfractsqusq    | fri64       |     ∅       | fru64       | ..                                |
| ✗ | __satfractsqudq    | fri64       |     ∅       | fru128      | ..                                |
| ✗ | __satfractsquha    | fri64       |     ∅       | acu16       | ..                                |
| ✗ | __satfractsqusa    | fri64       |     ∅       | acu32       | ..                                |
| ✗ | __satfractsquda    | fri64       |     ∅       | acu64       | ..                                |
| ✗ | __satfractsquta    | fri64       |     ∅       | acu128      | ..                                |
| ✗ | __satfractdqqq2    | fri128      |     ∅       | fri16       | ..                                |
| ✗ | __satfractdqhq2    | fri128      |     ∅       | fri32       | ..                                |
| ✗ | __satfractdqsq2    | fri128      |     ∅       | fri64       | ..                                |
| ✗ | __satfractdqha     | fri128      |     ∅       | aci16       | ..                                |
| ✗ | __satfractdqsa     | fri128      |     ∅       | aci32       | ..                                |
| ✗ | __satfractdqda     | fri128      |     ∅       | aci64       | ..                                |
| ✗ | __satfractdqta     | fri128      |     ∅       | aci128      | ..                                |
| ✗ | __satfractdquqq    | fri128      |     ∅       | fru16       | ..                                |
| ✗ | __satfractdquhq    | fri128      |     ∅       | fru32       | ..                                |
| ✗ | __satfractdqusq    | fri128      |     ∅       | fru64       | ..                                |
| ✗ | __satfractdqudq    | fri128      |     ∅       | fru128      | ..                                |
| ✗ | __satfractdquha    | fri128      |     ∅       | acu16       | ..                                |
| ✗ | __satfractdqusa    | fri128      |     ∅       | acu32       | ..                                |
| ✗ | __satfractdquda    | fri128      |     ∅       | acu64       | ..                                |
| ✗ | __satfractdquta    | fri128      |     ∅       | acu128      | ..                                |
| ✗ | __satfracthaqq     | aci16       |     ∅       | fri16       | ..                                |
| ✗ | __satfracthahq     | aci16       |     ∅       | fri32       | ..                                |
| ✗ | __satfracthasq     | aci16       |     ∅       | fri64       | ..                                |
| ✗ | __satfracthadq     | aci16       |     ∅       | fri128      | ..                                |
| ✗ | __satfracthasa2    | aci16       |     ∅       | aci32       | ..                                |
| ✗ | __satfracthada2    | aci16       |     ∅       | aci64       | ..                                |
| ✗ | __satfracthata2    | aci16       |     ∅       | aci128      | ..                                |
| ✗ | __satfracthauqq    | aci16       |     ∅       | fru16       | ..                                |
| ✗ | __satfracthauhq    | aci16       |     ∅       | fru32       | ..                                |
| ✗ | __satfracthausq    | aci16       |     ∅       | fru64       | ..                                |
| ✗ | __satfracthaudq    | aci16       |     ∅       | fru128      | ..                                |
| ✗ | __satfracthauha    | aci16       |     ∅       | acu16       | ..                                |
| ✗ | __satfracthausa    | aci16       |     ∅       | acu32       | ..                                |
| ✗ | __satfracthauda    | aci16       |     ∅       | acu64       | ..                                |
| ✗ | __satfracthauta    | aci16       |     ∅       | acu128      | ..                                |
| ✗ | __satfractsaqq     | aci32       |     ∅       | fri16       | ..                                |
| ✗ | __satfractsahq     | aci32       |     ∅       | fri32       | ..                                |
| ✗ | __satfractsasq     | aci32       |     ∅       | fri64       | ..                                |
| ✗ | __satfractsadq     | aci32       |     ∅       | fri128      | ..                                |
| ✗ | __satfractsaha2    | aci32       |     ∅       | aci16       | ..                                |
| ✗ | __satfractsada2    | aci32       |     ∅       | aci64       | ..                                |
| ✗ | __satfractsata2    | aci32       |     ∅       | aci128      | ..                                |
| ✗ | __satfractsauqq    | aci32       |     ∅       | fru16       | ..                                |
| ✗ | __satfractsauhq    | aci32       |     ∅       | fru32       | ..                                |
| ✗ | __satfractsausq    | aci32       |     ∅       | fru64       | ..                                |
| ✗ | __satfractsaudq    | aci32       |     ∅       | fru128      | ..                                |
| ✗ | __satfractsauha    | aci32       |     ∅       | acu16       | ..                                |
| ✗ | __satfractsausa    | aci32       |     ∅       | acu32       | ..                                |
| ✗ | __satfractsauda    | aci32       |     ∅       | acu64       | ..                                |
| ✗ | __satfractsauta    | aci32       |     ∅       | acu128      | ..                                |
| ✗ | __satfractdaqq     | aci64       |     ∅       | fri16       | ..                                |
| ✗ | __satfractdahq     | aci64       |     ∅       | fri32       | ..                                |
| ✗ | __satfractdasq     | aci64       |     ∅       | fri64       | ..                                |
| ✗ | __satfractdadq     | aci64       |     ∅       | fri128      | ..                                |
| ✗ | __satfractdaha2    | aci64       |     ∅       | aci16       | ..                                |
| ✗ | __satfractdasa2    | aci64       |     ∅       | aci32       | ..                                |
| ✗ | __satfractdata2    | aci64       |     ∅       | aci128      | ..                                |
| ✗ | __satfractdauqq    | aci64       |     ∅       | fru16       | ..                                |
| ✗ | __satfractdauhq    | aci64       |     ∅       | fru32       | ..                                |
| ✗ | __satfractdausq    | aci64       |     ∅       | fru64       | ..                                |
| ✗ | __satfractdaudq    | aci64       |     ∅       | fru128      | ..                                |
| ✗ | __satfractdauha    | aci64       |     ∅       | acu16       | ..                                |
| ✗ | __satfractdausa    | aci64       |     ∅       | acu32       | ..                                |
| ✗ | __satfractdauda    | aci64       |     ∅       | acu64       | ..                                |
| ✗ | __satfractdauta    | aci64       |     ∅       | acu128      | ..                                |
| ✗ | __satfracttaqq     | aci128      |     ∅       | fri16       | ..                                |
| ✗ | __satfracttahq     | aci128      |     ∅       | fri32       | ..                                |
| ✗ | __satfracttasq     | aci128      |     ∅       | fri64       | ..                                |
| ✗ | __satfracttadq     | aci128      |     ∅       | fri128      | ..                                |
| ✗ | __satfracttaha2    | aci128      |     ∅       | aci16       | ..                                |
| ✗ | __satfracttasa2    | aci128      |     ∅       | aci32       | ..                                |
| ✗ | __satfracttada2    | aci128      |     ∅       | aci64       | ..                                |
| ✗ | __satfracttauqq    | aci128      |     ∅       | fru16       | ..                                |
| ✗ | __satfracttauhq    | aci128      |     ∅       | fru32       | ..                                |
| ✗ | __satfracttausq    | aci128      |     ∅       | fru64       | ..                                |
| ✗ | __satfracttaudq    | aci128      |     ∅       | fru128      | ..                                |
| ✗ | __satfracttauha    | aci128      |     ∅       | acu16       | ..                                |
| ✗ | __satfracttausa    | aci128      |     ∅       | acu32       | ..                                |
| ✗ | __satfracttauda    | aci128      |     ∅       | acu64       | ..                                |
| ✗ | __satfracttauta    | aci128      |     ∅       | acu128      | ..                                |
| ✗ | __satfractuqqqq    | fru16       |     ∅       | fri16       | ..                                |
| ✗ | __satfractuqqhq    | fru16       |     ∅       | fri32       | ..                                |
| ✗ | __satfractuqqsq    | fru16       |     ∅       | fri64       | ..                                |
| ✗ | __satfractuqqdq    | fru16       |     ∅       | fri128      | ..                                |
| ✗ | __satfractuqqha    | fru16       |     ∅       | aci16       | ..                                |
| ✗ | __satfractuqqsa    | fru16       |     ∅       | aci32       | ..                                |
| ✗ | __satfractuqqda    | fru16       |     ∅       | aci64       | ..                                |
| ✗ | __satfractuqqta    | fru16       |     ∅       | aci128      | ..                                |
| ✗ | __satfractuqquhq2  | fru16       |     ∅       | fru32       | ..                                |
| ✗ | __satfractuqqusq2  | fru16       |     ∅       | fru64       | ..                                |
| ✗ | __satfractuqqudq2  | fru16       |     ∅       | fru128      | ..                                |
| ✗ | __satfractuqquha   | fru16       |     ∅       | acu16       | ..                                |
| ✗ | __satfractuqqusa   | fru16       |     ∅       | acu32       | ..                                |
| ✗ | __satfractuqquda   | fru16       |     ∅       | acu64       | ..                                |
| ✗ | __satfractuqquta   | fru16       |     ∅       | acu128      | ..                                |
| ✗ | __satfractuhqqq    | fru32       |     ∅       | fri16       | ..                                |
| ✗ | __satfractuhqhq    | fru32       |     ∅       | fri32       | ..                                |
| ✗ | __satfractuhqsq    | fru32       |     ∅       | fri64       | ..                                |
| ✗ | __satfractuhqdq    | fru32       |     ∅       | fri128      | ..                                |
| ✗ | __satfractuhqha    | fru32       |     ∅       | aci16       | ..                                |
| ✗ | __satfractuhqsa    | fru32       |     ∅       | aci32       | ..                                |
| ✗ | __satfractuhqda    | fru32       |     ∅       | aci64       | ..                                |
| ✗ | __satfractuhqta    | fru32       |     ∅       | aci128      | ..                                |
| ✗ | __satfractuhquqq2  | fru32       |     ∅       | fru16       | ..                                |
| ✗ | __satfractuhqusq2  | fru32       |     ∅       | fru64       | ..                                |
| ✗ | __satfractuhqudq2  | fru32       |     ∅       | fru128      | ..                                |
| ✗ | __satfractuhquha   | fru32       |     ∅       | acu16       | ..                                |
| ✗ | __satfractuhqusa   | fru32       |     ∅       | acu32       | ..                                |
| ✗ | __satfractuhquda   | fru32       |     ∅       | acu64       | ..                                |
| ✗ | __satfractuhquta   | fru32       |     ∅       | acu128      | ..                                |
| ✗ | __satfractusqqq    | fru64       |     ∅       | fri16       | ..                                |
| ✗ | __satfractusqhq    | fru64       |     ∅       | fri32       | ..                                |
| ✗ | __satfractusqsq    | fru64       |     ∅       | fri64       | ..                                |
| ✗ | __satfractusqdq    | fru64       |     ∅       | fri128      | ..                                |
| ✗ | __satfractusqha    | fru64       |     ∅       | aci16       | ..                                |
| ✗ | __satfractusqsa    | fru64       |     ∅       | aci32       | ..                                |
| ✗ | __satfractusqda    | fru64       |     ∅       | aci64       | ..                                |
| ✗ | __satfractusqta    | fru64       |     ∅       | aci128      | ..                                |
| ✗ | __satfractusquqq2  | fru64       |     ∅       | fru16       | ..                                |
| ✗ | __satfractusquhq2  | fru64       |     ∅       | fru32       | ..                                |
| ✗ | __satfractusqudq2  | fru64       |     ∅       | fru128      | ..                                |
| ✗ | __satfractusquha   | fru64       |     ∅       | acu16       | ..                                |
| ✗ | __satfractusqusa   | fru64       |     ∅       | acu32       | ..                                |
| ✗ | __satfractusquda   | fru64       |     ∅       | acu64       | ..                                |
| ✗ | __satfractusquta   | fru64       |     ∅       | acu128      | ..                                |
| ✗ | __satfractudqqq    | fru128      |     ∅       | fri16       | ..                                |
| ✗ | __satfractudqhq    | fru128      |     ∅       | fri32       | ..                                |
| ✗ | __satfractudqsq    | fru128      |     ∅       | fri64       | ..                                |
| ✗ | __satfractudqdq    | fru128      |     ∅       | fri128      | ..                                |
| ✗ | __satfractudqha    | fru128      |     ∅       | aci16       | ..                                |
| ✗ | __satfractudqsa    | fru128      |     ∅       | aci32       | ..                                |
| ✗ | __satfractudqda    | fru128      |     ∅       | aci64       | ..                                |
| ✗ | __satfractudqta    | fru128      |     ∅       | aci128      | ..                                |
| ✗ | __satfractudquqq2  | fru128      |     ∅       | fru16       | ..                                |
| ✗ | __satfractudquhq2  | fru128      |     ∅       | fru32       | ..                                |
| ✗ | __satfractudqusq2  | fru128      |     ∅       | fru64       | ..                                |
| ✗ | __satfractudquha   | fru128      |     ∅       | acu16       | ..                                |
| ✗ | __satfractudqusa   | fru128      |     ∅       | acu32       | ..                                |
| ✗ | __satfractudquda   | fru128      |     ∅       | acu64       | ..                                |
| ✗ | __satfractudquta   | fru128      |     ∅       | acu128      | ..                                |
| ✗ | __satfractuhaqq    | acu16       |     ∅       | fri16       | ..                                |
| ✗ | __satfractuhahq    | acu16       |     ∅       | fri32       | ..                                |
| ✗ | __satfractuhasq    | acu16       |     ∅       | fri64       | ..                                |
| ✗ | __satfractuhadq    | acu16       |     ∅       | fri128      | ..                                |
| ✗ | __satfractuhaha    | acu16       |     ∅       | aci16       | ..                                |
| ✗ | __satfractuhasa    | acu16       |     ∅       | aci32       | ..                                |
| ✗ | __satfractuhada    | acu16       |     ∅       | aci64       | ..                                |
| ✗ | __satfractuhata    | acu16       |     ∅       | aci128      | ..                                |
| ✗ | __satfractuhauqq   | acu16       |     ∅       | fru16       | ..                                |
| ✗ | __satfractuhauhq   | acu16       |     ∅       | fru32       | ..                                |
| ✗ | __satfractuhausq   | acu16       |     ∅       | fru64       | ..                                |
| ✗ | __satfractuhaudq   | acu16       |     ∅       | fru128      | ..                                |
| ✗ | __satfractuhausa2  | acu16       |     ∅       | acu32       | ..                                |
| ✗ | __satfractuhauda2  | acu16       |     ∅       | acu64       | ..                                |
| ✗ | __satfractuhauta2  | acu16       |     ∅       | acu128      | ..                                |
| ✗ | __satfractusaqq    | acu32       |     ∅       | fri16       | ..                                |
| ✗ | __satfractusahq    | acu32       |     ∅       | fri32       | ..                                |
| ✗ | __satfractusasq    | acu32       |     ∅       | fri64       | ..                                |
| ✗ | __satfractusadq    | acu32       |     ∅       | fri128      | ..                                |
| ✗ | __satfractusaha    | acu32       |     ∅       | aci16       | ..                                |
| ✗ | __satfractusasa    | acu32       |     ∅       | aci32       | ..                                |
| ✗ | __satfractusada    | acu32       |     ∅       | aci64       | ..                                |
| ✗ | __satfractusata    | acu32       |     ∅       | aci128      | ..                                |
| ✗ | __satfractusauqq   | acu32       |     ∅       | fru16       | ..                                |
| ✗ | __satfractusauhq   | acu32       |     ∅       | fru32       | ..                                |
| ✗ | __satfractusausq   | acu32       |     ∅       | fru64       | ..                                |
| ✗ | __satfractusaudq   | acu32       |     ∅       | fru128      | ..                                |
| ✗ | __satfractusauha2  | acu32       |     ∅       | acu16       | ..                                |
| ✗ | __satfractusauda2  | acu32       |     ∅       | acu64       | ..                                |
| ✗ | __satfractusauta2  | acu32       |     ∅       | acu128      | ..                                |
| ✗ | __satfractudaqq    | acu64       |     ∅       | fri16       | ..                                |
| ✗ | __satfractudahq    | acu64       |     ∅       | fri32       | ..                                |
| ✗ | __satfractudasq    | acu64       |     ∅       | fri64       | ..                                |
| ✗ | __satfractudadq    | acu64       |     ∅       | fri128      | ..                                |
| ✗ | __satfractudaha    | acu64       |     ∅       | aci16       | ..                                |
| ✗ | __satfractudasa    | acu64       |     ∅       | aci32       | ..                                |
| ✗ | __satfractudada    | acu64       |     ∅       | aci64       | ..                                |
| ✗ | __satfractudata    | acu64       |     ∅       | aci128      | ..                                |
| ✗ | __satfractudauqq   | acu64       |     ∅       | fru16       | ..                                |
| ✗ | __satfractudauhq   | acu64       |     ∅       | fru32       | ..                                |
| ✗ | __satfractudausq   | acu64       |     ∅       | fru64       | ..                                |
| ✗ | __satfractudaudq   | acu64       |     ∅       | fru128      | ..                                |
| ✗ | __satfractudauha2  | acu64       |     ∅       | acu16       | ..                                |
| ✗ | __satfractudausa2  | acu64       |     ∅       | acu32       | ..                                |
| ✗ | __satfractudauta2  | acu64       |     ∅       | acu128      | ..                                |
| ✗ | __satfractutaqq    | acu128      |     ∅       | fri16       | ..                                |
| ✗ | __satfractutahq    | acu128      |     ∅       | fri32       | ..                                |
| ✗ | __satfractutasq    | acu128      |     ∅       | fri64       | ..                                |
| ✗ | __satfractutadq    | acu128      |     ∅       | fri128      | ..                                |
| ✗ | __satfractutaha    | acu128      |     ∅       | aci16       | ..                                |
| ✗ | __satfractutasa    | acu128      |     ∅       | aci32       | ..                                |
| ✗ | __satfractutada    | acu128      |     ∅       | aci64       | ..                                |
| ✗ | __satfractutata    | acu128      |     ∅       | aci128      | ..                                |
| ✗ | __satfractutauqq   | acu128      |     ∅       | fru16       | ..                                |
| ✗ | __satfractutauhq   | acu128      |     ∅       | fru32       | ..                                |
| ✗ | __satfractutausq   | acu128      |     ∅       | fru64       | ..                                |
| ✗ | __satfractutaudq   | acu128      |     ∅       | fru128      | ..                                |
| ✗ | __satfractutauha2  | acu128      |     ∅       | acu16       | ..                                |
| ✗ | __satfractutausa2  | acu128      |     ∅       | acu32       | ..                                |
| ✗ | __satfractutauda2  | acu128      |     ∅       | acu64       | ..                                |
| ✗ | __satfractqiqq     | i8          |     ∅       | fri16       | Primitive to Fix-Point with saturation |
| ✗ | __satfractqihq     | i8          |     ∅       | fri32       | ..                                |
| ✗ | __satfractqisq     | i8          |     ∅       | fri64       | ..                                |
| ✗ | __satfractqidq     | i8          |     ∅       | fri128      | ..                                |
| ✗ | __satfractqiha     | i8          |     ∅       | aci16       | ..                                |
| ✗ | __satfractqisa     | i8          |     ∅       | aci32       | ..                                |
| ✗ | __satfractqida     | i8          |     ∅       | aci64       | ..                                |
| ✗ | __satfractqita     | i8          |     ∅       | aci128      | ..                                |
| ✗ | __satfractqiuqq    | i8          |     ∅       | fru16       | ..                                |
| ✗ | __satfractqiuhq    | i8          |     ∅       | fru32       | ..                                |
| ✗ | __satfractqiusq    | i8          |     ∅       | fru64       | ..                                |
| ✗ | __satfractqiudq    | i8          |     ∅       | fru128      | ..                                |
| ✗ | __satfractqiuha    | i8          |     ∅       | acu16       | ..                                |
| ✗ | __satfractqiusa    | i8          |     ∅       | acu32       | ..                                |
| ✗ | __satfractqiuda    | i8          |     ∅       | acu64       | ..                                |
| ✗ | __satfractqiuta    | i8          |     ∅       | acu128      | ..                                |
| ✗ | __satfracthiqq     | c_short     |     ∅       | fri16       | ..                                |
| ✗ | __satfracthihq     | c_short     |     ∅       | fri32       | ..                                |
| ✗ | __satfracthisq     | c_short     |     ∅       | fri64       | ..                                |
| ✗ | __satfracthidq     | c_short     |     ∅       | fri128      | ..                                |
| ✗ | __satfracthiha     | c_short     |     ∅       | aci16       | ..                                |
| ✗ | __satfracthisa     | c_short     |     ∅       | aci32       | ..                                |
| ✗ | __satfracthida     | c_short     |     ∅       | aci64       | ..                                |
| ✗ | __satfracthita     | c_short     |     ∅       | aci128      | ..                                |
| ✗ | __satfracthiuqq    | c_short     |     ∅       | fru16       | ..                                |
| ✗ | __satfracthiuhq    | c_short     |     ∅       | fru32       | ..                                |
| ✗ | __satfracthiusq    | c_short     |     ∅       | fru64       | ..                                |
| ✗ | __satfracthiudq    | c_short     |     ∅       | fru128      | ..                                |
| ✗ | __satfracthiuha    | c_short     |     ∅       | acu16       | ..                                |
| ✗ | __satfracthiusa    | c_short     |     ∅       | acu32       | ..                                |
| ✗ | __satfracthiuda    | c_short     |     ∅       | acu64       | ..                                |
| ✗ | __satfracthiuta    | c_short     |     ∅       | acu128      | ..                                |
| ✗ | __satfractsiqq     | c_int       |     ∅       | fri16       | ..                                |
| ✗ | __satfractsihq     | c_int       |     ∅       | fri32       | ..                                |
| ✗ | __satfractsisq     | c_int       |     ∅       | fri64       | ..                                |
| ✗ | __satfractsidq     | c_int       |     ∅       | fri128      | ..                                |
| ✗ | __satfractsiha     | c_int       |     ∅       | aci16       | ..                                |
| ✗ | __satfractsisa     | c_int       |     ∅       | aci32       | ..                                |
| ✗ | __satfractsida     | c_int       |     ∅       | aci64       | ..                                |
| ✗ | __satfractsita     | c_int       |     ∅       | aci128      | ..                                |
| ✗ | __satfractsiuqq    | c_int       |     ∅       | fru16       | ..                                |
| ✗ | __satfractsiuhq    | c_int       |     ∅       | fru32       | ..                                |
| ✗ | __satfractsiusq    | c_int       |     ∅       | fru64       | ..                                |
| ✗ | __satfractsiudq    | c_int       |     ∅       | fru128      | ..                                |
| ✗ | __satfractsiuha    | c_int       |     ∅       | acu16       | ..                                |
| ✗ | __satfractsiusa    | c_int       |     ∅       | acu32       | ..                                |
| ✗ | __satfractsiuda    | c_int       |     ∅       | acu64       | ..                                |
| ✗ | __satfractsiuta    | c_int       |     ∅       | acu128      | ..                                |
| ✗ | __satfractdiqq     | c_long      |     ∅       | fri16       | ..                                |
| ✗ | __satfractdihq     | c_long      |     ∅       | fri32       | ..                                |
| ✗ | __satfractdisq     | c_long      |     ∅       | fri64       | ..                                |
| ✗ | __satfractdidq     | c_long      |     ∅       | fri128      | ..                                |
| ✗ | __satfractdiha     | c_long      |     ∅       | aci16       | ..                                |
| ✗ | __satfractdisa     | c_long      |     ∅       | aci32       | ..                                |
| ✗ | __satfractdida     | c_long      |     ∅       | aci64       | ..                                |
| ✗ | __satfractdita     | c_long      |     ∅       | aci128      | ..                                |
| ✗ | __satfractdiuqq    | c_long      |     ∅       | fru16       | ..                                |
| ✗ | __satfractdiuhq    | c_long      |     ∅       | fru32       | ..                                |
| ✗ | __satfractdiusq    | c_long      |     ∅       | fru64       | ..                                |
| ✗ | __satfractdiudq    | c_long      |     ∅       | fru128      | ..                                |
| ✗ | __satfractdiuha    | c_long      |     ∅       | acu16       | ..                                |
| ✗ | __satfractdiusa    | c_long      |     ∅       | acu32       | ..                                |
| ✗ | __satfractdiuda    | c_long      |     ∅       | acu64       | ..                                |
| ✗ | __satfractdiuta    | c_long      |     ∅       | acu128      | ..                                |
| ✗ | __satfracttiqq     | c_longlong  |     ∅       | fri16       | ..                                |
| ✗ | __satfracttihq     | c_longlong  |     ∅       | fri32       | ..                                |
| ✗ | __satfracttisq     | c_longlong  |     ∅       | fri64       | ..                                |
| ✗ | __satfracttidq     | c_longlong  |     ∅       | fri128      | ..                                |
| ✗ | __satfracttiha     | c_longlong  |     ∅       | aci16       | ..                                |
| ✗ | __satfracttisa     | c_longlong  |     ∅       | aci32       | ..                                |
| ✗ | __satfracttida     | c_longlong  |     ∅       | aci64       | ..                                |
| ✗ | __satfracttita     | c_longlong  |     ∅       | aci128      | ..                                |
| ✗ | __satfracttiuqq    | c_longlong  |     ∅       | fru16       | ..                                |
| ✗ | __satfracttiuhq    | c_longlong  |     ∅       | fru32       | ..                                |
| ✗ | __satfracttiusq    | c_longlong  |     ∅       | fru64       | ..                                |
| ✗ | __satfracttiudq    | c_longlong  |     ∅       | fru128      | ..                                |
| ✗ | __satfracttiuha    | c_longlong  |     ∅       | acu16       | ..                                |
| ✗ | __satfracttiusa    | c_longlong  |     ∅       | acu32       | ..                                |
| ✗ | __satfracttiuda    | c_longlong  |     ∅       | acu64       | ..                                |
| ✗ | __satfracttiuta    | c_longlong  |     ∅       | acu128      | ..                                |
| ✗ | __satfractsfqq     | f32         |     ∅       | fri16       | ..                                |
| ✗ | __satfractsfhq     | f32         |     ∅       | fri32       | ..                                |
| ✗ | __satfractsfsq     | f32         |     ∅       | fri64       | ..                                |
| ✗ | __satfractsfdq     | f32         |     ∅       | fri128      | ..                                |
| ✗ | __satfractsfha     | f32         |     ∅       | aci16       | ..                                |
| ✗ | __satfractsfsa     | f32         |     ∅       | aci32       | ..                                |
| ✗ | __satfractsfda     | f32         |     ∅       | aci64       | ..                                |
| ✗ | __satfractsfta     | f32         |     ∅       | aci128      | ..                                |
| ✗ | __satfractsfuqq    | f32         |     ∅       | fru16       | ..                                |
| ✗ | __satfractsfuhq    | f32         |     ∅       | fru32       | ..                                |
| ✗ | __satfractsfusq    | f32         |     ∅       | fru64       | ..                                |
| ✗ | __satfractsfudq    | f32         |     ∅       | fru128      | ..                                |
| ✗ | __satfractsfuha    | f32         |     ∅       | acu16       | ..                                |
| ✗ | __satfractsfusa    | f32         |     ∅       | acu32       | ..                                |
| ✗ | __satfractsfuda    | f32         |     ∅       | acu64       | ..                                |
| ✗ | __satfractsfuta    | f32         |     ∅       | acu128      | ..                                |
| ✗ | __satfractdfqq     | f64         |     ∅       | fri16       | ..                                |
| ✗ | __satfractdfhq     | f64         |     ∅       | fri32       | ..                                |
| ✗ | __satfractdfsq     | f64         |     ∅       | fri64       | ..                                |
| ✗ | __satfractdfdq     | f64         |     ∅       | fri128      | ..                                |
| ✗ | __satfractdfha     | f64         |     ∅       | aci16       | ..                                |
| ✗ | __satfractdfsa     | f64         |     ∅       | aci32       | ..                                |
| ✗ | __satfractdfda     | f64         |     ∅       | aci64       | ..                                |
| ✗ | __satfractdfta     | f64         |     ∅       | aci128      | ..                                |
| ✗ | __satfractdfuqq    | f64         |     ∅       | fru16       | ..                                |
| ✗ | __satfractdfuhq    | f64         |     ∅       | fru32       | ..                                |
| ✗ | __satfractdfusq    | f64         |     ∅       | fru64       | ..                                |
| ✗ | __satfractdfudq    | f64         |     ∅       | fru128      | ..                                |
| ✗ | __satfractdfuha    | f64         |     ∅       | acu16       | ..                                |
| ✗ | __satfractdfusa    | f64         |     ∅       | acu32       | ..                                |
| ✗ | __satfractdfuda    | f64         |     ∅       | acu64       | ..                                |
| ✗ | __satfractdfuta    | f64         |     ∅       | acu128      | ..                                |
| ✗ | __fractunsqqqi     | fri16       |     ∅       | u8          | Fix-Point to otherwithout saturation |
| ✗ | __fractunsqqhi     | fri16       |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunsqqsi     | fri16       |     ∅       | c_uint      | ..                                |
| ✗ | __fractunsqqdi     | fri16       |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunsqqti     | fri16       |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunshqqi     | fri32       |     ∅       | u8          | ..                                |
| ✗ | __fractunshqhi     | fri32       |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunshqsi     | fri32       |     ∅       | c_uint      | ..                                |
| ✗ | __fractunshqdi     | fri32       |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunshqti     | fri32       |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunssqqi     | fri64       |     ∅       | u8          | ..                                |
| ✗ | __fractunssqhi     | fri64       |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunssqsi     | fri64       |     ∅       | c_uint      | ..                                |
| ✗ | __fractunssqdi     | fri64       |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunssqti     | fri64       |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunsdqqi     | fri128      |     ∅       | u8          | ..                                |
| ✗ | __fractunsdqhi     | fri128      |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunsdqsi     | fri128      |     ∅       | c_uint      | ..                                |
| ✗ | __fractunsdqdi     | fri128      |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunsdqti     | fri128      |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunshaqi     | aci16       |     ∅       | u8          | ..                                |
| ✗ | __fractunshahi     | aci16       |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunshasi     | aci16       |     ∅       | c_uint      | ..                                |
| ✗ | __fractunshadi     | aci16       |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunshati     | aci16       |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunssaqi     | aci32       |     ∅       | u8          | ..                                |
| ✗ | __fractunssahi     | aci32       |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunssasi     | aci32       |     ∅       | c_uint      | ..                                |
| ✗ | __fractunssadi     | aci32       |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunssati     | aci32       |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunsdaqi     | aci64       |     ∅       | u8          | ..                                |
| ✗ | __fractunsdahi     | aci64       |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunsdasi     | aci64       |     ∅       | c_uint      | ..                                |
| ✗ | __fractunsdadi     | aci64       |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunsdati     | aci64       |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunstaqi     | aci128      |     ∅       | u8          | ..                                |
| ✗ | __fractunstahi     | aci128      |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunstasi     | aci128      |     ∅       | c_uint      | ..                                |
| ✗ | __fractunstadi     | aci128      |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunstati     | aci128      |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunsuqqqi    | fru16       |     ∅       | u8          | ..                                |
| ✗ | __fractunsuqqhi    | fru16       |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunsuqqsi    | fru16       |     ∅       | c_uint      | ..                                |
| ✗ | __fractunsuqqdi    | fru16       |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunsuqqti    | fru16       |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunsuhqqi    | fru32       |     ∅       | u8          | ..                                |
| ✗ | __fractunsuhqhi    | fru32       |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunsuhqsi    | fru32       |     ∅       | c_uint      | ..                                |
| ✗ | __fractunsuhqdi    | fru32       |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunsuhqti    | fru32       |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunsusqqi    | fru64       |     ∅       | u8          | ..                                |
| ✗ | __fractunsusqhi    | fru64       |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunsusqsi    | fru64       |     ∅       | c_uint      | ..                                |
| ✗ | __fractunsusqdi    | fru64       |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunsusqti    | fru64       |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunsudqqi    | fru128      |     ∅       | u8          | ..                                |
| ✗ | __fractunsudqhi    | fru128      |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunsudqsi    | fru128      |     ∅       | c_uint      | ..                                |
| ✗ | __fractunsudqdi    | fru128      |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunsudqti    | fru128      |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunsuhaqi    | acu16       |     ∅       | u8          | ..                                |
| ✗ | __fractunsuhahi    | acu16       |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunsuhasi    | acu16       |     ∅       | c_uint      | ..                                |
| ✗ | __fractunsuhadi    | acu16       |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunsuhati    | acu16       |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunsusaqi    | acu32       |     ∅       | u8          | ..                                |
| ✗ | __fractunsusahi    | acu32       |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunsusasi    | acu32       |     ∅       | c_uint      | ..                                |
| ✗ | __fractunsusadi    | acu32       |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunsusati    | acu32       |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunsudaqi    | acu64       |     ∅       | u8          | ..                                |
| ✗ | __fractunsudahi    | acu64       |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunsudasi    | acu64       |     ∅       | c_uint      | ..                                |
| ✗ | __fractunsudadi    | acu64       |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunsudati    | acu64       |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunsutaqi    | acu128      |     ∅       | u8          | ..                                |
| ✗ | __fractunsutahi    | acu128      |     ∅       | c_ushort    | ..                                |
| ✗ | __fractunsutasi    | acu128      |     ∅       | c_uint      | ..                                |
| ✗ | __fractunsutadi    | acu128      |     ∅       | c_ulong     | ..                                |
| ✗ | __fractunsutati    | acu128      |     ∅       | c_ulonglong | ..                                |
| ✗ | __fractunsqiqq     | u8          |     ∅       | fri16       | Primitive to other without saturation |
| ✗ | __fractunsqihq     | u8          |     ∅       | fri32       | ..                                |
| ✗ | __fractunsqisq     | u8          |     ∅       | fri64       | ..                                |
| ✗ | __fractunsqidq     | u8          |     ∅       | fri128      | ..                                |
| ✗ | __fractunsqiha     | u8          |     ∅       | aci16       | ..                                |
| ✗ | __fractunsqisa     | u8          |     ∅       | aci32       | ..                                |
| ✗ | __fractunsqida     | u8          |     ∅       | aci64       | ..                                |
| ✗ | __fractunsqita     | u8          |     ∅       | aci128      | ..                                |
| ✗ | __fractunsqiuqq    | u8          |     ∅       | fru16       | ..                                |
| ✗ | __fractunsqiuhq    | u8          |     ∅       | fru32       | ..                                |
| ✗ | __fractunsqiusq    | u8          |     ∅       | fru64       | ..                                |
| ✗ | __fractunsqiudq    | u8          |     ∅       | fru128      | ..                                |
| ✗ | __fractunsqiuha    | u8          |     ∅       | acu16       | ..                                |
| ✗ | __fractunsqiusa    | u8          |     ∅       | acu32       | ..                                |
| ✗ | __fractunsqiuda    | u8          |     ∅       | acu64       | ..                                |
| ✗ | __fractunsqiuta    | u8          |     ∅       | acu128      | ..                                |
| ✗ | __fractunshiqq     | c_ushort    |     ∅       | fri16       | ..                                |
| ✗ | __fractunshihq     | c_ushort    |     ∅       | fri32       | ..                                |
| ✗ | __fractunshisq     | c_ushort    |     ∅       | fri64       | ..                                |
| ✗ | __fractunshidq     | c_ushort    |     ∅       | fri128      | ..                                |
| ✗ | __fractunshiha     | c_ushort    |     ∅       | aci16       | ..                                |
| ✗ | __fractunshisa     | c_ushort    |     ∅       | aci32       | ..                                |
| ✗ | __fractunshida     | c_ushort    |     ∅       | aci64       | ..                                |
| ✗ | __fractunshita     | c_ushort    |     ∅       | aci128      | ..                                |
| ✗ | __fractunshiuqq    | c_ushort    |     ∅       | fru16       | ..                                |
| ✗ | __fractunshiuhq    | c_ushort    |     ∅       | fru32       | ..                                |
| ✗ | __fractunshiusq    | c_ushort    |     ∅       | fru64       | ..                                |
| ✗ | __fractunshiudq    | c_ushort    |     ∅       | fru128      | ..                                |
| ✗ | __fractunshiuha    | c_ushort    |     ∅       | acu16       | ..                                |
| ✗ | __fractunshiusa    | c_ushort    |     ∅       | acu32       | ..                                |
| ✗ | __fractunshiuda    | c_ushort    |     ∅       | acu64       | ..                                |
| ✗ | __fractunshiuta    | c_ushort    |     ∅       | acu128      | ..                                |
| ✗ | __fractunssiqq     | c_uint      |     ∅       | fri16       | ..                                |
| ✗ | __fractunssihq     | c_uint      |     ∅       | fri32       | ..                                |
| ✗ | __fractunssisq     | c_uint      |     ∅       | fri64       | ..                                |
| ✗ | __fractunssidq     | c_uint      |     ∅       | fri128      | ..                                |
| ✗ | __fractunssiha     | c_uint      |     ∅       | aci16       | ..                                |
| ✗ | __fractunssisa     | c_uint      |     ∅       | aci32       | ..                                |
| ✗ | __fractunssida     | c_uint      |     ∅       | aci64       | ..                                |
| ✗ | __fractunssita     | c_uint      |     ∅       | aci128      | ..                                |
| ✗ | __fractunssiuqq    | c_uint      |     ∅       | fru16       | ..                                |
| ✗ | __fractunssiuhq    | c_uint      |     ∅       | fru32       | ..                                |
| ✗ | __fractunssiusq    | c_uint      |     ∅       | fru64       | ..                                |
| ✗ | __fractunssiudq    | c_uint      |     ∅       | fru128      | ..                                |
| ✗ | __fractunssiuha    | c_uint      |     ∅       | acu16       | ..                                |
| ✗ | __fractunssiusa    | c_uint      |     ∅       | acu32       | ..                                |
| ✗ | __fractunssiuda    | c_uint      |     ∅       | acu64       | ..                                |
| ✗ | __fractunssiuta    | c_uint      |     ∅       | acu128      | ..                                |
| ✗ | __fractunsdiqq     | c_ulong     |     ∅       | fri16       | ..                                |
| ✗ | __fractunsdihq     | c_ulong     |     ∅       | fri32       | ..                                |
| ✗ | __fractunsdisq     | c_ulong     |     ∅       | fri64       | ..                                |
| ✗ | __fractunsdidq     | c_ulong     |     ∅       | fri128      | ..                                |
| ✗ | __fractunsdiha     | c_ulong     |     ∅       | aci16       | ..                                |
| ✗ | __fractunsdisa     | c_ulong     |     ∅       | aci32       | ..                                |
| ✗ | __fractunsdida     | c_ulong     |     ∅       | aci64       | ..                                |
| ✗ | __fractunsdita     | c_ulong     |     ∅       | aci128      | ..                                |
| ✗ | __fractunsdiuqq    | c_ulong     |     ∅       | fru16       | ..                                |
| ✗ | __fractunsdiuhq    | c_ulong     |     ∅       | fru32       | ..                                |
| ✗ | __fractunsdiusq    | c_ulong     |     ∅       | fru64       | ..                                |
| ✗ | __fractunsdiudq    | c_ulong     |     ∅       | fru128      | ..                                |
| ✗ | __fractunsdiuha    | c_ulong     |     ∅       | acu16       | ..                                |
| ✗ | __fractunsdiusa    | c_ulong     |     ∅       | acu32       | ..                                |
| ✗ | __fractunsdiuda    | c_ulong     |     ∅       | acu64       | ..                                |
| ✗ | __fractunsdiuta    | c_ulong     |     ∅       | acu128      | ..                                |
| ✗ | __fractunstiqq     | c_ulonglong |     ∅       | fri16       | ..                                |
| ✗ | __fractunstihq     | c_ulonglong |     ∅       | fri32       | ..                                |
| ✗ | __fractunstisq     | c_ulonglong |     ∅       | fri64       | ..                                |
| ✗ | __fractunstidq     | c_ulonglong |     ∅       | fri128      | ..                                |
| ✗ | __fractunstiha     | c_ulonglong |     ∅       | aci16       | ..                                |
| ✗ | __fractunstisa     | c_ulonglong |     ∅       | aci32       | ..                                |
| ✗ | __fractunstida     | c_ulonglong |     ∅       | aci64       | ..                                |
| ✗ | __fractunstita     | c_ulonglong |     ∅       | aci128      | ..                                |
| ✗ | __fractunstiuqq    | c_ulonglong |     ∅       | fru16       | ..                                |
| ✗ | __fractunstiuhq    | c_ulonglong |     ∅       | fru32       | ..                                |
| ✗ | __fractunstiusq    | c_ulonglong |     ∅       | fru64       | ..                                |
| ✗ | __fractunstiudq    | c_ulonglong |     ∅       | fru128      | ..                                |
| ✗ | __fractunstiuha    | c_ulonglong |     ∅       | acu16       | ..                                |
| ✗ | __fractunstiusa    | c_ulonglong |     ∅       | acu32       | ..                                |
| ✗ | __fractunstiuda    | c_ulonglong |     ∅       | acu64       | ..                                |
| ✗ | __fractunstiuta    | c_ulonglong |     ∅       | acu128      | ..                                |
| ✗ | __satfractunsqiqq  | u8          |     ∅       | fri16       | Primitive to Fix-Point with saturation |
| ✗ | __satfractunsqihq  | u8          |     ∅       | fri32       | ..                                |
| ✗ | __satfractunsqisq  | u8          |     ∅       | fri64       | ..                                |
| ✗ | __satfractunsqidq  | u8          |     ∅       | fri128      | ..                                |
| ✗ | __satfractunsqiha  | u8          |     ∅       | aci16       | ..                                |
| ✗ | __satfractunsqisa  | u8          |     ∅       | aci32       | ..                                |
| ✗ | __satfractunsqida  | u8          |     ∅       | aci64       | ..                                |
| ✗ | __satfractunsqita  | u8          |     ∅       | aci128      | ..                                |
| ✗ | __satfractunsqiuqq | u8          |     ∅       | fru16       | ..                                |
| ✗ | __satfractunsqiuhq | u8          |     ∅       | fru32       | ..                                |
| ✗ | __satfractunsqiusq | u8          |     ∅       | fru64       | ..                                |
| ✗ | __satfractunsqiudq | u8          |     ∅       | fru128      | ..                                |
| ✗ | __satfractunsqiuha | u8          |     ∅       | acu16       | ..                                |
| ✗ | __satfractunsqiusa | u8          |     ∅       | acu32       | ..                                |
| ✗ | __satfractunsqiuda | u8          |     ∅       | acu64       | ..                                |
| ✗ | __satfractunsqiuta | u8          |     ∅       | acu128      | ..                                |
| ✗ | __satfractunshiqq  | c_ushort    |     ∅       | fri16       | ..                                |
| ✗ | __satfractunshihq  | c_ushort    |     ∅       | fri32       | ..                                |
| ✗ | __satfractunshisq  | c_ushort    |     ∅       | fri64       | ..                                |
| ✗ | __satfractunshidq  | c_ushort    |     ∅       | fri128      | ..                                |
| ✗ | __satfractunshiha  | c_ushort    |     ∅       | aci16       | ..                                |
| ✗ | __satfractunshisa  | c_ushort    |     ∅       | aci32       | ..                                |
| ✗ | __satfractunshida  | c_ushort    |     ∅       | aci64       | ..                                |
| ✗ | __satfractunshita  | c_ushort    |     ∅       | aci128      | ..                                |
| ✗ | __satfractunshiuqq | c_ushort    |     ∅       | fru16       | ..                                |
| ✗ | __satfractunshiuhq | c_ushort    |     ∅       | fru32       | ..                                |
| ✗ | __satfractunshiusq | c_ushort    |     ∅       | fru64       | ..                                |
| ✗ | __satfractunshiudq | c_ushort    |     ∅       | fru128      | ..                                |
| ✗ | __satfractunshiuha | c_ushort    |     ∅       | acu16       | ..                                |
| ✗ | __satfractunshiusa | c_ushort    |     ∅       | acu32       | ..                                |
| ✗ | __satfractunshiuda | c_ushort    |     ∅       | acu64       | ..                                |
| ✗ | __satfractunshiuta | c_ushort    |     ∅       | acu128      | ..                                |
| ✗ | __satfractunssiqq  | c_uint      |     ∅       | fri16       | ..                                |
| ✗ | __satfractunssihq  | c_uint      |     ∅       | fri32       | ..                                |
| ✗ | __satfractunssisq  | c_uint      |     ∅       | fri64       | ..                                |
| ✗ | __satfractunssidq  | c_uint      |     ∅       | fri128      | ..                                |
| ✗ | __satfractunssiha  | c_uint      |     ∅       | aci16       | ..                                |
| ✗ | __satfractunssisa  | c_uint      |     ∅       | aci32       | ..                                |
| ✗ | __satfractunssida  | c_uint      |     ∅       | aci64       | ..                                |
| ✗ | __satfractunssita  | c_uint      |     ∅       | aci128      | ..                                |
| ✗ | __satfractunssiuqq | c_uint      |     ∅       | fru16       | ..                                |
| ✗ | __satfractunssiuhq | c_uint      |     ∅       | fru32       | ..                                |
| ✗ | __satfractunssiusq | c_uint      |     ∅       | fru64       | ..                                |
| ✗ | __satfractunssiudq | c_uint      |     ∅       | fru128      | ..                                |
| ✗ | __satfractunssiuha | c_uint      |     ∅       | acu16       | ..                                |
| ✗ | __satfractunssiusa | c_uint      |     ∅       | acu32       | ..                                |
| ✗ | __satfractunssiuda | c_uint      |     ∅       | acu64       | ..                                |
| ✗ | __satfractunssiuta | c_uint      |     ∅       | acu128      | ..                                |
| ✗ | __satfractunsdiqq  | c_ulong     |     ∅       | fri16       | ..                                |
| ✗ | __satfractunsdihq  | c_ulong     |     ∅       | fri32       | ..                                |
| ✗ | __satfractunsdisq  | c_ulong     |     ∅       | fri64       | ..                                |
| ✗ | __satfractunsdidq  | c_ulong     |     ∅       | fri128      | ..                                |
| ✗ | __satfractunsdiha  | c_ulong     |     ∅       | aci16       | ..                                |
| ✗ | __satfractunsdisa  | c_ulong     |     ∅       | aci32       | ..                                |
| ✗ | __satfractunsdida  | c_ulong     |     ∅       | aci64       | ..                                |
| ✗ | __satfractunsdita  | c_ulong     |     ∅       | aci128      | ..                                |
| ✗ | __satfractunsdiuqq | c_ulong     |     ∅       | fru16       | ..                                |
| ✗ | __satfractunsdiuhq | c_ulong     |     ∅       | fru32       | ..                                |
| ✗ | __satfractunsdiusq | c_ulong     |     ∅       | fru64       | ..                                |
| ✗ | __satfractunsdiudq | c_ulong     |     ∅       | fru128      | ..                                |
| ✗ | __satfractunsdiuha | c_ulong     |     ∅       | acu16       | ..                                |
| ✗ | __satfractunsdiusa | c_ulong     |     ∅       | acu32       | ..                                |
| ✗ | __satfractunsdiuda | c_ulong     |     ∅       | acu64       | ..                                |
| ✗ | __satfractunsdiuta | c_ulong     |     ∅       | acu128      | ..                                |
| ✗ | __satfractunstiqq  | c_ulonglong |     ∅       | fri16       | ..                                |
| ✗ | __satfractunstihq  | c_ulonglong |     ∅       | fri32       | ..                                |
| ✗ | __satfractunstisq  | c_ulonglong |     ∅       | fri64       | ..                                |
| ✗ | __satfractunstidq  | c_ulonglong |     ∅       | fri128      | ..                                |
| ✗ | __satfractunstiha  | c_ulonglong |     ∅       | aci16       | ..                                |
| ✗ | __satfractunstisa  | c_ulonglong |     ∅       | aci32       | ..                                |
| ✗ | __satfractunstida  | c_ulonglong |     ∅       | aci64       | ..                                |
| ✗ | __satfractunstita  | c_ulonglong |     ∅       | aci128      | ..                                |
| ✗ | __satfractunstiuqq | c_ulonglong |     ∅       | fru16       | ..                                |
| ✗ | __satfractunstiuhq | c_ulonglong |     ∅       | fru32       | ..                                |
| ✗ | __satfractunstiusq | c_ulonglong |     ∅       | fru64       | ..                                |
| ✗ | __satfractunstiudq | c_ulonglong |     ∅       | fru128      | ..                                |
| ✗ | __satfractunstiuha | c_ulonglong |     ∅       | acu16       | ..                                |
| ✗ | __satfractunstiusa | c_ulonglong |     ∅       | acu32       | ..                                |
| ✗ | __satfractunstiuda | c_ulonglong |     ∅       | acu64       | ..                                |
| ✗ | __satfractunstiuta | c_ulonglong |     ∅       | acu128      | ..                                |
|   |                    |             |                           | **Fixed-Point Comparison**        |
| ✗ | __cmpqq2           | fri16       | fri16       | c_int       | a<b => 0, a==b => 1, a>b=> 2      |
| ✗ | __cmphq2           | fri32       | fri32       | c_int       | ..                                |
| ✗ | __cmpsq2           | fri64       | fri64       | c_int       | ..                                |
| ✗ | __cmpdq2           | fri128      | fri128      | c_int       | ..                                |
| ✗ | __cmpuqq2          | fru16       | fru16       | c_int       | ..                                |
| ✗ | __cmpuhq2          | fru32       | fru32       | c_int       | ..                                |
| ✗ | __cmpusq2          | fru64       | fru64       | c_int       | ..                                |
| ✗ | __cmpudq2          | fru128      | fru128      | c_int       | ..                                |
| ✗ | __cmpha2           | aci16       | aci16       | c_int       | ..                                |
| ✗ | __cmpsa2           | aci32       | aci32       | c_int       | ..                                |
| ✗ | __cmpda2           | aci64       | aci64       | c_int       | ..                                |
| ✗ | __cmpta2           | aci128      | aci128      | c_int       | ..                                |
| ✗ | __cmpuha2          | acu16       | acu16       | c_int       | ..                                |
| ✗ | __cmpusa2          | acu32       | acu32       | c_int       | ..                                |
| ✗ | __cmpuda2          | acu64       | acu64       | c_int       | ..                                |
| ✗ | __cmputa2          | acu128      | acu128      | c_int       | ..                                |
|   |                    |             |             |             | **Fixed-Point Arithmetic**        |
| ✗ | __addqq3           | fri16       | fri16       | fri16       | `a+b`                             |
| ✗ | __addhq3           | fri32       | fri32       | fri32       | ..                                |
| ✗ | __addsq3           | fri64       | fri64       | fri64       | ..                                |
| ✗ | __adddq3           | fri128      | fri128      | fri128      | ..                                |
| ✗ | __adduqq3          | fru16       | fru16       | fru16       | ..                                |
| ✗ | __adduhq3          | fru32       | fru32       | fru32       | ..                                |
| ✗ | __addusq3          | fru64       | fru64       | fru64       | ..                                |
| ✗ | __addudq3          | fru128      | fru128      | fru128      | ..                                |
| ✗ | __addha3           | aci16       | aci16       | aci16       | ..                                |
| ✗ | __addsa3           | aci32       | aci32       | aci32       | ..                                |
| ✗ | __addda3           | aci64       | aci64       | aci64       | ..                                |
| ✗ | __addta3           | aci128      | aci128      | aci128      | ..                                |
| ✗ | __adduha3          | acu16       | acu16       | acu16       | ..                                |
| ✗ | __addusa3          | acu32       | acu32       | acu32       | ..                                |
| ✗ | __adduda3          | acu64       | acu64       | acu64       | ..                                |
| ✗ | __adduta3          | acu128      | acu128      | acu128      | ..                                |
| ✗ | __ssaddqq3         | fri16       | fri16       | fri16       | `a+b` with signed saturation      |
| ✗ | __ssaddhq3         | fri32       | fri32       | fri32       | ..                                |
| ✗ | __ssaddsq3         | fri64       | fri64       | fri64       | ..                                |
| ✗ | __ssadddq3         | fri128      | fri128      | fri128      | ..                                |
| ✗ | __ssaddha3         | aci16       | aci16       | aci16       | ..                                |
| ✗ | __ssaddsa3         | aci32       | aci32       | aci32       | ..                                |
| ✗ | __ssaddda3         | aci64       | aci64       | aci64       | ..                                |
| ✗ | __ssaddta3         | aci128      | aci128      | aci128      | ..                                |
| ✗ | __usadduqq3        | fru16       | fru16       | fru16       | `a+b` with unsigned saturation    |
| ✗ | __usadduhq3        | fru32       | fru32       | fru32       | ..                                |
| ✗ | __usaddusq3        | fru64       | fru64       | fru64       | ..                                |
| ✗ | __usaddudq3        | fru128      | fru128      | fru128      | ..                                |
| ✗ | __usadduha3        | acu16       | acu16       | acu16       | ..                                |
| ✗ | __usaddusa3        | acu32       | acu32       | acu32       | ..                                |
| ✗ | __usadduda3        | acu64       | acu64       | acu64       | ..                                |
| ✗ | __usadduta3        | acu128      | acu128      | acu128      | ..                                |
| ✗ | __subqq3           | fri16       | fri16       | fri16       | `a-b`                             |
| ✗ | __subhq3           | fri32       | fri32       | fri32       | ..                                |
| ✗ | __subsq3           | fri64       | fri64       | fri64       | ..                                |
| ✗ | __subdq3           | fri128      | fri128      | fri128      | ..                                |
| ✗ | __subuqq3          | fru16       | fru16       | fru16       | ..                                |
| ✗ | __subuhq3          | fru32       | fru32       | fru32       | ..                                |
| ✗ | __subusq3          | fru64       | fru64       | fru64       | ..                                |
| ✗ | __subudq3          | fru128      | fru128      | fru128      | ..                                |
| ✗ | __subha3           | aci16       | aci16       | aci16       | ..                                |
| ✗ | __subsa3           | aci32       | aci32       | aci32       | ..                                |
| ✗ | __subda3           | aci64       | aci64       | aci64       | ..                                |
| ✗ | __subta3           | aci128      | aci128      | aci128      | ..                                |
| ✗ | __subuha3          | acu16       | acu16       | acu16       | ..                                |
| ✗ | __subusa3          | acu32       | acu32       | acu32       | ..                                |
| ✗ | __subuda3          | acu64       | acu64       | acu64       | ..                                |
| ✗ | __subuta3          | acu128      | acu128      | acu128      | ..                                |
| ✗ | __sssubqq3         | fri16       | fri16       | fri16       | `a-b` with signed saturation      |
| ✗ | __sssubhq3         | fri32       | fri32       | fri32       | ..                                |
| ✗ | __sssubsq3         | fri64       | fri64       | fri64       | ..                                |
| ✗ | __sssubdq3         | fri128      | fri128      | fri128      | ..                                |
| ✗ | __sssubha3         | aci16       | aci16       | aci16       | ..                                |
| ✗ | __sssubsa3         | aci32       | aci32       | aci32       | ..                                |
| ✗ | __sssubda3         | aci64       | aci64       | aci64       | ..                                |
| ✗ | __sssubta3         | aci128      | aci128      | aci128      | ..                                |
| ✗ | __ussubuqq3        | fru16       | fru16       | fru16       | `a-b` with unsigned saturation    |
| ✗ | __ussubuhq3        | fru32       | fru32       | fru32       | ..                                |
| ✗ | __ussubusq3        | fru64       | fru64       | fru64       | ..                                |
| ✗ | __ussubudq3        | fru128      | fru128      | fru128      | ..                                |
| ✗ | __ussubuha3        | acu16       | acu16       | acu16       | ..                                |
| ✗ | __ussubusa3        | acu32       | acu32       | acu32       | ..                                |
| ✗ | __ussubuda3        | acu64       | acu64       | acu64       | ..                                |
| ✗ | __ussubuta3        | acu128      | acu128      | acu128      | ..                                |
| ✗ | __mulqq3           | fri16       | fri16       | fri16       | `a*b`                             |
| ✗ | __mulhq3           | fri32       | fri32       | fri32       | ..                                |
| ✗ | __mulsq3           | fri64       | fri64       | fri64       | ..                                |
| ✗ | __muldq3           | fri128      | fri128      | fri128      | ..                                |
| ✗ | __muluqq3          | fru16       | fru16       | fru16       | ..                                |
| ✗ | __muluhq3          | fru32       | fru32       | fru32       | ..                                |
| ✗ | __mulusq3          | fru64       | fru64       | fru64       | ..                                |
| ✗ | __muludq3          | fru128      | fru128      | fru128      | ..                                |
| ✗ | __mulha3           | aci16       | aci16       | aci16       | ..                                |
| ✗ | __mulsa3           | aci32       | aci32       | aci32       | ..                                |
| ✗ | __mulda3           | aci64       | aci64       | aci64       | ..                                |
| ✗ | __multa3           | aci128      | aci128      | aci128      | ..                                |
| ✗ | __muluha3          | acu16       | acu16       | acu16       | ..                                |
| ✗ | __mulusa3          | acu32       | acu32       | acu32       | ..                                |
| ✗ | __muluda3          | acu64       | acu64       | acu64       | ..                                |
| ✗ | __muluta3          | acu128      | acu128      | acu128      | ..                                |
| ✗ | __ssmulqq3         | fri16       | fri16       | fri16       | `a*b` with signed saturation      |
| ✗ | __ssmulhq3         | fri32       | fri32       | fri32       | ..                                |
| ✗ | __ssmulsq3         | fri64       | fri64       | fri64       | ..                                |
| ✗ | __ssmuldq3         | fri128      | fri128      | fri128      | ..                                |
| ✗ | __ssmulha3         | aci16       | aci16       | aci16       | ..                                |
| ✗ | __ssmulsa3         | aci32       | aci32       | aci32       | ..                                |
| ✗ | __ssmulda3         | aci64       | aci64       | aci64       | ..                                |
| ✗ | __ssmulta3         | aci128      | aci128      | aci128      | ..                                |
| ✗ | __usmuluqq3        | fru16       | fru16       | fru16       | `a/b` with unsigned saturation    |
| ✗ | __usmuluhq3        | fru32       | fru32       | fru32       | ..                                |
| ✗ | __usmulusq3        | fru64       | fru64       | fru64       | ..                                |
| ✗ | __usmuludq3        | fru128      | fru128      | fru128      | ..                                |
| ✗ | __usmuluha3        | acu16       | acu16       | acu16       | ..                                |
| ✗ | __usmulusa3        | acu32       | acu32       | acu32       | ..                                |
| ✗ | __usmuluda3        | acu64       | acu64       | acu64       | ..                                |
| ✗ | __usmuluta3        | acu128      | acu128      | acu128      | ..                                |
| ✗ | __divqq3           | fri16       | fri16       | fri16       | `a/b`                             |
| ✗ | __divhq3           | fri32       | fri32       | fri32       | ..                                |
| ✗ | __divsq3           | fri64       | fri64       | fri64       | ..                                |
| ✗ | __divdq3           | fri128      | fri128      | fri128      | ..                                |
| ✗ | __divha3           | aci16       | aci16       | aci16       | ..                                |
| ✗ | __divsa3           | aci32       | aci32       | aci32       | ..                                |
| ✗ | __divda3           | aci64       | aci64       | aci64       | ..                                |
| ✗ | __divta3           | aci128      | aci128      | aci128      | ..                                |
| ✗ | __udivuqq3         | fru16       | fru16       | fru16       | `a/b`                             |
| ✗ | __udivuhq3         | fru32       | fru32       | fru32       | ..                                |
| ✗ | __udivusq3         | fru64       | fru64       | fru64       | ..                                |
| ✗ | __udivudq3         | fru128      | fru128      | fru128      | ..                                |
| ✗ | __udivuha3         | acu16       | acu16       | acu16       | ..                                |
| ✗ | __udivusa3         | acu32       | acu32       | acu32       | ..                                |
| ✗ | __udivuda3         | acu64       | acu64       | acu64       | ..                                |
| ✗ | __udivuta3         | acu128      | acu128      | acu128      | ..                                |
| ✗ | __ssdivqq3         | fri16       | fri16       | fri16       | `a/b` with signed saturation      |
| ✗ | __ssdivhq3         | fri32       | fri32       | fri32       | ..                                |
| ✗ | __ssdivsq3         | fri64       | fri64       | fri64       | ..                                |
| ✗ | __ssdivdq3         | fri128      | fri128      | fri128      | ..                                |
| ✗ | __ssdivha3         | aci16       | aci16       | aci16       | ..                                |
| ✗ | __ssdivsa3         | aci32       | aci32       | aci32       | ..                                |
| ✗ | __ssdivda3         | aci64       | aci64       | aci64       | ..                                |
| ✗ | __ssdivta3         | aci128      | aci128      | aci128      | ..                                |
| ✗ | __usdivuqq3        | fru16       | fru16       | fru16       | `a/b` with unsigned saturation    |
| ✗ | __usdivuhq3        | fru32       | fru32       | fru32       | ..                                |
| ✗ | __usdivusq3        | fru64       | fru64       | fru64       | ..                                |
| ✗ | __usdivudq3        | fru128      | fru128      | fru128      | ..                                |
| ✗ | __usdivuha3        | acu16       | acu16       | acu16       | ..                                |
| ✗ | __usdivusa3        | acu32       | acu32       | acu32       | ..                                |
| ✗ | __usdivuda3        | acu64       | acu64       | acu64       | ..                                |
| ✗ | __usdivuta3        | acu128      | acu128      | acu128      | ..                                |
| ✗ | __negqq2           | fri16       |     ∅       | fri16       | `-a`                              |
| ✗ | __neghq2           | fri32       |     ∅       | fri32       | ..                                |
| ✗ | __negsq2           | fri64       |     ∅       | fri64       | ..                                |
| ✗ | __negdq2           | fri128      |     ∅       | fri128      | ..                                |
| ✗ | __neguqq2          | fru16       |     ∅       | fru16       | ..                                |
| ✗ | __neguhq2          | fru32       |     ∅       | fru32       | ..                                |
| ✗ | __negusq2          | fru64       |     ∅       | fru64       | ..                                |
| ✗ | __negudq2          | fru128      |     ∅       | fru128      | ..                                |
| ✗ | __negha2           | aci16       |     ∅       | aci16       | ..                                |
| ✗ | __negsa2           | aci32       |     ∅       | aci32       | ..                                |
| ✗ | __negda2           | aci64       |     ∅       | aci64       | ..                                |
| ✗ | __negta2           | aci128      |     ∅       | aci128      | ..                                |
| ✗ | __neguha2          | acu16       |     ∅       | acu16       | ..                                |
| ✗ | __negusa2          | acu32       |     ∅       | acu32       | ..                                |
| ✗ | __neguda2          | acu64       |     ∅       | acu64       | ..                                |
| ✗ | __neguta2          | acu128      |     ∅       | acu128      | ..                                |
| ✗ | __ssnegqq2         | fri16       |     ∅       | fri16       | `-a` with signed saturation       |
| ✗ | __ssneghq2         | fri32       |     ∅       | fri32       | ..                                |
| ✗ | __ssnegsq2         | fri64       |     ∅       | fri64       | ..                                |
| ✗ | __ssnegdq2         | fri128      |     ∅       | fri128      | ..                                |
| ✗ | __ssnegha2         | aci16       |     ∅       | aci16       | ..                                |
| ✗ | __ssnegsa2         | aci32       |     ∅       | aci32       | ..                                |
| ✗ | __ssnegda2         | aci64       |     ∅       | aci64       | ..                                |
| ✗ | __ssnegta2         | aci128      |     ∅       | aci128      | ..                                |
| ✗ | __usneguqq2        | fru16       |     ∅       | fru16       | `-a` with unsigned saturation     |
| ✗ | __usneguhq2        | fru32       |     ∅       | fru32       | ..                                |
| ✗ | __usnegusq2        | fru64       |     ∅       | fru64       | ..                                |
| ✗ | __usnegudq2        | fru128      |     ∅       | fru128      | ..                                |
| ✗ | __usneguha2        | acu16       |     ∅       | acu16       | ..                                |
| ✗ | __usnegusa2        | acu32       |     ∅       | acu32       | ..                                |
| ✗ | __usneguda2        | acu64       |     ∅       | acu64       | ..                                |
| ✗ | __usneguta2        | acu128      |     ∅       | acu128      | ..                                |
| ✗ | __ashlqq3          | fri16       | c_int       | fri16       | `a << b`                          |
| ✗ | __ashlhq3          | fri32       | c_int       | fri32       | ..                                |
| ✗ | __ashlsq3          | fri64       | c_int       | fri64       | ..                                |
| ✗ | __ashldq3          | fri128      | c_int       | fri128      | ..                                |
| ✗ | __ashluqq3         | fru16       | c_int       | fru16       | ..                                |
| ✗ | __ashluhq3         | fru32       | c_int       | fru32       | ..                                |
| ✗ | __ashlusq3         | fru64       | c_int       | fru64       | ..                                |
| ✗ | __ashludq3         | fru128      | c_int       | fru128      | ..                                |
| ✗ | __ashlha3          | aci16       | c_int       | aci16       | ..                                |
| ✗ | __ashlsa3          | aci32       | c_int       | aci32       | ..                                |
| ✗ | __ashlda3          | aci64       | c_int       | aci64       | ..                                |
| ✗ | __ashlta3          | aci128      | c_int       | aci128      | ..                                |
| ✗ | __ashluha3         | acu16       | c_int       | acu16       | ..                                |
| ✗ | __ashlusa3         | acu32       | c_int       | acu32       | ..                                |
| ✗ | __ashluda3         | acu64       | c_int       | acu64       | ..                                |
| ✗ | __ashluta3         | acu128      | c_int       | acu128      | ..                                |
| ✗ | __ashrqq3          | fri16       | c_int       | fri16       | `a >> b` arithmetic (sign fill)   |
| ✗ | __ashrhq3          | fri32       | c_int       | fri32       | ..                                |
| ✗ | __ashrsq3          | fri64       | c_int       | fri64       | ..                                |
| ✗ | __ashrdq3          | fri128      | c_int       | fri128      | ..                                |
| ✗ | __ashrha3          | aci16       | c_int       | aci16       | ..                                |
| ✗ | __ashrsa3          | aci32       | c_int       | aci32       | ..                                |
| ✗ | __ashrda3          | aci64       | c_int       | aci64       | ..                                |
| ✗ | __ashrta3          | aci128      | c_int       | aci128      | ..                                |
| ✗ | __lshruqq3         | fru16       | c_int       | fru16       | `a >> b` logical (zero fill)      |
| ✗ | __lshruhq3         | fru32       | c_int       | fru32       | ..                                |
| ✗ | __lshrusq3         | fru64       | c_int       | fru64       | ..                                |
| ✗ | __lshrudq3         | fru128      | c_int       | fru128      | ..                                |
| ✗ | __lshruha3         | acu16       | c_int       | acu16       | ..                                |
| ✗ | __lshrusa3         | acu32       | c_int       | acu32       | ..                                |
| ✗ | __lshruda3         | acu64       | c_int       | acu64       | ..                                |
| ✗ | __lshruta3         | acu128      | c_int       | acu128      | ..                                |
| ✗ | __ssashlhq3        | fri32       | c_int       | fri32       | `a << b` with signed saturation   |
| ✗ | __ssashlsq3        | fri64       | c_int       | fri64       | ..                                |
| ✗ | __ssashldq3        | fri128      | c_int       | fri128      | ..                                |
| ✗ | __ssashlha3        | aci16       | c_int       | aci16       | ..                                |
| ✗ | __ssashlsa3        | aci32       | c_int       | aci32       | ..                                |
| ✗ | __ssashlda3        | aci64       | c_int       | aci64       | ..                                |
| ✗ | __ssashlta3        | aci128      | c_int       | aci128      | ..                                |
| ✗ | __usashluqq3       | fru16       | c_int       | fru16       | `a << b` with unsigned saturation |
| ✗ | __usashluhq3       | fru32       | c_int       | fru32       | ..                                |
| ✗ | __usashlusq3       | fru64       | c_int       | fru64       | ..                                |
| ✗ | __usashludq3       | fru128      | c_int       | fru128      | ..                                |
| ✗ | __usashluha3       | acu16       | c_int       | acu16       | ..                                |
| ✗ | __usashlusa3       | acu32       | c_int       | acu32       | ..                                |
| ✗ | __usashluda3       | acu64       | c_int       | acu64       | ..                                |
| ✗ | __usashluta3       | acu128      | c_int       | acu128      | ..                                |

Math functions according to C99 with gnu extension sincos. f16, f80 and f128 functions
are additionally supported by Zig, but not part of C standard. Alphabetically sorted.

| Done | Name    | a         | b         | Out       | Comment                    |
| ---- | ------- | --------- | --------- | --------- | -------------------------- |
| ✓ | __ceilh    |     f16   |    ∅      |     f16   |smallest integer value not less than a|
| ✓ | ceilf      |     f32   |    ∅      |     f32   |If a is integer, +-0, +-NaN, or +-infinite, a itself is returned.|
| ✓ | ceil       |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __ceilx    |     f80   |    ∅      |     f80   |                            |
| ✓ | ceilf128   |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | ceilq      |     f128  |    ∅      |     f128  | ..                         |
| ✓ | ceill      |c_longdouble|   ∅      |c_longdouble| ..                        |
| ✓ | __cosh     |     f16   |    ∅      |     f16   | `cos(a)=(e^(ia)+e^(-ia))/2`|
| ✓ | cosf       |     f32   |    ∅      |     f32   | ..                         |
| ✓ | cos        |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __cosx     |     f80   |    ∅      |     f80   | ..                         |
| ✓ | cosf128    |     f128  |    ∅      |     f128  | ..                         |
| ✓ | cosq       |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | cosl       |c_longdouble|   ∅      |c_longdouble| ..                        |
| ✓ | __exph     |     f16   |    ∅      |     f16   | `e^a` with e base of natural logarithms|
| ✓ | expf       |     f32   |    ∅      |     f32   | ..                         |
| ✓ | exp        |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __expx     |     f80   |    ∅      |     f80   | ..                         |
| ✓ | expf128    |     f128  |    ∅      |     f128  | ..                         |
| ✓ | expq       |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | expl       |c_longdouble|   ∅      |c_longdouble| ..                        |
| ✓ | __exp2h    |     f16   |    ∅      |     f16   | `2^a`                      |
| ✓ | exp2f      |     f32   |    ∅      |     f32   | ..                         |
| ✓ | exp2       |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __exp2x    |     f80   |    ∅      |     f80   | ..                         |
| ✓ | exp2f128   |     f128  |    ∅      |     f128  | ..                         |
| ✓ | exp2q      |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | exp2l      |c_longdouble|   ∅      |c_longdouble| ..                        |
| ✓ | __fabsh    |     f16   |    ∅      |     f16   | absolute value of a        |
| ✓ | fabsf      |     f32   |    ∅      |     f32   | ..                         |
| ✓ | fabs       |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __fabsx    |     f80   |    ∅      |     f80   | ..                         |
| ✓ | fabsf128   |     f128  |    ∅      |     f128  | ..                         |
| ✓ | fabsq      |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | fabsl      |c_longdouble|   ∅      |c_longdouble| ..                        |
| ✓ | __floorh   |     f16   |    ∅      |     f16   |largest integer value not greater than a|
| ✓ | floorf     |     f32   |    ∅      |     f32   |If a is integer, +-0, +-NaN, or +-infinite, a itself is returned.|
| ✓ | floor      |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __floorx   |     f80   |    ∅      |     f80   | ..                         |
| ✓ | floorf128  |     f128  |    ∅      |     f128  | ..                         |
| ✓ | floorq     |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | floorl     |c_longdouble|   ∅      |c_longdouble| ..                        |
| ✓ | __fmah     |     f16   |   2xf16   |     f16   | args a,b,c result `(a*b)+c`|
| ✓ | fmaf       |     f32   |   2xf32   |     f32   |Fused multiply-add for hardware acceleration|
| ✓ | fma        |     f64   |   2xf64   |     f64   | ..                         |
| ✓ | __fmax     |     f80   |   2xf80   |     f80   | ..                         |
| ✓ | fmaf128    |     f128  |   2xf128  |     f128  | ..                         |
| ✓ | fmaq       |     f128  |   2xf128  |     f128  | .. PPC                     |
| ✓ | fmal       |c_longdouble|2xc_longdouble|c_longdouble| ..                    |
| ✓ | __fmaxh    |     f16   |     f16   |     f16   | larger value of a,b        |
| ✓ | fmaxf      |     f32   |     f32   |     f32   | ..                         |
| ✓ | fmax       |     f64   |     f64   |     f64   | ..                         |
| ✓ | __fmaxx    |     f80   |     f80   |     f80   | ..                         |
| ✓ | fmaxf128   |     f128  |     f128  |     f128  | ..                         |
| ✓ | fmaxq      |     f128  |     f128  |     f128  | .. PPC                     |
| ✓ | fmaxl      |c_longdouble|c_longdouble|c_longdouble| ..                      |
| ✓ | __fminh    |     f16   |     f16   |     f16   | smaller value of a,b       |
| ✓ | fminf      |     f32   |     f32   |     f32   | ..                         |
| ✓ | fmin       |     f64   |     f64   |     f64   | ..                         |
| ✓ | __fminx    |     f80   |     f80   |     f80   | ..                         |
| ✓ | fminf128   |     f128  |     f128  |     f128  | ..                         |
| ✓ | fminq      |     f128  |     f128  |     f128  | .. PPC                     |
| ✓ | fminl      |c_longdouble|c_longdouble|c_longdouble| ..                      |
| ✓ | __fmodh    |     f16   |     f16   |     f16   |floating-point remainder of division a/b|
| ✓ | fmodf      |     f32   |     f32   |     f32   | ..                         |
| ✓ | fmod       |     f64   |     f64   |     f64   | ..                         |
| ✓ | __fmodx    |     f80   |     f80   |     f80   | ..                         |
| ✓ | fmodf128   |     f128  |     f128  |     f128  | ..                         |
| ✓ | fmodq      |     f128  |     f128  |     f128  | .. PPC                     |
| ✓ | fmodl      |c_longdouble|c_longdouble|c_longdouble| ..                      |
| ✓ | __logh     |     f16   |    ∅      |     f16   |natural (base-e) logarithm of a|
| ✓ | logf       |     f32   |    ∅      |     f32   | ..                         |
| ✓ | log        |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __logx     |     f80   |    ∅      |     f80   | ..                         |
| ✓ | logf128    |     f128  |    ∅      |     f128  | ..                         |
| ✓ | logq       |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | logl       |c_longdouble|   ∅      |c_longdouble| ..                        |
| ✓ | __log10h   |     f16   |    ∅      |     f16   |common (base-10) logarithm of a|
| ✓ | log10f     |     f32   |    ∅      |     f32   | ..                         |
| ✓ | log10      |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __log10x   |     f80   |    ∅      |     f80   | ..                         |
| ✓ | log10f128  |     f128  |    ∅      |     f128  | ..                         |
| ✓ | log10q     |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | log10l     |c_longdouble|   ∅      |c_longdouble| ..                        |
| ✓ | __log2h    |     f16   |    ∅      |     f16   | base-2 logarithm of a      |
| ✓ | log2f      |     f32   |    ∅      |     f32   | ..                         |
| ✓ | log2       |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __log2x    |     f80   |    ∅      |     f80   | ..                         |
| ✓ | log2f128   |     f128  |    ∅      |     f128  | ..                         |
| ✓ | log2q      |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | log2l      |c_longdouble|   ∅      |c_longdouble| ..                        |
| ✓ | __roundh   |     f16   |    ∅      |     f16   | a rounded to next int away from zero|
| ✓ | roundf     |     f32   |    ∅      |     f32   | ..                         |
| ✓ | round      |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __roundx   |     f80   |    ∅      |     f80   | ..                         |
| ✓ | roundf128  |     f128  |    ∅      |     f128  | ..                         |
| ✓ | roundq     |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | roundl     |c_longdouble|   ∅      |c_longdouble| ..                        |
| ✓ | __sinh     |     f16   |    ∅      |     f16   | `sin(a)=(e^(ia)-e^(-ia))/2`|
| ✓ | sinf       |     f32   |    ∅      |     f32   | ..                         |
| ✓ | sin        |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __sinx     |     f80   |    ∅      |     f80   | ..                         |
| ✓ | sinf128    |     f128  |    ∅      |     f128  | ..                         |
| ✓ | sinq       |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | sinl       |c_longdouble|   ∅      |c_longdouble| ..                        |
| ✓ | __sincosh  |     f16   | 2x *f16   |     ∅     |sin and cos of the same angle a|
| ✓ | sincosf    |     f32   | 2x *f32   |     ∅     |args a,*b,*c, `b.*=sin(x),c.*=cos(x)`|
| ✓ | sincos     |     f64   | 2x *f64   |     ∅     | ..                         |
| ✓ | __sincosx  |     f80   | 2x *f80   |     ∅     | ..                         |
| ✓ | sincosf128 |     f128  | 2x *f128  |     ∅     | ..                         |
| ✓ | sincosq    |     f128  | 2x *f128  |     ∅     | .. PPC                     |
| ✓ | sincosl    |c_longdouble| 2x *c_longdouble|∅     | ..                       |
| ✓ | __sqrth    |     f16   |    ∅      |     f16   | square root of a (find `r st. a=r^2`)|
| ✓ | sqrtf      |     f32   |    ∅      |     f32   | ..                         |
| ✓ | sqrt       |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __sqrtx    |     f80   |    ∅      |     f80   | ..                         |
| ✓ | sqrtf128   |     f128  |    ∅      |     f128  | ..                         |
| ✓ | sqrtq      |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | sqrtl      |c_longdouble|   ∅      |c_longdouble| ..                        |
| ✓ | __tanh     |     f16   |    ∅      |     f16   | `tan(x)=sin(x)/cos(x)      |
| ✓ | tanf       |     f32   |    ∅      |     f32   | ..                         |
| ✓ | tan        |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __tanx     |     f80   |    ∅      |     f80   | ..                         |
| ✓ | tanf128    |     f128  |    ∅      |     f128  | ..                         |
| ✓ | tanq       |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | tanl       |c_longdouble|   ∅      |c_longdouble| ..                        |
| ✓ | __trunch   |     f16   |    ∅      |     f16   | a rounded to next int towards zero|
| ✓ | truncf     |     f32   |    ∅      |     f32   | ..                         |
| ✓ | trunc      |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __truncx   |     f80   |    ∅      |     f80   | ..                         |
| ✓ | truncf128  |     f128  |    ∅      |     f128  | ..                         |
| ✓ | truncq     |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | truncl     |c_longdouble|   ∅      |c_longdouble| ..                        |

Arbitrary Precision Big Integer (BigInt) library routines

TODO brief description

| Done | Name    | result| a     | b     | size| ret   | Comment               |
| ---- | ------- | ----- | ----- | ----- | --- | ----- |---------------------- |
| |              |       |       |       |     |       |**BigInt Bit Operation**|
| |              |       |       |       |     |       |**BigInt Comparison**   |
| |              |       |       |       |     |       |**BigInt Arithmetic**   |
|✓|__udivei4     |[*c]u32|[*c]u32|[*c]u32|usize|void   | `a / b`               |
|✓|__umodei4     |[*c]u32|[*c]u32|[*c]u32|usize|void   | `a % b`               |
|✗|__divei4      |[*c]u32|[*c]u32|[*c]u32|usize|void   | `a / b`               |
|✗|__modei4      |[*c]u32|[*c]u32|[*c]u32|usize|void   | `a % b`               |
| |              |       |       |       |     |       |**BigInt Arithmetic with Trapping Overflow**|
| |              |       |       |       |     |       |**BigInt Arithmetic which Return on Overflow**[^noptr_faster]|

Further content (conditionally) exported with C abi:

ARM-only routines

| Done | Name      | a   | b   | Out  | Comment               |
| ---- | --------  | --- | --- | -----| ----------------------|
| |                |     |     |      | **Float Comparison**  |
|✗|__aeabi_cfcmpeq | f32 | f32 | void | `a == b` result in PSR ZC flags[^PSRZC] |
|✗|__aeabi_cfcmple | f32 | f32 | void | `a <= b` result ..    |
|✗|__aeabi_cfrcmple| f32 | f32 | void | `b <= a` ..           |
|✗|__aeabi_cdcmpeq | f64 | f64 | void | `a == b` ..           |
|✗|__aeabi_cdcmple | f64 | f64 | void | `a <= b` ..           |
|✗|__aeabi_cdrcmple| f64 | f64 | void | `b <= a` ..           |
| |                |     |     |      | **Float Arithmetic**  |
|✗|__aeabi_frsub   | f64 | f64 | f64  | `b - a`               |
|✗|__aeabi_drsub   | f64 | f64 | f64  | ..                    |
| |                |     |     |      | **Special**           |
|✓|__aeabi_read_tp |  ∅  |  ∅  | *u8  | ret tls pointer       |
|✗|__aeabi_idiv0   | i32 |  ∅  | i32  | div by 0 modifier     |
|✗|__aeabi_ldiv0   | i64 |  ∅  | i64  | div by 0 modifier     |
| |                |     |     |      | **Unaligned memory access** |
|✗|__aeabi_uread4  |[*]u8|  ∅  | i32  | ret value read        |
|✗|__aeabi_uwrite4 | i32 |[*]u8| i32  | ret value written     |
|✗|__aeabi_uread8  |[*]u8|  ∅  | i64  | ..                    |
|✗|__aeabi_uwrite8 | i64 |[*]u8| i64  | ..                    |


| Done | Name      | a   | b   | c  | Comment                 |
| ---- | --------  | --- | --- | -----| ----------------------|
| |                |     |     |      | **Memory copy, move and set** |
|✓|__aeabi_memcpy8 |[*]u8|[*]u8| usize| *dest, *src, size     |
|✓|__aeabi_memcpy4 |[*]u8|[*]u8| usize| ..                    |
|✓|__aeabi_memcpy  |[*]u8|[*]u8| usize| ..                    |
|✓|__aeabi_memmove8|[*]u8|[*]u8| usize| *dest, *src, size     |
|✓|__aeabi_memmove4|[*]u8|[*]u8| usize| ..                    |
|✓|__aeabi_memmove |[*]u8|[*]u8| usize| ..                    |
|✓|__aeabi_memset8 |[*]u8|usize| i32  | *dest, size, char     |
|✓|__aeabi_memset4 |[*]u8|usize| i32  | ..                    |
|✓|__aeabi_memset  |[*]u8|usize| i32  | ..                    |
|✓|__aeabi_memclr8 |[*]u8| u32 | usize| *dest, size           |
|✓|__aeabi_memclr4 |[*]u8| u32 | usize| ..                    |
|✓|__aeabi_memclr  |[*]u8| u32 | usize| ..                    |
|✓|__aeabi_uwrite8 | i64 |[*]u8| i64  | ..                    |

- __aeabi_read_tp

[^PSRZC]: return result in the CPSR Z and C flag. C is clear only if the
operands are ordered and the first operand is less than the second.
Z is set only when the operands are ordered and equal.
Preserves all core registers except ip, lr, and the CPSR.

- aarch64 outline atomics
- atomics
- bcmp
- clear cache
- memory routines (memcmp, memcpy, memset, memmove)
- msvc things like _alldiv, _aulldiv, _allrem
- objective-c __isPlatformVersionAtLeast check
- stack probe routines
- tls emulation
