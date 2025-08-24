const Database = @import("Database.zig");

const capabilities = @import("capability.zig");
const BooleanCapability = capabilities.BooleanCapability;
const NumberCapability = capabilities.NumberCapability;
const StringCapability = capabilities.StringCapability;

const std = @import("std");
const mem = std.mem;

const bool_caps_len = @typeInfo(BooleanCapability).@"enum".fields.len;
const num_caps_len = @typeInfo(NumberCapability).@"enum".fields.len;
const str_caps_len = @typeInfo(StringCapability).@"enum".fields.len;

const NumType = enum {
    i16,
    i32,
};

pub const Error = error{ NotATerminfo, ParsingFailed, AdditionalCapabilities };

pub fn parse(input: []const u8) Error!Database {
    var start: usize = 0;

    const magic = try readI16(input, &start);
    const num_type: NumType = switch (magic) {
        0o432 => .i16,
        0o1036 => .i32,
        else => return error.NotATerminfo,
    };

    const name_size: usize = @intCast(try readU16(input, &start));
    const bool_count: usize = @intCast(try readU16(input, &start));
    const num_count: usize = @intCast(try readU16(input, &start));
    const offset_count: usize = @intCast(try readU16(input, &start));
    const table_size: usize = @intCast(try readU16(input, &start));

    const names = try readN(input, &start, name_size);

    const booleans = try readN(input, &start, bool_count);

    if ((name_size + bool_count) % 2 != 0)
        _ = try readN(input, &start, 1);

    const numbers = try readN(input, &start, num_count * 2);

    const offsets = try readN(input, &start, offset_count * 2);

    const table = try readN(input, &start, table_size);

    _ = .{ offsets, table };

    var db = Database{
        .names = mem.zeroes([17]?[]const u8),
    };

    {
        var it = mem.splitScalar(u8, names[0 .. names.len - 1], '|');
        var names_list = mem.zeroes([17]?[]const u8);
        names_list[0] = it.first();

        if (it.peek() != null) {
            var i: usize = 1;
            while (it.peek() != null and i < 17) : (i += 1) {
                const name = it.next().?;
                names_list[i] = name;
            }
            db.description = names_list[i - 1].?;
            names_list[i - 1] = null;
            db.names = names_list;
        }
    }

    if (bool_count > bool_caps_len)
        return error.AdditionalCapabilities
    else {
        start = 0;
        for (0..bool_count - 1) |i| {
            const num = try readI8(booleans, &start);
            db._bool_caps[i] = switch (num) {
                -1, 0 => false,
                else => true,
            };
        }
    }

    if (num_count > num_caps_len)
        return error.AdditionalCapabilities
    else {
        start = 0;
        for (0..num_count - 1) |i| {
            const num = try readInt(numbers, &start, num_type);
            try assert(num >= -2);
            db._num_caps[i] = switch (num) {
                -1, -2 => null,
                else => num,
            };
        }
    }

    if (offset_count > str_caps_len)
        return error.AdditionalCapabilities
    else {
        var offset_start: usize = 0;
        for (0..offset_count - 1) |i| {
            const offset = try readI16(offsets, &offset_start);
            try assert(offset >= -2);
            db._string_caps[i] = switch (offset) {
                -1, -2 => null,
                else => blk: {
                    var exact_start: usize = 0;
                    const exact = table[@intCast(offset)..];
                    const match = try readUntil(exact, &exact_start, "\x00");
                    break :blk match;
                },
            };
        }
    }

    return db;
}

fn readI8(input: []const u8, start: *usize) !i8 {
    const match = input[start.*..];
    // std.debug.print("I8: {x}\n", .{match[0]});
    try assert(match.len >= 1);
    start.* += 1;
    return mem.readInt(i8, match[0..1], .little);
}

fn readU16(input: []const u8, start: *usize) !u16 {
    const match = input[start.*..];
    try assert(match.len >= 2);
    start.* += 2;
    return mem.readInt(u16, match[0..2], .little);
}

fn readI16(input: []const u8, start: *usize) !i16 {
    const match = input[start.*..];
    // std.debug.print("I16: {x} {x}\n", .{ match[0], match[1] });
    try assert(match.len >= 2);
    start.* += 2;
    return mem.readInt(i16, match[0..2], .little);
}

fn readI32(input: []const u8, start: *usize) !i32 {
    const match = input[start.*..];
    try assert(match.len >= 4);
    start.* += 4;
    return mem.readInt(i32, match[0..4], .little);
}

fn readInt(input: []const u8, start: *usize, typ: NumType) !i32 {
    return switch (typ) {
        .i16 => @intCast(try readI16(input, start)),
        .i32 => try readI32(input, start),
    };
}

fn readN(input: []const u8, start: *usize, n: usize) ![]const u8 {
    const match = input[start.*..];
    try assert(match.len >= n);
    std.debug.print("input: {} match: {}\n", .{ match.len, match[0..n].len });
    start.* += n;
    return match[0..n];
}

fn readUntil(input: []const u8, start: *usize, until: []const u8) ![]const u8 {
    const match = input[start.*..];
    var it = mem.tokenizeSequence(u8, match, until);
    try assert(it.peek() != null);
    return it.next().?;
}

inline fn assert(cond: bool) !void {
    if (!cond)
        return error.ParsingFailed;
}

const testing = std.testing;

inline fn load(comptime path: []const u8) !Database {
    return try parse(@embedFile(path));
}

test "should able to parse compiled terminfo" {
    const db = try load("./tests/st-256color");
    try testing.expectEqualSlices(u8, db.getStringCapability(.bell).?, "\x07");
}

// test "should able to get the name of the terminal" {
//     const db = try parse(@embedFile("./tests/dumb-emacs-ansi"));
//     try testing.expectEqualSlices(u8, db.name, "dumb-emacs-ansi");
// }

// test "should able to get the capability of the terminal" {
//     const db = try parse(@embedFile("./tests/st-256color"));
//     try testing.expectEqual(db.getNumberCapability(.columns), 80);
//     try testing.expectEqualSlices(u8, db.getStringCapability(.enter_bold_mode).?, "\\E[1m");
// }
