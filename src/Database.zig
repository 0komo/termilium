const capabilities = @import("capability.zig");
const BooleanCapability = capabilities.BooleanCapability;
const NumberCapability = capabilities.NumberCapability;
const StringCapability = capabilities.StringCapability;

const std = @import("std");
const mem = std.mem;

const bool_caps_len = @typeInfo(BooleanCapability).@"enum".fields.len;
const num_caps_len = @typeInfo(NumberCapability).@"enum".fields.len;
const str_caps_len = @typeInfo(StringCapability).@"enum".fields.len;

names: [17]?[]const u8,
description: []const u8 = "",

_bool_caps: [bool_caps_len]bool = mem.zeroes([bool_caps_len]bool),
_num_caps: [num_caps_len]?i32 = mem.zeroes([num_caps_len]?i32),
_string_caps: [str_caps_len]?[]const u8 = mem.zeroes([str_caps_len]?[]const u8),

const Self = @This();

pub fn getBooleanCapability(self: Self, cap: BooleanCapability) bool {
    return self._bool_caps[@intFromEnum(cap)];
}

pub fn getNumberCapability(self: Self, cap: NumberCapability) ?i32 {
    return self._num_caps[@intFromEnum(cap)];
}

pub fn getStringCapability(self: Self, cap: StringCapability) ?[]const u8 {
    return self._string_caps[@intFromEnum(cap)];
}
