const std = @import("std");
const csv = @import("zig_csv");
const fixtures = @import("fixtures").fixtures;
const expect = std.testing.expect;
const expectEqualString = std.testing.expectEqualStrings;
const allocator = std.testing.allocator;
const StructuredTable = csv.StructuredTable;

test "Initialize Table using Table.parse and export to CSV via Table.exportCSV" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
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
    try expectEqualString(csv_data, exported);
}

test "Initialize Table using Table.parseRow and export to CSV via Table.exportCSV" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
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
    try expectEqualString(csv_data, exported);
}

test "Initialize Table using custom delimiter and terminator and export to CSV via Table.exportCSV" {
    var table = csv.Table.init(allocator, csv.LexerSettings{
        .delimiter = "-",
        .escape = "\\",
        .quote = "\"",
        .terminator = "|",
    });
    defer table.deinit();
    const csv_data =
        \\1-2-3|a-b-c
    ;
    try table.parse(csv_data);

    const exported: []const u8 = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expectEqualString(csv_data, exported);
}

test "Get number of rows using Table.getRowCount" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    try table.parse(
        \\id,animal name,scientific name
        \\0,rat,rattus rattus
    );
    const row_count = table.getRowCount();
    try expect(row_count == 2);
}

test "Get number of columns using Table.getColumnCount" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    try table.parse(
        \\id,animal name,scientific name
        \\0,rat,rattus rattus
    );
    const column_count = table.getColumnCount();
    try expect(column_count == 3);
}

test "Find indexes of columns using Table.findColumnIndexesByValue" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
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
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
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
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
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
    try expectEqualString("id", column_0[0]);
    try expectEqualString("0", column_0[1]);

    const column_1 = try table.getColumnByIndex(arena_allocator, 1);
    try expect(column_1.len == 2);
    try expectEqualString("letter", column_1[0]);
    try expectEqualString("a", column_1[1]);
}

test "Get row by index using Table.getRowByIndex" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    try table.parse(
        \\id,letter
        \\0,a
    );

    const row_0 = try table.getRowByIndex(0);
    try expect(row_0.len == 2);
    try expectEqualString("id", row_0[0]);
    try expectEqualString("letter", row_0[1]);

    const row_1 = try table.getRowByIndex(1);
    try expect(row_1.len == 2);
    try expectEqualString("0", row_1[0]);
    try expectEqualString("a", row_1[1]);
}

test "Replace values using Table.replaceValue" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
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
    try expectEqualString(expected_csv, exported);
}

test "Replace values containing illegal characters using Table.replaceValues" {
    var table = csv.Table.init(allocator, csv.LexerSettings{
        .delimiter = ",",
        .escape = "\\",
        .quote = "\"",
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
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
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
    try expectEqualString(expected_csv, exported);
    try expect(inserted_at == 2);
}

test "Insert row using Table.insertEmptyRow" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
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
    try expectEqualString(expected_csv, exported);
    try expect(inserted_at == 1);
}

test "Append column using Table.insertEmptyColumn" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
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
    try expectEqualString(expected_csv, exported);
    try expect(inserted_at == 2);
}

test "Insert column using Table.insertEmptyColumn" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
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
    try expectEqualString(expected_csv, exported);
    try expect(inserted_at == 1);
}

test "Append row using Table.insertEmptyRow and Table.replaceValue" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
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
    try expectEqualString(expected_csv, exported);
}

test "Append column using Table.insertEmptyColumn and Table.replaceValue" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
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
    try expectEqualString(expected_csv, exported);
}

test "Delete row using Table.deleteRowByIndex" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
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
    try expectEqualString(expected_csv, exported);
}

test "Delete column using Table.deleteColumnByIndex" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
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
    try expectEqualString(expected_csv, exported);
}

test "Parse row with trailing delimiter" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    try table.parse(
        \\a,b,
    );

    const row = try table.getRowByIndex(0);
    try expect(row.len == 3);
    try expectEqualString("a", row[0]);
    try expectEqualString("b", row[1]);
    try expectEqualString("", row[2]);
}

test "Parse multiple consecutive delimiters" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    try table.parse(
        \\a,,,d
    );

    const row = try table.getRowByIndex(0);
    try expect(row.len == 4);
    try expectEqualString("a", row[0]);
    try expectEqualString("", row[1]);
    try expectEqualString("", row[2]);
    try expectEqualString("d", row[3]);
}

test "Parse unescaped empty field" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    try table.parse(
        \\a,,c
    );

    const row = try table.getRowByIndex(0);
    try expect(row.len == 3);
    try expectEqualString("a", row[0]);
    try expectEqualString("", row[1]);
    try expectEqualString("c", row[2]);
}

test "Handle trailing empty row" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    try table.parse(
        \\a,b
        \\
    );

    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expectEqualString("a,b", exported);
}

test "Fail-fast on empty row" {
    const data =
        \\a,b
        \\
        \\c,d
    ;
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    const result = table.parse(data);
    try expect(result == csv.TableError.InconsistentRowLength);
}

test "Fail-fast on inconsistent row lengths" {
    const data =
        \\a,b
        \\c,d,e
    ;
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    const result = table.parse(data);
    try expect(result == csv.TableError.InconsistentRowLength);
}

test "Parse empty escaped field" {
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    try table.parse(
        \\a,"",c
    );

    const row = try table.getRowByIndex(0);
    try expect(row.len == 3);
    try expectEqualString("a", row[0]);
    try expectEqualString("", row[1]);
    try expectEqualString("c", row[2]);
}

test "Parse with custom escape character" {
    const data =
        \\|a|,|b|
    ;
    var table = csv.Table.init(allocator, csv.LexerSettings{
        .delimiter = ",",
        .escape = "\\",
        .quote = "|",
        .terminator = "\n",
    });
    defer table.deinit();
    try table.parse(data);

    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    const expected_csv =
        \\a,b
    ;
    try expectEqualString(expected_csv, exported);
}

test "Parse escaped field with delimiter" {
    const data =
        \\a,"example string, with delimiter",c
    ;
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    try table.parse(data);

    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expectEqualString(data, exported);
}

test "Parse escaped field with escaped quote characters" {
    const data =
        \\a,"example string, with ""escape character""",c
    ;
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    try table.parse(data);

    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expectEqualString(data, exported);
}

test "Parse escaped field with newline" {
    const data =
        \\a,"example string,
        \\with newline",c
    ;
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    try table.parse(data);

    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    try expectEqualString(data, exported);
}

test "Fail-fast on unopened escaped field" {
    const data =
        \\a,example string",c
    ;
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    const result = table.parse(data);
    try expect(result == csv.ParserError.IllegalQuotation);
}

test "Fail-fast on unclosed escaped field" {
    const data =
        \\a,"example string,c
    ;
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    const result = table.parse(data);
    try expect(result == csv.ParserError.UnfinishedQuotation);
}

test "Fail-fast on whitespace between escape character and delimiter" {
    const data =
        \\"a, "example string",c
    ;
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    const result = table.parse(data);
    try expect(result == csv.ParserError.IllegalQuotation);
}

test "Fail-fast on unescaped escape character" {
    const data =
        \\a,example "str"ing,c
    ;
    var table = csv.Table.init(allocator, csv.LexerSettings.default());
    defer table.deinit();
    const result = table.parse(data);
    try expect(result == csv.ParserError.IllegalQuotation);
}

test "Handle custom escape character in exported CSV" {
    var table = csv.Table.init(allocator, csv.LexerSettings{
        .delimiter = ",",
        .escape = "|",
        .quote = "\"",
        .terminator = "\n",
    });
    defer table.deinit();
    try table.parse(
        \\id,letter
        \\0,a
    );

    try table.replaceValue(1, 1, "example \"word\"");

    const exported: []const u8 = try table.exportCSV(allocator);
    defer allocator.free(exported);
    const expected_csv =
        \\id,letter
        \\0,"example ""word"""
    ;
    try expectEqualString(expected_csv, exported);
}

test "Iterate all valid fixtures" {
    inline for (fixtures) |fixture| {
        var table = csv.Table.init(allocator, csv.LexerSettings.default());
        defer table.deinit();
        table.parse(fixture.data) catch |err| {
            std.debug.print("Fixture: {s}\n", .{fixture.name});
            return err;
        };
        const exported: []const u8 = try table.exportCSV(allocator);
        defer allocator.free(exported);
        expectEqualString(fixture.data[0 .. fixture.data.len - 1], exported) catch |err| {
            std.debug.print("Fixture: {s}\n", .{fixture.name});
            return err;
        };
    }
}
