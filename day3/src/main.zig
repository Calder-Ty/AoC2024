const std = @import("std");
const fs = std.fs;
const Allocator= std.mem.Allocator;
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const global_alloc = arena.allocator();
const max_read = 20 * 1024;


pub fn main() !void {
    defer arena.deinit();
    const data = try loadData(global_alloc, "data/prod.txt");
    const tokens = try lex(global_alloc, data);
    parseTokens(tokens);
}

/// Load the Data from path
fn loadData(allocator: Allocator, path: []const u8) ![]u8 {
    const fd = try fs.cwd().openFile(path, .{});
    return try fd.readToEndAlloc(allocator, max_read);
}

fn parseTokens(tokens: []Token) void {
    var pp: usize = 0;
    var sum: isize = 0;
    var on = true;
    while (pp < tokens.len) {
        if (tokens[pp] == .on) {
            on = true;
            pp += 1;
        }
        if (tokens[pp] == .off) {
            on = false;
            pp += 1;
        }
        if (!on) {
            pp += 1;
            continue;
        }
        if (parseEquation(tokens[pp..])) |eq| {
            pp += 5;
            sum += eq.a * eq.b;
        } else {
            pp += 1;
        }
    }
    std.debug.print("The sum is: {d}", .{sum});
}

fn parseEquation(tokens: []Token) ?Equation {
    if (tokens.len < 5) {
        return null;
    }
    if (tokens[0] == .mul_start and 
        tokens[1] == .digit and
        tokens[2] == .comma and
        tokens[3] == .digit and
        tokens[4] == .mul_end) {
        return Equation{.a = tokens[1].digit, .b = tokens[3].digit};
    } else {
        return null;
    }
}

const Equation = struct {
    a: isize,
    b: isize,
};

/// Lets build a simple parser, rather than reach for regex
const Token = union(enum) {
    mul_start,
    digit: isize,
    mul_end,
    comma,
    garbage,
    on,
    off,
};

/// Read in data and generate a stream of tokens
fn lex(allocator: Allocator, bytes: []const u8) ![]Token {
    var list = std.ArrayList(Token).init(allocator);
    var pp: usize = 0;
    while (pp < bytes.len) {
        const byte = bytes[pp];
        switch (byte) {
            'd' => {
                if(std.mem.startsWith(u8, bytes[pp..], "do()")) {
                    try list.append(.on);
                    pp += 4;
                } else if (std.mem.startsWith(u8, bytes[pp..], "don't()")) {
                    try list.append(.off);
                    pp += 7;
                } else {
                    pp += 1;
                }
            },
            'm' => {
                if (std.mem.eql(u8, "mul(", bytes[pp..pp+4])) {
                    try list.append(.mul_start);
                    pp += 4;
                } else {
                    try list.append(.garbage);
                    pp += 1;
                }
            },
            ')' => {try list.append(.mul_end); pp+=1;},
            ',' => {try list.append(.comma); pp+=1;},
           0x30...0x39 => {
               var x: usize = 1;
               while (x < 3): (x+=1) {
                   if (bytes[pp+x] < 0x30 or bytes[pp+x] > 0x39) {
                       try list.append(.{.digit=try std.fmt.parseInt(isize, bytes[pp..pp+x], 10)});
                       break;
                   }
               } else {
                   try list.append(.{.digit=try std.fmt.parseInt(isize, bytes[pp..pp+x], 10)});
               }
               pp += x;
           },
           else => {
               try list.append(.garbage);
               pp += 1;
           }
        }
    }
    return list.toOwnedSlice();
}


