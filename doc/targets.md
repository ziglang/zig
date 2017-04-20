# How to Add Support For More Targets

Create bootstrap code in std/bootstrap.zig and add conditional compilation
logic. This code is responsible for the real executable entry point, calling
main(argc, argv, env) and making the exit syscall when main returns.

How to pass a byvalue struct parameter in the C calling convention is
target-specific. Add logic for how to do function prototypes and function calls
for the target when an exported or external function has a byvalue struct.

Write the target-specific code in the standard library.

Update the C integer types to be the correct size for the target.

Make sure that `c_long_double` codegens the correct floating point value.
