# CSV Parser Philosophy

## Introduction

This document outlines the philosophy and design principles of the CSV parser library.
It is intended to provide a clear understanding of the design decisions and the reasoning behind them.

## Key Principles

All design decisions should be guided by the following principles:

- **Integrity**: Data integrity is paramount. Data should only be modified in the most expected of ways.
- **Fail-fast**: Ambigous or malformed input should result in immediate failure to avoid cascading errors.
- **Low-level**: The library should provide low-level access for flexibility purposes
- **Real-world compatible:** With high regard to the above, the library should be compatible with real-world data and not just idealized data.

# Escaped fields

Escaped fileds...

1. ...are surrounded by _escape characters_ (usually double quotes).
2. ...can contain any character, including the delimiter and newline characters.
3. ...can contain _escape characters_ themselves, which are preserved by doubling them.
4. ...must be used for all fields that contain the delimiter, newline characters, or _escape characters_ themselves.

The following table shows how escaped fields are parsed (escaped by a double quote character):

| Example                                            | Result                                                    | Additional Note                                                                             |
| -------------------------------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `a,"example string, with delimiter",c`             | `["a", "example string, with delimiter", "c"]`            | Fields are escaped by surrounding them with _escape characters_.                            |
| `a,"example string, with ""escape character""",c`  | `["a", "example string, with \"escape character\"", "c"]` | Delimiters are preserved by doubling them as proposed by the RFC 4180 standard.             |
| `a,"example string,\nwith newline",c`              | `["a", "example string,\nwith newline", "c"]`             | Newlines are preserved in escaped fields.                                                   |
| `a,example string",c`                              | Invalid syntax                                            | Escaped fields must start with an escape character.                                         |
| `a,"example string,c`                              | Invalid syntax                                            | Escaped fields must end with an escape character.                                           |
| `a, "example string",c` or `a,"example string" ,c` | Invalid syntax                                            | Whitespace around quotes is disallowed, since it can lead to ambiguity.                     |
| `a,example "str"ing,c`                             | Invalid syntax                                            | `Escape characters` within unescaped fields is not allowed, since it can lead to ambiguity. |

# Edge Cases

Most of the CSV parser design is adhering to the [RFC 4180 standard](https://www.ietf.org/rfc/rfc4180.txt).
However, there are some edge cases that are not covered by the standard.
These edge cases are handled in a way that is consistent with the principles above.

| Supported Cases                 | Example                                     | Reasoning                                                                                                                                                   |
| ------------------------------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Trailing delimiter              | `a,b,` → `["a", "b", ""]`                   | Each field is separated by a delimiter, so a trailing delimiter should result in an empty field.                                                            |
| Unquoted empty                  | `a,,c` → `["a", "", "c"]`                   | Each field is separated by a delimiter, so an unescaped empty field should result in an empty string.                                                       |
| Multiple consecutive delimiters | `a,,,b` → `["a", "", "", "b"]`              | Each field is separated by a delimiter, so multiple consecutive delimiters should result in empty fields.                                                   |
| Empty escaped field             | `"",x` → `["", "x"]`                        | Escaped fields may be empty, as no data is also valid data - no matter if escaped or not.                                                                   |
| Custom newline                  | rows separated by ex. `\n`, `\r\n`, or `\r` | Configurable line endings are supported (default is `\n`). There is no statical analysis of line endings to enforce consistency in parsing data.            |
| Custom delimiter                | columns separated by ex. `,` or `;`         | Configurable delimiters are supported (default is `,`). There is no statical analysis of delimiters to enforce consistency in parsing data.                 |
| Custom escape character         | fields escaped by ex. `"` or `'`            | Configurable escape characters are supported (default is `"`). There is no statical analysis of escape characters to enforce consistency in parsing data.   |
| Newline as last character       | `a,b\n` → `["a", "b"]`                      | Newline at the end of the file is ignored, as it is not considered part of the data as per the RFC 4180 standard. It is an expected case in many CSV files. |
| Missing final newline           | `a,b,c` EOF                                 | The parser should not require a final newline character at the end of the file, as per the RFC 4180 standard.                                               |
| Missing header row              | -                                           | The header row is optional, as per the RFC 4180 standard. The parser should be able to handle files without a header row.                                   |

| Unsupported Cases                       | Example                                            | Reasoning                                                                                                                                                   |
| --------------------------------------- | -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Empty lines                             | `a,b\n\nc`                                         | Empty lines may be a result of a misconfiguration or an error in the data. The parser should fail-fast to avoid cascading errors.                           |
| Inconsistent row lengths                | `a,b\nc,d,e`                                       | Fail-fast on inconsistent row lengths to ensure data integrity. Each row should have the same number of fields.                                             |
| Backslash escaping                      | `a\,b` → `["a,b"]` or `a,"\"",c` → `["a,\"", "c"]` | Backslash escaping is currently unsupported as it is not part of the RFC 4180 standard and could lead to ambiguity. However, it may be enabled if required. |
| Fields with comment-style trailing text | `a,b # note`                                       | Trailing comments are parsed verbatim and as part of the field. This should be avoided to prevent ambiguity.                                                |

# References

- [RFC 4180](https://www.ietf.org/rfc/rfc4180.txt) - The standard for CSV files.
