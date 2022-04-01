Coding Guide
============

.. contents::

This document describes coding requirements and conventions for
working with the PyPy code base.  Please read it carefully and
ask back any questions you might have. The document does not talk
very much about coding style issues. We mostly follow :pep:`8` though.
If in doubt, follow the style that is already present in the code base.


Overview and motivation
------------------------

We are writing a Python interpreter in Python, using Python's well known
ability to step behind the algorithmic problems as a language. At first glance,
one might think this achieves nothing but a better understanding how the
interpreter works.  This alone would make it worth doing, but we have much
larger goals.


CPython vs. PyPy
~~~~~~~~~~~~~~~~

Compared to the CPython implementation, Python takes the role of the C
Code. We rewrite the CPython interpreter in Python itself.  We could
also aim at writing a more flexible interpreter at C level but we
want to use Python to give an alternative description of the interpreter.

The clear advantage is that such a description is shorter and simpler to
read, and many implementation details vanish. The drawback of this approach is
that this interpreter will be unbearably slow as long as it is run on top
of CPython.

To get to a useful interpreter again, we need to translate our
high-level description of Python to a lower level one.  One rather
straight-forward way is to do a whole program analysis of the PyPy
interpreter and create a C source, again. There are many other ways,
but let's stick with this somewhat canonical approach.


.. _application-level:
.. _interpreter-level:

Application-level and interpreter-level execution and objects
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Since Python is used for implementing all of our code base, there is a
crucial distinction to be aware of: that between *interpreter-level* objects and
*application-level* objects.  The latter are the ones that you deal with
when you write normal python programs.  Interpreter-level code, however,
cannot invoke operations nor access attributes from application-level
objects.  You will immediately recognize any interpreter level code in
PyPy, because half the variable and object names start with a ``w_``, which
indicates that they are `wrapped`_ application-level values.

Let's show the difference with a simple example.  To sum the contents of
two variables ``a`` and ``b``, one would write the simple application-level
``a+b`` -- in contrast, the equivalent interpreter-level code is
``space.add(w_a, w_b)``, where ``space`` is an instance of an object space,
and ``w_a`` and ``w_b`` are typical names for the wrapped versions of the
two variables.

It helps to remember how CPython deals with the same issue: interpreter
level code, in CPython, is written in C and thus typical code for the
addition is ``PyNumber_Add(p_a, p_b)`` where ``p_a`` and ``p_b`` are C
variables of type ``PyObject*``. This is conceptually similar to how we write
our interpreter-level code in Python.

Moreover, in PyPy we have to make a sharp distinction between
interpreter- and application-level *exceptions*: application exceptions
are always contained inside an instance of ``OperationError``.  This
makes it easy to distinguish failures (or bugs) in our interpreter-level code
from failures appearing in a python application level program that we are
interpreting.


.. _app-preferable:

Application level is often preferable
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Application-level code is substantially higher-level, and therefore
correspondingly easier to write and debug.  For example, suppose we want
to implement the ``update`` method of dict objects.  Programming at
application level, we can write an obvious, simple implementation, one
that looks like an **executable definition** of ``update``, for
example::

    def update(self, other):
        for k in other.keys():
            self[k] = other[k]

If we had to code only at interpreter level, we would have to code
something much lower-level and involved, say something like::

    def update(space, w_self, w_other):
        w_keys = space.call_method(w_other, 'keys')
        w_iter = space.iter(w_keys)
        while True:
            try:
                w_key = space.next(w_iter)
            except OperationError as e:
                if not e.match(space, space.w_StopIteration):
                    raise       # re-raise other app-level exceptions
                break
            w_value = space.getitem(w_other, w_key)
            space.setitem(w_self, w_key, w_value)

This interpreter-level implementation looks much more similar to the C
source code.  It is still more readable than its C counterpart because
it doesn't contain memory management details and can use Python's native
exception mechanism.

In any case, it should be obvious that the application-level implementation
is definitely more readable, more elegant and more maintainable than the
interpreter-level one (and indeed, dict.update is really implemented at
applevel in PyPy).

In fact, in almost all parts of PyPy, you find application level code in
the middle of interpreter-level code.  Apart from some bootstrapping
problems (application level functions need a certain initialization
level of the object space before they can be executed), application
level code is usually preferable.  We have an abstraction (called the
'Gateway') which allows the caller of a function to remain ignorant of
whether a particular function is implemented at application or
interpreter level.


Our runtime interpreter is "RPython"
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In order to make a C code generator feasible all code on interpreter level has
to restrict itself to a subset of the Python language, and we adhere to some
rules which make translation to lower level languages feasible. Code on
application level can still use the full expressivity of Python.

Unlike source-to-source translations (like e.g. Starkiller_ or more recently
ShedSkin_) we start
translation from live python code objects which constitute our Python
interpreter.   When doing its work of interpreting bytecode our Python
implementation must behave in a static way often referenced as
"RPythonic".

.. _Starkiller: https://people.csail.mit.edu/jrb/Projects/starkiller.pdf
.. _ShedSkin: https://shed-skin.blogspot.com/

However, when the PyPy interpreter is started as a Python program, it
can use all of the Python language until it reaches a certain point in
time, from which on everything that is being executed must be static.
That is, during initialization our program is free to use the
full dynamism of Python, including dynamic code generation.

An example can be found in the current implementation which is quite
elegant: For the definition of all the opcodes of the Python
interpreter, the module ``dis`` is imported and used to initialize our
bytecode interpreter.  (See ``__initclass__`` in
:source:`pypy/interpreter/pyopcode.py`).  This
saves us from adding extra modules to PyPy. The import code is run at
startup time, and we are allowed to use the CPython builtin import
function.

After the startup code is finished, all resulting objects, functions,
code blocks etc. must adhere to certain runtime restrictions which we
describe further below.  Here is some background for why this is so:
during translation, a whole program analysis ("type inference") is
performed, which makes use of the restrictions defined in RPython. This
enables the code generator to emit efficient machine level replacements
for pure integer objects, for instance.

.. _wrapped:

Wrapping rules
--------------

Wrapping
~~~~~~~~

PyPy is made of Python source code at two levels: there is on the one hand
*application-level code* that looks like normal Python code, and that
implements some functionalities as one would expect from Python code (e.g. one
can give a pure Python implementation of some built-in functions like
``zip()``).  There is also *interpreter-level code* for the functionalities
that must more directly manipulate interpreter data and objects (e.g. the main
loop of the interpreter, and the various object spaces).

Application-level code doesn't see object spaces explicitly: it runs using an
object space to support the objects it manipulates, but this is implicit.
There is no need for particular conventions for application-level code.  The
sequel is only about interpreter-level code.  (Ideally, no application-level
variable should be called ``space`` or ``w_xxx`` to avoid confusion.)

The ``w_`` prefixes so lavishly used in the example above indicate,
by PyPy coding convention, that we are dealing with *wrapped* (or *boxed*) objects,
that is, interpreter-level objects which the object space constructs
to implement corresponding application-level objects.  Each object
space supplies ``wrap``, ``unwrap``, ``int_w``, ``interpclass_w``,
etc. operations that move between the two levels for objects of simple
built-in types; each object space also implements other Python types
with suitable interpreter-level classes with some amount of internal
structure.

For example, an application-level Python ``list``
is implemented by the :ref:`standard object space <standard-object-space>` as an
instance of ``W_ListObject``, which has an instance attribute
``wrappeditems`` (an interpreter-level list which contains the
application-level list's items as wrapped objects).

The rules are described in more details below.


Naming conventions
~~~~~~~~~~~~~~~~~~

* ``space``: the object space is only visible at
  interpreter-level code, where it is by convention passed around by the name
  ``space``.

* ``w_xxx``: any object seen by application-level code is an
  object explicitly managed by the object space.  From the
  interpreter-level point of view, this is called a *wrapped*
  object.  The ``w_`` prefix is used for any type of
  application-level object.

* ``xxx_w``: an interpreter-level container for wrapped
  objects, for example a list or a dict containing wrapped
  objects.  Not to be confused with a wrapped object that
  would be a list or a dict: these are normal wrapped objects,
  so they use the ``w_`` prefix.


Operations on ``w_xxx``
~~~~~~~~~~~~~~~~~~~~~~~

The core bytecode interpreter considers wrapped objects as black boxes.
It is not allowed to inspect them directly.  The allowed
operations are all implemented on the object space: they are
called ``space.xxx()``, where ``xxx`` is a standard operation
name (``add``, ``getattr``, ``call``, ``eq``...). They are documented in the
:ref:`object space document <objspace-interface>`.

A short warning: **don't do** ``w_x == w_y`` or ``w_x is w_y``!
rationale for this rule is that there is no reason that two
wrappers are related in any way even if they contain what
looks like the same object at application-level.  To check
for equality, use ``space.is_true(space.eq(w_x, w_y))`` or
even better the short-cut ``space.eq_w(w_x, w_y)`` returning
directly a interpreter-level bool.  To check for identity,
use ``space.is_true(space.is_(w_x, w_y))`` or better
``space.is_w(w_x, w_y)``.


.. _applevel-exceptions:

Application-level exceptions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Interpreter-level code can use exceptions freely.  However,
all application-level exceptions are represented as an
``OperationError`` at interpreter-level.  In other words, all
exceptions that are potentially visible at application-level
are internally an ``OperationError``.  This is the case of all
errors reported by the object space operations
(``space.add()`` etc.).

To raise an application-level exception::

    from pypy.interpreter.error import oefmt

    raise oefmt(space.w_XxxError, "message")

    raise oefmt(space.w_XxxError, "file '%s' not found in '%s'", filename, dir)

    raise oefmt(space.w_XxxError, "file descriptor '%d' not open", fd)

To catch a specific application-level exception::

    try:
        ...
    except OperationError as e:
        if not e.match(space, space.w_XxxError):
            raise
        ...

This construct catches all application-level exceptions, so we
have to match it against the particular ``w_XxxError`` we are
interested in and re-raise other exceptions.  The exception
instance ``e`` holds two attributes that you can inspect:
``e.w_type`` and ``e.w_value``.  Do not use ``e.w_type`` to
match an exception, as this will miss exceptions that are
instances of subclasses.


.. _modules:

Modules in PyPy
---------------

Modules visible from application programs are imported from
interpreter or application level files.  PyPy reuses almost all python
modules of CPython's standard library, currently from version 2.7.8.  We
sometimes need to `modify modules`_ and - more often - regression tests
because they rely on implementation details of CPython.

If we don't just modify an original CPython module but need to rewrite
it from scratch we put it into :source:`lib_pypy/` as a pure application level
module.

When we need access to interpreter-level objects we put the module into
:source:`pypy/module`.  Such modules use a `mixed module mechanism`_
which makes it convenient to use both interpreter- and application-level parts
for the implementation.  Note that there is no extra facility for
pure-interpreter level modules, you just write a mixed module and leave the
application-level part empty.


Determining the location of a module implementation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You can interactively find out where a module comes from, when running py.py.
here are examples for the possible locations::

    >>>> import sys
    >>>> sys.__file__
    '/home/hpk/pypy-dist/pypy/module/sys'

    >>>> import cPickle
    >>>> cPickle.__file__
    '/home/hpk/pypy-dist/lib_pypy/cPickle..py'

    >>>> import os
    >>>> os.__file__
    '/home/hpk/pypy-dist/lib-python/2.7/os.py'
    >>>>


Module directories / Import order
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Here is the order in which PyPy looks up Python modules:

*pypy/module*

    mixed interpreter/app-level builtin modules, such as
    the ``sys`` and ``__builtin__`` module.

*contents of PYTHONPATH*

    lookup application level modules in each of the ``:`` separated
    list of directories, specified in the ``PYTHONPATH`` environment
    variable.

*lib_pypy/*

    contains pure Python reimplementation of modules.

*lib-python/2.7/*

    The modified CPython library.


.. _modify modules:

Modifying a CPython library module or regression test
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Although PyPy is very compatible with CPython we sometimes need
to change modules contained in our copy of the standard library,
often due to the fact that PyPy works with all new-style classes
by default and CPython has a number of places where it relies
on some classes being old-style.

We just maintain those changes in place,
to see what is changed we have a branch called `vendor/stdlib`
wich contains the unmodified cpython stdlib


.. _mixed module mechanism:
.. _mixed-modules:

Implementing a mixed interpreter/application level Module
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If a module needs to access PyPy's interpreter level
then it is implemented as a mixed module.

Mixed modules are directories in :source:`pypy/module` with an  `__init__.py`
file containing specifications where each name in a module comes from.
Only specified names will be exported to a Mixed Module's applevel
namespace.

Sometimes it is necessary to really write some functions in C (or whatever
target language). See rffi_ details.

.. _rffi: https://rpython.readthedocs.org/en/latest/rffi.html

application level definitions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Application level specifications are found in the `appleveldefs`
dictionary found in ``__init__.py`` files of directories in ``pypy/module``.
For example, in :source:`pypy/module/__builtin__/__init__.py` you find the following
entry specifying where ``__builtin__.locals`` comes from::

     ...
     'locals'        : 'app_inspect.locals',
     ...

The ``app_`` prefix indicates that the submodule ``app_inspect`` is
interpreted at application level and the wrapped function value for ``locals``
will be extracted accordingly.


interpreter level definitions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Interpreter level specifications are found in the ``interpleveldefs``
dictionary found in ``__init__.py`` files of directories in ``pypy/module``.
For example, in :source:`pypy/module/__builtin__/__init__.py` the following
entry specifies where ``__builtin__.len`` comes from::

     ...
     'len'       : 'operation.len',
     ...

The ``operation`` submodule lives at interpreter level and ``len``
is expected to be exposable to application level.  Here is
the definition for ``operation.len()``::

    def len(space, w_obj):
        "len(object) -> integer\n\nReturn the number of items of a sequence or mapping."
        return space.len(w_obj)

Exposed interpreter level functions usually take a ``space`` argument
and some wrapped values (see `Wrapping rules`_) .

You can also use a convenient shortcut in ``interpleveldefs`` dictionaries:
namely an expression in parentheses to specify an interpreter level
expression directly (instead of pulling it indirectly from a file)::

    ...
    'None'          : '(space.w_None)',
    'False'         : '(space.w_False)',
    ...

The interpreter level expression has a ``space`` binding when
it is executed.

Adding an entry under pypy/module (e.g. mymodule) entails automatic
creation of a new config option (such as --withmod-mymodule and
--withoutmod-mymodule (the latter being the default)) for py.py and
translate.py.


Testing modules in ``lib_pypy/``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You can go to the :source:`pypy/module/test_lib_pypy/` directory and invoke the
testing tool ("py.test" or "python ../../pypy/test_all.py") to run tests
against the lib_pypy hierarchy.  This allows us to quickly test our
python-coded reimplementations against CPython.


Testing modules in ``pypy/module``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Simply change to ``pypy/module`` or to a subdirectory and `run the
tests as usual`_.


Testing modules in ``lib-python``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In order to let CPython's regression tests run against PyPy
you can switch to the :source:`lib-python/` directory and run
the testing tool in order to start compliance tests.
(XXX check windows compatibility for producing test reports).


Naming conventions and directory layout
---------------------------------------

Directory and File Naming
~~~~~~~~~~~~~~~~~~~~~~~~~

- directories/modules/namespaces are always **lowercase**

- never use plural names in directory and file names

- ``__init__.py`` is usually empty except for
  ``pypy/objspace/*`` and ``pypy/module/*/__init__.py``.

- don't use more than 4 directory nesting levels

- keep filenames concise and completion-friendly.


Naming of python objects
~~~~~~~~~~~~~~~~~~~~~~~~

- class names are **CamelCase**

- functions/methods are lowercase and ``_`` separated

- objectspace classes are spelled ``XyzObjSpace``. e.g.

  - StdObjSpace
  - FlowObjSpace

- at interpreter level and in ObjSpace all boxed values
  have a leading ``w_`` to indicate "wrapped values".  This
  includes w_self.  Don't use ``w_`` in application level
  python only code.


Committing & Branching to the repository
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- write good log messages because several people
  are reading the diffs.

- What was previously called ``trunk`` is called the ``default`` branch in
  mercurial. Branches in mercurial are always pushed together with the rest
  of the repository. To create a ``try1`` branch (assuming that a branch named
  ``try1`` doesn't already exists) you should do::

    hg branch try1

  The branch will be recorded in the repository only after a commit. To switch
  back to the default branch::

    hg update default

  For further details use the help or refer to the `official wiki`_::

    hg help branch

.. _official wiki: https://www.mercurial-scm.org/wiki/


.. _using-development-tracker:

Using the development bug/feature tracker
-----------------------------------------

We use https://foss.heptapod.net/pypy/pypy for :source:`issues` tracking and
:source:`pull-requests`.

.. _testing:

Testing in PyPy
---------------

Our tests are based on the `py.test`_ tool which lets you write
unittests without boilerplate.  All tests of modules
in a directory usually reside in a subdirectory **test**.  There are
basically two types of unit tests:

- **Interpreter Level tests**. They run at the same level as PyPy's
  interpreter.

- **Application Level tests**. They run at application level which means
  that they look like straight python code but they are interpreted by PyPy.

.. _py.test: https://pytest.org/


Interpreter level tests
~~~~~~~~~~~~~~~~~~~~~~~

You can write test functions and methods like this::

    def test_something(space):
        # use space ...

    class TestSomething(object):
        def test_some(self):
            # use 'self.space' here

Note that the prefix `test` for test functions and `Test` for test
classes is mandatory.  In both cases you can import Python modules at
module global level and use plain 'assert' statements thanks to the
usage of the `py.test`_ tool.

Application level tests
~~~~~~~~~~~~~~~~~~~~~~~

For testing the conformance and well-behavedness of PyPy it
is often sufficient to write "normal" application-level
Python code that doesn't need to be aware of any particular
coding style or restrictions. If we have a choice we often
use application level tests which are in files whose name starts with the
`apptest_` prefix and look like this::

    # spaceconfig = {"usemodules":["array"]}
    def test_this():
        # application level test code

These application level test functions will run on top
of PyPy, i.e. they have no access to interpreter details.

By default, they run on top of an untranslated PyPy which runs on top of the
host interpreter. When passing the `-D` option, they run directly on top of the
host interpreter, which is usually a translated pypy executable in this case::

    pypy3 -m pytest -D pypy/

Note that in interpreted mode, only a small subset of pytest's functionality is
available.  To configure the object space, the host interpreter will parse the
optional spaceconfig declaration.  This declaration must be in the form of a
valid json dict. 

Mixed-level tests (deprecated)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Mixed-level tests are similar to application-level tests, the difference being
that they're just snippets of app-level code embedded in an interp-level test
file, like this::

    class AppTestSomething(object):
        def test_this(self):
            # application level test code

You cannot use imported modules from global level because
they are imported at interpreter-level while you test code
runs at application level. If you need to use modules
you have to import them within the test function.

Data can be passed into the AppTest using 
the ``setup_class`` method of the AppTest. All wrapped objects that are
attached to the class there and start with ``w_`` can be accessed
via self (but without the ``w_``) in the actual test method. An example::

    class AppTestErrno(object):
        def setup_class(cls):
            cls.w_d = cls.space.wrap({"a": 1, "b", 2})

        def test_dict(self):
            assert self.d["a"] == 1
            assert self.d["b"] == 2


.. _run the tests as usual:

Another possibility is to use cls.space.appexec, for example::

    class AppTestSomething(object):
        def setup_class(cls):
            arg = 2
            cls.w_result = cls.space.appexec([cls.space.wrap(arg)], """(arg):
                return arg ** 6
                """)

        def test_power(self):
            assert self.result == 2 ** 6

which executes the code string function with the given arguments at app level.
Note the use of ``w_result`` in ``setup_class`` but self.result in the test.
Here is how to define an app level class  in ``setup_class`` that can be used
in subsequent tests::

    class AppTestSet(object):
        def setup_class(cls):
            w_fakeint = cls.space.appexec([], """():
                class FakeInt(object):
                    def __init__(self, value):
                        self.value = value
                    def __hash__(self):
                        return hash(self.value)

                    def __eq__(self, other):
                        if other == self.value:
                            return True
                        return False
                return FakeInt
                """)
            cls.w_FakeInt = w_fakeint

        def test_fakeint(self):
            f1 = self.FakeInt(4)
            assert f1 == 4
            assert hash(f1) == hash(4)


Command line tool test_all
~~~~~~~~~~~~~~~~~~~~~~~~~~

You can run almost all of PyPy's tests by invoking::

  python test_all.py file_or_directory

which is a synonym for the general `py.test`_ utility
located in the ``py/bin/`` directory.  For switches to
modify test execution pass the ``-h`` option.


Coverage reports
~~~~~~~~~~~~~~~~

In order to get coverage reports the `pytest-cov`_ plugin is included.
it adds some extra requirements ( coverage_ and `cov-core`_ )
and can once they are installed coverage testing can be invoked via::

  python test_all.py --cov file_or_direcory_to_cover file_or_directory

.. _pytest-cov: https://pypi.python.org/pypi/pytest-cov
.. _coverage: https://pypi.python.org/pypi/coverage
.. _cov-core: https://pypi.python.org/pypi/cov-core


Test conventions
~~~~~~~~~~~~~~~~

- adding features requires adding appropriate tests.  (It often even
  makes sense to first write the tests so that you are sure that they
  actually can fail.)

- All over the pypy source code there are test/ directories
  which contain unit tests.  Such scripts can usually be executed
  directly or are collectively run by pypy/test_all.py


.. _change documentation and website:

Changing documentation and website
----------------------------------

documentation/website files in your local checkout
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Most of the PyPy's documentation is kept in `pypy/doc`.
You can simply edit or add '.rst' files which contain ReST-markuped
files.  Here is a `ReST quickstart`_ but you can also just look
at the existing documentation and see how things work.

Note that the web site of https://pypy.org/ is maintained separately.
It is in the repository https://foss.heptapod.net/pypy/pypy.org

.. _ReST quickstart: https://docutils.sourceforge.net/docs/user/rst/quickref.html


Automatically test documentation/website changes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We automatically check referential integrity and ReST-conformance.  In order to
run the tests you need sphinx_ installed.  Then go to the local checkout
of the documentation directory and run the Makefile::

    cd pypy/doc
    make html

If you see no failures chances are high that your modifications at least
don't produce ReST-errors or wrong local references. Now you will have `.html`
files in the documentation directory which you can point your browser to!

Additionally, if you also want to check for remote references inside
the documentation issue::

    make linkcheck

which will check that remote URLs are reachable.

.. _sphinx: https://sphinx.pocoo.org/
