""" interactive debugging with PDB, the Python Debugger. """
from __future__ import absolute_import
import pdb
import sys

import pytest


def pytest_addoption(parser):
    group = parser.getgroup("general")
    group._addoption('--pdb',
               action="store_true", dest="usepdb", default=False,
               help="start the interactive Python debugger on errors.")

def pytest_namespace():
    return {'set_trace': pytestPDB().set_trace}

def pytest_configure(config):
    if config.getvalue("usepdb"):
        config.pluginmanager.register(PdbInvoke(), 'pdbinvoke')

    old = (pdb.set_trace, pytestPDB._pluginmanager)
    def fin():
        pdb.set_trace, pytestPDB._pluginmanager = old
        pytestPDB._config = None
    pdb.set_trace = pytest.set_trace
    pytestPDB._pluginmanager = config.pluginmanager
    pytestPDB._config = config
    config._cleanup.append(fin)

class pytestPDB:
    """ Pseudo PDB that defers to the real pdb. """
    _pluginmanager = None
    _config = None

    def set_trace(self):
        """ invoke PDB set_trace debugging, dropping any IO capturing. """
        import _pytest.config
        frame = sys._getframe().f_back
        if self._pluginmanager is not None:
            capman = self._pluginmanager.getplugin("capturemanager")
            if capman:
                capman.suspendcapture(in_=True)
            tw = _pytest.config.create_terminal_writer(self._config)
            tw.line()
            tw.sep(">", "PDB set_trace (IO-capturing turned off)")
            self._pluginmanager.hook.pytest_enter_pdb(config=self._config)
        pdb.Pdb().set_trace(frame)


class PdbInvoke:
    def pytest_exception_interact(self, node, call, report):
        capman = node.config.pluginmanager.getplugin("capturemanager")
        if capman:
            out, err = capman.suspendcapture(in_=True)
            sys.stdout.write(out)
            sys.stdout.write(err)
        _enter_pdb(node, call.excinfo, report)

    def pytest_internalerror(self, excrepr, excinfo):
        for line in str(excrepr).split("\n"):
            sys.stderr.write("INTERNALERROR> %s\n" %line)
            sys.stderr.flush()
        tb = _postmortem_traceback(excinfo)
        post_mortem(tb)


def _enter_pdb(node, excinfo, rep):
    # XXX we re-use the TerminalReporter's terminalwriter
    # because this seems to avoid some encoding related troubles
    # for not completely clear reasons.
    tw = node.config.pluginmanager.getplugin("terminalreporter")._tw
    tw.line()
    tw.sep(">", "traceback")
    rep.toterminal(tw)
    tw.sep(">", "entering PDB")
    tb = _postmortem_traceback(excinfo)
    post_mortem(tb)
    rep._pdbshown = True
    return rep


def _postmortem_traceback(excinfo):
    # A doctest.UnexpectedException is not useful for post_mortem.
    # Use the underlying exception instead:
    from doctest import UnexpectedException
    if isinstance(excinfo.value, UnexpectedException):
        return excinfo.value.exc_info[2]
    else:
        return excinfo._excinfo[2]


def _find_last_non_hidden_frame(stack):
    i = max(0, len(stack) - 1)
    while i and stack[i][0].f_locals.get("__tracebackhide__", False):
        i -= 1
    return i


def post_mortem(t):
    class Pdb(pdb.Pdb):
        def get_stack(self, f, t):
            stack, i = pdb.Pdb.get_stack(self, f, t)
            if f is None:
                i = _find_last_non_hidden_frame(stack)
            return stack, i
    p = Pdb()
    p.reset()
    p.interaction(None, t)
