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
| ✓ | __cmpti2           | i128 | i128 | i32  | ..                             |
| ✓ | __ucmpsi2          | u32  | u32  | i32  | `(a<b) -> 0, (a==b) -> 1, (a>b) -> 2` |
| ✓ | __ucmpdi2          | u64  | u64  | i32  | ..                             |
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
| ✓ | __udivmoddi4       | u64  | u64  | u64  | ..                             |
| ✓ | __udivmodti4       | u128 | u128 | u128 | ..                             |
| ✓ | __divmodsi4        | i32  | i32  | i32  | `a / b, rem.* = a % b`         |
| ✓ | __divmoddi4        | i64  | i64  | i64  | ..                             |
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
| ✓ | __extendsfdf2      | f32  | ∅    | f64  | ..                             |
| ✓ | __extendsftf2      | f32  | ∅    | f128 | ..                             |
| ✓ | __extendsfxf2      | f32  | ∅    | f80  | ..                             |
| ✓ | __extenddftf2      | f64  | ∅    | f128 | ..                             |
| ✓ | __extenddfxf2      | f64  | ∅    | f80  | ..                             |
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
| ✓ | __aeabi_f2h        | f32  | ∅    | f16  | .. ARM                         |
| ✓ | __gnu_f2h_ieee     | f32  | ∅    | f16  | ..GNU naming convention        |
| ✓ | __aeabi_d2h        | f64  | ∅    | f16  | .. ARM                         |
| ✓ | __aeabi_d2f        | f64  | ∅    | f32  | .. ARM                         |
| ✓ | __trunckfsf2       | f128 | ∅    | f32  | .. PPC                         |
| ✓ | _Qp_qtos           |*f128 | ∅    | f32  | .. SPARC                       |
| ✓ | __trunckfdf2       | f128 | ∅    | f64  | .. PPC                         |
| ✓ | _Qp_qtod           |*f128 | ∅    | f64  | .. SPARC                       |
| ✓ | __fixhfsi          | f16  | ∅    | i32  | float to int, rounding towards zero |
| ✓ | __fixsfsi          | f32  | ∅    | i32  | ..                             |
| ✓ | __fixdfsi          | f64  | ∅    | i32  | ..                             |
| ✓ | __fixtfsi          | f128 | ∅    | i32  | ..                             |
| ✓ | __fixxfsi          | f80  | ∅    | i32  | ..                             |
| ✓ | __fixhfdi          | f16  | ∅    | i64  | ..                             |
| ✓ | __fixsfdi          | f32  | ∅    | i64  | ..                             |
| ✓ | __fixdfdi          | f64  | ∅    | i64  | ..                             |
| ✓ | __fixtfdi          | f128 | ∅    | i64  | ..                             |
| ✓ | __fixxfdi          | f80  | ∅    | i64  | ..                             |
| ✓ | __fixhfti          | f16  | ∅    | i128 | ..                             |
| ✓ | __fixsfti          | f32  | ∅    | i128 | ..                             |
| ✓ | __fixdfti          | f64  | ∅    | i128 | ..                             |
| ✓ | __fixtfti          | f128 | ∅    | i128 | ..                             |
| ✓ | __fixxfti          | f80  | ∅    | i128 | ..                             |
| ✓ | __fixunshfsi       | f16  | ∅    | u32  | float to uint, rounding towards zero. negative values become 0. |
| ✓ | __fixunssfsi       | f32  | ∅    | u32  | ..                             |
| ✓ | __fixunsdfsi       | f64  | ∅    | u32  | ..                             |
| ✓ | __fixunstfsi       | f128 | ∅    | u32  | ..                             |
| ✓ | __fixunsxfsi       | f80  | ∅    | u32  | ..                             |
| ✓ | __fixunshfdi       | f16  | ∅    | u64  | ..                             |
| ✓ | __fixunssfdi       | f32  | ∅    | u64  | ..                             |
| ✓ | __fixunsdfdi       | f64  | ∅    | u64  | ..                             |
| ✓ | __fixunstfdi       | f128 | ∅    | u64  | ..                             |
| ✓ | __fixunsxfdi       | f80  | ∅    | u64  | ..                             |
| ✓ | __fixunshfti       | f16  | ∅    | u128 | ..                             |
| ✓ | __fixunssfti       | f32  | ∅    | u128 | ..                             |
| ✓ | __fixunsdfti       | f64  | ∅    | u128 | ..                             |
| ✓ | __fixunstfti       | f128 | ∅    | u128 | ..                             |
| ✓ | __fixunsxfti       | f80  | ∅    | u128 | ..                             |
| ✓ | __floatsihf        | i32  | ∅    | f16  | int to float                   |
| ✓ | __floatsisf        | i32  | ∅    | f32  | ..                             |
| ✓ | __floatsidf        | i32  | ∅    | f64  | ..                             |
| ✓ | __floatsitf        | i32  | ∅    | f128 | ..                             |
| ✓ | __floatsixf        | i32  | ∅    | f80  | ..                             |
| ✓ | __floatdisf        | i64  | ∅    | f32  | ..                             |
| ✓ | __floatdidf        | i64  | ∅    | f64  | ..                             |
| ✓ | __floatditf        | i64  | ∅    | f128 | ..                             |
| ✓ | __floatdixf        | i64  | ∅    | f80  | ..                             |
| ✓ | __floattihf        | i128 | ∅    | f16  | ..                             |
| ✓ | __floattisf        | i128 | ∅    | f32  | ..                             |
| ✓ | __floattidf        | i128 | ∅    | f64  | ..                             |
| ✓ | __floattitf        | i128 | ∅    | f128 | ..                             |
| ✓ | __floattixf        | i128 | ∅    | f80  | ..                             |
| ✓ | __floatunsihf      | u32  | ∅    | f16  | uint to float                  |
| ✓ | __floatunsisf      | u32  | ∅    | f32  | ..                             |
| ✓ | __floatunsidf      | u32  | ∅    | f64  | ..                             |
| ✓ | __floatunsitf      | u32  | ∅    | f128 | ..                             |
| ✓ | __floatunsixf      | u32  | ∅    | f80  | ..                             |
| ✓ | __floatundihf      | u64  | ∅    | f16  | ..                             |
| ✓ | __floatundisf      | u64  | ∅    | f32  | ..                             |
| ✓ | __floatundidf      | u64  | ∅    | f64  | ..                             |
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

Decimal float library routines

BID means Binary Integer Decimal encoding, DPD means Densely Packed Decimal encoding.
BID should be only chosen for binary data, DPD for decimal data (ASCII, Unicode etc).
For example the number 0.2 is not accurately representable in binary data.

| Done   | Name          | a           | b         | Out       | Comment                      |
| ------ | ------------- | ---------   | --------- | --------- | ---------------------------- |
|   |                    |             |           |           | **Decimal Float Conversion** |
| ✗ | __dpd_extendsddd2  |     dec32   | ∅         |     dec64 | conversion                   |
| ✗ | __bid_extendsddd2  |     dec32   | ∅         |     dec64 | ..                           |
| ✗ | __dpd_extendsdtd2  |     dec32   | ∅         |     dec128| ..                           |
| ✗ | __bid_extendsdtd2  |     dec32   | ∅         |     dec128| ..                           |
| ✗ | __dpd_extendddtd2  |     dec64   | ∅         |     dec128| ..                           |
| ✗ | __bid_extendddtd2  |     dec64   | ∅         |     dec128| ..                           |
| ✗ | __dpd_truncddsd2   |     dec64   | ∅         |     dec32 | ..                           |
| ✗ | __bid_truncddsd2   |     dec64   | ∅         |     dec32 | ..                           |
| ✗ | __dpd_trunctdsd2   |     dec128  | ∅         |     dec32 | ..                           |
| ✗ | __bid_trunctdsd2   |     dec128  | ∅         |     dec32 | ..                           |
| ✗ | __dpd_trunctddd2   |     dec128  | ∅         |     dec64 | ..                           |
| ✗ | __bid_trunctddd2   |     dec128  | ∅         |     dec64 | ..                           |
| ✗ | __dpd_extendsfdd   |     float   | ∅         |     dec64 | ..                           |
| ✗ | __bid_extendsfdd   |     float   | ∅         |     dec64 | ..                           |
| ✗ | __dpd_extendsftd   |     float   | ∅         |     dec128| ..                           |
| ✗ | __bid_extendsftd   |     float   | ∅         |     dec128| ..                           |
| ✗ | __dpd_extenddftd   |     double  | ∅         |     dec128| ..                           |
| ✗ | __bid_extenddftd   |     double  | ∅         |     dec128| ..                           |
| ✗ | __dpd_extendxftd   |long double  | ∅         |     dec128| ..                           |
| ✗ | __bid_extendxftd   |long double  | ∅         |     dec128| ..                           |
| ✗ | __dpd_truncdfsd    |     double  | ∅         |     dec32 | ..                           |
| ✗ | __bid_truncdfsd    |     double  | ∅         |     dec32 | ..                           |
| ✗ | __dpd_truncxfsd    |long double  | ∅         |     dec32 | ..                           |
| ✗ | __bid_truncxfsd    |long double  | ∅         |     dec32 | ..                           |
| ✗ | __dpd_trunctfsd    |long double  | ∅         |     dec32 | ..                           |
| ✗ | __bid_trunctfsd    |long double  | ∅         |     dec32 | ..                           |
| ✗ | __dpd_truncxfdd    |long double  | ∅         |     dec64 | ..                           |
| ✗ | __bid_truncxfdd    |long double  | ∅         |     dec64 | ..                           |
| ✗ | __dpd_trunctfdd    |long double  | ∅         |     dec64 | ..                           |
| ✗ | __bid_trunctfdd    |long double  | ∅         |     dec64 | ..                           |
| ✗ | __dpd_truncddsf    |     dec64   | ∅         |     float | ..                           |
| ✗ | __bid_truncddsf    |     dec64   | ∅         |     float | ..                           |
| ✗ | __dpd_trunctdsf    |     dec128  | ∅         |     float | ..                           |
| ✗ | __bid_trunctdsf    |     dec128  | ∅         |     float | ..                           |
| ✗ | __dpd_extendsddf   |     dec32   | ∅         |     double| ..                           |
| ✗ | __bid_extendsddf   |     dec32   | ∅         |     double| ..                           |
| ✗ | __dpd_trunctddf    |     dec128  | ∅         |     double| ..                           |
| ✗ | __bid_trunctddf    |     dec128  | ∅         |     double| ..                           |
| ✗ | __dpd_extendsdxf   |     dec32   | ∅         |long double| ..                           |
| ✗ | __bid_extendsdxf   |     dec32   | ∅         |long double| ..                           |
| ✗ | __dpd_extendddxf   |     dec64   | ∅         |long double| ..                           |
| ✗ | __bid_extendddxf   |     dec64   | ∅         |long double| ..                           |
| ✗ | __dpd_trunctdxf    |     dec128  | ∅         |long double| ..                           |
| ✗ | __bid_trunctdxf    |     dec128  | ∅         |long double| ..                           |
| ✗ | __dpd_extendsdtf   |     dec32   | ∅         |long double| ..                           |
| ✗ | __bid_extendsdtf   |     dec32   | ∅         |long double| ..                           |
| ✗ | __dpd_extendddtf   |     dec64   | ∅         |long double| ..                           |
| ✗ | __bid_extendddtf   |     dec64   | ∅         |long double| ..                           |
| ✗ | __dpd_extendsfsd   |     float   | ∅         |     dec32 | same size conversions        |
| ✗ | __bid_extendsfsd   |     float   | ∅         |     dec32 | ..                           |
| ✗ | __dpd_extenddfdd   |     double  | ∅         |     dec64 | ..                           |
| ✗ | __bid_extenddfdd   |     double  | ∅         |     dec64 | ..                           |
| ✗ | __dpd_extendtftd   |long double  | ∅         |     dec128| ..                           |
| ✗ | __bid_extendtftd   |long double  | ∅         |     dec128| ..                           |
| ✗ | __dpd_truncsdsf    |     dec32   | ∅         |     float | ..                           |
| ✗ | __bid_truncsdsf    |     dec32   | ∅         |     float | ..                           |
| ✗ | __dpd_truncdddf    |     dec64   | ∅         |     float | conversion                   |
| ✗ | __bid_truncdddf    |     dec64   | ∅         |     float | ..                           |
| ✗ | __dpd_trunctdtf    |     dec128  | ∅         |long double| ..                           |
| ✗ | __bid_trunctdtf    |     dec128  | ∅         |long double| ..                           |
| ✗ | __dpd_fixsdsi      |     dec32   | ∅         |     int   | ..                           |
| ✗ | __bid_fixsdsi      |     dec32   | ∅         |     int   | ..                           |
| ✗ | __dpd_fixddsi      |     dec64   | ∅         |     int   | ..                           |
| ✗ | __bid_fixddsi      |     dec64   | ∅         |     int   | ..                           |
| ✗ | __dpd_fixtdsi      |     dec128  | ∅         |     int   | ..                           |
| ✗ | __bid_fixtdsi      |     dec128  | ∅         |     int   | ..                           |
| ✗ | __dpd_fixsddi      |     dec32   | ∅         |     long  | ..                           |
| ✗ | __bid_fixsddi      |     dec32   | ∅         |     long  | ..                           |
| ✗ | __dpd_fixdddi      |     dec64   | ∅         |     long  | ..                           |
| ✗ | __bid_fixdddi      |     dec64   | ∅         |     long  | ..                           |
| ✗ | __dpd_fixtddi      |     dec128  | ∅         |     long  | ..                           |
| ✗ | __bid_fixtddi      |     dec128  | ∅         |     long  | ..                           |
| ✗ | __dpd_fixunssdsi   |     dec32   | ∅         |unsigned int | .. All negative values become zero. |
| ✗ | __bid_fixunssdsi   |     dec32   | ∅         |unsigned int | ..                         |
| ✗ | __dpd_fixunsddsi   |     dec64   | ∅         |unsigned int | ..                         |
| ✗ | __bid_fixunsddsi   |     dec64   | ∅         |unsigned int | ..                         |
| ✗ | __dpd_fixunstdsi   |     dec128  | ∅         |unsigned int | ..                         |
| ✗ | __bid_fixunstdsi   |     dec128  | ∅         |unsigned int | ..                         |
| ✗ | __dpd_fixunssddi   |     dec32   | ∅         |unsigned long| ..                         |
| ✗ | __bid_fixunssddi   |     dec32   | ∅         |unsigned long| ..                         |
| ✗ | __dpd_fixunsdddi   |     dec64   | ∅         |unsigned long| ..                         |
| ✗ | __bid_fixunsdddi   |     dec64   | ∅         |unsigned long| ..                         |
| ✗ | __dpd_fixunstddi   |     dec128  | ∅         |unsigned long| ..                         |
| ✗ | __bid_fixunstddi   |     dec128  | ∅         |unsigned long| ..                         |
| ✗ | __dpd_floatsisd    |     int     | ∅         |     dec32   | ..                         |
| ✗ | __bid_floatsisd    |     int     | ∅         |     dec32   | ..                         |
| ✗ | __dpd_floatsidd    |     int     | ∅         |     dec64   | ..                         |
| ✗ | __bid_floatsidd    |     int     | ∅         |     dec64   | ..                         |
| ✗ | __dpd_floatsitd    |     int     | ∅         |     dec128  | ..                         |
| ✗ | __bid_floatsitd    |     int     | ∅         |     dec128  | ..                         |
| ✗ | __dpd_floatdisd    |     long    | ∅         |     dec32   | ..                         |
| ✗ | __bid_floatdisd    |     long    | ∅         |     dec32   | ..                         |
| ✗ | __dpd_floatdidd    |     long    | ∅         |     dec64   | ..                         |
| ✗ | __bid_floatdidd    |     long    | ∅         |     dec64   | ..                         |
| ✗ | __dpd_floatditd    |     long    | ∅         |     dec128  | ..                         |
| ✗ | __bid_floatditd    |     long    | ∅         |     dec128  | ..                         |
| ✗ | __dpd_floatunssisd | unsigned int| ∅         |     dec32   | ..                         |
| ✗ | __bid_floatunssisd | unsigned int| ∅         |     dec32   | ..                         |
| ✗ | __dpd_floatunssidd | unsigned int| ∅         |     dec64   | ..                         |
| ✗ | __bid_floatunssidd | unsigned int| ∅         |     dec64   | ..                         |
| ✗ | __dpd_floatunssitd | unsigned int| ∅         |     dec128  | ..                         |
| ✗ | __bid_floatunssitd | unsigned int| ∅         |     dec128  | ..                         |
| ✗ | __dpd_floatunsdisd |unsigned long| ∅         |     dec32   | ..                         |
| ✗ | __bid_floatunsdisd |unsigned long| ∅         |     dec32   | ..                         |
| ✗ | __dpd_floatunsdidd |unsigned long| ∅         |     dec64   | ..                         |
| ✗ | __bid_floatunsdidd |unsigned long| ∅         |     dec64   | ..                         |
| ✗ | __dpd_floatunsditd |unsigned long| ∅         |     dec128  | ..                         |
| ✗ | __bid_floatunsditd |unsigned long| ∅         |     dec128  | ..                         |
|   |                |        |        |        | **Decimal Float Comparison**                            |
| ✗ | __dpd_unordsd2 | dec32  | dec32  | c_int  | `a +-NaN or a +-NaN -> 1(nonzero), else -> 0`           |
| ✗ | __bid_unordsd2 | dec32  | dec32  | c_int  | ..                                                      |
| ✗ | __dpd_unorddd2 | dec64  | dec64  | c_int  | ..                                                      |
| ✗ | __bid_unorddd2 | dec64  | dec64  | c_int  | ..                                                      |
| ✗ | __dpd_unordtd2 | dec128 | dec128 | c_int  | ..                                                      |
| ✗ | __bid_unordtd2 | dec128 | dec128 | c_int  | ..                                                      |
| ✗ | __dpd_eqsd2    | dec32  | dec32  | c_int  |`a!=+-NaN and b!=+-Nan and a==b -> 0, else -> 1(nonzero)`|
| ✗ | __bid_eqsd2    | dec32  | dec32  | c_int  | ..                                                      |
| ✗ | __dpd_eqdd2    | dec64  | dec64  | c_int  | ..                                                      |
| ✗ | __bid_eqdd2    | dec64  | dec64  | c_int  | ..                                                      |
| ✗ | __dpd_eqtd2    | dec128 | dec128 | c_int  | ..                                                      |
| ✗ | __bid_eqtd2    | dec128 | dec128 | c_int  | ..                                                      |
| ✗ | __dpd_nesd2    | dec32  | dec32  | c_int  | `a==+-NaN or b==+-NaN or a!=b -> 1(nonzero), else -> 0` |
| ✗ | __bid_nesd2    | dec32  | dec32  | c_int  | ..                                                      |
| ✗ | __dpd_nedd2    | dec64  | dec64  | c_int  | ..                                                      |
| ✗ | __bid_nedd2    | dec64  | dec64  | c_int  | ..                                                      |
| ✗ | __dpd_netd2    | dec128 | dec128 | c_int  | ..                                                      |
| ✗ | __bid_netd2    | dec128 | dec128 | c_int  | ..                                                      |
| ✗ | __dpd_gesd2    | dec32  | dec32  | c_int  | `a!=+-NaN and b!=+-NaN and a>=b -> >=0, else -> <0`     |
| ✗ | __bid_gesd2    | dec32  | dec32  | c_int  | ..                                                      |
| ✗ | __dpd_gedd2    | dec64  | dec64  | c_int  | ..                                                      |
| ✗ | __bid_gedd2    | dec64  | dec64  | c_int  | ..                                                      |
| ✗ | __dpd_getd2    | dec128 | dec128 | c_int  | ..                                                      |
| ✗ | __bid_getd2    | dec128 | dec128 | c_int  | ..                                                      |
| ✗ | __dpd_ltsd2    | dec32  | dec32  | c_int  | `a!=+-NaN and b!=+-NaN and a<b -> <0, else -> >=0`      |
| ✗ | __bid_ltsd2    | dec32  | dec32  | c_int  | ..                                                      |
| ✗ | __dpd_ltdd2    | dec64  | dec64  | c_int  | ..                                                      |
| ✗ | __bid_ltdd2    | dec64  | dec64  | c_int  | ..                                                      |
| ✗ | __dpd_lttd2    | dec128 | dec128 | c_int  | ..                                                      |
| ✗ | __bid_lttd2    | dec128 | dec128 | c_int  | ..                                                      |
| ✗ | __dpd_lesd2    | dec32  | dec32  | c_int  | `a!=+-NaN and b!=+-NaN and a<=b -> <=0, else -> >=0`    |
| ✗ | __bid_lesd2    | dec32  | dec32  | c_int  | ..                                                      |
| ✗ | __dpd_ledd2    | dec64  | dec64  | c_int  | ..                                                      |
| ✗ | __bid_ledd2    | dec64  | dec64  | c_int  | ..                                                      |
| ✗ | __dpd_letd2    | dec128 | dec128 | c_int  | ..                                                      |
| ✗ | __bid_letd2    | dec128 | dec128 | c_int  | ..                                                      |
| ✗ | __dpd_gtsd2    | dec32  | dec32  | c_int  | `a!=+-NaN and b!=+-NaN and a>b -> >0, else -> <=0`      |
| ✗ | __bid_gtsd2    | dec32  | dec32  | c_int  | ..                                                      |
| ✗ | __dpd_gtdd2    | dec64  | dec64  | c_int  | ..                                                      |
| ✗ | __bid_gtdd2    | dec64  | dec64  | c_int  | ..                                                      |
| ✗ | __dpd_gttd2    | dec128 | dec128 | c_int  | ..                                                      |
| ✗ | __bid_gttd2    | dec128 | dec128 | c_int  | ..                                                      |
|   |                |        |        |        | **Decimal Float Arithmetic**[^options] |
| ✗ | __dpd_addsd3   | dec32  | dec32  | dec32  |`a + b`|
| ✗ | __bid_addsd3   | dec32  | dec32  | dec32  | ..    |
| ✗ | __dpd_adddd3   | dec64  | dec64  | dec64  | ..    |
| ✗ | __bid_adddd3   | dec64  | dec64  | dec64  | ..    |
| ✗ | __dpd_addtd3   | dec128 | dec128 | dec128 | ..    |
| ✗ | __bid_addtd3   | dec128 | dec128 | dec128 | ..    |
| ✗ | __dpd_subsd3   | dec32  | dec32  | dec32  |`a - b`|
| ✗ | __bid_subsd3   | dec32  | dec32  | dec32  | ..    |
| ✗ | __dpd_subdd3   | dec64  | dec64  | dec64  | ..    |
| ✗ | __bid_subdd3   | dec64  | dec64  | dec64  | ..    |
| ✗ | __dpd_subtd3   | dec128 | dec128 | dec128 | ..    |
| ✗ | __bid_subtd3   | dec128 | dec128 | dec128 | ..    |
| ✗ | __dpd_mulsd3   | dec32  | dec32  | dec32  |`a * b`|
| ✗ | __bid_mulsd3   | dec32  | dec32  | dec32  | ..    |
| ✗ | __dpd_muldd3   | dec64  | dec64  | dec64  | ..    |
| ✗ | __bid_muldd3   | dec64  | dec64  | dec64  | ..    |
| ✗ | __dpd_multd3   | dec128 | dec128 | dec128 | ..    |
| ✗ | __bid_multd3   | dec128 | dec128 | dec128 | ..    |
| ✗ | __dpd_divsd3   | dec32  | dec32  | dec32  |`a / b`|
| ✗ | __bid_divsd3   | dec32  | dec32  | dec32  | ..    |
| ✗ | __dpd_divdd3   | dec64  | dec64  | dec64  | ..    |
| ✗ | __bid_divdd3   | dec64  | dec64  | dec64  | ..    |
| ✗ | __dpd_divtd3   | dec128 | dec128 | dec128 | ..    |
| ✗ | __bid_divtd3   | dec128 | dec128 | dec128 | ..    |
| ✗ | __dpd_negsd2   | dec32  | dec32  | dec32  | `-a`  |
| ✗ | __bid_negsd2   | dec32  | dec32  | dec32  | ..    |
| ✗ | __dpd_negdd2   | dec64  | dec64  | dec64  | ..    |
| ✗ | __bid_negdd2   | dec64  | dec64  | dec64  | ..    |
| ✗ | __dpd_negtd2   | dec128 | dec128 | dec128 | ..    |
| ✗ | __bid_negtd2   | dec128 | dec128 | dec128 | ..    |

[^options]: These numbers include options with routines for +-0 and +-Nan.

Fixed-point fractional library routines

TODO brief explanation + implementation

| Done   | Name          | a           | b         | Out       | Comment                    |
| ------ | ------------- | ---------   | --------- | --------- | -------------------------- |
|        |               |             |           |           | **Fixed-Point Fractional** |

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
| ✓ | ceill      |long double|    ∅      |long double| ..                         |
| ✓ | __cosh     |     f16   |    ∅      |     f16   | `cos(a)=(e^(ia)+e^(-ia))/2`|
| ✓ | cosf       |     f32   |    ∅      |     f32   | ..                         |
| ✓ | cos        |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __cosx     |     f80   |    ∅      |     f80   | ..                         |
| ✓ | cosf128    |     f128  |    ∅      |     f128  | ..                         |
| ✓ | cosq       |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | cosl       |long double|    ∅      |long double| ..                         |
| ✓ | __exph     |     f16   |    ∅      |     f16   | `e^a` with e base of natural logarithms|
| ✓ | expf       |     f32   |    ∅      |     f32   | ..                         |
| ✓ | exp        |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __expx     |     f80   |    ∅      |     f80   | ..                         |
| ✓ | expf128    |     f128  |    ∅      |     f128  | ..                         |
| ✓ | expq       |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | expl       |long double|    ∅      |long double| ..                         |
| ✓ | __exp2h    |     f16   |    ∅      |     f16   | `2^a`                      |
| ✓ | exp2f      |     f32   |    ∅      |     f32   | ..                         |
| ✓ | exp2       |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __exp2x    |     f80   |    ∅      |     f80   | ..                         |
| ✓ | exp2f128   |     f128  |    ∅      |     f128  | ..                         |
| ✓ | exp2q      |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | exp2l      |long double|    ∅      |long double| ..                         |
| ✓ | __fabsh    |     f16   |    ∅      |     f16   | absolute value of a        |
| ✓ | fabsf      |     f32   |    ∅      |     f32   | ..                         |
| ✓ | fabs       |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __fabsx    |     f80   |    ∅      |     f80   | ..                         |
| ✓ | fabsf128   |     f128  |    ∅      |     f128  | ..                         |
| ✓ | fabsq      |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | fabsl      |long double|    ∅      |long double| ..                         |
| ✓ | __floorh   |     f16   |    ∅      |     f16   |largest integer value not greater than a|
| ✓ | floorf     |     f32   |    ∅      |     f32   |If a is integer, +-0, +-NaN, or +-infinite, a itself is returned.|
| ✓ | floor      |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __floorx   |     f80   |    ∅      |     f80   | ..                         |
| ✓ | floorf128  |     f128  |    ∅      |     f128  | ..                         |
| ✓ | floorq     |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | floorl     |long double|    ∅      |long double| ..                         |
| ✓ | __fmah     |     f16   |   2xf16   |     f16   | args a,b,c result `(a*b)+c`|
| ✓ | fmaf       |     f32   |   2xf32   |     f32   |Fused multiply-add for hardware acceleration|
| ✓ | fma        |     f64   |   2xf64   |     f64   | ..                         |
| ✓ | __fmax     |     f80   |   2xf80   |     f80   | ..                         |
| ✓ | fmaf128    |     f128  |   2xf128  |     f128  | ..                         |
| ✓ | fmaq       |     f128  |   2xf128  |     f128  | .. PPC                     |
| ✓ | fmal       |long double|2xlong double|long double| ..                         |
| ✓ | __fmaxh    |     f16   |     f16   |     f16   | larger value of a,b        |
| ✓ | fmaxf      |     f32   |     f32   |     f32   | ..                         |
| ✓ | fmax       |     f64   |     f64   |     f64   | ..                         |
| ✓ | __fmaxx    |     f80   |     f80   |     f80   | ..                         |
| ✓ | fmaxf128   |     f128  |     f128  |     f128  | ..                         |
| ✓ | fmaxq      |     f128  |     f128  |     f128  | .. PPC                     |
| ✓ | fmaxl      |long double|long double|long double| ..                         |
| ✓ | __fminh    |     f16   |     f16   |     f16   | smaller value of a,b       |
| ✓ | fminf      |     f32   |     f32   |     f32   | ..                         |
| ✓ | fmin       |     f64   |     f64   |     f64   | ..                         |
| ✓ | __fminx    |     f80   |     f80   |     f80   | ..                         |
| ✓ | fminf128   |     f128  |     f128  |     f128  | ..                         |
| ✓ | fminq      |     f128  |     f128  |     f128  | .. PPC                     |
| ✓ | fminl      |long double|long double|long double| ..                         |
| ✓ | __fmodh    |     f16   |     f16   |     f16   |floating-point remainder of division a/b|
| ✓ | fmodf      |     f32   |     f32   |     f32   | ..                         |
| ✓ | fmod       |     f64   |     f64   |     f64   | ..                         |
| ✓ | __fmodx    |     f80   |     f80   |     f80   | ..                         |
| ✓ | fmodf128   |     f128  |     f128  |     f128  | ..                         |
| ✓ | fmodq      |     f128  |     f128  |     f128  | .. PPC                     |
| ✓ | fmodl      |long double|long double|long double| ..                         |
| ✓ | __logh     |     f16   |    ∅      |     f16   |natural (base-e) logarithm of a|
| ✓ | logf       |     f32   |    ∅      |     f32   | ..                         |
| ✓ | log        |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __logx     |     f80   |    ∅      |     f80   | ..                         |
| ✓ | logf128    |     f128  |    ∅      |     f128  | ..                         |
| ✓ | logq       |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | logl       |long double|    ∅      |long double| ..                         |
| ✓ | __log10h   |     f16   |    ∅      |     f16   |common (base-10) logarithm of a|
| ✓ | log10f     |     f32   |    ∅      |     f32   | ..                         |
| ✓ | log10      |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __log10x   |     f80   |    ∅      |     f80   | ..                         |
| ✓ | log10f128  |     f128  |    ∅      |     f128  | ..                         |
| ✓ | log10q     |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | log10l     |long double|    ∅      |long double| ..                         |
| ✓ | __log2h    |     f16   |    ∅      |     f16   | base-2 logarithm of a      |
| ✓ | log2f      |     f32   |    ∅      |     f32   | ..                         |
| ✓ | log2       |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __log2x    |     f80   |    ∅      |     f80   | ..                         |
| ✓ | log2f128   |     f128  |    ∅      |     f128  | ..                         |
| ✓ | log2q      |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | log2l      |long double|    ∅      |long double| ..                         |
| ✓ | __roundh   |     f16   |    ∅      |     f16   | a rounded to next int away from zero|
| ✓ | roundf     |     f32   |    ∅      |     f32   | ..                         |
| ✓ | round      |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __roundx   |     f80   |    ∅      |     f80   | ..                         |
| ✓ | roundf128  |     f128  |    ∅      |     f128  | ..                         |
| ✓ | roundq     |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | roundl     |long double|    ∅      |long double| ..                         |
| ✓ | __sinh     |     f16   |    ∅      |     f16   | `sin(a)=(e^(ia)-e^(-ia))/2`|
| ✓ | sinf       |     f32   |    ∅      |     f32   | ..                         |
| ✓ | sin        |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __sinx     |     f80   |    ∅      |     f80   | ..                         |
| ✓ | sinf128    |     f128  |    ∅      |     f128  | ..                         |
| ✓ | sinq       |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | sinl       |long double|    ∅      |long double| ..                         |
| ✓ | __sincosh  |     f16   | 2x *f16   |     ∅     |sin and cos of the same angle a|
| ✓ | sincosf    |     f32   | 2x *f32   |     ∅     |args a,*b,*c, `b.*=sin(x),c.*=cos(x)`|
| ✓ | sincos     |     f64   | 2x *f64   |     ∅     | ..                         |
| ✓ | __sincosx  |     f80   | 2x *f80   |     ∅     | ..                         |
| ✓ | sincosf128 |     f128  | 2x *f128  |     ∅     | ..                         |
| ✓ | sincosq    |     f128  | 2x *f128  |     ∅     | .. PPC                     |
| ✓ | sincosl    |long double| 2x *long double|∅     | ..                         |
| ✓ | __sqrth    |     f16   |    ∅      |     f16   | square root of a (find `r st. a=r^2`)|
| ✓ | sqrtf      |     f32   |    ∅      |     f32   | ..                         |
| ✓ | sqrt       |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __sqrtx    |     f80   |    ∅      |     f80   | ..                         |
| ✓ | sqrtf128   |     f128  |    ∅      |     f128  | ..                         |
| ✓ | sqrtq      |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | sqrtl      |long double|    ∅      |long double| ..                         |
| ✓ | __tanh     |     f16   |    ∅      |     f16   | `tan(x)=sin(x)/cos(x)      |
| ✓ | tanf       |     f32   |    ∅      |     f32   | ..                         |
| ✓ | tan        |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __tanx     |     f80   |    ∅      |     f80   | ..                         |
| ✓ | tanf128    |     f128  |    ∅      |     f128  | ..                         |
| ✓ | tanq       |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | tanl       |long double|    ∅      |long double| ..                         |
| ✓ | __trunch   |     f16   |    ∅      |     f16   | a rounded to next int towards zero|
| ✓ | truncf     |     f32   |    ∅      |     f32   | ..                         |
| ✓ | trunc      |     f64   |    ∅      |     f64   | ..                         |
| ✓ | __truncx   |     f80   |    ∅      |     f80   | ..                         |
| ✓ | truncf128  |     f128  |    ∅      |     f128  | ..                         |
| ✓ | truncq     |     f128  |    ∅      |     f128  | .. PPC                     |
| ✓ | truncl     |long double|    ∅      |long double| ..                         |

Further content (conditionally) exported with C abi:
- aarch64 outline atomics
- arm routines (memory routines + memclr [setting to 0], divmod routines and stubs for unwind_cpp)
- atomics
- bcmp
- clear cache
- memory routines (memcmp, memcpy, memset, memmove)
- msvc things like _alldiv, _aulldiv, _allrem
- objective-c __isPlatformVersionAtLeast check
- stack probe routines
- tls emulation

Future work:
- Arbitrary length integer library routines
