PyPy directory cross-reference
==============================

Here is a fully referenced alphabetical two-level deep
directory overview of PyPy:

========================================  ============================================
Directory                                 explanation/links
========================================  ============================================
:source:`pypy/bin/`                       command-line scripts, mainly
                                          :source:`pypy/bin/pyinteractive.py`

:source:`pypy/config/`                    handles the numerous options for building
                                          and running PyPy

:source:`pypy/doc/`                       text versions of PyPy developer
                                          documentation

:source:`pypy/doc/config/`                documentation for the numerous translation
                                          options

:source:`pypy/doc/discussion/`            drafts of ideas and documentation

:source:`pypy/goal/`                      our main PyPy-translation scripts
                                          live here

:source:`pypy/interpreter/`               :doc:`bytecode interpreter <interpreter>` and related objects
                                          (frames, functions, modules,...)

:source:`pypy/interpreter/pyparser/`      interpreter-level Python source parser

:source:`pypy/interpreter/astcompiler/`   interpreter-level bytecode compiler,
                                          via an AST representation

:source:`pypy/module/`                    contains :ref:`mixed modules <mixed-modules>`
                                          implementing core modules with
                                          both application and interpreter level code.
                                          Not all are finished and working.  Use
                                          the ``--withmod-xxx``
                                          or ``--allworkingmodules`` translation
                                          options.

:source:`pypy/objspace/`                  :doc:`object space <objspace>` implementations

:source:`pypy/objspace/std/`              the :ref:`StdObjSpace <standard-object-space>` implementing CPython's
                                          objects and types

:source:`pypy/tool/`                      various utilities and hacks used
                                          from various places

:source:`pypy/tool/pytest/`               support code for our :ref:`testing methods <testing>`

``*/test/``                               many directories have a test subdirectory
                                          containing test
                                          modules (see :ref:`testing`)

``_cache/``                               holds cache files from various purposes
========================================  ============================================
