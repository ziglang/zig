============================
PyPy 1.8 - business as usual
============================

We're pleased to announce the 1.8 release of PyPy. As habitual this
release brings a lot of bugfixes, together with performance and memory
improvements over the 1.7 release. The main highlight of the release
is the introduction of `list strategies`_ which makes homogenous lists
more efficient both in terms of performance and memory. This release
also upgrades us from Python 2.7.1 compatibility to 2.7.2. Otherwise
it's "business as usual" in the sense that performance improved
roughly 10% on average since the previous release.

you can download the PyPy 1.8 release here:

    https://pypy.org/download.html

.. _`list strategies`: https://morepypy.blogspot.com/2011/10/more-compact-lists-with-list-strategies.html

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7. It's fast (`pypy 1.8 and cpython 2.7.1`_ performance comparison)
due to its integrated tracing JIT compiler.

This release supports x86 machines running Linux 32/64, Mac OS X 32/64 or
Windows 32. Windows 64 work has been stalled, we would welcome a volunteer
to handle that.

.. _`pypy 1.8 and cpython 2.7.1`: https://speed.pypy.org


Highlights
==========

* List strategies. Now lists that contain only ints or only floats should
  be as efficient as storing them in a binary-packed array. It also improves
  the JIT performance in places that use such lists. There are also special
  strategies for unicode and string lists.

* As usual, numerous performance improvements. There are many examples
  of python constructs that now should be faster; too many to list them.

* Bugfixes and compatibility fixes with CPython.

* Windows fixes.

* NumPy effort progress; for the exact list of things that have been done,
  consult the `numpy status page`_. A tentative list of things that has
  been done:

  * multi dimensional arrays

  * various sizes of dtypes

  * a lot of ufuncs

  * a lot of other minor changes

  Right now the `numpy` module is available under both `numpy` and `numpypy`
  names. However, because it's incomplete, you have to `import numpypy` first
  before doing any imports from `numpy`.

* New JIT hooks that allow you to hook into the JIT process from your python
  program. There is a `brief overview`_ of what they offer.

* Standard library upgrade from 2.7.1 to 2.7.2.

Ongoing work
============

As usual, there is quite a bit of ongoing work that either didn't make it to
the release or is not ready yet. Highlights include:

* Non-x86 backends for the JIT: ARMv7 (almost ready) and PPC64 (in progress)

* Specialized type instances - allocate instances as efficient as C structs,
  including type specialization

* More numpy work

* Since the last release there was a significant breakthrough in PyPy's
  fundraising. We now have enough funds to work on first stages of `numpypy`_
  and `py3k`_. We would like to thank again to everyone who donated.

* It's also probably worth noting, we're considering donations for the
  Software Transactional Memory project. You can read more about `our plans`_

Cheers,
The PyPy Team

.. _`brief overview`: https://doc.pypy.org/en/latest/jit-hooks.html
.. _`numpy status page`: https://buildbot.pypy.org/numpy-status/latest.html
.. _`numpy status update blog report`: https://morepypy.blogspot.com/2012/01/numpypy-status-update.html
.. _`numpypy`: https://pypy.org/numpydonate.html
.. _`py3k`: https://pypy.org/py3donate.html
.. _`our plans`: https://morepypy.blogspot.com/2012/01/transactional-memory-ii.html
