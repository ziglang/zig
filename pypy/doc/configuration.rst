PyPy's Configuration Handling
=============================

Due to more and more available configuration options it became quite annoying to
hand the necessary options to where they are actually used and even more
annoying to add new options. To circumvent these problems configuration
management was introduced. There all the necessary options are stored in a
configuration object, which is available nearly everywhere in the `RPython
toolchain`_ and in the standard interpreter so that adding new options becomes
trivial. Options are organized into a tree. Configuration objects can be
created in different ways, there is support for creating an optparse command
line parser automatically.

.. _RPython toolchain: https://rpython.readthedocs.org/


Main Assumption
---------------

Configuration objects are produced at the entry points  and handed down to
where they are actually used. This keeps configuration local but available
everywhere and consistent. The configuration values are created using the
command line.


API Details
-----------

The handling of options is split into two parts: the description of which
options are available, what their possible values and defaults are and how they
are organized into a tree. A specific choice of options is bundled into a
configuration object which has a reference to its option description (and
therefore makes sure that the configuration values adhere to the option
description).
This splitting is remotely similar to the distinction between types and
instances in the type systems of the rtyper: the types describe what sort of
fields the instances have.

The Options are organized in a tree. Every option has a name, as does every
option group. The parts of the full name of the option are separated by dots:
e.g. ``config.translation.thread``.


Description of Options
~~~~~~~~~~~~~~~~~~~~~~

All the constructors take a ``name`` and a ``doc`` argument as first arguments
to give the option or option group a name and to document it. Most constructors
take a ``default`` argument that specifies the default value of the option. If
this argument is not supplied the default value is assumed to be ``None``.
Most constructors
also take a ``cmdline`` argument where you can specify what the command line
option should look like (for example cmdline="-v --version"). If ``cmdline`` is
not specified a default cmdline option is created that uses the name of the
option together with its full path. If ``None`` is passed in as ``cmdline`` then
no command line option is created at all.

Some options types can specify requirements to specify that a particular choice
for one option works only if a certain choice for another option is used. A
requirement is specified using a list of pairs. The first element of the pair
gives the path of the option that is required to be set and the second element
gives the required value.


``OptionDescription``
+++++++++++++++++++++

This class is used to group suboptions.

    ``__init__(self, name, doc, children)``
        ``children`` is a list of option descriptions (including
        ``OptionDescription`` instances for nested namespaces).


``ChoiceOption``
++++++++++++++++

Represents a choice out of several objects. The option can also have the value
``None``.

    ``__init__(self, name, doc, values, default=None, requires=None, cmdline=DEFAULT)``
        ``values`` is a list of values the option can possibly take,
        ``requires`` is a dictionary mapping values to lists of of two-element
        tuples.


``BoolOption``
++++++++++++++

Represents a choice between ``True`` and ``False``.

    ``__init__(self, name, doc, default=None, requires=None, suggests=None, cmdline=DEFAULT, negation=True)``
        ``default`` specifies the default value of the option. ``requires`` is
        a list of two-element tuples describing the requirements when the
        option is set to true, ``suggests`` is a list of the same structure but
        the options in there are only suggested, not absolutely necessary. The
        difference is small: if the current option is set to True, both the
        required and the suggested options are set. The required options cannot
        be changed later, though. ``negation`` specifies whether the negative
        commandline option should be generated.


``IntOption``
+++++++++++++

Represents a choice of an integer.

    ``__init__(self, name, doc, default=None, cmdline=DEFAULT)``


``FloatOption``
+++++++++++++++

Represents a choice of a floating point number.

    ``__init__(self, name, doc, default=None, cmdline=DEFAULT)``


``StrOption``
+++++++++++++

Represents the choice of a string.

    ``__init__(self, name, doc, default=None, cmdline=DEFAULT)``


Configuration Objects
~~~~~~~~~~~~~~~~~~~~~

``Config`` objects hold the chosen values for the options (of the default,
if no choice was made). A ``Config`` object is described by an
``OptionDescription`` instance. The attributes of the ``Config`` objects are the
names of the children of the ``OptionDescription``. Example::

    >>> from rpython.config.config import OptionDescription, Config, BoolOption
    >>> descr = OptionDescription("options", "", [
    ...     BoolOption("bool", "", default=False)])
    >>>
    >>> config = Config(descr)
    >>> config.bool
    False
    >>> config.bool = True
    >>> config.bool
    True


Description of the (useful) methods on ``Config``:

    ``__init__(self, descr, **overrides)``:
        ``descr`` is an instance of ``OptionDescription`` that describes the
        configuration object. ``overrides`` can be used to set different default
        values (see method ``override``).

    ``override(self, overrides)``:
        override default values. This marks the overridden values as defaults,
        which makes it possible to change them (you can usually change values
        only once). ``overrides`` is a dictionary of path strings to values.

    ``set(self, **kwargs)``:
        "do what I mean"-interface to option setting. Searches all paths
        starting from that config for matches of the optional arguments and sets
        the found option if the match is not ambiguous.


Production of optparse Parsers
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To produce an optparse parser use the function ``to_optparse``. It will create
an option parser using callbacks in such a way that the config object used for
creating the parser is updated automatically.

    ``to_optparse(config, useoptions=None, parser=None)``:
        Returns an optparse parser.  ``config`` is the configuration object for
        which to create the parser.  ``useoptions`` is a list of options for
        which to create command line options. It can contain full paths to
        options or also paths to an option description plus an additional ".*"
        to produce command line options for all sub-options of that description.
        If ``useoptions`` is ``None``, then all sub-options are turned into
        cmdline options. ``parser`` can be an existing parser object, if
        ``None`` is passed in, then a new one is created.


The usage of config objects in PyPy
-----------------------------------

The two large parts of PyPy, the Python interpreter and the RPython
toolchain, have two separate sets of options. The translation toolchain options
can be found on the ``config`` attribute of all ``TranslationContext``
instances and are described in :source:`rpython/config/translationoption.py`. The interpreter options
are attached to the object space, also under the name ``config`` and are
described in :source:`pypy/config/pypyoption.py`. Both set of options are
documented in the :doc:`config/index` section.

