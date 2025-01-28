//! This module provides structs for parsing and manipulating CSV data
//! [Released under GNU LGPLv3]
const std = @import("std");
const TableError = @import("zig-csv.zig").TableError;
const Allocator = std.mem.Allocator;

/// A struct for iterating over or fetching rows from a parsed table
pub const TableIterator = struct {
    /// The current row index as used by TableIterator.next
    iterator_index: usize = 0,
    delimiter: []const u8,
    header: []const []const u8,
    body: []const []const u8,
    allocator: Allocator,
    check_quote: bool,

    /// Reset the iterator for the function TableIterator.next
    pub fn reset(self: *TableIterator) void {
        self.iterator_index = 0;
    }

    /// Return the next row in the table
    pub fn next(self: *TableIterator) ?RowIterator {
        if (self.iterator_index >= self.body.len) return null;

        const row = RowIterator{
            .header = self.header,
            .row = std.mem.splitSequence(u8, self.body[self.iterator_index], self.delimiter),
            .allocator = self.allocator,
            .check_quote = self.check_quote,
        };

        self.iterator_index += 1;

        return row;
    }

    /// Return the value of the row with the provided index without changing the iterator index
    pub fn get(self: TableIterator, row_index: usize) TableError!RowIterator {
        if (row_index >= self.body.len) return TableError.IndexNotFound;

        return RowIterator{
            .header = self.header,
            .row = std.mem.splitSequence(u8, self.body[row_index], self.delimiter),
            .allocator = self.allocator,
            .check_quote = self.check_quote,
        };
    }
};

/// A struct for the representation of an item in a row
pub const RowItem = struct {
    /// Index of the column
    column_index: usize,
    /// The key of the column
    key: []const u8,
    /// The value of the item
    value: []const u8,
};

/// A struct for iterating over or fetching columns from a parsed row
pub const RowIterator = struct {
    /// The current column index as used by RowIterator.next
    iterator_index: usize = 0,
    header: []const []const u8,
    row: std.mem.SplitIterator(u8, .sequence),
    allocator: Allocator,
    check_quote: bool,

    /// Reset the iterator for the function RowIterator.next
    pub fn reset(self: *RowIterator) void {
        self.iterator_index = 0;
        self.row.reset();
    }

    /// Return the next column inside a row
    pub fn next(self: *RowIterator) ?RowItem {
        const value = self.row.next();
        if (value == null) return null;

        var item = RowItem{
            .column_index = self.iterator_index,
            .key = self.header[self.iterator_index],
            .value = value.?,
        };

        if (self.check_quote and item.value.len > 0 and item.value[0] == '"' and item.value[item.value.len - 1] != '"') {
            while (item.value[item.value.len - 1] != '"') {
                item.value = std.mem.concat(self.allocator, u8, &[_][]const u8{ item.value, self.row.delimiter, self.row.next().? }) catch item.value;
            }
        }

        self.iterator_index += 1;

        return item;
    }

    /// Return the value of the column with the provided index without changing the iterator index
    pub fn get(self: *RowIterator, target_column_index: usize) TableError!RowItem {
        var iterator = std.mem.splitSequence(u8, self.row.buffer, self.row.delimiter);
        var current_column_index: usize = 0;

        if (self.check_quote) {
            return RowItem{
                .column_index = target_column_index,
                .key = self.header[target_column_index],
                .value = try getColumnItemInQuote(u8, &iterator, target_column_index, self.allocator),
            };
        } else {
            while (iterator.next()) |value| : (current_column_index += 1) {
                if (current_column_index == target_column_index) {
                    return RowItem{
                        .column_index = current_column_index,
                        .key = self.header[current_column_index],
                        .value = value,
                    };
                }
            }
        }
        return TableError.IndexNotFound;
    }
};

/// A struct for the representation of an item in a column
pub const ColumnItem = struct {
    /// The row index where the value is located
    row_index: usize,
    /// The value of the item
    value: []const u8,
};

/// A struct for iterating over or fetching the values of a given column
pub const ColumnIterator = struct {
    /// The current row index as used by ColumnIterator.next
    iterator_index: usize = 0,
    column_index: usize,
    delimiter: []const u8,
    body: []const []const u8,
    allocator: Allocator,
    check_quote: bool,

    // Create a ColumnItem from a row
    fn rowToColumnItem(self: ColumnIterator, row: []const u8) ColumnItem {
        var item: ColumnItem = undefined;
        var values = std.mem.splitSequence(u8, row, self.delimiter);

        if (self.check_quote) {
            const value: ?[]const u8 = getColumnItemInQuote(u8, &values, self.column_index, self.allocator) catch null;
            if (value != null) {
                item = ColumnItem{
                    .row_index = self.iterator_index,
                    .value = value.?,
                };
            }
        } else {
            var current_index: usize = 0;
            while (values.next()) |value| : (current_index += 1) {
                if (current_index == self.column_index) {
                    item = ColumnItem{
                        .row_index = self.iterator_index,
                        .value = value,
                    };
                }
            }
        }

        return item;
    }

    /// Reset the iterator for the function ColumnIterator.next
    pub fn reset(self: *ColumnIterator) void {
        self.iterator_index = 0;
    }

    /// Return the next value inside the column
    pub fn next(self: *ColumnIterator) ?ColumnItem {
        if (self.iterator_index >= self.body.len) return null;

        const row = self.body[self.iterator_index];
        const item = self.rowToColumnItem(row);

        self.iterator_index += 1;

        return item;
    }

    /// Return the value of the row with the provided index without changing the iterator index
    pub fn get(self: *ColumnIterator, row_index: usize) TableError!ColumnItem {
        if (self.iterator_index >= self.body.len) return TableError.IndexNotFound;

        const row = self.body[row_index];
        const item = self.rowToColumnItem(row);

        return item;
    }
};

/// Return the value of a column in a row, while discarding delimiters inside "double quotes"
pub fn getColumnItemInQuote(comptime T: type, split_iterator: *std.mem.SplitIterator(T, .sequence), target_index: usize, allocator: std.mem.Allocator) TableError![]const T {
    var index: usize = 0;
    var in_quote = false;
    var item_in_quote: []const u8 = "";

    while (split_iterator.next()) |item| {
        if (!in_quote and item.len > 1 and item[0] == '"' and item[item.len - 1] != '"') { // check if item is the beginning of a double quoted value
            in_quote = true;
            if (index == target_index) item_in_quote = item;
            continue;
        } else if (in_quote) { // process item inside double quote
            // allocate if item needs to be returned
            if (index == target_index) {
                item_in_quote = try std.mem.concat(allocator, u8, &[_][]const u8{ item_in_quote, split_iterator.delimiter, item });
            }
            if (item.len == 0 or item[item.len - 1] != '"') continue;
            // item is the end of the double quoted value
            in_quote = false;
        }

        // return item value
        if (item_in_quote.len > 0) return item_in_quote else if (index == target_index) return item;
        index += 1;
    }

    return TableError.IndexNotFound;
}
