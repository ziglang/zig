=======================
LLD 6.0.0 Release Notes
=======================

.. contents::
    :local:

Introduction
============

This document contains the release notes for the lld linker, release 6.0.0.
Here we describe the status of lld, including major improvements
from the previous release. All lld releases may be downloaded
from the `LLVM releases web site <http://llvm.org/releases/>`_.

Non-comprehensive list of changes in this release
=================================================

ELF Improvements
----------------

* A lot of bugs and compatibility issues have been identified and fixed as a
  result of people using lld 5.0 as a standard system linker. In particular,
  linker script and version script support has significantly improved that
  it should be able to handle almost all scripts.

* A mitigation for Spectre v2 has been implemented. If you pass ``-z
  retpolineplt``, lld uses RET instruction instead of JMP instruction in PLT.
  The option is available for x86 and x86-64.

* Identical Code Folding (ICF) now de-duplicates .eh_frame entries, so lld now
  generates slightly smaller outputs than before when you pass ``--icf=all``.

* Analysis for ``--as-needed`` is now done after garbage collection. If garbage
  collector eliminates all sections that use some library, that library is
  eliminated from DT_NEEDED tags. Previously, the analysis ran before garbage
  collection.

* Size of code segment is now always rounded up to page size to make sure that
  unused bytes at end of code segment is filled with trap instructions (such
  as INT3) instead of zeros.

* lld is now able to generate Android-style compact dynamic relocation table.
  You can turn on the feature by passing ``--pack-dyn-relocs=android``.

* Debug information is used in more cases when reporting errors.

* ``--gdb-index`` gets faster than before.

* String merging is now multi-threaded, which makes ``-O2`` faster.

* ``--hash-style=both`` is now default instead of ``--hash-style=sysv`` to
  match the behavior of recent versions of GNU linkers.

* ARM PLT entries automatically use short or long variants.

* lld can now identify and patch a code sequence that triggers AArch64 errata 843419.
  Add ``--fix-cortex-a53-843419`` to enable the feature.

* lld can now generate thunks for out of range thunks.

* MIPS port now generates all output dynamic relocations using Elf_Rel format only.

* Added handling of the R_MIPS_26 relocation in case of N32/N64 ABIs and
  generating proper PLT entries.

* The following options have been added: ``--icf=none`` ``-z muldefs``
  ``--plugin-opt`` ``--no-eh-frame-hdr`` ``--no-gdb-index``
  ``--orphan-handling={place,discard,warn,error}``
  ``--pack-dyn-relocs={none,android}`` ``--no-omagic``
  ``--no-print-gc-sections`` ``--ignore-function-address-equality`` ``-z
  retpolineplt`` ``--print-icf-sections`` ``--no-pie``

COFF Improvements
-----------------

* A GNU ld style frontend for the COFF linker has been added for MinGW.
  In MinGW environments, the linker is invoked with GNU ld style parameters;
  which lld previously only supported when used as an ELF linker. When
  a PE/COFF target is chosen, those parameters are rewritten into the
  lld-link style parameters and the COFF linker is invoked instead.

* Initial support for the ARM64 architecture has been added.

* New ``--version`` flag.

* Significantly improved support for writing PDB Files.

* New ``--rsp-quoting`` flag, like ``clang-cl``.

* ``/manifestuac:no`` no longer incorrectly disables ``/manifestdependency:``.

* Only write ``.manifest`` files if ``/manifest`` is passed.

WebAssembly Improvements
------------------------

* Initial version of WebAssembly support has landed. You can invoke the
  WebAssembly linker by ``wasm-ld``.
