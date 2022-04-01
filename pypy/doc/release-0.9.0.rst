pypy-0.9.0: stackless, new extension compiler
==============================================================

The PyPy development team has been busy working and we've now packaged 
our latest improvements, completed work and new experiments as 
version 0.9.0, our fourth public release.

The highlights of this fourth release of PyPy are:

**implementation of "stackless" features**
    We now support the larger part of the interface of the original
    Stackless Python -- see https://www.stackless.com for more.  A
    significant part of this is the pickling and unpickling of a running
    tasklet.

    These features, especially the pickling, can be considered to be a
    "technology preview" -- they work, but for example the error handling
    is a little patchy in places.

**ext-compiler**
    The "extension compiler" is a new way of writing a C extension for
    CPython and PyPy at the same time. For more information, see its
    documentation: https://codespeak.net/pypy/dist/pypy/doc/extcompiler.html

**rctypes**
    Most useful in combination with the ext-compiler is the fact that our
    translation framework can translate code that uses the
    standard-in-Python-2.5 ctypes module.  See its documentation for more:
    https://codespeak.net/pypy/dist/pypy/doc/rctypes.html

**framework GCs** 
    PyPy's interpreter can now be compiled to use a garbage collector
    written in RPython.  This added control over PyPy's execution makes the
    implementation of new and interesting features possible, apart from
    being a significant achievement in its own right.

**__del__/weakref/__subclasses__**
    The PyPy interpreter's compatibility with CPython continues improves:
    now we support __del__ methods, the __subclasses__ method on types and
    weak references.  We now pass around 95% of CPython's core tests.

**logic space preview**
    This release contains the first version of the logic object space,
    which will add logical variables to Python.  See its docs for more:
    https://codespeak.net/pypy/dist/pypy/doc/howto-logicobjspace-0.9.html

**high level backends preview**
    This release contains the first versions of new backends targeting high
    level languages such as Squeak and .NET/CLI and updated versions of the
    JavaScript and Common Lisp backends.  They can't compile the PyPy
    interpreter yet, but they're getting there...

**bugfixes, better performance**
    As you would expect, performance continues to improve and bugs continue
    to be fixed.  The performance of the translated PyPy interpreter is
    2.5-3x times faster than 0.8 (on richards and pystone), and is now
    stable enough to be able to run CPython's test suite to the end.

**testing refinements**
    py.test, our testing tool, now has preliminary support for doctests.
    We now run all our tests every night, and you can see the summary at:
    https://buildbot.pypy.org/summary

What is PyPy (about)? 
------------------------------------------------

PyPy is a MIT-licensed research-oriented reimplementation of Python
written in Python itself, flexible and easy to experiment with.  It
translates itself to lower level languages.  Our goals are to target a
large variety of platforms, small and large, by providing a
compilation toolsuite that can produce custom Python versions.
Platform, memory and threading models are to become aspects of the
translation process - as opposed to encoding low level details into
the language implementation itself.  Eventually, dynamic optimization
techniques - implemented as another translation aspect - should become
robust against language changes.

Note that PyPy is mainly a research and development project and does
not by itself focus on getting a production-ready Python
implementation although we do hope and expect it to become a viable
contender in that area sometime next year.

PyPy is partially funded as a research project under the European
Union's IST programme.

Where to start? 
-----------------------------

Getting started:    https://codespeak.net/pypy/dist/pypy/doc/getting-started.html

PyPy Documentation: https://codespeak.net/pypy/dist/pypy/doc/ 

PyPy Homepage:      https://codespeak.net/pypy/

The interpreter and object model implementations shipped with the 0.9
version can run on their own and implement the core language features
of Python as of CPython 2.4.  However, we still do not recommend using
PyPy for anything else than for education, playing or research
purposes.

Ongoing work and near term goals
---------------------------------

The Just-in-Time compiler and other performance improvements will be one of
the main topics of the next few months' work, along with finishing the
logic object space.

Project Details
---------------

PyPy has been developed during approximately 20 coding sprints across
Europe and the US.  It continues to be a very dynamically and
incrementally evolving project with many of these one-week workshops
to follow.

PyPy has been a community effort from the start and it would
not have got that far without the coding and feedback support
from numerous people.   Please feel free to give feedback and 
raise questions. 

    contact points: https://codespeak.net/pypy/dist/pypy/doc/contact.html

have fun, 
    
    the pypy team, (Armin Rigo, Samuele Pedroni, 
    Holger Krekel, Christian Tismer, 
    Carl Friedrich Bolz, Michael Hudson, 
    and many others: https://codespeak.net/pypy/dist/pypy/doc/contributor.html)

PyPy development and activities happen as an open source project  
and with the support of a consortium partially funded by a two 
year European Union IST research grant. The full partners of that 
consortium are: 
        
    Heinrich-Heine University (Germany), AB Strakt (Sweden)
    merlinux GmbH (Germany), tismerysoft GmbH (Germany) 
    Logilab Paris (France), DFKI GmbH (Germany)
    ChangeMaker (Sweden), Impara (Germany)
