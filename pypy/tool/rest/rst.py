
""" reStructuredText generation tools

    provides an api to build a tree from nodes, which can be converted to
    ReStructuredText on demand

    note that not all of ReST is supported, a usable subset is offered, but
    certain features aren't supported, and also certain details (like how links
    are generated, or how escaping is done) can not be controlled
"""

from __future__ import generators

import py

def escape(txt):
    """escape ReST markup"""
    if not isinstance(txt, str) and not isinstance(txt, unicode):
        txt = str(txt)
    # XXX this takes a very naive approach to escaping, but it seems to be
    # sufficient...
    for c in '\\*`|:_':
        txt = txt.replace(c, '\\%s' % (c,))
    return txt

class RestError(Exception):
    """ raised on containment errors (wrong parent) """

class AbstractMetaclass(type):
    def __new__(cls, *args):
        obj = super(AbstractMetaclass, cls).__new__(cls, *args)
        parent_cls = obj.parentclass
        if parent_cls is None:
            return obj
        if not isinstance(parent_cls, list):
            class_list = [parent_cls]
        else:
            class_list = parent_cls
        if obj.allow_nesting:
            class_list.append(obj)

        for _class in class_list:
            if not _class.allowed_child:
                _class.allowed_child = {obj:True}
            else:
                _class.allowed_child[obj] = True
        return obj

class AbstractNode(object):
    """ Base class implementing rest generation
    """
    sep = ''
    __metaclass__ = AbstractMetaclass
    parentclass = None # this exists to allow parent to know what
        # children can exist
    allow_nesting = False
    allowed_child = {}
    defaults = {}

    _reg_whitespace = py.std.re.compile('\s+')

    def __init__(self, *args, **kwargs):
        self.parent = None
        self.children = []
        for child in args:
            self._add(child)
        for arg in kwargs:
            setattr(self, arg, kwargs[arg])

    def join(self, *children):
        """ add child nodes

            returns a reference to self
        """
        for child in children:
            self._add(child)
        return self

    def add(self, child):
        """ adds a child node

            returns a reference to the child
        """
        self._add(child)
        return child

    def _add(self, child):
        if child.__class__ not in self.allowed_child:
            raise RestError("%r cannot be child of %r" % \
                (child.__class__, self.__class__))
        self.children.append(child)
        child.parent = self

    def __getitem__(self, item):
        return self.children[item]

    def __setitem__(self, item, value):
        self.children[item] = value

    def text(self):
        """ return a ReST string representation of the node """
        return self.sep.join([child.text() for child in self.children])

    def wordlist(self):
        """ return a list of ReST strings for this node and its children """
        return [self.text()]

class Rest(AbstractNode):
    """ Root node of a document """

    sep = "\n\n"
    def __init__(self, *args, **kwargs):
        AbstractNode.__init__(self, *args, **kwargs)
        self.links = {}

    def render_links(self, check=False):
        """render the link attachments of the document"""
        assert not check, "Link checking not implemented"
        if not self.links:
            return ""
        link_texts = []
        # XXX this could check for duplicates and remove them...
        for link, target in self.links.iteritems():
            link_texts.append(".. _%s: %s" % (escape(link), target))
        return "\n" + "\n".join(link_texts) + "\n\n"

    def text(self):
        outcome = []
        if (isinstance(self.children[0], Transition) or
                isinstance(self.children[-1], Transition)):
            raise ValueError('document must not begin or end with a '
                               'transition')
        for child in self.children:
            outcome.append(child.text())

        # always a trailing newline
        text = self.sep.join([i for i in outcome if i]) + "\n"
        return text + self.render_links()

class Transition(AbstractNode):
    """ a horizontal line """
    parentclass = Rest

    def __init__(self, char='-', width=80, *args, **kwargs):
        self.char = char
        self.width = width
        super(Transition, self).__init__(*args, **kwargs)

    def text(self):
        return (self.width - 1) * self.char

class Paragraph(AbstractNode):
    """ simple paragraph """

    parentclass = Rest
    sep = " "
    indent = ""
    width = 80

    def __init__(self, *args, **kwargs):
        # make shortcut
        args = list(args)
        for num, arg in py.builtin.enumerate(args):
            if isinstance(arg, str):
                args[num] = Text(arg)
        super(Paragraph, self).__init__(*args, **kwargs)

    def text(self):
        texts = []
        for child in self.children:
            texts += child.wordlist()

        buf = []
        outcome = []
        lgt = len(self.indent)

        def grab(buf):
            outcome.append(self.indent + self.sep.join(buf))

        texts.reverse()
        while texts:
            next = texts[-1]
            if not next:
                texts.pop()
                continue
            if lgt + len(self.sep) + len(next) <= self.width or not buf:
                buf.append(next)
                lgt += len(next) + len(self.sep)
                texts.pop()
            else:
                grab(buf)
                lgt = len(self.indent)
                buf = []
        grab(buf)
        return "\n".join(outcome)

class SubParagraph(Paragraph):
    """ indented sub paragraph """

    indent = " "

class Title(Paragraph):
    """ title element """

    parentclass = Rest
    belowchar = "="
    abovechar = ""

    def text(self):
        txt = self._get_text()
        lines = []
        if self.abovechar:
            lines.append(self.abovechar * len(txt))
        lines.append(txt)
        if self.belowchar:
            lines.append(self.belowchar * len(txt))
        return "\n".join(lines)

    def _get_text(self):
        txt = []
        for node in self.children:
            txt += node.wordlist()
        return ' '.join(txt)

class AbstractText(AbstractNode):
    parentclass = [Paragraph, Title]
    start = ""
    end = ""
    def __init__(self, _text):
        self._text = _text

    def text(self):
        text = self.escape(self._text)
        return self.start + text + self.end

    def escape(self, text):
        if not isinstance(text, str) and not isinstance(text, unicode):
            text = str(text)
        if self.start:
            text = text.replace(self.start, '\\%s' % (self.start,))
        if self.end and self.end != self.start:
            text = text.replace(self.end, '\\%s' % (self.end,))
        return text

class Text(AbstractText):
    def wordlist(self):
        text = escape(self._text)
        return self._reg_whitespace.split(text)

class LiteralBlock(AbstractText):
    parentclass = Rest
    start = '::\n\n'

    def text(self):
        if not self._text.strip():
            return ''
        text = self.escape(self._text).split('\n')
        for i, line in py.builtin.enumerate(text):
            if line.strip():
                text[i] = '  %s' % (line,)
        return self.start + '\n'.join(text)

class Em(AbstractText):
    start = "*"
    end = "*"

class Strong(AbstractText):
    start = "**"
    end = "**"

class Quote(AbstractText):
    start = '``'
    end = '``'

class Anchor(AbstractText):
    start = '_`'
    end = '`'

class Footnote(AbstractText):
    def __init__(self, note, symbol=False):
        raise NotImplementedError('XXX')

class Citation(AbstractText):
    def __init__(self, text, cite):
        raise NotImplementedError('XXX')

class ListItem(Paragraph):
    allow_nesting = True
    item_chars = '*+-'

    def text(self):
        idepth = self.get_indent_depth()
        indent = self.indent + (idepth + 1) * '  '
        txt = '\n\n'.join(self.render_children(indent))
        ret = []
        item_char = self.item_chars[idepth]
        ret += [indent[len(item_char)+1:], item_char, ' ', txt[len(indent):]]
        return ''.join(ret)

    def render_children(self, indent):
        txt = []
        buffer = []
        def render_buffer(fro, to):
            if not fro:
                return
            p = Paragraph(indent=indent, *fro)
            p.parent = self.parent
            to.append(p.text())
        for child in self.children:
            if isinstance(child, AbstractText):
                buffer.append(child)
            else:
                if buffer:
                    render_buffer(buffer, txt)
                    buffer = []
                txt.append(child.text())

        render_buffer(buffer, txt)
        return txt

    def get_indent_depth(self):
        depth = 0
        current = self
        while (current.parent is not None and
                isinstance(current.parent, ListItem)):
            depth += 1
            current = current.parent
        return depth

class OrderedListItem(ListItem):
    item_chars = ["#."] * 5

class DListItem(ListItem):
    item_chars = None
    def __init__(self, term, definition, *args, **kwargs):
        self.term = term
        super(DListItem, self).__init__(definition, *args, **kwargs)

    def text(self):
        idepth = self.get_indent_depth()
        indent = self.indent + (idepth + 1) * '  '
        txt = '\n\n'.join(self.render_children(indent))
        ret = []
        ret += [indent[2:], self.term, '\n', txt]
        return ''.join(ret)

class Link(AbstractText):
    start = '`'
    end = '`_'

    def __init__(self, _text, target):
        self._text = _text
        self.target = target
        self.rest = None

    def text(self):
        if self.rest is None:
            self.rest = self.find_rest()
        if self.rest.links.get(self._text, self.target) != self.target:
            raise ValueError('link name %r already in use for a different '
                             'target' % (self.target,))
        self.rest.links[self._text] = self.target
        return AbstractText.text(self)

    def find_rest(self):
        # XXX little overkill, but who cares...
        next = self
        while next.parent is not None:
            next = next.parent
        return next

class InternalLink(AbstractText):
    start = '`'
    end = '`_'

class LinkTarget(Paragraph):
    def __init__(self, name, target):
        self.name = name
        self.target = target

    def text(self):
        return ".. _%s: %s\n" % (self.name, self.target)

class Substitution(AbstractText):
    def __init__(self, text, **kwargs):
        raise NotImplementedError('XXX')

class Directive(Paragraph):
    indent = '   '
    def __init__(self, name, *args, **options):
        self.name = name
        self.content = args
        super(Directive, self).__init__()
        self.options = options

    def text(self):
        # XXX not very pretty...
        txt = '.. %s::' % (self.name,)
        options = '\n'.join(['    :%s: %s' % (k, v) for (k, v) in
                             self.options.iteritems()])
        if options:
            txt += '\n%s' % (options,)

        if self.content:
            txt += '\n'
            for item in self.content:
                txt += '\n    ' + item

        return txt

