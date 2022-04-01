"""
    report test results in JUnit-XML format,
    for use with Jenkins and build integration servers.


Based on initial code from Ross Lawley.
"""
# Output conforms to https://github.com/jenkinsci/xunit-plugin/blob/master/
# src/main/resources/org/jenkinsci/plugins/xunit/types/model/xsd/junit-10.xsd

import py
import os
import re
import sys
import time
import pytest

# Python 2.X and 3.X compatibility
if sys.version_info[0] < 3:
    from codecs import open
else:
    unichr = chr
    unicode = str
    long = int


class Junit(py.xml.Namespace):
    pass

# We need to get the subset of the invalid unicode ranges according to
# XML 1.0 which are valid in this python build.  Hence we calculate
# this dynamically instead of hardcoding it.  The spec range of valid
# chars is: Char ::= #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD]
#                    | [#x10000-#x10FFFF]
_legal_chars = (0x09, 0x0A, 0x0d)
_legal_ranges = (
    (0x20, 0x7E), (0x80, 0xD7FF), (0xE000, 0xFFFD), (0x10000, 0x10FFFF),
)
_legal_xml_re = [
    unicode("%s-%s") % (unichr(low), unichr(high))
    for (low, high) in _legal_ranges if low < sys.maxunicode
]
_legal_xml_re = [unichr(x) for x in _legal_chars] + _legal_xml_re
illegal_xml_re = re.compile(unicode('[^%s]') % unicode('').join(_legal_xml_re))
del _legal_chars
del _legal_ranges
del _legal_xml_re

_py_ext_re = re.compile(r"\.py$")


def bin_xml_escape(arg):
    def repl(matchobj):
        i = ord(matchobj.group())
        if i <= 0xFF:
            return unicode('#x%02X') % i
        else:
            return unicode('#x%04X') % i

    return py.xml.raw(illegal_xml_re.sub(repl, py.xml.escape(arg)))


class _NodeReporter(object):
    def __init__(self, nodeid, xml):

        self.id = nodeid
        self.xml = xml
        self.add_stats = self.xml.add_stats
        self.duration = 0
        self.properties = []
        self.nodes = []
        self.testcase = None
        self.attrs = {}

    def append(self, node):
        self.xml.add_stats(type(node).__name__)
        self.nodes.append(node)

    def add_property(self, name, value):
        self.properties.append((str(name), bin_xml_escape(value)))

    def make_properties_node(self):
        """Return a Junit node containing custom properties, if any.
        """
        if self.properties:
            return Junit.properties([
                Junit.property(name=name, value=value)
                for name, value in self.properties
            ])
        return ''

    def record_testreport(self, testreport):
        assert not self.testcase
        names = mangle_test_address(testreport.nodeid)
        classnames = names[:-1]
        if self.xml.prefix:
            classnames.insert(0, self.xml.prefix)
        attrs = {
            "classname": ".".join(classnames),
            "name": bin_xml_escape(names[-1]),
            "file": testreport.location[0],
        }
        if testreport.location[1] is not None:
            attrs["line"] = testreport.location[1]
        self.attrs = attrs

    def to_xml(self):
        testcase = Junit.testcase(time=self.duration, **self.attrs)
        testcase.append(self.make_properties_node())
        for node in self.nodes:
            testcase.append(node)
        return testcase

    def _add_simple(self, kind, message, data=None):
        data = bin_xml_escape(data)
        node = kind(data, message=message)
        self.append(node)

    def _write_captured_output(self, report):
        for capname in ('out', 'err'):
            allcontent = ""
            for name, content in report.get_sections("Captured std%s" %
                                                     capname):
                allcontent += content
            if allcontent:
                tag = getattr(Junit, 'system-' + capname)
                self.append(tag(bin_xml_escape(allcontent)))

    def append_pass(self, report):
        self.add_stats('passed')
        self._write_captured_output(report)

    def append_failure(self, report):
        # msg = str(report.longrepr.reprtraceback.extraline)
        if hasattr(report, "wasxfail"):
            self._add_simple(
                Junit.skipped,
                "xfail-marked test passes unexpectedly")
        else:
            if hasattr(report.longrepr, "reprcrash"):
                message = report.longrepr.reprcrash.message
            elif isinstance(report.longrepr, (unicode, str)):
                message = report.longrepr
            else:
                message = str(report.longrepr)
            message = bin_xml_escape(message)
            fail = Junit.failure(message=message)
            fail.append(bin_xml_escape(report.longrepr))
            self.append(fail)
        self._write_captured_output(report)

    def append_collect_error(self, report):
        # msg = str(report.longrepr.reprtraceback.extraline)
        self.append(Junit.error(bin_xml_escape(report.longrepr),
                                message="collection failure"))

    def append_collect_skipped(self, report):
        self._add_simple(
            Junit.skipped, "collection skipped", report.longrepr)

    def append_error(self, report):
        self._add_simple(
            Junit.error, "test setup failure", report.longrepr)
        self._write_captured_output(report)

    def append_skipped(self, report):
        if hasattr(report, "wasxfail"):
            self._add_simple(
                Junit.skipped, "expected test failure", report.wasxfail
            )
        else:
            filename, lineno, skipreason = report.longrepr
            if skipreason.startswith("Skipped: "):
                skipreason = bin_xml_escape(skipreason[9:])
            self.append(
                Junit.skipped("%s:%s: %s" % (filename, lineno, skipreason),
                              type="pytest.skip",
                              message=skipreason))
        self._write_captured_output(report)

    def finalize(self):
        data = self.to_xml().unicode(indent=0)
        self.__dict__.clear()
        self.to_xml = lambda: py.xml.raw(data)


@pytest.fixture
def record_xml_property(request):
    """Fixture that adds extra xml properties to the tag for the calling test.
    The fixture is callable with (name, value), with value being automatically
    xml-encoded.
    """
    request.node.warn(
        code='C3',
        message='record_xml_property is an experimental feature',
    )
    xml = getattr(request.config, "_xml", None)
    if xml is not None:
        node_reporter = xml.node_reporter(request.node.nodeid)
        return node_reporter.add_property
    else:
        def add_property_noop(name, value):
            pass

        return add_property_noop


def pytest_addoption(parser):
    group = parser.getgroup("terminal reporting")
    group.addoption(
        '--junitxml', '--junit-xml',
        action="store",
        dest="xmlpath",
        metavar="path",
        default=None,
        help="create junit-xml style report file at given path.")
    group.addoption(
        '--junitprefix', '--junit-prefix',
        action="store",
        metavar="str",
        default=None,
        help="prepend prefix to classnames in junit-xml output")


def pytest_configure(config):
    xmlpath = config.option.xmlpath
    # prevent opening xmllog on slave nodes (xdist)
    if xmlpath and not hasattr(config, 'slaveinput'):
        config._xml = LogXML(xmlpath, config.option.junitprefix)
        config.pluginmanager.register(config._xml)


def pytest_unconfigure(config):
    xml = getattr(config, '_xml', None)
    if xml:
        del config._xml
        config.pluginmanager.unregister(xml)


def mangle_test_address(address):
    path, possible_open_bracket, params = address.partition('[')
    names = path.split("::")
    try:
        names.remove('()')
    except ValueError:
        pass
    # convert file path to dotted path
    names[0] = names[0].replace("/", '.')
    names[0] = _py_ext_re.sub("", names[0])
    # put any params back
    names[-1] += possible_open_bracket + params
    return names


class LogXML(object):
    def __init__(self, logfile, prefix):
        logfile = os.path.expanduser(os.path.expandvars(logfile))
        self.logfile = os.path.normpath(os.path.abspath(logfile))
        self.prefix = prefix
        self.stats = dict.fromkeys([
            'error',
            'passed',
            'failure',
            'skipped',
        ], 0)
        self.node_reporters = {}  # nodeid -> _NodeReporter
        self.node_reporters_ordered = []

    def finalize(self, report):
        nodeid = getattr(report, 'nodeid', report)
        # local hack to handle xdist report order
        slavenode = getattr(report, 'node', None)
        reporter = self.node_reporters.pop((nodeid, slavenode))
        if reporter is not None:
            reporter.finalize()

    def node_reporter(self, report):
        nodeid = getattr(report, 'nodeid', report)
        # local hack to handle xdist report order
        slavenode = getattr(report, 'node', None)

        key = nodeid, slavenode

        if key in self.node_reporters:
            # TODO: breasks for --dist=each
            return self.node_reporters[key]
        reporter = _NodeReporter(nodeid, self)
        self.node_reporters[key] = reporter
        self.node_reporters_ordered.append(reporter)
        return reporter

    def add_stats(self, key):
        if key in self.stats:
            self.stats[key] += 1

    def _opentestcase(self, report):
        reporter = self.node_reporter(report)
        reporter.record_testreport(report)
        return reporter

    def pytest_runtest_logreport(self, report):
        """handle a setup/call/teardown report, generating the appropriate
        xml tags as necessary.

        note: due to plugins like xdist, this hook may be called in interlaced
        order with reports from other nodes. for example:

        usual call order:
            -> setup node1
            -> call node1
            -> teardown node1
            -> setup node2
            -> call node2
            -> teardown node2

        possible call order in xdist:
            -> setup node1
            -> call node1
            -> setup node2
            -> call node2
            -> teardown node2
            -> teardown node1
        """
        if report.passed:
            if report.when == "call":  # ignore setup/teardown
                reporter = self._opentestcase(report)
                reporter.append_pass(report)
        elif report.failed:
            reporter = self._opentestcase(report)
            if report.when == "call":
                reporter.append_failure(report)
            else:
                reporter.append_error(report)
        elif report.skipped:
            reporter = self._opentestcase(report)
            reporter.append_skipped(report)
        self.update_testcase_duration(report)
        if report.when == "teardown":
            self.finalize(report)

    def update_testcase_duration(self, report):
        """accumulates total duration for nodeid from given report and updates
        the Junit.testcase with the new total if already created.
        """
        reporter = self.node_reporter(report)
        reporter.duration += getattr(report, 'duration', 0.0)

    def pytest_collectreport(self, report):
        if not report.passed:
            reporter = self._opentestcase(report)
            if report.failed:
                reporter.append_collect_error(report)
            else:
                reporter.append_collect_skipped(report)

    def pytest_internalerror(self, excrepr):
        reporter = self.node_reporter('internal')
        reporter.attrs.update(classname="pytest", name='internal')
        reporter._add_simple(Junit.error, 'internal error', excrepr)

    def pytest_sessionstart(self):
        self.suite_start_time = time.time()

    def pytest_sessionfinish(self):
        dirname = os.path.dirname(os.path.abspath(self.logfile))
        if not os.path.isdir(dirname):
            os.makedirs(dirname)
        logfile = open(self.logfile, 'w', encoding='utf-8')
        suite_stop_time = time.time()
        suite_time_delta = suite_stop_time - self.suite_start_time

        numtests = self.stats['passed'] + self.stats['failure'] + self.stats['skipped']

        logfile.write('<?xml version="1.0" encoding="utf-8"?>')
        logfile.write(Junit.testsuite(
            [x.to_xml() for x in self.node_reporters_ordered],
            name="pytest",
            errors=self.stats['error'],
            failures=self.stats['failure'],
            skips=self.stats['skipped'],
            tests=numtests,
            time="%.3f" % suite_time_delta, ).unicode(indent=0))
        logfile.close()

    def pytest_terminal_summary(self, terminalreporter):
        terminalreporter.write_sep("-",
                                   "generated xml file: %s" % (self.logfile))
