const std = @import("std");

const builtin = std.builtin;
const Build = std.Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("termilium", .{
        .root_source_file = b.path("src/termilium.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    const module_run_tests = b.addRunArtifact(b.addTest(.{
        .root_module = path(b, target, optimize, "./src/parser.zig"),
    }));
    test_step.dependOn(&module_run_tests.step);

    const check_step = b.step("check", "Check if termilium compiles");
    const test_check = b.addTest(.{
        .root_module = module,
    });
    check_step.dependOn(&test_check.step);
}

fn path(b: *Build, target: Build.ResolvedTarget, optimize: builtin.OptimizeMode, p: []const u8) *Build.Module {
    return b.createModule(.{
        .root_source_file = b.path(p),
        .target = target,
        .optimize = optimize,
    });
}
