const std = @import("std");
const assert = @import("std").debug.assert;

pub const Macho64_Header64 = struct {
    magic: u32,
    cputype: u32,
    cpusubtype: u32,
    filetype: u32,
    ncmds: u32,
    sizeofcmds: u32,
    flags: u32,
    reserved: u32
};

pub const Macho64_Header32 = struct {
    magic: u32, 
    cputype: u32, 
    cpusubtype: u32, 
    filetype: u32, 
    ncmds: u32, 
    sizeofcmds: u32,
    flags: u32
};

pub const MACHO_MAGIC_64: u32 = 0xfeedfacf;

// Constants for the filetype field of the mach_header
pub const MH_OBJECT: u32 = 0x1;    
pub const MH_EXECUTE: u32 = 0x2;     
pub const MH_FVMLIB: u32 = 0x3;     
pub const MH_CORE: u32 = 0x4;    
pub const MH_PRELOAD: u32 = 0x5;   
pub const MH_DYLIB: u32 = 0x6;
pub const MH_DYLINKER: u32 = 0x7;  
pub const MH_BUNDLE: u32 = 0x8;
pub const MH_DYLIB_STUB: u32 = 0x9; 
pub const MH_DSYM: u32 = 0xa;
pub const MH_KEXT_BUNDLE: u32 = 0xb; 

// Constants for the flags field of the mach_header 
pub const MH_NOUNDEFS: u32 = 0x1;
pub const MH_INCRLINK: u32 = 0x2;
pub const MH_DYLDLINK: u32 = 0x4;
pub const MH_BINDATLOAD: u32 = 0x8;
pub const MH_PREBOUND: u32 = 0x10;
pub const MH_SPLIT_SEGS: u32 = 0x20;
pub const MH_LAZY_INIT: u32 = 0x40;
pub const MH_TWOLEVEL: u32 = 0x80;
pub const MH_FORCE_FLAT: u32 = 0x100;
pub const MH_NOMULTIDEFS: u32 = 0x200;
pub const MH_NOFIXPREBINDING: u32 = 0x400;
pub const MH_PREBINDABLE: u32 = 0x800;
pub const MH_ALLMODSBOUND: u32 = 0x1000;
pub const MH_SUBSECTIONS_VIA_SYMBOLS: u32 = 0x2000;
pub const MH_CANONICAL: u32 = 0x4000;
pub const MH_WEAK_DEFINES: u32 = 0x8000;
pub const MH_BINDS_TO_WEAK: u32 = 0x10000;
pub const MH_ALLOW_STACK_EXECUTION: u32 = 0x20000;
pub const MH_ROOT_SAFE: u32 =  0x40000;
pub const MH_SETUID_SAFE: u32 = 0x80000;
pub const MH_NO_REEXPORTED_DYLIBS: u32 = 0x100000;
pub const MH_PIE: u32 = 0x200000;
pub const MH_DEAD_STRIPPABLE_DYLIB: u32 = 0x400000;
pub const MH_HAS_TLV_DESCRIPTORS: u32 = 0x800000;
pub const MH_NO_HEAP_EXECUTION: u32 = 0x1000000;


pub const Load_Command = struct {
    cmd: u32,    
    cmdsize: u32
};

pub const Symtab_Command = struct {
    cmd: u32,       
    cmdsize: u32,  
    symoff: u32,       
    nsyms: u32,    
    stroff: u32,        
    strsize: u32  
};

const Segment_Command_64 = struct { 
    cmd: u32,       
    cmdsize: u32,   
    segname: u8[16],
    vmaddr: u64,        
    vmsize: u64,        
    fileoff: u64,   
    filesize: u64,  
    maxprot: u32,   
    initprot: u32,  
    nsects: u32,        
    flags: u32,     
};

const Segment_Command_32 = struct { 
    cmd: u32,       
    cmdsize: u32,   
    segname: u8[16],
    vmaddr: u32,        
    vmsize: u32,        
    fileoff: u32,   
    filesize: u32,  
    maxprot: u32,   
    initprot: u32,  
    nsects: u32,        
    flags: u32,     
};

//  Constants for the flags field of the segment_command 
pub const SG_HIGHVM: u32 = 0x1;
pub const SG_FVMLIB: u32 = 0x2;
pub const SG_NORELOC: u32 = 0x4;
pub const SG_PROTECTED_VERSION_1: u32 = 0x8; 

// Values for N_TYPE bits of the n_type field.
pub const N_STAB: u32 = 0xe0; 
pub const N_PEXT: u32 = 0x10;
pub const N_TYPE: u32 = 0x0e;  
pub const N_EXT: u32 = 0x01;
pub const N_UNDF: u32 = 0x0;  
pub const N_ABS: u32 = 0x2;   
pub const N_SECT: u32 = 0xe;     
pub const N_PBUD: u32 = 0xc;    
pub const N_INDR: u32 = 0xa;    

pub const Nlist_64 = struct { 
    n_strx: u32, 
    n_type: u8,
    n_sect: u8, 
    n_desc: u16, 
    n_value: u64 
};

pub const Section_64 = struct { 
    sectname: u8[16],  
    segname: u8[16],   
    addr: u64,       
    size: u64,       
    offset: u32,     
    salign: u32,      
    reloff: u32,     
    nreloc: u32,     
    flags: u32,      
    reserved1: u32,  
    reserved2: u32,  
    reserved3: u32 
};

pub const Section_32 = struct { 
    sectname: u8[16],  
    segname: u8[16],   
    addr: u32,       
    size: u32,       
    offset: u32,     
    salign: u32,      
    reloff: u32,     
    nreloc: u32,     
    flags: u32,      
    reserved1: u32,  
    reserved2: u32,  
    reserved3: u32
};

// Flags for section type
pub const SECTION_TYPE = 0x000000ff;
pub const SECTION_ATTRIBUTES = 0xffffff00;
pub const S_REGULAR = 0x0; 
pub const S_ZEROFILL = 0x1; 
pub const S_CSTRING_LITERALS = 0x2;
pub const S_4BYTE_LITERALS = 0x3;
pub const S_8BYTE_LITERALS = 0x4;
pub const S_LITERAL_POINTERS = 0x5;
                    
pub const Relocation = struct {
    r_address: i32, 
    r_symbolnum: u24, 
    r_pcrel: u1,
    r_length: u2,
    r_extern: u1,
    r_type: u4
};

pub const INDIRECT_SYMBOL_LOCAL: u32 = 0x80000000;
pub const INDIRECT_SYMBOL_ABS: u32 = 0x40000000;

pub const Dylib_Table_Of_Contents = struct {
    symbol_index: u32,  
    module_index: u32
};  

pub const Dylib_Module_32 = struct {
    module_name: u32,   
    iextdefsym: u32,
    nextdefsym: u32,    
    irefsym: u32,     
    nrefsym: u32,       
    ilocalsym: u32,     
    nlocalsym: u32,     
    iextrel: u32,       
    nextrel: u32,       
    iinit_iterm: u32,   
    ninit_nterm: u32,  
    objc_module_info_addr: u32,  
    objc_module_info_size: u32
};  

pub const Dylib_Module_64 = struct {
    module_name:u32,   
    iextdefsym: u32,    
    nextdefsym: u32,    
    irefsym: u32,       
    nrefsym: u32,       
    ilocalsym: u32,     
    nlocalsym: u32,     
    iextrel: u32,       
    nextrel: u32,       
    iinit_iterm: u32,   
    ninit_nterm: u32,     
    objc_module_info_size: u32,  
    objc_module_info_addr: u64
};

pub const Dylib_Reference = struct {
    isym: u24,       
    flags: u8;  
};

pub const Version_Min_Command = struct {
    cmd: u32,      
    cmdsize: u32,   
    version: u32,  
    reserved: u32  
};

test "sizes of headers" {
    assert(@sizeOf(Macho64_Header64) == 32);
    assert(@sizeOf(Macho64_Header32) == 28);
}