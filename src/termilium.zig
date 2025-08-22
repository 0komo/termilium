const std = @import("std");
const helper = @import("./parser/helper.zig");

test "xxxx" {
    const allocator = std.testing.allocator;

    const p2 = try helper.leU32.parse(allocator, &.{ 0, 0, 0, 0 });
    if (p2.value == .err) {
        @panic("failed");
    }
    std.debug.print("{} {}", .{ p2.value.ok, @TypeOf(p2.value.ok) });
}
