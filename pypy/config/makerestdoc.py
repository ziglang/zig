import py
from pypy.tool.rest.rst import Rest, Paragraph, Strong, ListItem, Title, Link
from pypy.tool.rest.rst import Directive, Text

from rpython.config.config import ChoiceOption, BoolOption, StrOption, IntOption
from rpython.config.config import FloatOption, OptionDescription, Option, Config
from rpython.config.config import ArbitraryOption, DEFAULT_OPTION_NAME
from rpython.config.config import _getnegation

configdocdir = py.path.local(__file__).dirpath().dirpath().join("doc", "config")

def get_fullpath(opt, path):
    if path:
        return "%s.%s" % (path, opt._name)
    else:
        return opt._name


def get_cmdline(cmdline, fullpath):
    if cmdline is DEFAULT_OPTION_NAME:
        return '--%s' % (fullpath.replace('.', '-'),)
    else:
        return cmdline


class __extend__(Option):
    def make_rest_doc(self, path=""):
        fullpath = get_fullpath(self, path)
        result = Rest(
            Title(fullpath, abovechar="=", belowchar="="),
            ListItem(Strong("name:"), self._name),
            ListItem(Strong("description:"), self.doc))
        if self.cmdline is not None:
            cmdline = get_cmdline(self.cmdline, fullpath)
            result.add(ListItem(Strong("command-line:"), cmdline))
        return result

class __extend__(ChoiceOption):
    def make_rest_doc(self, path=""):
        content = super(ChoiceOption, self).make_rest_doc(path)
        content.add(ListItem(Strong("option type:"), "choice option"))
        content.add(ListItem(Strong("possible values:"),
                             *[ListItem(str(val)) for val in self.values]))
        if self.default is not None:
            content.add(ListItem(Strong("default:"), str(self.default)))

        requirements = []

        for val in self.values:
            if val not in self._requires:
                continue
            req = self._requires[val]
            requirements.append(ListItem("value '%s' requires:" % (val, ),
                *[ListItem(Link(opt, opt + ".html"),
                           "to be set to '%s'" % (rval, ))
                      for (opt, rval) in req]))
        if requirements:
            content.add(ListItem(Strong("requirements:"), *requirements))
        return content

class __extend__(BoolOption):
    def make_rest_doc(self, path=""):
        content = super(BoolOption, self).make_rest_doc(path)
        fullpath = get_fullpath(self, path)
        if self.negation and self.cmdline is not None:
            if self.cmdline is DEFAULT_OPTION_NAME:
                cmdline = '--%s' % (fullpath.replace('.', '-'),)
            else:
                cmdline = self.cmdline
            neg_cmdline = ["--" + _getnegation(argname.lstrip("-"))
                               for argname in cmdline.split()
                                   if argname.startswith("--")][0]
            content.add(ListItem(Strong("command-line for negation:"),
                                 neg_cmdline))
        content.add(ListItem(Strong("option type:"), "boolean option"))
        if self.default is not None:
            content.add(ListItem(Strong("default:"), str(self.default)))
        if self._requires is not None:
            requirements = [ListItem(Link(opt, opt + ".html"),
                               "must be set to '%s'" % (rval, ))
                                for (opt, rval) in self._requires]
            if requirements:
                content.add(ListItem(Strong("requirements:"), *requirements))
        if self._suggests is not None:
            suggestions = [ListItem(Link(opt, opt + ".html"),
                              "should be set to '%s'" % (rval, ))
                               for (opt, rval) in self._suggests]
            if suggestions:
                content.add(ListItem(Strong("suggestions:"), *suggestions))
        return content

class __extend__(IntOption):
    def make_rest_doc(self, path=""):
        content = super(IntOption, self).make_rest_doc(path)
        content.add(ListItem(Strong("option type:"), "integer option"))
        if self.default is not None:
            content.add(ListItem(Strong("default:"), str(self.default)))
        return content

class __extend__(FloatOption):
    def make_rest_doc(self, path=""):
        content = super(FloatOption, self).make_rest_doc(path)
        content.add(ListItem(Strong("option type:"), "float option"))
        if self.default is not None:
            content.add(ListItem(Strong("default:"), str(self.default)))
        return content

class __extend__(StrOption):
    def make_rest_doc(self, path=""):
        content = super(StrOption, self).make_rest_doc(path)
        content.add(ListItem(Strong("option type:"), "string option"))
        if self.default is not None:
            content.add(ListItem(Strong("default:"), str(self.default)))
        return content

class __extend__(ArbitraryOption):
    def make_rest_doc(self, path=""):
        content = super(ArbitraryOption, self).make_rest_doc(path)
        content.add(ListItem(Strong("option type:"),
                             "arbitrary option (mostly internal)"))
        if self.default is not None:
            content.add(ListItem(Strong("default:"), str(self.default)))
        elif self.defaultfactory is not None:
            content.add(ListItem(Strong("factory for the default value:"),
                                 str(self.defaultfactory)))
        return content

class __extend__(OptionDescription):
    def make_rest_doc(self, path=""):
        fullpath = get_fullpath(self, path)
        content = Rest(
            Title(fullpath, abovechar="=", belowchar="="))
        toctree = []
        for child in self._children:
            subpath = fullpath + "." + child._name
            toctree.append(subpath)
        content.add(Directive("toctree", *toctree, **{'maxdepth': 4}))
        content.join(
            ListItem(Strong("name:"), self._name),
            ListItem(Strong("description:"), self.doc))
        return content


def _get_section_header(cmdline, fullpath, subdescr):
    # XXX:  pypy specific hack
    txtfile = configdocdir.join(fullpath + ".txt")
    if not txtfile.check():
        print txtfile, "not found"
        return ""
    content = txtfile.read()
    if ".. internal" in content:
        return "Internal Options"
    return ""

def make_cmdline_overview(descr, title=True):
    content = Rest()
    if title:
        content.add(
            Title("Overview of Command Line Options for '%s'" % (descr._name, ),
                  abovechar="=", belowchar="="))
    cmdlines = []
    config = Config(descr)
    for path in config.getpaths(include_groups=False):
        subconf, step = config._cfgimpl_get_home_by_path(path)
        fullpath = (descr._name + "." + path)
        subdescr = getattr(subconf._cfgimpl_descr, step)
        cmdline = get_cmdline(subdescr.cmdline, fullpath)
        if cmdline is not None:
            header = _get_section_header(cmdline, fullpath, subdescr)
            cmdlines.append((header, cmdline, fullpath, subdescr))
    cmdlines.sort(key=lambda x: (x[0], x[1].strip("-")))
    currheader = ""
    curr = content
    for header, cmdline, fullpath, subdescr in cmdlines:
        if header != currheader:
            content.add(Title(header, abovechar="", belowchar="="))
            curr = content.add(Paragraph())
            currheader = header
        curr.add(ListItem(Link(cmdline + ":", fullpath + ".html"),
                          Text(subdescr.doc)))
    return content


def register_config_role(docdir):
    """ register a :config: ReST link role for use in documentation. """
    try:
        from docutils.parsers.rst import directives, states, roles
        from pypy.tool.rest.directive import register_linkrole
    except ImportError:
        return
    # enable :config: link role
    def config_role(name, rawtext, text, lineno, inliner, options={},
                    content=[]):
        from docutils import nodes
        from pypy.config.pypyoption import get_pypy_config
        from pypy.config.makerestdoc import get_cmdline
        txt = docdir.join("config", text + ".rst")
        html = docdir.join("config", text + ".html")
        assert txt.check()
        assert name == "config"
        sourcedir = py.path.local(inliner.document.settings._source).dirpath()
        curr = sourcedir
        prefix = ""
        while 1:
            relative = str(html.relto(curr))
            if relative:
                break
            curr = curr.dirpath()
            prefix += "../"
        config = get_pypy_config()
        # begin horror
        h, n = config._cfgimpl_get_home_by_path(text)
        opt = getattr(h._cfgimpl_descr, n)
        # end horror
        cmdline = get_cmdline(opt.cmdline, text)
        if cmdline is not None:
            shortest_long_option = 'X'*1000
            for cmd in cmdline.split():
                if cmd.startswith('--') and len(cmd) < len(shortest_long_option):
                    shortest_long_option = cmd
            text = shortest_long_option
        target = prefix + relative
        reference_node = nodes.reference(rawtext, text, name=text, refuri=target)
        return [reference_node], []
    config_role.content = True
    config_role.options = {}
    return config_role
