const std = @import("std");

pub fn build(b: *std.Build) anyerror!void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const fixtures = try generateCsvFixtures(b);
    const module_fixtures = b.addModule("fixtures", .{
        .root_source_file = fixtures,
        .optimize = mode,
        .target = target,
    });
    module_fixtures.addEmbedPath(b.path("src/tests/fixtures"));

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
    lib_tests.root_module.addImport("fixtures", module_fixtures);
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

fn generateCsvFixtures(b: *std.Build) anyerror!std.Build.LazyPath {
    const allocator = b.allocator;
    const io = b.graph.io;

    var source: std.ArrayList(u8) = .empty;
    defer source.deinit(allocator);

    try source.appendSlice(allocator,
        \\pub const fixtures = .{
        \\
    );

    const write_files = b.addWriteFiles();

    var directory = try b.build_root.handle.openDir(
        io,
        "src/tests/fixtures",
        .{ .iterate = true },
    );
    defer directory.close(io);

    var iterator = directory.iterate();
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".csv")) continue;

        _ = write_files.addCopyFile(
            b.path(b.fmt("src/tests/fixtures/{s}", .{entry.name})),
            b.fmt("data/{s}", .{entry.name}),
        );

        try source.print(
            allocator,
            \\    .{{
            \\        .name = "{f}",
            \\        .data = @embedFile("data/{f}"),
            \\    }},
            \\
        ,
            .{
                std.zig.fmtString(entry.name),
                std.zig.fmtString(entry.name),
            },
        );
    }
    try source.appendSlice(allocator,
        \\};
        \\
    );

    return write_files.add("fixtures.zig", source.items);
}
