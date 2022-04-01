import py

from rpython.config.config import *
from pypy.config.makerestdoc import make_cmdline_overview
from pypy.tool.rest.rest import process as restcheck

tempdir = py.test.ensuretemp('config')

try:
    import docutils
except ImportError:
    py.test.skip("don't have docutils")

def checkrest(rest, filename):
    tempfile = tempdir.join(filename)
    tempfile.write(rest)
    restcheck(tempfile)
    return tempfile.new(ext='.html').read()

def generate_html(descr):
    config = Config(descr)
    txt = descr.make_rest_doc().text()

    result = {"": txt}
    for path in config.getpaths(include_groups=True):
        subconf, step = config._cfgimpl_get_home_by_path(path)
        fullpath = (descr._name + "." + path)
        prefix = fullpath.rsplit(".", 1)[0]
        txt = getattr(subconf._cfgimpl_descr, step).make_rest_doc(
                prefix).text()
        result[path] = txt
    return result

def test_simple():
    descr = OptionDescription("foo", "doc", [
            ChoiceOption("bar", "more doc", ["a", "b", "c"]),
            OptionDescription("sub", "nope", [
                ChoiceOption("subbar", "", ["d", "f"]),
                BoolOption("boolean", "this is a boolean", default=False,
                           cmdline="-b --with-b")
                ]),
            StrOption("str", "string option!", default="strange"),
            IntOption("int", "integer option", default=42),
            FloatOption("float", "float option", default=py.std.math.pi),
            ArbitraryOption("surprise", "special", defaultfactory=int),
            ])
    generate_html(descr)

def test_choice_requires():
    descr = OptionDescription("s0", "doc", [
            BoolOption("b1", "", default=False),
            BoolOption("b2", "", default=False),
            BoolOption("b3", "", default=False),
            ChoiceOption("bar", "more doc", ["a", "b", "c"],
                         default="a",
                         requires={"a": [("s0.b1", True),
                                         ("s0.b2", False)],
                                   "b": [("s0.b1", False)]})
            ])
    generate_html(descr)

def test_bool_requires_suggests():
    descr = OptionDescription("a0", "doc", [
            BoolOption("B1", "", default=False),
            BoolOption("B2", "", default=False,
                       suggests=[("a0.B1", True)]),
            BoolOption("B3", "", default=False,
                       requires=[("a0.bar", "c"), ("a0.B2", True)]),
            ChoiceOption("bar", "more doc", ["a", "b", "c"],
                         default="a")])
    result = generate_html(descr)

def test_cmdline_overview():
    descr = OptionDescription("foo", "doc", [
            ChoiceOption("bar", "more doc", ["a", "b", "c"]),
            OptionDescription("sub", "nope", [
                ChoiceOption("subbar", "", ["d", "f"]),
                BoolOption("boolean", "this is a boolean", default=False,
                           cmdline="-b --with-b")
                ]),
            StrOption("str", "string option!", default="strange"),
            IntOption("int", "integer option", default=42),
            FloatOption("float", "float option", default=py.std.math.pi),
            ArbitraryOption("surprise", "special", defaultfactory=int),
            ])
    generate_html(descr)
    c = make_cmdline_overview(descr)
    checkrest(c.text(), "index.txt")
