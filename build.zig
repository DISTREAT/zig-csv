const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const lib = b.addStaticLibrary("zig-cvs", "src/zig-csv.zig");
    const lib_tests = b.addTest("src/tests.zig");

    lib.emit_docs = .emit;
    lib.install();

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&lib_tests.step);
}
