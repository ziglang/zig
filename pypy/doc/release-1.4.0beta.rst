====================================
PyPy 1.4beta - towards 1.4.0 release
====================================

Hello.

As we head towards 1.4 release, which should be considered the very first PyPy
release ready to substitute CPython for at least some of us, we're pleased to
announce 1.4 beta release.

This release contains all major features from upcoming 1.4, the only thing
missing being improved memory footprint.

However, this is a beta release and might still contain some issues. One of
those issues is that, like on nightly builds, pypy might print some debugging
output at the end of your program run.

Highlights:

* x86_64 JIT backend

* since PyPy 1.3 we have an experimental support for CPython C extensions.
  Those have to be recompiled using `pypy setup.py build`. Extensions usually
  have to be tweaked for e.g. refcounting bugs that don't manifest on CPython.
  There is a `list of patches`_ available for some extensions.

* rewritten fast and jitted regular expressions

* improvements all across the board (for example faster map calls)

* virtualenv support (virtualenv 1.5 or later)

Cheers,
The PyPy team

.. _`list of patches`: https://bitbucket.org/pypy/pypy/src/tip/pypy/module/cpyext/patches/
