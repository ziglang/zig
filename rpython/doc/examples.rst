Projects Using RPython
======================

A very time-dependent list of interpreters written in RPython. Corrections welcome,
this list was last curated in
Nov 2016

Actively Developed:

  * PyPy, Python2 and Python3, very complete and maintained, http://pypy.org
  * Pydgin, CPU emulation framework, supports ARM well, jitted, active
    development, https://github.com/cornell-brg/pydgin
  * RSqueak VM, Smalltalk, core complete, JIT working, graphics etc getting
    there, in active development https://github.com/HPI-SWA-Lab/RSqueak
  * Pixie, 'A small, fast, native lisp with "magical" powers', jitted,
    maintained, https://github.com/pixie-lang/pixie
  * Monte, 'A dynamic language inspired by Python and E.' has an rpython
    implementation, in active development, https://github.com/monte-language/typhon
  * Typhon, 'A virtual machine for Monte', in active development,
    https://github.com/monte-language/typhon
  * Tulip, an untyped functional language, in language design mode, maintained,
    https://github.com/tulip-lang/tulip/
  * Pycket, a Racket implementation, proof of concept, small language core
    working, a lot of primitives are missing. Slow development 
    https://github.com/samth/pycket
  * Lever, a dynamic language with a modifiable grammar, actively developed,
    https://github.com/cheery/lever

Complete, functioning, but inactive

  * Converge 2, complete, last release version 2.1 in Feb 2015, http://convergepl.org/
  * Pyrolog, Prolog, core complete, extensions missing, last commit in Nov
    2015, https://hg.sr.ht/~cfbolz/Pyrolog
  * PyPy.js, compiles PyPy to Javascript via emscripten_, with a custom JIT 
    backend that emits asm.js_ code at runtime, http://pypyjs.org

.. _emscripten: http://emscripten.org
.. _asm.js: http://asmjs.org

Inactive (last reviewed Sept 2015):

  * Topaz, Ruby, major functionality complete, library missing, inactive http://topazruby.com
  * Rapydo, R, execution semantics complete, most builtins missing, inactive, http://bitbucket.org/cfbolz/rapydo
  * Hippy, PHP, proof of concept, inactive, http://morepypy.blogspot.de/2012/07/hello-everyone.html
  * Scheme, no clue about completeness, inactive, http://bitbucket.org/pypy/lang-scheme/
  * PyGirl, Gameboy emulator, works but there is a bug somewhere, does not use JIT, unmaintained, http://bitbucket.org/pypy/lang-gameboy
  * Javascript, proof of concept, inactive, http://bitbucket.org/pypy/lang-js
  * An implementation of Notch's DCPU-16, https://github.com/AlekSi/dcpu16py/tree/pypy-again
  * Haskell, core of the language works, but not many libraries, inactive http://bitbucket.org/cfbolz/haskell-python
  * IO, no clue about completeness, inactive https://bitbucket.org/pypy/lang-io
  * Qoppy, an implementation Qoppa, which is a scheme without special forms: https://github.com/timfel/qoppy
  * XlispX, a toy Lisp: https://bitbucket.org/rxe/xlispx
  * RPySOM, an RPython implementation of SOM (Simple Object Model) https://github.com/SOM-st/RPySOM          
  * SQPyte, really experimental implementation of the SQLite bytecode VM, jitted, probably inactive, https://bitbucket.org/softdevteam/sqpyte
  * Icbink, an implementation of Kernel, core complete, naive, no JIT optimizations yet, on hiatus https://github.com/euccastro/icbink

