const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "zig-cvs",
        .root_source_file = .{ .path = "src/zig-csv.zig" },
        .target = target,
        .optimize = optimize,
    });

    const lib_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = target,
        .optimize = optimize,
    });

    lib.emit_docs = .emit;
    lib.install();

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&lib_tests.run().step);
}
