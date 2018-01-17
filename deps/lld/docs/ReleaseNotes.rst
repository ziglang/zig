=======================
LLD 6.0.0 Release Notes
=======================

.. contents::
    :local:

.. warning::
   These are in-progress notes for the upcoming LLVM 6.0.0 release.
   Release notes for previous releases can be found on
   `the Download Page <http://releases.llvm.org/download.html>`_.

Introduction
============

This document contains the release notes for the LLD linker, release 6.0.0.
Here we describe the status of LLD, including major improvements
from the previous release. All LLD releases may be downloaded
from the `LLVM releases web site <http://llvm.org/releases/>`_.

Non-comprehensive list of changes in this release
=================================================

ELF Improvements
----------------

* Item 1.

COFF Improvements
-----------------

* A GNU ld style frontend for the COFF linker has been added for MinGW.
  In MinGW environments, the linker is invoked with GNU ld style parameters;
  which LLD previously only supported when used as an ELF linker. When
  a PE/COFF target is chosen, those parameters are rewritten into the
  lld-link style parameters and the COFF linker is invoked instead.

* Initial support for the ARM64 architecture has been added.

MachO Improvements
------------------

* Item 1.
