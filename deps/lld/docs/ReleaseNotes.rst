=======================
lld 9.0.0 Release Notes
=======================

.. contents::
    :local:

Introduction
============

lld is a high-performance linker that supports ELF (Unix), COFF
(Windows), Mach-O (macOS), MinGW and WebAssembly. lld is
command-line-compatible with GNU linkers and Microsoft link.exe and is
significantly faster than the system default linkers.

lld 9 has lots of feature improvements and bug fixes.

Non-comprehensive list of changes in this release
=================================================

ELF Improvements
----------------

* ld.lld now has typo suggestions for flags:
  ``$ ld.lld --call-shared`` now prints
  ``unknown argument '--call-shared', did you mean '--call_shared'``.
  (`r361518 <https://reviews.llvm.org/rL361518>`_)

* ``--allow-shlib-undefined`` and ``--no-allow-shlib-undefined``
  options are added. ``--no-allow-shlib-undefined`` is the default for
  executables.
  (`r352826 <https://reviews.llvm.org/rL352826>`_)

* ``-nmagic`` and ``-omagic`` options are fully supported.
  (`r360593 <https://reviews.llvm.org/rL360593>`_)

* Segment layout has changed. PT_GNU_RELRO, which was previously
  placed in the middle of readable/writable PT_LOAD segments, is now
  placed at the beginning of them. This change permits lld-produced
  ELF files to be read correctly by GNU strip older than 2.31, which
  has a bug to discard a PT_GNU_RELRO in the former layout.

* ``-z common-page-size`` is supported.
  (`r360593 <https://reviews.llvm.org/rL360593>`_)

* Diagnostics messages have improved. A new flag ``--vs-diagnostics``
  alters the format of diagnostic output to enable source hyperlinks
  in Microsoft Visual Studio IDE.

* Linker script compatibility with GNU BFD linker has generally improved.

* The clang ``--dependent-library`` form of autolinking is supported.

  This feature is added to implement the Windows-style autolinking for
  Unix. On Unix, in order to use a library, you usually have to
  include a header file provided by the library and then explicitly
  link the library with the linker ``-l`` option. On Windows, header
  files usually contain pragmas that list needed libraries. Compilers
  copy that information to object files, so that linkers can
  automatically link needed libraries. ``--dependent-library`` is
  added for implementing that Windows semantics on Unix.
  (`r360984 <https://reviews.llvm.org/rL360984>`_)

* AArch64 BTI and PAC are supported.
  (`r362793 <https://reviews.llvm.org/rL362793>`_)

* lld now supports replacing ``JAL`` with ``JALX`` instructions in case
  of MIPS-microMIPS cross-mode jumps.
  (`r354311 <https://reviews.llvm.org/rL354311>`_)

* lld now creates LA25 thunks for MIPS R6 code.
  (`r354312 <https://reviews.llvm.org/rL354312>`_)

* Put MIPS-specific .reginfo, .MIPS.options, and .MIPS.abiflags sections
  into corresponding PT_MIPS_REGINFO, PT_MIPS_OPTIONS, and PT_MIPS_ABIFLAGS
  segments.

* The quality of RISC-V and PowerPC ports have greatly improved. Many
  applications can now be linked by lld. PowerPC64 is now almost
  production ready.

* The Linux kernel for arm32_7, arm64, ppc64le and x86_64 can now be
  linked by lld.

* x86-64 TLSDESC is supported.
  (`r361911 <https://reviews.llvm.org/rL361911>`_,
  `r362078 <https://reviews.llvm.org/rL362078>`_)

* DF_STATIC_TLS flag is set for i386 and x86-64 when needed.
  (`r353293 <https://reviews.llvm.org/rL353293>`_,
  `r353378 <https://reviews.llvm.org/rL353378>`_)

* The experimental partitioning feature is added to allow a program to
  be split into multiple pieces.

  The feature allows you to semi-automatically split a single program
  into multiple ELF files called "partitions". Since all partitions
  share the same memory address space and don't use PLT/GOT, split
  programs run as fast as regular programs.

  With the mechanism, you can start a program only with a "main"
  partition and load remaining partitions on-demand. For example, you
  can split a web browser into a main partition and a PDF reader
  sub-partition and load the PDF reader partition only when a user
  tries to open a PDF file.

  See `the documentation <Partitions.html>`_ for more information.

* If "-" is given as an output filename, lld writes the final result
  to the standard output. Previously, it created a file "-" in the
  current directory.
  (`r351852 <https://reviews.llvm.org/rL351852>`_)

* ``-z ifunc-noplt`` option is added to reduce IFunc function call
  overhead in a freestanding environment such as the OS kernel.

  Functions resolved by the IFunc mechanism are usually dispatched via
  PLT and thus slower than regular functions because of the cost of
  indirection. With ``-z ifunc-noplt``, you can eliminate it by doing
  text relocations at load-time. You need a special loader to utilize
  this feature. This feature is added for the FreeBSD kernel but can
  be used by any operating systems.
  (`r360685 <https://reviews.llvm.org/rL360685>`_)

* ``--undefined-glob`` option is added. The new option is an extension
  to ``--undefined`` to take a glob pattern instead of a single symbol
  name.
  (`r363396 <https://reviews.llvm.org/rL363396>`_)


COFF Improvements
-----------------

* Like the ELF driver, lld-link now has typo suggestions for flags.
  (`r361518 <https://reviews.llvm.org/rL361518>`_)

* lld-link now correctly reports duplicate symbol errors for object
  files that were compiled with ``/Gy``.
  (`r352590 <https://reviews.llvm.org/rL352590>`_)

* lld-link now correctly reports duplicate symbol errors when several
  resource (.res) input files define resources with the same type,
  name and language.  This can be demoted to a warning using
  ``/force:multipleres``.
  (`r359829 <https://reviews.llvm.org/rL359829>`_)

* lld-link now rejects more than one resource object input files,
  matching link.exe. Previously, lld-link would silently ignore all
  but one.  If you hit this: Don't pass resource object files to the
  linker, instead pass res files to the linker directly. Don't put
  resource files in static libraries, pass them on the command line.
  (`r359749 <https://reviews.llvm.org/rL359749>`_)

* Having more than two ``/natvis:`` now works correctly; it used to not
  work for larger binaries before.
  (`r327895 <https://reviews.llvm.org/rL327895>`_)

* Undefined symbols are now printed only in demangled form. Pass
  ``/demangle:no`` to see raw symbol names instead.
  (`r355878 <https://reviews.llvm.org/rL355878>`_)

* Several speed and memory usage improvements.

* lld-link now supports resource object files created by GNU windres and
  MS cvtres, not only llvm-cvtres.

* The generated thunks for delayimports now share the majority of code
  among thunks, significantly reducing the overhead of using delayimport.
  (`r365823 <https://reviews.llvm.org/rL365823>`_)

* ``IMAGE_REL_ARM{,64}_REL32`` relocations are supported.
  (`r352325 <https://reviews.llvm.org/rL352325>`_)

* Range extension thunks for AArch64 are now supported, so lld can
  create large executables for Windows/ARM64.
  (`r352929 <https://reviews.llvm.org/rL352929>`_)

* The following flags have been added:
  ``/functionpadmin`` (`r354716 <https://reviews.llvm.org/rL354716>`_),
  ``/swaprun:`` (`r359192 <https://reviews.llvm.org/rL359192>`_),
  ``/threads:no`` (`r355029 <https://reviews.llvm.org/rL355029>`_),
  ``/filealign`` (`r361634 <https://reviews.llvm.org/rL361634>`_)

WebAssembly Improvements
------------------------

* Imports from custom module names are supported.
  (`r352828 <https://reviews.llvm.org/rL352828>`_)

* Symbols that are in llvm.used are now exported by default.
  (`r353364 <https://reviews.llvm.org/rL353364>`_)

* Initial support for PIC and dynamic linking has landed.
  (`r357022 <https://reviews.llvm.org/rL357022>`_)

* wasm-ld now add ``__start_``/``__stop_`` symbols for data sections.
  (`r361236 <https://reviews.llvm.org/rL361236>`_)

* wasm-ld now doesn't report an error on archives without a symbol index.
  (`r364338 <https://reviews.llvm.org/rL364338>`_)

* The following flags have been added:
  ``--emit-relocs`` (`r361635 <https://reviews.llvm.org/rL361635>`_),
  ``--wrap`` (`r361639 <https://reviews.llvm.org/rL361639>`_),
  ``--trace`` and ``--trace-symbol``
  (`r353264 <https://reviews.llvm.org/rL353264>`_).


MinGW Improvements
------------------

* lld now correctly links crtend.o as the last object file, handling
  terminators for the sections such as .eh_frame properly, fixing
  DWARF exception handling with libgcc and gcc's crtend.o.

* lld now also handles DWARF unwind info generated by GCC, when linking
  with libgcc.

* PDB output can be requested without manually specifying the PDB file
  name, with the new option ``-pdb=`` with an empty value to the option.
  (The old existing syntax ``-pdb <filename>`` was more cumbersome to use
  with an empty parameter value.)

* ``--no-insert-timestamp`` option is added as an alias to ``/timestamp:0``.
  (`r353145 <https://reviews.llvm.org/rL353145>`_)

* Many more GNU ld options are now supported, which e.g. allows the lld
  MinGW frontend to be called by GCC.

* The following options are added: ``--exclude-all-symbols``,
  ``--appcontainer``, ``--undefined``
