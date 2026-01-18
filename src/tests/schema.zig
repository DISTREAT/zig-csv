const std = @import("std");
const csv = @import("zig_csv");
const expect = std.testing.expect;
const allocator = std.testing.allocator;
const StructuredTable = csv.StructuredTable;

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

test "StructuredTable: Optional fields parse and null behavior" {
    const DogTableOpt = struct {
        name: ?[]const u8,
        age: ?u8,
        alive: ?bool,
        foo: ?f32,
    };

    var table = StructuredTable(DogTableOpt).init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\name,age,alive,foo
        \\Fido,4,Yes,0.3
        \\,,,
    );

    try expect(table.getRowCount() == 2);

    const row_0 = try table.getRow(0);
    const value_0 = row_0.ok.value;
    try expect(std.mem.eql(u8, value_0.name.?, "Fido"));
    try expect(value_0.age.? == 4);
    try expect(value_0.alive.?);
    try expect(value_0.foo.? == 0.3);

    const row_1 = try table.getRow(1);
    const value_1 = row_1.ok.value;
    try expect(value_1.name == null);
    try expect(value_1.age == null);
    try expect(value_1.alive == null);
    try expect(value_1.foo == null);
}

test "StructuredTable: Optional fields edit writes empty when null" {
    const DogTableOpt = struct {
        name: ?[]const u8,
        age: ?u8,
        alive: ?bool,
        foo: ?f32,
    };

    var table = StructuredTable(DogTableOpt).init(allocator, csv.Settings.default());
    defer table.deinit();
    try table.parse(
        \\name,age,alive,foo
        \\Fido,4,true,0.3
    );

    const row = try table.getRow(0);
    var value = row.ok.value;
    value.name = null;
    value.age = null;
    value.alive = null;
    value.foo = null;

    _ = try table.editRow(0, value);

    const exported = try table.exportCSV(allocator);
    defer allocator.free(exported);
    const expected_csv =
        \\name,age,alive,foo
        \\,,,
    ;
    try expect(std.mem.eql(u8, exported, expected_csv));
}
