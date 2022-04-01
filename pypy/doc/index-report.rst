.. warning::

   Some of these reports are interesting for historical reasons only.

PyPy - Overview over the EU-reports
===================================

Below reports summarize and discuss research and development results
of the PyPy project during the EU funding period (Dez 2004 - March 2007).
They also are very good documentation if you'd like to know in more
detail about motivation and implementation of the various parts
and aspects of PyPy.  Feel free to send questions or comments
to `pypy-dev`_, the development list.


Reports of 2007
---------------

The `PyPy EU Final Activity Report`_ summarizes the 28 month EU project
period (Dec 2004-March 2007) on technical, scientific and community levels.
You do not need prior knowledge about PyPy but some technical knowledge about
computer language implementations is helpful.  The report contains reflections
and recommendations which might be interesting for other project aiming
at funded Open Source research. *(2007-05-11)*

`D09.1 Constraint Solving and Semantic Web`_ is  a report about PyPy's logic
programming and constraint solving features, as well as the work going on to
tie semantic web technologies and PyPy together. *(2007-05-11)*

`D14.4 PyPy-1.0 Milestone report`_ (for language developers and researchers)
summarizes research & technical results of the PyPy-1.0 release and discusses
related development process and community aspects. *(2007-05-01)*

`D08.2 JIT Compiler Architecture`_ is a report about the Architecture and
working of our JIT compiler generator. *(2007-05-01)*

`D08.1 JIT Compiler Release`_ reports on our successfully including a
JIT compiler for Python and the novel framework we used to
automatically generate it in PyPy 1.0. *(2007-04-30)*

`D06.1 Core Object Optimization Results`_ documents the optimizations
we implemented in the interpreter and object space: dictionary
implementations, method call optimizations, etc. The report is still not final
so we are very interested in any feedback *(2007-04-04)*

`D14.5 Documentation of the development process`_ documents PyPy's
sprint-driven development process and puts it into the context of agile
methodologies. *(2007-03-30)*

`D13.1 Integration and Configuration`_ is a report about our build and
configuration toolchain as well as the planned Debian packages. It also
describes the work done to integrate the results of other workpackages into the
rest of the project. *(2007-03-30)*

`D02.2 Release Scheme`_ lists PyPy's six public releases and explains the release structure, tools, directories and policies for performing PyPy releases. *(2007-03-30)*

`D01.2-4 Project Organization`_ is a report about the management activities
within the PyPy project and PyPy development process. *(2007-03-28)*

`D11.1 PyPy for Embedded Devices`_ is a report about the possibilities of using
PyPy technology for programming embedded devices. *(2007-03-26)*

`D02.3 Testing Tool`_ is a report about the
`py.test`_ testing tool which is part of the `py-lib`_. *(2007-03-23)*

`D10.1 Aspect-Oriented, Design-by-Contract Programming and RPython static
checking`_ is a report about the ``aop`` module providing an Aspect Oriented
Programming mechanism for PyPy, and how this can be leveraged to implement a
Design-by-Contract module. It also introduces RPylint static type checker for
RPython code. *(2007-03-22)*

`D12.1 High-Level-Backends and Feature Prototypes`_ is
a report about our high-level backends and our
several validation prototypes: an information flow security prototype,
a distribution prototype and a persistence proof-of-concept. *(2007-03-22)*

`D14.2 Tutorials and Guide Through the PyPy Source Code`_ is
a report about the steps we have taken to make the project approachable for
newcomers. *(2007-03-22)*


`D02.1 Development Tools and Website`_ is a report
about the codespeak_ development environment and additional tool support for the
PyPy development process. *(2007-03-21)*

`D03.1 Extension Compiler`_ is a report about
PyPy's extension compiler and RCTypes, as well as the effort to keep up with
CPython's changes. *(2007-03-21)*


`D07.1 Massive Parallelism and Translation Aspects`_ is a report about
PyPy's optimization efforts, garbage collectors and massive parallelism
(stackless) features.  This report refers to the paper `PyPy's approach
to virtual machine construction`_.  Extends the content previously
available in the document "Memory management and threading models as
translation aspects -- solutions and challenges".  *(2007-02-28)*

.. _py-lib: https://pylib.org/
.. _py.test: https://pytest.org/
.. _codespeak: https://codespeak.net/
.. _pypy-dev: https://mail.python.org/mailman/listinfo/pypy-dev


Reports of 2006
---------------

`D14.3 Report about Milestone/Phase 2`_ is the final report about
the second phase of the EU project, summarizing and detailing technical,
research, dissemination and community aspects.  Feedback is very welcome!


Reports of 2005
---------------

`D04.1 Partial Python Implementation`_ contains details about the 0.6 release.
All the content can be found in the regular documentation section.

`D04.2 Complete Python Implementation`_ contains details about the 0.7 release.
All the content can be found in the regular documentation section.

`D04.3 Parser and Bytecode Compiler`_ describes our parser and bytecode compiler.

`D04.4 PyPy as a Research Tool`_ contains details about the 0.8 release.
All the content can be found in the regular documentation section.

`D05.1 Compiling Dynamic Language Implementations`_ is a paper that describes
the translation process, especially the flow object space and the annotator in
detail.

`D05.2 A Compiled Version of PyPy`_ contains more details about the 0.7 release.
All the content can be found in the regular documentation section.

`D05.3 Implementation with Translation Aspects`_
describes how our approach hides away a lot of low level details.

`D05.4 Encapsulating Low Level Aspects`_ describes how we weave different
properties into our interpreter during the translation process.

`D14.1 Report about Milestone/Phase 1`_ describes what happened in the PyPy
project during the first year of EU funding (December 2004 - December 2005)

.. _PyPy EU Final Activity Report: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/PYPY-EU-Final-Activity-Report.pdf
.. _D01.2-4 Project Organization: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D01.2-4_Project_Organization-2007-03-28.pdf
.. _D02.1 Development Tools and Website: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D02.1_Development_Tools_and_Website-2007-03-21.pdf
.. _D02.2 Release Scheme: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D02.2_Release_Scheme-2007-03-30.pdf
.. _D02.3 Testing Tool: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D02.3_Testing_Framework-2007-03-23.pdf
.. _D03.1 Extension Compiler: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D03.1_Extension_Compiler-2007-03-21.pdf
.. _D04.1 Partial Python Implementation: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D04.1_Partial_Python_Implementation_on_top_of_CPython.pdf
.. _D04.2 Complete Python Implementation: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D04.2_Complete_Python_Implementation_on_top_of_CPython.pdf
.. _D04.3 Parser and Bytecode Compiler: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D04.3_Report_about_the_parser_and_bytecode_compiler.pdf
.. _D04.4 PyPy as a Research Tool: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D04.4_Release_PyPy_as_a_research_tool.pdf
.. _D05.1 Compiling Dynamic Language Implementations: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D05.1_Publish_on_translating_a_very-high-level_description.pdf
.. _D05.2 A Compiled Version of PyPy: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D05.2_A_compiled,_self-contained_version_of_PyPy.pdf
.. _D05.3 Implementation with Translation Aspects: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D05.3_Publish_on_implementation_with_translation_aspects.pdf
.. _D05.4 Encapsulating Low Level Aspects: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D05.4_Publish_on_encapsulating_low_level_language_aspects.pdf
.. _D06.1 Core Object Optimization Results: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D06.1_Core_Optimizations-2007-04-30.pdf
.. _D07.1 Massive Parallelism and Translation Aspects: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D07.1_Massive_Parallelism_and_Translation_Aspects-2007-02-28.pdf
.. _D08.2 JIT Compiler Architecture: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D08.2_JIT_Compiler_Architecture-2007-05-01.pdf
.. _D08.1 JIT Compiler Release: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D08.1_JIT_Compiler_Release-2007-04-30.pdf
.. _D09.1 Constraint Solving and Semantic Web: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D09.1_Constraint_Solving_and_Semantic_Web-2007-05-11.pdf
.. _D10.1 Aspect-Oriented, Design-by-Contract Programming and RPython static checking: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D10.1_Aspect_Oriented_Programming_in_PyPy-2007-03-22.pdf
.. _D11.1 PyPy for Embedded Devices: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D11.1_PyPy_for_Embedded_Devices-2007-03-26.pdf
.. _D12.1 High-Level-Backends and Feature Prototypes: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D12.1_H-L-Backends_and_Feature_Prototypes-2007-03-22.pdf
.. _D13.1 Integration and Configuration: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D13.1_Integration_and_Configuration-2007-03-30.pdf
.. _D14.1 Report about Milestone/Phase 1: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D14.1_Report_about_Milestone_Phase_1.pdf
.. _D14.2 Tutorials and Guide Through the PyPy Source Code: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D14.2_Tutorials_and_Guide_Through_the_PyPy_Source_Code-2007-03-22.pdf
.. _D14.3 Report about Milestone/Phase 2: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D14.3_Report_about_Milestone_Phase_2-final-2006-08-03.pdf
.. _D14.4 PyPy-1.0 Milestone report: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D14.4_Report_About_Milestone_Phase_3-2007-05-01.pdf
.. _D14.5 Documentation of the development process: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/eu-report/D14.5_Documentation_of_the_development_process-2007-03-30.pdf

.. _PyPy's approach to virtual machine construction: https://foss.heptapod.net/pypy/extradoc/-/blob/branch/extradoc/talk/dls2006/pypy-vm-construction.pdf
