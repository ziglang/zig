// cmakedefine
// undefined
#cmakedefine noval unreachable

// 1
#cmakedefine trueval 1

// undefined
#cmakedefine falseval unreachable

// undefined
#cmakedefine zeroval unreachable

// 1
#cmakedefine oneval 1

// 1
#cmakedefine tenval 1

// 1
#cmakedefine stringval 1


// cmakedefine01
// 0
#cmakedefine01 boolnoval

// 1
#cmakedefine01 booltrueval

// 0
#cmakedefine01 boolfalseval

// 0
#cmakedefine01 boolzeroval

// 1
#cmakedefine01 booloneval

// 1
#cmakedefine01 booltenval

// 1
#cmakedefine01 boolstringval


// @ substition

// no substition
// @noval@

// no substition
// @noval@@noval@

// no substition
// @noval@.@noval@

// 1
// @trueval@

// 0
// @falseval@

// 10
// @trueval@@falseval@

// 0.1
// @falseval@.@trueval@

// 0
// @zeroval@

// 1
// @oneval@

// 10
// @tenval@

// 01
// @zeroval@@oneval@

// 0.10
// @zeroval@.@tenval@

// test
// @stringval@

// testtest
// @stringval@@stringval@

// test.test
// @stringval@.@stringval@

// test10
// @noval@@stringval@@trueval@@zeroval@

// ${} substition

// no substition
// ${noval}

// no substition
// ${noval}${noval}

// no substition
// ${noval}.${noval}

// 1
// ${trueval}

// 0
// ${falseval}

// 10
// ${trueval}${falseval}

// 0.1
// ${falseval}.${trueval}

// 0
// ${zeroval}

// 1
// ${oneval}

// 10
// ${tenval}

// 01
// ${zeroval}${oneval}

// 0.10
// ${zeroval}.${tenval}

// test
// ${stringval}

// testtest
// ${stringval}${stringval}

// test.test
// ${stringval}.${stringval}

// test10
// ${noval}${stringval}${trueval}${zeroval}
