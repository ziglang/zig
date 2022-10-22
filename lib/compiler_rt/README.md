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

The routines in this folder are listed below.
Routines are annotated as `type source routine // description`, with `routine`
being the name used in aforementioned `compiler_rt.zig`.
`dev` means deviating from compiler_rt, `port` ported, `source` is the
information source for the implementation, `none` means unimplemented.
Some examples for the naming convention are:
- dev source name_routine, name_routine2 various implementations for performance, simplicity etc
- port llvm compiler-rt library routines from [LLVM](http://compiler-rt.llvm.org/)
   * LLVM emits library calls to compiler-rt, if the hardware lacks functionality
- port musl libc routines from [musl](https://musl.libc.org/)
If the library or information source is uncommon, use the entry `other` for `source`.
Please do not break the search by inserting entries in another format than `impl space source`.

Bugs should be solved by trying to duplicate the bug upstream, if possible.
 * If the bug exists upstream, get it fixed upstream and port the fix downstream to Zig.
 * If the bug only exists in Zig, use the corresponding C code and debug
   both implementations side by side to figure out what is wrong.

## Integer library routines

#### Integer Bit operations

- dev HackersDelight __clzsi2        // count leading zeros
- dev HackersDelight __clzdi2        // count leading zeros
- dev HackersDelight __clzti2        // count leading zeros
- dev HackersDelight __ctzsi2        // count trailing zeros
- dev HackersDelight __ctzdi2        // count trailing zeros
- dev HackersDelight __ctzti2        // count trailing zeros
- dev __ctzsi2 __ffssi2              // find least significant 1 bit
- dev __ctzsi2 __ffsdi2              // find least significant 1 bit
- dev __ctzsi2 __ffsti2              // find least significant 1 bit
- dev BitTwiddlingHacks __paritysi2  // bit parity
- dev BitTwiddlingHacks __paritydi2  // bit parity
- dev BitTwiddlingHacks __parityti2  // bit parity
- dev TAOCP __popcountsi2            // bit population
- dev TAOCP __popcountdi2            // bit population
- dev TAOCP __popcountti2            // bit population
- dev other __bswapsi2               // a byteswapped
- dev other __bswapdi2               // a byteswapped
- dev other __bswapti2               // a byteswapped

#### Integer Comparison

- port llvm __cmpsi2        // a,b: i32, (a<b)-> 0, (a==b) -> 1, (a>b) -> 2
- port llvm __cmpdi2        // a,b: i64
- port llvm __cmpti2        // a,b: i128
- port llvm __ucmpsi2       // a,b: u32, (a<b)-> 0, (a==b) -> 1, (a>b) -> 2
- port llvm __ucmpdi2       // a,b: u64
- port llvm __ucmpti2       // a,b: u128

#### Integer Arithmetic

- none none __ashlsi3       // a,b: i32, a << b unused in llvm, TODO (e.g. used by rl78)
- port llvm __ashldi3       // a,b: u64
- port llvm __ashlti3       // a,b: u128
- none none __ashrsi3       // a,b: i32, a >> b  arithmetic (sign fill) TODO (e.g. used by rl78)
- port llvm __ashrdi3       // ..
- port llvm __ashrti3       //
- none none __lshrsi3       // a,b: i32, a >> b  logical    (zero fill) TODO (e.g. used by rl78)
- port llvm __lshrdi3       //
- port llvm __lshrti3       //
- port llvm __negdi2        // a: i32,  -a, symbol-level compatibility with libgcc
- port llvm __negti2        //              unnecessary: unused in backends
- port llvm __mulsi3        // a,b: i32, a * b
- port llvm __muldi3        //
- port llvm __multi3        //
- port llvm __divsi3        // a,b: i32, a / b
- port llvm __divdi3        //
- port llvm __divti3        //
- port llvm __udivsi3       // a,b: u32, a / b
- port llvm __udivdi3       //
- port llvm __udivti3       //
- port llvm __modsi3        // a,b: i32, a % b
- port llvm __moddi3        //
- port llvm __modti3        //
- port llvm __umodsi3       // a,b: u32, a % b
- port llvm __umoddi3       //
- port llvm __umodti3       //
- port llvm __udivmoddi4    // a,b: u32, a / b, rem.* = a % b  unsigned
- port llvm __udivmodti4    //
- port llvm __udivmodsi4    //
- port llvm __divmodsi4     // a,b: i32, a / b, rem.* = a % b  signed, ARM
- port llvm __divmoddi4     //

#### Integer Arithmetic with trapping overflow

- dev BitTwiddlingHacks __absvsi2  // abs(a)
- dev BitTwiddlingHacks __absvdi2  // abs(a)
- dev BitTwiddlingHacks __absvti2  // abs(a)
- port llvm __negvsi2              // -a symbol-level compatibility: libgcc
- port llvm __negvdi2              // -a unnecessary: unused in backends
- port llvm __negvti2              // -a
- TODO upstreaming __addvsi3..__mulvti3 after testing panics works
- dev HackersDelight __addvsi3     // a + b
- dev HackersDelight __addvdi3     //
- dev HackersDelight __addvti3     //
- dev HackersDelight __subvsi3     // a - b
- dev HackersDelight __subvdi3     //
- dev HackersDelight __subvti3     //
- dev HackersDelight __mulvsi3     // a * b
- dev HackersDelight __mulvdi3     //
- dev HackersDelight __mulvti3     //

#### Integer Arithmetic which returns if overflow (would be faster without pointer)

- dev HackersDelight __addosi4     // a + b, overflow->ov.*=1 else 0
- dev HackersDelight __addodi4     // (completeness + performance, llvm does not use them)
- dev HackersDelight __addoti4     //
- dev HackersDelight __subosi4     // a - b, overflow->ov.*=1 else 0
- dev HackersDelight __subodi4     // (completeness + performance, llvm does not use them)
- dev HackersDelight __suboti4     //
- dev HackersDelight __mulosi4     // a * b, overflow->ov.*=1 else 0
- dev HackersDelight __mulodi4     // (required by llvm)
- dev HackersDelight __muloti4     //

## Float library routines

TODO: review source of implementation

#### Float Conversion

- dev  other __extendsfdf2   // a: f32 -> f64, TODO: missing tests
- dev  other __extendsftf2   // a: f32 -> f128
- dev   llvm __extendsfxf2   // a: f32 -> f80, TODO: missing tests
- dev  other __extenddftf2   // a: f64 -> f128
- dev   llvm __extenddfxf2   // a: f64 -> f80
- dev  other __truncdfsf2    // a: f64 -> f32, rounding towards zero
- dev  other __trunctfdf2    // a: f128-> f64
- dev  other __trunctfsf2    // a: f128-> f32
- dev   llvm __truncxfsf2    // a: f80 -> f32, TODO: missing tests
- dev   llvm __truncxfdf2    // a: f80 -> f64, TODO: missing tests

- dev  unclear __fixsfsi     // a: f32 -> i32, rounding towards zero
- dev  unclear __fixdfsi     // a: f64 -> i32
- dev  unclear __fixtfsi     // a: f128-> i32
- dev  unclear __fixxfsi     // a: f80 -> i32, TODO: missing tests
- dev  unclear __fixsfdi     // a: f32 -> i64, rounding towards zero
- dev  unclear __fixdfdi     // ..
- dev  unclear __fixtfdi     //
- dev  unclear __fixxfdi     // TODO: missing tests
- dev  unclear __fixsfti     // a: f32 -> i128, rounding towards zero
- dev  unclear __fixdfti     // ..
- dev  unclear __fixtfdi     //
- dev  unclear __fixxfti     // TODO: missing tests

- dev unclear __fixunssfsi   // a: f32 -> u32, rounding towards zero. negative values become 0.
- dev unclear __fixunsdfsi   // ..
- dev unclear __fixunstfsi   //
- dev unclear __fixunsxfsi   // TODO: missing tests
- dev unclear __fixunssfdi   // a: f32 -> u64, rounding towards zero. negative values become 0.
- dev unclear __fixunsdfdi   //
- dev unclear __fixunstfdi   //
- dev unclear __fixunsxfdi   // TODO: missing tests
- dev unclear __fixunssfti   // a: f32 -> u128, rounding towards zero. negative values become 0.
- dev unclear __fixunsdfti   //
- dev unclear __fixunstfdi   //
- dev unclear __fixunsxfti   // TODO: some more tests needed for base coverage

- dev unclear __floatsisf    // a: i32 -> f32
- dev unclear __floatsidf    // a: i32 -> f64, TODO: missing tests
- dev unclear __floatsitf    // ..
- dev unclear __floatsixf    // TODO: missing tests
- dev unclear __floatdisf    // a: i64 -> f32
- dev unclear __floatdidf    //
- dev unclear __floatditf    //
- dev unclear __floatdixf    // TODO: missing tests
- dev unclear __floattisf    // a: i128-> f32
- dev unclear __floattidf    //
- dev unclear __floattitf    //
- dev unclear __floattixf    // TODO: missing tests

- dev unclear __floatunsisf  // a: u32 -> f32
- dev unclear __floatunsidf  // TODO: missing tests
- dev unclear __floatunsitf  //
- dev unclear __floatunsixf  // TODO: missing tests
- dev unclear __floatundisf  // a: u64 -> f32
- dev unclear __floatundidf  //
- dev unclear __floatunditf  //
- dev unclear __floatundixf  // TODO: missing tests
- dev unclear __floatuntisf  // a: u128-> f32
- dev unclear __floatuntidf  //
- dev unclear __floatuntitf  //
- dev unclear __floatuntixf  // TODO: missing tests

#### Float Comparison

- dev other __cmpsf2       // a,b:f32, (a<b)->-1,(a==b)->0,(a>b)->1,Nan->1
- dev other __cmpdf2       // exported from __lesf2, __ledf2, __letf2 (below)
- dev other __cmptf2       // But: if NaN is a possibility, use another routine.
- dev other __unordsf2     // a,b:f32, (a==+-NaN or b==+-NaN) -> !=0, else -> 0
- dev other __unorddf2     // __only reliable for (input!=NaN)__
- dev other __unordtf2     // TODO: missing tests
- dev other __eqsf2        // (a!=NaN) and (b!=Nan) and (a==b) -> output=0
- dev other __eqdf2        //
- dev other __eqtf2        //
- dev other __nesf2        // (a==NaN) or (b==Nan) or (a!=b) -> output!=0
- dev other __nedf2        //
- dev other __netf2        // __eqtf2 and __netf2 have same return value -> tested with __eqsf2
- dev other __gesf2        // (a!=Nan) and (b!=Nan) and (a>=b) -> output>=0
- dev other __gedf2        //
- dev other __getf2        // TODO: missing tests
- dev other __ltsf2        // (a!=Nan) and (b!=Nan) and (a<b) -> output<0
- dev other __ltdf2        //
- dev other __lttf2        // TODO: missing tests
- dev other __lesf2        // (a!=Nan) and (b!=Nan) and (a<=b) -> output<=0
- dev other __ledf2        //
- dev other __letf2        // TODO: missing tests
- dev other __gtsf2        // (a!=Nan) and (b!=Nan) and (a>b) -> output>0
- dev other __gtdf2        //
- dev other __gttf2        // TODO: missing tests

#### Float Arithmetic

- dev unclear __addsf3       // a + b f32, TODO: missing tests
- dev unclear __adddf3       // a + b f64, TODO: missing tests
- dev unclear __addtf3       // a + b f128
- dev unclear __addxf3       // a + b f80
- dev unclear __aeabi_fadd   // a + b f64 ARM: AAPCS
- dev unclear __aeabi_dadd   // a + b f64 ARM: AAPCS
- dev unclear __subsf3       // a - b, TODO: missing tests
- dev unclear __subdf3       // a - b, TODO: missing tests
- dev unclear __subtf3       // a - b
- dev unclear __subxf3       // a - b f80, TODO: missing tests
- dev unclear __aeabi_fsub   // a - b f64 ARM: AAPCS
- dev unclear __aeabi_dsub   // a - b f64 ARM: AAPCS
- dev unclear __mulsf3       // a * b, TODO: missing tests
- dev unclear __muldf3       // a * b, TODO: missing tests
- dev unclear __multf3       // a * b
- dev unclear __mulxf3       // a * b
- dev unclear __divsf3       // a / b, TODO: review tests
- dev unclear __divdf3       // a / b, TODO: review tests
- dev unclear __divtf3       // a / b
- dev unclear __divxf3       // a / b
- dev unclear __negsf2       // -a symbol-level compatibility: libgcc uses this for the rl78
- dev unclear __negdf2       // -a unnecessary: can be lowered directly to a xor
- dev unclear __negtf2       // -a, TODO: missing tests
- dev unclear __negxf2       // -a, TODO: missing tests

#### Floating point raised to integer power
- dev unclear __powisf2  // a ^ b, TODO
- dev unclear __powidf2  //
- dev unclear __powitf2  //
- dev unclear __powixf2  //
- dev unclear __mulsc3   // (a+ib) * (c+id)
- dev unclear __muldc3   //
- dev unclear __multc3   //
- dev unclear __mulxc3   //
- dev unclear __divsc3   // (a+ib) * / (c+id)
- dev unclear __divdc3   //
- dev unclear __divtc3   //
- dev unclear __divxc3   //

## Decimal float library routines

BID means Binary Integer Decimal encoding, DPD means Densely Packed Decimal encoding.
BID should be only chosen for binary data, DPD for decimal data (ASCII, Unicode etc).
If possible, use BCD instead of DPD to represent numbers not accurately representable
in binary like the number 0.2.

All routines are TODO.

#### Decimal float Conversion

- __dpd_extendsddd2  //       dec32->dec64
- __bid_extendsddd2  //       dec32->dec64
- __dpd_extendsdtd2  //       dec32->dec128
- __bid_extendsdtd2  //       dec32->dec128
- __dpd_extendddtd2  //       dec64->dec128
- __bid_extendddtd2  //       dec64->dec128
- __dpd_truncddsd2   //       dec64->dec32
- __bid_truncddsd2   //       dec64->dec32
- __dpd_trunctdsd2   //      dec128->dec32
- __bid_trunctdsd2   //      dec128->dec32
- __dpd_trunctddd2   //      dec128->dec64
- __bid_trunctddd2   //      dec128->dec64

- __dpd_extendsfdd   //       float->dec64
- __bid_extendsfdd   //       float->dec64
- __dpd_extendsftd   //       float->dec128
- __bid_extendsftd   //       float->dec128
- __dpd_extenddftd   //      double->dec128
- __bid_extenddftd   //      double->dec128
- __dpd_extendxftd   // long double->dec128
- __bid_extendxftd   // long double->dec128
- __dpd_truncdfsd    //      double->dec32
- __bid_truncdfsd    //      double->dec32
- __dpd_truncxfsd    // long double->dec32
- __bid_truncxfsd    // long double->dec32
- __dpd_trunctfsd    // long double->dec32
- __bid_trunctfsd    // long double->dec32
- __dpd_truncxfdd    // long double->dec64
- __bid_truncxfdd    // long double->dec64
- __dpd_trunctfdd    // long double->dec64
- __bid_trunctfdd    // long double->dec64

- __dpd_truncddsf    //      dec64->float
- __bid_truncddsf    //      dec64->float
- __dpd_trunctdsf    //     dec128->float
- __bid_trunctdsf    //     dec128->float
- __dpd_extendsddf   //      dec32->double
- __bid_extendsddf   //      dec32->double
- __dpd_trunctddf    //     dec128->double
- __bid_trunctddf    //     dec128->double
- __dpd_extendsdxf   //      dec32->long double
- __bid_extendsdxf   //      dec32->long double
- __dpd_extendddxf   //      dec64->long double
- __bid_extendddxf   //      dec64->long double
- __dpd_trunctdxf    //     dec128->long double
- __bid_trunctdxf    //     dec128->long double
- __dpd_extendsdtf   //      dec32->long double
- __bid_extendsdtf   //      dec32->long double
- __dpd_extendddtf   //      dec64->long double
- __bid_extendddtf   //      dec64->long double

Same size conversion:
- __dpd_extendsfsd   //      float->dec32
- __bid_extendsfsd   //      float->dec32
- __dpd_extenddfdd   //     double->dec64
- __bid_extenddfdd   //     double->dec64
- __dpd_extendtftd   //long double->dec128
- __bid_extendtftd   //long double->dec128
- __dpd_truncsdsf    //      dec32->float
- __bid_truncsdsf    //      dec32->float
- __dpd_truncdddf    //      dec64->float
- __bid_truncdddf    //      dec64->float
- __dpd_trunctdtf    //     dec128->long double
- __bid_trunctdtf    //     dec128->long double

- __dpd_fixsdsi      //      dec32->int
- __bid_fixsdsi      //      dec32->int
- __dpd_fixddsi      //      dec64->int
- __bid_fixddsi      //      dec64->int
- __dpd_fixtdsi      //     dec128->int
- __bid_fixtdsi      //     dec128->int

- __dpd_fixsddi      //      dec32->long
- __bid_fixsddi      //      dec32->long
- __dpd_fixdddi      //      dec64->long
- __bid_fixdddi      //      dec64->long
- __dpd_fixtddi      //     dec128->long
- __bid_fixtddi      //     dec128->long

- __dpd_fixunssdsi   //   dec32->unsigned int, All negative values become zero.
- __bid_fixunssdsi   //   dec32->unsigned int
- __dpd_fixunsddsi   //   dec64->unsigned int
- __bid_fixunsddsi   //   dec64->unsigned int
- __dpd_fixunstdsi   //  dec128->unsigned int
- __bid_fixunstdsi   //  dec128->unsigned int

- __dpd_fixunssddi   //   dec32->unsigned long, All negative values become zero.
- __bid_fixunssddi   //   dec32->unsigned long
- __dpd_fixunsdddi   //   dec64->unsigned long
- __bid_fixunsdddi   //   dec64->unsigned long
- __dpd_fixunstddi   //  dec128->unsigned long
- __bid_fixunstddi   //  dec128->unsigned long

- __dpd_floatsisd    //     int->dec32
- __bid_floatsisd    //     int->dec32
- __dpd_floatsidd    //     int->dec64
- __bid_floatsidd    //     int->dec64
- __dpd_floatsitd    //     int->dec128
- __bid_floatsitd    //     int->dec128

- __dpd_floatdisd    //    long->dec32
- __bid_floatdisd    //    long->dec32
- __dpd_floatdidd    //    long->dec64
- __bid_floatdidd    //    long->dec64
- __dpd_floatditd    //    long->dec128
- __bid_floatditd    //    long->dec128

- __dpd_floatunssisd  //  unsigned int->dec32
- __bid_floatunssisd  //  unsigned int->dec32
- __dpd_floatunssidd  //  unsigned int->dec64
- __bid_floatunssidd  //  unsigned int->dec64
- __dpd_floatunssitd  //  unsigned int->dec128
- __bid_floatunssitd  //  unsigned int->dec128

- __dpd_floatunsdisd  // unsigned long->dec32
- __bid_floatunsdisd  // unsigned long->dec32
- __dpd_floatunsdidd  // unsigned long->dec64
- __bid_floatunsdidd  // unsigned long->dec64
- __dpd_floatunsditd  // unsigned long->dec128
- __bid_floatunsditd  // unsigned long->dec128

#### Decimal float Comparison

All decimal float comparison routines return c_int.

- __dpd_unordsd2  // a,b: dec32, a +-NaN or a +-NaN -> 1(nonzero), else -> 0
- __bid_unordsd2  // a,b: dec32
- __dpd_unorddd2  // a,b: dec64
- __bid_unorddd2  // a,b: dec64
- __dpd_unordtd2  // a,b: dec128
- __bid_unordtd2  // a,b: dec128

- __dpd_eqsd2  // a,b: dec32, a!=+-NaN and b!=+-Nan and a==b -> 0, else -> 1(nonzero)
- __bid_eqsd2  // a,b: dec32
- __dpd_eqdd2  // a,b: dec64
- __bid_eqdd2  // a,b: dec64
- __dpd_eqtd2  // a,b: dec128
- __bid_eqtd2  // a,b: dec128

- __dpd_nesd2  // a,b: dec32, a==+-NaN or b==+-NaN or a!=b -> 1(nonzero), else -> 0
- __bid_nesd2  // a,b: dec32
- __dpd_nedd2  // a,b: dec64
- __bid_nedd2  // a,b: dec64
- __dpd_netd2  // a,b: dec128
- __bid_netd2  // a,b: dec128

- __dpd_gesd2  // a,b: dec32, a!=+-NaN and b!=+-NaN and a>=b -> >=0, else -> <0
- __bid_gesd2  // a,b: dec32
- __dpd_gedd2  // a,b: dec64
- __bid_gedd2  // a,b: dec64
- __dpd_getd2  // a,b: dec128
- __bid_getd2  // a,b: dec128

- __dpd_ltsd2  // a,b: dec32, a!=+-NaN and b!=+-NaN and a<b -> <0, else -> >=0
- __bid_ltsd2  // a,b: dec32
- __dpd_ltdd2  // a,b: dec64
- __bid_ltdd2  // a,b: dec64
- __dpd_lttd2  // a,b: dec128
- __bid_lttd2  // a,b: dec128

- __dpd_lesd2  // a,b: dec32, a!=+-NaN and b!=+-NaN and a<=b -> <=0, else -> >=0
- __bid_lesd2  // a,b: dec32
- __dpd_ledd2  // a,b: dec64
- __bid_ledd2  // a,b: dec64
- __dpd_letd2  // a,b: dec128
- __bid_letd2  // a,b: dec128

- __dpd_gtsd2  // a,b: dec32, a!=+-NaN and b!=+-NaN and a>b -> >0, else -> <=0
- __bid_gtsd2  // a,b: dec32
- __dpd_gtdd2  // a,b: dec64
- __bid_gtdd2  // a,b: dec64
- __dpd_gttd2  // a,b: dec128
- __bid_gttd2  // a,b: dec128

#### Decimal float Arithmetic

These numbers include options with routines for +-0 and +-Nan.

- __dpd_addsd3  // a,b: dec32 -> dec32,  a + b
- __bid_addsd3  // a,b: dec32 -> dec32
- __dpd_adddd3  // a,b: dec64 -> dec64
- __bid_adddd3  // a,b: dec64 -> dec64
- __dpd_addtd3  // a,b: dec128-> dec128
- __bid_addtd3  // a,b: dec128-> dec128
- __dpd_subsd3  // a,b: dec32,  a - b
- __bid_subsd3  // a,b: dec32 -> dec32
- __dpd_subdd3  // a,b: dec64 ..
- __bid_subdd3  // a,b: dec64
- __dpd_subtd3  // a,b: dec128
- __bid_subtd3  // a,b: dec128
- __dpd_mulsd3  // a,b: dec32,  a * b
- __bid_mulsd3  // a,b: dec32 -> dec32
- __dpd_muldd3  // a,b: dec64 ..
- __bid_muldd3  // a,b: dec64
- __dpd_multd3  // a,b: dec128
- __bid_multd3  // a,b: dec128
- __dpd_divsd3  // a,b: dec32,  a / b
- __bid_divsd3  // a,b: dec32 -> dec32
- __dpd_divdd3  // a,b: dec64 ..
- __bid_divdd3  // a,b: dec64
- __dpd_divtd3  // a,b: dec128
- __bid_divtd3  // a,b: dec128
- __dpd_negsd2  // a,b: dec32, -a
- __bid_negsd2  // a,b: dec32 -> dec32
- __dpd_negdd2  // a,b: dec64 ..
- __bid_negdd2  // a,b: dec64
- __dpd_negtd2  // a,b: dec128
- __bid_negtd2  // a,b: dec128

## Fixed-point fractional library routines

TODO

Too unclear for work items:
- Miscellaneous routines => unclear, if supported (cache control and stack functions)
- Zig-specific language runtime features, for example "Arbitrary length integer library routines"
