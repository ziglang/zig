================================
PyPy 2.5.1 - Pineapple Bromeliad
================================

We're pleased to announce PyPy 2.5.1, Pineapple `Bromeliad`_ following on the heels of 2.5.0

You can download the PyPy 2.5.1 release here:

    https://pypy.org/download.html

We would like to thank our donors for the continued support of the PyPy
project, and for those who donate to our three sub-projects, as well as our
volunteers and contributors.  
We've shown quite a bit of progress, but we're slowly running out of funds.
Please consider donating more, or even better convince your employer to donate,
so we can finish those projects! The three sub-projects are:

* `Py3k`_ (supporting Python 3.x): We have released a Python 3.2.5 compatible version
   we call PyPy3 2.4.0, and are working toward a Python 3.3 compatible version

* `STM`_ (software transactional memory): We have released a first working version,
  and continue to try out new promising paths of achieving a fast multithreaded Python

* `NumPy`_ which requires installation of our fork of upstream numpy,
  available `on bitbucket`_

.. _`Bromeliad`: https://xkcd.com/1498
.. _`Py3k`: https://pypy.org/py3donate.html
.. _`STM`: https://pypy.org/tmdonate2.html
.. _`NumPy`: https://pypy.org/numpydonate.html
.. _`on bitbucket`: https://www.bitbucket.org/pypy/numpy

We would also like to encourage new people to join the project. PyPy has many
layers and we need help with all of them: `PyPy`_ and `Rpython`_ documentation
improvements, tweaking popular `modules`_ to run on pypy, or general `help`_ with making
Rpython's JIT even better.

.. _`PyPy`: https://doc.pypy.org 
.. _`Rpython`: https://rpython.readthedocs.org
.. _`modules`: https://doc.pypy.org/en/latest/project-ideas.html#make-more-python-modules-pypy-friendly
.. _`help`: https://doc.pypy.org/en/latest/project-ideas.html

What is PyPy?
=============

PyPy is a very compliant Python interpreter, almost a drop-in replacement for
CPython 2.7. It's fast (`pypy and cpython 2.7.x`_ performance comparison)
due to its integrated tracing JIT compiler.

This release supports **x86** machines on most common operating systems
(Linux 32/64, Mac OS X 64, Windows, and OpenBSD),
as well as newer **ARM** hardware (ARMv6 or ARMv7, with VFPv3) running Linux.

While we support 32 bit python on Windows, work on the native Windows 64
bit python is still stalling, we would welcome a volunteer
to `handle that`_.

.. _`pypy and cpython 2.7.x`: https://speed.pypy.org
.. _`handle that`: https://doc.pypy.org/en/latest/windows.html#what-is-missing-for-a-full-64-bit-translation

Highlights 
==========

* The past months have seen pypy mature and grow, as rpython becomes the goto
  solution for writing fast dynamic language interpreters. Our separation of
  Rpython and the python interpreter PyPy is now much clearer in the
  `PyPy documentation`_  and we now have seperate `RPython documentation`_.
  Tell us what still isn't clear, or even better help us improve the documentation.

* We merged version 2.7.9 of python's stdlib. From the python release notice:

  * The entirety of Python 3.4's `ssl module`_ has been backported. 
    See `PEP 466`_ for justification.

  * HTTPS certificate validation using the system's certificate store is now
    enabled by default. See `PEP 476`_ for details.

  * SSLv3 has been disabled by default in httplib and its reverse dependencies
    due to the `POODLE attack`_.

  * The `ensurepip module`_ has been backported, which provides the pip
    package manager in every Python 2.7 installation. See `PEP 477`_.

* The garbage collector now ignores parts of the stack which did not change
  since the last collection, another performance boost

* errno and LastError are saved around cffi calls so things like pdb will not
  overwrite it

* We continue to asymptotically approach a score of 7 times faster than cpython
  on our benchmark suite, we now rank 6.98 on latest runs

* Issues reported with our previous release were resolved_ after reports from users on
  our issue tracker at https://bitbucket.org/pypy/pypy/issues or on IRC at
  #pypy.

.. _`PyPy documentation`: https://doc.pypy.org
.. _`RPython documentation`: https://rpython.readthedocs.org
.. _`ssl module`: https://docs.python.org/3/library/ssl.html
.. _`PEP 466`: https://www.python.org/dev/peps/pep-0466
.. _`PEP 476`: https://www.python.org/dev/peps/pep-0476
.. _`PEP 477`: https://www.python.org/dev/peps/pep-0477
.. _`POODLE attack`: https://www.imperialviolet.org/2014/10/14/poodle.html
.. _`ensurepip module`: https://docs.python.org/2/library/ensurepip.html
.. _resolved: https://doc.pypy.org/en/latest/whatsnew-2.5.1.html

Please try it out and let us know what you think. We welcome
success stories, `experiments`_,  or `benchmarks`_, we know you are using PyPy, please tell us about it!

Cheers

The PyPy Team

.. _`experiments`: https://morepypy.blogspot.com/2015/02/experiments-in-pyrlang-with-rpython.html
.. _`benchmarks`: https://mithrandi.net/blog/2015/03/axiom-benchmark-results-on-pypy-2-5-0
