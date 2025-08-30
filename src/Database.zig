const capabilities = @import("capability.zig");
const BooleanCapability = capabilities.BooleanCapability;
const NumberCapability = capabilities.NumberCapability;
const StringCapability = capabilities.StringCapability;

const std = @import("std");
const mem = std.mem;

const max_bool_caps = @typeInfo(BooleanCapability).@"enum".fields.len;
const max_num_caps = @typeInfo(NumberCapability).@"enum".fields.len;
const max_string_caps = @typeInfo(StringCapability).@"enum".fields.len;

name: []const u8,
aliases: [][]const u8,
description: []const u8,

allocator: mem.Allocator,

bool_caps: [max_bool_caps]bool = mem.zeroes([max_bool_caps]bool),
num_cups: [max_num_caps]?i32 = mem.zeroes([max_num_caps]?i32),
string_caps: [max_string_caps]?[]const u8 = mem.zeroes([max_string_caps]?[]const u8),

bool_ext_caps: std.StringHashMap(bool) = undefined,
num_ext_caps: std.StringHashMap(i32) = undefined,
string_ext_caps: std.StringHashMap([]const u8) = undefined,

const Self = @This();

pub fn deinit(self: Self) void {
    self.allocator.free(self.aliases);
}

pub fn getBooleanCapability(self: Self, cap: BooleanCapability) bool {
    return self.bool_caps[@intFromEnum(cap)];
}

pub fn getNumberCapability(self: Self, cap: NumberCapability) ?i32 {
    return self.num_cups[@intFromEnum(cap)];
}

pub fn getStringCapability(self: Self, cap: StringCapability) ?[]const u8 {
    return self.string_caps[@intFromEnum(cap)];
}
