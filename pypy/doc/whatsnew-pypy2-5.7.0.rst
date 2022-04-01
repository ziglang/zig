=========================
What's new in PyPy2.7 5.7
=========================

.. this is a revision shortly after release-pypy2.7-v5.6
.. startrev: 7e9787939641


Since a while now, PyPy preserves the order of dictionaries and sets.
However, the set literal syntax ``{x, y, z}`` would by mistake build a
set with the opposite order: ``set([z, y, x])``.  This has been fixed.
Note that CPython is inconsistent too: in 2.7.12, ``{5, 5.0}`` would be
``set([5.0])``, but in 2.7.trunk it is ``set([5])``.  PyPy's behavior
changed in exactly the same way because of this fix.


.. branch: mappingproxy
.. branch: py3k-finish_time
.. branch: py3k-kwonly-builtin
.. branch: py3k_add_terminal_size
.. branch: testing-cleanup-py3k

.. branch: rpython-resync
Backport rpython changes made directly on the py3k and py3.5 branches.

.. branch: rpython-error-to-systemerror

Any uncaught RPython exception (from a PyPy bug) is turned into an
app-level SystemError.  This should improve the lot of users hitting an
uncaught RPython error.

.. branch: union-side-effects-2

Try to improve the consistency of RPython annotation unions.

.. branch: pytest-2.9.2

.. branch: clean-exported-state

Clean-ups in the jit optimizeopt

.. branch: conditional_call_value_4

Add jit.conditional_call_elidable(), a way to tell the JIT "conditonally
call this function" returning a result.

.. branch: desc-specialize

Refactor FunctionDesc.specialize() and related code (RPython annotator).

.. branch: raw-calloc

.. branch: issue2446

Assign ``tp_doc`` to the new TypeObject's type dictionary ``__doc__`` key
so it will be picked up by app-level objects of that type

.. branch: cling-support

Module cppyy now uses cling as its backend (Reflex has been removed). The
user-facing interface and main developer tools (genreflex, selection files,
class loader, etc.) remain the same.  A libcppyy_backend.so library is still
needed but is now available through PyPI with pip: PyPy-cppyy-backend.

The Cling-backend brings support for modern C++ (11, 14, etc.), dynamic
template instantations, and improved integration with CFFI for better
performance.  It also provides interactive C++ (and bindings to that).

.. branch: better-PyDict_Next

Improve the performance of ``PyDict_Next``. When trying ``PyDict_Next`` on a
typedef dict, the test exposed a problem converting a ``GetSetProperty`` to a
``PyGetSetDescrObject``. The other direction seem to be fully implemented.
This branch made a minimal effort to convert the basic fields to avoid
segfaults, but trying to use the ``PyGetSetDescrObject`` will probably fail.

.. branch: stdlib-2.7.13

Updated the implementation to match CPython 2.7.13 instead of 2.7.13.

.. branch: issue2444

Fix ``PyObject_GetBuffer`` and ``PyMemoryView_GET_BUFFER``, which leaked
memory and held references. Add a finalizer to CPyBuffer, add a
PyMemoryViewObject with a PyBuffer attached so that the call to 
``PyMemoryView_GET_BUFFER`` does not leak a PyBuffer-sized piece of memory.
Properly call ``bf_releasebuffer`` when not ``NULL``.

.. branch: boehm-rawrefcount

Support translations of cpyext with the Boehm GC (for special cases like
revdb).

.. branch: strbuf-as-buffer

Implement StringBuffer.get_raw_address (missing feature for the buffer protocol).
More generally it is now possible to obtain the address of any object (if it
is readonly) without pinning it.

.. branch: cpyext-cleanup
.. branch: api_func-refactor

Refactor cpyext initialisation.

.. branch: cpyext-from2

Fix a test failure introduced by strbuf-as-buffer

.. branch: cpyext-FromBuffer

Do not recreate the object in PyMemoryView_FromBuffer, rather pass it to
the returned PyMemoryViewObject, to take ownership of it. Fixes a ref leak.

.. branch: issue2464

Give (almost?) all GetSetProperties a valid __objclass__.

.. branch: TreeStain/fixed-typo-line-29-mostly-to-most-1484469416419
.. branch: TreeStain/main-lines-changed-in-l77-l83-made-para-1484471558033

.. branch: missing-tp_new

Improve mixing app-level classes in c-extensions, especially if the app-level
class has a ``tp_new`` or ``tp_dealloc``. The issue is that c-extensions expect
all the method slots to be filled with a function pointer, where app-level will
search up the mro for an appropriate function at runtime. With this branch we
now fill many more slots in the c-extenion type objects.
Also fix for c-extension type that calls ``tp_hash`` during initialization
(str, unicode types), and fix instantiating c-extension types from built-in
classes by enforcing an order of instaniation.

.. branch: rffi-parser-2

rffi structures in cpyext can now be created by parsing simple C headers.
Additionally, the cts object that holds the parsed information can act like
cffi's ffi objects, with the methods cts.cast() and cts.gettype().

.. branch: rpython-hash

Don't freeze hashes in the translated pypy.  In practice, that means
that we can now translate PyPy with the option --hash=siphash24 and get
the same hashes as CPython 3.5, which can be randomized (in a
crypographically good way).  It is the default in PyPy3.  The default of
PyPy2 remains unchanged: there are user programs out there that depend
on constant hashes (or even sometimes on specific hash results).

.. branch: dict-move-to-end

Our dicts, which are always ordered, now have an extra "method" for
Python 3.x which moves an item to first or last position.  In PyPy 3.5
it is the standard ``OrderedDict.move_to_end()`` method, but the
behavior is also available on Python 2.x or for the ``dict`` type by
calling ``__pypy__.move_to_end(dict, key, last=True)``.


.. branch optinfo-into-bridges-3

Improve the optimization of branchy Python code by retaining more information
across failing guards.


.. branch: space-newtext

Internal refactoring of ``space.wrap()``, which is now replaced with
explicitly-typed methods.  Notably, there are now ``space.newbytes()``
and ``space.newtext()``: these two methods are identical on PyPy 2.7 but
not on PyPy 3.x.  The latter is used to get an app-level unicode string
by decoding the RPython string, assumed to be utf-8.

.. branch: space-wrap

.. branch: fix_bool_restype

Fix for ``ctypes.c_bool``-returning ctypes functions

.. branch: py3.5-text-utf8

space.text_w now encodes to utf-8 not preserving surrogates.

.. branch: fix-cpyext-releasebuffer

Improve handling of the Py3-style buffer slots in cpyext: fix memoryviews
keeping objects alive forever (missing decref), and make sure that
bf_releasebuffer is called when it should, e.g. from PyBuffer_Release.

.. branch: fix-global

Fix bug (bad reported info) when asked to translate SyntaxWarning to
SyntaxError.

.. branch: optinfo-into-bridges-3

Improve the optimization of branchy Python code by retaining more
information across failing guards. This is done by appending some
carefully encoded extra information into the resume code.

.. branch: shadowstack-perf-2

Two changes that together bring the performance of shadowstack close to
asmgcc---close enough that we can now make shadowstack the default even
on Linux.  This should remove a whole class of rare bugs introduced by
asmgcc.

.. branch: fniephaus/fix-typo-1488123166752
