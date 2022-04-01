==========================================
PyPy 1.0: JIT compilers for free and more
==========================================

Welcome to the PyPy 1.0 release - a milestone integrating the results 
of four years of research, engineering, management and sprinting 
efforts, concluding the 28 months phase of EU co-funding!

Although still not mature enough for general use, PyPy 1.0 materializes
for the first time the full extent of our original vision:

- A flexible Python interpreter, written in "RPython":

  - Mostly unaware of threading, memory and lower-level target platform
    aspects.
  - Showcasing advanced interpreter features and prototypes.
  - Passing core CPython regression tests, translatable to C, LLVM and .NET.

- An advanced framework to translate such interpreters and programs:

  - That performs whole type-inference on RPython programs.
  - Can weave in threading, memory and target platform aspects.
  - Has low level (C, LLVM) and high level (CLI, Java, JavaScript) backends.

- A **Just-In-Time Compiler generator** able to **automatically**
  enhance the low level versions of our Python interpreter, leading to
  run-time machine code that runs algorithmic examples at speeds typical
  of JITs!

Previous releases, particularly the 0.99.0 release from February,
already highlighted features of our Python implementation and the
abilities of our translation approach but the **new JIT generator**
clearly marks a major research result and gives weight to our vision
that one can generate efficient interpreter implementations, starting
from a description in a high level language.

We have prepared several entry points to help you get started:

* The main entry point for JIT documentation and status:

   https://codespeak.net/pypy/dist/pypy/doc/jit.html

* The main documentation and getting-started PyPy entry point:

   https://codespeak.net/pypy/dist/pypy/doc/index.html

* Our online "play1" demos showcasing various Python interpreters,
  features (and a new way to program AJAX applications):

   https://play1.codespeak.net/

* Our detailed and in-depth Reports about various aspects of the
  project:

   https://codespeak.net/pypy/dist/pypy/doc/index-report.html

In the next few months we are going to discuss the goals and form of
the next stage of development - now more than ever depending on your
feedback and contributions - and we hope you appreciate PyPy 1.0 as an
interesting basis for greater things to come, as much as we do
ourselves!

have fun,

    the PyPy release team,
    Samuele Pedroni, Armin Rigo, Holger Krekel, Michael Hudson,
    Carl Friedrich Bolz, Antonio Cuni, Anders Chrigstroem, Guido Wesdorp
    Maciej Fijalkowski, Alexandre Fayolle

    and many others:
    https://codespeak.net/pypy/dist/pypy/doc/contributor.html


What is PyPy?
================================

Technically, PyPy is both a Python interpreter implementation and an
advanced compiler, or more precisely a framework for implementing dynamic
languages and generating virtual machines for them.

The framework allows for alternative frontends and for alternative
backends, currently C, LLVM and .NET.  For our main target "C", we can
can "mix in" different garbage collectors and threading models,
including micro-threads aka "Stackless".  The inherent complexity that
arises from this ambitious approach is mostly kept away from the Python
interpreter implementation, our main frontend.

PyPy is now also a Just-In-Time compiler generator.  The translation
framework contains the now-integrated JIT generation technology.  This
depends only on a few hints added to the interpreter source and should
be able to cope with the changes to the interpreter and be generally
applicable to other interpreters written using the framework.

Socially, PyPy is a collaborative effort of many individuals working
together in a distributed and sprint-driven way since 2003.  PyPy would
not have gotten as far as it has without the coding, feedback and
general support from numerous people.

Formally, many of the current developers were involved in executing an
EU contract with the goal of exploring and researching new approaches
to language and compiler development and software engineering.  This
contract's duration is about to end this month (March 2007) and we are
working and preparing the according final review which is scheduled
for May 2007.

For the future, we are in the process of setting up structures to help
maintain conceptual integrity of the project and to discuss and deal
with funding opportunities related to further PyPy sprinting and
developments. See here for results of the discussion so far:

    https://codespeak.net/pipermail/pypy-dev/2007q1/003577.html


1.0.0 Feature highlights
==============================


Here is a summary list of key features included in PyPy 1.0:

- The Just-In-Time compiler generator, now capable of generating the
  first JIT compiler versions of our Python interpreter:

   https://codespeak.net/pypy/dist/pypy/doc/jit.html

- More Python interpreter optimizations (a CALL_METHOD bytecode, a method
  cache, rope-based strings), now running benchmarks at around half of
  CPython's speed (without the JIT):

   https://codespeak.net/pypy/dist/pypy/doc/interpreter-optimizations.html

- The Python interpreter can be translated to .NET and enables
  interactions with the CLR libraries:

   https://codespeak.net/pypy/dist/pypy/doc/cli-backend.html
   https://codespeak.net/pypy/dist/pypy/doc/clr-module.html

- Aspect Oriented Programming facilities (based on mutating the Abstract
  Syntax Tree):

   https://codespeak.net/pypy/dist/pypy/doc/aspect_oriented_programming.html
   https://codespeak.net/pypy/extradoc/eu-report/D10.1_Aspect_Oriented_Programming_in_PyPy-2007-03-22.pdf

- The JavaScript backend has evolved to a point where it can be used to
  write AJAX web applications with it. This is still an experimental
  technique, though. For demo applications which also showcase various
  generated Python and PROLOG interpreters, see:

   https://play1.codespeak.net/

- Proxying object spaces and features of our Python interpreter:

  - Tainting: a 270-line proxy object space tracking and boxing
    sensitive information within an application.

  - Transparent proxies: allow the customization of both application and
    builtin objects from application level code.  Now featuring an
    initial support module (tputil.py) for working with transparent
    proxies.

For a detailed description and discussion of high level backends and
Python interpreter features, please see our extensive "D12" report:

https://codespeak.net/pypy/extradoc/eu-report/D12.1_H-L-Backends_and_Feature_Prototypes-2007-03-22.pdf


Funding partners and organizations
=====================================================

PyPy development and activities happen as an open source project and
with the support of a consortium partially funded by a 28 month
European Union IST research grant for the period from December 2004 to
March 2007. The full partners of that consortium are:

    Heinrich-Heine University (Germany), Open End (Sweden)
    merlinux GmbH (Germany), tismerysoft GmbH (Germany)
    Logilab Paris (France), DFKI GmbH (Germany)
    ChangeMaker (Sweden), Impara (Germany)
