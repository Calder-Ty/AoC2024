const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const sort = std.sort;
const Allocator = std.mem.Allocator;
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const global_alloc = arena.allocator();
const max_read = 21 * 1024;

const is_test = false;
const data_file = if (is_test) "data/test.txt" else "data/prod.txt";

const u16x2 = @Vector(2, isize);
const CoordPairs = struct { a: u16x2, b: u16x2, prize: u16x2 };

const cost_a = 3;
const cost_b = 1;
const additional_factor = 10_000_000_000_000;

pub fn main() !void {
    const data = try loadData(global_alloc, data_file);
    var iter = std.mem.tokenizeSequence(u8, data, "\n\n");
    var machine_list = std.ArrayList(CoordPairs).init(global_alloc);
    while (iter.next()) |d| {
        try machine_list.append(try parseMachine(d));
    }
    part2(machine_list.items);
}

fn part1(machine_list: []CoordPairs) void {
    var answer:usize = 0;
    for (machine_list) |machine| {
        var token_cost:?usize = null;
        for (0..100) |n_a| {
            for (0..100) |n_b| {
                if (pressButtons(@splat(@truncate(n_a)), @splat(@truncate(n_b)), machine)) |cost| {
                    if (token_cost == null or cost < token_cost.?) {
                        token_cost = cost;
                    }
                }
            }
        }
        if (token_cost) |cost| {
            answer += cost;
        }
    }
    if (is_test) {
        const result: []const u8 = if (answer == 480) "OK" else "FAIL";
        std.debug.print("Testing: answer = {d} [{s}]\n", .{ answer, result });
    } else {
        std.debug.print("Answer = {d}\n", .{answer});
    }
}

/// I want to explain the logic here a bit. Each control can be
/// mapped to a line: 
/// A: X+94, Y+34 => A = (34/94)z
/// B: X+22, Y+67 => B = (67/22)z
///
///
/// Use Cramers Rule:
/// Ax = b
///
/// Det = |A| = x_a * y_b - x_b * y_a
///
/// Detx = x_p * y_b - y_p * 
fn part2(machine_list: []CoordPairs) void {
    var answer:u64 = 0;
    for (machine_list) |v| {
        const det = @abs(v.a[0] * v.b[1] - v.a[1] * v.b[0]);
        if (det == 0) unreachable;
        const det_a = @abs((v.prize[0]+additional_factor)*v.b[1] - (v.prize[1]+additional_factor)*v.b[0]);
        const det_b = @abs((v.prize[0]+additional_factor)*v.a[1] - (v.prize[1]+additional_factor)*v.a[0]);
        if (@mod(det_a, det) == 0 and @mod(det_b, det) == 0) {
            const n_a = @divTrunc(det_a, det);
            const n_b = @divTrunc(det_b, det);
            answer += n_a * 3 + n_b;
        }
    }

    std.debug.print("Answer: {d}", .{answer});
}


fn pressButtons(n_a: u16x2, n_b: u16x2, pairs: CoordPairs) ?usize {
    const res = n_a*pairs.a + n_b * pairs.b;
    if ( res[0] == pairs.prize[0] and res[1] == pairs.prize[1]) {
        return n_a[0] * cost_a + n_b[0] * cost_b;
    }
    return null;
}

fn parseMachine(data: []const u8) !CoordPairs {
    var lines = std.mem.tokenizeScalar(u8, data, '\n');
    const a = try parseButton(lines.next().?);
    const b = try parseButton(lines.next().?);
    const prize = try parsePrize(lines.next().?);

    return .{.a=a, .b=b, .prize=prize};
}

fn parseButton(data: []const u8) !u16x2 {
    // TODO: Do this in one pass (data is neatly ordered)
    const x_start = std.mem.indexOfScalar(u8, data, 'X').?;
    const x_end = std.mem.indexOfScalar(u8, data, ',').?;
    const y_start = std.mem.indexOfScalar(u8, data, 'Y').?;

    const x = try fmt.parseInt(u16, data[x_start + 1 .. x_end], 10);
    const y = try fmt.parseInt(u16, data[y_start + 1 ..], 10);
    return u16x2{ x, y };
}

fn parsePrize(data: []const u8) !u16x2 {
    const x_start = std.mem.indexOfScalar(u8, data, 'X').?;
    const x_end = std.mem.indexOfScalar(u8, data, ',').?;
    const y_start = std.mem.indexOfScalar(u8, data, 'Y').?;
    const x = try fmt.parseInt(u16, data[x_start + 2 .. x_end], 10);
    const y = try fmt.parseInt(u16, data[y_start + 2 ..], 10);
    return .{ x, y };
}

/// Load the Data from path
fn loadData(allocator: Allocator, path: []const u8) ![]u8 {
    const fd = try fs.cwd().openFile(path, .{});
    return try fd.readToEndAlloc(allocator, max_read);
}
