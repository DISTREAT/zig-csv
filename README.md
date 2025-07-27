# zig-csv

A library for parsing, creating, and manipulating CSV data.

## Features

- Data integrity: modifications are explicit and predictable.
- Fail-fast: ambiguous or malformed input results in immediate failure.
- Low-level access: exposes internals for flexibility and control.
- Real-world compatibility: handles edge cases and non-standard CSV formats.

## Example

```zig
const std = @import("std");
const csv = @import("zig-csv");
const allocator = std.heap.allocator;

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
const animal_col = try table.findColumnIndexesByValue(allocator, 0, "animal")[0];
const dog_row = try table.findRowIndexesByValue(allocator, animal_col, "dog")[0];
const color_col = try table.findColumnIndexesByValue(allocator, 0, "color")[0];
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

## Docs

The documentation is created in the directory `docs/` when running `zig build`.

[Documentation](https://distreat.github.io/zig-csv/)
