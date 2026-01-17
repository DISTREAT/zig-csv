const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

/// A structure for storing settings for use with struct Table
pub const Settings = struct {
    /// The delimiter that separates the values (aka. separator)
    delimiter: []const u8,
    /// The terminator that defines when a row of delimiter-separated values is terminated
    terminator: []const u8,

    pub fn default() Settings {
        return Settings{
            .delimiter = ",",
            .terminator = "\n",
        };
    }
};

/// Errors that may return from struct Table
pub const TableError = error{
    ColumnNotFound,
    IllegalCharacter,
    InconsistentRowLength,
    OutOfMemory,
    RowNotFound,
    ValueNotFound,
};

/// A structure for parsing and manipulating CSV data
pub const Table = struct {
    settings: Settings,
    allocator: Allocator,
    expected_column_count: ?usize,
    data: ArrayList(ArrayList([]const u8)),

    pub fn init(allocator: Allocator, settings: Settings) Table {
        return Table{
            .settings = settings,
            .allocator = allocator,
            .expected_column_count = null,
            .data = .empty,
        };
    }

    pub fn deinit(self: *Table) void {
        for (self.data.items) |*row| {
            row.deinit(self.allocator);
        }
        self.data.deinit(self.allocator);
    }

    pub fn parse(self: *Table, csv_data: []const u8) TableError!void {
        const csv_data_sanitized = std.mem.trimRight(u8, csv_data, self.settings.terminator);
        var rows = std.mem.splitSequence(u8, csv_data_sanitized, self.settings.terminator);
        while (rows.next()) |row| {
            const value_count = try self.parseRow(row);
            if (self.expected_column_count == null) {
                self.expected_column_count = value_count;
            } else if (value_count != self.expected_column_count) {
                return TableError.InconsistentRowLength;
            }
        }
    }

    fn parseRow(self: *Table, row: []const u8) TableError!usize {
        var values: ArrayList([]const u8) = .empty;
        var columns = std.mem.splitSequence(u8, row, self.settings.delimiter);
        while (columns.next()) |value| {
            try values.append(self.allocator, value);
        }
        try self.data.append(self.allocator, values);
        return values.items.len;
    }

    pub fn getRowCount(self: Table) usize {
        return self.data.items.len;
    }

    pub fn getColumnCount(self: Table) usize {
        return self.expected_column_count orelse 0;
    }

    pub fn findColumnIndexesByValue(self: Table, allocator: Allocator, row_index: usize, searched_value: []const u8) TableError![]usize {
        if (row_index >= self.data.items.len) return TableError.RowNotFound;
        var column_indexes: ArrayList(usize) = .empty;
        const row = self.data.items[row_index];
        for (row.items, 0..) |column_value, column_index| {
            if (std.mem.eql(u8, column_value, searched_value)) {
                try column_indexes.append(allocator, column_index);
            }
        }
        if (column_indexes.items.len == 0) {
            column_indexes.deinit(allocator);
            return TableError.ValueNotFound;
        }
        return column_indexes.toOwnedSlice(allocator);
    }

    pub fn findRowIndexesByValue(self: Table, allocator: Allocator, column_index: usize, searched_value: []const u8) TableError![]usize {
        if (self.expected_column_count == null) return TableError.ColumnNotFound;
        const col_count = self.expected_column_count orelse 0;
        if (column_index >= col_count) return TableError.ColumnNotFound;
        var row_indexes: ArrayList(usize) = .empty;
        for (self.data.items, 0..) |row, row_index| {
            if (row.items.len <= column_index) continue; // skip inconsistent rows
            if (std.mem.eql(u8, row.items[column_index], searched_value)) {
                try row_indexes.append(allocator, row_index);
            }
        }
        if (row_indexes.items.len == 0) {
            row_indexes.deinit(allocator);
            return TableError.ValueNotFound;
        }
        return row_indexes.toOwnedSlice(allocator);
    }

    pub fn getColumnByIndex(self: Table, allocator: Allocator, column_index: usize) TableError![]const []const u8 {
        if (self.expected_column_count == null) return TableError.ColumnNotFound;
        const col_count = self.expected_column_count orelse 0;
        if (column_index >= col_count) return TableError.ColumnNotFound;
        var column_values: ArrayList([]const u8) = .empty;
        for (self.data.items) |row| {
            if (row.items.len <= column_index) {
                try column_values.append(allocator, "");
            } else {
                try column_values.append(allocator, row.items[column_index]);
            }
        }
        return column_values.toOwnedSlice(allocator);
    }

    pub fn getRowByIndex(self: Table, row_index: usize) TableError![]const []const u8 {
        if (row_index >= self.data.items.len) return TableError.RowNotFound;
        return self.data.items[row_index].items;
    }

    pub fn insertEmptyRow(self: *Table, row_index: ?usize) TableError!usize {
        const target_index = row_index orelse self.data.items.len;
        if (target_index > self.data.items.len) return TableError.RowNotFound;
        var empty_row: ArrayList([]const u8) = .empty;
        for (0..self.expected_column_count orelse 0) |_| try empty_row.append(self.allocator, "");
        try self.data.insert(self.allocator, target_index, empty_row);
        return target_index;
    }

    pub fn insertEmptyColumn(self: *Table, column_index: ?usize) TableError!usize {
        const target_index = column_index orelse self.expected_column_count orelse 0;
        if (target_index > self.expected_column_count orelse 0) return TableError.ColumnNotFound;
        for (self.data.items) |*row| {
            try row.insert(self.allocator, target_index, "");
        }
        self.expected_column_count = (self.expected_column_count orelse 0) + 1;
        return target_index;
    }

    pub fn replaceValue(self: *Table, row_index: usize, column_index: usize, new_value: []const u8) TableError!void {
        if (row_index >= self.data.items.len) return TableError.RowNotFound;
        if (self.expected_column_count == null) return TableError.ColumnNotFound;
        if (column_index >= (self.expected_column_count orelse 0)) return TableError.ColumnNotFound;
        if (std.mem.indexOf(u8, new_value, self.settings.delimiter) != null) return TableError.IllegalCharacter;
        if (std.mem.indexOf(u8, new_value, self.settings.terminator) != null) return TableError.IllegalCharacter;
        self.data.items[row_index].items[column_index] = new_value;
    }

    pub fn deleteColumnByIndex(self: *Table, column_index: usize) TableError!void {
        if (self.expected_column_count == null) return TableError.ColumnNotFound;
        if (column_index >= (self.expected_column_count orelse 0)) return TableError.ColumnNotFound;
        for (self.data.items) |*row| {
            _ = row.orderedRemove(column_index);
        }
        self.expected_column_count = (self.expected_column_count orelse 0) - 1;
    }

    pub fn deleteRowByIndex(self: *Table, row_index: usize) TableError!void {
        if (row_index >= self.data.items.len) return TableError.RowNotFound;
        self.data.items[row_index].deinit(self.allocator);
        _ = self.data.orderedRemove(row_index);
    }

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
