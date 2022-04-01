from pypy.module._cppyy import helper

def test_remove_const():
    assert helper.remove_const("const int") == "int"

    assert helper.remove_const("const some_class*") == "some_class*"
    assert helper.remove_const("const some_class const*") == "some_class*"
    assert helper.remove_const("some_class const*const") == "some_class*"

    assert helper.remove_const("const some_class<const aap>*") == "some_class<const aap>*"
    assert helper.remove_const("const some_class<const aap> const*") == "some_class<const aap>*"
    assert helper.remove_const("some_class const<const aap*const>*const") == "some_class<const aap*const>*"

def test_compound():
    assert helper.compound("int*") == "*"
    assert helper.compound("int* const *&") == "**&"
    assert helper.compound("std::vector<int>*") == "*"
    assert helper.compound("unsigned long int[5]") == "[]"
    assert helper.array_size("unsigned long int[5]") == 5


def test_array_size():
    assert helper.array_size("int[5]") == 5


def test_clean_type():
    assert helper.clean_type(" int***") == "int"
    assert helper.clean_type("int* const *&") == "int"
    assert helper.clean_type("std::vector<int>&") == "std::vector<int>"
    assert helper.clean_type("const std::vector<int>&") == "std::vector<int>"
    assert helper.clean_type("std::vector<std::vector<int> >" ) == "std::vector<std::vector<int> >"
    assert helper.clean_type("unsigned short int[3]") == "unsigned short int"


def test_operator_mapping():
    assert helper.map_operator_name(None, "operator[]", 1, "const int&")  == "__getitem__"
    assert helper.map_operator_name(None, "operator[]", 1, "int&")        == "__setitem__"

    assert helper.map_operator_name(None, "operator()", 1, "")  == "__call__"
    assert helper.map_operator_name(None, "operator%", 1, "")   == "__mod__"
    assert helper.map_operator_name(None, "operator**", 1, "")  == "__pow__"
    assert helper.map_operator_name(None, "operator<<", 1, "")  == "__lshift__"
    assert helper.map_operator_name(None, "operator|", 1, "")   == "__or__"

    assert helper.map_operator_name(None, "operator*", 1, "") == "__mul__"
    assert helper.map_operator_name(None, "operator*", 0, "") == "__deref__"

    assert helper.map_operator_name(None, "operator+", 1, "") == "__add__"
    assert helper.map_operator_name(None, "operator+", 0, "") == "__pos__"

    assert helper.map_operator_name(None, "func", 0, "")        == "func"
    assert helper.map_operator_name(None, "some_method", 0, "") == "some_method"


def test_namespace_extraction():
    from pypy.module._cppyy import pythonify

    assert pythonify.extract_namespace("vector")[0]                     == ""
    assert pythonify.extract_namespace("std::vector")[0]                == "std"
    assert pythonify.extract_namespace("std::vector<double>")[0]        == "std"
    assert pythonify.extract_namespace("std::vector<std::vector>")[0]   == "std"
    assert pythonify.extract_namespace("vector<double>")[0]             == ""
    assert pythonify.extract_namespace("vector<std::vector>")[0]        == ""
    assert pythonify.extract_namespace("aap::noot::mies::zus")[0]       == "aap::noot::mies"
