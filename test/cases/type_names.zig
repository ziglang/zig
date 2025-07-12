const namespace = struct {
    const S = struct {};
    const E = enum {};
    const U = union {};
    const O = opaque {};
};
export fn declarationValue() void {
    @compileLog(@typeName(namespace.S));
    @compileLog(@typeName(namespace.E));
    @compileLog(@typeName(namespace.U));
    @compileLog(@typeName(namespace.O));
}

export fn localVarValue() void {
    const S = struct {};
    const E = enum {};
    const U = union {};
    const O = opaque {};
    @compileLog(@typeName(S));
    @compileLog(@typeName(E));
    @compileLog(@typeName(U));
    @compileLog(@typeName(O));
}

fn MakeS() type {
    return struct {};
}
fn MakeE() type {
    return enum {};
}
fn MakeU() type {
    return union {};
}
fn MakeO() type {
    return opaque {};
}

export fn returnValue() void {
    @compileLog(@typeName(MakeS()));
    @compileLog(@typeName(MakeE()));
    @compileLog(@typeName(MakeU()));
    @compileLog(@typeName(MakeO()));
}

const StructInStruct = struct { a: struct { b: u8 } };
const UnionInStruct = struct { a: union { b: u8 } };
const StructInUnion = union { a: struct { b: u8 } };
const UnionInUnion = union { a: union { b: u8 } };
const InnerStruct = struct { b: u8 };
const StructInTuple = struct { a: InnerStruct };
const InnerUnion = union { b: u8 };
const UnionInTuple = struct { a: InnerUnion };

export fn nestedTypes() void {
    @compileLog(@typeName(StructInStruct));
    @compileLog(@typeName(UnionInStruct));
    @compileLog(@typeName(StructInUnion));
    @compileLog(@typeName(UnionInUnion));
    @compileLog(@typeName(StructInTuple));
    @compileLog(@typeName(UnionInTuple));
}

// error
//
// :8:5: error: found compile log statement
// :19:5: note: also here
// :39:5: note: also here
// :55:5: note: also here
//
//Compile Log Output:
//@as(*const [22:0]u8, "type_names.namespace.S")
//@as(*const [22:0]u8, "type_names.namespace.E")
//@as(*const [22:0]u8, "type_names.namespace.U")
//@as(*const [22:0]u8, "type_names.namespace.O")
//@as(*const [26:0]u8, "type_names.localVarValue.S")
//@as(*const [26:0]u8, "type_names.localVarValue.E")
//@as(*const [26:0]u8, "type_names.localVarValue.U")
//@as(*const [26:0]u8, "type_names.localVarValue.O")
//@as(*const [18:0]u8, "type_names.MakeS()")
//@as(*const [18:0]u8, "type_names.MakeE()")
//@as(*const [18:0]u8, "type_names.MakeU()")
//@as(*const [18:0]u8, "type_names.MakeO()")
//@as(*const [25:0]u8, "type_names.StructInStruct")
//@as(*const [24:0]u8, "type_names.UnionInStruct")
//@as(*const [24:0]u8, "type_names.StructInUnion")
//@as(*const [23:0]u8, "type_names.UnionInUnion")
//@as(*const [24:0]u8, "type_names.StructInTuple")
//@as(*const [23:0]u8, "type_names.UnionInTuple")
