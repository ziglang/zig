.. _rffi:

Foreign Function Interface for RPython
======================================

Purpose
-------

This document describes an FFI for the RPython language, concentrating
on low-level backends like C. It describes
how to declare and call low-level (C) functions from RPython level.


Declaring low-level external function
-------------------------------------

Declaring external C function in RPython is easy, but one needs to
remember that low level functions eat :ref:`low level types <low-level-types>` (like
lltype.Signed or lltype.Array) and memory management must be done
by hand. To declare a function, we write::

  from rpython.rtyper.lltypesystem import rffi

  external_function = rffi.llexternal(name, args, result)

where:

* name - a C-level name of a function (how it would be rendered)
* args - low level types of args
* result - low level type of a result

You can pass in additional information about C-level includes,
libraries and sources by passing in the optional ``compilation_info``
parameter::

  from rpython.rtyper.lltypesystem import rffi
  from rpython.translator.tool.cbuild import ExternalCompilationInfo

  info = ExternalCompilationInfo(includes=[], libraries=[])

  external_function = rffi.llexternal(
    name, args, result, compilation_info=info
    )

See :source:`cbuild <rpython/translator/tool/cbuild.py>` for more info on ExternalCompilationInfo.


Types
-----

In :source:`rffi <rpython/rtyper/lltypesystem/rffi.py>` there are various declared types for C-structures, like CCHARP
(char*), SIZE_T (size_t) and others. Refer to file for details. 
Instances of non-primitive types must be alloced by hand, with call 
to lltype.malloc, and freed by lltype.free both with keyword argument 
flavor='raw'. There are several helpers like string -> char*
converter, refer to the source for details.


Registering function as external
--------------------------------

Once we provided low-level implementation of an external function,
would be nice to wrap call to some library function (like os.open)
with such a call. For this, there is a `register_external` routine,
located in :source:`extfunc.py <rpython/rtyper/extfunc.py>`, which provides nice API for declaring such a
functions, passing llimpl as an argument and eventually llfakeimpl
as a fake low-level implementation for tests performed by an llinterp.
