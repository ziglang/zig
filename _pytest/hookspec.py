""" hook specifications for pytest plugins, invoked from main.py and builtin plugins.  """

from _pytest._pluggy import HookspecMarker

hookspec = HookspecMarker("pytest")

# -------------------------------------------------------------------------
# Initialization hooks called for every plugin
# -------------------------------------------------------------------------

@hookspec(historic=True)
def pytest_addhooks(pluginmanager):
    """called at plugin registration time to allow adding new hooks via a call to
    pluginmanager.add_hookspecs(module_or_class, prefix)."""


@hookspec(historic=True)
def pytest_namespace():
    """return dict of name->object to be made globally available in
    the pytest namespace.  This hook is called at plugin registration
    time.
    """

@hookspec(historic=True)
def pytest_plugin_registered(plugin, manager):
    """ a new pytest plugin got registered. """


@hookspec(historic=True)
def pytest_addoption(parser):
    """register argparse-style options and ini-style config values,
    called once at the beginning of a test run.

    .. note::

        This function should be implemented only in plugins or ``conftest.py``
        files situated at the tests root directory due to how py.test
        :ref:`discovers plugins during startup <pluginorder>`.

    :arg parser: To add command line options, call
        :py:func:`parser.addoption(...) <_pytest.config.Parser.addoption>`.
        To add ini-file values call :py:func:`parser.addini(...)
        <_pytest.config.Parser.addini>`.

    Options can later be accessed through the
    :py:class:`config <_pytest.config.Config>` object, respectively:

    - :py:func:`config.getoption(name) <_pytest.config.Config.getoption>` to
      retrieve the value of a command line option.

    - :py:func:`config.getini(name) <_pytest.config.Config.getini>` to retrieve
      a value read from an ini-style file.

    The config object is passed around on many internal objects via the ``.config``
    attribute or can be retrieved as the ``pytestconfig`` fixture or accessed
    via (deprecated) ``pytest.config``.
    """

@hookspec(historic=True)
def pytest_configure(config):
    """ called after command line options have been parsed
    and all plugins and initial conftest files been loaded.
    This hook is called for every plugin.
    """

# -------------------------------------------------------------------------
# Bootstrapping hooks called for plugins registered early enough:
# internal and 3rd party plugins as well as directly
# discoverable conftest.py local plugins.
# -------------------------------------------------------------------------

@hookspec(firstresult=True)
def pytest_cmdline_parse(pluginmanager, args):
    """return initialized config object, parsing the specified args. """

def pytest_cmdline_preparse(config, args):
    """(deprecated) modify command line arguments before option parsing. """

@hookspec(firstresult=True)
def pytest_cmdline_main(config):
    """ called for performing the main command line action. The default
    implementation will invoke the configure hooks and runtest_mainloop. """

def pytest_load_initial_conftests(early_config, parser, args):
    """ implements the loading of initial conftest files ahead
    of command line option parsing. """


# -------------------------------------------------------------------------
# collection hooks
# -------------------------------------------------------------------------

@hookspec(firstresult=True)
def pytest_collection(session):
    """ perform the collection protocol for the given session. """

def pytest_collection_modifyitems(session, config, items):
    """ called after collection has been performed, may filter or re-order
    the items in-place."""

def pytest_collection_finish(session):
    """ called after collection has been performed and modified. """

@hookspec(firstresult=True)
def pytest_ignore_collect(path, config):
    """ return True to prevent considering this path for collection.
    This hook is consulted for all files and directories prior to calling
    more specific hooks.
    """

@hookspec(firstresult=True)
def pytest_collect_directory(path, parent):
    """ called before traversing a directory for collection files. """

def pytest_collect_file(path, parent):
    """ return collection Node or None for the given path. Any new node
    needs to have the specified ``parent`` as a parent."""

# logging hooks for collection
def pytest_collectstart(collector):
    """ collector starts collecting. """

def pytest_itemcollected(item):
    """ we just collected a test item. """

def pytest_collectreport(report):
    """ collector finished collecting. """

def pytest_deselected(items):
    """ called for test items deselected by keyword. """

@hookspec(firstresult=True)
def pytest_make_collect_report(collector):
    """ perform ``collector.collect()`` and return a CollectReport. """

# -------------------------------------------------------------------------
# Python test function related hooks
# -------------------------------------------------------------------------

@hookspec(firstresult=True)
def pytest_pycollect_makemodule(path, parent):
    """ return a Module collector or None for the given path.
    This hook will be called for each matching test module path.
    The pytest_collect_file hook needs to be used if you want to
    create test modules for files that do not match as a test module.
    """

@hookspec(firstresult=True)
def pytest_pycollect_makeitem(collector, name, obj):
    """ return custom item/collector for a python object in a module, or None.  """

@hookspec(firstresult=True)
def pytest_pyfunc_call(pyfuncitem):
    """ call underlying test function. """

def pytest_generate_tests(metafunc):
    """ generate (multiple) parametrized calls to a test function."""

# -------------------------------------------------------------------------
# generic runtest related hooks
# -------------------------------------------------------------------------

@hookspec(firstresult=True)
def pytest_runtestloop(session):
    """ called for performing the main runtest loop
    (after collection finished). """

def pytest_itemstart(item, node):
    """ (deprecated, use pytest_runtest_logstart). """

@hookspec(firstresult=True)
def pytest_runtest_protocol(item, nextitem):
    """ implements the runtest_setup/call/teardown protocol for
    the given test item, including capturing exceptions and calling
    reporting hooks.

    :arg item: test item for which the runtest protocol is performed.

    :arg nextitem: the scheduled-to-be-next test item (or None if this
                   is the end my friend).  This argument is passed on to
                   :py:func:`pytest_runtest_teardown`.

    :return boolean: True if no further hook implementations should be invoked.
    """

def pytest_runtest_logstart(nodeid, location):
    """ signal the start of running a single test item. """

def pytest_runtest_setup(item):
    """ called before ``pytest_runtest_call(item)``. """

def pytest_runtest_call(item):
    """ called to execute the test ``item``. """

def pytest_runtest_teardown(item, nextitem):
    """ called after ``pytest_runtest_call``.

    :arg nextitem: the scheduled-to-be-next test item (None if no further
                   test item is scheduled).  This argument can be used to
                   perform exact teardowns, i.e. calling just enough finalizers
                   so that nextitem only needs to call setup-functions.
    """

@hookspec(firstresult=True)
def pytest_runtest_makereport(item, call):
    """ return a :py:class:`_pytest.runner.TestReport` object
    for the given :py:class:`pytest.Item` and
    :py:class:`_pytest.runner.CallInfo`.
    """

def pytest_runtest_logreport(report):
    """ process a test setup/call/teardown report relating to
    the respective phase of executing a test. """

# -------------------------------------------------------------------------
# test session related hooks
# -------------------------------------------------------------------------

def pytest_sessionstart(session):
    """ before session.main() is called. """

def pytest_sessionfinish(session, exitstatus):
    """ whole test run finishes. """

def pytest_unconfigure(config):
    """ called before test process is exited.  """


# -------------------------------------------------------------------------
# hooks for customising the assert methods
# -------------------------------------------------------------------------

def pytest_assertrepr_compare(config, op, left, right):
    """return explanation for comparisons in failing assert expressions.

    Return None for no custom explanation, otherwise return a list
    of strings.  The strings will be joined by newlines but any newlines
    *in* a string will be escaped.  Note that all but the first line will
    be indented sligthly, the intention is for the first line to be a summary.
    """

# -------------------------------------------------------------------------
# hooks for influencing reporting (invoked from _pytest_terminal)
# -------------------------------------------------------------------------

def pytest_report_header(config, startdir):
    """ return a string to be displayed as header info for terminal reporting."""

@hookspec(firstresult=True)
def pytest_report_teststatus(report):
    """ return result-category, shortletter and verbose word for reporting."""

def pytest_terminal_summary(terminalreporter):
    """ add additional section in terminal summary reporting.  """


@hookspec(historic=True)
def pytest_logwarning(message, code, nodeid, fslocation):
    """ process a warning specified by a message, a code string,
    a nodeid and fslocation (both of which may be None
    if the warning is not tied to a partilar node/location)."""

# -------------------------------------------------------------------------
# doctest hooks
# -------------------------------------------------------------------------

@hookspec(firstresult=True)
def pytest_doctest_prepare_content(content):
    """ return processed content for a given doctest"""

# -------------------------------------------------------------------------
# error handling and internal debugging hooks
# -------------------------------------------------------------------------

def pytest_internalerror(excrepr, excinfo):
    """ called for internal errors. """

def pytest_keyboard_interrupt(excinfo):
    """ called for keyboard interrupt. """

def pytest_exception_interact(node, call, report):
    """called when an exception was raised which can potentially be
    interactively handled.

    This hook is only called if an exception was raised
    that is not an internal exception like ``skip.Exception``.
    """

def pytest_enter_pdb(config):
    """ called upon pdb.set_trace(), can be used by plugins to take special
    action just before the python debugger enters in interactive mode.

    :arg config: pytest config object
    :type config: _pytest.config.Config
    """
