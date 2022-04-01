=========================
What's new in PyPy2.7 5.4
=========================

.. this is a revision shortly after release-pypy2.7-v5.3
.. startrev: 873218a739f1

.. 418b05f95db5

Improve CPython compatibility for ``is``. Now code like ``if x is ():``
works the same way as it does on CPython.  See https://pypy.readthedocs.io/en/latest/cpython_differences.html#object-identity-of-primitive-values-is-and-id .

.. pull request #455

Add sys.{get,set}dlopenflags, for cpyext extensions.

.. branch: fix-gen-dfa

Resolves an issue with the generator script to build the dfa for Python syntax.

.. branch: z196-support

Fixes a critical issue in the register allocator and extends support on s390x.
PyPy runs and translates on the s390x revisions z10 (released February 2008, experimental)
and z196 (released August 2010) in addition to zEC12 and z13.
To target e.g. z196 on a zEC12 machine supply CFLAGS="-march=z196" to your shell environment.

.. branch: s390x-5.3-catchup

Implement the backend related changes for s390x.

.. branch: incminimark-ll_assert
.. branch: vmprof-openbsd

.. branch: testing-cleanup

Simplify handling of interp-level tests and make it more forward-
compatible.

.. branch: pyfile-tell

Sync w_file with the c-level FILE* before returning FILE* in PyFile_AsFile

.. branch: rw-PyString_AS_STRING

Allow rw access to the char* returned from PyString_AS_STRING, also refactor
PyStringObject to look like cpython's and allow subclassing PyString_Type and
PyUnicode_Type

.. branch: save_socket_errno

Bug fix: if ``socket.socket()`` failed, the ``socket.error`` did not show
the errno of the failing system call, but instead some random previous
errno.

.. branch: PyTuple_Type-subclass

Refactor PyTupleObject to look like cpython's and allow subclassing 
PyTuple_Type

.. branch: call-via-pyobj

Use offsets from PyTypeObject to find actual c function to call rather than
fixed functions, allows function override after PyType_Ready is called

.. branch: issue2335

Avoid exhausting the stack in the JIT due to successive guard
failures in the same Python function ending up as successive levels of
RPython functions, while at app-level the traceback is very short

.. branch: use-madv-free

Try harder to memory to the OS.  See e.g. issue #2336.  Note that it does
not show up as a reduction of the VIRT column in ``top``, and the RES
column might also not show the reduction, particularly on Linux >= 4.5 or
on OS/X: it uses MADV_FREE, which only marks the pages as returnable to
the OS if the memory is low.

.. branch: cpyext-slotdefs2

Fill in more slots when creating a PyTypeObject from a W_TypeObject
More slots are still TBD, like tp_print and richcmp

.. branch: json-surrogates

Align json module decode with the cpython's impl, fixes issue 2345

.. branch: issue2343

Copy CPython's logic more closely for handling of ``__instancecheck__()``
and ``__subclasscheck__()``.  Fixes issue 2343.

.. branch: msvcrt-cffi

Rewrite the Win32 dependencies of 'subprocess' to use cffi instead
of ctypes. This avoids importing ctypes in many small programs and
scripts, which in turn avoids enabling threads (because ctypes
creates callbacks at import time, and callbacks need threads).

.. branch: new-jit-log

The new logging facility that integrates with and adds features to vmprof.com.

.. branch: jitlog-32bit

Resolve issues to use the new logging facility on a 32bit system

.. branch: ep2016sprint

Trying harder to make hash(-1) return -2, like it does on CPython

.. branch: jitlog-exact-source-lines

Log exact line positions in debug merge points.

.. branch: null_byte_after_str

Allocate all RPython strings with one extra byte, normally unused.
It is used to hold a final zero in case we need some ``char *``
representation of the string, together with checks like ``not
can_move()`` or object pinning. Main new thing that this allows:
``ffi.from_buffer(string)`` in CFFI.  Additionally, and most
importantly, CFFI calls that take directly a string as argument don't
copy the string any more---this is like CFFI on CPython.

.. branch: resource_warning

Add a new command line option -X track-resources which will produce
ResourceWarnings when the GC closes unclosed files and sockets.

.. branch: cpyext-realloc

Implement PyObject_Realloc

.. branch: inline-blocks

Improve a little bit the readability of the generated C code

.. branch: improve-vmprof-testing

Improved vmprof support: now tries hard to not miss any Python-level
frame in the captured stacks, even if there is the metainterp or
blackhole interp involved.  Also fix the stacklet (greenlet) support.

.. branch: py2-mappingproxy

``type.__dict__`` now returns a ``dict_proxy`` object, like on CPython.
Previously it returned what looked like a regular dict object (but it
was already read-only).


.. branch: const-fold-we-are-jitted

Reduce the size of the generated C code by constant-folding ``we_are_jitted``
in non-jitcode.

.. branch: memoryview-attributes

Support for memoryview attributes (format, itemsize, ...).
Extends the cpyext emulation layer.

.. branch: redirect-assembler-jitlog

Log more information to properly rebuild the redirected traces in jitviewer.

.. branch: cpyext-subclass

Copy Py_TPFLAGS_CHECKTYPES, Py_TPFLAGS_HAVE_INPLACEOPS when inheriting
