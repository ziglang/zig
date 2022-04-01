""" log machine-parseable test session result information in a plain
text file.
"""

import py
import os

def pytest_addoption(parser):
    group = parser.getgroup("terminal reporting", "resultlog plugin options")
    group.addoption('--resultlog', '--result-log', action="store",
        metavar="path", default=None,
        help="path for machine-readable result log.")

def pytest_configure(config):
    resultlog = config.option.resultlog
    # prevent opening resultlog on slave nodes (xdist)
    if resultlog and not hasattr(config, 'slaveinput'):
        dirname = os.path.dirname(os.path.abspath(resultlog))
        if not os.path.isdir(dirname):
            os.makedirs(dirname)
        logfile = open(resultlog, 'w', 1) # line buffered
        config._resultlog = ResultLog(config, logfile)
        config.pluginmanager.register(config._resultlog)

def pytest_unconfigure(config):
    resultlog = getattr(config, '_resultlog', None)
    if resultlog:
        resultlog.logfile.close()
        del config._resultlog
        config.pluginmanager.unregister(resultlog)

def generic_path(item):
    chain = item.listchain()
    gpath = [chain[0].name]
    fspath = chain[0].fspath
    fspart = False
    for node in chain[1:]:
        newfspath = node.fspath
        if newfspath == fspath:
            if fspart:
                gpath.append(':')
                fspart = False
            else:
                gpath.append('.')
        else:
            gpath.append('/')
            fspart = True
        name = node.name
        if name[0] in '([':
            gpath.pop()
        gpath.append(name)
        fspath = newfspath
    return ''.join(gpath)

class ResultLog(object):
    def __init__(self, config, logfile):
        self.config = config
        self.logfile = logfile # preferably line buffered

    def write_log_entry(self, testpath, lettercode, longrepr, sections=None):
        _safeprint("%s %s" % (lettercode, testpath), file=self.logfile)
        for line in longrepr.splitlines():
            _safeprint(" %s" % line, file=self.logfile)
        if sections is not None and (
                lettercode in ('E', 'F')):    # to limit the size of logs
            for title, content in sections:
                _safeprint(" ---------- %s ----------" % (title,),
                           file=self.logfile)
                for line in content.splitlines():
                    _safeprint(" %s" % line, file=self.logfile)

    def log_outcome(self, report, lettercode, longrepr):
        testpath = getattr(report, 'nodeid', None)
        if testpath is None:
            testpath = report.fspath
        self.write_log_entry(testpath, lettercode, longrepr,
                             getattr(report, 'sections', None))

    def pytest_runtest_logreport(self, report):
        if report.when != "call" and report.passed:
            return
        res = self.config.hook.pytest_report_teststatus(report=report)
        code = res[1]
        if code == 'x':
            longrepr = str(report.longrepr)
        elif code == 'X':
            longrepr = ''
        elif report.passed:
            longrepr = ""
        elif report.failed:
            longrepr = str(report.longrepr)
        elif report.skipped:
            longrepr = str(report.longrepr[2])
        self.log_outcome(report, code, longrepr)

    def pytest_collectreport(self, report):
        if not report.passed:
            if report.failed:
                code = "F"
                longrepr = str(report.longrepr)
            else:
                assert report.skipped
                code = "S"
                longrepr = "%s:%d: %s" % report.longrepr
            self.log_outcome(report, code, longrepr)

    def pytest_internalerror(self, excrepr):
        reprcrash = getattr(excrepr, 'reprcrash', None)
        path = getattr(reprcrash, "path", None)
        if path is None:
            path = "cwd:%s" % py.path.local()
        self.write_log_entry(path, '!', str(excrepr))

def _safeprint(s, file):
    if isinstance(s, unicode):
        s = s.encode('utf-8')
    py.builtin.print_(s, file=file)
