//! This module provides structs for parsing and manipulating CSV data
//! [Released under GNU LGPLv3]
//!
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const schema = @import("schema.zig");

/// A structure for storing settings for use with struct Table
pub const Settings = struct {
    /// The delimiter that separates the values (aka. separator)
    delimiter: []const u8,
    /// The terminator that defines when a row of delimiter-separated values is terminated
    terminator: []const u8,

    /// A function that returns the default settings that are most commonly used for CSV data
    /// { .delimiter = ",", .terminator = "\n" }
    pub fn default() Settings {
        return Settings{
            .delimiter = ",",
            .terminator = "\n",
        };
    }
};

/// Errors that may return from struct Table
pub const TableError = error{
    /// The requested column was not found
    ColumnNotFound,
    /// The requested value contains a delimiter or terminator character
    IllegalCharacter,
    /// A row is inconsistent with the number of values previously parsed
    InconsistentRowLength,
    /// Could not allocate required memory
    OutOfMemory,
    /// The requested row was not found
    RowNotFound,
    /// The requested value was not found
    ValueNotFound,
};

/// A structure for parsing and manipulating CSV data
pub const Table = struct {
    /// The settings that should be used when parsing the CSV data
    settings: Settings,
    // allocator used for temporary allocations
    allocator: Allocator,
    // amount of columns expected in each row, used for validation
    expected_column_count: ?usize,
    // array of rows, each row is an array of subsequent column values
    data: ArrayList(ArrayList([]const u8)),

    /// Initialize struct Table
    pub fn init(allocator: Allocator, settings: Settings) Table {
        return Table{
            .settings = settings,
            .allocator = allocator,
            .expected_column_count = null,
            .data = .empty,
        };
    }

    /// Deinitializes the internal arena allocator and parsed data
    pub fn deinit(self: *Table) void {
        for (self.data.items) |*row| {
            row.deinit(self.allocator);
        }
        self.data.deinit(self.allocator);
    }

    /// Load and append CSV data to the struct Table
    pub fn parse(self: *Table, csv_data: []const u8) TableError!void {
        const csv_data_sanatized = std.mem.trimRight(u8, csv_data, self.settings.terminator);
        var rows = std.mem.splitSequence(u8, csv_data_sanatized, self.settings.terminator);
        while (rows.next()) |row| {
            const value_count = try self.parseRow(row);
            if (self.expected_column_count == null) {
                self.expected_column_count = value_count;
            } else if (value_count != self.expected_column_count) {
                return TableError.InconsistentRowLength;
            }
        }
    }

    /// Parse a single row of CSV data and append it to the struct Table
    ///
    /// Returns the number of values parsed in the row.
    fn parseRow(self: *Table, row: []const u8) TableError!usize {
        var values: ArrayList([]const u8) = .empty;
        var columns = std.mem.splitSequence(u8, row, self.settings.delimiter);
        while (columns.next()) |value| {
            try values.append(self.allocator, value);
        }
        try self.data.append(self.allocator, values);
        return values.items.len;
    }

    /// Returns the number of rows in the table
    pub fn getRowCount(self: Table) usize {
        return self.data.items.len;
    }

    /// Returns the number of rows in the table
    pub fn getColumnCount(self: Table) usize {
        return self.expected_column_count orelse 0;
    }

    /// Returns all columns indexes that match a given value in a specific row
    ///
    /// Arguments:
    /// - `allocator`: The allocator to use for the returned slice.
    /// - `row_index`: The index of the row to search in.
    /// - `searched_value`: The value to search for in the row.
    ///
    /// Raises `TableError.ValueNotFound` if no matching values are found.
    ///
    /// This function may be used for retrieving columns by their header key:
    /// ```zig
    /// try table.parse(
    ///    \\id,name
    ///    \\1,John
    /// );
    /// const indexes = try table.findColumnIndexesByValue(allocator, 0, "id");
    /// assert(indexes == &.{0});
    /// ```
    pub fn findColumnIndexesByValue(self: Table, allocator: Allocator, row_index: usize, searched_value: []const u8) TableError![]usize {
        if (self.data.items.len < row_index) return TableError.RowNotFound;
        var column_indexes: ArrayList(usize) = .empty;
        for (self.data.items[row_index].items, 0..) |column_value, column_index| {
            if (std.mem.eql(u8, column_value, searched_value)) {
                try column_indexes.append(allocator, column_index);
            }
        }
        if (column_indexes.items.len <= 0) {
            column_indexes.deinit(allocator);
            return TableError.ValueNotFound;
        }
        return column_indexes.toOwnedSlice(allocator);
    }

    /// Returns all row indexes that match a given value in a specific column
    ///
    /// Arguments:
    /// - `allocator`: The allocator to use for the returned slice.
    /// - `column_index`: The index of the column to search in.
    /// - `searched_value`: The value to search for in the column.
    ///
    /// Raises `TableError.ValueNotFound` if no matching values are found.
    ///
    /// This function may be used for retrieving columns by their header key:
    /// ```zig
    /// try table.parse(
    ///    \\id,name
    ///    \\1,John
    /// );
    /// const indexes = try table.findRowIndexesByValue(allocator, 0, "1");
    /// assert(indexes == &.{1});
    /// ```
    pub fn findRowIndexesByValue(self: Table, allocator: Allocator, column_index: usize, searched_value: []const u8) TableError![]usize {
        if (self.expected_column_count == null) return TableError.ColumnNotFound;
        if (column_index >= self.expected_column_count orelse unreachable) return TableError.ColumnNotFound;
        var row_indexes: ArrayList(usize) = .empty;
        for (self.data.items, 0..) |row, row_index| {
            if (std.mem.eql(u8, row.items[column_index], searched_value)) {
                try row_indexes.append(allocator, row_index);
            }
        }
        if (row_indexes.items.len <= 0) {
            row_indexes.deinit(allocator);
            return TableError.ValueNotFound;
        }
        return row_indexes.toOwnedSlice(allocator);
    }

    /// Return the column at the provided index as a slice of values
    pub fn getColumnByIndex(self: Table, allocator: Allocator, column_index: usize) TableError![]const []const u8 {
        if (self.expected_column_count == null) return TableError.ColumnNotFound;
        if (column_index > self.expected_column_count orelse unreachable) return TableError.ColumnNotFound;
        var column_values: ArrayList([]const u8) = .empty;
        for (self.data.items) |row| {
            try column_values.append(allocator, row.items[column_index]);
        }
        return column_values.toOwnedSlice(allocator);
    }

    /// Return the row at the provided index as a slice of values
    pub fn getRowByIndex(self: Table, row_index: usize) TableError![]const []const u8 {
        if (row_index >= self.data.items.len) return TableError.RowNotFound;
        return self.data.items[row_index].items;
    }

    /// Insert an empty row at the provided index and shift all subsequent rows
    ///
    /// Arguments:
    /// - `row_index`: The index at which to insert the empty row. If `null`, the row will be appended to the end.
    ///
    /// Returns the index of the newly inserted row.
    pub fn insertEmptyRow(self: *Table, row_index: ?usize) TableError!usize {
        const target_index = row_index orelse self.data.items.len;
        if (target_index > self.data.items.len) return TableError.RowNotFound;
        var empty_row: ArrayList([]const u8) = .empty;
        for (0..self.expected_column_count orelse 0) |_| try empty_row.append(self.allocator, "");
        try self.data.insert(self.allocator, target_index, empty_row);
        return target_index;
    }

    /// Insert an empty column at the provided index and shift all subsequent columns
    ///
    /// Arguments:
    /// - `column_index`: The index at which to insert the empty column. If `null`, the column will be appended to the end.
    ///
    /// Returns the index of the newly inserted column.
    pub fn insertEmptyColumn(self: *Table, column_index: ?usize) TableError!usize {
        const target_index = column_index orelse self.expected_column_count orelse 0;
        if (target_index > self.expected_column_count orelse 0) return TableError.ColumnNotFound;
        for (self.data.items) |*row| {
            try row.insert(self.allocator, target_index, "");
        }
        self.expected_column_count = (self.expected_column_count orelse 0) + 1;
        return target_index;
    }

    /// Replace a value by a given new value, row index, and column index
    pub fn replaceValue(self: *Table, row_index: usize, column_index: usize, new_value: []const u8) TableError!void {
        if (row_index >= self.data.items.len) return TableError.RowNotFound;
        if (column_index >= self.expected_column_count orelse 0) return TableError.ColumnNotFound;
        if (std.mem.count(u8, new_value, self.settings.delimiter) != 0) return TableError.IllegalCharacter;
        if (std.mem.count(u8, new_value, self.settings.terminator) != 0) return TableError.IllegalCharacter;
        self.data.items[row_index].items[column_index] = new_value;
    }

    /// Remove a column by its index
    ///
    /// All prior column indexes will be invalidated.
    pub fn deleteColumnByIndex(self: *Table, column_index: usize) TableError!void {
        if (column_index >= self.expected_column_count orelse 0) return TableError.ColumnNotFound;
        for (self.data.items) |*row| {
            _ = row.orderedRemove(column_index);
        }
        self.expected_column_count = (self.expected_column_count orelse 0) - 1;
    }

    /// Remove a row by its index
    ///
    /// All prior row indexes will be invalidated.
    pub fn deleteRowByIndex(self: *Table, row_index: usize) TableError!void {
        if (row_index >= self.data.items.len) return TableError.RowNotFound;
        self.data.items[row_index].deinit(self.allocator);
        _ = self.data.orderedRemove(row_index);
    }

    /// Returns a slice of bytes containing the CSV data stored in the struct Table.
    pub fn exportCSV(self: *Table, allocator: Allocator) TableError![]const u8 {
        var csv: ArrayList(u8) = .empty;
        for (self.data.items, 0..) |row, row_index| {
            if (row_index > 0) {
                try csv.appendSlice(allocator, self.settings.terminator);
            }
            for (row.items, 0..) |column, column_index| {
                if (column_index > 0) {
                    try csv.appendSlice(allocator, self.settings.delimiter);
                }
                try csv.appendSlice(allocator, column);
            }
        }
        return csv.toOwnedSlice(allocator);
    }
};
