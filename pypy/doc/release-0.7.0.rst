pypy-0.7.0: first PyPy-generated Python Implementations
==============================================================

What was once just an idea between a few people discussing 
on some nested mailing list thread and in a pub became reality ... 
the PyPy development team is happy to announce its first
public release of a fully translatable self contained Python
implementation.  The 0.7 release showcases the results of our
efforts in the last few months since the 0.6 preview release
which have been partially funded by the European Union:

- whole program type inference on our Python Interpreter 
  implementation with full translation to two different 
  machine-level targets: C and LLVM 

- a translation choice of using a refcounting or Boehm 
  garbage collectors

- the ability to translate with or without thread support 

- very complete language-level compliance with CPython 2.4.1 


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


Where to start? 
-----------------------------

Getting started:    https://codespeak.net/pypy/dist/pypy/doc/getting-started.html

PyPy Documentation: https://codespeak.net/pypy/dist/pypy/doc/ 

PyPy Homepage:      https://codespeak.net/pypy/

The interpreter and object model implementations shipped with
the 0.7 version can run on their own and implement the core
language features of Python as of CPython 2.4.  However, we still
do not recommend using PyPy for anything else than for education, 
playing or research purposes.  

Ongoing work and near term goals
---------------------------------

PyPy has been developed during approximately 15 coding sprints
across Europe and the US.  It continues to be a very
dynamically and incrementally evolving project with many
one-week meetings to follow.  You are invited to consider coming to 
the next such meeting in Paris mid October 2005 where we intend to 
plan and head for an even more intense phase of the project
involving building a JIT-Compiler and enabling unique
features not found in other Python language implementations.

PyPy has been a community effort from the start and it would
not have got that far without the coding and feedback support
from numerous people.   Please feel free to give feedback and 
raise questions. 

    contact points: https://codespeak.net/pypy/dist/pypy/doc/contact.html

    contributor list: https://codespeak.net/pypy/dist/pypy/doc/contributor.html

have fun, 
    
    the pypy team, of which here is a partial snapshot
    of mainly involved persons: 

    Armin Rigo, Samuele Pedroni, 
    Holger Krekel, Christian Tismer, 
    Carl Friedrich Bolz, Michael Hudson, 
    Eric van Riet Paap, Richard Emslie, 
    Anders Chrigstroem, Anders Lehmann, 
    Ludovic Aubry, Adrien Di Mascio, 
    Niklaus Haldimann, Jacob Hallen, 
    Bea During, Laura Creighton, 
    and many contributors ... 

PyPy development and activities happen as an open source project  
and with the support of a consortium partially funded by a two 
year European Union IST research grant. Here is a list of 
the full partners of that consortium: 
        
    Heinrich-Heine University (Germany), AB Strakt (Sweden)
    merlinux GmbH (Germany), tismerysoft GmbH(Germany) 
    Logilab Paris (France), DFKI GmbH (Germany)
    ChangeMaker (Sweden), Impara (Germany)
