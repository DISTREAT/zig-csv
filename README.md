# zig-csv

A library for parsing, creating, and manipulating CSV data in Zig.

## Features

- Data integrity: modifications are explicit and predictable.
- Fail-fast: ambiguous or malformed input results in immediate failure.
- Low-level access: exposes internals for flexibility and control.
- Real-world compatibility: handles edge cases and non-standard CSV formats.

## Philosophy

The design of this library is guided by the principles outlined in the [CSV Parser Philosophy](PHILOSOPHY.md) document,
which emphasizes data integrity, fail-fast behavior, and low-level access to parsed data.
This design approach ensures the library is compatible with real-world CSV data while avoiding ambiguity in parsing.

## Installation

First, add the dependency to your `build.zig.zon`:

```sh
zig fetch --save git+https://github.com/DISTREAT/zig-csv
```

Then, add the package to your `build.zig`:

```zig
const zig_csv = b.dependency("zig_csv", .{});
exe.root_module.addImport("zig_csv", zig_csv.module("zig_csv"));
```

## Usage

The library provides two primary types for working with CSV data:
`StructuredTable` and `Table`.

The differences between them are as follows:
- `StructuredTable` requires a predefined schema,
  allowing for type-safe parsing and manipulation of CSV data.
- `Table` offers a more flexible approach, enabling dynamic
  handling of CSV data without a predefined schema.

### StructuredTable

The `StructuredTable` allows you to define a schema for your CSV data,
enabling type-safe parsing and manipulation.

```zig
const std = @import("std");
const csv = @import("zig_csv");
const allocator = std.heap.page_allocator;

// Define a schema for the CSV data
const Animal = struct {
    id: i32,
    name: []const u8,
    happy: ?bool,
};

// Parse CSV data into a StructuredTable
var table = csv.StructuredTable(Animal).init(
    allocator,
    csv.Settings.default()
);
defer table.deinit();
try table.parse(
    \\id,name,happy
    \\1,dog,
    \\2,cat,
    \\3,bird,
);

// Modify the name of the animal with id 2
for (0..table.getRowCount()) |index| {
    // Retrieve the row at the current index.
    const row = try table.getRow(index);
    if (row == .@"error") {
        // If the row structure doesn't match the schema, handle the error.
        break;
    }
    // Access the parsed Animal struct from the row.
    var animal = row.ok.value;
    // Look for the animal with id == 2.
    if (animal.id != 2) continue;

    // Change the animal's name to "mouse".
    animal.name = "mouse";
    // Attempt to write the modified struct back to the table.
    const result = try table.editRow(index, animal);
    if (result == .@"error") {
        // If the new struct doesn't match the schema, handle the error.
    }
    // Stop after editing the first matching row.
    break;
}

// Export the table back to CSV
const exported_csv = try table.exportCSV(allocator);
defer allocator.free(exported_csv);
std.debug.print("Exported CSV:\n{s}\n", .{exported_csv});
// id,name,happy
// 1,dog,
// 2,mouse,
// 3,bird,

```

### Table

The `Table` type provides a flexible way to work with CSV data without a predefined schema.

```zig
const std = @import("std");
const csv = @import("zig_csv");
const allocator = std.heap.page_allocator;

// Parse CSV data
var table = csv.Table.init(allocator, csv.Settings.default());
defer table.deinit();
try table.parse(
    \\id,animal,color
    \\1,cat,black
    \\2,dog,brown
    \\3,bird,blue
);

// Change the color of the dog to "white"
const animal_col = (try table.findColumnIndexesByValue(allocator, 0, "animal"))[0];
const dog_row = (try table.findRowIndexesByValue(allocator, animal_col, "dog"))[0];
const color_col = (try table.findColumnIndexesByValue(allocator, 0, "color"))[0];
try table.replaceValue(dog_row, color_col, "white");

// Add a new animal
const new_row = try table.insertEmptyRow(null);
try table.replaceValue(new_row, animal_col, "fish");
try table.replaceValue(new_row, color_col, "gold");

// Export the table back to CSV
const exported = try table.exportCSV(allocator);
defer allocator.free(exported);

std.debug.print("Exported CSV:\n{s}\n", .{exported});
// id,animal,color
// 1,cat,black
// 2,dog,white
// 3,bird,blue
// ,fish,gold
```

_More examples can be found in `src/tests.zig`._

## Documentation

The documentation is available [online](https://distreat.github.io/zig-csv/),
or can be built locally using `zig build docs`.
