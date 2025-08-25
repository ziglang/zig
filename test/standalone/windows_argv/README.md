Tests that Zig's `std.process.ArgIteratorWindows` is compatible with both the MSVC and MinGW C runtimes' argv splitting algorithms.

The method of testing is:
- Compile a C file with `wmain` as its entry point
- The C `wmain` calls a Zig-implemented `verify` function that takes the `argv` from `wmain` and compares it to the argv gotten from `std.proccess.argsAlloc` (which takes `kernel32.GetCommandLineW()` and splits it)
- The compiled C program is spawned continuously as a child process by the implementation in `fuzz.zig` with randomly generated command lines
  + On Windows, the 'application name' and the 'command line' are disjoint concepts. That is, you can spawn `foo.exe` but set the command line to `bar.exe`, and `CreateProcessW` will spawn `foo.exe` but `argv[0]` will be `bar.exe`. This quirk allows us to test arbitrary `argv[0]` values as well which otherwise wouldn't be possible.

Note: This is intentionally testing against the C runtime argv splitting and *not* [`CommandLineToArgvW`](https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-commandlinetoargvw), since the C runtime argv splitting was updated in 2008 but `CommandLineToArgvW` still uses the pre-2008 algorithm (which differs in both `argv[0]` rules and `""`; see [here](https://daviddeley.com/autohotkey/parameters/parameters.htm#WINCRULESDOC) for details)

---

In addition to being run during `zig build test-standalone`, this test can be run on its own via `zig build test` from within this directory.

When run on its own:
- `-Diterations=<num>` can be used to set the max fuzzing iterations, and `-Diterations=0` can be used to fuzz indefinitely
- `-Dseed=<num>` can be used to set the PRNG seed for fuzz testing. If not provided, then the seed is chosen at random during `build.zig` compilation.

On failure, the number of iterations and the seed can be seen in the failing command, e.g. in `path\to\fuzz.exe path\to\verify-msvc.exe 100 2780392459403250529`, the iterations is `100` and the seed is `2780392459403250529`.
