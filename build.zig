const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "zig-cvs",
        .root_source_file = .{ .path = "src/zig-csv.zig" },
        .optimize = mode,
        .target = target,
    });
    const lib_tests = b.addTest(.{ .root_source_file = .{ .path = "src/tests.zig" } });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .{ .custom = ".." },
        .install_subdir = "docs",
    });

    b.installArtifact(lib);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&lib_tests.step);
    const docs_step = b.step("docs", "Build the documentation");
    docs_step.dependOn(&install_docs.step);
}
