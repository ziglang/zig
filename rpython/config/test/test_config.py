from rpython.config.config import *
import py, sys

def make_description():
    gcoption = ChoiceOption('name', 'GC name', ['ref', 'framework'], 'ref')
    gcdummy = BoolOption('dummy', 'dummy', default=False)
    booloption = BoolOption('bool', 'Test boolean option', default=True)
    intoption = IntOption('int', 'Test int option', default=0)
    floatoption = FloatOption('float', 'Test float option', default=2.3)
    stroption = StrOption('str', 'Test string option', default="abc")

    wantref_option = BoolOption('wantref', 'Test requires', default=False,
                                    requires=[('gc.name', 'ref')])
    wantframework_option = BoolOption('wantframework', 'Test requires',
                                      default=False,
                                      requires=[('gc.name', 'framework')])
    
    gcgroup = OptionDescription('gc', '', [gcoption, gcdummy, floatoption])
    descr = OptionDescription('pypy', '', [gcgroup, booloption,
                                           wantref_option, stroption,
                                           wantframework_option,
                                           intoption])
    return descr

def test_base_config():
    descr = make_description()
    config = Config(descr, bool=False)

    assert config.gc.name == 'ref'
    config.gc.name = 'framework'
    assert config.gc.name == 'framework'
    assert getattr(config, "gc.name") == 'framework'

    assert config.gc.float == 2.3
    assert config.int == 0
    config.gc.float = 3.4
    config.int = 123
    assert config.gc.float == 3.4
    assert config.int == 123

    assert not config.wantref

    assert config.str == "abc"
    config.str = "def"
    assert config.str == "def"

    py.test.raises(ConfigError, 'config.gc.name = "foo"')
    py.test.raises(AttributeError, 'config.gc.foo = "bar"')
    py.test.raises(ConfigError, 'config.bool = 123')
    py.test.raises(ConfigError, 'config.int = "hello"')
    py.test.raises(ConfigError, 'config.gc.float = None')

    config = Config(descr, bool=False)
    assert config.gc.name == 'ref'
    config.wantframework = True
    py.test.raises(ConfigError, 'config.gc.name = "ref"')
    config.gc.name = "framework"

def test___dir__():
    descr = make_description()
    config = Config(descr, bool=False)
    attrs = dir(config)
    assert '__repr__' in attrs        # from the type
    assert '_cfgimpl_values' in attrs # from self
    if sys.version_info >= (2, 6):
        assert 'gc' in attrs              # custom attribute
    #
    attrs = dir(config.gc)
    if sys.version_info >= (2, 6):
        assert 'name' in attrs
        assert 'dummy' in attrs
        assert 'float' in attrs

def test_arbitrary_option():
    descr = OptionDescription("top", "", [
        ArbitraryOption("a", "no help", default=None)
    ])
    config = Config(descr)
    config.a = []
    config.a.append(1)
    assert config.a == [1]

    descr = OptionDescription("top", "", [
        ArbitraryOption("a", "no help", defaultfactory=list)
    ])
    c1 = Config(descr)
    c2 = Config(descr)
    c1.a.append(1)
    assert c2.a == []
    assert c1.a == [1]

def test_annotator_folding():
    from rpython.translator.interactive import Translation

    gcoption = ChoiceOption('name', 'GC name', ['ref', 'framework'], 'ref')
    gcgroup = OptionDescription('gc', '', [gcoption])
    descr = OptionDescription('pypy', '', [gcgroup])
    config = Config(descr)
    
    def f(x):
        if config.gc.name == 'ref':
            return x + 1
        else:
            return 'foo'

    t = Translation(f, [int])
    t.rtype()
    
    block = t.context.graphs[0].startblock
    assert len(block.exits[0].target.operations) == 0
    assert len(block.operations) == 1
    assert len(block.exits) == 1
    assert block.operations[0].opname == 'int_add'

    assert config._freeze_()
    # does not raise, since it does not change the attribute
    config.gc.name = "ref"
    py.test.raises(TypeError, 'config.gc.name = "framework"')

def test_compare_configs():
    descr = make_description()
    conf1 = Config(descr)
    conf2 = Config(descr, wantref=True)
    assert conf1 != conf2
    assert hash(conf1) != hash(conf2)
    assert conf1.getkey() != conf2.getkey()
    conf1.wantref = True
    assert conf1 == conf2
    assert hash(conf1) == hash(conf2)
    assert conf1.getkey() == conf2.getkey()

def test_loop():
    descr = make_description()
    conf = Config(descr)
    for (name, value), (gname, gvalue) in \
        zip(conf.gc, [("name", "ref"), ("dummy", False)]):
        assert name == gname
        assert value == gvalue
        
def test_to_optparse():
    gcoption = ChoiceOption('name', 'GC name', ['ref', 'framework'], 'ref',
                                cmdline='--gc -g')
    gcgroup = OptionDescription('gc', '', [gcoption])
    descr = OptionDescription('pypy', '', [gcgroup])
    config = Config(descr)
    
    parser = to_optparse(config, ['gc.name'])
    (options, args) = parser.parse_args(args=['--gc=framework'])
    
    assert config.gc.name == 'framework'
    

    config = Config(descr)
    parser = to_optparse(config, ['gc.name'])
    (options, args) = parser.parse_args(args=['-g ref'])
    assert config.gc.name == 'ref'

    # XXX strange exception
    py.test.raises(SystemExit,
                    "(options, args) = parser.parse_args(args=['-g foobar'])")

def test_to_optparse_number():
    intoption = IntOption('int', 'Int option test', cmdline='--int -i')
    floatoption = FloatOption('float', 'Float option test', 
                                cmdline='--float -f')
    descr = OptionDescription('test', '', [intoption, floatoption])
    config = Config(descr)

    parser = to_optparse(config, ['int', 'float'])
    (options, args) = parser.parse_args(args=['-i 2', '--float=0.1'])

    assert config.int == 2
    assert config.float == 0.1
    
    py.test.raises(SystemExit,
        "(options, args) = parser.parse_args(args=['--int=foo', '-f bar'])")
    
def test_to_optparse_bool():
    booloption1 = BoolOption('bool1', 'Boolean option test', default=False,
                             cmdline='--bool1 -b')
    booloption2 = BoolOption('bool2', 'Boolean option test', default=True,
                             cmdline='--with-bool2 -c')
    booloption3 = BoolOption('bool3', 'Boolean option test', default=True,
                             cmdline='--bool3')
    booloption4 = BoolOption('bool4', 'Boolean option test', default=True,
                             cmdline='--bool4', negation=False)
    descr = OptionDescription('test', '', [booloption1, booloption2,
                                           booloption3, booloption4])
    config = Config(descr)

    parser = to_optparse(config, ['bool1', 'bool2'])
    (options, args) = parser.parse_args(args=['-b'])

    assert config.bool1
    assert config.bool2

    config = Config(descr)
    parser = to_optparse(config, ['bool1', 'bool2', 'bool3', 'bool4'])
    (options, args) = parser.parse_args(args=['--without-bool2', '--no-bool3',
                                              '--bool4'])
    assert not config.bool1
    assert not config.bool2
    assert not config.bool3

    py.test.raises(SystemExit,
            "(options, args) = parser.parse_args(args=['-bfoo'])")
    py.test.raises(SystemExit,
            "(options, args) = parser.parse_args(args=['--no-bool4'])")

def test_config_start():
    descr = make_description()
    config = Config(descr)
    parser = to_optparse(config, ["gc.*"])

    options, args = parser.parse_args(args=["--gc-name=framework", "--gc-dummy"])
    assert config.gc.name == "framework"
    assert config.gc.dummy

def test_star_works_recursively():
    descr = OptionDescription("top", "", [
        OptionDescription("a", "", [
            BoolOption("b1", "", default=False, cmdline="--b1"),
            OptionDescription("sub", "", [
                BoolOption("b2", "", default=False, cmdline="--b2")
            ])
        ]),
        BoolOption("b3", "", default=False, cmdline="--b3"),
    ])
    config = Config(descr)
    assert not config.a.b1
    assert not config.a.sub.b2
    parser = to_optparse(config, ['a.*'])
    options, args = parser.parse_args(args=["--b1", "--b2"])
    assert config.a.b1
    assert config.a.sub.b2
    py.test.raises(SystemExit,
            "(options, args) = parser.parse_args(args=['--b3'])")

    config = Config(descr)
    assert not config.a.b1
    assert not config.a.sub.b2
    # does not lead to an option conflict
    parser = to_optparse(config, ['a.*', 'a.sub.*']) 
    options, args = parser.parse_args(args=["--b1", "--b2"])
    assert config.a.b1
    assert config.a.sub.b2
    
def test_optparse_path_options():
    gcoption = ChoiceOption('name', 'GC name', ['ref', 'framework'], 'ref')
    gcgroup = OptionDescription('gc', '', [gcoption])
    descr = OptionDescription('pypy', '', [gcgroup])
    config = Config(descr)
    
    parser = to_optparse(config, ['gc.name'])
    (options, args) = parser.parse_args(args=['--gc-name=framework'])

    assert config.gc.name == 'framework'

def test_getpaths():
    descr = make_description()
    config = Config(descr)
    
    assert config.getpaths() == ['gc.name', 'gc.dummy', 'gc.float', 'bool',
                                 'wantref', 'str', 'wantframework',
                                 'int']
    assert config.getpaths() == descr.getpaths()
    assert config.gc.getpaths() == ['name', 'dummy', 'float']
    assert config.gc.getpaths() == descr.gc.getpaths()
    assert config.getpaths(include_groups=True) == [
        'gc', 'gc.name', 'gc.dummy', 'gc.float',
        'bool', 'wantref', 'str', 'wantframework', 'int']
    assert config.getpaths(True) == descr.getpaths(True)

def test_underscore_in_option_name():
    descr = OptionDescription("opt", "", [
        BoolOption("_foobar", "", default=False),
    ])
    config = Config(descr)
    parser = to_optparse(config)
    assert parser.has_option("--_foobar")

def test_none():
    dummy1 = BoolOption('dummy1', 'doc dummy', default=False, cmdline=None)
    dummy2 = BoolOption('dummy2', 'doc dummy', default=False, cmdline='--dummy')
    group = OptionDescription('group', '', [dummy1, dummy2])
    config = Config(group)

    parser = to_optparse(config)
    py.test.raises(SystemExit,
        "(options, args) = parser.parse_args(args=['--dummy1'])")
 
def test_requirements_from_top():
    descr = OptionDescription("test", '', [
        BoolOption("toplevel", "", default=False),
        OptionDescription("sub", '', [
            BoolOption("opt", "", default=False,
                       requires=[("toplevel", True)])
        ])
    ])
    config = Config(descr)
    config.sub.opt = True
    assert config.toplevel

def test_requirements_for_choice():
    descr = OptionDescription("test", '', [
        BoolOption("toplevel", "", default=False),
        OptionDescription("s", '', [
            ChoiceOption("type_system", "", ["ll", "oo"], "ll"),
            ChoiceOption("backend", "",
                         ["c", "cli"], "c",
                         requires={
                             "c": [("s.type_system", "ll"),
                                   ("toplevel", True)],
                             "cli": [("s.type_system", "oo")],
                         })
        ])
    ])
    config = Config(descr)
    config.s.backend = "cli"
    assert config.s.type_system == "oo"

def test_choice_with_no_default():
    descr = OptionDescription("test", "", [
        ChoiceOption("backend", "", ["c", "cli"])])
    config = Config(descr)
    assert config.backend is None
    config.backend = "c"

def test_overrides_are_defaults():
    descr = OptionDescription("test", "", [
        BoolOption("b1", "", default=False, requires=[("b2", False)]),
        BoolOption("b2", "", default=False),
        ])
    config = Config(descr, b2=True)
    assert config.b2
    config.b1 = True
    assert not config.b2
    print config._cfgimpl_value_owners

def test_overrides_require_as_default():
    descr = OptionDescription("test", "", [
        ChoiceOption("backend", "", ['c', 'cli'], 'c',
                     requires={'c': [('type_system', 'll')],
                               'cli': [('type_system', 'oo')]}),
        ChoiceOption("type_system", "", ['ll', 'oo'], 'll')
        ])
    config = Config(descr, backend='c')
    config.set(backend=None, type_system=None)
    config = Config(descr, backend='c')
    config.set(backend='cli')
    assert config.backend == 'cli'
    assert config.type_system == 'oo'

def test_overrides_require_as_default_boolopt():
    descr = OptionDescription("test", "", [
        BoolOption("backend", "", default=False,
                   requires=[('type_system', True)]),
        BoolOption("type_system", "", default=False)
        ])
    config = Config(descr, backend=True)
    config.set(backend=False)
    config.set(type_system=False)
    assert config.backend == False
    assert config.type_system == False

def test_overrides_dont_change_user_options():
    descr = OptionDescription("test", "", [
        BoolOption("b", "", default=False)])
    config = Config(descr)
    config.b = True
    config.override({'b': False})
    assert config.b
    
def test_str():
    descr = make_description()
    c = Config(descr)
    print c # does not crash

def test_dwim_set():
    descr = OptionDescription("opt", "", [
        OptionDescription("sub", "", [
            BoolOption("b1", ""),
            ChoiceOption("c1", "", ['a', 'b', 'c'], 'a'),
            BoolOption("d1", ""),
        ]),
        BoolOption("b2", ""),
        BoolOption("d1", ""),
    ])
    c = Config(descr)
    c.set(b1=False, c1='b')
    assert not c.sub.b1
    assert c.sub.c1 == 'b'
    # new config, because you cannot change values once they are set
    c = Config(descr)
    c.set(b2=False, **{'sub.c1': 'c'})
    assert not c.b2
    assert c.sub.c1 == 'c'
    py.test.raises(AmbigousOptionError, "c.set(d1=True)")
    py.test.raises(NoMatchingOptionFound, "c.set(unknown='foo')")

def test_more_set():
    descr = OptionDescription("opt", "", [
        OptionDescription("s1", "", [
            BoolOption("a", "", default=False)]),
        IntOption("int", "", default=42)])
    d = {'s1.a': True, 'int': 23}
    config = Config(descr)
    config.set(**d)
    assert config.s1.a
    assert config.int == 23

def test_optparse_help():
    import cStringIO
    descr = OptionDescription("opt", "", [
        BoolOption("bool1", 'do bool1', default=False, cmdline='--bool1'),
        BoolOption("bool2", 'do bool2', default=False, cmdline='--bool2', negation=False),
        BoolOption("bool3", 'do bool3', default=True, cmdline='--bool3'),
        ChoiceOption("choice", "choose!", ['a', 'b', 'c'], 'a', '--choice'),
        ChoiceOption("choice2", "choose2!", ['x', 'y', 'z'], None, '--choice2'),
        StrOption("str", 'specify xyz', default='hello', cmdline='--str'),
    ])
    conf = Config(descr)
    parser = to_optparse(conf)
    out = cStringIO.StringIO()
    parser.print_help(out)
    help = out.getvalue()
    #print help
    assert "do bool1\n" in help
    assert "unset option set by --bool1 [default]" in help
    assert "do bool2\n" in help
    assert "do bool3 [default]" in help
    assert "choose! [CHOICE=a|b|c, default: a]" in help
    assert "choose2! [CHOICE2=x|y|z]" in help
    assert "specify xyz [default: hello]" in help

def test_make_dict():
    descr = OptionDescription("opt", "", [
        OptionDescription("s1", "", [
            BoolOption("a", "", default=False)]),
        IntOption("int", "", default=42)])
    config = Config(descr)
    d = make_dict(config)
    assert d == {"s1.a": False, "int": 42}
    config.int = 43
    config.s1.a = True
    d = make_dict(config)
    assert d == {"s1.a": True, "int": 43}

def test_copy():
    descr = OptionDescription("opt", "", [
        OptionDescription("s1", "", [
            BoolOption("a", "", default=False)]),
        IntOption("int", "", default=42)])
    c1 = Config(descr)
    c1.int = 43
    c2 = c1.copy()
    assert c2.int == 43
    assert not c2.s1.a
    c2.s1.a = True
    assert c2.s1.a
    py.test.raises(ConfigError, "c2.int = 44")
    c2 = c1.copy(as_default=True)
    assert c2.int == 43
    assert not c2.s1.a
    c2.s1.a = True
    assert c2.s1.a
    c2.int = 44 # does not crash

def test_bool_suggests():
    descr = OptionDescription("test", '', [
        BoolOption("toplevel", "", default=False),
        BoolOption("opt", "", default=False,
                   suggests=[("toplevel", True)])
    ])
    c = Config(descr)
    assert not c.toplevel
    assert not c.opt
    c.opt = True
    assert c.opt
    assert c.toplevel
    # does not crash
    c.toplevel = False
    assert not c.toplevel

    c = Config(descr)
    c.toplevel = False
    assert not c.toplevel
    # does not crash
    c.opt = True
    assert c.opt
    assert not c.toplevel

def test_suggests_can_fail():
    descr = OptionDescription("test", '', [
        BoolOption("t1", "", default=False),
        BoolOption("t2", "", default=False,
                   requires=[("t3", True)]),
        BoolOption("t3", "", default=False),
        BoolOption("opt", "", default=False,
                   suggests=[("t1", True), ("t2", True)])
    ])
    c = Config(descr)
    assert not c.t1
    assert not c.t2
    assert not c.t3
    assert not c.opt
    c.opt = True
    assert c.opt
    assert c.t1
    assert c.t2
    assert c.t3
    # does not crash
    c.t2 = False
    assert not c.t2

    c = Config(descr)
    c.t3 = False
    assert not c.t3
    # does not crash
    c.opt = True
    assert c.opt
    assert not c.t3
    assert not c.t2

def test_suggests_can_fail_choiceopt():
    # this is what occurs in "./translate.py --gcrootfinder=asmgcc --jit"
    # with --jit suggesting the boehm gc, but --gcrootfinder requiring the
    # framework gctransformer.
    descr = OptionDescription("test", '', [
        ChoiceOption("t1", "", ["a", "b"], default="a"),
        ChoiceOption("t2", "", ["c", "d"], default="c",
                     requires={"d": [("t3", "f")]}),
        ChoiceOption("t3", "", ["e", "f"], default="e"),
        ChoiceOption("opt", "", ["g", "h"], default="g",
                     suggests={"h": [("t1", "b"), ("t2", "d")]})
    ])
    c = Config(descr)
    assert c.t1 == 'a'
    assert c.t2 == 'c'
    assert c.t3 == 'e'
    assert c.opt == 'g'
    c.opt = "h"
    assert c.opt == 'h'
    assert c.t1 == 'b'
    assert c.t2 == 'd'
    assert c.t3 == 'f'
    # does not crash
    c.t2 = 'c'
    assert c.t2 == 'c'

    c = Config(descr)
    c.t3 = 'e'
    assert c.t3 == 'e'
    # does not crash
    c.opt = 'h'
    assert c.opt == 'h'
    assert c.t3 == 'e'
    assert c.t2 == 'c'


def test_choice_suggests():
    descr = OptionDescription("test", '', [
        BoolOption("toplevel", "", default=False),
        ChoiceOption("opt", "", ["a", "b", "c"],
                     "a",
                     suggests={"b": [("toplevel", True)]})
    ])
    c = Config(descr)
    assert not c.toplevel
    assert c.opt == "a"
    c.opt = "b"
    assert c.opt == "b"
    assert c.toplevel
    # does not crash
    c.toplevel = False
    assert not c.toplevel

    c = Config(descr)
    c.toplevel = False
    assert not c.toplevel
    # does not crash
    c.opt = "b"
    assert c.opt == "b"
    assert not c.toplevel


def test_bogus_suggests():
    descr = OptionDescription("test", '', [
        BoolOption("toplevel", "", suggests=[("opt", "bogusvalue")]),
        ChoiceOption("opt", "", ["a", "b", "c"], "a"),
    ])
    c = Config(descr)
    py.test.raises(ConfigError, "c.toplevel = True")


def test_delattr():
    descr = OptionDescription("opt", "", [
    OptionDescription("s1", "", [
        BoolOption("a", "", default=False)]),
    IntOption("int", "", default=42)])
    c = Config(descr)
    c.int = 45
    assert c.int == 45
    del c.int
    assert c.int == 42
    c.int = 45
    assert c.int == 45

def test_validator():
    def my_validator_1(config):
        assert config is c

    def my_validator_2(config):
        assert config is c
        raise ConflictConfigError

    descr = OptionDescription("opt", "", [
        BoolOption('booloption1', 'option test1', default=False,
                   validator=my_validator_1),
        BoolOption('booloption2', 'option test2', default=False,
                   validator=my_validator_2),
        BoolOption('booloption3', 'option test3', default=False,
                   requires=[("booloption2", True)]),
        BoolOption('booloption4', 'option test4', default=False,
                   suggests=[("booloption2", True)]),
        ])
    c = Config(descr)
    c.booloption1 = True
    py.test.raises(ConfigError, "c.booloption2 = True")
    assert c.booloption2 is False
    py.test.raises(ConfigError, "c.booloption3 = True")
    assert c.booloption2 is False
    c.booloption4 = True
    assert c.booloption2 is False
    c.booloption2 = False
    assert c.booloption2 is False

def test_suggested_owner_does_not_override():
    descr = OptionDescription("test", '', [
        BoolOption("toplevel", "", default=False),
        BoolOption("opt", "", default=False,
                   suggests=[("toplevel", False)]),
        BoolOption("opt2", "", default=False,
                   suggests=[("toplevel", True)]),
    ])
    c = Config(descr)
    c.toplevel = False
    c.opt = True      # bug: sets owner of toplevel back to 'suggested'
    c.opt2 = True     # and this overrides toplevel because it's only suggested
    assert c.toplevel == False
    assert c.opt == True
    assert c.opt2 == True
