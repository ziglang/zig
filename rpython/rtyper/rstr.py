from rpython.annotator import model as annmodel
from rpython.rlib import jit
from rpython.rtyper import rint
from rpython.rtyper.error import TyperError
from rpython.rtyper.lltypesystem.lltype import Signed, Bool, Void, UniChar
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.rmodel import IteratorRepr, inputconst, Repr
from rpython.rtyper.rint import IntegerRepr
from rpython.rtyper.rfloat import FloatRepr
from rpython.tool.pairtype import pairtype, pair

def str_decode_utf8(s):
    from rpython.rlib.rstring import UnicodeBuilder
    from rpython.rlib import runicode

    size = len(s)
    if size == 0:
        return u''

    result = UnicodeBuilder(size)
    pos = 0
    while pos < size:
        ordch1 = ord(s[pos])
        # fast path for ASCII
        # XXX maybe use a while loop here
        if ordch1 < 0x80:
            result.append(unichr(ordch1))
            pos += 1
            continue

        n = ord(runicode._utf8_code_length[ordch1 - 0x80])
        if pos + n > size:
            raise UnicodeDecodeError('utf8', s, pos, pos + 1,
                                      'whatever')
        if n == 0:
            raise UnicodeDecodeError('utf8', s, pos, pos + 1,
                                     'whatever')
        elif n == 1:
            assert 0, "ascii should have gone through the fast path"

        elif n == 2:
            ordch2 = ord(s[pos+1])
            if runicode._invalid_byte_2_of_2(ordch2):

                raise UnicodeDecodeError('utf8', s, pos, pos + 1,
                                         'whatever')
            # 110yyyyy 10zzzzzz -> 00000000 00000yyy yyzzzzzz
            result.append(unichr(((ordch1 & 0x1F) << 6) +    # 0b00011111
                                 (ordch2 & 0x3F)))           # 0b00111111
            pos += 2

        elif n == 3:
            ordch2 = ord(s[pos+1])
            ordch3 = ord(s[pos+2])
            if (runicode._invalid_byte_2_of_3(ordch1, ordch2, True) or
                runicode._invalid_byte_3_of_3(ordch3)):
                raise UnicodeDecodeError('utf8', s, pos, pos + 1,
                                         'whatever')
            # 1110xxxx 10yyyyyy 10zzzzzz -> 00000000 xxxxyyyy yyzzzzzz
            result.append(unichr(((ordch1 & 0x0F) << 12) +     # 0b00001111
                                 ((ordch2 & 0x3F) << 6) +      # 0b00111111
                                 (ordch3 & 0x3F)))             # 0b00111111
            pos += 3

        elif n == 4:
            ordch2 = ord(s[pos+1])
            ordch3 = ord(s[pos+2])
            ordch4 = ord(s[pos+3])
            if (runicode._invalid_byte_2_of_4(ordch1, ordch2) or
                runicode._invalid_byte_3_of_4(ordch3) or
                runicode._invalid_byte_4_of_4(ordch4)):

                raise UnicodeDecodeError('utf8', s, pos, pos + 1,
                                         'whatever')
            # 11110www 10xxxxxx 10yyyyyy 10zzzzzz -> 000wwwxx xxxxyyyy yyzzzzzz
            c = (((ordch1 & 0x07) << 18) +      # 0b00000111
                 ((ordch2 & 0x3F) << 12) +      # 0b00111111
                 ((ordch3 & 0x3F) << 6) +       # 0b00111111
                 (ordch4 & 0x3F))               # 0b00111111
            if c <= runicode.MAXUNICODE:
                result.append(runicode.UNICHR(c))
            else:
                # compute and append the two surrogates:
                # translate from 10000..10FFFF to 0..FFFF
                c -= 0x10000
                # high surrogate = top 10 bits added to D800
                result.append(unichr(0xD800 + (c >> 10)))
                # low surrogate = bottom 10 bits added to DC00
                result.append(unichr(0xDC00 + (c & 0x03FF)))
            pos += 4

    return result.build()


class AbstractStringRepr(Repr):

    @jit.elidable
    def ll_decode_utf8(self, llvalue):
        from rpython.rtyper.annlowlevel import hlstr
        value = hlstr(llvalue)
        assert value is not None
        # NB. keep the arguments in sync with annotator/unaryop.py
        u = str_decode_utf8(value)
        # XXX maybe the whole ''.decode('utf-8') should be not RPython.
        return self.ll.llunicode(u)

    def _str_reprs(self, hop):
        return hop.args_r[0].repr, hop.args_r[1].repr

    def get_ll_eq_function(self):
        return self.ll.ll_streq

    def get_ll_hash_function(self):
        return self.ll.ll_strhash

    def get_ll_fasthash_function(self):
        return self.ll.ll_strfasthash

    def rtype_len(self, hop):
        string_repr = self.repr
        v_str, = hop.inputargs(string_repr)
        return hop.gendirectcall(self.ll.ll_strlen, v_str)

    def rtype_bool(self, hop):
        s_str = hop.args_s[0]
        if s_str.can_be_None:
            string_repr = hop.args_r[0].repr
            v_str, = hop.inputargs(string_repr)
            return hop.gendirectcall(self.ll.ll_str_is_true, v_str)
        else:
            # defaults to checking the length
            return super(AbstractStringRepr, self).rtype_bool(hop)

    def rtype_method_startswith(self, hop):
        str1_repr = hop.args_r[0].repr
        str2_repr = hop.args_r[1]
        v_str = hop.inputarg(str1_repr, arg=0)
        if str2_repr == str2_repr.char_repr:
            v_value = hop.inputarg(str2_repr.char_repr, arg=1)
            fn = self.ll.ll_startswith_char
        else:
            v_value = hop.inputarg(str2_repr, arg=1)
            fn = self.ll.ll_startswith
        hop.exception_cannot_occur()
        return hop.gendirectcall(fn, v_str, v_value)

    def rtype_method_endswith(self, hop):
        str1_repr = hop.args_r[0].repr
        str2_repr = hop.args_r[1]
        v_str = hop.inputarg(str1_repr, arg=0)
        if str2_repr == str2_repr.char_repr:
            v_value = hop.inputarg(str2_repr.char_repr, arg=1)
            fn = self.ll.ll_endswith_char
        else:
            v_value = hop.inputarg(str2_repr, arg=1)
            fn = self.ll.ll_endswith
        hop.exception_cannot_occur()
        return hop.gendirectcall(fn, v_str, v_value)

    def rtype_method_find(self, hop, reverse=False):
        # XXX binaryop
        string_repr = hop.args_r[0].repr
        char_repr = hop.args_r[0].char_repr
        v_str = hop.inputarg(string_repr, arg=0)
        if hop.args_r[1] == char_repr:
            v_value = hop.inputarg(char_repr, arg=1)
            llfn = reverse and self.ll.ll_rfind_char or self.ll.ll_find_char
        else:
            v_value = hop.inputarg(string_repr, arg=1)
            llfn = reverse and self.ll.ll_rfind or self.ll.ll_find
        if hop.nb_args > 2:
            v_start = hop.inputarg(Signed, arg=2)
            if not hop.args_s[2].nonneg:
                raise TyperError("str.%s() start must be proven non-negative"
                                 % (reverse and 'rfind' or 'find',))
        else:
            v_start = hop.inputconst(Signed, 0)
        if hop.nb_args > 3:
            v_end = hop.inputarg(Signed, arg=3)
            if not hop.args_s[3].nonneg:
                raise TyperError("str.%s() end must be proven non-negative"
                                 % (reverse and 'rfind' or 'find',))
        else:
            v_end = hop.gendirectcall(self.ll.ll_strlen, v_str)
        hop.exception_cannot_occur()
        return hop.gendirectcall(llfn, v_str, v_value, v_start, v_end)

    def rtype_method_rfind(self, hop):
        return self.rtype_method_find(hop, reverse=True)

    def rtype_method_count(self, hop):
        rstr = hop.args_r[0].repr
        v_str = hop.inputarg(rstr.repr, arg=0)
        if hop.args_r[1] == rstr.char_repr:
            v_value = hop.inputarg(rstr.char_repr, arg=1)
            llfn = self.ll.ll_count_char
        else:
            v_value = hop.inputarg(rstr.repr, arg=1)
            llfn = self.ll.ll_count
        if hop.nb_args > 2:
            v_start = hop.inputarg(Signed, arg=2)
            if not hop.args_s[2].nonneg:
                raise TyperError("str.count() start must be proven non-negative")
        else:
            v_start = hop.inputconst(Signed, 0)
        if hop.nb_args > 3:
            v_end = hop.inputarg(Signed, arg=3)
            if not hop.args_s[3].nonneg:
                raise TyperError("str.count() end must be proven non-negative")
        else:
            v_end = hop.gendirectcall(self.ll.ll_strlen, v_str)
        hop.exception_cannot_occur()
        return hop.gendirectcall(llfn, v_str, v_value, v_start, v_end)

    def rtype_method_strip(self, hop, left=True, right=True):
        rstr = hop.args_r[0].repr
        v_str = hop.inputarg(rstr.repr, arg=0)
        args_v = [v_str]
        if len(hop.args_s) == 2:
            if isinstance(hop.args_s[1], annmodel.SomeString):
                v_stripstr = hop.inputarg(rstr.repr, arg=1)
                args_v.append(v_stripstr)
                func = self.ll.ll_strip_multiple
            else:
                v_char = hop.inputarg(rstr.char_repr, arg=1)
                args_v.append(v_char)
                func = self.ll.ll_strip
        else:
            func = self.ll.ll_strip_default
        args_v.append(hop.inputconst(Bool, left))
        args_v.append(hop.inputconst(Bool, right))
        hop.exception_is_here()
        return hop.gendirectcall(func, *args_v)

    def rtype_method_lstrip(self, hop):
        return self.rtype_method_strip(hop, left=True, right=False)

    def rtype_method_rstrip(self, hop):
        return self.rtype_method_strip(hop, left=False, right=True)

    def rtype_method_upper(self, hop):
        string_repr = hop.args_r[0].repr
        v_str, = hop.inputargs(string_repr)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll.ll_upper, v_str)

    def rtype_method_lower(self, hop):
        string_repr = hop.args_r[0].repr
        v_str, = hop.inputargs(string_repr)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll.ll_lower, v_str)

    def rtype_method_isdigit(self, hop):
        string_repr = hop.args_r[0].repr
        [v_str] = hop.inputargs(string_repr)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll.ll_isdigit, v_str)

    def rtype_method_isalpha(self, hop):
        string_repr = hop.args_r[0].repr
        [v_str] = hop.inputargs(string_repr)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll.ll_isalpha, v_str)

    def rtype_method_isalnum(self, hop):
        string_repr = hop.args_r[0].repr
        [v_str] = hop.inputargs(string_repr)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll.ll_isalnum, v_str)

    def _list_length_items(self, hop, v_lst, LIST):
        """Return two Variables containing the length and items of a
        list. Need to be overriden because it is typesystem-specific."""
        raise NotImplementedError

    def rtype_method_join(self, hop):
        from rpython.rtyper.lltypesystem.rlist import BaseListRepr
        from rpython.rtyper.lltypesystem.rstr import char_repr, unichar_repr
        hop.exception_cannot_occur()
        rstr = hop.args_r[0]
        if hop.s_result.is_constant():
            return inputconst(rstr.repr, hop.s_result.const)
        r_lst = hop.args_r[1]
        if not isinstance(r_lst, BaseListRepr):
            raise TyperError("string.join of non-list: %r" % r_lst)
        v_str, v_lst = hop.inputargs(rstr.repr, r_lst)
        v_length, v_items = self._list_length_items(hop, v_lst, r_lst.lowleveltype)

        if hop.args_s[0].is_constant() and hop.args_s[0].const == '':
            if r_lst.item_repr == rstr.repr:
                llfn = self.ll.ll_join_strs
            elif (r_lst.item_repr == char_repr or
                  r_lst.item_repr == unichar_repr):
                v_tp = hop.inputconst(Void, self.lowleveltype)
                return hop.gendirectcall(self.ll.ll_join_chars, v_length,
                                         v_items, v_tp)
            else:
                raise TyperError("''.join() of non-string list: %r" % r_lst)
            return hop.gendirectcall(llfn, v_length, v_items)
        else:
            if r_lst.item_repr == rstr.repr:
                llfn = self.ll.ll_join
            else:
                raise TyperError("sep.join() of non-string list: %r" % r_lst)
            return hop.gendirectcall(llfn, v_str, v_length, v_items)

    def rtype_method_splitlines(self, hop):
        rstr = hop.args_r[0].repr
        if hop.nb_args == 2:
            args = hop.inputargs(rstr.repr, Bool)
        else:
            args = [hop.inputarg(rstr.repr, 0), hop.inputconst(Bool, False)]
        try:
            list_type = hop.r_result.lowleveltype.TO
        except AttributeError:
            list_type = hop.r_result.lowleveltype
        cLIST = hop.inputconst(Void, list_type)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll.ll_splitlines, cLIST, *args)

    def rtype_method_split(self, hop):
        rstr = hop.args_r[0].repr
        v_str = hop.inputarg(rstr.repr, 0)
        if isinstance(hop.args_s[1], annmodel.SomeString):
            v_chr = hop.inputarg(rstr.repr, 1)
            fn = self.ll.ll_split
        else:
            v_chr = hop.inputarg(rstr.char_repr, 1)
            fn = self.ll.ll_split_chr
        if hop.nb_args == 3:
            v_max = hop.inputarg(Signed, 2)
        else:
            v_max = hop.inputconst(Signed, -1)
        try:
            list_type = hop.r_result.lowleveltype.TO
        except AttributeError:
            list_type = hop.r_result.lowleveltype
        cLIST = hop.inputconst(Void, list_type)
        hop.exception_cannot_occur()
        return hop.gendirectcall(fn, cLIST, v_str, v_chr, v_max)

    def rtype_method_rsplit(self, hop):
        rstr = hop.args_r[0].repr
        v_str = hop.inputarg(rstr.repr, 0)
        if isinstance(hop.args_s[1], annmodel.SomeString):
            v_chr = hop.inputarg(rstr.repr, 1)
            fn = self.ll.ll_rsplit
        else:
            v_chr = hop.inputarg(rstr.char_repr, 1)
            fn = self.ll.ll_rsplit_chr
        if hop.nb_args == 3:
            v_max = hop.inputarg(Signed, 2)
        else:
            v_max = hop.inputconst(Signed, -1)
        try:
            list_type = hop.r_result.lowleveltype.TO
        except AttributeError:
            list_type = hop.r_result.lowleveltype
        cLIST = hop.inputconst(Void, list_type)
        hop.exception_cannot_occur()
        return hop.gendirectcall(fn, cLIST, v_str, v_chr, v_max)

    def rtype_method_replace(self, hop):
        rstr = hop.args_r[0].repr
        if not (hop.args_r[1] == rstr.char_repr and hop.args_r[2] == rstr.char_repr):
            raise TyperError('replace only works for char args')
        v_str, v_c1, v_c2 = hop.inputargs(rstr.repr, rstr.char_repr, rstr.char_repr)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll.ll_replace_chr_chr, v_str, v_c1, v_c2)

    def rtype_int(self, hop):
        hop.has_implicit_exception(ValueError)   # record that we know about it
        string_repr = hop.args_r[0].repr
        if hop.nb_args == 1:
            v_str, = hop.inputargs(string_repr)
            c_base = inputconst(Signed, 10)
            hop.exception_is_here()
            return hop.gendirectcall(self.ll.ll_int, v_str, c_base)
        if not hop.args_r[1] == rint.signed_repr:
            raise TyperError('base needs to be an int')
        v_str, v_base = hop.inputargs(string_repr, rint.signed_repr)
        hop.exception_is_here()
        return hop.gendirectcall(self.ll.ll_int, v_str, v_base)

    def rtype_unicode(self, hop):
        if hop.args_s[0].is_constant():
            # convertion errors occur during annotation, so cannot any more:
            hop.exception_cannot_occur()
            return hop.inputconst(hop.r_result, hop.s_result.const)
        repr = hop.args_r[0].repr
        v_str = hop.inputarg(repr, 0)
        if repr == hop.r_result:  # the argument is a unicode string already
            hop.exception_cannot_occur()
            return v_str
        hop.exception_is_here()
        return hop.gendirectcall(self.ll.ll_str2unicode, v_str)

    def rtype_bytearray(self, hop):
        hop.exception_is_here()
        return hop.gendirectcall(self.ll.ll_str2bytearray,
                                 hop.inputarg(hop.args_r[0].repr, 0))

    def rtype_method_decode(self, hop):
        if not hop.args_s[1].is_constant():
            raise TyperError("encoding must be a constant")
        encoding = hop.args_s[1].const
        v_self = hop.inputarg(self.repr, 0)
        hop.exception_is_here()
        if encoding == 'ascii':
            return hop.gendirectcall(self.ll.ll_str2unicode, v_self)
        elif encoding == 'latin-1':
            return hop.gendirectcall(self.ll_decode_latin1, v_self)
        elif encoding == 'utf-8' or encoding == 'utf8':
            return hop.gendirectcall(self.ll_decode_utf8, v_self)
        else:
            raise TyperError("encoding %s not implemented" % (encoding, ))

    def rtype_float(self, hop):
        hop.has_implicit_exception(ValueError)   # record that we know about it
        string_repr = hop.args_r[0].repr
        v_str, = hop.inputargs(string_repr)
        hop.exception_is_here()
        return hop.gendirectcall(self.ll.ll_float, v_str)

    def ll_str(self, s):
        if s:
            return s
        else:
            return self.ll.ll_constant('None')

    def rtype_getslice(r_str, hop):
        string_repr = r_str.repr
        v_str = hop.inputarg(string_repr, arg=0)
        kind, vlist = hop.decompose_slice_args()
        ll_fn = getattr(r_str.ll, 'll_stringslice_%s' % (kind,))
        return hop.gendirectcall(ll_fn, v_str, *vlist)

    def rtype_bltn_list(self, hop):
        string_repr = hop.args_r[0].repr
        if hop.r_result.LIST.ITEM != string_repr.lowleveltype.TO.chars.OF:
            raise TyperError("list(str-or-unicode) returns a list of chars; "
                             "it cannot return a list of %r" % (
                                 hop.r_result.LIST.ITEM,))
        v_str, = hop.inputargs(string_repr)
        cRESLIST = hop.inputconst(Void, hop.r_result.LIST)
        hop.exception_is_here()
        return hop.gendirectcall(self.ll.ll_string2list, cRESLIST, v_str)


class AbstractUnicodeRepr(AbstractStringRepr):

    def rtype_method_upper(self, hop):
        raise TyperError("Cannot do toupper on unicode string")

    def rtype_method_lower(self, hop):
        raise TyperError("Cannot do tolower on unicode string")

    @jit.elidable
    def ll_encode_utf8(self, ll_s):
        from rpython.rtyper.annlowlevel import hlunicode
        from rpython.rlib import runicode
        s = hlunicode(ll_s)
        assert s is not None
        errorhandler = runicode.default_unicode_error_encode
        # NB. keep the arguments in sync with annotator/unaryop.py
        bytes = runicode.unicode_encode_utf_8_elidable(
            s, len(s), 'strict', errorhandler, True)
        return self.ll.llstr(bytes)

    def rtype_method_encode(self, hop):
        if not hop.args_s[1].is_constant():
            raise TyperError("encoding must be constant")
        encoding = hop.args_s[1].const
        if encoding == "ascii" and self.lowleveltype == UniChar:
            expect = UniChar             # only for unichar.encode('ascii')
        else:
            expect = self.repr           # must be a regular unicode string
        v_self = hop.inputarg(expect, 0)
        hop.exception_is_here()
        if encoding == "ascii":
            return hop.gendirectcall(self.ll_str, v_self)
        elif encoding == "latin-1":
            return hop.gendirectcall(self.ll_encode_latin1, v_self)
        elif encoding == 'utf-8' or encoding == 'utf8':
            return hop.gendirectcall(self.ll_encode_utf8, v_self)
        else:
            raise TyperError("encoding %s not implemented" % (encoding, ))

class BaseCharReprMixin(object):

    def convert_const(self, value):
        if not isinstance(value, str) or len(value) != 1:
            raise TyperError("not a character: %r" % (value,))
        return value

    def get_ll_eq_function(self):
        return None

    def get_ll_hash_function(self):
        return self.ll.ll_char_hash

    get_ll_fasthash_function = get_ll_hash_function

    def rtype_len(_, hop):
        return hop.inputconst(Signed, 1)

    def rtype_bool(_, hop):
        assert not hop.args_s[0].can_be_None
        return hop.inputconst(Bool, True)

    def rtype_ord(_, hop):
        repr = hop.args_r[0].char_repr
        vlist = hop.inputargs(repr)
        return hop.genop('cast_char_to_int', vlist, resulttype=Signed)

    def _rtype_method_isxxx(_, llfn, hop):
        repr = hop.args_r[0].char_repr
        vlist = hop.inputargs(repr)
        hop.exception_cannot_occur()
        return hop.gendirectcall(llfn, vlist[0])

    def rtype_method_isspace(self, hop):
        return self._rtype_method_isxxx(self.ll.ll_char_isspace, hop)

    def rtype_method_isdigit(self, hop):
        return self._rtype_method_isxxx(self.ll.ll_char_isdigit, hop)

    def rtype_method_isalpha(self, hop):
        return self._rtype_method_isxxx(self.ll.ll_char_isalpha, hop)

    def rtype_method_isalnum(self, hop):
        return self._rtype_method_isxxx(self.ll.ll_char_isalnum, hop)

    def rtype_method_isupper(self, hop):
        return self._rtype_method_isxxx(self.ll.ll_char_isupper, hop)

    def rtype_method_islower(self, hop):
        return self._rtype_method_isxxx(self.ll.ll_char_islower, hop)


class AbstractCharRepr(BaseCharReprMixin, AbstractStringRepr):
    def rtype_method_lower(self, hop):
        char_repr = hop.args_r[0].char_repr
        v_chr, = hop.inputargs(char_repr)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll.ll_lower_char, v_chr)

    def rtype_method_upper(self, hop):
        char_repr = hop.args_r[0].char_repr
        v_chr, = hop.inputargs(char_repr)
        hop.exception_cannot_occur()
        return hop.gendirectcall(self.ll.ll_upper_char, v_chr)

    def ll_str(self, ch):
        return self.ll.ll_chr2str(ch)


class AbstractUniCharRepr(BaseCharReprMixin, AbstractStringRepr):

    def ll_str(self, ch):
        # xxx suboptimal, maybe
        return str(unicode(ch))

    def ll_unicode(self, ch):
        return unicode(ch)


class __extend__(annmodel.SomeString):
    def rtyper_makerepr(self, rtyper):
        from rpython.rtyper.lltypesystem.rstr import string_repr
        return string_repr

    def rtyper_makekey(self):
        return self.__class__,

class __extend__(annmodel.SomeUnicodeString):
    def rtyper_makerepr(self, rtyper):
        from rpython.rtyper.lltypesystem.rstr import unicode_repr
        return unicode_repr

    def rtyper_makekey(self):
        return self.__class__,

class __extend__(annmodel.SomeChar):
    def rtyper_makerepr(self, rtyper):
        from rpython.rtyper.lltypesystem.rstr import char_repr
        return char_repr

    def rtyper_makekey(self):
        return self.__class__,

class __extend__(annmodel.SomeUnicodeCodePoint):
    def rtyper_makerepr(self, rtyper):
        from rpython.rtyper.lltypesystem.rstr import unichar_repr
        return unichar_repr

    def rtyper_makekey(self):
        return self.__class__,


class __extend__(pairtype(AbstractStringRepr, Repr)):
    def rtype_mod((r_str, _), hop):
        # for the case where the 2nd argument is a tuple, see the
        # overriding rtype_mod() below
        return r_str.ll.do_stringformat(hop, [(hop.args_v[1], hop.args_r[1])])


class __extend__(pairtype(AbstractStringRepr, FloatRepr)):
    def rtype_mod(_, hop):
        from rpython.rtyper.lltypesystem.rstr import do_stringformat
        return do_stringformat(hop, [(hop.args_v[1], hop.args_r[1])])


class __extend__(pairtype(AbstractStringRepr, IntegerRepr)):
    def rtype_getitem((r_str, r_int), hop, checkidx=False):
        string_repr = r_str.repr
        v_str, v_index = hop.inputargs(string_repr, Signed)
        if checkidx:
            if hop.args_s[1].nonneg:
                llfn = r_str.ll.ll_stritem_nonneg_checked
            else:
                llfn = r_str.ll.ll_stritem_checked
        else:
            if hop.args_s[1].nonneg:
                llfn = r_str.ll.ll_stritem_nonneg
            else:
                llfn = r_str.ll.ll_stritem
        if checkidx:
            hop.exception_is_here()
        else:
            hop.exception_cannot_occur()
        return hop.gendirectcall(llfn, v_str, v_index)

    def rtype_getitem_idx((r_str, r_int), hop):
        return pair(r_str, r_int).rtype_getitem(hop, checkidx=True)

    def rtype_mul((r_str, r_int), hop):
        str_repr = r_str.repr
        v_str, v_int = hop.inputargs(str_repr, Signed)
        return hop.gendirectcall(r_str.ll.ll_str_mul, v_str, v_int)
    rtype_inplace_mul = rtype_mul

class __extend__(pairtype(IntegerRepr, AbstractStringRepr)):
    def rtype_mul((r_int, r_str), hop):
        str_repr = r_str.repr
        v_int, v_str = hop.inputargs(Signed, str_repr)
        return hop.gendirectcall(r_str.ll.ll_str_mul, v_str, v_int)
    rtype_inplace_mul = rtype_mul


class __extend__(pairtype(AbstractStringRepr, AbstractStringRepr)):
    def rtype_add((r_str1, r_str2), hop):
        str1_repr = r_str1.repr
        str2_repr = r_str2.repr
        if hop.s_result.is_constant():
            return hop.inputconst(str1_repr, hop.s_result.const)
        v_str1, v_str2 = hop.inputargs(str1_repr, str2_repr)
        return hop.gendirectcall(r_str1.ll.ll_strconcat, v_str1, v_str2)
    rtype_inplace_add = rtype_add

    def rtype_eq((r_str1, r_str2), hop):
        v_str1, v_str2 = hop.inputargs(r_str1.repr, r_str2.repr)
        return hop.gendirectcall(r_str1.ll.ll_streq, v_str1, v_str2)

    def rtype_ne((r_str1, r_str2), hop):
        v_str1, v_str2 = hop.inputargs(r_str1.repr, r_str2.repr)
        vres = hop.gendirectcall(r_str1.ll.ll_streq, v_str1, v_str2)
        return hop.genop('bool_not', [vres], resulttype=Bool)

    def rtype_lt((r_str1, r_str2), hop):
        v_str1, v_str2 = hop.inputargs(r_str1.repr, r_str2.repr)
        vres = hop.gendirectcall(r_str1.ll.ll_strcmp, v_str1, v_str2)
        return hop.genop('int_lt', [vres, hop.inputconst(Signed, 0)],
                         resulttype=Bool)

    def rtype_le((r_str1, r_str2), hop):
        v_str1, v_str2 = hop.inputargs(r_str1.repr, r_str2.repr)
        vres = hop.gendirectcall(r_str1.ll.ll_strcmp, v_str1, v_str2)
        return hop.genop('int_le', [vres, hop.inputconst(Signed, 0)],
                         resulttype=Bool)

    def rtype_ge((r_str1, r_str2), hop):
        v_str1, v_str2 = hop.inputargs(r_str1.repr, r_str2.repr)
        vres = hop.gendirectcall(r_str1.ll.ll_strcmp, v_str1, v_str2)
        return hop.genop('int_ge', [vres, hop.inputconst(Signed, 0)],
                         resulttype=Bool)

    def rtype_gt((r_str1, r_str2), hop):
        v_str1, v_str2 = hop.inputargs(r_str1.repr, r_str2.repr)
        vres = hop.gendirectcall(r_str1.ll.ll_strcmp, v_str1, v_str2)
        return hop.genop('int_gt', [vres, hop.inputconst(Signed, 0)],
                         resulttype=Bool)

    def rtype_contains((r_str1, r_str2), hop):
        v_str1, v_str2 = hop.inputargs(r_str1.repr, r_str2.repr)
        v_end = hop.gendirectcall(r_str1.ll.ll_strlen, v_str1)
        vres = hop.gendirectcall(r_str1.ll.ll_find, v_str1, v_str2,
                                 hop.inputconst(Signed, 0), v_end)
        hop.exception_cannot_occur()
        return hop.genop('int_ne', [vres, hop.inputconst(Signed, -1)],
                         resulttype=Bool)


class __extend__(pairtype(AbstractStringRepr, AbstractCharRepr),
                 pairtype(AbstractUnicodeRepr, AbstractUniCharRepr)):
    def rtype_contains((r_str, r_chr), hop):
        string_repr = r_str.repr
        char_repr = r_chr.char_repr
        v_str, v_chr = hop.inputargs(string_repr, char_repr)
        hop.exception_cannot_occur()
        return hop.gendirectcall(r_str.ll.ll_contains, v_str, v_chr)


class __extend__(pairtype(AbstractCharRepr, IntegerRepr),
                 pairtype(AbstractUniCharRepr, IntegerRepr)):

    def rtype_mul((r_chr, r_int), hop):
        char_repr = r_chr.char_repr
        v_char, v_int = hop.inputargs(char_repr, Signed)
        return hop.gendirectcall(r_chr.ll.ll_char_mul, v_char, v_int)
    rtype_inplace_mul = rtype_mul

class __extend__(pairtype(IntegerRepr, AbstractCharRepr),
                 pairtype(IntegerRepr, AbstractUniCharRepr)):
    def rtype_mul((r_int, r_chr), hop):
        char_repr = r_chr.char_repr
        v_int, v_char = hop.inputargs(Signed, char_repr)
        return hop.gendirectcall(r_chr.ll.ll_char_mul, v_char, v_int)
    rtype_inplace_mul = rtype_mul

class __extend__(pairtype(AbstractCharRepr, AbstractCharRepr)):
    def rtype_eq(_, hop): return _rtype_compare_template(hop, 'eq')
    def rtype_ne(_, hop): return _rtype_compare_template(hop, 'ne')
    def rtype_lt(_, hop): return _rtype_compare_template(hop, 'lt')
    def rtype_le(_, hop): return _rtype_compare_template(hop, 'le')
    def rtype_gt(_, hop): return _rtype_compare_template(hop, 'gt')
    def rtype_ge(_, hop): return _rtype_compare_template(hop, 'ge')

#Helper functions for comparisons

def _rtype_compare_template(hop, func):
    from rpython.rtyper.lltypesystem.rstr import char_repr
    vlist = hop.inputargs(char_repr, char_repr)
    return hop.genop('char_' + func, vlist, resulttype=Bool)

class __extend__(AbstractUniCharRepr):

    def convert_const(self, value):
        if isinstance(value, str):
            value = unicode(value)
        if not isinstance(value, unicode) or len(value) != 1:
            raise TyperError("not a unicode character: %r" % (value,))
        return value

    def get_ll_eq_function(self):
        return None

    def get_ll_hash_function(self):
        return self.ll.ll_unichar_hash

    get_ll_fasthash_function = get_ll_hash_function

    def rtype_ord(_, hop):
        from rpython.rtyper.lltypesystem.rstr import unichar_repr
        vlist = hop.inputargs(unichar_repr)
        return hop.genop('cast_unichar_to_int', vlist, resulttype=Signed)


class __extend__(pairtype(AbstractUniCharRepr, AbstractUniCharRepr)):
    def rtype_eq(_, hop): return _rtype_unchr_compare_template(hop, 'eq')
    def rtype_ne(_, hop): return _rtype_unchr_compare_template(hop, 'ne')
    def rtype_lt(_, hop): return _rtype_unchr_compare_template_ord(hop, 'lt')
    def rtype_le(_, hop): return _rtype_unchr_compare_template_ord(hop, 'le')
    def rtype_gt(_, hop): return _rtype_unchr_compare_template_ord(hop, 'gt')
    def rtype_ge(_, hop): return _rtype_unchr_compare_template_ord(hop, 'ge')


#Helper functions for comparisons

def _rtype_unchr_compare_template(hop, func):
    from rpython.rtyper.lltypesystem.rstr import unichar_repr
    vlist = hop.inputargs(unichar_repr, unichar_repr)
    return hop.genop('unichar_' + func, vlist, resulttype=Bool)

def _rtype_unchr_compare_template_ord(hop, func):
    vlist = hop.inputargs(*hop.args_r)
    vlist2 = []
    for v in vlist:
        v = hop.genop('cast_unichar_to_int', [v], resulttype=lltype.Signed)
        vlist2.append(v)
    return hop.genop('int_' + func, vlist2, resulttype=Bool)

#
# _________________________ Conversions _________________________

class __extend__(pairtype(AbstractCharRepr, AbstractStringRepr),
                 pairtype(AbstractUniCharRepr, AbstractUnicodeRepr)):
    def convert_from_to((r_from, r_to), v, llops):
        from rpython.rtyper.lltypesystem.rstr import (
            string_repr, unicode_repr, char_repr, unichar_repr)
        if (r_from == char_repr and r_to == string_repr) or\
           (r_from == unichar_repr and r_to == unicode_repr):
            return llops.gendirectcall(r_from.ll.ll_chr2str, v)
        return NotImplemented

class __extend__(pairtype(AbstractStringRepr, AbstractCharRepr)):
    def convert_from_to((r_from, r_to), v, llops):
        from rpython.rtyper.lltypesystem.rstr import string_repr, char_repr
        if r_from == string_repr and r_to == char_repr:
            c_zero = inputconst(Signed, 0)
            return llops.gendirectcall(r_from.ll.ll_stritem_nonneg, v, c_zero)
        return NotImplemented

# ____________________________________________________________
#
#  Iteration.

class AbstractStringIteratorRepr(IteratorRepr):

    def newiter(self, hop):
        string_repr = hop.args_r[0].repr
        v_str, = hop.inputargs(string_repr)
        return hop.gendirectcall(self.ll_striter, v_str)

    def rtype_next(self, hop):
        v_iter, = hop.inputargs(self)
        hop.has_implicit_exception(StopIteration) # record that we know about it
        hop.exception_is_here()
        return hop.gendirectcall(self.ll_strnext, v_iter)


# ____________________________________________________________
#
#  Low-level methods.  These can be run for testing, but are meant to
#  be direct_call'ed from rtyped flow graphs, which means that they will
#  get flowed and annotated, mostly with SomePtr.
#

class AbstractLLHelpers(object):
    @staticmethod
    def ll_isdigit(s):
        from rpython.rtyper.annlowlevel import hlstr

        s = hlstr(s)
        if not s:
            return False
        for ch in s:
            if not ch.isdigit():
                return False
        return True

    @staticmethod
    def ll_isalpha(s):
        from rpython.rtyper.annlowlevel import hlstr

        s = hlstr(s)
        if not s:
            return False
        for ch in s:
            if not ch.isalpha():
                return False
        return True

    @staticmethod
    def ll_isalnum(s):
        from rpython.rtyper.annlowlevel import hlstr

        s = hlstr(s)
        if not s:
            return False
        for ch in s:
            if not ch.isalnum():
                return False
        return True

    @staticmethod
    def ll_char_isspace(ch):
        c = ord(ch)
        return c == 32 or (9 <= c <= 13)   # c in (9, 10, 11, 12, 13, 32)

    @staticmethod
    def ll_char_isdigit(ch):
        c = ord(ch)
        return c <= 57 and c >= 48

    @staticmethod
    def ll_char_isalpha(ch):
        c = ord(ch)
        if c >= 97:
            return c <= 122
        else:
            return 65 <= c <= 90

    @staticmethod
    def ll_char_isalnum(ch):
        c = ord(ch)
        if c >= 65:
            if c >= 97:
                return c <= 122
            else:
                return c <= 90
        else:
            return 48 <= c <= 57

    @staticmethod
    def ll_char_isupper(ch):
        c = ord(ch)
        return 65 <= c <= 90

    @staticmethod
    def ll_char_islower(ch):
        c = ord(ch)
        return 97 <= c <= 122

    @staticmethod
    def ll_upper_char(ch):
        if 'a' <= ch <= 'z':
            ch = chr(ord(ch) - 32)
        return ch

    @staticmethod
    def ll_lower_char(ch):
        if 'A' <= ch <= 'Z':
            ch = chr(ord(ch) + 32)
        return ch

    @staticmethod
    def ll_char_hash(ch):
        return ord(ch)

    @staticmethod
    def ll_unichar_hash(ch):
        return ord(ch)

    @classmethod
    def ll_str_is_true(cls, s):
        # check if a string is True, allowing for None
        return bool(s) and cls.ll_strlen(s) != 0

    @classmethod
    def ll_stritem_nonneg_checked(cls, s, i):
        if i >= cls.ll_strlen(s):
            raise IndexError
        return cls.ll_stritem_nonneg(s, i)

    @classmethod
    def ll_stritem(cls, s, i):
        if i < 0:
            i += cls.ll_strlen(s)
        return cls.ll_stritem_nonneg(s, i)

    @classmethod
    def ll_stritem_checked(cls, s, i):
        length = cls.ll_strlen(s)
        if i < 0:
            i += length
        if i >= length or i < 0:
            raise IndexError
        return cls.ll_stritem_nonneg(s, i)

    @staticmethod
    def parse_fmt_string(fmt):
        # we support x, d, s, f, [r]
        it = iter(fmt)
        r = []
        curstr = ''
        for c in it:
            if c == '%':
                f = it.next()
                if f == '%':
                    curstr += '%'
                    continue

                if curstr:
                    r.append(curstr)
                curstr = ''
                if f not in 'xdosrf':
                    raise TyperError("Unsupported formatting specifier: %r in %r" % (f, fmt))

                r.append((f,))
            else:
                curstr += c
        if curstr:
            r.append(curstr)
        return r

    @staticmethod
    def ll_float(ll_str):
        from rpython.rtyper.annlowlevel import hlstr
        from rpython.rlib.rfloat import rstring_to_float
        s = hlstr(ll_str)
        assert s is not None

        n = len(s)
        beg = 0
        while beg < n:
            if s[beg] == ' ':
                beg += 1
            else:
                break
        if beg == n:
            raise ValueError
        end = n - 1
        while end >= 0:
            if s[end] == ' ':
                end -= 1
            else:
                break
        assert end >= 0
        return rstring_to_float(s[beg:end + 1])

    @classmethod
    def ll_splitlines(cls, LIST, ll_str, keep_newlines):
        from rpython.rtyper.annlowlevel import hlstr
        s = hlstr(ll_str)
        strlen = len(s)
        i = 0
        j = 0
        # The annotator makes sure this list is resizable.
        res = LIST.ll_newlist(0)
        while j < strlen:
            while i < strlen and s[i] != '\n' and s[i] != '\r':
                i += 1
            eol = i
            if i < strlen:
                if s[i] == '\r' and i + 1 < strlen and s[i + 1] == '\n':
                    i += 2
                else:
                    i += 1
                if keep_newlines:
                    eol = i
            list_length = res.ll_length()
            res._ll_resize_ge(list_length + 1)
            item = cls.ll_stringslice_startstop(ll_str, j, eol)
            res.ll_setitem_fast(list_length, item)
            j = i
        if j < strlen:
            list_length = res.ll_length()
            res._ll_resize_ge(list_length + 1)
            item = cls.ll_stringslice_startstop(ll_str, j, strlen)
            res.ll_setitem_fast(list_length, item)
        return res
