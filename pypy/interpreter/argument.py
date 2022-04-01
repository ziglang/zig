"""
Arguments objects.
"""
from rpython.rlib.debug import make_sure_not_resized
from rpython.rlib.objectmodel import not_rpython, specialize
from rpython.rlib import jit
from rpython.rlib.objectmodel import enforceargs
from rpython.rlib.rstring import StringBuilder

from pypy.interpreter.error import OperationError, oefmt

@specialize.arg(2)
def raise_type_error(space, fnname_parens, msg, *args):
    if fnname_parens is None:
        raise oefmt(space.w_TypeError, msg, *args)
    msg = "%s " + msg
    raise oefmt(space.w_TypeError, msg, fnname_parens, *args)


class Arguments(object):
    """
    Collects the arguments of a function call.

    Instances should be considered immutable.

    Some parts of this class are written in a slightly convoluted style to help
    the JIT. It is really crucial to get this right, because Python's argument
    semantics are complex, but calls occur everywhere.
    """

    def __init__(self, space, args_w, keyword_names_w=None, keywords_w=None,
                 w_stararg=None, w_starstararg=None,
                 methodcall=False, fnname_parens=None):
        self.space = space
        assert isinstance(args_w, list)
        self.arguments_w = args_w
        # keyword_names_w and keywords_w are two parallel lists
        self.keyword_names_w = keyword_names_w
        self.keywords_w = keywords_w
        if keyword_names_w is not None:
            assert keywords_w is not None
            assert len(keywords_w) == len(keyword_names_w)
            make_sure_not_resized(self.keyword_names_w)
            make_sure_not_resized(self.keywords_w)

        make_sure_not_resized(self.arguments_w)
        self._combine_wrapped(w_stararg, w_starstararg, fnname_parens)
        # a flag that specifies whether the JIT can unroll loops that operate
        # on the keywords
        self._jit_few_keywords = self.keyword_names_w is None or jit.isconstant(len(self.keyword_names_w))
        # a flag whether this is likely a method call, which doesn't change the
        # behaviour but produces better error messages
        self.methodcall = methodcall

    @not_rpython
    def __repr__(self):
        name = self.__class__.__name__
        if not self.keyword_names_w:
            return '%s(%s)' % (name, self.arguments_w,)
        else:
            return '%s(%s, %s, %s)' % (name, self.arguments_w,
                                       [self.space.text_w(w_name) for w_name in self.keyword_names_w],
                                       self.keywords_w)


    ###  Manipulation  ###

    @jit.look_inside_iff(lambda self: self._jit_few_keywords)
    def unpack(self): # slowish
        "Return a ([w1,w2...], {'kw':w3...}) pair."
        kwds_w = {}
        if self.keyword_names_w:
            for i in range(len(self.keyword_names_w)):
                kwds_w[self.space.text_w(self.keyword_names_w[i])] = self.keywords_w[i]
        return self.arguments_w, kwds_w

    def replace_arguments(self, args_w):
        "Return a new Arguments with a args_w as positional arguments."
        return Arguments(self.space, args_w, self.keyword_names_w, self.keywords_w)

    def prepend(self, w_firstarg):
        "Return a new Arguments with a new argument inserted first."
        return self.replace_arguments([w_firstarg] + self.arguments_w)

    def _combine_wrapped(self, w_stararg, w_starstararg, fnname_parens=None):
        "unpack the *arg and **kwd into arguments_w and keywords_w"
        if w_stararg is not None:
            self._combine_starargs_wrapped(w_stararg, fnname_parens)
        if w_starstararg is not None:
            self._combine_starstarargs_wrapped(w_starstararg, fnname_parens)

    def _combine_starargs_wrapped(self, w_stararg, fnname_parens=None):
        # unpack the * arguments
        space = self.space
        try:
            args_w = space.fixedview(w_stararg)
        except OperationError as e:
            if (e.match(space, space.w_TypeError) and
                    not space.is_iterable(w_stararg)):
                raise_type_error(space, fnname_parens,
                            "argument after * must be an iterable, not %T",
                            w_stararg)
            raise
        self.arguments_w = self.arguments_w + args_w

    def _combine_starstarargs_wrapped(self, w_starstararg, fnname_parens=None):
        # unpack the ** arguments
        space = self.space
        keyword_names_w, values_w = space.view_as_kwargs(w_starstararg)
        if keyword_names_w is not None: # this path also taken for empty dicts
            if self.keyword_names_w is None:
                self.keyword_names_w = keyword_names_w
                self.keywords_w = values_w
            else:
                _check_not_duplicate_kwargs(
                    self.space, self.keyword_names_w, keyword_names_w, values_w,
                    fnname_parens)
                self.keyword_names_w = self.keyword_names_w + keyword_names_w
                self.keywords_w = self.keywords_w + values_w
            return
        is_dict = False
        if space.isinstance_w(w_starstararg, space.w_dict):
            is_dict = True
            keys_w = space.unpackiterable(w_starstararg)
        else:
            try:
                w_keys = space.call_method(w_starstararg, "keys")
            except OperationError as e:
                if e.match(space, space.w_AttributeError):
                    raise_type_error(space, fnname_parens,
                                "argument after ** must be a mapping, not %T",
                                w_starstararg)
                raise
            keys_w = space.unpackiterable(w_keys)
        keywords_w = [None] * len(keys_w)
        keyword_names_w = [None] * len(keys_w)
        _do_combine_starstarargs_wrapped(
            space, keys_w, w_starstararg, keyword_names_w, keywords_w, self.keyword_names_w,
            is_dict, fnname_parens)
        if self.keyword_names_w is None:
            self.keyword_names_w = keyword_names_w
            self.keywords_w = keywords_w
        else:
            self.keyword_names_w = self.keyword_names_w + keyword_names_w
            self.keywords_w = self.keywords_w + keywords_w


    def fixedunpack(self, argcount):
        """The simplest argument parsing: get the 'argcount' arguments,
        or raise a real ValueError if the length is wrong."""
        if self.keyword_names_w:
            raise ValueError("no keyword arguments expected")
        if len(self.arguments_w) > argcount:
            raise ValueError("too many arguments (%d expected)" % argcount)
        elif len(self.arguments_w) < argcount:
            raise ValueError("not enough arguments (%d expected)" % argcount)
        return self.arguments_w

    def firstarg(self):
        "Return the first argument for inspection."
        if self.arguments_w:
            return self.arguments_w[0]
        return None

    ###  Parsing for function calls  ###

    @jit.unroll_safe
    def _match_signature(self, w_firstarg, scope_w, signature, defaults_w=None,
                         w_kw_defs=None, blindargs=0):
        """Parse args and kwargs according to the signature of a code object,
        or raise an ArgErr in case of failure.
        """
        #   w_firstarg = a first argument to be inserted (e.g. self) or None
        #   args_w = list of the normal actual parameters, wrapped
        #   scope_w = resulting list of wrapped values
        #

        # some comments about the JIT: it assumes that signature is a constant,
        # so all values coming from there can be assumed constant. It assumes
        # that the length of the defaults_w does not vary too much.
        co_posonlyargcount = signature.posonlyargcount
        co_argcount = signature.num_argnames()
        co_kwonlyargcount = signature.num_kwonlyargnames()
        too_many_args = False

        # put the special w_firstarg into the scope, if it exists
        upfront = 0
        args_w = self.arguments_w
        if w_firstarg is not None:
            if co_argcount > 0:
                scope_w[0] = w_firstarg
                upfront = 1
            else:
                # ugh, this is a call to a method 'def meth(*args)', maybe
                # (see test_issue2996_*).  Fall-back solution...
                args_w = [w_firstarg] + args_w

        num_args = len(args_w)
        avail = num_args + upfront

        keyword_names_w = self.keyword_names_w
        num_kwds = 0
        if keyword_names_w is not None:
            num_kwds = len(keyword_names_w)

        # put as many positional input arguments into place as available
        input_argcount = upfront
        if input_argcount < co_argcount:
            take = min(num_args, co_argcount - upfront)

            # letting the JIT unroll this loop is safe, because take is always
            # smaller than co_argcount
            for i in range(take):
                scope_w[i + input_argcount] = args_w[i]
            input_argcount += take

        # collect extra positional arguments into the *vararg
        if signature.has_vararg():
            args_left = co_argcount - upfront
            assert args_left >= 0  # check required by rpython
            if num_args > args_left:
                starargs_w = args_w[args_left:]
            else:
                starargs_w = []
            loc = co_argcount + co_kwonlyargcount
            scope_w[loc] = self.space.newtuple(starargs_w)
        elif avail > co_argcount:
            too_many_args = True

        # if a **kwargs argument is needed, create the dict
        w_kwds = None
        if signature.has_kwarg():
            w_kwds = self.space.newdict(kwargs=True)
            scope_w[co_argcount + co_kwonlyargcount + signature.has_vararg()] = w_kwds

        # handle keyword arguments
        num_remainingkwds = 0
        keywords_w = self.keywords_w
        kwds_mapping = None
        if num_kwds:
            # kwds_mapping maps target indexes in the scope (minus input_argcount)
            # to positions in the keywords_w list
            kwds_mapping = [0] * (co_argcount + co_kwonlyargcount - input_argcount)
            # initialize manually, for the JIT :-(
            for i in range(len(kwds_mapping)):
                kwds_mapping[i] = -1
            # match the keywords given at the call site to the argument names
            # the called function takes
            # this function must not take a scope_w, to make the scope not
            # escape
            num_remainingkwds = _match_keywords(
                    self.space,
                    signature, blindargs, co_posonlyargcount, input_argcount,
                    keyword_names_w, kwds_mapping, self._jit_few_keywords)
            if num_remainingkwds:
                if w_kwds is not None:
                    # collect extra keyword arguments into the **kwarg
                    _collect_keyword_args(
                            self.space, keyword_names_w, keywords_w, w_kwds,
                            kwds_mapping, self._jit_few_keywords)
                else:
                    raise ArgErrUnknownKwds(self.space, num_remainingkwds,
                            keyword_names_w, kwds_mapping)

        # check for missing arguments and fill them from the kwds,
        # or with defaults, if available
        more_filling = (input_argcount < co_argcount + co_kwonlyargcount)
        def_first = 0
        if more_filling:
            def_first = co_argcount - (0 if defaults_w is None else len(defaults_w))
            j = 0
            kwds_index = -1
            # first, fill the arguments from the kwds
            for i in range(input_argcount, co_argcount + co_kwonlyargcount):
                if kwds_mapping is not None:
                    kwds_index = kwds_mapping[j]
                    j += 1
                    if kwds_index >= 0:
                        scope_w[i] = keywords_w[kwds_index]

        if too_many_args:
            kwonly_given = 0
            for i in range(co_argcount, co_argcount + co_kwonlyargcount):
                if scope_w[i] is not None:
                    kwonly_given += 1
            if self.methodcall:
                cls = ArgErrTooManyMethod
            else:
                cls = ArgErrTooMany
            raise cls(signature,
                                0 if defaults_w is None else len(defaults_w),
                                avail, kwonly_given)

        if more_filling:
            missing_positional = None
            missing_kwonly = None
            # then, fill the posonly arguments with defaults_w (if needed)
            for i in range(input_argcount, co_argcount):
                if scope_w[i] is not None:
                    continue
                defnum = i - def_first
                if defnum >= 0:
                    scope_w[i] = defaults_w[defnum]
                else:
                    if missing_positional is None:
                        missing_positional = []
                    missing_positional.append(signature.argnames[i])

            # finally, fill kwonly arguments with w_kw_defs (if needed)
            for i in range(co_argcount, co_argcount + co_kwonlyargcount):
                if scope_w[i] is not None:
                    continue
                name = signature.argnames[i]
                if w_kw_defs is None:
                    if missing_kwonly is None:
                        missing_kwonly = []
                    missing_kwonly.append(name)
                    continue
                w_def = self.space.finditem_str(w_kw_defs, name)
                if w_def is not None:
                    scope_w[i] = w_def
                else:
                    if missing_kwonly is None:
                        missing_kwonly = []
                    missing_kwonly.append(name)

            if missing_positional:
                raise ArgErrMissing(missing_positional, True)
            if missing_kwonly:
                raise ArgErrMissing(missing_kwonly, False)


    def parse_into_scope(self, w_firstarg,
                         scope_w, fnname, signature, defaults_w=None,
                         w_kw_defs=None):
        """Parse args and kwargs to initialize a frame
        according to the signature of code object.
        Store the argumentvalues into scope_w.
        scope_w must be big enough for signature.
        """
        try:
            self._match_signature(w_firstarg,
                                  scope_w, signature, defaults_w,
                                  w_kw_defs, 0)
        except ArgErr as e:
            raise oefmt(self.space.w_TypeError, "%s() %8", fnname, e.getmsg())
        return signature.scope_length()

    def _parse(self, w_firstarg, signature, defaults_w, w_kw_defs, blindargs=0):
        """Parse args and kwargs according to the signature of a code object,
        or raise an ArgErr in case of failure.
        """
        scopelen = signature.scope_length()
        scope_w = [None] * scopelen
        self._match_signature(w_firstarg, scope_w, signature, defaults_w,
                              w_kw_defs, blindargs)
        return scope_w


    def parse_obj(self, w_firstarg,
                  fnname, signature, defaults_w=None, w_kw_defs=None,
                  blindargs=0):
        """Parse args and kwargs into a list according to the signature of a
        code object.
        """
        try:
            return self._parse(w_firstarg, signature, defaults_w, w_kw_defs,
                               blindargs)
        except ArgErr as e:
            raise oefmt(self.space.w_TypeError, "%s() %8", fnname, e.getmsg())

    @staticmethod
    def frompacked(space, w_args=None, w_kwds=None):
        """Convenience static method to build an Arguments
           from a wrapped sequence and a wrapped dictionary."""
        return Arguments(space, [], w_stararg=w_args, w_starstararg=w_kwds)

    def topacked(self):
        """Express the Argument object as a pair of wrapped w_args, w_kwds."""
        space = self.space
        w_args = space.newtuple(self.arguments_w)
        w_kwds = space.newdict()
        if self.keyword_names_w is not None:
            for i in range(len(self.keyword_names_w)):
                w_key = self.keyword_names_w[i]
                space.setitem(w_kwds, w_key, self.keywords_w[i])
        return w_args, w_kwds

# JIT helper functions
# these functions contain functionality that the JIT is not always supposed to
# look at. They should not get a self arguments, which makes the amount of
# arguments annoying :-(

@jit.look_inside_iff(lambda space, existingkeywords_w, keyword_names_w, keywords_w, fnname_parens:
        jit.isconstant(len(keyword_names_w) and
        jit.isconstant(existingkeywords_w)))
def _check_not_duplicate_kwargs(space, existingkeywords_w, keyword_names_w, keywords_w, fnname_parens):
    # looks quadratic, but the JIT should remove all of it nicely.
    # Also, all the lists should be small
    for w_key in keyword_names_w:
        if contains_w_names(w_key, existingkeywords_w):
            raise_type_error(space, fnname_parens,
                        "got multiple values for keyword argument '%S'",
                        w_key)

def contains_w_names(w_key, keys_w):
    for w_other in keys_w:
        if w_other.eq_w(w_key):
            return True
    return False

def _do_combine_starstarargs_wrapped(space, keys_w, w_starstararg, keyword_names_w,
        keywords_w, existingkeywords_w, is_dict, fnname_parens):
    i = 0
    seen = {}
    for w_key in keys_w:
        try:
            key = space.text_w(w_key)
        except OperationError as e:
            if e.match(space, space.w_TypeError):
                raise_type_error(space, fnname_parens,
                            "keywords must be strings, not '%T'",
                            w_key)
            raise
        else:
            if ((existingkeywords_w and
                 contains_w_names(w_key, existingkeywords_w)) or
                key in seen
            ):
                raise_type_error(space, fnname_parens,
                            "got multiple values for keyword argument '%S'",
                            w_key)
        seen[key] = None
        assert isinstance(w_key, space.UnicodeObjectCls)
        keyword_names_w[i] = w_key
        if is_dict:
            # issue 2435: bug-to-bug compatibility with cpython. for a subclass of
            # dict, just ignore the __getitem__ and access the underlying dict
            # directly
            from pypy.objspace.descroperation import dict_getitem
            w_descr = dict_getitem(space)
            w_value = space.get_and_call_function(w_descr, w_starstararg, w_key)
        else:
            w_value = space.getitem(w_starstararg, w_key)
        keywords_w[i] = w_value
        i += 1

@jit.look_inside_iff(
    lambda space, signature, blindargs, co_posonlyargcount, input_argcount,
           keyword_names_w, kwds_mapping, jiton: jiton)
def _match_keywords(space, signature, blindargs, co_posonlyargcount,
                    input_argcount, keyword_names_w, kwds_mapping, _):
    # letting JIT unroll the loop is *only* safe if the callsite didn't
    # use **args because num_kwds can be arbitrarily large otherwise.
    num_kwds = num_remainingkwds = len(keyword_names_w)
    wrong_posonly = None
    for i in range(num_kwds):
        w_name = keyword_names_w[i]
        assert w_name is not None
        j = signature.find_w_argname(w_name)
        if 0 <= j < co_posonlyargcount:
            # we complain about a forbidden positional only keyword argument
            # only if there is no **kwargs. otherwise, the keyword goes into
            # the kwargs dict.
            if signature.has_kwarg():
                j = -1
            else:
                if wrong_posonly is None:
                    wrong_posonly = []
                wrong_posonly.append(signature.argnames[j])
                continue
        if j < input_argcount:
            # if j == -1 nothing happens, because j < input_argcount and
            # blindargs > j

            # check that no keyword argument conflicts with these. note
            # that for this purpose we ignore the first blindargs,
            # which were put into place by prepend().  This way,
            # keywords do not conflict with the hidden extra argument
            # bound by methods.
            if blindargs <= j:
                raise ArgErrMultipleValues(space.text_w(w_name))
        else:
            kwds_mapping[j - input_argcount] = i # map to the right index
            num_remainingkwds -= 1
    if wrong_posonly:
        raise ArgErrPosonlyAsKwds(wrong_posonly)
    return num_remainingkwds

@jit.look_inside_iff(
    lambda space, keyword_names_w, keywords_w, w_kwds, kwds_mapping,
        jiton: jiton)
def _collect_keyword_args(space, keyword_names_w, keywords_w, w_kwds,
                          kwds_mapping, _):
    for i in range(len(keyword_names_w)):
        # again a dangerous-looking loop that either the JIT unrolls
        # or that is not too bad, because len(kwds_mapping) is small
        for j in kwds_mapping:
            if i == j:
                break
        else:
            w_key = keyword_names_w[i]
            space.setitem(w_kwds, w_key, keywords_w[i])

#
# ArgErr family of exceptions raised in case of argument mismatch.
# We try to give error messages following CPython's, which are very informative.
#

class ArgErr(Exception):

    def getmsg(self):
        raise NotImplementedError


class ArgErrMissing(ArgErr):
    def __init__(self, missing, positional):
        self.missing = missing
        self.positional = positional  # keyword-only otherwise

    def getmsg(self):
        arguments_str = StringBuilder()
        for i, arg in enumerate(self.missing):
            if i == 0:
                pass
            elif i == len(self.missing) - 1:
                if len(self.missing) == 2:
                    arguments_str.append(" and ")
                else:
                    arguments_str.append(", and ")
            else:
                arguments_str.append(", ")
            arguments_str.append("'%s'" % arg)
        msg = "missing %s required %s argument%s: %s" % (
            len(self.missing),
            "positional" if self.positional else "keyword-only",
            "s" if len(self.missing) != 1 else "",
            arguments_str.build())
        return msg


class ArgErrTooMany(ArgErr):
    def __init__(self, signature, num_defaults, given, kwonly_given):
        self.signature = signature
        self.num_defaults = num_defaults
        self.given = given
        self.kwonly_given = kwonly_given

    def getmsg(self):
        num_args = self.signature.num_argnames()
        num_defaults = self.num_defaults
        if num_defaults:
            takes_str = "from %d to %d positional arguments" % (
                num_args - num_defaults, num_args)
        else:
            takes_str = "%d positional argument%s" % (
                num_args, "s" if num_args != 1 else "")
        if self.kwonly_given:
            given_str = ("%s positional argument%s "
                         "(and %s keyword-only argument%s) were") % (
                self.given, "s" if self.given != 1 else "",
                self.kwonly_given, "s" if self.kwonly_given != 1 else "")
        else:
            given_str = "%s %s" % (
                self.given, "were" if self.given != 1 else "was")
        msg = "takes %s but %s given" % (takes_str, given_str)
        return msg

class ArgErrTooManyMethod(ArgErrTooMany):
    """ A subclass of ArgErrCount that is used if the argument matching is done
    as part of a method call, in which case more information is added to the
    error message, if the cause of the error is likely a forgotten `self`
    argument.
    """

    def getmsg(self):
        msg = ArgErrTooMany.getmsg(self)
        n = self.signature.num_argnames()
        if (self.given == n + 1 and
                (n == 0 or self.signature.argnames[0] != "self")):
            msg += ". Did you forget 'self' in the function definition?"
        return msg


class ArgErrMultipleValues(ArgErr):

    def __init__(self, argname):
        self.argname = argname

    def getmsg(self):
        msg = "got multiple values for argument '%s'" % self.argname
        return msg

class ArgErrUnknownKwds(ArgErr):

    def __init__(self, space, num_remainingkwds, keyword_names_w,
            kwds_mapping):
        name = ''
        self.num_kwds = num_remainingkwds
        if num_remainingkwds == 1:
            for i in range(len(keyword_names_w)):
                if i not in kwds_mapping:
                    name = space.text_w(keyword_names_w[i])
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


class ArgErrPosonlyAsKwds(ArgErr):

    def __init__(self, posonly_kwds):
        self.posonly_kwds = posonly_kwds

    def getmsg(self):
        if len(self.posonly_kwds) == 1:
            msg = ("got a positional-only argument passed as keyword argument: '%s'" % self.posonly_kwds[0])
        else:
            msg = ("got some positional-only arguments passed as keyword arguments: '%s'" % ", ".join(self.posonly_kwds))
        return msg
