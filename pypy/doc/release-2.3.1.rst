=================================================
PyPy 2.3.1 - Terrestrial Arthropod Trap Revisited
=================================================

We're pleased to announce PyPy 2.3.1, a feature-and-bugfix improvement over our
recent release last month.

This release contains several bugfixes and enhancements.

You can download the PyPy 2.3.1 release here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project, and for those who donate to our three sub-projects.
We've shown quite a bit of progress 
but we're slowly running out of funds.
Please consider donating more, or even better convince your employer to donate,
so we can finish those projects!  The three sub-projects are:

* `STM`_ (software transactional memory): a preview will be released very soon,
  once we fix a few bugs

* `NumPy`_ which requires installation of our fork of upstream numpy, available `on bitbucket`_

.. _`STM`: https://pypy.org/tmdonate2.html
.. _`NumPy`: https://pypy.org/numpydonate.html
.. _`on bitbucket`: https://www.bitbucket.org/pypy/numpy   

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7. It's fast (`pypy 2.3 and cpython 2.7.x`_ performance comparison;
note that cpython's speed has not changed since 2.7.2)
due to its integrated tracing JIT compiler.

This release supports x86 machines running Linux 32/64, Mac OS X 64, Windows,
and OpenBSD,
as well as newer ARM hardware (ARMv6 or ARMv7, with VFPv3) running Linux. 

While we support 32 bit python on Windows, work on the native Windows 64
bit python is still stalling, we would welcome a volunteer
to `handle that`_.

.. _`pypy 2.3 and cpython 2.7.x`: https://speed.pypy.org
.. _`handle that`: https://doc.pypy.org/en/latest/windows.html#what-is-missing-for-a-full-64-bit-translation

Highlights
==========

Issues with the 2.3 release were resolved after being reported by users to
our new issue tracker at https://bitbucket.org/pypy/pypy/issues or on IRC at
#pypy. Here is a summary of the user-facing changes;
for more information see `whats-new`_:

* The built-in ``struct`` module was renamed to ``_struct``, solving issues
  with IDLE and other modules.

* Support for compilation with gcc-4.9

* A rewrite of packaging.py which produces our downloadable packages to
  modernize command line argument handling and to document third-party
  contributions in our LICENSE file

* A CFFI-based version of the gdbm module is now included in our downloads

* Many issues were resolved_ since the 2.3 release on May 8

.. _`whats-new`: https://doc.pypy.org/en/latest/whatsnew-2.3.1.html
.. _resolved: https://bitbucket.org/pypy/pypy/issues?status=resolved

Please try it out and let us know what you think. We especially welcome
success stories, we know you are using PyPy, please tell us about it!

Cheers

The PyPy Team

