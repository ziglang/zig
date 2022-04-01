pypy-0.8.0: Translatable compiler/parser and some more speed 
==============================================================

The PyPy development team has been busy working and we've now packaged 
our latest improvements, completed work and new experiments as 
version 0.8.0, our third public release.

The highlights of this third release of PyPy are:

- Translatable parser and AST compiler. PyPy now integrates its own
  compiler based on Python own 'compiler' package but with a number
  of fixes and code simplifications in order to get it translated 
  with the rest of PyPy.  This makes using the translated pypy 
  interactively much more pleasant, as compilation is considerably 
  faster than in 0.7.0.

- Some Speed enhancements. Translated PyPy is now about 10 times
  faster than 0.7 but still 10-20 times slower than
  CPython on pystones and other benchmarks.  At the same time, 
  language compliance has been slightly increased compared to 0.7
  which had already reached major CPython compliance goals. 

- Some experimental features are now translatable.  Since 0.6.0, PyPy
  shipped with an experimental Object Space (the part of PyPy
  implementing Python object operations and manipulation) implementing
  lazily computed objects, the "Thunk" object space. With 0.8.0 this
  object space can also be translated preserving its feature
  additions.

What is PyPy (about)? 
------------------------------------------------

PyPy is a MIT-licensed research-oriented reimplementation of
Python written in Python itself, flexible and easy to
experiment with.  It translates itself to lower level
languages.  Our goals are to target a large variety of
platforms, small and large, by providing a compilation toolsuite
that can produce custom Python versions.  Platform, Memory and
Threading models are to become aspects of the translation
process - as opposed to encoding low level details into a
language implementation itself.  Eventually, dynamic
optimization techniques - implemented as another translation
aspect - should become robust against language changes.

Note that PyPy is mainly a research and development project
and does not by itself focus on getting a production-ready
Python implementation although we do hope and expect it to
become a viable contender in that area sometime next year. 

PyPy is partially funded as a research project under the 
European Union's IST programme. 

Where to start? 
-----------------------------

Getting started:    https://codespeak.net/pypy/dist/pypy/doc/getting-started.html

PyPy Documentation: https://codespeak.net/pypy/dist/pypy/doc/ 

PyPy Homepage:      https://codespeak.net/pypy/

The interpreter and object model implementations shipped with
the 0.8 version can run on their own and implement the core
language features of Python as of CPython 2.4.  However, we still
do not recommend using PyPy for anything else than for education, 
playing or research purposes.  

Ongoing work and near term goals
---------------------------------

At the last sprint in Paris we started exploring the new directions of
our work, in terms of extending and optimizing PyPy further. We
started to scratch the surface of Just-In-Time compiler related work,
which we still expect will be the major source of our future speed
improvements and some successful amount of work has been done on the
support needed for stackless-like features.
  
This release also includes the snapshots in preliminary or embryonic
form of the following interesting but yet not completed sub projects:

- The OOtyper, a RTyper variation for higher-level backends 
  (Squeak, ...)
- A JavaScript backend
- A limited (PPC) assembler backend (this related to the JIT)
- some bits for a socket module

PyPy has been developed during approximately 16 coding sprints across
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
