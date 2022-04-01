"""The builtin bytes implementation"""

from rpython.rlib import jit, rutf8
from rpython.rlib.objectmodel import (
    compute_hash, compute_unique_id, import_from_mixin)
from rpython.rlib.rstring import StringBuilder

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.buffer import SimpleView, StringBuffer
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import (
    WrappedDefault, interp2app, interpindirect2app, unwrap_spec)
from pypy.interpreter.typedef import TypeDef
from pypy.objspace.std.stringmethods import StringMethods
from pypy.objspace.std.util import IDTAG_SPECIAL, IDTAG_SHIFT
from pypy.objspace.std.formatting import mod_format, FORMAT_BYTES
from pypy.objspace.std.unicodeobject import (encode_object, getdefaultencoding,
           decode_object)

class W_AbstractBytesObject(W_Root):
    __slots__ = ()
    exact_class_applevel_name = 'bytes'

    def is_w(self, space, w_other):
        if not isinstance(w_other, W_AbstractBytesObject):
            return False
        if self is w_other:
            return True
        if self.user_overridden_class or w_other.user_overridden_class:
            return False
        s1 = space.bytes_w(self)
        s2 = space.bytes_w(w_other)
        if len(s2) > 1:
            return s1 is s2
        if len(s2) == 0:
            return len(s1) == 0
        else:            # strings of len <= 1 are unique-ified
            return len(s1) == 1 and s1[0] == s2[0]

    def immutable_unique_id(self, space):
        if self.user_overridden_class:
            return None
        s = space.bytes_w(self)
        if len(s) > 1:
            uid = compute_unique_id(s)
        else:            # strings of len <= 1 are unique-ified
            if len(s) == 1:
                base = ord(s[0])     # base values 0-255
            else:
                base = 256           # empty string: base value 256
            uid = (base << IDTAG_SHIFT) | IDTAG_SPECIAL
        return space.newint(uid)

    def descr_add(self, space, w_other):
        """x.__add__(y) <==> x+y"""

    def descr_contains(self, space, w_sub):
        """x.__contains__(y) <==> y in x"""

    def descr_eq(self, space, w_other):
        """x.__eq__(y) <==> x==y"""

    def descr_ge(self, space, w_other):
        """x.__ge__(y) <==> x>=y"""

    def descr_getitem(self, space, w_index):
        """x.__getitem__(y) <==> x[y]"""

    def descr_getnewargs(self, space):
        ""

    def descr_gt(self, space, w_other):
        """x.__gt__(y) <==> x>y"""

    def descr_hash(self, space):
        """x.__hash__() <==> hash(x)"""

    def descr_isascii(self, space):
        """B.isascii() -> bool

        Return true if the string is empty or all characters in the string are ASCII, false otherwise.
        ASCII characters have code points in the range U+0000-U+007F."""

    def descr_iter(self, space):
        """x.__iter__() <==> iter(x)"""

    def descr_le(self, space, w_other):
        """x.__le__(y) <==> x<=y"""

    def descr_len(self, space):
        """x.__len__() <==> len(x)"""

    def descr_lt(self, space, w_other):
        """x.__lt__(y) <==> x<y"""

    def descr_mul(self, space, w_times):
        """x.__mul__(n) <==> x*n"""

    def descr_ne(self, space, w_other):
        """x.__ne__(y) <==> x!=y"""

    def descr_repr(self, space):
        """x.__repr__() <==> repr(x)"""

    def descr_rmod(self, space, w_values):
        """x.__rmod__(y) <==> y%x"""

    def descr_rmul(self, space, w_times):
        """x.__rmul__(n) <==> n*x"""

    def descr_str(self, space):
        """x.__str__() <==> str(x)"""

    def descr_capitalize(self, space):
        """B.capitalize() -> copy of B

        Return a capitalized version of B, i.e. make the first character
        have upper case and the rest lower case.
        """

    @unwrap_spec(width=int, w_fillchar=WrappedDefault(' '))
    def descr_center(self, space, width, w_fillchar):
        """B.center(width[, fillchar]) -> copy of B

        Return B centered in a string of length width. Padding is
        done using the specified fill character (default is a space).
        """

    def descr_count(self, space, w_sub, w_start=None, w_end=None):
        """B.count(sub[, start[, end]]) -> int

        Return the number of non-overlapping occurrences of substring sub in
        string B[start:end].  Optional arguments start and end are interpreted
        as in slice notation.
        """

    def descr_decode(self, space, w_encoding=None, w_errors=None):
        """B.decode(encoding=None, errors='strict') -> object

        Decode B using the codec registered for encoding. encoding defaults
        to the default encoding. errors may be given to set a different error
        handling scheme. Default is 'strict' meaning that encoding errors raise
        a UnicodeDecodeError. Other possible values are 'ignore' and 'replace'
        as well as any other name registered with codecs.register_error that is
        able to handle UnicodeDecodeErrors.
        """

    def descr_endswith(self, space, w_suffix, w_start=None, w_end=None):
        """B.endswith(suffix[, start[, end]]) -> bool

        Return True if B ends with the specified suffix, False otherwise.
        With optional start, test B beginning at that position.
        With optional end, stop comparing B at that position.
        suffix can also be a tuple of bytes to try.
        """

    @unwrap_spec(tabsize=int)
    def descr_expandtabs(self, space, tabsize=8):
        """B.expandtabs([tabsize]) -> copy of B

        Return a copy of B where all tab characters are expanded using spaces.
        If tabsize is not given, a tab size of 8 characters is assumed.
        """

    def descr_find(self, space, w_sub, w_start=None, w_end=None):
        """B.find(sub[, start[, end]]) -> int

        Return the lowest index in B where substring sub is found,
        such that sub is contained within B[start:end].  Optional
        arguments start and end are interpreted as in slice notation.

        Return -1 on failure.
        """

    def descr_index(self, space, w_sub, w_start=None, w_end=None):
        """B.index(sub[, start[, end]]) -> int

        Like B.find() but raise ValueError when the substring is not found.
        """

    def descr_isalnum(self, space):
        """B.isalnum() -> bool

        Return True if all characters in B are alphanumeric
        and there is at least one character in B, False otherwise.
        """

    def descr_isalpha(self, space):
        """B.isalpha() -> bool

        Return True if all characters in B are alphabetic
        and there is at least one character in B, False otherwise.
        """

    def descr_isdigit(self, space):
        """B.isdigit() -> bool

        Return True if all characters in B are digits
        and there is at least one character in B, False otherwise.
        """

    def descr_islower(self, space):
        """B.islower() -> bool

        Return True if all cased characters in B are lowercase and there is
        at least one cased character in B, False otherwise.
        """

    def descr_isspace(self, space):
        """B.isspace() -> bool

        Return True if all characters in B are whitespace
        and there is at least one character in B, False otherwise.
        """

    def descr_istitle(self, space):
        """B.istitle() -> bool

        Return True if B is a titlecased string and there is at least one
        character in B, i.e. uppercase characters may only follow uncased
        characters and lowercase characters only cased ones. Return False
        otherwise.
        """

    def descr_isupper(self, space):
        """B.isupper() -> bool

        Return True if all cased characters in B are uppercase and there is
        at least one cased character in B, False otherwise.
        """

    def descr_join(self, space, w_list):
        """B.join(iterable) -> bytes

        Return a bytes object which is the concatenation of the bytes in the
        iterable.  The separator between elements is B.
        """

    @unwrap_spec(width=int, w_fillchar=WrappedDefault(' '))
    def descr_ljust(self, space, width, w_fillchar):
        """B.ljust(width[, fillchar]) -> copy of B

        Return B left-justified in a string of length width. Padding is
        done using the specified fill character (default is a space).
        """

    def descr_lower(self, space):
        """B.lower() -> copy of B

        Return a copy of the string B converted to lowercase.
        """

    def descr_lstrip(self, space, w_chars=None):
        """B.lstrip([chars]) -> copy of B

        Return a copy of the string B with leading whitespace removed.
        If chars is given and not None, remove characters in chars instead.
        """

    def descr_partition(self, space, w_sub):
        """B.partition(sep) -> (head, sep, tail)

        Search for the separator sep in B, and return the part before it,
        the separator itself, and the part after it.  If the separator is not
        found, return B and two empty bytes objects.
        """

    @unwrap_spec(count=int)
    def descr_replace(self, space, w_old, w_new, count=-1):
        """B.replace(old, new[, count]) -> copy of B

        Return a copy of string B with all occurrences of substring
        old replaced by new.  If the optional argument count is
        given, only the first count occurrences are replaced.
        """

    def descr_rfind(self, space, w_sub, w_start=None, w_end=None):
        """B.rfind(sub[, start[, end]]) -> int

        Return the highest index in B where substring sub is found,
        such that sub is contained within B[start:end].  Optional
        arguments start and end are interpreted as in slice notation.

        Return -1 on failure.
        """

    def descr_rindex(self, space, w_sub, w_start=None, w_end=None):
        """B.rindex(sub[, start[, end]]) -> int

        Like B.rfind() but raise ValueError when the substring is not found.
        """

    @unwrap_spec(width=int, w_fillchar=WrappedDefault(' '))
    def descr_rjust(self, space, width, w_fillchar):
        """B.rjust(width[, fillchar]) -> copy of B

        Return B right-justified in a string of length width. Padding is
        done using the specified fill character (default is a space).
        """

    def descr_rpartition(self, space, w_sub):
        """B.rpartition(sep) -> (head, sep, tail)

        Search for the separator sep in B, starting at the end of B, and return
        the part before it, the separator itself, and the part after it.  If
        the separator is not found, return two empty bytes objects and B.
        """

    @unwrap_spec(maxsplit=int)
    def descr_rsplit(self, space, w_sep=None, maxsplit=-1):
        """B.rsplit(sep=None, maxsplit=-1) -> list of bytes objects

        Return a list of the words in the string B, using sep as the
        delimiter string, starting at the end of the string and working
        to the front.  If maxsplit is given, at most maxsplit splits are
        done. If sep is not specified or is None, any whitespace string
        is a separator.
        """

    def descr_rstrip(self, space, w_chars=None):
        """B.rstrip([chars]) -> copy of B

        Return a copy of the string B with trailing whitespace removed.
        If chars is given and not None, remove characters in chars instead.
        """

    @unwrap_spec(maxsplit=int)
    def descr_split(self, space, w_sep=None, maxsplit=-1):
        """B.split(sep=None, maxsplit=-1) -> list of bytes objects

        Return a list of the words in the string B, using sep as the
        delimiter string.  If maxsplit is given, at most maxsplit
        splits are done. If sep is not specified or is None, any
        whitespace string is a separator and empty strings are removed
        from the result.
        """

    @unwrap_spec(keepends=bool)
    def descr_splitlines(self, space, keepends=False):
        """B.splitlines(keepends=False) -> list of bytes objects

        Return a list of the lines in B, breaking at line boundaries.
        Line breaks are not included in the resulting list unless keepends
        is given and true.
        """

    def descr_startswith(self, space, w_prefix, w_start=None, w_end=None):
        """B.startswith(prefix[, start[, end]]) -> bool

        Return True if B starts with the specified prefix, False otherwise.
        With optional start, test B beginning at that position.
        With optional end, stop comparing B at that position.
        prefix can also be a tuple of bytes to try.
        """

    def descr_strip(self, space, w_chars=None):
        """B.strip([chars]) -> copy of B

        Return a copy of the string B with leading and trailing
        whitespace removed.
        If chars is given and not None, remove characters in chars instead.
        """

    def descr_swapcase(self, space):
        """B.swapcase() -> copy of B

        Return a copy of the string B with uppercase characters
        converted to lowercase and vice versa.
        """

    def descr_title(self, space):
        """B.title() -> copy of B

        Return a titlecased version of B, i.e. words start with uppercase
        characters, all remaining cased characters have lowercase.
        """

    @unwrap_spec(w_delete=WrappedDefault(''))
    def descr_translate(self, space, w_table, w_delete):
        """B.translate(table[, deletechars]) -> copy of B

        Return a copy of the string B, where all characters occurring
        in the optional argument deletechars are removed, and the
        remaining characters have been mapped through the given
        translation table, which must be a string of length 256 or None.
        If the table argument is None, no translation is applied and
        the operation simply removes the characters in deletechars.
        """

    def descr_upper(self, space):
        """B.upper() -> copy of B

        Return a copy of the string B converted to uppercase.
        """

    @unwrap_spec(width=int)
    def descr_zfill(self, space, width):
        """B.zfill(width) -> copy of B

        Pad a numeric string B with zeros on the left, to fill a field
        of the specified width. The string B is never truncated.
        """

    def descr_mod(self, space, w_values):
        """B % values -> bytes

        Format bytes objects
        """

    def descr_removeprefix(self, space, w_prefix):
        """Return a str with the given prefix string removed if present.

        If the string starts with the prefix string, return string[len(prefix):].
        Otherwise, return a copy of the original string.
        """

    def descr_removesuffix(self, space, w_suffix):
        """Return a str with the given suffix string removed if present.

        If the string ends with the suffix string, return string[:len(suffix)].
        Otherwise, return a copy of the original string.
        """


class W_BytesObject(W_AbstractBytesObject):
    import_from_mixin(StringMethods)
    _immutable_fields_ = ['_value']
    _KIND1 = "byte"
    _KIND2 = "bytes"

    def __init__(self, s):
        assert s is not None
        self._value = s

    def __repr__(self):
        """representation for debugging purposes"""
        return "%s(%r)" % (self.__class__.__name__, self._value)

    def unwrap(self, space):
        return self._value

    def bytes_w(self, space):
        return self._value

    def realunicode_w(self, space):
        raise oefmt(space.w_TypeError,
                    "unicode object expected, received bytes instead")

    def text_w(self, space):
        return self._value

    def utf8_w(self, space):
        return self._value

    def utf8_w(self, space):
        return self._value

    def utf8_w(self, space):
        return self._value

    def buffer_w(self, space, flags):
        space.check_buf_flags(flags, True)
        return SimpleView(StringBuffer(self._value), w_obj=self)

    def descr_getbuffer(self, space, w_flags):
        #from pypy.objspace.std.bufferobject import W_Buffer
        #return W_Buffer(StringBuffer(self._value))
        return self

    def listview_int(self):
        return _create_list_from_bytes(self._value)

    def ord(self, space):
        if len(self._value) != 1:
            raise oefmt(space.w_TypeError,
                        "ord() expected a character, but bytes of length %d "
                        "found", len(self._value))
        return space.newint(ord(self._value[0]))

    def _new(self, value):
        return W_BytesObject(value)

    def _new_from_list(self, value):
        return W_BytesObject(''.join(value))

    def _empty(self):
        return W_BytesObject.EMPTY

    def _len(self):
        return len(self._value)

    _val = bytes_w

    @staticmethod
    def _use_rstr_ops(space, w_other):
        return True

    @staticmethod
    def _op_val(space, w_other, allow_char=False):
        # Some functions (contains, find) allow a number to specify a
        # single char.
        if allow_char and space.isinstance_w(w_other, space.w_int):
            return StringMethods._single_char(space, w_other)
        try:
            return space.bytes_w(w_other)
        except OperationError as e:
            if not e.match(space, space.w_TypeError):
                raise
        return space.buffer_w(w_other, space.BUF_SIMPLE).as_str()

    def _chr(self, char):
        assert len(char) == 1
        return str(char)[0]

    _builder = StringBuilder

    def _isupper(self, ch):
        return ch.isupper()

    def _islower(self, ch):
        return ch.islower()

    def _istitle(self, ch):
        return ch.isupper()

    def _isspace(self, ch):
        return ch.isspace()

    def _isalpha(self, ch):
        return ch.isalpha()

    def _isalnum(self, ch):
        return ch.isalnum()

    def _isdigit(self, ch):
        return ch.isdigit()

    _iscased = _isalpha

    def _islinebreak(self, ch):
        return (ch == '\n') or (ch == '\r')

    def _upper(self, ch):
        if ch.islower():
            o = ord(ch) - 32
            return chr(o)
        else:
            return ch

    def _lower(self, ch):
        if ch.isupper():
            o = ord(ch) + 32
            return chr(o)
        else:
            return ch

    _title = _upper

    def _newlist_unwrapped(self, space, lst):
        return space.newlist_bytes(lst)

    @staticmethod
    @unwrap_spec(encoding='text_or_none', errors='text_or_none')
    def descr_new(space, w_stringtype, w_source=None, encoding=None,
                  errors=None):
        if (w_source and space.is_w(w_stringtype, space.w_bytes)
                and encoding is None and errors is None):
            # special-case 'bytes(byte_object)'
            w_srctype = space.type(w_source)
            if w_srctype is space.w_bytes:
                return w_source
            # special-case 'bytes([single_integer])' or 'bytes((single_int,))'
            # for JITted performance only, when we clearly see the
            # length of the list/tuple being constant and equal to 1
            if w_srctype is space.w_list or w_srctype is space.w_tuple:
                length = space.len_w(w_source)
                if jit.isconstant(length) and length == 1:
                    w_item = space.getitem(w_source, space.newint(0))
                    value = space.byte_w(w_item)
                    return W_BytesObject(value)
            else:
                # special-case 'bytes(X)' if X has a __bytes__() method:
                # we must return the result unmodified even if it is a
                # subclass of bytes
                w_result = invoke_bytes_method(space, w_source)
                if w_result is not None:
                    return w_result
            value = newbytesdata_w_tail(space, w_source)
        else:
            value = newbytesdata_w(space, w_source, encoding, errors)
        w_obj = space.allocate_instance(W_BytesObject, w_stringtype)
        W_BytesObject.__init__(w_obj, value)
        return w_obj

    @staticmethod
    def descr_fromhex(space, w_type, w_hexstring):
        r"""bytes.fromhex(string) -> bytes

        Create a bytes object from a string of hexadecimal numbers.
        Spaces between two numbers are accepted.
        Example: bytes.fromhex('B9 01EF') -> b'\xb9\x01\xef'.
        """
        if not space.is_w(space.type(w_hexstring), space.w_unicode):
            raise oefmt(space.w_TypeError, "must be str, not %T", w_hexstring)
        from pypy.objspace.std.bytearrayobject import _hexstring_to_array
        hexstring = space.utf8_w(w_hexstring)
        bytes = ''.join(_hexstring_to_array(space, hexstring))
        w_result = W_BytesObject(bytes)
        if w_type is not space.w_bytes:
            w_result = space.call_function(w_type, w_result)
        return w_result

    def descr_repr(self, space):
        return space.newtext(string_escape_encode(self._value, True))

    def descr_str(self, space):
        if space.sys.get_flag('bytes_warning'):
            space.warn(space.newtext("str() on a bytes instance"),
                       space.w_BytesWarning)
        return self.descr_repr(space)

    def descr_hash(self, space):
        x = compute_hash(self._value)
        x -= (x == -1) # convert -1 to -2 without creating a bridge
        return space.newint(x)

    def descr_isascii(self, space):
        for i in self._value:
            if ord(i) > 127:
                return space.w_False
        return space.w_True

    def descr_eq(self, space, w_other):
        if not isinstance(w_other, W_BytesObject):
            return space.w_NotImplemented
        return space.newbool(self._value == w_other._value)

    def descr_ne(self, space, w_other):
        if not isinstance(w_other, W_BytesObject):
            return space.w_NotImplemented
        return space.newbool(self._value != w_other._value)

    def descr_lt(self, space, w_other):
        if not isinstance(w_other, W_BytesObject):
            return space.w_NotImplemented
        return space.newbool(self._value < w_other._value)

    def descr_le(self, space, w_other):
        if not isinstance(w_other, W_BytesObject):
            return space.w_NotImplemented
        return space.newbool(self._value <= w_other._value)

    def descr_gt(self, space, w_other):
        if not isinstance(w_other, W_BytesObject):
            return space.w_NotImplemented
        return space.newbool(self._value > w_other._value)

    def descr_ge(self, space, w_other):
        if not isinstance(w_other, W_BytesObject):
            return space.w_NotImplemented
        return space.newbool(self._value >= w_other._value)

    # auto-conversion fun

    @unwrap_spec(count=int)
    def descr_replace(self, space, w_old, w_new, count=-1):
        from rpython.rlib.rstring import replace
        # almost copy of StringMethods.descr_replace :-(
        input = self._value

        sub = self._op_val(space, w_old)
        by = self._op_val(space, w_new)
        try:
            res = replace(input, sub, by, count)
        except OverflowError:
            raise oefmt(space.w_OverflowError, "replace string is too long")
        # difference: reuse self if no replacement was done
        if type(self) is W_BytesObject and res is input:
            return self

        return self._new(res)

    _StringMethods_descr_join = descr_join
    def descr_join(self, space, w_list):
        l = space.listview_bytes(w_list)
        if l is not None:
            if len(l) == 1:
                return space.newbytes(l[0])
            return space.newbytes(self._val(space).join(l))
        return self._StringMethods_descr_join(space, w_list)

    def _join_return_one(self, space, w_obj):
        return space.is_w(space.type(w_obj), space.w_bytes)

    def descr_lower(self, space):
        return W_BytesObject(self._value.lower())

    def descr_upper(self, space):
        return W_BytesObject(self._value.upper())

    def descr_hex(self, space, w_sep=None, w_bytes_per_sep=None):
        """
        Create a str of hexadecimal numbers from a bytes object.

          sep
            An optional single character or byte to separate hex bytes.
          bytes_per_sep
            How many bytes between separators.  Positive values count from the
            right, negative values count from the left.

        Example:
        >>> value = b'\\xb9\\x01\\xef'
        >>> value.hex()
        'b901ef'
        >>> value.hex(':')
        'b9:01:ef'
        >>> value.hex(':', 2)
        'b9:01ef'
        >>> value.hex(':', -2)
        'b901:ef'
        """
        from pypy.objspace.std.bytearrayobject import _array_to_hexstring, unwrap_hex_sep_arguments
        sep, bytes_per_sep = unwrap_hex_sep_arguments(space, w_sep, w_bytes_per_sep)
        return _array_to_hexstring(space, StringBuffer(self._value), 0, 1,
                                   len(self._value), sep=sep, bytes_per_sep=bytes_per_sep)

    def descr_mod(self, space, w_values):
        return mod_format(space, self, w_values, fmt_type=FORMAT_BYTES)

    def descr_rmod(self, space, w_values):
        if not isinstance(w_values, W_AbstractBytesObject):
            return space.w_NotImplemented
        return mod_format(space, w_values, self, fmt_type=FORMAT_BYTES)

    @staticmethod
    def _iter_getitem_result(self, space, index):
        assert isinstance(self, W_BytesObject)
        return self._getitem_result(space, index)


def _create_list_from_bytes(value):
    # need this helper function to allow the jit to look inside and inline
    # listview_int
    return [ord(s) for s in value]

W_BytesObject.EMPTY = W_BytesObject('')


def invoke_bytes_method(space, w_source):
    w_bytes_method = space.lookup(w_source, "__bytes__")
    if w_bytes_method is not None:
        w_bytes = space.get_and_call_function(w_bytes_method, w_source)
        if not space.isinstance_w(w_bytes, space.w_bytes):
            raise oefmt(space.w_TypeError,
                        "__bytes__ returned non-bytes (type '%T')", w_bytes)
        return w_bytes
    return None

def newbytesdata_w(space, w_source, encoding, errors):
    # None value
    if w_source is None:
        if encoding is not None or errors is not None:
            raise oefmt(space.w_TypeError,
                "encoding or errors without sequence argument")
        else:
            return b""
    # Unicode with encoding
    if encoding is not None:
        if not space.isinstance_w(w_source, space.w_unicode):
            raise oefmt(space.w_TypeError,
                "encoding without string argument (got '%T' instead)",
                w_source)
        w_source = encode_object(space, w_source, encoding, errors)
        # and continue with the encoded string
    elif errors is not None:
        if not space.isinstance_w(w_source, space.w_unicode):
            raise oefmt(space.w_TypeError,
                "errors without string argument (got '%T' instead)",
                w_source)
        else:
            raise oefmt(space.w_TypeError,
                "string argument without an encoding")
    # Fast-path for bytes
    if space.type(w_source) is space.w_bytes:
        return space.bytes_w(w_source)
    # Some other object with a __bytes__ special method (could be str subclass)
    w_result = invoke_bytes_method(space, w_source)
    if w_result is not None:
        return space.bytes_w(w_result)

    return newbytesdata_w_tail(space, w_source)

def newbytesdata_w_tail(space, w_source):
    # converts rare case of bytes constructor arguments: we don't have
    # any encodings/errors, and the argument does not have __bytes__()
    if space.isinstance_w(w_source, space.w_unicode):
        raise oefmt(space.w_TypeError, "string argument without an encoding")

    # Is it an integer?
    # Note that we're calling space.getindex_w() instead of space.int_w().
    try:
        count = space.getindex_w(w_source, space.w_OverflowError)
    except OperationError as e:
        if not e.match(space, space.w_TypeError):
            raise
    else:
        if count < 0:
            raise oefmt(space.w_ValueError, "negative count")
        return '\0' * count

    return _convert_from_buffer_or_iterable(space, w_source)

def makebytesdata_w(space, w_source):
    w_bytes_method = space.lookup(w_source, "__bytes__")
    if w_bytes_method is not None:
        w_bytes = space.get_and_call_function(w_bytes_method, w_source)
        if not space.isinstance_w(w_bytes, space.w_bytes):
            raise oefmt(space.w_TypeError,
                        "__bytes__ returned non-bytes (type '%T')", w_bytes)
        return space.bytes_w(w_bytes)
    return _convert_from_buffer_or_iterable(space, w_source)

def _convert_from_buffer_or_iterable(space, w_source):
    # String-like argument
    try:
        buf = space.buffer_w(w_source, space.BUF_FULL_RO)
    except OperationError as e:
        if not e.match(space, space.w_TypeError):
            raise
    else:
        return buf.as_str()

    if space.isinstance_w(w_source, space.w_unicode):
        raise oefmt(space.w_TypeError,
                    "cannot convert a (unicode) str object to bytes")
    return _from_byte_sequence(space, w_source)


def _get_printable_location(w_type):
    return ('bytearray_from_byte_sequence [w_type=%s]' %
            w_type.getname(w_type.space))

_byteseq_jitdriver = jit.JitDriver(
    name='bytearray_from_byte_sequence',
    greens=['w_type'],
    reds=['w_iter', 'builder'],
    get_printable_location=_get_printable_location)

def _from_byte_sequence(space, w_source):
    # Split off in a separate function for the JIT's benefit
    # and add a jitdriver with the type of w_iter as the green key
    w_iter = space.iter(w_source)
    length_hint = space.length_hint(w_source, 0)
    builder = StringBuilder(length_hint)
    #
    _from_byte_sequence_loop(space, w_iter, builder)
    #
    return builder.build()

def _from_byte_sequence_loop(space, w_iter, builder):
    w_type = space.type(w_iter)
    while True:
        _byteseq_jitdriver.jit_merge_point(w_type=w_type,
                                           w_iter=w_iter,
                                           builder=builder)
        try:
            w_item = space.next(w_iter)
        except OperationError as e:
            if not e.match(space, space.w_StopIteration):
                raise
            break
        builder.append(space.byte_w(w_item))

W_BytesObject.typedef = TypeDef(
    "bytes", None, None, "read",
    __new__ = interp2app(W_BytesObject.descr_new),
    __doc__ = """bytes(iterable_of_ints) -> bytes
    bytes(string, encoding[, errors]) -> bytes
    bytes(bytes_or_buffer) -> immutable copy of bytes_or_buffer
    bytes(int) -> bytes object of size given by the parameter initialized with null bytes
    bytes() -> empty bytes object

    Construct an immutable array of bytes from:
      - an iterable yielding integers in range(256)
      - a text string encoded using the specified encoding
      - any object implementing the buffer API.
      - an integer
    """,

    __repr__ = interpindirect2app(W_AbstractBytesObject.descr_repr),
    __str__ = interpindirect2app(W_AbstractBytesObject.descr_str),
    __hash__ = interpindirect2app(W_AbstractBytesObject.descr_hash),

    __eq__ = interpindirect2app(W_AbstractBytesObject.descr_eq),
    __ne__ = interpindirect2app(W_AbstractBytesObject.descr_ne),
    __lt__ = interpindirect2app(W_AbstractBytesObject.descr_lt),
    __le__ = interpindirect2app(W_AbstractBytesObject.descr_le),
    __gt__ = interpindirect2app(W_AbstractBytesObject.descr_gt),
    __ge__ = interpindirect2app(W_AbstractBytesObject.descr_ge),

    __iter__ = interpindirect2app(W_AbstractBytesObject.descr_iter),
    __len__ = interpindirect2app(W_AbstractBytesObject.descr_len),
    __contains__ = interpindirect2app(W_AbstractBytesObject.descr_contains),

    __add__ = interpindirect2app(W_AbstractBytesObject.descr_add),
    __mul__ = interpindirect2app(W_AbstractBytesObject.descr_mul),
    __rmul__ = interpindirect2app(W_AbstractBytesObject.descr_rmul),

    __mod__ = interpindirect2app(W_AbstractBytesObject.descr_mod),
    __rmod__ = interpindirect2app(W_AbstractBytesObject.descr_rmod),

    __getitem__ = interpindirect2app(W_AbstractBytesObject.descr_getitem),

    capitalize = interpindirect2app(W_AbstractBytesObject.descr_capitalize),
    center = interpindirect2app(W_AbstractBytesObject.descr_center),
    count = interpindirect2app(W_AbstractBytesObject.descr_count),
    decode = interpindirect2app(W_AbstractBytesObject.descr_decode),
    expandtabs = interpindirect2app(W_AbstractBytesObject.descr_expandtabs),
    find = interpindirect2app(W_AbstractBytesObject.descr_find),
    rfind = interpindirect2app(W_AbstractBytesObject.descr_rfind),
    index = interpindirect2app(W_AbstractBytesObject.descr_index),
    rindex = interpindirect2app(W_AbstractBytesObject.descr_rindex),
    isalnum = interpindirect2app(W_AbstractBytesObject.descr_isalnum),
    isalpha = interpindirect2app(W_AbstractBytesObject.descr_isalpha),
    isdigit = interpindirect2app(W_AbstractBytesObject.descr_isdigit),
    islower = interpindirect2app(W_AbstractBytesObject.descr_islower),
    isspace = interpindirect2app(W_AbstractBytesObject.descr_isspace),
    istitle = interpindirect2app(W_AbstractBytesObject.descr_istitle),
    isupper = interpindirect2app(W_AbstractBytesObject.descr_isupper),
    isascii = interpindirect2app(W_AbstractBytesObject.descr_isascii),
    join = interpindirect2app(W_AbstractBytesObject.descr_join),
    ljust = interpindirect2app(W_AbstractBytesObject.descr_ljust),
    rjust = interpindirect2app(W_AbstractBytesObject.descr_rjust),
    lower = interpindirect2app(W_AbstractBytesObject.descr_lower),
    partition = interpindirect2app(W_AbstractBytesObject.descr_partition),
    rpartition = interpindirect2app(W_AbstractBytesObject.descr_rpartition),
    replace = interpindirect2app(W_AbstractBytesObject.descr_replace),
    split = interpindirect2app(W_AbstractBytesObject.descr_split),
    rsplit = interpindirect2app(W_AbstractBytesObject.descr_rsplit),
    splitlines = interpindirect2app(W_AbstractBytesObject.descr_splitlines),
    startswith = interpindirect2app(W_AbstractBytesObject.descr_startswith),
    endswith = interpindirect2app(W_AbstractBytesObject.descr_endswith),
    strip = interpindirect2app(W_AbstractBytesObject.descr_strip),
    lstrip = interpindirect2app(W_AbstractBytesObject.descr_lstrip),
    rstrip = interpindirect2app(W_AbstractBytesObject.descr_rstrip),
    swapcase = interpindirect2app(W_AbstractBytesObject.descr_swapcase),
    title = interpindirect2app(W_AbstractBytesObject.descr_title),
    translate = interpindirect2app(W_AbstractBytesObject.descr_translate),
    upper = interpindirect2app(W_AbstractBytesObject.descr_upper),
    zfill = interpindirect2app(W_AbstractBytesObject.descr_zfill),

    removeprefix = interpindirect2app(W_AbstractBytesObject.descr_removeprefix),
    removesuffix = interpindirect2app(W_AbstractBytesObject.descr_removesuffix),

    __getnewargs__ = interpindirect2app(
        W_AbstractBytesObject.descr_getnewargs),

    fromhex = interp2app(W_BytesObject.descr_fromhex, as_classmethod=True),
    maketrans = interp2app(W_BytesObject.descr_maketrans, as_classmethod=True),
    hex = interp2app(W_BytesObject.descr_hex),
)
W_BytesObject.typedef.flag_sequence_bug_compat = True


@jit.elidable
def string_escape_encode(s, quotes):
    buf = StringBuilder(len(s) + 2)

    quote = "'"
    if quotes:
        if quote in s and '"' not in s:
            quote = '"'
            buf.append('b"')
        else:
            buf.append("b'")

    startslice = 0

    for i in range(len(s)):
        c = s[i]
        use_bs_char = False # character quoted by backspace

        if c == '\\' or c == quote:
            bs_char = c
            use_bs_char = True
        elif c == '\t':
            bs_char = 't'
            use_bs_char = True
        elif c == '\r':
            bs_char = 'r'
            use_bs_char = True
        elif c == '\n':
            bs_char = 'n'
            use_bs_char = True
        elif not '\x20' <= c < '\x7f':
            n = ord(c)
            if i != startslice:
                buf.append_slice(s, startslice, i)
            startslice = i + 1
            buf.append('\\x')
            buf.append("0123456789abcdef"[n >> 4])
            buf.append("0123456789abcdef"[n & 0xF])

        if use_bs_char:
            if i != startslice:
                buf.append_slice(s, startslice, i)
            startslice = i + 1
            buf.append('\\')
            buf.append(bs_char)

    if len(s) != startslice:
        buf.append_slice(s, startslice, len(s))

    if quotes:
        buf.append(quote)

    return buf.build()
