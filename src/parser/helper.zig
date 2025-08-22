const std = @import("std");
const Tuple = std.meta.Tuple;
const Allocator = std.mem.Allocator;

const mecha = @import("mecha");
const Result = mecha.Result;
const ascii = mecha.ascii;
const oneOf = mecha.oneOf;
const combine = mecha.combine;
const manyN = mecha.manyN;

const any = mecha.Parser(u8){
    .parse = struct {
        const Res = Result(u8);
        fn parse(_: Allocator, str: []const u8) !Res {
            return if (str.len != 0)
                Res.ok(1, str[0])
            else
                Res.err(0);
        }
    }.parse,
};

pub const Magic = enum {
    legacy,
    extended,
};

pub const magic = leU16.convert(struct {
    fn map(_: Allocator, n: u16) !Magic {
        return switch (n) {
            0x11A => .legacy,
            0x21E => .extended,
            else => error.ConversionFailed,
        };
    }
}.map);

pub const leU16 = manyN(any, 2, .{}).map(struct {
    fn map(combined: [2]u8) u16 {
        var a: u16 = undefined;
        var b: u16 = undefined;
        a, b = combined;
        return a + b * 256;
    }
}.map);

pub const leI16 = leU16.map(struct {
    fn map(n: u16) i16 {
        return if (n <= 0x7fff)
            @as(i16, @bitCast(n))
        else
            -1;
    }
}.map);

pub const leU32 = manyN(any, 4, .{}).map(struct {
    fn map(combined: [4]u8) u32 {
        var a: u32 = undefined;
        var b: u32 = undefined;
        var c: u32 = undefined;
        var d: u32 = undefined;
        a, b, c, d = combined;
        return a + b * 256 + c * 256 * 256 + d * 256 * 256 * 256;
    }
}.map);

pub const leI32 = leU32.map(struct {
    fn map(n: u32) i32 {
        return if (n <= 0x7fffffff)
            @as(i32, @bitCast(n))
        else
            -1;
    }
}.map);
