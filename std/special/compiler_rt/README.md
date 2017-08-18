This compiler-rt library is ported from [LLVM](http://compiler-rt.llvm.org/).

It's needed because LLVM emits library calls to compiler-rt when hardware lacks
functionality, for example, 64-bit integer multiplication on 32-bit x86.

This library is automatically built as-needed for the compilation target and
then statically linked and therefore is a transparent dependency for the
programmer.

Any bugs should be solved by trying to duplicate the bug upstream.
 * If the bug exists upstream, get it fixed with the LLVM team and then port
   the fix downstream to Zig.
 * If the bug only exists in Zig, something went wrong porting the code,
   and you can run the C code and Zig code side by side in a debugger
   to figure out what's happening differently.
