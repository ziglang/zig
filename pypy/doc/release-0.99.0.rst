======================================================================
pypy-0.99.0: new object spaces, optimizations, configuration ... 
======================================================================

Welcome to the PyPy 0.99.0 release - a major snapshot
and milestone of the last 8 months of work and contributions 
since PyPy-0.9.0 came out in June 2006!

Main entry point for getting-started/download and documentation: 

    https://codespeak.net/pypy/dist/pypy/doc/index.html

Further below you'll find some notes about PyPy,
the 0.99.0 highlights and our aims for PyPy 1.0. 

have fun, 

    the PyPy team, 
    Samuele Pedroni, Carl Friedrich Bolz, Armin Rigo, Michael Hudson,
    Maciej Fijalkowski, Anders Chrigstroem, Holger Krekel,
    Guido Wesdorp

    and many others: 
    https://codespeak.net/pypy/dist/pypy/doc/contributor.html


What is PyPy? 
================================

Technically, PyPy is both a Python Interpreter implementation 
and an advanced Compiler, actually a framework for implementing 
dynamic languages and generating virtual machines for them.
The Framework allows for alternative frontends and
for alternative backends, currently C, LLVM and .NET.  
For our main target "C", we can can "mix in" different Garbage
Collectors and threading models, including micro-threads aka
"Stackless".  The inherent complexity that arises from this
ambitious approach is mostly kept away from the Python
interpreter implementation, our main frontend.

Socially, PyPy is a collaborative effort of many individuals
working together in a distributed and sprint-driven way since
2003.  PyPy would not have gotten as far without the coding,
feedback and general support from numerous people. 

Formally, many of the current developers are involved in
executing an EU contract with the goal of exploring and
researching new approaches to Language/Compiler development and
software engineering.  This contract's duration is about to
end March 2007 and we are working and preparing the according
final review which is scheduled for May 2007.  


Key 0.99.0 Features 
=====================

* new object spaces:

  - Tainting: a 270-line proxy object space tracking 
    and boxing sensitive information within an application. 
    A tainted object is completely barred from crossing 
    an I/O barrier, such as writing to files, databases
    or sockets.  This allows to significantly reduce the 
    effort of e.g. security reviews to the few places where 
    objects are "declassified" in order to send information 
    across I/O barriers. 

  - Transparent proxies: allow to customize both application and
    builtin objects from application level code.  Works as an addition
    to the Standard Object Space (and is translatable). For details see
    https://codespeak.net/pypy/dist/pypy/doc/proxy.html
 
* optimizations: 

  - Experimental new optimized implementations for various built in Python
    types (strings, dicts, lists)

  - Optimized builtin lookups to not require any dictionary lookups if the
    builtin is not shadowed by a name in the global dictionary.

  - Improved inlining (now also working for higher level
    backends) and malloc removal.

  - twice the speed of the 0.9 release, overall 2-3 slower than CPython 

* High level backends:

  - It is now possible to translate the PyPy interpreter to run on the .NET
    platform, which gives a very compliant (but somewhat slow) Python
    interpreter.

  - the JavaScript backend has evolved to a point where it can be used to write
    AJAX web applications with it. This is still an experimental technique,
    though. For demo applications see:
    https://play1.codespeak.net/ 

* new configuration system: 
  There is a new comprehensive configuration system that allows 
  fine-grained configuration of the PyPy standard interpreter and the
  translation process. 

* new and improved modules: Since the last release, the signal, mmap, bz2
  and fcntl standard library modules have been implemented for PyPy. The socket, 
  _sre and os modules have been greatly improved. In addition we added a the
  pypymagic module that contains PyPy-specific functionality.

* improved file implementation: Our file implementation was ported to RPython
  and is therefore faster (and not based on libc).

* The stability of stackless features was greatly improved. For more details
  see: https://codespeak.net/pypy/dist/pypy/doc/stackless.html

* RPython library: The release contains our emerging RPython library that tries
  to make programming in RPython more pleasant. It contains an experimental
  parser generator framework. For more details see:
  https://codespeak.net/pypy/dist/pypy/doc/rlib.html

* improved documentation:
  
  - extended documentation about stackless features:
    https://codespeak.net/pypy/dist/pypy/doc/stackless.html
  
  - PyPy video documentation: eight hours of talks, interviews and features:
    https://codespeak.net/pypy/dist/pypy/doc/video-index.html

  - technical reports about various aspects of PyPy:
    https://codespeak.net/pypy/dist/pypy/doc/index-report.html
    
  The entry point to all our documentation is:
  https://codespeak.net/pypy/dist/pypy/doc/index.html



What about 1.0? 
======================

In the last week leading up to the release, we decided
to go for tagging the release as 0.99.0, mainly because
we have some efforts pending to integrate and complete 
research and coding work: 

* the JIT Compiler Generator is ready, but not fully integrated
  with the PyPy interpreter.  As a result, the JIT does not give
  actual speed improvements yet, so we chose to leave it out of the
  0.99 release: the result doesn't meet yet the speed expectations
  that we set for ourselves - and which some blogs and people 
  have chosen as the main criterium for looking at PyPy.

* the extension enabling runtime changes of the Python grammar is not
  yet integrated. This will be used to provide Aspect-Oriented
  Programming extensions and Design by Contract facilities in PyPy. 

* the Logic object space, which provides Logic Variables in PyPy,
  needs to undergo a bit more testing. A constraint problem solver
  extension module is ready, and needs to be integrated with the codebase. 

PyPy 0.99 is the start for getting to 1.0 end of March 2007,
which we intend to become a base for a longer (and more relaxed :) 
time to come. 



Funding partners and organizations
=====================================================
    
PyPy development and activities happen as an open source project  
and with the support of a consortium partially funded by a 28 months
European Union IST research grant. The full partners of that 
consortium are: 
        
    Heinrich-Heine University (Germany), Open End (Sweden)
    merlinux GmbH (Germany), tismerysoft GmbH (Germany) 
    Logilab Paris (France), DFKI GmbH (Germany)
    ChangeMaker (Sweden), Impara (Germany)

