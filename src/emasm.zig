pub fn EM_ASM(comptime code: []const u8, args: anytype) void {
    _ = @call(.auto, emscripten_asm_const_int, .{ CODE_EXPR(code), EM_ASM_ARG_SIGS(args) } ++ args);
}

pub fn EM_ASM_INT(comptime code: []const u8, args: anytype) c_int {
    return @call(.auto, emscripten_asm_const_int, .{ CODE_EXPR(code), EM_ASM_ARG_SIGS(args) } ++ args);
}

pub fn EM_ASM_PTR(comptime code: []const u8, args: anytype) ?*anyopaque {
    return @call(.auto, emscripten_asm_const_ptr, .{ CODE_EXPR(code), EM_ASM_ARG_SIGS(args) } ++ args);
}

pub fn EM_ASM_DOUBLE(comptime code: []const u8, args: anytype) f64 {
    return @call(.auto, emscripten_asm_const_double, .{ CODE_EXPR(code), EM_ASM_ARG_SIGS(args) } ++ args);
}

extern fn emscripten_asm_const_int(code: [*:0]const u8, arg_sigs: [*:0]const u8, ...) c_int;
extern fn emscripten_asm_const_ptr(code: [*:0]const u8, arg_sigs: [*:0]const u8, ...) ?*anyopaque;
extern fn emscripten_asm_const_double(code: [*:0]const u8, arg_sigs: [*:0]const u8, ...) f64;

fn CODE_EXPR(comptime code: []const u8) [*:0]const u8 {
    return withSection("em_asm", code ++ "");
}

fn EM_ASM_ARG_SIGS(args: anytype) [*:0]const u8 {
    comptime var sigs: [args.len]u8 = undefined;
    inline for (&sigs, args) |*sig, arg| {
        const Arg = @TypeOf(arg);
        const bits = @bitSizeOf(Arg);
        sig.* = switch (@typeInfo(@TypeOf(arg))) {
            .bool, .int, .error_set, .@"enum" => if (bits <= 32) 'i' else if (bits <= 64) 'j' else 'p',
            .float => if (bits <= 32) 'f' else if (bits <= 64) 'd' else 'p',
            .@"struct" => |info| if (info.backing_integer != null) (if (bits <= 32) 'i' else if (bits <= 64) 'j' else 'p') else 'p',
            else => 'p',
        };
    }
    return &sigs ++ "";
}

pub fn withSection(comptime section: []const u8, comptime value: anytype) @TypeOf(&declareWithSection(section, value).x) {
    return &declareWithSection(section, value).x;
}

fn declareWithSection(comptime section: []const u8, comptime value: anytype) type {
    const info = @typeInfo(@TypeOf(value)).pointer;
    return struct {
        const x linksection(section) = switch (info.size) {
            .one => value,
            .slice => if (info.sentinel()) |s| value[0..value.len :s] else value[0..value.len],
            else => unreachable,
        }.*;
    };
}
