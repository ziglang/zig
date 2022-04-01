================
PyPy3 2.1 beta 1
================

We're pleased to announce the first beta of the upcoming 2.1 release of
PyPy3. This is the first release of PyPy which targets Python 3 (3.2.3)
compatibility.

We would like to thank all of the people who donated_ to the `py3k proposal`_
for supporting the work that went into this and future releases.

You can download the PyPy3 2.1 beta 1 release here:

    https://pypy.org/download.html#pypy3-2-1-beta-1

Highlights
==========

* The first release of PyPy3: support for Python 3, targetting CPython 3.2.3!

  - There are some `known issues`_ including performance regressions (issues
    `#1540`_ & `#1541`_) slated to be resolved before the final release.

What is PyPy?
==============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7.3 or 3.2.3. It's fast due to its integrated tracing JIT compiler.

This release supports x86 machines running Linux 32/64, Mac OS X 64 or Windows
32. Also this release supports ARM machines running Linux 32bit - anything with
``ARMv6`` (like the Raspberry Pi) or ``ARMv7`` (like Beagleboard,
Chromebook, Cubieboard, etc.) that supports ``VFPv3`` should work.

Windows 64 work is still stalling and we would welcome a volunteer to handle
that.

How to use PyPy?
=================

We suggest using PyPy from a `virtualenv`_. Once you have a virtualenv
installed, you can follow instructions from `pypy documentation`_ on how
to proceed. This document also covers other `installation schemes`_.

.. _donated: https://morepypy.blogspot.com/2012/01/py3k-and-numpy-first-stage-thanks-to.html
.. _`py3k proposal`: https://pypy.org/py3donate.html
.. _`known issues`: https://bugs.pypy.org/issue?%40search_text=&title=py3k&%40columns=title&keyword=&id=&%40columns=id&creation=&creator=&release=&activity=&%40columns=activity&%40sort=activity&actor=&priority=&%40group=priority&status=-1%2C1%2C2%2C3%2C4%2C5%2C6&%40columns=status&assignedto=&%40columns=assignedto&%40pagesize=50&%40startwith=0&%40queryname=&%40old-queryname=&%40action=search
.. _`#1540`: https://bugs.pypy.org/issue1540
.. _`#1541`: https://bugs.pypy.org/issue1541
.. _`pypy documentation`: https://doc.pypy.org/en/latest/getting-started.html#installing-using-virtualenv
.. _`virtualenv`: https://www.virtualenv.org/en/latest/
.. _`installation schemes`: https://doc.pypy.org/en/latest/getting-started.html#installing-pypy


Cheers,
the PyPy team
