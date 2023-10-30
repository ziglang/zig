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

## Translate-c

If you want to test translating C code to Zig use `translate-c`:

```c
// translate-c
// c_frontend=aro,clang
// target=x86_64-linux
//
// pub const foo = 1;
// pub const immediately_after_foo = 2;
//
// pub const somewhere_else_in_the_file = 3:
```

## Run Translated C

If you want to test translating C code to Zig and then executing it use `run-translated-c`:

```c
// run-translated-c
// c_frontend=aro,clang
// target=x86_64-linux
//
// Hello world!
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
// backend=stage2,llvm
// target=x86_64-linux,x86_64-macos
```

Possible backends are:

 * `stage1`: equivalent to `-fstage1`.
 * `stage2`: equivalent to passing `-fno-stage1 -fno-LLVM`.
 * `llvm`: equivalent to `-fLLVM -fno-stage1`.
