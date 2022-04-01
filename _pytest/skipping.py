""" support for skip/xfail functions and markers. """
import os
import sys
import traceback

import py
import pytest
from _pytest.mark import MarkInfo, MarkDecorator


def pytest_addoption(parser):
    group = parser.getgroup("general")
    group.addoption('--runxfail',
           action="store_true", dest="runxfail", default=False,
           help="run tests even if they are marked xfail")

    parser.addini("xfail_strict", "default for the strict parameter of xfail "
                                  "markers when not given explicitly (default: "
                                  "False)",
                                  default=False,
                                  type="bool")


def pytest_configure(config):
    if config.option.runxfail:
        old = pytest.xfail
        config._cleanup.append(lambda: setattr(pytest, "xfail", old))
        def nop(*args, **kwargs):
            pass
        nop.Exception = XFailed
        setattr(pytest, "xfail", nop)

    config.addinivalue_line("markers",
        "skip(reason=None): skip the given test function with an optional reason. "
        "Example: skip(reason=\"no way of currently testing this\") skips the "
        "test."
    )
    config.addinivalue_line("markers",
        "skipif(condition): skip the given test function if eval(condition) "
        "results in a True value.  Evaluation happens within the "
        "module global context. Example: skipif('sys.platform == \"win32\"') "
        "skips the test if we are on the win32 platform. see "
        "http://pytest.org/latest/skipping.html"
    )
    config.addinivalue_line("markers",
        "xfail(condition, reason=None, run=True, raises=None, strict=False): "
        "mark the the test function as an expected failure if eval(condition) "
        "has a True value. Optionally specify a reason for better reporting "
        "and run=False if you don't even want to execute the test function. "
        "If only specific exception(s) are expected, you can list them in "
        "raises, and if the test fails in other ways, it will be reported as "
        "a true failure. See http://pytest.org/latest/skipping.html"
    )


def pytest_namespace():
    return dict(xfail=xfail)


class XFailed(pytest.fail.Exception):
    """ raised from an explicit call to pytest.xfail() """


def xfail(reason=""):
    """ xfail an executing test or setup functions with the given reason."""
    __tracebackhide__ = True
    raise XFailed(reason)
xfail.Exception = XFailed


class MarkEvaluator:
    def __init__(self, item, name):
        self.item = item
        self.name = name

    @property
    def holder(self):
        return self.item.keywords.get(self.name)

    def __bool__(self):
        return bool(self.holder)
    __nonzero__ = __bool__

    def wasvalid(self):
        return not hasattr(self, 'exc')

    def invalidraise(self, exc):
        raises = self.get('raises')
        if not raises:
            return
        return not isinstance(exc, raises)

    def istrue(self):
        try:
            return self._istrue()
        except Exception:
            self.exc = sys.exc_info()
            if isinstance(self.exc[1], SyntaxError):
                msg = [" " * (self.exc[1].offset + 4) + "^",]
                msg.append("SyntaxError: invalid syntax")
            else:
                msg = traceback.format_exception_only(*self.exc[:2])
            pytest.fail("Error evaluating %r expression\n"
                        "    %s\n"
                        "%s"
                        %(self.name, self.expr, "\n".join(msg)),
                        pytrace=False)

    def _getglobals(self):
        d = {'os': os, 'sys': sys, 'config': self.item.config}
        func = self.item.obj
        try:
            d.update(func.__globals__)
        except AttributeError:
            d.update(func.func_globals)
        return d

    def _istrue(self):
        if hasattr(self, 'result'):
            return self.result
        if self.holder:
            d = self._getglobals()
            if self.holder.args or 'condition' in self.holder.kwargs:
                self.result = False
                # "holder" might be a MarkInfo or a MarkDecorator; only
                # MarkInfo keeps track of all parameters it received in an
                # _arglist attribute
                if hasattr(self.holder, '_arglist'):
                    arglist = self.holder._arglist
                else:
                    arglist = [(self.holder.args, self.holder.kwargs)]
                for args, kwargs in arglist:
                    if 'condition' in kwargs:
                        args = (kwargs['condition'],)
                    for expr in args:
                        self.expr = expr
                        if isinstance(expr, py.builtin._basestring):
                            result = cached_eval(self.item.config, expr, d)
                        else:
                            if "reason" not in kwargs:
                                # XXX better be checked at collection time
                                msg = "you need to specify reason=STRING " \
                                      "when using booleans as conditions."
                                pytest.fail(msg)
                            result = bool(expr)
                        if result:
                            self.result = True
                            self.reason = kwargs.get('reason', None)
                            self.expr = expr
                            return self.result
            else:
                self.result = True
        return getattr(self, 'result', False)

    def get(self, attr, default=None):
        return self.holder.kwargs.get(attr, default)

    def getexplanation(self):
        expl = getattr(self, 'reason', None) or self.get('reason', None)
        if not expl:
            if not hasattr(self, 'expr'):
                return ""
            else:
                return "condition: " + str(self.expr)
        return expl


@pytest.hookimpl(tryfirst=True)
def pytest_runtest_setup(item):
    # Check if skip or skipif are specified as pytest marks

    skipif_info = item.keywords.get('skipif')
    if isinstance(skipif_info, (MarkInfo, MarkDecorator)):
        eval_skipif = MarkEvaluator(item, 'skipif')
        if eval_skipif.istrue():
            item._evalskip = eval_skipif
            pytest.skip(eval_skipif.getexplanation())

    skip_info = item.keywords.get('skip')
    if isinstance(skip_info, (MarkInfo, MarkDecorator)):
        item._evalskip = True
        if 'reason' in skip_info.kwargs:
            pytest.skip(skip_info.kwargs['reason'])
        elif skip_info.args:
            pytest.skip(skip_info.args[0])
        else:
            pytest.skip("unconditional skip")

    item._evalxfail = MarkEvaluator(item, 'xfail')
    check_xfail_no_run(item)


@pytest.mark.hookwrapper
def pytest_pyfunc_call(pyfuncitem):
    check_xfail_no_run(pyfuncitem)
    outcome = yield
    passed = outcome.excinfo is None
    if passed:
        check_strict_xfail(pyfuncitem)


def check_xfail_no_run(item):
    """check xfail(run=False)"""
    if not item.config.option.runxfail:
        evalxfail = item._evalxfail
        if evalxfail.istrue():
            if not evalxfail.get('run', True):
                pytest.xfail("[NOTRUN] " + evalxfail.getexplanation())


def check_strict_xfail(pyfuncitem):
    """check xfail(strict=True) for the given PASSING test"""
    evalxfail = pyfuncitem._evalxfail
    if evalxfail.istrue():
        strict_default = pyfuncitem.config.getini('xfail_strict')
        is_strict_xfail = evalxfail.get('strict', strict_default)
        if is_strict_xfail:
            del pyfuncitem._evalxfail
            explanation = evalxfail.getexplanation()
            pytest.fail('[XPASS(strict)] ' + explanation, pytrace=False)


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    rep = outcome.get_result()
    evalxfail = getattr(item, '_evalxfail', None)
    evalskip = getattr(item, '_evalskip', None)
    # unitttest special case, see setting of _unexpectedsuccess
    if hasattr(item, '_unexpectedsuccess') and rep.when == "call":
        # we need to translate into how pytest encodes xpass
        rep.wasxfail = "reason: " + repr(item._unexpectedsuccess)
        rep.outcome = "failed"
    elif item.config.option.runxfail:
        pass   # don't interefere
    elif call.excinfo and call.excinfo.errisinstance(pytest.xfail.Exception):
        rep.wasxfail = "reason: " + call.excinfo.value.msg
        rep.outcome = "skipped"
    elif evalxfail and not rep.skipped and evalxfail.wasvalid() and \
        evalxfail.istrue():
        if call.excinfo:
            if evalxfail.invalidraise(call.excinfo.value):
                rep.outcome = "failed"
            else:
                rep.outcome = "skipped"
                rep.wasxfail = evalxfail.getexplanation()
        elif call.when == "call":
            rep.outcome = "failed"  # xpass outcome
            rep.wasxfail = evalxfail.getexplanation()
    elif evalskip is not None and rep.skipped and type(rep.longrepr) is tuple:
        # skipped by mark.skipif; change the location of the failure
        # to point to the item definition, otherwise it will display
        # the location of where the skip exception was raised within pytest
        filename, line, reason = rep.longrepr
        filename, line = item.location[:2]
        rep.longrepr = filename, line, reason

# called by terminalreporter progress reporting
def pytest_report_teststatus(report):
    if hasattr(report, "wasxfail"):
        if report.skipped:
            return "xfailed", "x", "xfail"
        elif report.failed:
            return "xpassed", "X", ("XPASS", {'yellow': True})

# called by the terminalreporter instance/plugin
def pytest_terminal_summary(terminalreporter):
    tr = terminalreporter
    if not tr.reportchars:
        #for name in "xfailed skipped failed xpassed":
        #    if not tr.stats.get(name, 0):
        #        tr.write_line("HINT: use '-r' option to see extra "
        #              "summary info about tests")
        #        break
        return

    lines = []
    for char in tr.reportchars:
        if char == "x":
            show_xfailed(terminalreporter, lines)
        elif char == "X":
            show_xpassed(terminalreporter, lines)
        elif char in "fF":
            show_simple(terminalreporter, lines, 'failed', "FAIL %s")
        elif char in "sS":
            show_skipped(terminalreporter, lines)
        elif char == "E":
            show_simple(terminalreporter, lines, 'error', "ERROR %s")
        elif char == 'p':
            show_simple(terminalreporter, lines, 'passed', "PASSED %s")

    if lines:
        tr._tw.sep("=", "short test summary info")
        for line in lines:
            tr._tw.line(line)

def show_simple(terminalreporter, lines, stat, format):
    failed = terminalreporter.stats.get(stat)
    if failed:
        for rep in failed:
            pos = terminalreporter.config.cwd_relative_nodeid(rep.nodeid)
            lines.append(format %(pos,))

def show_xfailed(terminalreporter, lines):
    xfailed = terminalreporter.stats.get("xfailed")
    if xfailed:
        for rep in xfailed:
            pos = terminalreporter.config.cwd_relative_nodeid(rep.nodeid)
            reason = rep.wasxfail
            lines.append("XFAIL %s" % (pos,))
            if reason:
                lines.append("  " + str(reason))

def show_xpassed(terminalreporter, lines):
    xpassed = terminalreporter.stats.get("xpassed")
    if xpassed:
        for rep in xpassed:
            pos = terminalreporter.config.cwd_relative_nodeid(rep.nodeid)
            reason = rep.wasxfail
            lines.append("XPASS %s %s" %(pos, reason))

def cached_eval(config, expr, d):
    if not hasattr(config, '_evalcache'):
        config._evalcache = {}
    try:
        return config._evalcache[expr]
    except KeyError:
        import _pytest._code
        exprcode = _pytest._code.compile(expr, mode="eval")
        config._evalcache[expr] = x = eval(exprcode, d)
        return x


def folded_skips(skipped):
    d = {}
    for event in skipped:
        key = event.longrepr
        assert len(key) == 3, (event, key)
        d.setdefault(key, []).append(event)
    l = []
    for key, events in d.items():
        l.append((len(events),) + key)
    return l

def show_skipped(terminalreporter, lines):
    tr = terminalreporter
    skipped = tr.stats.get('skipped', [])
    if skipped:
        #if not tr.hasopt('skipped'):
        #    tr.write_line(
        #        "%d skipped tests, specify -rs for more info" %
        #        len(skipped))
        #    return
        fskips = folded_skips(skipped)
        if fskips:
            #tr.write_sep("_", "skipped test summary")
            for num, fspath, lineno, reason in fskips:
                if reason.startswith("Skipped: "):
                    reason = reason[9:]
                lines.append("SKIP [%d] %s:%d: %s" %
                    (num, fspath, lineno, reason))
