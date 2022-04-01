=========================
What's new in PyPy2.7 5.9
=========================

.. this is a revision shortly after release-pypy2.7-v5.8.0
.. startrev: 558bd00b3dd8

In previous versions of PyPy, ``instance.method`` would return always
the same bound method object, when gotten out of the same instance (as
far as ``is`` and ``id()`` can tell).  CPython doesn't do that.  Now
PyPy, like CPython, returns a different bound method object every time.
For ``type.method``, PyPy2 still returns always the same *unbound*
method object; CPython does it for built-in types but not for
user-defined types.

.. branch: cffi-complex
.. branch: cffi-char16-char32

The two ``cffi-*`` branches are part of the upgrade to cffi 1.11.

.. branch: ctypes_char_indexing

Indexing into char* behaves differently than CPython

.. branch: vmprof-0.4.8

Improve and fix issues with vmprof

.. branch: issue-2592

CPyext PyListObject.pop must return the value

.. branch: cpyext-hash_notimpl

If ``tp_hash`` is ``PyObject_HashNotImplemented``, set ``obj.__dict__['__hash__']`` to None

.. branch: cppyy-packaging

Renaming of ``cppyy`` to ``_cppyy``.
The former is now an external package installable with ``pip install cppyy``.

.. branch: Enable_PGO_for_clang

.. branch: nopax

At the end of translation, run ``attr -q -s pax.flags -V m`` on
PAX-enabled systems on the produced binary.  This seems necessary
because PyPy uses a JIT.

.. branch: pypy_bytearray

Improve ``bytearray`` performance (backported from py3.5)

.. branch: gc-del-limit-growth

Fix the bounds in the GC when allocating a lot of objects with finalizers,
fixes issue #2590

.. branch: arrays-force-less

Small improvement to optimize list accesses with constant indexes better by
throwing away information about them less eagerly.


.. branch: getarrayitem-into-bridges

More information is retained into a bridge: knowledge about the content of
arrays (at fixed indices) is stored in guards (and thus available at the
beginning of bridges). Also, some better feeding of information about known
fields of constant objects into bridges.

.. branch: cpyext-leakchecking

Add support for leakfinder in cpyext tests (disabled for now, due to too many
failures).

.. branch: pypy_swappedbytes

Added ``_swappedbytes_`` support for ``ctypes.Structure``

.. branch: pycheck-macros

Convert many Py*_Check cpyext functions into macros, like CPython.

.. branch: py_ssize_t

Explicitly use Py_ssize_t as the Signed type in pypy c-api

.. branch: cpyext-jit

Differentiate the code to call METH_NOARGS, METH_O and METH_VARARGS in cpyext:
this allows to write specialized code which is much faster than previous
completely generic version. Moreover, let the JIT to look inside the cpyext
module: the net result is that cpyext calls are up to 7x faster. However, this
is true only for very simple situations: in all real life code, we are still
much slower than CPython (more optimizations to come)
