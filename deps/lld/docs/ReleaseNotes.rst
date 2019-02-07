=======================
lld 8.0.0 Release Notes
=======================

.. contents::
    :local:

.. warning::
   These are in-progress notes for the upcoming LLVM 8.0.0 release.
   Release notes for previous releases can be found on
   `the Download Page <https://releases.llvm.org/download.html>`_.

Introduction
============

This document contains the release notes for the lld linker, release 8.0.0.
Here we describe the status of lld, including major improvements
from the previous release. All lld releases may be downloaded
from the `LLVM releases web site <https://llvm.org/releases/>`_.

Non-comprehensive list of changes in this release
=================================================

ELF Improvements
----------------

* lld now supports RISC-V. (`r339364
  <https://reviews.llvm.org/rL339364>`_)

* Default image base address has changed from 65536 to 2 MiB for i386
  and 4 MiB for AArch64 to make lld-generated executables work better
  with automatic superpage promotion. FreeBSD can promote contiguous
  non-superpages to a superpage if they are aligned to the superpage
  size. (`r342746 <https://reviews.llvm.org/rL342746>`_)

* lld/Hexagon can now link Linux kernel and musl libc for Qualcomm
  Hexagon ISA.

* Initial MSP430 ISA support has landed.

* The following flags have been added: ``-z interpose``, ``-z global``

* lld now uses the ``sigrie`` instruction as a trap instruction for
  MIPS targets.

COFF Improvements
-----------------

* PDB GUID is set to hash of PDB contents instead to a random byte
  sequence for build reproducibility.

* ``/pdbsourcepath:`` is now also used to make ``"cwd"``, ``"exe"``, ``"pdb"``
  in the env block of PDB outputs absolute if they are relative, and to make
  paths to obj files referenced in PDB outputs absolute if they are relative.
  Together with the previous item, this makes it possible to generate
  executables and PDBs that are fully deterministic and independent of the
  absolute path to the build directory, so that different machines building
  the same code in different directories can produce exactly the same output.

* The following flags have been added: ``/force:multiple``

* lld now can link against import libraries produced by GNU tools.

* lld can create thunks for ARM and ARM64, to allow linking larger images
  (over 16 MB for ARM and over 128 MB for ARM64)

* Several speed and memory usage improvements.

* lld now creates debug info for typedefs.

* lld can now link obj files produced by ``cl.exe /Z7 /Yc``.

* lld now understands ``%_PDB%`` and ``%_EXT%`` in ``/pdbaltpath:``.

* Undefined symbols are now printed in demangled form in addition to raw form.

MinGW Improvements
------------------

* lld can now automatically import data variables from DLLs without the
  use of the dllimport attribute.

* lld can now use existing normal MinGW sysroots with import libraries and
  CRT startup object files for GNU binutils. lld can handle most object
  files produced by GCC, and thus works as a drop-in replacement for
  ld.bfd in such environments. (There are known issues with linking crtend.o
  from GCC in setups with DWARF exceptions though, where object files are
  linked in a different order than with GNU ld, inserting a DWARF exception
  table terminator too early.)

* lld now supports COFF embedded directives for linking to nondefault
  libraries, just like for the normal COFF target.

* Actually generate a codeview build id signature, even if not creating a PDB.
  Previously, the ``--build-id`` option did not actually generate a build id
  unless ``--pdb`` was specified.

MachO Improvements
------------------

* Item 1.

WebAssembly Improvements
------------------------

* Add initial support for creating shared libraries (-shared).
  Note: The shared library format is still under active development and may
  undergo significant changes in future versions.
  See: https://github.com/WebAssembly/tool-conventions/blob/master/DynamicLinking.md
