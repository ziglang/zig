"""The unicode/str format() method"""

import math
import sys
import string

from pypy.interpreter.error import OperationError, oefmt
from rpython.rlib import rstring, rlocale, rfloat, jit, rutf8
from rpython.rlib.objectmodel import specialize
from rpython.rlib.rfloat import formatd
from rpython.rlib.rarithmetic import r_uint, intmask
from pypy.interpreter.signature import Signature

@specialize.argtype(1)
@jit.look_inside_iff(lambda space, s, start, end:
       jit.isconstant(s) and
       jit.isconstant(start) and
       jit.isconstant(end))
def _parse_int(space, s, start, end):
    """Parse a number and check for overflows"""
    result = 0
    i = start
    while i < end:
        digit = ord(s[i]) - ord('0')
        if 0 <= digit <= 9:
            if result > (sys.maxint - digit) / 10:
                raise oefmt(space.w_ValueError,
                            "too many decimal digits in format string")
            result = result * 10 + digit
        else:
            break
        i += 1
    if i == start:
        result = -1
    return result, i


# Auto number state
ANS_INIT = 1
ANS_AUTO = 2
ANS_MANUAL = 3


format_signature = Signature([], 'args', 'kwargs')


def make_template_formatting_class(for_unicode):
    class TemplateFormatter(object):
        is_unicode = for_unicode

        if for_unicode:
            def wrap(self, u):
                lgt = rutf8.check_utf8(u, True)
                return self.space.newutf8(u, lgt)
        else:
            def wrap(self, s):
                return self.space.newbytes(s)

        parser_list_w = None

        def __init__(self, space, template):
            self.space = space
            self.template = template

        def build(self, args, w_kwargs):
            self.args = args
            self.w_kwargs = w_kwargs
            self.auto_numbering = 0
            self.auto_numbering_state = ANS_INIT
            return self._build_string(0, len(self.template), 2)

        def _build_string(self, start, end, level):
            space = self.space
            out = rstring.StringBuilder()
            if not level:
                raise oefmt(space.w_ValueError, "Recursion depth exceeded")
            level -= 1
            s = self.template
            return self._do_build_string(start, end, level, out, s)

        @jit.look_inside_iff(lambda self, start, end, level, out, s: jit.isconstant(s))
        def _do_build_string(self, start, end, level, out, s):
            space = self.space
            last_literal = i = start
            while i < end:
                c = s[i]
                i += 1
                if c == "{" or c == "}":
                    at_end = i == end
                    # Find escaped "{" and "}"
                    markup_follows = True
                    if c == "}":
                        if at_end or s[i] != "}":
                            raise oefmt(space.w_ValueError, "Single '}'")
                        i += 1
                        markup_follows = False
                    if c == "{":
                        if at_end:
                            raise oefmt(space.w_ValueError, "Single '{'")
                        if s[i] == "{":
                            i += 1
                            markup_follows = False
                    # Attach literal data, ending with { or }
                    out.append_slice(s, last_literal, i - 1)
                    if not markup_follows:
                        if self.parser_list_w is not None:
                            end_literal = i - 1
                            assert end_literal > last_literal
                            literal = self.template[last_literal:end_literal]
                            w_entry = space.newtuple([
                                self.wrap(literal),
                                space.w_None, space.w_None, space.w_None])
                            self.parser_list_w.append(w_entry)
                            self.last_end = i
                        last_literal = i
                        continue
                    nested = 1
                    field_start = i
                    recursive = False
                    in_second_part = False
                    while i < end:
                        c = s[i]
                        if c == "{":
                            recursive = True
                            nested += 1
                        elif c == "}":
                            nested -= 1
                            if not nested:
                                break
                        elif c == "[" and not in_second_part:
                            i += 1
                            while i < end and s[i] != "]":
                                i += 1
                            continue
                        elif c == ':' or c == '!':
                            in_second_part = True
                        i += 1
                    if nested:
                        raise oefmt(space.w_ValueError, "Unmatched '{'")
                    rendered = self._render_field(field_start, i, recursive, level)
                    out.append(rendered)
                    i += 1
                    last_literal = i

            out.append_slice(s, last_literal, end)
            return out.build()

        # This is only ever called if we're already unrolling _do_build_string
        @jit.unroll_safe
        def _parse_field(self, start, end):
            s = self.template
            # Find ":" or "!"
            i = start
            while i < end:
                c = s[i]
                if c == ":" or c == "!":
                    end_name = i
                    if c == "!":
                        i += 1
                        if i == end:
                            raise oefmt(self.space.w_ValueError,
                                        "expected conversion")
                        conversion = s[i]
                        i += 1
                        if i < end:
                            if s[i] != ':':
                                raise oefmt(self.space.w_ValueError,
                                            "expected ':' after format "
                                            "specifier")
                            i += 1
                    else:
                        conversion = None
                        i += 1
                    return s[start:end_name], conversion, i
                elif c == "[":
                    while i + 1 < end and s[i + 1] != "]":
                        i += 1
                elif c == "{":
                    raise oefmt(self.space.w_ValueError,
                                "unexpected '{' in field name")
                i += 1
            return s[start:end], None, end

        @jit.unroll_safe
        def _get_argument(self, name):
            # First, find the argument.
            space = self.space
            i = 0
            end = len(name)
            while i < end:
                c = name[i]
                if c == "[" or c == ".":
                    break
                i += 1
            empty = not i
            if empty:
                index = -1
            else:
                index, stop = _parse_int(self.space, name, 0, i)
                if stop != i:
                    index = -1
            use_numeric = empty or index != -1
            if self.auto_numbering_state == ANS_INIT and use_numeric:
                if empty:
                    self.auto_numbering_state = ANS_AUTO
                else:
                    self.auto_numbering_state = ANS_MANUAL
            if use_numeric:
                if self.auto_numbering_state == ANS_MANUAL:
                    if empty:
                        raise oefmt(space.w_ValueError,
                                    "switching from manual to automatic "
                                    "numbering")
                elif not empty:
                    raise oefmt(space.w_ValueError,
                                "switching from automatic to manual numbering")
            if empty:
                index = self.auto_numbering
                self.auto_numbering += 1
            if index == -1:
                kwarg = name[:i]
                if self.is_unicode:
                    w_kwarg = space.newtext(kwarg)
                else:
                    w_kwarg = space.newbytes(kwarg)
                w_arg = space.getitem(self.w_kwargs, w_kwarg)
            else:
                if self.args is None:
                    raise oefmt(space.w_ValueError,
                                "Format string contains positional fields")
                try:
                    w_arg = self.args[index]
                except IndexError:
                    raise oefmt(space.w_IndexError,
                                "out of range: index %d but only %d argument%s",
                                index, len(self.args),
                                "s" if len(self.args) != 1 else "")
            return self._resolve_lookups(w_arg, name, i, end)

        @jit.unroll_safe
        def _resolve_lookups(self, w_obj, name, start, end):
            # Resolve attribute and item lookups.
            space = self.space
            i = start
            while i < end:
                c = name[i]
                if c == ".":
                    i += 1
                    start = i
                    while i < end:
                        c = name[i]
                        if c == "[" or c == ".":
                            break
                        i += 1
                    if start == i:
                        raise oefmt(space.w_ValueError,
                                    "Empty attribute in format string")
                    w_attr = self.wrap(name[start:i])
                    if w_obj is not None:
                        w_obj = space.getattr(w_obj, w_attr)
                    else:
                        self.parser_list_w.append(space.newtuple([
                            space.w_True, w_attr]))
                elif c == "[":
                    got_bracket = False
                    i += 1
                    start = i
                    while i < end:
                        c = name[i]
                        if c == "]":
                            got_bracket = True
                            break
                        i += 1
                    if not got_bracket:
                        raise oefmt(space.w_ValueError, "Missing ']'")
                    index, reached = _parse_int(self.space, name, start, i)
                    if index != -1 and reached == i:
                        w_item = space.newint(index)
                    else:
                        w_item = self.wrap(name[start:i])
                    i += 1 # Skip "]"
                    if w_obj is not None:
                        w_obj = space.getitem(w_obj, w_item)
                    else:
                        self.parser_list_w.append(space.newtuple([
                            space.w_False, w_item]))
                else:
                    raise oefmt(space.w_ValueError,
                                "Only '[' and '.' may follow ']'")
            return w_obj

        def formatter_field_name_split(self):
            space = self.space
            name = self.template
            i = 0
            end = len(name)
            while i < end:
                c = name[i]
                if c == "[" or c == ".":
                    break
                i += 1
            if i == 0:
                index = -1
            else:
                index, stop = _parse_int(self.space, name, 0, i)
                if stop != i:
                    index = -1
            if index >= 0:
                w_first = space.newint(index)
            else:
                w_first = self.wrap(name[:i])
            #
            self.parser_list_w = []
            self._resolve_lookups(None, name, i, end)
            #
            return space.newtuple([w_first,
                                   space.iter(space.newlist(self.parser_list_w))])

        def _convert(self, w_obj, conversion):
            space = self.space
            conv = conversion[0]
            if conv == "r":
                return space.repr(w_obj)
            elif conv == "s":
                if self.is_unicode:
                    return space.call_function(space.w_unicode, w_obj)
                return space.str(w_obj)
            elif conv == "a":
                from pypy.objspace.std.unicodeobject import ascii_from_object
                return ascii_from_object(space, w_obj)
            else:
                raise oefmt(space.w_ValueError, "invalid conversion")

        def _render_field(self, start, end, recursive, level):
            name, conversion, spec_start = self._parse_field(start, end)
            spec = self.template[spec_start:end]
            #
            if self.parser_list_w is not None:
                # used from formatter_parser()
                if level == 1:    # ignore recursive calls
                    space = self.space
                    startm1 = start - 1
                    assert startm1 >= self.last_end
                    if conversion is None:
                        w_conversion = space.w_None
                    else:
                        w_conversion = self.wrap(conversion)
                    w_entry = space.newtuple([
                        self.wrap(self.template[self.last_end:startm1]),
                        self.wrap(name),
                        self.wrap(spec),
                        w_conversion])
                    self.parser_list_w.append(w_entry)
                    self.last_end = end + 1
                return ""
            #
            w_obj = self._get_argument(name)
            if conversion is not None:
                w_obj = self._convert(w_obj, conversion)
            if recursive:
                spec = self._build_string(spec_start, end, level)
            w_rendered = self.space.format(w_obj, self.wrap(spec))
            if self.is_unicode:
                w_rendered = self.space.unicode_from_object(w_rendered)
                return self.space.utf8_w(w_rendered)
            else:
                return self.space.bytes_w(w_rendered)

        def formatter_parser(self):
            self.parser_list_w = []
            self.last_end = 0
            self._build_string(0, len(self.template), 2)
            #
            space = self.space
            if self.last_end < len(self.template):
                w_lastentry = space.newtuple([
                    self.wrap(self.template[self.last_end:]),
                    space.w_None,
                    space.w_None,
                    space.w_None])
                self.parser_list_w.append(w_lastentry)
            return space.iter(space.newlist(self.parser_list_w))
    return TemplateFormatter

str_template_formatter = make_template_formatting_class(for_unicode=False)
unicode_template_formatter = make_template_formatting_class(for_unicode=True)


def format_method(space, w_string, args, w_kwargs, is_unicode):
    if is_unicode:
        template = unicode_template_formatter(space,
                                              space.utf8_w(w_string))
        r = template.build(args, w_kwargs)
        lgt = rutf8.check_utf8(r, True)
        return space.newutf8(r, lgt)
    else:
        template = str_template_formatter(space, space.bytes_w(w_string))
        return space.newbytes(template.build(args, w_kwargs))


class NumberSpec(object):
    pass


class BaseFormatter(object):
    def format_int_or_long(self, w_num, kind):
        raise NotImplementedError

    def format_float(self, w_num):
        raise NotImplementedError

    def format_complex(self, w_num):
        raise NotImplementedError


INT_KIND = 1
LONG_KIND = 2

NO_LOCALE = 1
DEFAULT_LOCALE = 2
CURRENT_LOCALE = 3

LONG_DIGITS = string.digits + string.ascii_lowercase

def make_formatting_class(for_unicode):
    class Formatter(BaseFormatter):
        """__format__ implementation for builtin types."""

        if for_unicode:
            def wrap(self, u):
                lgt = rutf8.check_utf8(u, True)
                return self.space.newutf8(u, lgt)
        else:
            def wrap(self, s):
                return self.space.newbytes(s)

        is_unicode = for_unicode
        _grouped_digits = None

        def __init__(self, space, spec):
            self.space = space
            self.spec = spec

        def _is_alignment(self, c):
            return (c == "<" or
                    c == ">" or
                    c == "=" or
                    c == "^")

        def _is_sign(self, c):
            return (c == " " or
                    c == "+" or
                    c == "-")

        def _parse_spec(self, default_type, default_align):
            space = self.space
            self._fill_char = self._lit(" ")[0]
            self._align = default_align
            self._alternate = False
            self._sign = "\0"
            self._thousands_sep = "\0"
            self._precision = -1
            the_type = default_type
            spec = self.spec
            if not spec:
                return True
            length = len(spec)
            i = 0
            got_align = True
            got_fill_char = False
            # The single character could be utf8-encoded unicode
            if self.is_unicode:
                after_i = rutf8.next_codepoint_pos(spec, i)
            else:
                after_i = i + 1
            if length - i >= 2 and self._is_alignment(spec[after_i]):
                self._align = spec[after_i]
                self._fill_char = spec[i:after_i]
                got_fill_char = True
                i = after_i + 1
            elif length - i >= 1 and self._is_alignment(spec[i]):
                self._align = spec[i]
                i += 1
            else:
                got_align = False
            if length - i >= 1 and self._is_sign(spec[i]):
                self._sign = spec[i]
                i += 1
            if length - i >= 1 and spec[i] == "#":
                self._alternate = True
                i += 1
            if not got_fill_char and length - i >= 1 and spec[i] == "0":
                self._fill_char = self._lit("0")[0]
                if not got_align:
                    self._align = "="
                i += 1
            self._width, i = _parse_int(self.space, spec, i, length)
            if length != i and spec[i] == ",":
                self._thousands_sep = ","
                i += 1
            if length != i and spec[i] == "_":
                if self._thousands_sep != "\0":
                    raise oefmt(
                        space.w_ValueError, "Cannot specify both ',' and '_'.")
                self._thousands_sep = "_"
                i += 1
                if length != i and spec[i] == ",":
                    raise oefmt(
                        space.w_ValueError, "Cannot specify both ',' and '_'.")
            if length != i and spec[i] == ".":
                i += 1
                self._precision, i = _parse_int(self.space, spec, i, length)
                if self._precision == -1:
                    raise oefmt(space.w_ValueError, "no precision given")
            if length - i > 1:
                raise oefmt(space.w_ValueError, "invalid format spec")
            if length - i == 1:
                presentation_type = spec[i]
                if self.is_unicode:
                    try:
                        rutf8.check_utf8(spec[i], True)
                        the_type = spec[i][0]
                    except rutf8.CheckError:
                        raise oefmt(space.w_ValueError,
                                    "invalid presentation type")
                else:
                    the_type = presentation_type
                i += 1
            self._type = the_type
            if self._thousands_sep != "\0":
                tp = self._type
                if (tp == "d" or
                    tp == "e" or
                    tp == "f" or
                    tp == "g" or
                    tp == "E" or
                    tp == "G" or
                    tp == "%" or
                    tp == "F" or
                    tp == "\0"):
                    # ok
                    pass
                elif self._thousands_sep == "_" and (
                        tp == "b" or
                        tp == "o" or
                        tp == "x" or
                        tp == "X"):
                    pass # ok
                else:
                    raise oefmt(space.w_ValueError,
                                "Cannot specify '%s' with '%s'.", 
                                self._thousands_sep, tp)
            return False

        def _calc_padding(self, string, length):
            """compute left and right padding, return total width of string"""
            if self._width != -1 and length < self._width:
                total = self._width
            else:
                total = length
            align = self._align
            if align == ">":
                left = total - length
            elif align == "^":
                left = (total - length) / 2
            elif align == "<" or align == "=":
                left = 0
            else:
                raise AssertionError("shouldn't be here")
            right = total - length - left
            self._left_pad = left
            self._right_pad = right
            return total

        def _lit(self, s):
            assert len(s) == 1
            if self.is_unicode:
                return rutf8.unichr_as_utf8(ord(s[0]))
            else:
                return s

        def _pad(self, string):
            builder = self._builder()
            builder.append_multiple_char(self._fill_char, self._left_pad)
            builder.append(string)
            builder.append_multiple_char(self._fill_char, self._right_pad)
            return builder.build()

        def _builder(self):
            if self.is_unicode:
                return rutf8.Utf8StringBuilder()
            else:
                return rstring.StringBuilder()

        def _unknown_presentation(self, w_val):
            raise oefmt(self.space.w_ValueError,
                        "Unknown format code %s for object of type '%T'", self._type, w_val)

        def format_string(self, w_string):
            space = self.space
            if not space.is_w(space.type(w_string), space.w_unicode):
                w_string = space.str(w_string)
            string = space.utf8_w(w_string)
            if self._parse_spec("s", "<"):
                return self.wrap(string)
            if self._type != "s":
                self._unknown_presentation(w_string)
            if self._sign != "\0":
                if self._sign == " ":
                    raise oefmt(space.w_ValueError,
                                "Space not allowed in string format specifier")
                raise oefmt(space.w_ValueError,
                            "Sign not allowed in string format specifier")
            if self._alternate:
                raise oefmt(space.w_ValueError,
                            "Alternate form (#) not allowed in string format "
                            "specifier")
            if self._align == "=":
                raise oefmt(space.w_ValueError,
                            "'=' alignment not allowed in string format "
                            "specifier")
            length = space.len_w(w_string)
            precision = self._precision
            if precision != -1 and length >= precision:
                assert precision >= 0
                length = precision
                if for_unicode:
                    w_slice = space.newslice(
                        space.newint(0), space.newint(precision), space.w_None)
                    w_string = space.getitem(w_string, w_slice)
                    string = space.utf8_w(w_string)
                else:
                    string = string[:precision]
            self._calc_padding(string, length)
            return self.wrap(self._pad(string))

        def _get_locale(self, tp):
            if tp == "n":
                dec, thousands, grouping = rlocale.numeric_formatting()
            elif self._thousands_sep != "\0":
                thousands = self._thousands_sep
                dec = "."
                grouping = "\3"
                if tp in "boxX":
                    assert self._thousands_sep == "_"
                    grouping = "\4"
            else:
                dec = "."
                thousands = ""
                grouping = "\xFF"    # special value to mean 'stop'
            if self.is_unicode:
                self._loc_dec = rutf8.decode_latin_1(dec)
                self._loc_thousands = rutf8.decode_latin_1(thousands)
            else:
                self._loc_dec = dec
                self._loc_thousands = thousands
            self._loc_grouping = grouping

        def _calc_num_width(self, n_prefix, sign_char, to_number, n_number,
                            n_remainder, has_dec, digits):
            """Calculate widths of all parts of formatted number.

            Output will look like:

                <lpadding> <sign> <prefix> <spadding> <grouped_digits> <decimal>
                <remainder> <rpadding>

            sign is computed from self._sign, and the sign of the number
            prefix is given
            digits is known
            """
            spec = NumberSpec()
            spec.n_digits = n_number - n_remainder - has_dec
            spec.n_prefix = n_prefix
            spec.n_lpadding = 0
            spec.n_decimal = int(has_dec)
            spec.n_remainder = n_remainder
            spec.n_spadding = 0
            spec.n_rpadding = 0
            spec.n_min_width = 0
            spec.n_total = 0
            spec.sign = "\0"
            spec.n_sign = 0
            sign = self._sign
            if sign == "+":
                spec.n_sign = 1
                spec.sign = "-" if sign_char == "-" else "+"
            elif sign == " ":
                spec.n_sign = 1
                spec.sign = "-" if sign_char == "-" else " "
            elif sign_char == "-":
                spec.n_sign = 1
                spec.sign = "-"
            extra_length = (spec.n_sign + spec.n_prefix + spec.n_decimal +
                            spec.n_remainder) # Not padding or digits
            if self._fill_char == "0" and self._align == "=":
                spec.n_min_width = self._width - extra_length
            if self._loc_thousands:
                self._group_digits(spec, digits[to_number:])
                n_grouped_digits = len(self._grouped_digits)
            else:
                n_grouped_digits = spec.n_digits
            n_padding = self._width - (extra_length + n_grouped_digits)
            if n_padding > 0:
                align = self._align
                if align == "<":
                    spec.n_rpadding = n_padding
                elif align == ">":
                    spec.n_lpadding = n_padding
                elif align == "^":
                    spec.n_lpadding = n_padding // 2
                    spec.n_rpadding = n_padding - spec.n_lpadding
                elif align == "=":
                    spec.n_spadding = n_padding
                else:
                    raise AssertionError("shouldn't reach")
            spec.n_total = spec.n_lpadding + spec.n_sign + spec.n_prefix + \
                           spec.n_spadding + n_grouped_digits + \
                           spec.n_decimal + spec.n_remainder + spec.n_rpadding
            return spec

        def _fill_digits(self, buf, digits, d_state, n_chars, n_zeros,
                         thousands_sep):
            if thousands_sep:
                for c in thousands_sep:
                    buf.append(c)
            for i in range(d_state - 1, d_state - n_chars - 1, -1):
                buf.append(digits[i])
            for i in range(n_zeros):
                buf.append("0")

        def _group_digits(self, spec, digits):
            buf = []
            grouping = self._loc_grouping
            min_width = spec.n_min_width
            grouping_state = 0
            left = spec.n_digits
            n_ts = len(self._loc_thousands)
            need_separator = False
            done = False
            previous = 0
            while True:
                if grouping_state >= len(grouping):
                    group = previous     # end of string
                else:
                    # else, get the next value from the string
                    group = ord(grouping[grouping_state])
                    if group == 0xFF:    # special value to mean 'stop'
                        break
                    grouping_state += 1
                    previous = group
                #
                final_grouping = min(group, max(left, max(min_width, 1)))
                n_zeros = max(0, final_grouping - left)
                n_chars = max(0, min(left, final_grouping))
                ts = self._loc_thousands if need_separator else None
                self._fill_digits(buf, digits, left, n_chars, n_zeros, ts)
                need_separator = True
                left -= n_chars
                min_width -= final_grouping
                if left <= 0 and min_width <= 0:
                    done = True
                    break
                min_width -= n_ts
            if not done:
                group = max(max(left, min_width), 1)
                n_zeros = max(0, group - left)
                n_chars = max(0, min(left, group))
                ts = self._loc_thousands if need_separator else None
                self._fill_digits(buf, digits, left, n_chars, n_zeros, ts)
            buf.reverse()
            self._grouped_digits = "".join(buf)

        def _upcase_string(self, s):
            buf = []
            for c in s:
                index = ord(c)
                if ord("a") <= index <= ord("z"):
                    c = chr(index - 32)
                buf.append(c)
            return "".join(buf)


        def _fill_number(self, spec, num, to_digits, to_prefix, fill_char,
                         to_remainder, upper, grouped_digits=None):
            out = self._builder()
            if spec.n_lpadding:
                out.append_multiple_char(fill_char, spec.n_lpadding)
            if spec.n_sign:
                sign = self._lit(spec.sign)
                out.append(sign)
            if spec.n_prefix:
                pref = num[to_prefix:to_prefix + spec.n_prefix]
                if upper:
                    pref = self._upcase_string(pref)
                out.append(pref)
            if spec.n_spadding:
                out.append_multiple_char(fill_char, spec.n_spadding)
            if spec.n_digits != 0:
                if self._loc_thousands:
                    if grouped_digits is not None:
                        digits = grouped_digits
                    else:
                        digits = self._grouped_digits
                        assert digits is not None
                else:
                    stop = to_digits + spec.n_digits
                    assert stop >= 0
                    digits = num[to_digits:stop]
                if upper:
                    digits = self._upcase_string(digits)
                out.append(digits)
            if spec.n_decimal:
                out.append(self._lit(self._loc_dec)[0])
            if spec.n_remainder:
                out.append(num[to_remainder:])
            if spec.n_rpadding:
                out.append_multiple_char(fill_char, spec.n_rpadding)
            #if complex, need to call twice - just retun the buffer
            return out.build()

        def _format_int_or_long(self, w_num, kind):
            space = self.space
            if self._precision != -1:
                raise oefmt(space.w_ValueError,
                            "precision not allowed in integer type")
            sign_char = "\0"
            tp = self._type
            if tp == "c":
                if self._sign != "\0":
                    raise oefmt(space.w_ValueError,
                                "sign not allowed with 'c' presentation type")
                if self._alternate:
                    raise oefmt(space.w_ValueError,
                                "Alternate form (#) not allowed "
                                "with 'c' presentation type")
                value = space.int_w(w_num)
                max_char = 0x10FFFF if self.is_unicode else 0xFF
                if not (0 <= value <= max_char):
                    raise oefmt(space.w_OverflowError,
                                "%%c arg not in range(%s)",
                                hex(max_char))
                if self.is_unicode:
                    result = rutf8.unichr_as_utf8(value)
                else:
                    result = chr(value)
                n_digits = 1
                n_remainder = 1
                to_remainder = 0
                n_prefix = 0
                to_prefix = 0
                to_numeric = 0
            else:
                if tp == "b":
                    base = 2
                    skip_leading = 2
                elif tp == "o":
                    base = 8
                    skip_leading = 2
                elif tp == "x" or tp == "X":
                    base = 16
                    skip_leading = 2
                elif tp == "n" or tp == "d":
                    base = 10
                    skip_leading = 0
                else:
                    raise AssertionError("shouldn't reach")
                if kind == INT_KIND:
                    result = self._int_to_base(base, space.int_w(w_num))
                else:
                    result = self._long_to_base(base, space.bigint_w(w_num))
                n_prefix = skip_leading if self._alternate else 0
                to_prefix = 0
                if result[0] == "-":
                    sign_char = "-"
                    skip_leading += 1
                    to_prefix += 1
                n_digits = len(result) - skip_leading
                n_remainder = 0
                to_remainder = 0
                to_numeric = skip_leading
            self._get_locale(tp)
            spec = self._calc_num_width(n_prefix, sign_char, to_numeric, n_digits,
                                        n_remainder, False, result)
            fill = self._fill_char
            upper = self._type == "X"
            return self.wrap(self._fill_number(spec, result, to_numeric,
                             to_prefix, fill, to_remainder, upper))

        def _long_to_base(self, base, value):
            prefix = ""
            if base == 2:
                prefix = "0b"
            elif base == 8:
                prefix = "0o"
            elif base == 16:
                prefix = "0x"
            as_str = value.format(LONG_DIGITS[:base], prefix)
            if self.is_unicode:
                return rutf8.decode_latin_1(as_str)
            return as_str

        def _int_to_base(self, base, value):
            if base == 10:
                s = str(value)
                if self.is_unicode:
                    return rutf8.decode_latin_1(s)
                return s
            # This part is slow.
            negative = value < 0
            base = r_uint(base)
            value = r_uint(value)
            if negative:   # change the sign on the unsigned number: otherwise,
                value = -value   #   we'd risk overflow if value==-sys.maxint-1
            #
            buf = ["\0"] * (8 * 8 + 6) # Too much on 32 bit, but who cares?
            i = len(buf) - 1
            while True:
                div = value // base         # unsigned
                mod = value - div * base    # unsigned, always in range(0,base)
                digit = intmask(mod)
                digit += ord("0") if digit < 10 else ord("a") - 10
                buf[i] = chr(digit)
                value = div                 # unsigned
                i -= 1
                if not value:
                    break
            if base == r_uint(2):
                buf[i] = "b"
                buf[i - 1] = "0"
            elif base == r_uint(8):
                buf[i] = "o"
                buf[i - 1] = "0"
            elif base == r_uint(16):
                buf[i] = "x"
                buf[i - 1] = "0"
            else:
                buf[i] = "#"
                buf[i - 1] = chr(ord("0") + intmask(base % r_uint(10)))
                if base > r_uint(10):
                    buf[i - 2] = chr(ord("0") + intmask(base // r_uint(10)))
                    i -= 1
            i -= 1
            if negative:
                i -= 1
                buf[i] = "-"
            assert i >= 0
            return "".join(buf[i:])

        def format_int_or_long(self, w_num, kind):
            space = self.space
            if self._parse_spec("d", ">"):
                if self.is_unicode:
                    return space.call_function(space.w_unicode, w_num)
                return self.space.str(w_num)
            tp = self._type
            if (tp == "b" or
                tp == "c" or
                tp == "d" or
                tp == "o" or
                tp == "x" or
                tp == "X" or
                tp == "n"):
                return self._format_int_or_long(w_num, kind)
            elif (tp == "e" or
                  tp == "E" or
                  tp == "f" or
                  tp == "F" or
                  tp == "g" or
                  tp == "G" or
                  tp == "%"):
                w_float = space.float(w_num)
                return self._format_float(w_float)
            else:
                self._unknown_presentation(w_num)

        def _parse_number(self, s, i):
            """Determine if s has a decimal point, and the index of the first #
            after the decimal, or the end of the number."""
            length = len(s)
            while i < length and "0" <= s[i] <= "9":
                i += 1
            rest = i
            dec_point = i < length and s[i] == "."
            if dec_point:
                rest += 1
            #differs from CPython method - CPython sets n_remainder
            return dec_point, rest

        def _format_float(self, w_float):
            """helper for format_float"""
            space = self.space
            flags = 0
            default_precision = 6
            if self._alternate:
               flags |= rfloat.DTSF_ALT

            tp = self._type
            self._get_locale(tp)
            if tp == "\0":
                flags |= rfloat.DTSF_ADD_DOT_0
                tp = "r"
                default_precision = 0
            elif tp == "n":
                tp = "g"
            value = space.float_w(w_float)
            if tp == "%":
                tp = "f"
                value *= 100
                add_pct = True
            else:
                add_pct = False
            if self._precision == -1:
                self._precision = default_precision
            elif tp == "r":
                tp = "g"
            result, special = rfloat.double_to_string(value, tp,
                                                      self._precision, flags)
            if add_pct:
                result += "%"
            n_digits = len(result)
            if result[0] == "-":
                sign = "-"
                to_number = 1
                n_digits -= 1
            else:
                sign = "\0"
                to_number = 0
            have_dec_point, to_remainder = self._parse_number(result, to_number)
            n_remainder = len(result) - to_remainder
            if self.is_unicode:
                digits = rutf8.decode_latin_1(result)
            else:
                digits = result
            spec = self._calc_num_width(0, sign, to_number, n_digits,
                                        n_remainder, have_dec_point, digits)
            fill = self._fill_char
            return self.wrap(self._fill_number(spec, digits, to_number, 0,
                             fill, to_remainder, False))

        def format_float(self, w_float):
            space = self.space
            if self._parse_spec("\0", ">"):
                if self.is_unicode:
                    return space.call_function(space.w_unicode, w_float)
                return space.str(w_float)
            tp = self._type
            if (tp == "\0" or
                tp == "e" or
                tp == "E" or
                tp == "f" or
                tp == "F" or
                tp == "g" or
                tp == "G" or
                tp == "n" or
                tp == "%"):
                return self._format_float(w_float)
            self._unknown_presentation(w_float)

        def _format_complex(self, w_complex):
            flags = 0
            space = self.space
            tp = self._type
            self._get_locale(tp)
            default_precision = 6
            if self._align == "=":
                # '=' alignment is invalid
                raise oefmt(space.w_ValueError,
                            "'=' alignment flag is not allowed in complex "
                            "format specifier")
            if self._fill_char == "0":
                # zero padding is invalid
                raise oefmt(space.w_ValueError,
                            "Zero padding is not allowed in complex format "
                            "specifier")
            if self._alternate:
                flags |= rfloat.DTSF_ALT

            skip_re = 0
            add_parens = 0
            if tp == "\0":
                #should mirror str() output
                tp = "g"
                default_precision = 12
                #test if real part is non-zero
                if (w_complex.realval == 0 and
                    math.copysign(1., w_complex.realval) == 1.):
                    skip_re = 1
                else:
                    add_parens = 1

            if tp == "n":
                #same as 'g' except for locale, taken care of later
                tp = "g"

            #check if precision not set
            if self._precision == -1:
                self._precision = default_precision

            #in CPython it's named 're' - clashes with re module
            re_num, special = rfloat.double_to_string(w_complex.realval, tp, self._precision, flags)
            im_num, special = rfloat.double_to_string(w_complex.imagval, tp, self._precision, flags)
            n_re_digits = len(re_num)
            n_im_digits = len(im_num)

            to_real_number = 0
            to_imag_number = 0
            re_sign = im_sign = ''
            #if a sign character is in the output, remember it and skip
            if re_num[0] == "-":
                re_sign = "-"
                to_real_number = 1
                n_re_digits -= 1
            if im_num[0] == "-":
                im_sign = "-"
                to_imag_number = 1
                n_im_digits -= 1

            #turn off padding - do it after number composition
            #calc_num_width uses self._width, so assign to temporary variable,
            #calculate width of real and imag parts, then reassign padding, align
            tmp_fill_char = self._fill_char
            tmp_align = self._align
            tmp_width = self._width
            self._fill_char = "\0"
            self._align = "<"
            self._width = -1

            #determine if we have remainder, might include dec or exponent or both
            re_have_dec, re_remainder_ptr = self._parse_number(re_num,
                                                               to_real_number)
            im_have_dec, im_remainder_ptr = self._parse_number(im_num,
                                                               to_imag_number)

            if self.is_unicode:
                re_num = rutf8.decode_latin_1(re_num)
                im_num = rutf8.decode_latin_1(im_num)

            #set remainder, in CPython _parse_number sets this
            #using n_re_digits causes tests to fail
            re_n_remainder = len(re_num) - re_remainder_ptr
            im_n_remainder = len(im_num) - im_remainder_ptr
            re_spec = self._calc_num_width(0, re_sign, to_real_number, n_re_digits,
                                           re_n_remainder, re_have_dec,
                                           re_num)

            #capture grouped digits b/c _fill_number reads from self._grouped_digits
            #self._grouped_digits will get overwritten in imaginary calc_num_width
            re_grouped_digits = self._grouped_digits
            if not skip_re:
                self._sign = "+"
            im_spec = self._calc_num_width(0, im_sign, to_imag_number, n_im_digits,
                                           im_n_remainder, im_have_dec,
                                           im_num)

            im_grouped_digits = self._grouped_digits
            if skip_re:
                re_spec.n_total = 0

            #reassign width, alignment, fill character
            self._align = tmp_align
            self._width = tmp_width
            self._fill_char = tmp_fill_char

            #compute L and R padding - stored in self._left_pad and self._right_pad
            self._calc_padding("", re_spec.n_total + im_spec.n_total + 1 +
                                           add_parens * 2)

            out = self._builder()
            fill = self._fill_char

            #compose the string
            #add left padding
            out.append_multiple_char(fill, self._left_pad)
            if add_parens:
                out.append(self._lit('(')[0])

            #if the no. has a real component, add it
            if not skip_re:
                out.append(self._fill_number(re_spec, re_num, to_real_number, 0,
                                             fill, re_remainder_ptr, False,
                                             re_grouped_digits))

            #add imaginary component
            out.append(self._fill_number(im_spec, im_num, to_imag_number, 0,
                                         fill, im_remainder_ptr, False,
                                         im_grouped_digits))

            #add 'j' character
            out.append(self._lit('j')[0])

            if add_parens:
                out.append(self._lit(')')[0])

            #add right padding
            out.append_multiple_char(fill, self._right_pad)

            return self.wrap(out.build())


        def format_complex(self, w_complex):
            """return the string representation of a complex number"""
            space = self.space
            #parse format specification, set associated variables
            if self._parse_spec("\0", ">"):
                return space.str(w_complex)
            tp = self._type
            if (tp == "\0" or
                tp == "e" or
                tp == "E" or
                tp == "f" or
                tp == "F" or
                tp == "g" or
                tp == "G" or
                tp == "n"):
                return self._format_complex(w_complex)
            self._unknown_presentation(w_complex)
    return Formatter

unicode_formatter = make_formatting_class(for_unicode=True)


@specialize.arg(2)
def run_formatter(space, w_format_spec, meth, *args):
    formatter = unicode_formatter(space, space.utf8_w(w_format_spec))
    return getattr(formatter, meth)(*args)
