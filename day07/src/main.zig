const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const sort = std.sort;

const Allocator = std.mem.Allocator;
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const global_alloc = arena.allocator();
const max_read = 26 * 1024;

const Operators = enum {
    add,
    multiply,
    concat,
};

pub fn main() !void {
    const data = try loadData(global_alloc, "data/prod.txt");
    const eqs = try parseData(data);
    var total: isize = 0;
    for (eqs) |e| {
        if (isSolvable(e)) {
            total += e.total;
        }
    }
    std.debug.print("Total is: {d}\n", .{total});
}

const Equation = struct {
    total: i64,
    components: []i64,
};

fn parseData(data: []u8) ![]Equation {
    var list = std.ArrayList(Equation).init(global_alloc);
    var lines = std.mem.tokenizeScalar(u8, data, '\n');
    while (lines.next()) |line| {
        var splits = std.mem.tokenizeAny(u8, line, ": ");
        const total = try fmt.parseInt(i64, splits.next().?, 10);
        var comps = std.ArrayList(i64).init(global_alloc);

        while (splits.next()) |tok| {
            const val = try fmt.parseInt(i64, tok, 10);
            try comps.append(val);
        }
        const c = try comps.toOwnedSlice();
        try list.append(.{.total=total, .components = c});
    }
    return list.toOwnedSlice();
}

fn isSolvable(eq: Equation) bool {
    return solve(eq.total, eq.components[0], eq.components[1..], .add) or solve(eq.total, eq.components[0], eq.components[1..], .multiply) or solve(eq.total, eq.components[0], eq.components[1..], .concat);
}

fn solve(total: i64, cumtotal: i64, rest: []i64, operator: Operators) bool {
    if (rest.len == 1) {
        return total == doOp(cumtotal, rest[0], operator);
    } else {
        const c = doOp(cumtotal, rest[0], operator);
        if (c > total) return false;
        return solve(total, c, rest[1..], .add) or solve(total, c, rest[1..], .multiply) or solve(total, c, rest[1..], .concat);
    }
}

fn doOp(a: i64, b: i64, op: Operators) i64 {
    switch (op) {
        .multiply => return a * b,
        .add => return a + b,
        .concat => return concat(a, b),
    }
}

fn concat(a: i64, b: i64) i64 {
    var c = b;
    var n_digits: i8 = 1;
    while (true) : (n_digits += 1) {
        c  = @divFloor(c, 10);
        if (c > 0) continue else break;
    }
    return a * std.math.pow(i64, 10, n_digits) + b;
}

test "concat" {
    try std.testing.expectEqual(110, concat(1, 10));
    try std.testing.expectEqual(10123, concat(10, 123));
}

/// Load the Data from path
fn loadData(allocator: Allocator, path: []const u8) ![]u8 {
    const fd = try fs.cwd().openFile(path, .{});
    return try fd.readToEndAlloc(allocator, max_read);
}
