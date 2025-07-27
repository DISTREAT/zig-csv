const std = @import("std");
const table = @import("table.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Token = enum {
    DELIMITER,
    ESCAPE,
    QUOTE,
    TERMINATOR,
    TEXT,
};

pub const TokenValuePair = struct {
    token: Token,
    value: ?[]const u8,
};

pub const LexerSettings = struct {
    /// Byte sequence used to separate fields within a row.
    delimiter: []const u8,
    /// Byte sequence used to escape special syntax within a field.
    /// A null value disables this functionality.
    escape: ?[]const u8,
    /// Byte sequence used to wrap fields as a whole to allow
    /// use of delimiters and terminators inside them.
    quote: []const u8,
    /// Byte sequence used to end a row (i.e., terminates a record).
    terminator: []const u8,

    pub fn default() LexerSettings {
        return LexerSettings{
            .delimiter = ",",
            .escape = null,
            .quote = "\"",
            .terminator = "\n",
        };
    }
};

pub const Lexer = struct {
    cursor: usize = 0,
    data: []const u8,
    settings: LexerSettings,
    text_start: ?usize,

    pub const TOKEN_FIELDS = .{
        .{ .token = Token.DELIMITER, .field_name = "delimiter" },
        .{ .token = Token.ESCAPE, .field_name = "escape" },
        .{ .token = Token.QUOTE, .field_name = "quote" },
        .{ .token = Token.TERMINATOR, .field_name = "terminator" },
    };

    pub fn init(settings: LexerSettings, csv_data: []const u8) Lexer {
        return Lexer{
            .cursor = 0,
            .data = csv_data,
            .settings = settings,
            .text_start = null,
        };
    }

    pub fn next(self: *Lexer) ?TokenValuePair {
        while (true) {
            if (self.cursor == self.data.len and self.text_start != null) {
                self.cursor += 1;
                return .{ .token = Token.TEXT, .value = self.data[self.text_start orelse unreachable ..] };
            }
            if (self.cursor >= self.data.len) return null;
            const lookahead = self.data[self.cursor..];
            inline for (TOKEN_FIELDS) |token_field| {
                const token_type = token_field.token;
                const token_byteseq: ?[]const u8 = @field(self.settings, token_field.field_name);
                if (token_byteseq != null and
                    std.mem.startsWith(u8, lookahead, token_byteseq.?))
                {
                    const text_start = self.text_start;
                    if (text_start != null) {
                        self.text_start = null;
                        return .{ .token = Token.TEXT, .value = self.data[text_start orelse unreachable .. self.cursor] };
                    }
                    self.cursor += token_byteseq.?.len;
                    return .{ .token = token_type, .value = null };
                }
            }
            if (self.text_start == null) {
                self.text_start = self.cursor;
            }
            self.cursor += 1;
        }
    }
};

pub const ParserError = error{
    /// Certain TokenValuePairs require a value other than null
    ExpectedValueFoundNull,
    /// Quote sequences are expeced at beginning and end of a field
    IllegalQuotation,
    /// Not enough memory
    OutOfMemory,
    /// Starting a field with the QUOTE sequence requires the field
    /// to be closed with the same sequence as well
    UnfinishedQuotation,
};

pub const ParsingResult = union(enum) {
    field: []u8,
    end_of_row: void,
};

pub const Parser = struct {
    expect_field_end_after_quotation: bool,
    in_quotes: bool,
    is_escaped: bool,
    is_row_finished: bool,
    last_token_pair: ?TokenValuePair,
    lexer: Lexer,
    settings: LexerSettings,

    pub fn init(settings: LexerSettings, csv_data: []const u8) Parser {
        const lexer = Lexer.init(settings, csv_data);
        return Parser{
            .expect_field_end_after_quotation = false,
            .in_quotes = false,
            .is_escaped = false,
            .is_row_finished = false,
            .last_token_pair = null,
            .lexer = lexer,
            .settings = settings,
        };
    }

    pub fn next(self: *Parser, allocator: Allocator) ParserError!?ParsingResult {
        if (self.is_row_finished) {
            self.is_row_finished = false;
            return .end_of_row;
        }
        var field: ArrayList(u8) = .empty;
        errdefer field.deinit(allocator);
        while (true) {
            const token_value_pair = self.lexer.next();
            if (self.expect_field_end_after_quotation and token_value_pair != null) {
                switch (token_value_pair.?.token) {
                    Token.DELIMITER, Token.TERMINATOR => {
                        self.expect_field_end_after_quotation = false;
                    },
                    // consecutive double quotes are ignored within an escaped field
                    Token.QUOTE => {
                        self.in_quotes = !self.in_quotes;
                        self.expect_field_end_after_quotation = false;
                        self.is_escaped = true;
                    },
                    // confirm closing quote token only right before ending a field
                    else => {
                        return ParserError.IllegalQuotation;
                    },
                }
            }
            if (token_value_pair == null) break;
            defer self.last_token_pair = token_value_pair;
            if (self.is_escaped) {
                self.is_escaped = false;
                inline for (Lexer.TOKEN_FIELDS) |token_field| {
                    const token_type = token_field.token;
                    const token_byteseq: ?[]const u8 = @field(self.settings, token_field.field_name);
                    if (token_byteseq != null and token_value_pair.?.token == token_type) {
                        try field.appendSlice(allocator, token_byteseq.?);
                        break;
                    }
                }
                continue;
            }
            if (token_value_pair.?.token == Token.ESCAPE) {
                self.is_escaped = true;
            } else if (token_value_pair.?.token == Token.QUOTE) {
                // confirm quote token right after starting new field
                if (
                // quotation must not be toggled on for we assume
                // a new quotation
                !self.in_quotes and
                    // ensure the previous field was closed
                    self.last_token_pair != null and
                    (self.last_token_pair.?.token != Token.DELIMITER and
                        self.last_token_pair.?.token != Token.TERMINATOR))
                {
                    return ParserError.IllegalQuotation;
                }
                if (self.in_quotes) self.expect_field_end_after_quotation = true;
                self.in_quotes = !self.in_quotes;
            } else if (token_value_pair.?.token == Token.TEXT) {
                if (token_value_pair.?.value == null) {
                    return ParserError.ExpectedValueFoundNull;
                }
                try field.appendSlice(allocator, token_value_pair.?.value.?);
            } else if (self.is_escaped) {
                continue;
            } else if (token_value_pair.?.token == Token.DELIMITER or
                token_value_pair.?.token == Token.TERMINATOR)
            {
                if (self.in_quotes) {
                    switch (token_value_pair.?.token) {
                        Token.DELIMITER => try field.appendSlice(allocator, self.settings.delimiter),
                        Token.TERMINATOR => try field.appendSlice(allocator, self.settings.terminator),
                        else => unreachable,
                    }
                } else {
                    if (token_value_pair.?.token == Token.TERMINATOR)
                        self.is_row_finished = true;
                    return ParsingResult{
                        .field = try field.toOwnedSlice(allocator),
                    };
                }
            }
        }
        if (self.in_quotes) {
            return ParserError.UnfinishedQuotation;
        }
        if (field.items.len > 0 or
            (self.last_token_pair != null and (self.last_token_pair.?.token == Token.DELIMITER or
                self.last_token_pair.?.token == Token.QUOTE)))
        {
            // ensure it does not match the condition on the
            // next run, throwing the same field twice
            self.last_token_pair = null;
            return ParsingResult{
                .field = try field.toOwnedSlice(allocator),
            };
        }
        return null;
    }
};
