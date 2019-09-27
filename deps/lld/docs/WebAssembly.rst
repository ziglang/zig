WebAssembly lld port
====================

The WebAssembly version of lld takes WebAssembly binaries as inputs and produces
a WebAssembly binary as its output.  For the most part it tries to mimic the
behaviour of traditional ELF linkers and specifically the ELF lld port.  Where
possible the command line flags and the semantics should be the same.


Object file format
------------------

The WebAssembly object file format used by LLVM and LLD is specified as part of
the WebAssembly tool conventions on linking_.

This is the object format that the llvm will produce when run with the
``wasm32-unknown-unknown`` target.

Usage
-----

The WebAssembly version of lld is installed as **wasm-ld**.  It shared many 
common linker flags with **ld.lld** but also includes several
WebAssembly-specific options:

.. option:: --no-entry

  Don't search for the entry point symbol (by default ``_start``).

.. option:: --export-table

  Export the function table to the environment.

.. option:: --import-table

  Import the function table from the environment.

.. option:: --export-all

  Export all symbols (normally combined with --no-gc-sections)

.. option:: --export-dynamic

  When building an executable, export any non-hidden symbols.  By default only
  the entry point and any symbols marked with --export/--export-all are
  exported.

.. option:: --global-base=<value>

  Address at which to place global data.

.. option:: --no-merge-data-segments

  Disable merging of data segments.

.. option:: --stack-first

  Place stack at start of linear memory rather than after data.

.. option:: --compress-relocations

  Relocation targets in the code section 5-bytes wide in order to potentially
  occomate the largest LEB128 value.  This option will cause the linker to
  shirnk the code section to remove any padding from the final output.  However
  because it effects code offset, this option is not comatible with outputing
  debug information.

.. option:: --allow-undefined

  Allow undefined symbols in linked binary.

.. option:: --import-memory

  Import memory from the environment.

.. option:: --initial-memory=<value>

  Initial size of the linear memory. Default: static data size.

.. option:: --max-memory=<value>

  Maximum size of the linear memory. Default: unlimited.

By default the function table is neither imported nor exported, but defined
for internal use only.

Behaviour
---------

In general, where possible, the WebAssembly linker attempts to emulate the
behaviour of a traditional ELF linker, and in particular the ELF port of lld.
For more specific details on how this is achieved see the tool conventions on
linking_.

Function Signatures
~~~~~~~~~~~~~~~~~~~

One way in which the WebAssembly linker differs from traditional native linkers
is that function signature checking is strict in WebAssembly.  It is a
validation error for a module to contain a call site that doesn't agree with
the target signature.  Even though this is undefined behaviour in C/C++, it is not
uncommon to find this in real-world C/C++ programs.  For example, a call site in
one compilation unit which calls a function defined in another compilation
unit but with too many arguments.

In order not to generate such invalid modules, lld has two modes of handling such
mismatches: it can simply error-out or it can create stub functions that will
trap at runtime (functions that contain only an ``unreachable`` instruction)
and use these stub functions at the otherwise invalid call sites.

The default behaviour is to generate these stub function and to produce
a warning.  The ``--falal-warnings`` flag can be used to disable this behaviour
and error out if mismatched are found.

Imports and Exports
~~~~~~~~~~~~~~~~~~~

When building a shared library any symbols marked as ``visibility=default`` will
be exported.  When building an executable, only the entry point and symbols
flagged as ``WASM_SYMBOL_EXPORTED`` are exported by default.  In LLVM the
``WASM_SYMBOL_EXPORTED`` flag is applied to any symbol in the ``llvm.used`` list
which corresponds to ``__attribute__((used))`` in C/C++ sources.

In addition, symbols can be exported via the linker command line using
``--export``.

Finally, just like with native ELF linker the ``--export-dynamic`` flag can be
used to export symbol in the executable which are marked as
``visibility=default``.

Garbage Collection
~~~~~~~~~~~~~~~~~~

Since WebAssembly is designed with size in mind the linker defaults to
``--gc-sections`` which means that all unused functions and data segments will
be stripped from the binary.

The symbols which are preserved by default are:

- The entry point (by default ``_start``).
- Any symbol which is to be exported.
- Any symbol transitively referenced by the above.

Weak Undefined Functions
~~~~~~~~~~~~~~~~~~~~~~~~

On native platforms, calls to weak undefined functions end up as calls to the
null function pointer.  With WebAssembly, direct calls must reference a defined
function (with the correct signature).  In order to handle this case the linker
will generate function a stub containing only the ``unreachable`` instruction
and use this for any direct references to an undefined weak function.

For example a runtime call to a weak undefined function ``foo`` will up trapping
on ``unreachable`` inside and linker-generated function called
``undefined:foo``.

Missing features
----------------

- Merging of data section similar to ``SHF_MERGE`` in the ELF world is not
  supported.
- No support for creating shared libraries.  The spec for shared libraries in
  WebAssembly is still in flux:
  https://github.com/WebAssembly/tool-conventions/blob/master/DynamicLinking.md

.. _linking: https://github.com/WebAssembly/tool-conventions/blob/master/Linking.md
