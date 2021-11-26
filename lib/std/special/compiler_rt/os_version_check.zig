// Ported from llvm-project 13.0.0 d7b669b3a30345cfcdb2fde2af6f48aa4b94845d
//
// https://github.com/llvm/llvm-project/blob/llvmorg-13.0.0/compiler-rt/lib/builtins/os_version_check.c

// The compiler generates calls to __isPlatformVersionAtLeast() and __isOSVersionAtLeast() when
// Objective-C's @available function is invoked.
