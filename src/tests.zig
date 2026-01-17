//! Unit and Integration tests for the module scope `src/*.zig`
//! [Released under GNU LGPLv3]
const std = @import("std");
const csv = @import("root.zig");
const expect = std.testing.expect;
const allocator = std.testing.allocator;
const StructuredTable = csv.StructuredTable;

test "Initialize Table using Table.parse and export to CSV via Table.exportCSV" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    const csv_data =
        \\id,shorthand,animal name,scientific name
        \\0,r,rat,rattus rattus
        \\1,c,cat,felis catus
        \\2,p,pig,sus domesticus
        \\3,d,dog,canis familiaris
    ;
    try table.parse(csv_data);

    const exported: []const u8 = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expect(std.mem.eql(u8, exported, csv_data));
}

test "Initialize Table using Table.parseRow and export to CSV via Table.exportCSV" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    const csv_data =
        \\id,letter
        \\0,a
        \\1,b
    ;
    var csv_data_1_iterator = std.mem.splitSequence(u8, csv_data, "\n");
    while (csv_data_1_iterator.next()) |row| try table.parse(row);

    const exported: []const u8 = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expect(std.mem.eql(u8, exported, csv_data));
}

test "Initialize Table using custom delimiter and terminator and export to CSV via Table.exportCSV" {
    var table = csv.Table.init(allocator, csv.Settings{
        .delimiter = "-",
        .terminator = "|",
    });
    defer table.deinit();
    const csv_data =
        \\1-2-3|a-b-c
    ;
    try table.parse(csv_data);

    const exported: []const u8 = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expect(std.mem.eql(u8, exported, csv_data));
}

test "Get number of rows using Table.getRowCount" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\id,animal name,scientific name
        \\0,rat,rattus rattus
    );
    const row_count = table.getRowCount();
    try expect(row_count == 2);
}

test "Get number of columns using Table.getColumnCount" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\id,animal name,scientific name
        \\0,rat,rattus rattus
    );
    const column_count = table.getColumnCount();
    try expect(column_count == 3);
}

test "Find indexes of columns using Table.findColumnIndexesByValue" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\id,animal name,scientific name
        \\0,rat,rattus rattus
        \\1,pig,sus domesticus
    );

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const cases = [_]struct {
        row_index: usize,
        expected_index: usize,
        searched_key: []const u8,
    }{
        .{ .row_index = 0, .searched_key = "id", .expected_index = 0 },
        .{ .row_index = 0, .searched_key = "animal name", .expected_index = 1 },
        .{ .row_index = 0, .searched_key = "scientific name", .expected_index = 2 },
        .{ .row_index = 1, .searched_key = "rat", .expected_index = 1 },
    };
    inline for (cases) |case| {
        const indexes = try table.findColumnIndexesByValue(arena_allocator, case.row_index, case.searched_key);
        try expect(indexes.len == 1);
        try expect(indexes[0] == case.expected_index);
    }

    const column_indexes_ne = table.findColumnIndexesByValue(arena_allocator, 0, "non-existent");
    try expect(column_indexes_ne == csv.TableError.ValueNotFound);
}

test "Find indexes of columns using Table.findRowIndexesByValue" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\id,animal name,scientific name
        \\0,rat,rattus rattus
        \\1,pig,sus domesticus
    );

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const cases = [_]struct {
        column_index: usize,
        expected_index: usize,
        searched_key: []const u8,
    }{
        .{ .column_index = 0, .searched_key = "id", .expected_index = 0 },
        .{ .column_index = 0, .searched_key = "0", .expected_index = 1 },
        .{ .column_index = 0, .searched_key = "1", .expected_index = 2 },
        .{ .column_index = 1, .searched_key = "rat", .expected_index = 1 },
    };
    inline for (cases) |case| {
        const indexes = try table.findRowIndexesByValue(arena_allocator, case.column_index, case.searched_key);
        try expect(indexes.len == 1);
        try expect(indexes[0] == case.expected_index);
    }

    const column_indexes_ne = table.findRowIndexesByValue(arena_allocator, 0, "non-existent");
    try expect(column_indexes_ne == csv.TableError.ValueNotFound);
}

test "Get column by index using Table.getColumnByIndex" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\id,letter
        \\0,a
    );

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const column_0 = try table.getColumnByIndex(arena_allocator, 0);
    try expect(column_0.len == 2);
    try expect(std.mem.eql(u8, column_0[0], "id"));
    try expect(std.mem.eql(u8, column_0[1], "0"));

    const column_1 = try table.getColumnByIndex(arena_allocator, 1);
    try expect(column_1.len == 2);
    try expect(std.mem.eql(u8, column_1[0], "letter"));
    try expect(std.mem.eql(u8, column_1[1], "a"));
}

test "Get row by index using Table.getRowByIndex" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\id,letter
        \\0,a
    );

    const row_0 = try table.getRowByIndex(0);
    try expect(row_0.len == 2);
    try expect(std.mem.eql(u8, row_0[0], "id"));
    try expect(std.mem.eql(u8, row_0[1], "letter"));

    const row_1 = try table.getRowByIndex(1);
    try expect(row_1.len == 2);
    try expect(std.mem.eql(u8, row_1[0], "0"));
    try expect(std.mem.eql(u8, row_1[1], "a"));
}

test "Replace values using Table.replaceValue" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\id,letter
        \\0,a
        \\1,b
    );
    try table.replaceValue(1, 0, "2");
    try table.replaceValue(2, 1, "c");

    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    const expected_csv =
        \\id,letter
        \\2,a
        \\1,c
    ;
    try expect(std.mem.eql(u8, exported, expected_csv));
}

test "Replace values containing illegal characters using Table.replaceValues" {
    var table = csv.Table.init(allocator, csv.Settings{
        .delimiter = ",",
        .terminator = "\n",
    });
    defer table.deinit();
    try table.parse(
        \\a,b
        \\c,d
    );

    try expect(table.replaceValue(0, 0, ",2") == csv.TableError.IllegalCharacter);
    try expect(table.replaceValue(0, 0, "2\n") == csv.TableError.IllegalCharacter);
}

test "Append row using Table.insertEmptyRow" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\id,letter
        \\0,a
    );
    const inserted_at = try table.insertEmptyRow(null);

    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    const expected_csv =
        \\id,letter
        \\0,a
        \\,
    ;
    try expect(std.mem.eql(u8, exported, expected_csv));
    try expect(inserted_at == 2);
}

test "Insert row using Table.insertEmptyRow" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    const csv_data =
        \\id,letter
        \\1,b
    ;
    try table.parse(csv_data);

    const inserted_at = try table.insertEmptyRow(1);
    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    const expected_csv =
        \\id,letter
        \\,
        \\1,b
    ;
    try expect(std.mem.eql(u8, exported, expected_csv));
    try expect(inserted_at == 1);
}

test "Append column using Table.insertEmptyColumn" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\id,letter
        \\0,a
    );
    const inserted_at = try table.insertEmptyColumn(null);

    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    const expected_csv =
        \\id,letter,
        \\0,a,
    ;
    try expect(std.mem.eql(u8, exported, expected_csv));
    try expect(inserted_at == 2);
}

test "Insert column using Table.insertEmptyColumn" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    const csv_data =
        \\id,letter
        \\1,b
    ;
    try table.parse(csv_data);

    const inserted_at = try table.insertEmptyColumn(1);
    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    const expected_csv =
        \\id,,letter
        \\1,,b
    ;
    try expect(std.mem.eql(u8, exported, expected_csv));
    try expect(inserted_at == 1);
}

test "Append row using Table.insertEmptyRow and Table.replaceValue" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\id,letter
        \\0,a
        \\1,b
    );
    const row_index = try table.insertEmptyRow(null);
    try table.replaceValue(row_index, 0, "2");
    try table.replaceValue(row_index, 1, "c");

    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    const expected_csv =
        \\id,letter
        \\0,a
        \\1,b
        \\2,c
    ;
    try expect(std.mem.eql(u8, exported, expected_csv));
}

test "Append column using Table.insertEmptyColumn and Table.replaceValue" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\id,letter
        \\0,a
        \\1,b
    );
    const column_index = try table.insertEmptyColumn(null);
    try table.replaceValue(0, column_index, "example word");
    try table.replaceValue(1, column_index, "anemone");
    try table.replaceValue(2, column_index, "bee");

    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    const expected_csv =
        \\id,letter,example word
        \\0,a,anemone
        \\1,b,bee
    ;
    try expect(std.mem.eql(u8, exported, expected_csv));
}

test "Delete row using Table.deleteRowByIndex" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\id,letter
        \\0,a
        \\1,b
    );
    try table.deleteRowByIndex(1);

    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    const expected_csv =
        \\id,letter
        \\1,b
    ;
    try expect(std.mem.eql(u8, exported, expected_csv));
}

test "Delete column using Table.deleteColumnByIndex" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\id,letter
        \\0,a
        \\1,b
    );
    try table.deleteColumnByIndex(0);

    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    const expected_csv =
        \\letter
        \\a
        \\b
    ;
    try expect(std.mem.eql(u8, exported, expected_csv));
}

test "Parse row with trailing delimiter" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\a,b,
    );

    const row = try table.getRowByIndex(0);
    try expect(row.len == 3);
    try expect(std.mem.eql(u8, row[0], "a"));
    try expect(std.mem.eql(u8, row[1], "b"));
    try expect(std.mem.eql(u8, row[2], ""));
}

test "Parse multiple consecutive delimiters" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\a,,,d
    );

    const row = try table.getRowByIndex(0);
    try expect(row.len == 4);
    try expect(std.mem.eql(u8, row[0], "a"));
    try expect(std.mem.eql(u8, row[1], ""));
    try expect(std.mem.eql(u8, row[2], ""));
    try expect(std.mem.eql(u8, row[3], "d"));
}

test "Parse unescaped empty field" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\a,,c
    );

    const row = try table.getRowByIndex(0);
    try expect(row.len == 3);
    try expect(std.mem.eql(u8, row[0], "a"));
    try expect(std.mem.eql(u8, row[1], ""));
    try expect(std.mem.eql(u8, row[2], "c"));
}

test "Handle trailing empty row" {
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\a,b
        \\
    );

    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expect(std.mem.eql(u8, exported, "a,b"));
}

test "Fail-fast on empty row" {
    const data =
        \\a,b
        \\
        \\c,d
    ;
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    const result = table.parse(data);
    try expect(result == csv.TableError.InconsistentRowLength);
}

test "Fail-fast on inconsistent row lengths" {
    const data =
        \\a,b
        \\c,d,e"
    ;
    var table = csv.Table.init(allocator, csv.Settings.default());
    defer table.deinit();
    const result = table.parse(data);
    try expect(result == csv.TableError.InconsistentRowLength);
}

test "StructuredTable: Parse CSV into struct and access rows" {
    const DogTable = struct {
        name: []const u8,
        age: u8,
        alive: bool,
        foo: f32,
    };

    var table = StructuredTable(DogTable).init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\name,age,alive,foo
        \\Fido,4,Yes,0.3
        \\Rex,7,0,0.11
    );

    try expect(table.getRowCount() == 2);

    const row_1 = try table.getRow(0);
    const row_1_value = row_1.ok.value;
    const row_2 = try table.getRow(1);
    const row_2_value = row_2.ok.value;
    try expect(table.getRow(2) == csv.TableError.RowNotFound);

    try expect(std.mem.eql(u8, row_1_value.name, "Fido"));
    try expect(std.mem.eql(u8, row_2_value.name, "Rex"));
    try expect(row_1_value.age == 4);
    try expect(row_2_value.age == 7);
    try expect(row_1_value.alive);
    try expect(!row_2_value.alive);
    try expect(row_1_value.foo == 0.3);
    try expect(row_2_value.foo == 0.11);
}

test "StructuredTable: Edit struct row and export to CSV" {
    const DogTable = struct {
        name: []const u8,
        age: u8,
        alive: bool,
        foo: f32,
    };

    var table = StructuredTable(DogTable).init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\name,age,alive,foo
        \\Fido,4,true,0.3
        \\Rex,7,false,0.11
    );

    try expect(table.getRowCount() == 2);

    const row = try table.getRow(0);
    var value = row.ok.value;
    try expect(std.mem.eql(u8, value.name, "Fido"));

    value.name = "Berta";
    _ = try table.editRow(0, value);

    const exported_csv = try table.exportCSV(allocator);
    defer allocator.free(exported_csv);
    const expected_csv =
        \\name,age,alive,foo
        \\Berta,4,true,0.3
        \\Rex,7,false,0.11
    ;
    try expect(std.mem.eql(u8, exported_csv, expected_csv));
}

test "StructuredTable: Delete struct row" {
    const DogTable = struct {
        name: []const u8,
        age: u8,
        alive: bool,
        foo: f32,
    };

    var table = StructuredTable(DogTable).init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\name,age,alive,foo
        \\Fido,4,true,0.3
        \\Rex,7,false,0.11
    );

    try expect(table.getRowCount() == 2);

    try table.deleteRow(0);
    try expect(table.getRowCount() == 1);

    const exported_csv = try table.exportCSV(allocator);
    defer allocator.free(exported_csv);
    const expected_csv =
        \\name,age,alive,foo
        \\Rex,7,false,0.11
    ;
    try expect(std.mem.eql(u8, exported_csv, expected_csv));
}

test "StructuredTable: Create empty struct table and insert rows" {
    const DogTable = struct {
        name: []const u8,
        age: u8,
        alive: bool,
        foo: f32,
    };

    var table = StructuredTable(DogTable).init(allocator, csv.Settings.default());
    defer table.deinit();

    const new_row_1 = DogTable{
        .name = "Buddy",
        .age = 3,
        .alive = true,
        .foo = 0.5,
    };
    _ = try table.insertRow(null, new_row_1);

    const new_row_2 = DogTable{
        .name = "Max",
        .age = 5,
        .alive = false,
        .foo = 0.2,
    };
    _ = try table.insertRow(null, new_row_2);

    try expect(table.getRowCount() == 2);

    const exported_csv = try table.exportCSV(allocator);
    defer allocator.free(exported_csv);
    const expected_csv =
        \\name,age,alive,foo
        \\Buddy,3,true,0.5
        \\Max,5,false,0.2
    ;
    try expect(std.mem.eql(u8, exported_csv, expected_csv));
}

test "StructuredTable: Delete row" {
    const DogTable = struct {
        name: []const u8,
        age: u8,
        alive: bool,
        foo: f32,
    };

    var table = StructuredTable(DogTable).init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\name,age,alive,foo
        \\Fido,4,true,0.3
        \\Rex,7,false,0.11
    );

    try expect(table.getRowCount() == 2);

    try table.deleteRow(0);
    try expect(table.getRowCount() == 1);

    const exported_csv = try table.exportCSV(allocator);
    defer allocator.free(exported_csv);
    const expected_csv =
        \\name,age,alive,foo
        \\Rex,7,false,0.11
    ;
    try expect(std.mem.eql(u8, exported_csv, expected_csv));
}

test "StructureTable: Insert row at specific index" {
    const DogTable = struct {
        name: []const u8,
        age: u8,
        alive: bool,
        foo: f32,
    };

    var table = StructuredTable(DogTable).init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\name,age,alive,foo
        \\Fido,4,true,0.3
        \\Rex,7,false,0.11
    );

    const new_row = DogTable{
        .name = "Buddy",
        .age = 3,
        .alive = true,
        .foo = 0.5,
    };
    _ = try table.insertRow(1, new_row);

    try expect(table.getRowCount() == 3);

    const exported_csv = try table.exportCSV(allocator);
    defer allocator.free(exported_csv);
    const expected_csv =
        \\name,age,alive,foo
        \\Fido,4,true,0.3
        \\Buddy,3,true,0.5
        \\Rex,7,false,0.11
    ;
    try expect(std.mem.eql(u8, exported_csv, expected_csv));
}

test "StructuredTable: Handle parsing error due to invalid csv type" {
    const DogTable = struct {
        name: []const u8,
        age: u8,
        alive: bool,
        foo: f32,
    };

    var table = StructuredTable(DogTable).init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\name,age,alive,foo
        \\Fido,invalid_age,true,0.3
    );
    const result = try table.getRow(0);
    const err = result.@"error";
    try expect(err.kind == csv.StructureError.UnexpectedType);
    try expect(std.mem.eql(u8, err.csv_value.?, "invalid_age"));
    try expect(std.mem.eql(u8, err.field_name.?, "age"));
    try expect(std.mem.eql(u8, err.field_type.?, "u8"));
}
