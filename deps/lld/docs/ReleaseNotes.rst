=======================
LLD 7.0.0 Release Notes
=======================

.. contents::
    :local:

Introduction
============

This document contains the release notes for the lld linker, release 7.0.0.
Here we describe the status of lld, including major improvements
from the previous release. All lld releases may be downloaded
from the `LLVM releases web site <https://llvm.org/releases/>`_.

Non-comprehensive list of changes in this release
=================================================

ELF Improvements
----------------

* lld is now able to overcome MIPS GOT entries number limitation
  and generate multi-GOT if necessary.

* lld is now able to produce MIPS position-independent executable (PIE).

* Fixed MIPS TLS GOT entries for local symbols in shared libraries.

* Fixed calculation of MIPS GP relative relocations
  in case of relocatable output.

COFF Improvements
-----------------

* Improved correctness of exporting mangled stdcall symbols.

* Completed support for ARM64 relocations.

* Added support for outputting PDB debug info for MinGW targets.

* Improved compatibility of output binaries with GNU binutils objcopy/strip.
