The PyPy 0.6 release
-------------------- 

*The PyPy Development Team is happy to announce the first 
public release of PyPy after two years of spare-time and
half a year of EU funded development.  The 0.6 release 
is eminently a preview release.*  

What it is and where to start 
-----------------------------

Getting started:    getting-started.html

PyPy Documentation: index.html

PyPy Homepage:      https://pypy.org

PyPy is a MIT-licensed reimplementation of Python written in
Python itself.  The long term goals are an implementation that
is flexible and easy to experiment with and retarget to
different platforms (also non-C ones) and such that high
performance can be achieved through high-level implementations
of dynamic optimization techniques.

The interpreter and object model implementations shipped with 0.6 can
be run on top of CPython and implement the core language features of
Python as of CPython 2.3.  PyPy passes around 90% of the Python language
regression tests that do not depend deeply on C-extensions.  Some of
that functionality is still made available by PyPy piggy-backing on
the host CPython interpreter.  Double interpretation and abstractions
in the code-base make it so that PyPy running on CPython is quite slow
(around 2000x slower than CPython ), this is expected.  

This release is intended for people that want to look and get a feel
into what we are doing, playing with interpreter and perusing the
codebase.  Possibly to join in the fun and efforts.

Interesting bits and highlights
---------------------------------

The release is also a snap-shot of our ongoing efforts towards 
low-level translation and experimenting with unique features. 

* By default, PyPy is a Python version that works completely with
  new-style-classes semantics.  However, support for old-style classes
  is still available.  Implementations, mostly as user-level code, of
  their metaclass and instance object are included and can be re-made
  the default with the ``--oldstyle`` option.

* In PyPy, bytecode interpretation and object manipulations 
  are well separated between a bytecode interpreter and an 
  *object space* which implements operations on objects. 
  PyPy comes with experimental object spaces augmenting the
  standard one through delegation:

  * an experimental object space that does extensive tracing of
    bytecode and object operations;

  * the 'thunk' object space that implements lazy values and a 'become'
    operation that can exchange object identities.
  
  These spaces already give a glimpse in the flexibility potential of
  PyPy.  See demo/fibonacci.py and demo/sharedref.py for examples
  about the 'thunk' object space.

* The 0.6 release also contains a snapshot of our translation-efforts 
  to lower level languages.  For that we have developed an
  annotator which is capable of inferring type information
  across our code base.  The annotator right now is already
  capable of successfully type annotating basically *all* of
  PyPy code-base, and is included with 0.6.  

* From type annotated code, low-level code needs to be generated.
  Backends for various targets (C, LLVM,...) are included; they are
  all somehow incomplete and have been and are quite in flux. What is
  shipped with 0.6 is able to deal with more or less small/medium examples.


Ongoing work and near term goals
---------------------------------

Generating low-level code is the main area we are hammering on in the
next months; our plan is to produce a PyPy version in August/September 
that does not need to be interpreted by CPython anymore and will 
thus run considerably faster than the 0.6 preview release. 

PyPy has been a community effort from the start and it would
not have got that far without the coding and feedback support
from numerous people.   Please feel free to give feedback and 
raise questions. 

    contact points: https://pypy.org/contact.html

    contributor list: contributor.html

have fun, 

    Armin Rigo, Samuele Pedroni, 

    Holger Krekel, Christian Tismer, 

    Carl Friedrich Bolz 


    PyPy development and activities happen as an open source project  
    and with the support of a consortium funded by a two year EU IST 
    research grant. Here is a list of partners of the EU project: 
        
        Heinrich-Heine University (Germany), AB Strakt (Sweden)

        merlinux GmbH (Germany), tismerysoft GmbH(Germany) 

        Logilab Paris (France), DFKI GmbH (Germany)

        ChangeMaker (Sweden)

