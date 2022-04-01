import optparse
from rpython.tool.pairtype import extendabletype

SUPPRESS_USAGE = optparse.SUPPRESS_USAGE

class AmbigousOptionError(Exception):
    pass

class NoMatchingOptionFound(AttributeError):
    pass

class ConfigError(Exception):
    pass

class ConflictConfigError(ConfigError):
    pass

class Config(object):
    _cfgimpl_frozen = False

    def __init__(self, descr, parent=None, **overrides):
        self._cfgimpl_descr = descr
        self._cfgimpl_value_owners = {}
        self._cfgimpl_parent = parent
        self._cfgimpl_values = {}
        self._cfgimpl_warnings = []
        self._cfgimpl_build(overrides)

    def _cfgimpl_build(self, overrides):
        for child in self._cfgimpl_descr._children:
            if isinstance(child, Option):
                self._cfgimpl_values[child._name] = child.getdefault()
                self._cfgimpl_value_owners[child._name] = 'default'
            elif isinstance(child, OptionDescription):
                self._cfgimpl_values[child._name] = Config(child, parent=self)
        self.override(overrides)

    def override(self, overrides):
        for name, value in overrides.iteritems():
            homeconfig, name = self._cfgimpl_get_home_by_path(name)
            homeconfig.setoption(name, value, 'default')

    def copy(self, as_default=False, parent=None):
        result = Config.__new__(self.__class__)
        result._cfgimpl_descr = self._cfgimpl_descr
        result._cfgimpl_value_owners = owners = {}
        result._cfgimpl_parent = parent
        result._cfgimpl_values = v = {}
        for child in self._cfgimpl_descr._children:
            if isinstance(child, Option):
                v[child._name] = self._cfgimpl_values[child._name]
                if as_default:
                    owners[child._name] = 'default'
                else:
                    owners[child._name] = (
                        self._cfgimpl_value_owners[child._name])
            elif isinstance(child, OptionDescription):
                v[child._name] = self._cfgimpl_values[child._name].copy(
                    as_default, parent=result)
        return result

    def __setattr__(self, name, value):
        if self._cfgimpl_frozen and getattr(self, name) != value:
            raise TypeError("trying to change a frozen option object")
        if name.startswith('_cfgimpl_'):
            self.__dict__[name] = value
            return
        self.setoption(name, value, 'user')

    def __getattr__(self, name):
        if '.' in name:
            homeconfig, name = self._cfgimpl_get_home_by_path(name)
            return getattr(homeconfig, name)
        if name.startswith('_cfgimpl_'):
            # if it were in __dict__ it would have been found already
            raise AttributeError("%s object has no attribute %s" %
                                 (self.__class__, name))
        if name not in self._cfgimpl_values:
            raise AttributeError("%s object has no attribute %s" %
                                 (self.__class__, name))
        return self._cfgimpl_values[name]

    def __dir__(self):
        from_type = dir(type(self))
        from_dict = list(self.__dict__)
        extras = list(self._cfgimpl_values)
        return sorted(set(extras + from_type + from_dict))

    def __delattr__(self, name):
        # XXX if you use delattr you are responsible for all bad things
        # happening
        if name.startswith('_cfgimpl_'):
            del self.__dict__[name]
            return
        self._cfgimpl_value_owners[name] = 'default'
        opt = getattr(self._cfgimpl_descr, name)
        if isinstance(opt, OptionDescription):
            raise AttributeError("can't option subgroup")
        self._cfgimpl_values[name] = getattr(opt, 'default', None)

    def setoption(self, name, value, who):
        if name not in self._cfgimpl_values:
            raise AttributeError('unknown option %s' % (name,))
        child = getattr(self._cfgimpl_descr, name)
        oldowner = self._cfgimpl_value_owners[child._name]
        if oldowner not in ("default", "suggested"):
            oldvalue = getattr(self, name)
            if oldvalue == value or who in ("default", "suggested"):
                return
            raise ConflictConfigError('cannot override value to %s for '
                                      'option %s' % (value, name))
        child.setoption(self, value, who)
        self._cfgimpl_value_owners[name] = who

    def suggest(self, **kwargs):
        for name, value in kwargs.items():
            self.suggestoption(name, value)

    def suggestoption(self, name, value):
        try:
            self.setoption(name, value, "suggested")
        except ConflictConfigError:
            # setting didn't work, but that is fine, since it is
            # suggested only
            pass

    def set(self, **kwargs):
        all_paths = [p.split(".") for p in self.getpaths()]
        for key, value in kwargs.iteritems():
            key_p = key.split('.')
            candidates = [p for p in all_paths if p[-len(key_p):] == key_p]
            if len(candidates) == 1:
                name = '.'.join(candidates[0])
                homeconfig, name = self._cfgimpl_get_home_by_path(name)
                homeconfig.setoption(name, value, "user")
            elif len(candidates) > 1:
                raise AmbigousOptionError(
                    'more than one option that ends with %s' % (key, ))
            else:
                raise NoMatchingOptionFound(
                    'there is no option that matches %s' % (key, ))

    def _cfgimpl_get_home_by_path(self, path):
        """returns tuple (config, name)"""
        path = path.split('.')
        for step in path[:-1]:
            self = getattr(self, step)
        return self, path[-1]

    def _cfgimpl_get_toplevel(self):
        while self._cfgimpl_parent is not None:
            self = self._cfgimpl_parent
        return self

    def add_warning(self, warning):
        self._cfgimpl_get_toplevel()._cfgimpl_warnings.append(warning)

    def get_warnings(self):
        return self._cfgimpl_get_toplevel()._cfgimpl_warnings

    def _freeze_(self):
        self.__dict__['_cfgimpl_frozen'] = True
        return True

    def getkey(self):
        return self._cfgimpl_descr.getkey(self)

    def __hash__(self):
        return hash(self.getkey())

    def __eq__(self, other):
        return self.getkey() == other.getkey()

    def __ne__(self, other):
        return not self == other

    def __iter__(self):
        for child in self._cfgimpl_descr._children:
            if isinstance(child, Option):
                yield child._name, getattr(self, child._name)

    def __str__(self, indent=""):
        lines = []
        children = [(child._name, child)
                    for child in self._cfgimpl_descr._children]
        children.sort()
        for name, child in children:
            if self._cfgimpl_value_owners.get(name, None) == 'default':
                continue
            value = getattr(self, name)
            if isinstance(value, Config):
                substr = value.__str__(indent + "    ")
            else:
                substr = "%s    %s = %s" % (indent, name, value)
            if substr:
                lines.append(substr)
        if indent and not lines:
            return ''   # hide subgroups with all default values
        lines.insert(0, "%s[%s]" % (indent, self._cfgimpl_descr._name,))
        return '\n'.join(lines)

    def getpaths(self, include_groups=False):
        """returns a list of all paths in self, recursively
        """
        return self._cfgimpl_descr.getpaths(include_groups=include_groups)


DEFAULT_OPTION_NAME = object()


class Option(object):
    __metaclass__ = extendabletype

    def __init__(self, name, doc, cmdline=DEFAULT_OPTION_NAME):
        self._name = name
        self.doc = doc
        self.cmdline = cmdline

    def validate(self, value):
        raise NotImplementedError('abstract base class')

    def getdefault(self):
        return self.default

    def setoption(self, config, value, who):
        name = self._name
        if who == "default" and value is None:
            pass
        elif not self.validate(value):
            raise ConfigError('invalid value %s for option %s' % (value, name))
        config._cfgimpl_values[name] = value

    def getkey(self, value):
        return value

    def convert_from_cmdline(self, value):
        return value

    def add_optparse_option(self, argnames, parser, config):
        callback = ConfigUpdate(config, self)
        parser.add_option(help=self.doc+" %default",
                          action='callback', type=self.opt_type,
                          callback=callback, metavar=self._name.upper(),
                          *argnames)


class ChoiceOption(Option):
    opt_type = 'string'

    def __init__(self, name, doc, values, default=None, requires=None,
                 suggests=None, cmdline=DEFAULT_OPTION_NAME):
        super(ChoiceOption, self).__init__(name, doc, cmdline)
        self.values = values
        self.default = default
        if requires is None:
            requires = {}
        self._requires = requires
        if suggests is None:
            suggests = {}
        self._suggests = suggests

    def setoption(self, config, value, who):
        name = self._name
        for path, reqvalue in self._requires.get(value, []):
            toplevel = config._cfgimpl_get_toplevel()
            homeconfig, name = toplevel._cfgimpl_get_home_by_path(path)
            if who == 'default':
                who2 = 'default'
            else:
                who2 = 'required'
            homeconfig.setoption(name, reqvalue, who2)
        for path, reqvalue in self._suggests.get(value, []):
            toplevel = config._cfgimpl_get_toplevel()
            homeconfig, name = toplevel._cfgimpl_get_home_by_path(path)
            homeconfig.suggestoption(name, reqvalue)
        super(ChoiceOption, self).setoption(config, value, who)

    def validate(self, value):
        return value is None or value in self.values

    def convert_from_cmdline(self, value):
        return value.strip()


def _getnegation(optname):
    if optname.startswith("without"):
        return "with" + optname[len("without"):]
    if optname.startswith("with"):
        return "without" + optname[len("with"):]
    return "no-" + optname

class BoolOption(Option):
    def __init__(self, name, doc, default=None, requires=None,
                 suggests=None, validator=None,
                 cmdline=DEFAULT_OPTION_NAME, negation=True):
        super(BoolOption, self).__init__(name, doc, cmdline=cmdline)
        self._requires = requires
        self._suggests = suggests
        self.default = default
        self.negation = negation
        self._validator = validator

    def validate(self, value):
        return isinstance(value, bool)

    def setoption(self, config, value, who):
        name = self._name
        if value and self._validator is not None:
            toplevel = config._cfgimpl_get_toplevel()
            self._validator(toplevel)
        if value and self._requires is not None:
            for path, reqvalue in self._requires:
                toplevel = config._cfgimpl_get_toplevel()
                homeconfig, name = toplevel._cfgimpl_get_home_by_path(path)
                if who == 'default':
                    who2 = 'default'
                else:
                    who2 = 'required'
                homeconfig.setoption(name, reqvalue, who2)
        if value and self._suggests is not None:
            for path, reqvalue in self._suggests:
                toplevel = config._cfgimpl_get_toplevel()
                homeconfig, name = toplevel._cfgimpl_get_home_by_path(path)
                homeconfig.suggestoption(name, reqvalue)

        super(BoolOption, self).setoption(config, value, who)

    def add_optparse_option(self, argnames, parser, config):
        callback = BoolConfigUpdate(config, self, True)
        parser.add_option(help=self.doc+" %default",
                          action='callback',
                          callback=callback, *argnames)
        if not self.negation:
            return
        no_argnames = ["--" + _getnegation(argname.lstrip("-"))
                           for argname in argnames
                               if argname.startswith("--")]
        if len(no_argnames) == 0:
            no_argnames = ["--" + _getnegation(argname.lstrip("-"))
                               for argname in argnames]
        callback = BoolConfigUpdate(config, self, False)
        parser.add_option(help="unset option set by %s %%default" % (argname, ),
                          action='callback',
                          callback=callback, *no_argnames)


class IntOption(Option):
    opt_type = 'int'

    def __init__(self, name, doc, default=None, cmdline=DEFAULT_OPTION_NAME):
        super(IntOption, self).__init__(name, doc, cmdline)
        self.default = default

    def validate(self, value):
        try:
            int(value)
        except TypeError:
            return False
        return True

    def setoption(self, config, value, who):
        try:
            super(IntOption, self).setoption(config, int(value), who)
        except TypeError as e:
            raise ConfigError(*e.args)


class FloatOption(Option):
    opt_type = 'float'

    def __init__(self, name, doc, default=None, cmdline=DEFAULT_OPTION_NAME):
        super(FloatOption, self).__init__(name, doc, cmdline)
        self.default = default

    def validate(self, value):
        try:
            float(value)
        except TypeError:
            return False
        return True

    def setoption(self, config, value, who):
        try:
            super(FloatOption, self).setoption(config, float(value), who)
        except TypeError as e:
            raise ConfigError(*e.args)


class StrOption(Option):
    opt_type = 'string'

    def __init__(self, name, doc, default=None, cmdline=DEFAULT_OPTION_NAME):
        super(StrOption, self).__init__(name, doc, cmdline)
        self.default = default

    def validate(self, value):
        return isinstance(value, str)

    def setoption(self, config, value, who):
        try:
            super(StrOption, self).setoption(config, value, who)
        except TypeError as e:
            raise ConfigError(*e.args)


class ArbitraryOption(Option):
    def __init__(self, name, doc, default=None, defaultfactory=None):
        super(ArbitraryOption, self).__init__(name, doc, cmdline=None)
        self.default = default
        self.defaultfactory = defaultfactory
        if defaultfactory is not None:
            assert default is None

    def validate(self, value):
        return True

    def add_optparse_option(self, *args, **kwargs):
        return

    def getdefault(self):
        if self.defaultfactory is not None:
            return self.defaultfactory()
        return self.default


class OptionDescription(object):
    __metaclass__ = extendabletype

    cmdline = None

    def __init__(self, name, doc, children):
        self._name = name
        self.doc = doc
        self._children = children
        self._build()

    def _build(self):
        for child in self._children:
            setattr(self, child._name, child)

    def getkey(self, config):
        return tuple([child.getkey(getattr(config, child._name))
                      for child in self._children])

    def add_optparse_option(self, argnames, parser, config):
        return

    def getpaths(self, include_groups=False, currpath=None):
        """returns a list of all paths in self, recursively

            currpath should not be provided (helps with recursion)
        """
        if currpath is None:
            currpath = []
        paths = []
        for option in self._children:
            attr = option._name
            if attr.startswith('_cfgimpl'):
                continue
            value = getattr(self, attr)
            if isinstance(value, OptionDescription):
                if include_groups:
                    paths.append('.'.join(currpath + [attr]))
                currpath.append(attr)
                paths += value.getpaths(include_groups=include_groups,
                                        currpath=currpath)
                currpath.pop()
            else:
                paths.append('.'.join(currpath + [attr]))
        return paths


class OptHelpFormatter(optparse.TitledHelpFormatter):
    extra_useage = None

    def expand_default(self, option):
        assert self.parser
        dfls = self.parser.defaults
        defl = ""
        choices = None
        if option.action == 'callback' and isinstance(option.callback, ConfigUpdate):
            callback = option.callback
            defl = callback.help_default()
            if isinstance(callback.option, ChoiceOption):
                choices = callback.option.values
        else:
            val = dfls.get(option.dest)
            if val is None:
                pass
            elif isinstance(val, bool):
                if val is True and option.action=="store_true":
                    defl = "default"
            else:
                defl = "default: %s" % val

        if option.type == 'choice':
            choices = option.choices

        if choices is not None:
            choices = "%s=%s" % (option.metavar, '|'.join(choices))
        else:
            choices = ""

        if '%default' in option.help:
            if choices and defl:
                sep = ", "
            else:
                sep = ""
            defl = '[%s%s%s]' % (choices, sep, defl)
            if defl == '[]':
                defl = ""
            return option.help.replace("%default", defl)
        elif choices:
            return option.help + ' [%s]' % choices

        return option.help

    def format_usage(self, usage):
        # XXX bit of a hack
        result = optparse.TitledHelpFormatter.format_usage(self, usage)
        if self.extra_useage is not None:
            return result + "\n" + self.extra_useage + "\n\n"
        return result



class ConfigUpdate(object):

    def __init__(self, config, option):
        self.config = config
        self.option = option

    def convert_from_cmdline(self, value):
        return self.option.convert_from_cmdline(value)

    def __call__(self, option, opt_str, value, parser, *args, **kwargs):
        try:
            value = self.convert_from_cmdline(value)
            self.config.setoption(self.option._name, value, who='cmdline')
        except ConfigError as e:
            # This OptionValueError is going to exit the translate.py process.
            # Now is the last chance to print the warnings, which might give
            # more information...  hack.
            import sys
            for warning in self.config.get_warnings():
                print >> sys.stderr, warning
            raise optparse.OptionValueError(e.args[0])

    def help_default(self):
        default = getattr(self.config, self.option._name)
        owner = self.config._cfgimpl_value_owners[self.option._name]
        if default is None:
            if owner == 'default':
                return ''
            else:
                default = '???'
        return "%s: %s" % (owner, default)


class BoolConfigUpdate(ConfigUpdate):
    def __init__(self, config, option, which_value):
        super(BoolConfigUpdate, self).__init__(config, option)
        self.which_value = which_value

    def convert_from_cmdline(self, value):
        return self.which_value

    def help_default(self):
        default = getattr(self.config, self.option._name)
        owner = self.config._cfgimpl_value_owners[self.option._name]
        if default == self.which_value:
            return owner
        else:
            return ""


def to_optparse(config, useoptions=None, parser=None,
                parserargs=None, parserkwargs=None, extra_useage=None):
    grps = {}
    def get_group(name, doc):
        steps = name.split('.')
        if len(steps) < 2:
            return parser
        grpname = steps[-2]
        grp = grps.get(grpname, None)
        if grp is None:
            grp = grps[grpname] = parser.add_option_group(doc)
        return grp

    if parser is None:
        if parserargs is None:
            parserargs = []
        if parserkwargs is None:
            parserkwargs = {}
        formatter = OptHelpFormatter()
        formatter.extra_useage = extra_useage
        parser = optparse.OptionParser(
            formatter=formatter,
            *parserargs, **parserkwargs)
    if useoptions is None:
        useoptions = config.getpaths(include_groups=True)
    seen = {}
    for path in useoptions:
        if path.endswith(".*"):
            path = path[:-2]
            homeconf, name = config._cfgimpl_get_home_by_path(path)
            subconf = getattr(homeconf, name)
            children = [
                path + "." + child
                for child in subconf.getpaths()]
            useoptions.extend(children)
        else:
            if path in seen:
                continue
            seen[path] = True
            homeconf, name = config._cfgimpl_get_home_by_path(path)
            option = getattr(homeconf._cfgimpl_descr, name)
            if option.cmdline is DEFAULT_OPTION_NAME:
                chunks = ('--%s' % (path.replace('.', '-'),),)
            elif option.cmdline is None:
                continue
            else:
                chunks = option.cmdline.split(' ')
            grp = get_group(path, homeconf._cfgimpl_descr.doc)
            option.add_optparse_option(chunks, grp, homeconf)
    return parser


def make_dict(config):
    paths = config.getpaths()
    options = dict([(path, getattr(config, path)) for path in paths])
    return options

