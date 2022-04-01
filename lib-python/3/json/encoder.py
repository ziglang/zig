"""Implementation of JSONEncoder
"""
import re

from __pypy__.builders import StringBuilder


ESCAPE = re.compile(r'[\x00-\x1f\\"\b\f\n\r\t]')
ESCAPE_ASCII = re.compile(r'([\\"]|[^\ -~])')
HAS_UTF8 = re.compile(b'[\x80-\xff]')
ESCAPE_DCT = {
    '\\': '\\\\',
    '"': '\\"',
    '\b': '\\b',
    '\f': '\\f',
    '\n': '\\n',
    '\r': '\\r',
    '\t': '\\t',
}
for i in range(0x20):
    ESCAPE_DCT.setdefault(chr(i), '\\u{0:04x}'.format(i))
    #ESCAPE_DCT.setdefault(chr(i), '\\u%04x' % (i,))

INFINITY = float('inf')

def raw_encode_basestring(s):
    """Return a JSON representation of a Python string

    """
    def replace(match):
        return ESCAPE_DCT[match.group(0)]
    return ESCAPE.sub(replace, s)
encode_basestring = lambda s: '"' + raw_encode_basestring(s) + '"'


def raw_encode_basestring_ascii(s):
    """Return an ASCII-only JSON representation of a Python string

    """
    def replace(match):
        s = match.group(0)
        try:
            return ESCAPE_DCT[s]
        except KeyError:
            n = ord(s)
            if n < 0x10000:
                return '\\u{0:04x}'.format(n)
                #return '\\u%04x' % (n,)
            else:
                # surrogate pair
                n -= 0x10000
                s1 = 0xd800 | ((n >> 10) & 0x3ff)
                s2 = 0xdc00 | (n & 0x3ff)
                return '\\u{0:04x}\\u{1:04x}'.format(s1, s2)
    return ESCAPE_ASCII.sub(replace, s)
encode_basestring_ascii = lambda s: '"' + raw_encode_basestring_ascii(s) + '"'


class JSONEncoder(object):
    """Extensible JSON <http://json.org> encoder for Python data structures.

    Supports the following objects and types by default:

    +-------------------+---------------+
    | Python            | JSON          |
    +===================+===============+
    | dict              | object        |
    +-------------------+---------------+
    | list, tuple       | array         |
    +-------------------+---------------+
    | str               | string        |
    +-------------------+---------------+
    | int, float        | number        |
    +-------------------+---------------+
    | True              | true          |
    +-------------------+---------------+
    | False             | false         |
    +-------------------+---------------+
    | None              | null          |
    +-------------------+---------------+

    To extend this to recognize other objects, subclass and implement a
    ``.default()`` method with another method that returns a serializable
    object for ``o`` if possible, otherwise it should call the superclass
    implementation (to raise ``TypeError``).

    """
    item_separator = ', '
    key_separator = ': '
    def __init__(self, *, skipkeys=False, ensure_ascii=True,
            check_circular=True, allow_nan=True, sort_keys=False,
            indent=None, separators=None, default=None):
        """Constructor for JSONEncoder, with sensible defaults.

        If skipkeys is false, then it is a TypeError to attempt
        encoding of keys that are not str, int, float or None.  If
        skipkeys is True, such items are simply skipped.

        If ensure_ascii is true, the output is guaranteed to be str
        objects with all incoming non-ASCII characters escaped.  If
        ensure_ascii is false, the output can contain non-ASCII characters.

        If check_circular is true, then lists, dicts, and custom encoded
        objects will be checked for circular references during encoding to
        prevent an infinite recursion (which would cause an RecursionError).
        Otherwise, no such check takes place.

        If allow_nan is true, then NaN, Infinity, and -Infinity will be
        encoded as such.  This behavior is not JSON specification compliant,
        but is consistent with most JavaScript based encoders and decoders.
        Otherwise, it will be a ValueError to encode such floats.

        If sort_keys is true, then the output of dictionaries will be
        sorted by key; this is useful for regression tests to ensure
        that JSON serializations can be compared on a day-to-day basis.

        If indent is a non-negative integer, then JSON array
        elements and object members will be pretty-printed with that
        indent level.  An indent level of 0 will only insert newlines.
        None is the most compact representation.

        If specified, separators should be an (item_separator, key_separator)
        tuple.  The default is (', ', ': ') if *indent* is ``None`` and
        (',', ': ') otherwise.  To get the most compact JSON representation,
        you should specify (',', ':') to eliminate whitespace.

        If specified, default is a function that gets called for objects
        that can't otherwise be serialized.  It should return a JSON encodable
        version of the object or raise a ``TypeError``.

        """

        self.skipkeys = skipkeys
        self.ensure_ascii = ensure_ascii
        if ensure_ascii:
            self.__encoder = raw_encode_basestring_ascii
        else:
            self.__encoder = raw_encode_basestring
        self.check_circular = check_circular
        self.allow_nan = allow_nan
        self.sort_keys = sort_keys
        self.indent = indent
        if separators is not None:
            self.item_separator, self.key_separator = separators
        elif indent is not None:
            self.item_separator = ','
        if default is not None:
            self.default = default

        if indent is not None and not isinstance(indent, str):
            self.indent_str = ' ' * indent
        else:
            self.indent_str = indent

    def default(self, o):
        """Implement this method in a subclass such that it returns
        a serializable object for ``o``, or calls the base implementation
        (to raise a ``TypeError``).

        For example, to support arbitrary iterators, you could
        implement default like this::

            def default(self, o):
                try:
                    iterable = iter(o)
                except TypeError:
                    pass
                else:
                    return list(iterable)
                # Let the base class default method raise the TypeError
                return JSONEncoder.default(self, o)

        """
        raise TypeError(f'Object of type {o.__class__.__name__} '
                        f'is not JSON serializable')

    def encode(self, o):
        """Return a JSON string representation of a Python data structure.

        >>> from json.encoder import JSONEncoder
        >>> JSONEncoder().encode({"foo": ["bar", "baz"]})
        '{"foo": ["bar", "baz"]}'

        """
        if self.check_circular:
            markers = {}
        else:
            markers = None
        builder = StringBuilder()
        self.__encode(o, markers, builder, 0)
        return builder.build()

    def __emit_indent(self, builder, _current_indent_level):
        if self.indent is not None:
            _current_indent_level += 1
            newline_indent = '\n' + self.indent_str * _current_indent_level
            separator = self.item_separator + newline_indent
            builder.append(newline_indent)
        else:
            separator = self.item_separator
        return separator, _current_indent_level

    def __emit_unindent(self, builder, _current_indent_level):
        if self.indent is not None:
            builder.append('\n')
            builder.append(self.indent_str * (_current_indent_level - 1))

    def __encode(self, o, markers, builder, _current_indent_level):
        if isinstance(o, str):
            builder.append('"')
            builder.append(self.__encoder(o))
            builder.append('"')
        elif o is None:
            builder.append('null')
        elif o is True:
            builder.append('true')
        elif o is False:
            builder.append('false')
        elif isinstance(o, int):
            # Subclasses of int/float may override __str__, but we still
            # want to encode them as integers/floats in JSON. One example
            # within the standard library is IntEnum.
            builder.append(int.__str__(o))
        elif isinstance(o, float):
            builder.append(self.__floatstr(o))
        elif isinstance(o, (list, tuple)):
            if not o:
                builder.append('[]')
                return
            self.__encode_list(o, markers, builder, _current_indent_level)
        elif isinstance(o, dict):
            if not o:
                builder.append('{}')
                return
            self.__encode_dict(o, markers, builder, _current_indent_level)
        else:
            self.__mark_markers(markers, o)
            res = self.default(o)
            self.__encode(res, markers, builder, _current_indent_level)
            self.__remove_markers(markers, o)
            return res

    def __encode_list(self, l, markers, builder, _current_indent_level):
        self.__mark_markers(markers, l)
        builder.append('[')
        first = True
        separator, _current_indent_level = self.__emit_indent(builder,
                                                      _current_indent_level)
        for elem in l:
            if first:
                first = False
            else:
                builder.append(separator)
            self.__encode(elem, markers, builder, _current_indent_level)
            del elem # XXX grumble
        self.__emit_unindent(builder, _current_indent_level)
        builder.append(']')
        self.__remove_markers(markers, l)

    def __encode_dict(self, d, markers, builder, _current_indent_level):
        self.__mark_markers(markers, d)
        first = True
        builder.append('{')
        separator, _current_indent_level = self.__emit_indent(builder,
                                                         _current_indent_level)
        if self.sort_keys:
            items = sorted(d.items(), key=lambda kv: kv[0])
        else:
            items = d.items()

        for key, v in items:
            if isinstance(key, str):
                pass
            # JavaScript is weakly typed for these, so it makes sense to
            # also allow them.  Many encoders seem to do something like this.
            elif isinstance(key, float):
                key = self.__floatstr(key)
            elif key is True:
                key = 'true'
            elif key is False:
                key = 'false'
            elif key is None:
                key = 'null'
            elif isinstance(key, int):
                # see comment for int in __encode
                key = int.__str__(key)
            elif self.skipkeys:
                continue
            else:
                raise TypeError(f'keys must be str, int, float, bool or None, '
                                f'not {key.__class__.__name__}')
            if first:
                first = False
            else:
                builder.append(separator)
            builder.append('"')
            builder.append(self.__encoder(key))
            builder.append('"')
            builder.append(self.key_separator)
            self.__encode(v, markers, builder, _current_indent_level)
            del key
            del v # XXX grumble
        self.__emit_unindent(builder, _current_indent_level)
        builder.append('}')
        self.__remove_markers(markers, d)

    def iterencode(self, o, _one_shot=False):
        """Encode the given object and yield each string
        representation as available.

        For example::

            for chunk in JSONEncoder().iterencode(bigobject):
                mysocket.write(chunk)

        """
        if self.check_circular:
            markers = {}
        else:
            markers = None
        return self.__iterencode(o, markers, 0)

    def __floatstr(self, o):
        # Check for specials.  Note that this type of test is processor
        # and/or platform-specific, so do tests which don't depend on the
        # internals.

        if o != o:
            text = 'NaN'
        elif o == INFINITY:
            text = 'Infinity'
        elif o == -INFINITY:
            text = '-Infinity'
        else:
            return float.__repr__(o)

        if not self.allow_nan:
            raise ValueError(
                "Out of range float values are not JSON compliant: " +
                repr(o))

        return text

    def __mark_markers(self, markers, o):
        if markers is not None:
            if id(o) in markers:
                raise ValueError("Circular reference detected")
            markers[id(o)] = None

    def __remove_markers(self, markers, o):
        if markers is not None:
            del markers[id(o)]

    def __iterencode_list(self, lst, markers, _current_indent_level):
        if not lst:
            yield '[]'
            return
        self.__mark_markers(markers, lst)
        buf = '['
        if self.indent is not None:
            _current_indent_level += 1
            newline_indent = '\n' + self.indent_str * _current_indent_level
            separator = self.item_separator + newline_indent
            buf += newline_indent
        else:
            newline_indent = None
            separator = self.item_separator
        first = True
        for value in lst:
            if first:
                first = False
            else:
                buf = separator
            if isinstance(value, str):
                yield buf + '"' + self.__encoder(value) + '"'
            elif value is None:
                yield buf + 'null'
            elif value is True:
                yield buf + 'true'
            elif value is False:
                yield buf + 'false'
            elif isinstance(value, int):
                # see comment for int in __encode
                yield buf + int.__str__(value)
            elif isinstance(value, float):
                yield buf + self.__floatstr(value)
            else:
                yield buf
                if isinstance(value, (list, tuple)):
                    chunks = self.__iterencode_list(value, markers,
                                                   _current_indent_level)
                elif isinstance(value, dict):
                    chunks = self.__iterencode_dict(value, markers,
                                                   _current_indent_level)
                else:
                    chunks = self.__iterencode(value, markers,
                                              _current_indent_level)
                yield from chunks
        if newline_indent is not None:
            _current_indent_level -= 1
            yield '\n' + self.indent_str * _current_indent_level
        yield ']'
        self.__remove_markers(markers, lst)

    def __iterencode_dict(self, dct, markers, _current_indent_level):
        if not dct:
            yield '{}'
            return
        self.__mark_markers(markers, dct)
        yield '{'
        if self.indent is not None:
            _current_indent_level += 1
            newline_indent = '\n' + self.indent_str * _current_indent_level
            item_separator = self.item_separator + newline_indent
            yield newline_indent
        else:
            newline_indent = None
            item_separator = self.item_separator
        first = True
        if self.sort_keys:
            items = sorted(dct.items())
        else:
            items = dct.items()
        for key, value in items:
            if isinstance(key, str):
                pass
            # JavaScript is weakly typed for these, so it makes sense to
            # also allow them.  Many encoders seem to do something like this.
            elif isinstance(key, float):
                key = self.__floatstr(key)
            elif key is True:
                key = 'true'
            elif key is False:
                key = 'false'
            elif key is None:
                key = 'null'
            elif isinstance(key, int):
                # see comment for int in __encode
                key = int.__str__(key)
            elif self.skipkeys:
                continue
            else:
                raise TypeError(f'keys must be str, int, float, bool or None, '
                                f'not {key.__class__.__name__}')
            if first:
                first = False
            else:
                yield item_separator
            yield '"' + self.__encoder(key) + '"'
            yield self.key_separator
            if isinstance(value, str):
                yield '"' + self.__encoder(value) + '"'
            elif value is None:
                yield 'null'
            elif value is True:
                yield 'true'
            elif value is False:
                yield 'false'
            elif isinstance(value, int):
                yield int.__str__(value)
            elif isinstance(value, float):
                yield self.__floatstr(value)
            else:
                if isinstance(value, (list, tuple)):
                    chunks = self.__iterencode_list(value, markers,
                                                   _current_indent_level)
                elif isinstance(value, dict):
                    chunks = self.__iterencode_dict(value, markers,
                                                   _current_indent_level)
                else:
                    chunks = self.__iterencode(value, markers,
                                              _current_indent_level)
                yield from chunks
        if newline_indent is not None:
            _current_indent_level -= 1
            yield '\n' + self.indent_str * _current_indent_level
        yield '}'
        self.__remove_markers(markers, dct)

    def __iterencode(self, o, markers, _current_indent_level):
        if isinstance(o, str):
            yield '"' + self.__encoder(o) + '"'
        elif o is None:
            yield 'null'
        elif o is True:
            yield 'true'
        elif o is False:
            yield 'false'
        elif isinstance(o, int):
            yield int.__str__(o)
        elif isinstance(o, float):
            yield self.__floatstr(o)
        elif isinstance(o, (list, tuple)):
            yield from self.__iterencode_list(o, markers, _current_indent_level)
        elif isinstance(o, dict):
            yield from self.__iterencode_dict(o, markers, _current_indent_level)
        else:
            self.__mark_markers(markers, o)
            obj = self.default(o)
            yield from self.__iterencode(obj, markers, _current_indent_level)
            self.__remove_markers(markers, o)


# overwrite some helpers here with more efficient versions
try:
    from _pypyjson import raw_encode_basestring_ascii
except ImportError:
    pass
