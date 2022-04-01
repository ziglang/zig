Project Documentation
=====================

:doc:`architecture <architecture>` gives a complete view of PyPy's basic design.

:doc:`coding guide <coding-guide>` helps you to write code for PyPy (especially also describes
coding in RPython a bit).

:doc:`sprint reports <sprint-reports>` lists reports written at most of our sprints, from
2003 to the present.

:doc:`papers, talks and related projects <extradoc>` lists presentations
and related projects as well as our published papers.

:doc:`PyPy video documentation <video-index>` is a page linking to the videos (e.g. of talks and
introductions) that are available.

:doc:`Technical reports <index-report>` is a page that contains links to the
reports that we submitted to the European Union.

:doc:`development methodology <dev_method>` describes our sprint-driven approach.

:source:`LICENSE` contains licensing details (basically a straight MIT-license).

:doc:`glossary` of PyPy words to help you align your inner self with
the PyPy universe.

.. toctree::
   :hidden:

   coding-guide
   sprint-reports
   extradoc
   eventhistory
   video-index
   index-report
   discussions
   dev_method
   embedding
   objspace-proxies


Source Code Documentation
=========================

:doc:`object spaces <objspace>` discusses the object space interface
and several implementations.

:doc:`bytecode interpreter <interpreter>` explains the basic mechanisms
of the bytecode interpreter and virtual machine.

:doc:`interpreter-optimizations` describes our various strategies for
improving the performance of our interpreter, including alternative
object implementations (for strings, dictionaries and lists) in the
standard object space.

`dynamic-language translation`_ is a paper that describes
the translation process, especially the flow object space
and the annotator in detail. (This document is one
of the :doc:`EU reports <index-report>`.)

:doc:`parser <parser>` contains (outdated, unfinished) documentation about
the parser.

:doc:`configuration documentation <config/index>` describes the various configuration options that
allow you to customize PyPy.

:doc:`command line reference <commandline_ref>`

:doc:`directory cross-reference <dir-reference>`

.. _dynamic-language translation: https://foss.heptapod.net/pypy/extradoc/-/tree/branch/extradoc/eu-report/D05.1_Publish_on_translating_a_very-high-level_description.pdf

.. toctree::
   :hidden:

   objspace
   interpreter
   interpreter-optimizations
   parser
   config/index
   commandline_ref
   dir-reference
