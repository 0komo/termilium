const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("termilium", .{
        .root_source_file = b.path("src/termilium.zig"),
        .target = target,
        .optimize = optimize,
    });

    {
        const mecha = b.dependency("mecha", .{});
        module.addImport("mecha", mecha.module("mecha"));
    }

    const test_step = b.step("test", "Run unit tests");
    const module_run_tests = b.addRunArtifact(b.addTest(.{
        .root_module = module,
    }));
    test_step.dependOn(&module_run_tests.step);

    const check_step = b.step("check", "Check if termilium compiles");
    const test_check = b.addTest(.{
        .root_module = module,
    });
    check_step.dependOn(&test_check.step);
}
