# zig-csv

A library for parsing, creating, and manipulating CSV data.

## Features

- avoiding memory leaks
- flexible and simplistic API

## Example

```zig
const std = @import("std");
const csv = @import("zig-csv");
const allocator = std.heap.allocator;

// parse CSV data
var table = csv.Table.init(allocator, csv.Settings.default());
defer table.deinit();

try table.parse(
    \\id,animal,shorthand
    \\0,dog,d
    \\1,cat,c
    \\2,pig,p
);

// print all animals
const column_indexes_animal = try table.findColumnIndexesByKey(allocator, "animal");
defer allocator.free(column_indexes_animal);

var animals = table.getColumnByIndex(column_indexes_animal[0]);

while (animals.next()) |animal| {
    std.debug.print("{s}", .{animal.value});
}

// replace a value
const column_indexes_id = try table.findColumnIndexesByKey(allocator, "id");
defer allocator.free(column_indexes_id);

const row_indexes_id_2 = try table.findRowIndexesByValue(allocator, column_indexes_id[0], "2");
defer allocator.free(row_indexes_id_2);

try table.replaceValue(row_indexes_id_2[0], column_indexes_animal[0], "porcupine");

// delete a column
try table.deleteColumnByIndex(column_indexes_id[0]);

// export back to CSV
const exported = try table.exportCSV(allocator);
defer allocator.free(exported);

```

_More examples can be found in `src/tests.zig`._

## Docs

The documentation is created in the directory `docs/` when running `zig build`.

[Documentation](https://distreat.github.io/zig-csv/)
