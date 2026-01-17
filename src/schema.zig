const std = @import("std");
const csv = @import("root.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Table = csv.Table;
const TableError = csv.TableError;
const Settings = csv.Settings;

/// Errors that can occur when mapping CSV data to a structured type
pub const StructureError = error{
    /// Multiple columns found with the same name
    AmbiguousColumn,
    /// Number of columns does not correspond to number of fields expected
    InvalidColumnCount,
    /// No column found for a given expected field name
    MissingColumn,
    /// Column value could not be converted to expected field type
    UnexpectedType,
};

/// Result of parsing a row into a structured type
/// Used to provide detailed error information when parsing fails
pub fn ParseResult(table_schema: type) type {
    return union {
        /// Successfully parsed structured value
        ok: struct {
            /// The parsed structured value
            value: table_schema,
        },
        /// Error occurred while parsing structured value
        @"error": struct {
            /// The kind of structure error that occurred
            kind: StructureError,
            /// The name of the field that caused the error
            field_name: ?[]const u8,
            /// The expected type of the field that caused the error
            field_type: ?[]const u8,
            /// The CSV value that caused the error
            csv_value: ?[]const u8,
        },
    };
}

/// A high-level table that maps CSV data to a struct type
pub fn StructuredTable(table_schema: type) type {
    const schema_info = @typeInfo(table_schema);
    if (schema_info != .@"struct") {
        @compileError("table_schema must be a struct type");
    }
    return struct {
        /// The underlying CSV table
        table: Table,
        /// The settings that should be used when parsing the CSV data
        settings: Settings,
        /// The allocator used for memory management
        allocator: Allocator,
        /// An arena allocator for dangling allocations
        arena_allocator: std.heap.ArenaAllocator,

        const Self = @This();

        /// Initialize a new StructuredTable
        pub fn init(allocator: Allocator, settings: Settings) Self {
            return Self{
                .table = Table.init(allocator, settings),
                .settings = settings,
                .allocator = allocator,
                .arena_allocator = std.heap.ArenaAllocator.init(allocator),
            };
        }

        /// Deinitialize the StructuredTable and free its resources
        pub fn deinit(self: *Self) void {
            self.arena_allocator.deinit();
            self.table.deinit();
        }

        /// Parse CSV data into the StructuredTable
        pub fn parse(self: *Self, csv_data: []const u8) (TableError || StructureError)!void {
            try self.table.parse(csv_data);
            if (self.table.getColumnCount() != schema_info.@"struct".fields.len) return StructureError.InvalidColumnCount;
        }

        /// Get the number of data rows in the StructuredTable
        pub fn getRowCount(self: Self) usize {
            const count = self.table.getRowCount();
            if (count == 0) return 0;
            return count - 1;
        }

        /// Get a structured row from the StructuredTable by index
        ///
        /// Example looping through all rows:
        /// ```zig
        /// var table = StructuredTable(MyStruct).init(allocator, settings);
        /// defer table.deinit();
        /// try table.parse(csv_data);
        /// for (0..table.getRowCount()) |index| {
        ///     const row_result = try table.getRow(index);
        ///     if (row_result.@tag == .@"error") {
        ///         // Handle error
        ///         break;
        ///     }
        ///     const row = row_result.ok.value;
        /// }
        /// ```
        pub fn getRow(self: Self, row_index: usize) TableError!ParseResult(table_schema) {
            if (row_index >= self.getRowCount()) return TableError.RowNotFound;
            var out: table_schema = undefined;
            inline for (schema_info.@"struct".fields) |field| {
                const field_name = field.name;
                const field_type = @typeInfo(field.type);
                const column_indexes = self.table.findColumnIndexesByValue(self.allocator, 0, field_name) catch return ParseResult(table_schema){
                    .@"error" = .{
                        .kind = StructureError.MissingColumn,
                        .field_name = field_name,
                        .field_type = @typeName(field.type),
                        .csv_value = null,
                    },
                };
                defer self.allocator.free(column_indexes);
                if (column_indexes.len > 1) return ParseResult(table_schema){
                    .@"error" = .{
                        .kind = StructureError.AmbiguousColumn,
                        .field_name = field_name,
                        .field_type = @typeName(field.type),
                        .csv_value = null,
                    },
                };
                const rows = self.table.getColumnByIndex(self.allocator, column_indexes[0]) catch return ParseResult(table_schema){
                    .@"error" = .{
                        .kind = StructureError.MissingColumn,
                        .field_name = field_name,
                        .field_type = @typeName(field.type),
                        .csv_value = null,
                    },
                };
                defer self.allocator.free(rows);
                const value = rows[row_index + 1];
                if (field_type == .pointer and
                    field_type.pointer.size == .slice and
                    field_type.pointer.child == u8)
                {
                    @field(out, field_name) = value;
                    continue;
                }
                switch (field_type) {
                    .bool => {
                        const lower = std.ascii.allocLowerString(self.allocator, value) catch return TableError.OutOfMemory;
                        defer self.allocator.free(lower);
                        var matched = false;
                        for ([_][]const u8{ "true", "1", "yes", "y" }) |true_word| {
                            if (std.mem.eql(u8, true_word, lower)) {
                                @field(out, field_name) = true;
                                matched = true;
                            }
                        }
                        for ([_][]const u8{ "false", "0", "no", "n" }) |false_word| {
                            if (std.mem.eql(u8, false_word, lower)) {
                                @field(out, field_name) = false;
                                matched = true;
                            }
                        }
                        if (!matched) return ParseResult(table_schema){
                            .@"error" = .{
                                .kind = StructureError.UnexpectedType,
                                .field_name = field_name,
                                .field_type = @typeName(field.type),
                                .csv_value = value,
                            },
                        };
                    },
                    .int => {
                        @field(out, field_name) = std.fmt.parseInt(field.type, value, 0) catch return ParseResult(table_schema){
                            .@"error" = .{
                                .kind = StructureError.UnexpectedType,
                                .field_name = field_name,
                                .field_type = @typeName(field.type),
                                .csv_value = value,
                            },
                        };
                    },
                    .float => {
                        @field(out, field_name) = std.fmt.parseFloat(field.type, value) catch return ParseResult(table_schema){
                            .@"error" = .{
                                .kind = StructureError.UnexpectedType,
                                .field_name = field_name,
                                .field_type = @typeName(field.type),
                                .csv_value = value,
                            },
                        };
                    },
                    else => {
                        @compileError(std.fmt.comptimePrint("unsupported field type for '{}'", .{@typeName(field.type)}));
                    },
                }
            }
            return ParseResult(table_schema){
                .ok = .{
                    .value = out,
                },
            };
        }

        /// Edit a structured row in the StructuredTable by index
        ///
        /// Example:
        /// ```zig
        /// var table = StructuredTable(MyStruct).init(allocator, settings);
        /// defer table.deinit();
        /// try table.parse(csv_data);
        /// const row = try table.getRow(0);
        /// var value = row.ok.value;
        /// value.my_field = 42;
        /// try table.editRow(0, value);
        /// ```
        pub fn editRow(self: *Self, row_index: usize, row: table_schema) TableError!ParseResult(table_schema) {
            if (row_index >= self.getRowCount()) return TableError.RowNotFound;
            inline for (schema_info.@"struct".fields) |field| {
                const field_name = field.name;
                const field_type = @typeInfo(field.type);
                const column_indexes = self.table.findColumnIndexesByValue(self.allocator, 0, field_name) catch return ParseResult(table_schema){
                    .@"error" = .{
                        .kind = StructureError.MissingColumn,
                        .field_name = field_name,
                        .field_type = @typeName(field.type),
                        .csv_value = null,
                    },
                };
                defer self.allocator.free(column_indexes);
                if (column_indexes.len > 1) return ParseResult(table_schema){
                    .@"error" = .{
                        .kind = StructureError.AmbiguousColumn,
                        .field_name = field_name,
                        .field_type = @typeName(field.type),
                        .csv_value = null,
                    },
                };
                const column_index = column_indexes[0];
                if (field_type == .pointer and
                    field_type.pointer.size == .slice and
                    field_type.pointer.child == u8)
                {
                    try self.table.replaceValue(row_index + 1, column_index, @field(row, field_name));
                    continue;
                }
                switch (field_type) {
                    .bool => {
                        if (@field(row, field_name)) {
                            try self.table.replaceValue(row_index + 1, column_index, "true");
                        } else {
                            try self.table.replaceValue(row_index + 1, column_index, "false");
                        }
                    },
                    .int, .float => {
                        const formatted = std.fmt.allocPrint(self.arena_allocator.allocator(), "{d}", .{@field(row, field_name)}) catch return TableError.OutOfMemory;
                        try self.table.replaceValue(row_index + 1, column_index, formatted);
                    },
                    else => {
                        @compileError(std.fmt.comptimePrint("unsupported field type for '{}'", .{@typeName(field.type)}));
                    },
                }
            }
            return ParseResult(table_schema){
                .ok = .{
                    .value = row,
                },
            };
        }

        /// Insert a structured row into the StructuredTable at the specified index
        ///
        /// If row_index is null, the row is appended to the end of the table
        pub fn insertRow(self: *Self, row_index: ?usize, row: table_schema) TableError!void {
            if (self.table.getRowCount() == 0) {
                _ = try self.table.insertEmptyRow(null);
                inline for (schema_info.@"struct".fields) |field| {
                    const header_row_index = try self.table.insertEmptyColumn(null);
                    try self.table.replaceValue(0, header_row_index, field.name);
                }
            }
            const index = self.table.insertEmptyRow(if (row_index) |index| index + 1 else null) catch return TableError.OutOfMemory;
            _ = try self.editRow(index - 1, row);
        }

        /// Delete a structured row from the StructuredTable by index
        pub fn deleteRow(self: *Self, row_index: usize) TableError!void {
            if (row_index >= self.getRowCount()) return TableError.RowNotFound;
            try self.table.deleteRowByIndex(row_index + 1);
        }

        /// Export the StructuredTable to CSV format
        ///
        /// Returns the CSV data as a byte slice
        ///
        /// Example:
        /// ```zig
        /// var table = StructuredTable(MyStruct).init(allocator, settings);
        /// defer table.deinit();
        /// try table.parse(csv_data);
        /// const csv_output = try table.exportCSV(allocator);
        /// defer allocator.free(csv_output);
        /// ```
        pub fn exportCSV(self: *Self, allocator: Allocator) TableError![]const u8 {
            return self.table.exportCSV(allocator);
        }
    };
}
