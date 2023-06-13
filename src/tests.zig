//! Unit and Integration tests for the module scope `src/*.zig`
//! [Released under GNU LGPLv3]
const std = @import("std");
const csv = @import("zig-csv.zig");
const expect = std.testing.expect;
const allocator = std.testing.allocator;

const csv_data_1: []const u8 =
    \\id,shorthand,animal name,scientific name
    \\0,r,rat,rattus rattus
    \\1,c,cat,felis catus
    \\2,p,pig,sus domesticus
    \\3,d,dog,canis familiaris
;
const csv_data_2: []const u8 =
    \\id,letter
    \\0,a
    \\1,b
;
const csv_data_2_keys = [_][]const u8{ "id", "letter" };
const csv_data_2_rows = [_][2][]const u8{
    [_][]const u8{ "0", "a" },
    [_][]const u8{ "1", "b" },
};
const csv_data_3: []const u8 = "id-letter|0-a|1-b";

test "Initialize Table using Table.parse and export to CSV via Table.exportCSV" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(csv_data_1);

    const exported: []const u8 = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expect(std.mem.eql(u8, exported, csv_data_1));
}

test "Initialize Table using Table.parseRow and export to CSV via Table.exportCSV" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();

    var csv_data_1_iterator = std.mem.split(u8, csv_data_1, "\n");
    while (csv_data_1_iterator.next()) |row| try table.parseRow(row);

    const exported: []const u8 = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expect(std.mem.eql(u8, exported, csv_data_1));
}

test "Initialize Table using different Settings and export to CSV via Table.exportCSV" {
    var table = csv.Table.init(allocator, csv.Settings{
        .delimiter = "-",
        .terminator = "|",
    });
    defer table.deinit();
    try table.parse(csv_data_3);

    const exported: []const u8 = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expect(std.mem.eql(u8, exported, csv_data_3));
}

test "Accessing struct data via Table.getAllColumns and Table.getAllRows" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(csv_data_2);

    const columns = table.getAllColumns();
    var rows = table.getAllRows();

    // verify that struct TableIterator works as expected
    var row_1 = rows.next().?; // 0, a
    var row_2 = try rows.get(1); // 1, b

    // compare columns and csv_data_2_keys
    try expect(columns.len == csv_data_2_keys.len);
    for (columns, 0..) |column, column_index| {
        try expect(std.mem.eql(u8, column, csv_data_2_keys[column_index]));
    }

    // try to access out-of-bounds row
    _ = rows.next();
    try expect(rows.next() == null);

    // verify that struct RowIterator works as expected
    try expect(std.mem.eql(u8, row_1.next().?.value, csv_data_2_rows[0][0]));
    try expect(std.mem.eql(u8, row_1.next().?.key, csv_data_2_keys[1]));

    const key_1 = try row_1.get(0);
    try expect(std.mem.eql(u8, key_1.key, csv_data_2_keys[0]));

    _ = row_2.next();
    try expect(std.mem.eql(u8, row_2.next().?.value, csv_data_2_rows[1][1]));
}

test "Find indexes of columns using Table.findColumnIndexesByKey" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(csv_data_1);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const column_indexes_id = try table.findColumnIndexesByKey(arena_allocator, "id");
    const column_indexes_sh = try table.findColumnIndexesByKey(arena_allocator, "shorthand");
    const column_indexes_an = try table.findColumnIndexesByKey(arena_allocator, "animal name");
    const column_indexes_sn = try table.findColumnIndexesByKey(arena_allocator, "scientific name");

    const column_indexes_ne = table.findColumnIndexesByKey(arena_allocator, "non-existent");
    try expect(column_indexes_ne == csv.TableError.KeyNotFound);

    try expect(column_indexes_id.len == 1);
    try expect(column_indexes_sh.len == 1);
    try expect(column_indexes_an.len == 1);
    try expect(column_indexes_sn.len == 1);

    try expect(column_indexes_id[0] == 0);
    try expect(column_indexes_sh[0] == 1);
    try expect(column_indexes_an[0] == 2);
}

test "Find indexes of rows using Table.findRowIndexesByValue" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(csv_data_1);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const row_indexes_rat = try table.findRowIndexesByValue(arena_allocator, 1, "r");
    const row_indexes_pig = try table.findRowIndexesByValue(arena_allocator, 3, "sus domesticus");

    const row_indexes_ne = table.findRowIndexesByValue(arena_allocator, 3, "non-existent");
    const row_indexes_ic = table.findRowIndexesByValue(arena_allocator, 250, "invalid column index");
    try expect(row_indexes_ne == csv.TableError.RowNotFound);
    try expect(row_indexes_ic == csv.TableError.IndexNotFound);

    try expect(row_indexes_rat.len == 1);
    try expect(row_indexes_pig.len == 1);

    try expect(row_indexes_rat[0] == 0);
    try expect(row_indexes_pig[0] == 2);
}

test "Get column by index using Table.getColumnByIndex" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(csv_data_2);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const column_index_id = try table.findColumnIndexesByKey(arena_allocator, "id");
    const column_index_letter = try table.findColumnIndexesByKey(arena_allocator, "letter");

    var ids = table.getColumnByIndex(column_index_id[0]);
    var letters = table.getColumnByIndex(column_index_letter[0]);

    // verify that ColumnIterator works as expected
    try expect(std.mem.eql(u8, ids.next().?.value, "0"));
    try expect(std.mem.eql(u8, ids.next().?.value, "1"));

    const letter_0 = try letters.get(0);
    const letter_1 = try letters.get(1);
    try expect(std.mem.eql(u8, letter_0.value, "a"));
    try expect(std.mem.eql(u8, letter_1.value, "b"));

    try expect(ids.next() == null);
    try expect(std.mem.eql(u8, letters.next().?.value, "a"));
}

test "Get row by index using Table.getRowByIndex" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(csv_data_2);

    var row_0 = try table.getRowByIndex(0);

    const column_index_letter = try table.findColumnIndexesByKey(allocator, "letter");
    defer allocator.free(column_index_letter);

    const letter_0 = try row_0.get(column_index_letter[0]);

    try expect(std.mem.eql(u8, letter_0.value, "a"));

    try expect(std.mem.eql(u8, row_0.next().?.value, "0"));
    try expect(std.mem.eql(u8, row_0.next().?.value, "a"));

    try expect(row_0.next() == null);

    row_0.reset();
    try expect(std.mem.eql(u8, row_0.next().?.value, "0"));
}

test "Replace values using Table.replaceValues" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(csv_data_2);

    try table.replaceValue(0, 0, "2");
    try table.replaceValue(1, 1, "c");

    const expected_csv =
        \\id,letter
        \\2,a
        \\1,c
    ;
    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expect(std.mem.eql(u8, exported, expected_csv));
}

test "Replace values containing illegal characters using Table.replaceValues" {
    var table = csv.Table.init(allocator, csv.Settings{
        .delimiter = ",",
        .terminator = "\n",
    });
    defer table.deinit();
    try table.parse(csv_data_2);

    try expect(table.replaceValue(0, 0, ",2") == csv.TableError.IllegalCharacter);
    try expect(table.replaceValue(0, 0, "2\n") == csv.TableError.IllegalCharacter);
}

test "Append row using Table.insertEmptyRow" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(csv_data_2);

    _ = try table.insertEmptyRow();

    const expected_csv =
        \\id,letter
        \\0,a
        \\1,b
        \\,
    ;
    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expect(std.mem.eql(u8, exported, expected_csv));
}

test "Append row using Table.insertEmptyRow and Table.replaceValue" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(csv_data_2);

    const row_index = try table.insertEmptyRow();
    try table.replaceValue(row_index, 0, "2");
    try table.replaceValue(row_index, 1, "c");

    const expected_csv =
        \\id,letter
        \\0,a
        \\1,b
        \\2,c
    ;
    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expect(std.mem.eql(u8, exported, expected_csv));
}

test "Append column using Table.insertEmptyColumn" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(csv_data_2);

    _ = try table.insertEmptyColumn("example word");

    const expected_csv =
        \\id,letter,example word
        \\0,a,
        \\1,b,
    ;
    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expect(std.mem.eql(u8, exported, expected_csv));
}

test "Append column containing illegal characters using Table.insertEmptyColumn" {
    var table = csv.Table.init(allocator, csv.Settings{
        .delimiter = ",",
        .terminator = "\n",
    });
    defer table.deinit();
    try table.parse(csv_data_2);

    try expect(table.insertEmptyColumn("example, word") == csv.TableError.IllegalCharacter);
    try expect(table.insertEmptyColumn("example\n word") == csv.TableError.IllegalCharacter);
}

test "Append column using Table.insertEmptyColumn and Table.replaceValue" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(csv_data_2);

    const column_index = try table.insertEmptyColumn("example word");
    try table.replaceValue(0, column_index, "anemone");
    try table.replaceValue(1, column_index, "bee");

    const expected_csv =
        \\id,letter,example word
        \\0,a,anemone
        \\1,b,bee
    ;
    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expect(std.mem.eql(u8, exported, expected_csv));
}

test "Delete row using Table.deleteRowByIndex" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(csv_data_2);

    try table.deleteRowByIndex(0);

    const expected_csv =
        \\id,letter
        \\1,b
    ;
    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expect(std.mem.eql(u8, exported, expected_csv));
}

test "Delete column using Table.deleteColumnByIndex" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(csv_data_2);

    try table.deleteColumnByIndex(0);

    const expected_csv =
        \\letter
        \\a
        \\b
    ;
    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expect(std.mem.eql(u8, exported, expected_csv));
}

test "Initializing Table from empty and ArenaAllocator, recreating test data" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();

    const column_index_id = try table.insertEmptyColumn("id");
    const column_index_letter = try table.insertEmptyColumn("letter");

    for ([_][]const u8{ "a", "b" }, 0..) |row, row_index| {
        const targetRowByIndex_index = try table.insertEmptyRow();
        const row_id = try std.fmt.allocPrint(allocator, "{d}", .{row_index});
        defer allocator.free(row_id);

        try table.replaceValue(targetRowByIndex_index, column_index_id, row_id);
        try table.replaceValue(targetRowByIndex_index, column_index_letter, row);
    }

    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expect(std.mem.eql(u8, exported, csv_data_2));
}
