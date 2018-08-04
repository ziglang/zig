WebAssembly lld port
====================

Note: The WebAssembly port is still a work in progress and is be lacking
certain features.

The WebAssembly version of lld takes WebAssembly binaries as inputs and produces
a WebAssembly binary as its output.  For the most part this port tried to mimic
the behaviour of traditional ELF linkers and specifically the ELF lld port.
Where possible that command line flags and the semantics should be the same.


Object file format
------------------

The format the input object files that lld expects is specified as part of the
the WebAssembly tool conventions
https://github.com/WebAssembly/tool-conventions/blob/master/Linking.md.

This is object format that the llvm will produce when run with the
``wasm32-unknown-unknown`` target.  To build llvm with WebAssembly support
currently requires enabling the experimental backed using
``-DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly``.


Missing features
----------------

There are several key features that are not yet implement in the WebAssembly
ports:

- COMDAT support.  This means that support for C++ is still very limited.
- Function stripping.  Currently there is no support for ``--gc-sections`` so
  functions and data from a given object will linked as a unit.
- Section start/end symbols.  The synthetic symbols that mark the start and
  of data regions are not yet created in the output file.
