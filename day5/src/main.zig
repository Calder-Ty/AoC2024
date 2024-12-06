const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const sort = std.sort;
const Allocator = std.mem.Allocator;
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const global_alloc = arena.allocator();
const max_read = 21 * 1024;

// Cheating? I just inspected the data and 
// see what minimum and maximum page values were
const min = 11;
const max = 99;

const ChildStatus = enum {
    preceed,
    follows,
    unknown,
};

const OrderingGraph = [max-min+1][max-min+1]ChildStatus;

pub fn main() !void {

    const data = try loadData(global_alloc, "data/prod.txt");
    var split = std.mem.tokenizeSequence(u8, data, "\n\n");
    const ordering_data = split.next().?;
    const update_data = split.next().?;

    const orderings = try parseOrderings(global_alloc, ordering_data);
    const updates = try parseUpdates(global_alloc, update_data);
    const table = buildTable(orderings);

    // part1(updates, table);
    part2(updates, table);
}

fn part1(updates: [][]u8, table: OrderingGraph) void {
    // Now its a sorting and graph problem,
    // The question is (are these arrays sorted?)
    var sum: usize = 0;
    for (updates) |update| {
        if (isInOrder(update, table)) {
            sum += update[update.len/2];
        }
    }
    std.debug.print("Sum is {d}\n", .{sum});
}

fn part2( updates:[][]u8, table: OrderingGraph) void {
    var sum: usize = 0;
    for (updates) |update| {
        if (!putInOrder(update, table)) {
            sum += update[update.len/2];
        }
    }
    std.debug.print("Sum is {d}\n", .{sum});
}

fn parseUpdates(allocator: Allocator, data:[]const u8) ![][]u8{
    var list = std.ArrayList([]u8).init(allocator);
    var iter = std.mem.tokenizeScalar(u8, data, '\n');
    while (iter.next()) |d| {
        var inner = std.ArrayList(u8).init(allocator);
        var updates = std.mem.tokenizeScalar(u8, d, ',');
        while (updates.next()) |value| {
            try inner.append(try std.fmt.parseInt(u8,value, 10));
        }
        try list.append(try inner.toOwnedSlice());
    }
    return list.toOwnedSlice();
}

fn parseOrderings(allocator: Allocator, data: []const u8) ![]Ordering {
    var iter = std.mem.tokenizeAny(u8, data, "\n|");
    var list = std.ArrayList(Ordering).init(allocator);
    while (iter.next()) |first| {
        const last = iter.next().?;

        try list.append(.{.first=try std.fmt.parseInt(u8, first, 10),
            .last=try std.fmt.parseInt(u8, last, 10),
        });

    }
    return list.toOwnedSlice();
}

fn buildTable(orderings: []Ordering ) OrderingGraph{
    // Is there a better way to initailzie an multidimensional array?
    var table: OrderingGraph= .{
        [_]ChildStatus{.unknown} ** (max-min + 1)
    } ** (max - min + 1);

    for (orderings) |value| {
        const i_first = value.first - min;
        const i_last = value.last - min;
        table[i_first][i_last] = .preceed;
        table[i_last][i_first] = .follows;
    }
    return table;
}

/// Load the Data from path
fn loadData(allocator: Allocator, path: []const u8) ![]u8 {
    const fd = try fs.cwd().openFile(path, .{});
    return try fd.readToEndAlloc(allocator, max_read);
}

const Ordering = struct {
    first: u8,
    last: u8
};


fn isInOrder(update: []u8, table: OrderingGraph) bool {
    var isValid = true;
    for (update, 1..) |check, i| {
        for (update[i..]) |checked| {
            const i_check = check - min;
            const i_checked = checked - min;
            if (table[i_check][i_checked] == .follows) {
                isValid = false;
                break;
            }
        }
    }
    return isValid;
}

fn putInOrder(update: []u8, table: OrderingGraph) bool {
    var isValid = true;
    for (update, 1..) |check, i| {
        for (update[i..]) |checked| {
            const i_check = check - min;
            const i_checked = checked - min;
            if (table[i_check][i_checked] == .follows) {
                sort.insertion(u8, update, table, lessThan);
                isValid = false;
                break;
            }
        }
    }
    return isValid;
}


fn lessThan(context: OrderingGraph, lhs: u8, rhs:u8) bool {
    const i_lhs = lhs - min;
    const i_rhs = rhs - min;
    return context[i_lhs][i_rhs] != .follows;
}
