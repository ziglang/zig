Motivating JIT Compiler Generation
==================================

.. contents::

This is a non-technical introduction and motivation for RPython's approach
to Just-In-Time compiler generation.


Motivation
----------

Overview
~~~~~~~~

Writing an interpreter for a complex dynamic language like Python is not
a small task, especially if, for performance goals, we want to write a
Just-in-Time (JIT) compiler too.

The good news is that it's not what we did.  We indeed wrote an
interpreter for Python, but we never wrote any JIT compiler for Python
in PyPy.  Instead, we use the fact that our interpreter for Python is
written in RPython, which is a nice, high-level language -- and we turn
it *automatically* into a JIT compiler for Python.

This transformation is of course completely transparent to the user,
i.e. the programmer writing Python programs.  The goal (which we
achieved) is to support *all* Python features -- including, for example,
random frame access and debuggers.  But it is also mostly transparent to
the language implementor, i.e. to the source code of the Python
interpreter.  It only needs a bit of guidance: we had to put a small
number of hints in the source code of our interpreter.  Based on these
hints, the *JIT compiler generator* produces a JIT compiler which has
the same language semantics as the original interpreter by construction.
This JIT compiler itself generates machine code at runtime, aggressively
optimizing the user's program and leading to a big performance boost,
while keeping the semantics unmodified.  Of course, the interesting bit
is that our Python language interpreter can evolve over time without
getting out of sync with the JIT compiler.


The path we followed
~~~~~~~~~~~~~~~~~~~~

Our previous incarnations of PyPy's JIT generator were based on partial
evaluation. This is a well-known and much-researched topic, considered
to be very promising. There have been many attempts to use it to
automatically transform an interpreter into a compiler. However, none of
them have lead to substantial speedups for real-world languages. We
believe that the missing key insight is to use partial evaluation to
produce just-in-time compilers, rather than classical ahead-of-time
compilers.  If this turns out to be correct, the practical speed of
dynamic languages could be vastly improved.

All these previous JIT compiler generators were producing JIT compilers
similar to the hand-written Psyco.  But today, starting from 2009, our
prototype is no longer using partial evaluation -- at least not in a way
that would convince paper reviewers.  It is instead based on the notion
of *tracing JIT,* recently studied for Java and JavaScript.  When
compared to all existing tracing JITs so far, however, partial
evaluation gives us some extra techniques that we already had in our
previous JIT generators, notably how to optimize structures by removing
allocations.

The closest comparison to our current JIT is Tamarin's TraceMonkey.
However, this JIT compiler is written manually, which is quite some
effort.  Instead, we write a JIT generator at the level of RPython,
which means that our final JIT does not have to -- indeed, cannot -- be
written to encode all the details of the full Python language.  These
details are automatically supplied by the fact that we have an
interpreter for full Python.


Practical results
~~~~~~~~~~~~~~~~~

The JIT compilers that we generate use some techniques that are not in
widespread use so far, but they are not exactly new either.  The point
we want to make here is not that we are pushing the theoretical limits
of how fast a given dynamic language can be run.  Our point is: we are
making it **practical** to have reasonably good Just-In-Time compilers
for all dynamic languages, no matter how complicated or non-widespread
(e.g. Open Source dynamic languages without large industry or academic
support, or internal domain-specific languages).  By practical we mean
that this should be:

* Easy: requires little more efforts than writing the interpreter in the
  first place.

* Maintainable: our generated JIT compilers are not separate projects
  (we do not generate separate source code, but only throw-away C code
  that is compiled into the generated VM).  In other words, the whole
  JIT compiler is regenerated anew every time the high-level interpreter
  is modified, so that they cannot get out of sync no matter how fast
  the language evolves.

* Fast enough: we can get some rather good performance out of the
  generated JIT compilers.  That's the whole point, of course.


Alternative approaches to improve speed
---------------------------------------

+----------------------------------------------------------------------+
| :NOTE:                                                               |
|                                                                      |
|   Please take the following section as just a statement of opinion.  |
|   In order to be debated over, the summaries should first be         |
|   expanded into full arguments.  We include them here as links;      |
|   we are aware of them, even if sometimes pessimistic about them     |
|   ``:-)``                                                            |
+----------------------------------------------------------------------+

There are a large number of approaches to improving the execution speed of
dynamic programming languages, most of which only produce small improvements
and none offer the flexibility and customisability provided by our approach.
Over the last 6 years of tweaking, the speed of CPython has only improved by a
factor of 1.3 or 1.4 (depending on benchmarks).  Many tweaks are applicable to
PyPy as well. Indeed, some of the CPython tweaks originated as tweaks for PyPy.

IronPython initially achieved a speed of about 1.8 times that of CPython by
leaving out some details of the language and by leveraging the large investment
that Microsoft has put into making the .NET platform fast; the current, more
complete implementation has roughly the same speed as CPython.  In general, the
existing approaches have reached the end of the road, speed-wise.  Microsoft's
Dynamic Language Runtime (DLR), often cited in this context, is essentially
only an API to make the techniques pioneered in IronPython official.  At best,
it will give another small improvement.

Another technique regularly mentioned is adding types to the language in order
to speed it up: either explicit optional typing or soft typing (i.e., inferred
"likely" types).  For Python, all projects in this area have started with a
simplified subset of the language; no project has scaled up to anything close
to the complete language.  This would be a major effort and be platform- and
language-specific.  Moreover maintenance would be a headache: we believe that
many changes that are trivial to implement in CPython, are likely to invalidate
previous carefully-tuned optimizations.

For major improvements in speed, JIT techniques are necessary.  For Python,
Psyco gives typical speedups of 2 to 4 times - up to 100 times in algorithmic
examples.  It has come to a dead end because of the difficulty and huge costs
associated with developing and maintaining it.  It has a relatively poor
encoding of language semantics - knowledge about Python behavior needs to be
encoded by hand and kept up-to-date.  At least, Psyco works correctly even when
encountering one of the numerous Python constructs it does not support, by
falling back to CPython.  The PyPy JIT started out as a metaprogrammatic,
non-language-specific equivalent of Psyco.

A different kind of prior art are self-hosting JIT compilers such as Jikes.
Jikes is a JIT compiler for Java written in Java. It has a poor encoding of
language semantics; it would take an enormous amount of work to encode all the
details of a Python-like language directly into a JIT compiler.  It also has
limited portability, which is an issue for Python; it is likely that large
parts of the JIT compiler would need retargetting in order to run in a
different environment than the intended low-level one.

Simply reusing an existing well-tuned JIT like that of the JVM does not
really work, because of concept mismatches between the implementor's
language and the host VM language: the former needs to be compiled to
the target environment in such a way that the JIT is able to speed it up
significantly - an approach which essentially has failed in Python so
far: even though CPython is a simple interpreter, its Java and .NET
re-implementations are not significantly faster.

More recently, several larger projects have started in the JIT area.  For
instance, Sun Microsystems is investing in JRuby, which aims to use the Java
Hotspot JIT to improve the performance of Ruby. However, this requires a lot of
hand crafting and will only provide speedups for one language on one platform.
Some issues are delicate, e.g., how to remove the overhead of constantly boxing
and unboxing, typical in dynamic languages.  An advantage compared to PyPy is
that there are some hand optimizations that can be performed, that do not fit
in the metaprogramming approach.  But metaprogramming makes the PyPy JIT
reusable for many different languages on many different execution platforms.
It is also possible to combine the approaches - we can get substantial speedups
using our JIT and then feed the result to Java's Hotspot JIT for further
improvement.  One of us is even a member of the `JSR 292`_ Expert Group
to define additions to the JVM to better support dynamic languages, and
is contributing insights from our JIT research, in ways that will also
benefit PyPy.

Finally, tracing JITs are now emerging for dynamic languages like
JavaScript with TraceMonkey.  The code generated by PyPy is very similar
(but not hand-written) to the concepts of tracing JITs.

.. _JSR 292: http://jcp.org/en/jsr/detail?id=292


Further reading
---------------

The description of the current RPython JIT generator is given in :doc:`PyJitPl5 <pyjitpl5>`
(draft).
