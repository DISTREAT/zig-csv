const std = @import("std");
const csv = @import("zig_csv");
const allocator = std.testing.allocator;
const expect = std.testing.expect;
const expectEqualString = std.testing.expectEqualStrings;
const Lexer = csv.parser.Lexer;
const LexerSettings = csv.parser.LexerSettings;
const Parser = csv.parser.Parser;
const ParserError = csv.parser.ParserError;
const Token = csv.parser.Token;
const TokenValuePair = csv.parser.TokenValuePair;

fn expect_token_value_pair(token_value_pair: TokenValuePair, expected_token_value_pair: TokenValuePair) anyerror!void {
    try expect(token_value_pair.token == expected_token_value_pair.token);
    if (token_value_pair.value == null or expected_token_value_pair.value == null) {
        try expect(token_value_pair.value == null);
        try expect(expected_token_value_pair.value == null);
    } else {
        try expectEqualString(expected_token_value_pair.value.?, token_value_pair.value.?);
    }
}

fn expect_parser_field_next(parser: *Parser, expected: []const u8) anyerror!void {
    const result = try parser.next(allocator);
    try expect(result != null);
    try expect(result.? == .field);
    defer allocator.free(result.?.field);
    try expectEqualString(expected, result.?.field);
}

test "Lexer(Token.DELIMITER): basic test" {
    const data =
        \\ABC,DEF
    ;
    var lexer = Lexer.init(LexerSettings.default(), data);
    try expect_token_value_pair(lexer.next().?, .{ .token = Token.TEXT, .value = "ABC" });
    try expect_token_value_pair(lexer.next().?, .{ .token = Token.DELIMITER, .value = null });
    try expect_token_value_pair(lexer.next().?, .{ .token = Token.TEXT, .value = "DEF" });
    try expect(lexer.next() == null);
}

test "Lexer(Token.TERMINATOR): basic test" {
    const data =
        \\ABC
        \\DEF
    ;
    var lexer = Lexer.init(LexerSettings.default(), data);
    try expect_token_value_pair(lexer.next().?, .{ .token = Token.TEXT, .value = "ABC" });
    try expect_token_value_pair(lexer.next().?, .{ .token = Token.TERMINATOR, .value = null });
    try expect_token_value_pair(lexer.next().?, .{ .token = Token.TEXT, .value = "DEF" });
    try expect(lexer.next() == null);
}

test "Lexer(Token.QUOTE): basic test" {
    const data =
        \\"ABC"
    ;
    var lexer = Lexer.init(LexerSettings.default(), data);
    try expect_token_value_pair(lexer.next().?, .{ .token = Token.QUOTE, .value = null });
    try expect_token_value_pair(lexer.next().?, .{ .token = Token.TEXT, .value = "ABC" });
    try expect_token_value_pair(lexer.next().?, .{ .token = Token.QUOTE, .value = null });
    try expect(lexer.next() == null);
}

test "Lexer(Token.ESCAPE): basic test" {
    const data =
        \\ABC\,DEF
    ;
    var settings = LexerSettings.default();
    settings.escape = "\\";
    var lexer = Lexer.init(settings, data);
    try expect_token_value_pair(lexer.next().?, .{ .token = Token.TEXT, .value = "ABC" });
    try expect_token_value_pair(lexer.next().?, .{ .token = Token.ESCAPE, .value = null });
    try expect_token_value_pair(lexer.next().?, .{ .token = Token.DELIMITER, .value = null });
    try expect_token_value_pair(lexer.next().?, .{ .token = Token.TEXT, .value = "DEF" });
    try expect(lexer.next() == null);
}

test "Parser(DELIMITER): basic test" {
    const data =
        \\ABC,DEF
    ;
    var parser = Parser.init(LexerSettings.default(), data);
    try expect_parser_field_next(&parser, "ABC");
    try expect_parser_field_next(&parser, "DEF");
    try expect(try parser.next(allocator) == null);
}

test "Parser(TERMINATOR): basic test" {
    const data =
        \\ABC
        \\DEF
    ;
    var parser = Parser.init(LexerSettings.default(), data);
    try expect_parser_field_next(&parser, "ABC");
    try expect((try parser.next(allocator)).? == .end_of_row);
    try expect_parser_field_next(&parser, "DEF");
    try expect(try parser.next(allocator) == null);
}

test "Parser(QUOTE): legal quotation cases" {
    const data =
        \\""
        \\"ABC"
        \\"DEF",GHI
        \\JKL,"MNO"
        \\"PQR","STU"
    ;
    var parser = Parser.init(LexerSettings.default(), data);
    try expect_parser_field_next(&parser, "");
    try expect((try parser.next(allocator)).? == .end_of_row);
    try expect_parser_field_next(&parser, "ABC");
    try expect((try parser.next(allocator)).? == .end_of_row);
    try expect_parser_field_next(&parser, "DEF");
    try expect_parser_field_next(&parser, "GHI");
    try expect((try parser.next(allocator)).? == .end_of_row);
    try expect_parser_field_next(&parser, "JKL");
    try expect_parser_field_next(&parser, "MNO");
    try expect((try parser.next(allocator)).? == .end_of_row);
    try expect_parser_field_next(&parser, "PQR");
    try expect_parser_field_next(&parser, "STU");
    try expect(try parser.next(allocator) == null);
}

test "Parser(QUOTE): empty value" {
    const data =
        \\""
    ;
    var parser = Parser.init(LexerSettings.default(), data);
    try expect_parser_field_next(&parser, "");
    try expect(try parser.next(allocator) == null);
}

test "Parser(QUOTE): ignores delimiters" {
    const data =
        \\";"
    ;
    var parser = Parser.init(LexerSettings.default(), data);
    try expect_parser_field_next(&parser, ";");
    try expect(try parser.next(allocator) == null);
}

test "Parser(QUOTE): ignores terminators" {
    const data =
        \\"
        \\"
    ;
    var parser = Parser.init(LexerSettings.default(), data);
    try expect_parser_field_next(&parser, "\n");
    try expect(try parser.next(allocator) == null);
}

test "Parser(QUOTE): illegal quotation" {
    const data =
        \\"ABC" DEF,GHI
    ;
    var parser = Parser.init(LexerSettings.default(), data);
    try expect(parser.next(allocator) == ParserError.IllegalQuotation);
}

test "Parser(QUOTE): unfinished quotation" {
    const data =
        \\"ABC,DEF
    ;
    var parser = Parser.init(LexerSettings.default(), data);
    try expect(parser.next(allocator) == ParserError.UnfinishedQuotation);
}

test "Parser(ESCAPE): ignores delimiters" {
    const data =
        \\\,
    ;
    var settings = LexerSettings.default();
    settings.escape = "\\";
    var parser = Parser.init(settings, data);
    try expect_parser_field_next(&parser, ",");
    try expect(try parser.next(allocator) == null);
}

test "Parser(ESCAPE): ignores terminators" {
    const data =
        \\\
        \\
    ;
    var settings = LexerSettings.default();
    settings.escape = "\\";
    var parser = Parser.init(settings, data);
    try expect_parser_field_next(&parser, "\n");
    try expect(try parser.next(allocator) == null);
}

test "Parser(ESCAPE): ignores quotes" {
    const data =
        \\\"
    ;
    var settings = LexerSettings.default();
    settings.escape = "\\";
    var parser = Parser.init(settings, data);
    try expect_parser_field_next(&parser, "\"");
    try expect(try parser.next(allocator) == null);
}

test "Parser: empty fields" {
    const data =
        \\
        \\,
    ;
    var parser = Parser.init(LexerSettings.default(), data);
    try expect_parser_field_next(&parser, "");
    try expect((try parser.next(allocator)).? == .end_of_row);
    try expect_parser_field_next(&parser, "");
    try expect_parser_field_next(&parser, "");
    try expect(try parser.next(allocator) == null);
}
