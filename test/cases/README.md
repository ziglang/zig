# Test Case Quick Reference

Use comments at the **end of the file** to indicate metadata about the test
case. Here are examples of different kinds of tests:

## Compile Error Test

If you want it to be run with `zig test` and match expected error messages:

```zig
// error
// is_test=true
//
// :4:13: error: 'try' outside function scope
```

## Execution

This will do `zig run` on the code and expect exit code 0.

```zig
// run
```

## Incremental Compilation

Make multiple files that have ".", and then an integer, before the ".zig"
extension, like this:

```
hello.0.zig
hello.1.zig
hello.2.zig
```

Each file can be a different kind of test, such as expecting compile errors,
or expecting to be run and exit(0). The test harness will use these to simulate
incremental compilation.

At the time of writing there is no way to specify multiple files being changed
as part of an update.

## Subdirectories

Subdirectories do not have any semantic meaning but they can be used for
organization since the test harness will recurse into them. The full directory
path will be prepended as a prefix on the test case name.

## Limiting which Backends and Targets are Tested

```zig
// run
// backend=selfhosted,llvm
// target=x86_64-linux,x86_64-macos
```

Possible backends are:

 * `auto`: the default; compiler picks the backend based on robustness.
 * `selfhosted`: equivalent to passing `-fno-llvm -fno-lld`.
 * `llvm`: equivalent to `-fllvm`.
