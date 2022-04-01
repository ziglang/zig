Writing extension modules for pypy
==================================

This document tries to explain how to interface the PyPy python interpreter
with any external library.

Right now, there are the following possibilities of providing
third-party modules for the PyPy python interpreter (in order, from most
directly useful to most messy to use with PyPy):

* Write them in pure Python and use CFFI_.

* Write them in pure Python and use ctypes_.

* Write them in C++ and bind them through  cppyy_ using Cling.

* Write them as `RPython mixed modules`_.


CFFI
----

CFFI__ is the recommended way.  It is a way to write pure Python code
that accesses C libraries.  The idea is to support either ABI- or
API-level access to C --- so that you can sanely access C libraries
without depending on details like the exact field order in the C
structures or the numerical value of all the constants.  It works on
both CPython (as a separate ``python -mpip install cffi``) and on PyPy, where it
is included by default.

PyPy's JIT does a quite reasonable job on the Python code that call C
functions or manipulate C pointers with CFFI.  (As of PyPy 2.2.1, it
could still be improved, but is already good.)

See the documentation here__.

.. __: https://cffi.readthedocs.org/
.. __: https://cffi.readthedocs.org/


CTypes
------

The goal of the ctypes module of PyPy is to be as compatible as possible
with the `CPython ctypes`_ version.  It works for large examples, such
as pyglet.  PyPy's implementation is not strictly 100% compatible with
CPython, but close enough for most cases.
More (but older) information is available :doc:`here <discussion/ctypes-implementation>`.
Also, ctypes' performance is not as good as CFFI's.

.. _CPython ctypes: https://docs.python.org/library/ctypes.html

PyPy implements ctypes as pure Python code around two built-in modules
called ``_rawffi`` and ``_rawffi.alt``, which give a very low-level binding to
the C library libffi_.  Nowadays it is not recommended to use directly
these two modules.

.. _libffi: https://sourceware.org/libffi/


cppyy
-----

For C++, _cppyy_ is an automated bindings generator available for both
PyPy and CPython.
_cppyy_ relies on declarations from C++ header files to dynamically
construct Python equivalent classes, functions, variables, etc.
It is designed for use by large scale programs and supports modern C++.
With PyPy, it leverages the built-in ``_cppyy`` module, allowing the JIT to
remove most of the cross-language overhead.

To install, run ``<pypy> -mpip install cppyy``.
Further details are available in the `full documentation`_.

.. _`full documentation`: https://cppyy.readthedocs.org/


RPython Mixed Modules
---------------------

This is the internal way to write built-in extension modules in PyPy.
It cannot be used by any 3rd-party module: the extension modules are
*built-in*, not independently loadable DLLs.

This is reserved for special cases: it gives direct access to e.g. the
details of the JIT, allowing us to tweak its interaction with user code.
This is how the numpy module is being developed.


