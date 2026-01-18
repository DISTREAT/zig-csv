// Test harness root file: imports individual test files located under src/tests/
// This file is used as the root source for the tests module so that
// @import("root.zig") in test files resolves to src/root.zig.

// Import test files as anonymous comptime blocks so they don't create duplicate
// top-level symbols in this module.
comptime {
    _ = @import("schema.zig");
    _ = @import("table.zig");
}
