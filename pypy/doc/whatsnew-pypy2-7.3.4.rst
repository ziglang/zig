===========================
What's new in PyPy2.7 7.3.4
===========================

.. this is a revision shortly after release-pypy-7.3.3
.. startrev: de512cf13506

.. branch: rpython-error_value
.. branch: hpy-error-value
   
Introduce @rlib.objectmodel.llhelper_error_value, will is used by HPy

.. branch: new-ci-image

CI: Add a Dockerfile for CI to prevent hitting pull limits on docker hub

.. branch: issue-3333

Fix xml.etree.ElementTree assigning default attribute values: issue 3333

.. branch: rpython-rsre-for-37

Support for the new format of regular expressions in Python 3.7

.. branch: rpy-cparser

Upstream internal cparser tool from pypy/ to rpython/


.. branch: win64

Change rpython and pypy to enable translating 64-bit windows


.. branch: rpython-error_value

Introduce @rlib.objectmodel.llhelper_error_value, will be used by HPy

.. branch: add-rffi-constcharpsize2str

Add ``rffi.constcharpsize2str``

.. branch: document-win64

Refactor documentation of win64 from future plans to what was executed

.. branch: sync-distutils

Backport msvc detection from python3, which probably breaks using Visual Studio
2008 (MSVC9, or the version that used to be used to build CPython2.7 on
Windows)

.. branch: py2.7-winreg

Backport fixes to winreg adding reflection and fix for passing None (bpo
21151).

.. branch: pymodule_new-const-charp

Change parameter type of ``PyModule_New`` to ``const char*``, add
``PyModule_Check`` and ``PyModule_CheckExact``

.. branch: rpython-never-allocate

Introduce a ``@never_allocate`` class decorator, which ensure that a certain
RPython class is never actually instantiated at runtime. Useful to ensure that
e.g. it's always constant-folded away

.. branch: map-improvements

Optimize instances with integer or float fields to have more efficent field
reads and writes. They also use less memory if they have at least two such
fields.

.. branch: win-tcl8.6

Update the version of Tk/Tcl on windows to 8.6

.. branch: big-sur-dyld-cache

Backport changes to ``_ctypes`` needed for maxos BigSur from py3.7

.. branch: cppyy-packaging

Updated the API to the latest cppyy_backend (1.14.2), made all types used
consistent to avoid void*/long casting problems on Win64, and added several
new "builtin" types (wide chars, complex, etc.).


.. branch: intbound-improvements-3

Refactor the intbound analysis in the JIT

.. branch: issue-3404

Fix ``PyObject_Format`` for type objects


.. branch: string-algorithmic-optimizations

Faster str.replace and bytes.replace implementations.

.. branch: vmprof-aarch64

Enable vmprof on arm64

.. branch: icon-aliasing

Improve pypy.ico
