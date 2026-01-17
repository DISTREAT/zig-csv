const table = @import("table.zig");
const schema = @import("schema.zig");

/// Thin root module that re-exports the core Table implementation and the schema
/// module. This avoids circular import issues by keeping the core implementation
/// in `table.zig` while allowing consumers to import this single entrypoint.
pub const Table = table.Table;
pub const Settings = table.Settings;
pub const TableError = table.TableError;
pub const StructureError = schema.StructureError;
pub const ParseResult = schema.ParseResult;
pub const StructuredTable = schema.StructuredTable;
