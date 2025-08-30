const Database = @import("Database.zig");

const capabilities = @import("capability.zig");
const BooleanCapability = capabilities.BooleanCapability;
const NumberCapability = capabilities.NumberCapability;
const StringCapability = capabilities.StringCapability;

const std = @import("std");
const mem = std.mem;

const max_bool_caps = @typeInfo(BooleanCapability).@"enum".fields.len;
const max_num_caps = @typeInfo(NumberCapability).@"enum".fields.len;
const max_string_caps = @typeInfo(StringCapability).@"enum".fields.len;

const NumType = enum {
    i16,
    i32,
};

pub const Error = error{ NotATerminfo, ParsingFailed, AdditionalCapabilities } || mem.Allocator.Error;

pub fn parse(allocator: mem.Allocator, input: []const u8) Error!Database {
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

    var name: []const u8 = undefined;
    var description: []const u8 = undefined;
    var aliases: [][]const u8 = undefined;

    {
        var it = mem.splitScalar(u8, names[0 .. names.len - 1], '|');
        name = it.first();

        if (it.peek() != null) {
            var names_list = std.ArrayList([]const u8).empty;
            while (it.next()) |alias| {
                try names_list.append(allocator, alias);
            }
            description = names_list.pop().?;
            aliases = try names_list.toOwnedSlice(allocator);
        }
    }

    const bool_caps = if (bool_count > max_bool_caps)
        return error.AdditionalCapabilities
    else blk: {
        var caps = mem.zeroes([max_bool_caps]bool);
        start = 0;
        for (0..bool_count - 1) |i| {
            const num = try readI8(booleans, &start);
            caps[i] = switch (num) {
                -1, 0 => false,
                else => true,
            };
        }
        break :blk caps;
    };

    const num_caps = if (num_count > max_num_caps)
        return error.AdditionalCapabilities
    else blk: {
        var caps = mem.zeroes([max_num_caps]?i32);
        start = 0;
        for (0..num_count - 1) |i| {
            const num = try readInt(numbers, &start, num_type);
            try assert(num >= -2);
            caps[i] = switch (num) {
                -1, -2 => null,
                else => num,
            };
        }
        break :blk caps;
    };

    const string_caps = if (offset_count > max_string_caps)
        return error.AdditionalCapabilities
    else res: {
        var caps = mem.zeroes([max_string_caps]?[]const u8);
        var offset_start: usize = 0;
        for (0..offset_count - 1) |i| {
            const offset = try readI16(offsets, &offset_start);
            try assert(offset >= -2);
            caps[i] = switch (offset) {
                -1, -2 => null,
                else => blk: {
                    var exact_start: usize = 0;
                    const exact = table[@intCast(offset)..];
                    const match = try readUntil(exact, &exact_start, "\x00");
                    break :blk match;
                },
            };
        }
        break :res caps;
    };

    if (start == input.len) {
        if (table_size % 2 != 0)
            try readN(input, &start, 1);

        const ext_bool_count: usize = @intCast(try readU16(input, &start));
        const ext_num_count: usize = @intCast(try readU16(input, &start));
        const ext_string_count: usize = @intCast(try readU16(input, &start));
        const ext_offset_count: usize = @intCast(try readU16(input, &start));
        const ext_table_size: usize = @intCast(try readU16(input, &start));

        const ext_booleans = try readN(input, &start, ext_bool_count);

        if (ext_bool_count % 2 != 0)
            try readN(input, &start, 1);

        const ext_numbers = try readN(input, &start, ext_num_count);

        const ext_offsets = try readN(input, &start, ext_string_count);

        const ext_names_raw = try readN(input, &start, ext_bool_count + ext_num_count + ext_string_count);

        const ext_table = try readN(input, &start, ext_table_size);

        const ext_names = blk: {
            var arr = std.ArrayList([]const u8).empty;
            var it = mem.splitScalar(u8, ext_table, 0);
            while (it.next()) |str| {
                try arr.append(allocator, str);
            }
            break :blk try arr.toOwnedSlice(allocator);
        };
        defer allocator.free(ext_names);

        const ext_bools = blk: {
            var map = std.StringHashMap(bool).init(allocator);
            start = 0;
        };
    }

    return Database{
        .name = name,
        .description = description,
        .aliases = aliases,
        .bool_caps = bool_caps,
        .num_caps = num_caps,
        .string_caps = string_caps,
    };
}

fn readI8(input: []const u8, start: *usize) !i8 {
    const match = input[start.*..];
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
    start.* += n;
    return match[0..n];
}

fn readUntil(input: []const u8, start: *usize, until: []const u8) ![]const u8 {
    const match = input[start.*..];
    var it = mem.tokenizeSequence(u8, match, until);
    const first = it.next();
    try assert(first != null);
    start.* += first.?.len;
    return first.?;
}

fn find(comptime T: type, haystack: []const T, needle: T) error{NotFound}!T {
    for (0..haystack.len - 1) |i| {
        const v = haystack[i];
        if (v == needle)
            return v;
    }
    return error.NotFound;
}

inline fn assert(cond: bool) !void {
    if (!cond)
        return error.ParsingFailed;
}

const testing = std.testing;

inline fn load(comptime path: []const u8) !Database {
    return try parse(testing.allocator, @embedFile(path));
}

test "should able to parse compiled terminfo" {
    (try load("./tests/cancer-256color")).deinit(testing.allocator);
}

test "should able to get the name of the terminal" {
    const db = try load("./tests/dumb-emacs-ansi");
    defer db.deinit(testing.allocator);
    try testing.expectEqualSlices(u8, db.name, "dumb-emacs-ansi");
}

test "should able to get the capability of the terminal" {
    const db = try load("./tests/st-256color");
    defer db.deinit(testing.allocator);
    try testing.expectEqual(db.getBooleanCapability(.auto_right_margin), true);
    try testing.expectEqual(db.getNumberCapability(.columns).?, 80);
    try testing.expectEqualSlices(u8, db.getStringCapability(.bell).?, "\x07");
}
