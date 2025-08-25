var internal_variable: u32 = 42;
export const p_internal_variable = &internal_variable;

extern var external_variable: u32;
export const p_external_variable = &external_variable;

// compile
// output_mode=Obj
// backend=stage2,llvm
// target=x86_64-linux
