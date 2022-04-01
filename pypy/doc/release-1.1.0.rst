==========================================
PyPy 1.1: Compatibility & Consolidation
==========================================

Welcome to the PyPy 1.1 release - the first release after the end of EU
funding. This release focuses on making PyPy's Python interpreter more
compatible with CPython (currently CPython 2.5) and on making the
interpreter more stable and bug-free.

Download page:
    
   https://codespeak.net/pypy/dist/pypy/doc/download.html

PyPy's Getting Started lives at:

   https://codespeak.net/pypy/dist/pypy/doc/getting-started.html

Highlights of This Release
==========================

  - More of CPython's standard library extension modules are supported,
    among them ctypes, sqlite3, csv, and many more. Most of these extension 
    modules are fully supported under Windows as well.

    https://codespeak.net/pypy/dist/pypy/doc/cpython_differences.html
    https://morepypy.blogspot.com/2008/06/pypy-improvements.html

  - Through a large number of tweaks, performance has been improved by
    10%-50% since the 1.0 release. The Python interpreter is now between
    0.8-2x (and in some corner case 3-4x) slower than CPython. A large
    part of these speed-ups come from our new generational garbage
    collectors.

    https://codespeak.net/pypy/dist/pypy/doc/garbage_collection.html

  - Our Python interpreter now supports distutils as well as
    easy_install for pure-Python modules.

  - We have tested PyPy with a number of third-party libraries. PyPy can
    run now: Django, Pylons, BitTorrent, Twisted, SymPy, Pyglet, Nevow,
    Pinax:

    https://morepypy.blogspot.com/2008/08/pypy-runs-unmodified-django-10-beta.html
    https://morepypy.blogspot.com/2008/07/pypys-python-runs-pinax-django.html
    https://morepypy.blogspot.com/2008/06/running-nevow-on-top-of-pypy.html

  - A buildbot was set up to run the various tests that PyPy is using
    nightly on Windows and Linux machines:

    https://codespeak.net:8099/

  - Sandboxing support: It is possible to translate the Python
    interpreter in a special way so that the result is fully sandboxed.
    
    https://codespeak.net/pypy/dist/pypy/doc/sandbox.html
    https://blog.sandbox.lt/en/WSGI%20and%20PyPy%20sandbox


Other Changes
=============

  - The ``clr`` module was greatly improved. This module is used to
    interface with .NET libraries when translating the Python
    interpreter to the CLI.

    https://codespeak.net/pypy/dist/pypy/doc/clr-module.html
    https://morepypy.blogspot.com/2008/01/pypynet-goes-windows-forms.html
    https://morepypy.blogspot.com/2008/01/improve-net-integration.html

  - Stackless improvements: PyPy's ``stackless`` module is now more
    complete. We added channel preferences which change details of the
    scheduling semantics. In addition, the pickling of tasklets has been
    improved to work in more cases.

  - Classic classes are enabled by default now. In addition, they have
    been greatly optimized and debugged:

    https://morepypy.blogspot.com/2007/12/faster-implementation-of-classic.html

  - PyPy's Python interpreter can be translated to Java bytecode now to
    produce a pypy-jvm. At the moment there is no integration with
    Java libraries yet, so this is not really useful.

  - We added cross-compilation machinery to our translation toolchain to
    make it possible to cross-compile our Python interpreter to Nokia's
    Maemo platform:

    https://codespeak.net/pypy/dist/pypy/doc/maemo.html

  - Some effort was spent to make the Python interpreter more
    memory-efficient. This includes the implementation of a mark-compact
    GC which uses less memory than other GCs during collection.
    Additionally there were various optimizations that make Python
    objects smaller, e.g. class instances are often only 50% of the size
    of CPython.

    https://morepypy.blogspot.com/2008/10/dsseldorf-sprint-report-days-1-3.html

  - The support for the trace hook in the Python interpreter was
    improved to be able to trace the execution of builtin functions and
    methods. With this, we implemented the ``_lsprof`` module, which is
    the core of the ``cProfile`` module.

  - A number of rarely used features of PyPy were removed since the previous
    release because they were unmaintained and/or buggy. Those are: The
    LLVM and the JS backends, the aspect-oriented programming features,
    the logic object space, the extension compiler and the first
    incarnation of the JIT generator. The new JIT generator is in active
    development, but not included in the release.

    https://codespeak.net/pipermail/pypy-dev/2009q2/005143.html
    https://morepypy.blogspot.com/2009/03/good-news-everyone.html
    https://morepypy.blogspot.com/2009/03/jit-bit-of-look-inside.html


What is PyPy?
=============

Technically, PyPy is both a Python interpreter implementation and an
advanced compiler, or more precisely a framework for implementing dynamic
languages and generating virtual machines for them.

The framework allows for alternative frontends and for alternative
backends, currently C, Java and .NET.  For our main target "C", we can
"mix in" different garbage collectors and threading models,
including micro-threads aka "Stackless".  The inherent complexity that
arises from this ambitious approach is mostly kept away from the Python
interpreter implementation, our main frontend.

Socially, PyPy is a collaborative effort of many individuals working
together in a distributed and sprint-driven way since 2003.  PyPy would
not have gotten as far as it has without the coding, feedback and
general support from numerous people.



Have fun,

    the PyPy release team, [in alphabetical order]
    
    Amaury Forgeot d'Arc, Anders Hammerquist, Antonio Cuni, Armin Rigo,
    Carl Friedrich Bolz, Christian Tismer, Holger Krekel,
    Maciek Fijalkowski, Samuele Pedroni

    and many others:
    https://codespeak.net/pypy/dist/pypy/doc/contributor.html
