===========================
What's new in PyPy3.7 7.3.6
===========================

.. this is the revision after release-pypy3.6-v7.3.3
.. startrev: a57ea1224248

.. branch: hpy

Merge latest hpy

.. branch: py3.7-errormsg-improvements

Produce better error messages for IndentationErrors (showing statement and line
that opened the block that is missing), AttributeErrors and NameErrors (showing
suggestions which name could have been meant instead in case of typos). This
follows the upcoming CPython 3.10 features.

.. branch: distutils-implementation

Instantiate the ``distutils.command.install`` schema for the python
implementation (issue 3436)

.. branch: py3.7-bpo-30245

Avoid overflow in ``struct.pack_into`` error message (BPO 30245)


.. branch: py3.7-newtext-const-arg-caching

Reduce memory allocations at runtime caused by interpreter-internal
identifiers.

.. branch: py3.7-import-speedup

Speep up cached imports by re-implementing (a subset of) BPO-22557. This brings
it very close to PyPy2 standards.

.. branch: py3.7-ignore-finalizer-files-after-close

Make creation and destruction of many files cheaper: don't call ``.__del__`` of
streams that had their ``.close()`` method called (and aren't user defined
classes).

.. branch: multiarch

Add a ``sys.implementation._multiarch`` field like CPython on linux, darwin via
``__pypy__.os._get_multiarch()``

.. branch: sysconfigdata

Add a ``lib_pypy/_sysconfigdata__*.py`` file like CPython on linux, darwin
during packaging via ``sysconfig._generate_posix_vars()`` (issue 3483).

.. branch: py3.8-reversed-dict
Implement ``reversed(dict)``
.. branch: py3.8-new-opcodes
Implement new opcodes that CPython 3.8 uses

.. branch: py3.8-buffer-gets-w_obj
Refactor the buffer implementation to add a ``.w_obj`` field to ``BufferView``.
.. branch: hpy-0.0.2

Update HPy backend to 0.0.2

.. branch: implement_timezone_c_api

Implement missing PyDateTimeAPI functions related to timezones (issue 3320)

.. branch: libffi-win64

Use libffi v3.3 like CPython instead of the very old ``libffi_msvc`` on windows

.. branch: compact-unicode

When creating a PyUnicodeObject, use the compact form to store the data
directly on the object and not via an additional buffer. This is used in
pythran via _PyUnicode_COMPACT_DATA even though it is a "private" interface.

.. branch: hpy-refactor-exceptions

Use the cpyext error indicator to implement HPy exceptions
