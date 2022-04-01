"""
Arguments objects.
"""
from rpython.annotator.model import SomeTuple
from rpython.flowspace.argument import CallSpec

class ArgumentsForTranslation(CallSpec):
    @property
    def positional_args(self):
        if self.w_stararg is not None:
            args_w = self.unpackiterable(self.w_stararg)
            return self.arguments_w + args_w
        else:
            return self.arguments_w

    def newtuple(self, items_s):
        return SomeTuple(items_s)

    def unpackiterable(self, s_obj):
        assert isinstance(s_obj, SomeTuple)
        return list(s_obj.items)

    def fixedunpack(self, argcount):
        """The simplest argument parsing: get the 'argcount' arguments,
        or raise a real ValueError if the length is wrong."""
        if self.keywords:
            raise ValueError("no keyword arguments expected")
        if len(self.arguments_w) > argcount:
            raise ValueError("too many arguments (%d expected)" % argcount)
        elif len(self.arguments_w) < argcount:
            raise ValueError("not enough arguments (%d expected)" % argcount)
        return self.arguments_w

    def prepend(self, w_firstarg): # used often
        "Return a new Arguments with a new argument inserted first."
        return ArgumentsForTranslation([w_firstarg] + self.arguments_w,
                                       self.keywords, self.w_stararg)

    def copy(self):
        return ArgumentsForTranslation(self.arguments_w, self.keywords,
                self.w_stararg)

    def _match_signature(self, scope_w, signature, defaults_w=None):
        """Parse args and kwargs according to the signature of a code object,
        or raise an ArgErr in case of failure.
        """
        #   args_w = list of the normal actual parameters, wrapped
        #   scope_w = resulting list of wrapped values
        #
        co_argcount = signature.num_argnames() # expected formal arguments, without */**

        args_w = self.positional_args
        num_args = len(args_w)
        keywords = self.keywords
        num_kwds = len(keywords)

        # put as many positional input arguments into place as available
        take = min(num_args, co_argcount)
        scope_w[:take] = args_w[:take]
        input_argcount = take

        # collect extra positional arguments into the *vararg
        if signature.has_vararg():
            if num_args > co_argcount:
                starargs_w = args_w[co_argcount:]
            else:
                starargs_w = []
            scope_w[co_argcount] = self.newtuple(starargs_w)
        elif num_args > co_argcount:
            raise ArgErrCount(num_args, num_kwds, signature, defaults_w, 0)

        assert not signature.has_kwarg() # XXX should not happen?

        # handle keyword arguments
        num_remainingkwds = 0
        kwds_mapping = None
        if num_kwds:
            # kwds_mapping maps target indexes in the scope (minus input_argcount)
            # to keyword names
            kwds_mapping = []
            # match the keywords given at the call site to the argument names
            # the called function takes
            # this function must not take a scope_w, to make the scope not
            # escape
            num_remainingkwds = len(keywords)
            for name in keywords:
                j = signature.find_argname(name)
                # if j == -1 nothing happens
                if j < input_argcount:
                    # check that no keyword argument conflicts with these.
                    if j >= 0:
                        raise ArgErrMultipleValues(name)
                else:
                    kwds_mapping.append(name)
                    num_remainingkwds -= 1

            if num_remainingkwds:
                if co_argcount == 0:
                    raise ArgErrCount(num_args, num_kwds, signature, defaults_w, 0)
                raise ArgErrUnknownKwds(num_remainingkwds, keywords,
                                        kwds_mapping)

        # check for missing arguments and fill them from the kwds,
        # or with defaults, if available
        missing = 0
        if input_argcount < co_argcount:
            def_first = co_argcount - (0 if defaults_w is None else len(defaults_w))
            j = 0
            for i in range(input_argcount, co_argcount):
                name = signature.argnames[i]
                if name in keywords:
                    scope_w[i] = keywords[name]
                    continue
                defnum = i - def_first
                if defnum >= 0:
                    scope_w[i] = defaults_w[defnum]
                else:
                    missing += 1
            if missing:
                raise ArgErrCount(num_args, num_kwds, signature, defaults_w, missing)

    def unpack(self):
        "Return a ([w1,w2...], {'kw':w3...}) pair."
        return self.positional_args, self.keywords

    def match_signature(self, signature, defaults_w):
        """Parse args and kwargs according to the signature of a code object,
        or raise an ArgErr in case of failure.
        """
        scopelen = signature.scope_length()
        scope_w = [None] * scopelen
        self._match_signature(scope_w, signature, defaults_w)
        return scope_w

    def unmatch_signature(self, signature, data_w):
        """kind of inverse of match_signature"""
        argnames, varargname, kwargname = signature
        assert kwargname is None
        cnt = len(argnames)
        need_cnt = len(self.positional_args)
        if varargname:
            assert len(data_w) == cnt + 1
            stararg_w = self.unpackiterable(data_w[cnt])
            if stararg_w:
                args_w = data_w[:cnt] + stararg_w
                assert len(args_w) == need_cnt
                assert not self.keywords
                return ArgumentsForTranslation(args_w, {})
            else:
                data_w = data_w[:-1]
        assert len(data_w) == cnt
        assert len(data_w) >= need_cnt
        args_w = data_w[:need_cnt]
        _kwds_w = dict(zip(argnames[need_cnt:], data_w[need_cnt:]))
        keywords_w = [_kwds_w[key] for key in self.keywords]
        return ArgumentsForTranslation(args_w, dict(zip(self.keywords, keywords_w)))


def rawshape(args):
    return args._rawshape()

def simple_args(args_s):
    return ArgumentsForTranslation(list(args_s))

def complex_args(args_s):
    return ArgumentsForTranslation.fromshape(args_s[0].const,
                                             list(args_s[1:]))

#
# ArgErr family of exceptions raised in case of argument mismatch.
# We try to give error messages following CPython's, which are very informative.
#

class ArgErr(Exception):
    def getmsg(self):
        raise NotImplementedError


class ArgErrCount(ArgErr):
    def __init__(self, got_nargs, nkwds, signature,
                 defaults_w, missing_args):
        self.signature = signature

        self.num_defaults = 0 if defaults_w is None else len(defaults_w)
        self.missing_args = missing_args
        self.num_args = got_nargs
        self.num_kwds = nkwds

    def getmsg(self):
        n = self.signature.num_argnames()
        if n == 0:
            msg = "takes no arguments (%d given)" % (
                self.num_args + self.num_kwds)
        else:
            defcount = self.num_defaults
            has_kwarg = self.signature.has_kwarg()
            num_args = self.num_args
            num_kwds = self.num_kwds
            if defcount == 0 and not self.signature.has_vararg():
                msg1 = "exactly"
                if not has_kwarg:
                    num_args += num_kwds
                    num_kwds = 0
            elif not self.missing_args:
                msg1 = "at most"
            else:
                msg1 = "at least"
                has_kwarg = False
                n -= defcount
            if n == 1:
                plural = ""
            else:
                plural = "s"
            if has_kwarg or num_kwds > 0:
                msg2 = " non-keyword"
            else:
                msg2 = ""
            msg = "takes %s %d%s argument%s (%d given)" % (
                msg1,
                n,
                msg2,
                plural,
                num_args)
        return msg


class ArgErrMultipleValues(ArgErr):
    def __init__(self, argname):
        self.argname = argname

    def getmsg(self):
        msg = "got multiple values for keyword argument '%s'" % (
            self.argname)
        return msg


class ArgErrUnknownKwds(ArgErr):
    def __init__(self, num_remainingkwds, keywords, kwds_mapping):
        name = ''
        self.num_kwds = num_remainingkwds
        if num_remainingkwds == 1:
            for name in keywords:
                if name not in kwds_mapping:
                    break
        self.kwd_name = name

    def getmsg(self):
        if self.num_kwds == 1:
            msg = "got an unexpected keyword argument '%s'" % (
                self.kwd_name)
        else:
            msg = "got %d unexpected keyword arguments" % (
                self.num_kwds)
        return msg
