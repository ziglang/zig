Contributing Guidelines
===========================

.. contents::

PyPy is a very large project that has a reputation of being hard to dive into.
Some of this fame is warranted, some of it is purely accidental. There are three
important lessons that everyone willing to contribute should learn:

* PyPy has layers. There are many pieces of architecture that are very well
  separated from each other. More about this below, but often the manifestation
  of this is that things are at a different layer than you would expect them
  to be. For example if you are looking for the JIT implementation, you will
  not find it in the implementation of the Python programming language.

* Because of the above, we are very serious about Test Driven Development.
  It's not only what we believe in, but also that PyPy's architecture is
  working very well with TDD in mind and not so well without it. Often
  development means progressing in an unrelated corner, one unittest
  at a time; and then flipping a giant switch, bringing it all together.
  (It generally works out of the box.  If it doesn't, then we didn't
  write enough unit tests.)  It's worth repeating - PyPy's
  approach is great if you do TDD, and not so great otherwise.

* PyPy uses an entirely different set of tools - most of them included
  in the PyPy repository. There is no Makefile, nor autoconf. More below.

The first thing to remember is that PyPy project is very different than most
projects out there. It's also different from a classic compiler project,
so academic courses about compilers often don't apply or lead in the wrong
direction. However, if you want to understand how designing & building a runtime
works in the real world then this is a great project!

Getting involved
^^^^^^^^^^^^^^^^

PyPy employs a relatively standard open-source development process. You are
encouraged as a first step to join our `pypy-dev mailing list`_ and IRC channel,
details of which can be found in our :ref:`contact <contact>` section. The folks
there are very friendly, and can point you in the right direction.

We give out commit rights usually fairly liberally, so if you want to do something
with PyPy, you can become a "developer" by logging into https://foss.heptapod.net
and clicking the "Request Access" link on the `PyPy group page`. We also run
coding sprints which are separately announced and are usually announced on `the
blog`_.

Like any Open Source project, issues should be filed on the `issue tracker`_,
and `merge requests`_ to fix issues are welcome.

Further Reading: :ref:`Contact <contact>`

.. _the blog: https://morepypy.blogspot.com
.. _pypy-dev mailing list: https://mail.python.org/mailman/listinfo/pypy-dev
.. _`PyPy group page`: https://foss.heptapod.net/pypy
.. _`merge requests`: https://foss.heptapod.net/heptapod/foss.heptapod.net/-/merge_requests


Your first contribution
^^^^^^^^^^^^^^^^^^^^^^^

The first and most important rule how **not** to contribute to PyPy is
"just hacking a feature". This won't work, and you'll find your PR will typically
require a lot of re-work. There are a few reasons why not:

* build times are large
* PyPy has very thick layer separation
* context of the cPython runtime is often required

Instead, reach out on the dev mailing list or the IRC channel, and we're more
than happy to help! :)

Some ideas for first contributions are:

* Documentation - this will give you an understanding of the pypy architecture
* Test failures - find a failing test in the `nightly builds`_, and fix it
* Missing language features - these are listed in our `issue tracker`_

.. _nightly builds: https://buildbot.pypy.org/nightly/
.. _issue tracker: https://foss.heptapod.net/pypy/pypy/issues

Source Control
--------------

PyPy's main repositories are hosted here: https://foss.heptapod.net/pypy.

`Heptapod <https://heptapod.net/>`_ is a friendly fork of GitLab Community
Edition supporting Mercurial. https://foss.heptapod.net is a public instance
for Free and Open-Source Software (more information `here
<https://foss.heptapod.net/heptapod/foss.heptapod.net>`_).

Thanks to `Octobus <https://octobus.net/>`_ and `Clever Cloud
<https://www.clever-cloud.com>`_ for providing this service!

.. raw:: html

   <h1 align="center">
     <a href="https://foss.heptapod.net/heptapod/foss.heptapod.net">
       <img width="500" alt="Octobus + Clever Cloud"
            src="https://foss.heptapod.net/heptapod/slides/2020-FOSDEM/raw/branch/default/octobus+clever.png"
            >
     </a>
   </h1>

Get Access
----------

As stated above, you need to request access to the repo.
Since the free hosting on foss.heptapod.net does not allow personal forks, you
need permissions to push your changes directly to our repo. Once you sign in to
https://foss.heptapod.net using either a new login or your GitHub or Atlassian
logins, you can get developer status for pushing directly to
the project (just ask by clicking the link at foss.heptapod.net/pypy just under
the logo, and you'll get it, basically).  Once you have it you can rewrite your
file ``.hg/hgrc`` to contain ``default = ssh://hg@foss.heptapod.net/pypy/pypy``.
Your changes will then be pushed directly to a branch on the official repo, and
we will review the branches you want to merge.

Clone
-----

* Clone the PyPy repo to your local machine with the command
  ``hg clone https://foss.heptapod.net/pypy/pypy``.  It takes a minute or two
  operation but only ever needs to be done once.  See also
  https://pypy.org/download.html#building-from-source .
  If you already cloned the repo before, even if some time ago,
  then you can reuse the same clone by editing the file ``.hg/hgrc`` in
  your clone to contain the line ``default =
  https://foss.heptapod.net/pypy/pypy``, and then do ``hg pull && hg
  up``.  If you already have such a clone but don't want to change it,
  you can clone that copy with ``hg clone /path/to/other/copy``, and
  then edit ``.hg/hgrc`` as above and do ``hg pull && hg up``.

* Now you have a complete copy of the PyPy repo.  Make a long-lived branch
  with a command like ``hg branch name_of_your_branch``.

Edit
----

* Edit things.  Use ``hg diff`` to see what you changed.  Use ``hg add``
  to make Mercurial aware of new files you added, e.g. new test files.
  Use ``hg status`` to see if there are such files.  Write and run tests!
  (See the rest of this page.)

* Commit regularly with ``hg commit``.  A one-line commit message is
  fine.  We love to have tons of commits; make one as soon as you have
  some progress, even if it is only some new test that doesn't pass yet,
  or fixing things even if not all tests pass.  Step by step, you are
  building the history of your changes, which is the point of a version
  control system.  (There are commands like ``hg log`` and ``hg up``
  that you should read about later, to learn how to navigate this
  history.)

* The commits stay on your machine until you do ``hg push`` to "push"
  them back to the repo named in the file ``.hg/hgrc``.  Repos are
  basically just collections of commits (a commit is also called a
  changeset): there is one repo per url, plus one for each local copy on
  each local machine.  The commands ``hg push`` and ``hg pull`` copy
  commits around, with the goal that all repos in question end up with
  the exact same set of commits.  By opposition, ``hg up`` only updates
  the "working copy" by reading the local repository, i.e. it makes the
  files that you see correspond to the latest (or any other) commit
  locally present.

* You should push often; there is no real reason not to.  Remember that
  even if they are pushed, with the setup above, the commits are only in the
  branch you
  named.  Yes, they are publicly visible, but don't worry about someone
  walking around the many branches of PyPy saying "hah, look
  at the bad coding style of that person".  Try to get into the mindset
  that your work is not secret and it's fine that way.  We might not
  accept it as is for PyPy, asking you instead to improve some things,
  but we are not going to judge you unless you don't write tests.

Merge Request
-------------

* The final step is to open a merge request, so that we know that you'd
  like to merge that branch back to the original ``pypy/pypy`` repo.
  This can also be done several times if you have interesting
  intermediate states, but if you get there, then we're likely to
  proceed to the next stage, which is...

* If you get closer to the regular day-to-day development, you'll notice
  that we generally push small changes as one or a few commits directly
  to the branch ``default`` or ``py3.6``.  Also, we often collaborate even if
  we are on other branches, which do not really "belong" to anyone.  At this
  point you'll need ``hg merge`` and learn how to resolve conflicts that
  sometimes occur when two people try to push different commits in
  parallel on the same branch.  But it is likely an issue for later ``:-)``

Architecture
^^^^^^^^^^^^

PyPy has layers. Just like ogres or onions. Those layers help us keep the
respective parts separated enough to be worked on independently and make the
complexity manageable. This is, again, just a sanity requirement for such
a complex project. For example writing a new optimization for the JIT usually
does **not** involve touching a Python interpreter at all or the JIT assembler
backend or the garbage collector. Instead it requires writing small tests in
``rpython/jit/metainterp/optimizeopt/test/test_*`` and fixing files there.
After that, you can just compile PyPy and things should just work.

Further Reading: :doc:`architecture <architecture>`

Where to start?
---------------

PyPy is made from parts that are relatively independent of each other.
You should start looking at the part that attracts you most (all paths are
relative to the PyPy top level directory).  You may look at our
:doc:`directory reference <dir-reference>` or start off at one of the following
points:

*  :source:`pypy/interpreter` contains the bytecode interpreter: bytecode dispatcher
   in :source:`pypy/interpreter/pyopcode.py`, frame and code objects in
   :source:`pypy/interpreter/eval.py` and :source:`pypy/interpreter/pyframe.py`,
   function objects and argument passing in :source:`pypy/interpreter/function.py`
   and :source:`pypy/interpreter/argument.py`, the object space interface
   definition in :source:`pypy/interpreter/baseobjspace.py`, modules in
   :source:`pypy/interpreter/module.py` and :source:`pypy/interpreter/mixedmodule.py`.
   Core types supporting the bytecode interpreter are defined in
   :source:`pypy/interpreter/typedef.py`.

*  :source:`pypy/interpreter/pyparser` contains a recursive descent parser,
   and grammar files that allow it to parse the syntax of various Python
   versions. Once the grammar has been processed, the parser can be
   translated by the above machinery into efficient code.

*  :source:`pypy/interpreter/astcompiler` contains the compiler.  This
   contains a modified version of the compiler package from CPython
   that fixes some bugs and is translatable.

*  :source:`pypy/objspace/std` contains the
   :ref:`Standard object space <standard-object-space>`.  The main file
   is :source:`pypy/objspace/std/objspace.py`.  For each type, the file
   ``xxxobject.py`` contains the implementation for objects of type ``xxx``,
   as a first approximation.  (Some types have multiple implementations.)

Building
^^^^^^^^

For building PyPy, we recommend installing a pre-built PyPy first (see
:doc:`install`). It is possible to build PyPy with CPython, but it will take a
lot longer to run -- depending on your architecture, between two and three
times as long.

Further Reading: :doc:`Build <build>`

Coding Guide
------------

As well as the usual pep8 and formatting standards, there are a number of
naming conventions and coding styles that are important to understand before
browsing the source.

Further Reading: :doc:`Coding Guide <coding-guide>`

Testing
^^^^^^^

Test driven development
-----------------------

Instead, we practice a lot of test driven development. This is partly because
of very high quality requirements for compilers and partly because there is
simply no other way to get around such complex project, that will keep you sane.
There are probably people out there who are smart enough not to need it, we're
not one of those. You may consider familiarizing yourself with `pytest`_,
since this is a tool we use for tests. We ship our own tweaked version of
pytest in the top of the tree, so ``python -m pytest`` will pick up our version,
which means our tests need to run with that version of pytest.

We also have post-translation tests in the ``extra_tests`` directory that are
run in a virtual environment from a separate directory, so they use a more
up-to-date version of pytest. As much as possible, these are meant to be
pass with CPython as well.

.. _pytest: https://pytest.org/

Running PyPy's unit tests
-------------------------

PyPy development always was and is still thoroughly test-driven.
There are two modes of tests: those that run on top of RPython before
translation (untranslated tests) and those that run on top of a translated
``pypy`` (app tests). Since RPython is a dialect of Python2, the untranslated
tests run with a python2 host. 

The PyPy source tree comes with an inlined version of ``py.test``
which you can invoke by typing::

    python2 pytest.py -h

You will need the `build requirements`_ to run tests successfully, since many of
them compile little pieces of PyPy and then run the tests inside that minimal
interpreter. The `cpyext` tests also require `pycparser`, and many tests build
cases with `hypothesis`.

Now on to running some tests.  PyPy has many different test directories
and you can use shell completion to point at directories or files::

    python2 pytest.py pypy/interpreter/test/test_pyframe.py

    # or for running tests of a whole subdirectory
    python2 pytest.py pypy/interpreter/

Beware trying to run "all" pypy tests by pointing to the root
directory or even the top level subdirectory ``pypy``.  It takes
hours and uses huge amounts of RAM and is not recommended.

To run CPython regression tests, you should start with a translated PyPy and
run the tests as you would with CPython (see below).  You can, however, also
attempt to run the tests before translation, but be aware that it is done with
a hack that doesn't work in all cases and it is usually extremely slow:
``py.test lib-python/2.7/test/test_datetime.py``.  Usually, a better idea is to
extract a minimal failing test of at most a few lines, and put it into one of
our own tests in ``pypy/*/test/``.

.. _`build requirements`: build.html#install-build-time-dependencies

App level testing
^^^^^^^^^^^^^^^^^

While the usual invocation of `python2 pytest.py` runs app-level tests on an
untranslated PyPy that runs on top of CPython, we have a test extension to run tests
directly on the host python. This is very convenient for modules such as
`cpyext`, to compare and contrast test results between CPython and PyPy.

App-level tests (ones whose file name start with ``apptest_`` not ``test_``)
run directly on the host interpreter when passing `-D` or
`--direct-apptest` to `pytest`::

    pypy3 -m pytest -D pypy/interpreter/test/apptest_pyframe.py

Mixed-level tests (the usual ones that start with ``test_``) are invoked by using the `-A` or `--runappdirect` option to
`pytest`::

    python2 pytest.py -A pypy/module/cpyext/test

where `python2` can be either `python2` or `pypy2`. On the `py3` branch, the
collection phase must be run with `python2` so untranslated tests are run
with::

    python2 pytest.py -A pypy/module/cpyext/test --python=path/to/pypy3


Testing After Translation
^^^^^^^^^^^^^^^^^^^^^^^^^

If you run translation, you will end up with a binary named ``pypy-c`` (or
``pypy3-c`` for the Python3 branches) in the directory where you ran the
translation.

To run a test from the standard CPython regression test suite, use the regular
Python way, i.e. (use the exact binary name)::

    ./pypy3-c -m test.test_datetime
    # or
    ./pypy3-c lib-python/3/test/test_audit.py


Tooling & Utilities
^^^^^^^^^^^^^^^^^^^

If you are interested in the inner workings of the PyPy Python interpreter,
there are some features of the untranslated Python interpreter that allow you
to introspect its internals.


Interpreter-level console
-------------------------

To start interpreting Python with PyPy, install a C compiler that is
supported by distutils and use Python 2.7 or greater to run PyPy::

    cd pypy
    python bin/pyinteractive.py

After a few seconds (remember: this is running on top of CPython), you should
be at the PyPy prompt, which is the same as the Python prompt, but with an
extra ">".

If you press
<Ctrl-C> on the console you enter the interpreter-level console, a
usual CPython console.  You can then access internal objects of PyPy
(e.g. the :ref:`object space <objspace>`) and any variables you have created on the PyPy
prompt with the prefix ``w_``::

    >>>> a = 123
    >>>> <Ctrl-C>
    *** Entering interpreter-level console ***
    >>> w_a
    W_IntObject(123)

The mechanism works in both directions. If you define a variable with the ``w_`` prefix on the interpreter-level, you will see it on the app-level::

    >>> w_l = space.newlist([space.wrap(1), space.wrap("abc")])
    >>> <Ctrl-D>
    *** Leaving interpreter-level console ***

    KeyboardInterrupt
    >>>> l
    [1, 'abc']

Note that the prompt of the interpreter-level console is only '>>>' since
it runs on CPython level. If you want to return to PyPy, press <Ctrl-D> (under
Linux) or <Ctrl-Z>, <Enter> (under Windows).

Also note that not all modules are available by default in this mode (for
example: ``_continuation`` needed by ``greenlet``) , you may need to use one of
``--withmod-...`` command line options.

You may be interested in reading more about the distinction between
:ref:`interpreter-level and app-level <interpreter-level>`.

pyinteractive.py options
------------------------

To list the PyPy interpreter command line options, type::

    cd pypy
    python bin/pyinteractive.py --help

pyinteractive.py supports most of the options that CPython supports too (in addition to a
large amount of options that can be used to customize pyinteractive.py).
As an example of using PyPy from the command line, you could type::

    python pyinteractive.py --withmod-time -c "from test import pystone; pystone.main(10)"

Alternatively, as with regular Python, you can simply give a
script name on the command line::

    python pyinteractive.py --withmod-time ../../lib-python/2.7/test/pystone.py 10

The ``--withmod-xxx`` option enables the built-in module ``xxx``.  By
default almost none of them are, because initializing them takes time.
If you want anyway to enable all built-in modules, you can use
``--allworkingmodules``.

See our :doc:`configuration sections <config/index>` for details about what all the commandline
options do.


.. _trace example:

Tracing bytecode and operations on objects
------------------------------------------

You can use a simple tracing mode to monitor the interpretation of
bytecodes.  To enable it, set ``__pytrace__ = 1`` on the interactive
PyPy console::

    >>>> __pytrace__ = 1
    Tracing enabled
    >>>> x = 5
            <module>:           LOAD_CONST    0 (5)
            <module>:           STORE_NAME    0 (x)
            <module>:           LOAD_CONST    1 (None)
            <module>:           RETURN_VALUE    0
    >>>> x
            <module>:           LOAD_NAME    0 (x)
            <module>:           PRINT_EXPR    0
    5
            <module>:           LOAD_CONST    0 (None)
            <module>:           RETURN_VALUE    0
    >>>>


Demos
^^^^^

The `example-interpreter`_ repository contains an example interpreter
written using the RPython translation toolchain.

.. _example-interpreter: https://foss.heptapod.net/pypy/example-interpreter


graphviz & pygame for flow graph viewing (highly recommended)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

graphviz and pygame are both necessary if you want to look at generated flow
graphs:

    graphviz: https://www.graphviz.org/Download.php

    pygame: https://www.pygame.org/download.shtml

