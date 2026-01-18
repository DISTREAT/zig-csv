const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const module_root = b.addModule("zig_csv", .{
        .root_source_file = b.path("src/root.zig"),
        .optimize = mode,
        .target = target,
    });
    const lib = b.addLibrary(.{
        .name = "zig_csv",
        .linkage = .static,
        .root_module = module_root,
    });
    const module_tests = b.addModule("tests", .{
        .root_source_file = b.path("src/tests/root.zig"),
        .optimize = mode,
        .target = target,
    });
    const lib_tests = b.addTest(.{
        .root_module = module_tests,
    });
    lib_tests.root_module.addImport("zig_csv", module_root);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .{ .custom = ".." },
        .install_subdir = "docs",
    });

    b.installArtifact(lib);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(lib_tests).step);
    const docs_step = b.step("docs", "Build the documentation");
    docs_step.dependOn(&install_docs.step);
}
