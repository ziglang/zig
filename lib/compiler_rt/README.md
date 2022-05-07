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
- Soft float library routines => only f80 routines missing
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
- dev HackersDelight __clzsi2          // count leading zeros
- dev HackersDelight __clzdi2          // count leading zeros
- dev HackersDelight __clzti2          // count leading zeros
- dev HackersDelight __ctzsi2          // count trailing zeros
- dev HackersDelight __ctzdi2          // count trailing zeros
- dev HackersDelight __ctzti2          // count trailing zeros
- dev __ctzsi2 __ffssi2                // find least significant 1 bit
- dev __ctzsi2 __ffsdi2                // find least significant 1 bit
- dev __ctzsi2 __ffsti2                // find least significant 1 bit
- dev BitTwiddlingHacks __paritysi2    // bit parity
- dev BitTwiddlingHacks __paritydi2    // bit parity
- dev BitTwiddlingHacks __parityti2    // bit parity
- dev TAOCP __popcountsi2              // bit population
- dev TAOCP __popcountdi2              // bit population
- dev TAOCP __popcountti2              // bit population
- dev other __bswapsi2                 // a byteswapped
- dev other __bswapdi2                 // a byteswapped
- dev other __bswapti2                 // a byteswapped

#### Integer Comparison
- port llvm __cmpsi2        // (a<b)=>output=0, (a==b)=>output=1, (a>b)=>output=2
- port llvm __cmpdi2
- port llvm __cmpti2
- port llvm __ucmpsi2       // (a<b)=>output=0, (a==b)=>output=1, (a>b)=>output=2
- port llvm __ucmpdi2
- port llvm __ucmpti2

#### Integer Arithmetic
- none none __ashlsi3              // a << b unused in llvm, missing (e.g. used by rl78)
- port llvm __ashldi3              // a << b
- port llvm __ashlti3              // a << b
- none none __ashrsi3              // a >> b  arithmetic (sign fill) missing (e.g. used by rl78)
- port llvm __ashrdi3              // a >> b  arithmetic (sign fill)
- port llvm __ashrti3              // a >> b  arithmetic (sign fill)
- none none __lshrsi3              // a >> b  logical    (zero fill) missing (e.g. used by rl78)
- port llvm __lshrdi3              // a >> b  logical    (zero fill)
- port llvm __lshrti3              // a >> b  logical    (zero fill)
- port llvm __negdi2               // -a symbol-level compatibility: libgcc
- port llvm __negti2               // -a unnecessary: unused in backends
- port llvm __mulsi3               // a * b  signed
- port llvm __muldi3               // a * b  signed
- port llvm __multi3               // a * b  signed
- port llvm __divsi3               // a / b  signed
- port llvm __divdi3               // a / b  signed
- port llvm __divti3               // a / b  signed
- port llvm __udivsi3              // a / b  unsigned
- port llvm __udivdi3              // a / b  unsigned
- port llvm __udivti3              // a / b  unsigned
- port llvm __modsi3               // a % b  signed
- port llvm __moddi3               // a % b  signed
- port llvm __modti3               // a % b  signed
- port llvm __umodsi3              // a % b  unsigned
- port llvm __umoddi3              // a % b  unsigned
- port llvm __umodti3              // a % b  unsigned
- port llvm __udivmoddi4           // a / b, rem.* = a % b  unsigned
- port llvm __udivmodti4           // a / b, rem.* = a % b  unsigned
- port llvm __udivmodsi4           // a / b, rem.* = a % b  unsigned
- port llvm __divmodsi4            // a / b, rem.* = a % b  signed, ARM

#### Integer Arithmetic with trapping overflow
- dev BitTwiddlingHacks __absvsi2  // abs(a)
- dev BitTwiddlingHacks __absvdi2  // abs(a)
- dev BitTwiddlingHacks __absvti2  // abs(a)
- port llvm __negvsi2              // -a symbol-level compatibility: libgcc
- port llvm __negvdi2              // -a unnecessary: unused in backends
- port llvm __negvti2              // -a
- TODO upstreaming __addvsi3..__mulvti3 after testing panics works
- dev HackersDelight __addvsi3     // a + b
- dev HackersDelight __addvdi3     // a + b
- dev HackersDelight __addvti3     // a + b
- dev HackersDelight __subvsi3     // a - b
- dev HackersDelight __subvdi3     // a - b
- dev HackersDelight __subvti3     // a - b
- dev HackersDelight __mulvsi3     // a * b
- dev HackersDelight __mulvdi3     // a * b
- dev HackersDelight __mulvti3     // a * b

#### Integer Arithmetic which returns if overflow (would be faster without pointer)
- dev HackersDelight __addosi4     // a + b, overflow=>ov.*=1 else 0
- dev HackersDelight __addodi4     // (completeness + performance, llvm does not use them)
- dev HackersDelight __addoti4     //
- dev HackersDelight __subosi4     // a - b, overflow=>ov.*=1 else 0
- dev HackersDelight __subodi4     // (completeness + performance, llvm does not use them)
- dev HackersDelight __suboti4     //
- dev HackersDelight __mulosi4     // a * b, overflow=>ov.*=1 else 0
- dev HackersDelight __mulodi4     // (required by llvm)
- dev HackersDelight __muloti4     //

## Float library routines

#### Float Conversion
- todo todo __extendsfdf2  // extend a f32 => f64
- todo todo __extendsftf2  // extend a f32 => f128
- dev  llvm __extendsfxf2  // extend a f32 => f80
- todo todo __extenddftf2  // extend a f64 => f128
- dev  llvm __extenddfxf2  // extend a f64 => f80
- todo todo __truncdfsf2   // truncate a to narrower mode of return type, rounding towards zero
- todo todo __trunctfdf2   //
- todo todo __trunctfsf2   //
- dev  llvm __truncxfsf2   //
- dev  llvm __truncxfdf2   //
- todo todo __fixsfsi      // convert a to i32, rounding towards zero
- todo todo __fixdfsi      //
- todo todo __fixtfsi      //
- todo todo __fixxfsi      //
- todo todo __fixsfdi      // convert a to i64, rounding towards zero
- todo todo __fixdfdi      //
- todo todo __fixtfdi      //
- todo todo __fixxfdi      //
- todo todo __fixsfti      // convert a to i128, rounding towards zero
- todo todo __fixdfti      //
- todo todo __fixtfdi      //
- todo todo __fixxfti      //

- __fixunssfsi   // convert to u32, rounding towards zero. negative values become 0.
- __fixunsdfsi   //
- __fixunstfsi   //
- __fixunsxfsi   //
- __fixunssfdi   // convert to u64, rounding towards zero. negative values become 0.
- __fixunsdfdi   //
- __fixunstfdi   //
- __fixunsxfdi   //
- __fixunssfti   // convert to u128, rounding towards zero. negative values become 0.
- __fixunsdfti   //
- __fixunstfdi   //
- __fixunsxfti   //

- __floatsisf    // convert i32 to floating point
- __floatsidf    //
- __floatsitf    //
- __floatsixf    //
- __floatdisf    // convert i64 to floating point
- __floatdidf    //
- __floatditf    //
- __floatdixf    //
- __floattisf    // convert i128 to floating point
- __floattidf    //
- __floattixf    //

- __floatunsisf  // convert u32 to floating point
- __floatunsidf  //
- __floatunsitf  //
- __floatunsixf  //
- __floatundisf  // convert u64 to floating point
- __floatundidf  //
- __floatunditf  //
- __floatundixf  //
- __floatuntisf  // convert u128 to floating point
- __floatuntidf  //
- __floatuntitf  //
- __floatuntixf  //

#### Float Comparison
- __cmpsf2       // return (a<b)=>-1,(a==b)=>0,(a>b)=>1,Nan=>1 dont rely on this
- __cmpdf2       // exported from __lesf2, __ledf2, __letf2 (below)
- __cmptf2       //
- __unordsf2     // (input==NaN) => out!=0 else out=0,
- __unorddf2     // __only reliable for (input!=Nan)__
- __unordtf2     //
- __eqsf2        // (a!=NaN) and (b!=Nan) and (a==b) => output=0
- __eqdf2        //
- __eqtf2        //
- __nesf2        // (a==NaN) or (b==Nan) or (a!=b) => output!=0
- __nedf2        //
- __netf2        //
- __gesf2        // (a!=Nan) and (b!=Nan) and (a>=b) => output>=0
- __gedf2        //
- __getf2        //
- __ltsf2        // (a!=Nan) and (b!=Nan) and (a<b) => output<0
- __ltdf2        //
- __lttf2        //
- __lesf2        // (a!=Nan) and (b!=Nan) and (a<=b) => output<=0
- __ledf2        //
- __letf2        //
- __gtsf2        // (a!=Nan) and (b!=Nan) and (a>b) => output>0
- __gtdf2        //
- __gttf2        //

#### Float Arithmetic
- __addsf3       // a + b f32
- __adddf3       // a + b f64
- __addtf3       // a + b f128
- __addxf3       // a + b f80
- __aeabi_fadd   // a + b f64 ARM: AAPCS
- __aeabi_dadd   // a + b f64 ARM: AAPCS
- __subsf3       // a - b
- __subdf3       // a - b
- __subtf3       // a - b
- __subxf3       // a - b f80
- __aeabi_fsub   // a - b f64 ARM: AAPCS
- __aeabi_dsub   // a - b f64 ARM: AAPCS
- __mulsf3       // a * b
- __muldf3       // a * b
- __multf3       // a * b
- __mulxf3       // a * b
- __divsf3       // a / b
- __divdf3       // a / b
- __divtf3       // a / b
- __divxf3       // a / b
- __negsf2       // -a symbol-level compatibility: libgcc uses this for the rl78
- __negdf2       // -a unnecessary: can be lowered directly to a xor
- __negtf2       // -a
- __negxf2       // -a

#### Floating point raised to integer power
- __powisf2  // unclear, if supported a ^ b
- __powidf2  //
- __powitf2  //
- __powixf2  //
- __mulsc3   // unsupported (a+ib) * (c+id)
- __muldc3   //
- __multc3   //
- __mulxc3   //
- __divsc3   // unsupported (a+ib) * / (c+id)
- __divdc3   //
- __divtc3   //
- __divxc3   //
