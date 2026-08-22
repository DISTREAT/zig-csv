pub const parser = @import("parser.zig");
pub const schema = @import("schema.zig");
pub const table = @import("table.zig");

/// Thin root module that re-exports the core Table implementation and the schema
/// module. This avoids circular import issues by keeping the core implementation
/// in `table.zig` while allowing consumers to import this single entrypoint.
pub const LexerSettings = parser.LexerSettings;
pub const ParseResult = schema.ParseResult;
pub const ParserError = parser.ParserError;
pub const StructureError = schema.StructureError;
pub const StructuredTable = schema.StructuredTable;
pub const Table = table.Table;
pub const TableError = table.TableError;
