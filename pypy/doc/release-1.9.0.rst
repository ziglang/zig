====================
PyPy 1.9 - Yard Wolf
====================

We're pleased to announce the 1.9 release of PyPy. This release brings mostly
bugfixes, performance improvements, other small improvements and overall
progress on the `numpypy`_ effort.
It also brings an improved situation on Windows and OS X.

You can download the PyPy 1.9 release here:

    https://pypy.org/download.html 

.. _`numpypy`: https://pypy.org/numpydonate.html


What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7. It's fast (`pypy 1.9 and cpython 2.7.2`_ performance comparison)
due to its integrated tracing JIT compiler.

This release supports x86 machines running Linux 32/64, Mac OS X 64 or
Windows 32.  Windows 64 work is still stalling, we would welcome a volunteer
to handle that.

.. _`pypy 1.9 and cpython 2.7.2`: https://speed.pypy.org


Thanks to our donors
====================

But first of all, we would like to say thank you to all people who
donated some money to one of our four calls:

  * `NumPy in PyPy`_ (got so far $44502 out of $60000, 74%)

  * `Py3k (Python 3)`_ (got so far $43563 out of $105000, 41%)

  * `Software Transactional Memory`_ (got so far $21791 of $50400, 43%)

  * as well as our general PyPy pot.

Thank you all for proving that it is indeed possible for a small team of
programmers to get funded like that, at least for some
time.  We want to include this thank you in the present release
announcement even though most of the work is not finished yet.  More
precisely, neither Py3k nor STM are ready to make it in an official release
yet: people interested in them need to grab and (attempt to) translate
PyPy from the corresponding branches (respectively ``py3k`` and
``stm-thread``).

.. _`NumPy in PyPy`: https://pypy.org/numpydonate.html
.. _`Py3k (Python 3)`: https://pypy.org/py3donate.html
.. _`Software Transactional Memory`: https://pypy.org/tmdonate.html

Highlights
==========

* This release still implements Python 2.7.2.

* Many bugs were corrected for Windows 32 bit.  This includes new
  functionality to test the validity of file descriptors; and
  correct handling of the calling convensions for ctypes.  (Still not
  much progress on Win64.) A lot of work on this has been done by Matti Picus
  and Amaury Forgeot d'Arc.

* Improvements in ``cpyext``, our emulator for CPython C extension modules.
  For example PyOpenSSL should now work.  We thank various people for help.

* Sets now have strategies just like dictionaries. This means for example
  that a set containing only ints will be more compact (and faster).

* A lot of progress on various aspects of ``numpypy``. See the `numpy-status`_
  page for the automatic report.

* It is now possible to create and manipulate C-like structures using the
  PyPy-only ``_ffi`` module.  The advantage over using e.g. ``ctypes`` is that
  ``_ffi`` is very JIT-friendly, and getting/setting of fields is translated
  to few assembler instructions by the JIT. However, this is mostly intended
  as a low-level backend to be used by more user-friendly FFI packages, and
  the API might change in the future. Use it at your own risk.

* The non-x86 backends for the JIT are progressing but are still not
  merged (ARMv7 and PPC64).

* JIT hooks for inspecting the created assembler code have been improved.
  See `JIT hooks documentation`_ for details.

* ``select.kqueue`` has been added (BSD).

* Handling of keyword arguments has been drastically improved in the best-case
  scenario: proxy functions which simply forwards ``*args`` and ``**kwargs``
  to another function now performs much better with the JIT.

* List comprehension has been improved.

.. _`numpy-status`: https://buildbot.pypy.org/numpy-status/latest.html
.. _`JIT hooks documentation`: https://doc.pypy.org/en/latest/jit-hooks.html

JitViewer
=========

There will be a corresponding 1.9 release of JitViewer which is guaranteed
to work with PyPy 1.9. See the `JitViewer docs`_ for details.

.. _`JitViewer docs`: https://bitbucket.org/pypy/jitviewer

Cheers,
The PyPy Team
