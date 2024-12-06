// #! https://adventofcode.com/2024/day/6
const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const sort = std.sort;
const Allocator = std.mem.Allocator;
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const global_alloc = arena.allocator();
const max_read = 21 * 1024;

const size = 130;

const StepData = struct {
    // Keep track of the direction traveled when visited
    directions: Directions,
};

const Directions = packed struct {
    north: bool,
    east: bool,
    south: bool,
    west: bool,

    fn empty() Directions {
        return .{ .north = false, .east = false, .south = false, .west = false };
    }
};

const VisitedRow = [size]?StepData;
const Visited = [size]VisitedRow;
var map: [size][]const u8 = undefined;

pub fn main() !void {
    const data = try loadData(global_alloc, "data/prod.txt");
    var visited: Visited = [_]VisitedRow{[_]?StepData{null} ** size} ** size;

    var iter = std.mem.tokenizeScalar(u8, data, '\n');

    var row_num: u8 = 0;
    var guard = Guard{ .pos = undefined, .direction = '.' };
    while (iter.next()) |map_row| : (row_num += 1) {
        map[row_num] = map_row;
        if (std.mem.indexOfAny(u8, map_row, "^><v")) |col| {
            guard.pos = .{ .row = row_num, .col = @truncate(col) };
            guard.direction = map_row[col];
        }
    }

    // Let's walk (Part 1)
    walkRoute(guard, row_num, &visited);
    var sum: usize = 0;
    for (visited) |row_line| {
        sum += count(row_line);
    }
    std.debug.print("Traveled {d} spaces\n", .{sum});
}

fn count(row: VisitedRow) usize {
    var sum: usize = 0;
    for (row) |v| {
        if (v != null) {
            sum += 1;
        }
    }
    return sum;
}

fn walkRoute(grd: Guard, max_rows: usize, visited: *Visited) void {
    var guard = grd;
    // Let's walk
    while (guard.pos.col < max_rows and guard.pos.col >= 0 and guard.pos.row < max_rows and guard.pos.row >= 0) {
        var step: StepData = if (visited[guard.pos.col][guard.pos.row] != null) visited[guard.pos.col][guard.pos.row].? else .{ .directions = Directions.empty() };
        switch (guard.direction) {
            '^' => step.directions.north = true,
            '>' => step.directions.east = true,
            'v' => step.directions.south = true,
            '<' => step.directions.west = true,
            else => unreachable,
        }
        visited[guard.pos.col][guard.pos.row] = step;
        switch (guard.direction) {
            '^' => {
                if (guard.pos.row == 0) break;
                if (map[guard.pos.row - 1][guard.pos.col] == '#') {
                    guard.turn();
                } else guard.pos.row -= 1;
            },
            '>' => {
                if (guard.pos.col == max_rows - 1) break;
                if (map[guard.pos.row][guard.pos.col + 1] == '#') {
                    guard.turn();
                } else guard.pos.col += 1;
            },
            'v' => {
                if (guard.pos.row == max_rows - 1)  break;
                if (map[guard.pos.row + 1][guard.pos.col] == '#') {
                    guard.turn();
                } else guard.pos.row += 1;
            },
            '<' => {
                if (guard.pos.col == 0) break;
                if (map[guard.pos.row][guard.pos.col - 1] == '#') {
                    guard.turn();
                } else guard.pos.col -= 1;
            },
            else => {},
        }
    }
}

const Coord = struct {
    row: u8,
    col: u8,
};

const Guard = struct {
    pos: Coord,
    direction: u8,

    fn turn(self: *Guard) void {
        switch (self.direction) {
            '^' => self.direction = '>',
            '>' => self.direction = 'v',
            'v' => self.direction = '<',
            '<' => self.direction = '^',
            else => unreachable,
        }
    }
};

/// Load the Data from path
fn loadData(allocator: Allocator, path: []const u8) ![]u8 {
    const fd = try fs.cwd().openFile(path, .{});
    return try fd.readToEndAlloc(allocator, max_read);
}

// Part 2:
//
// We need to discover if there are opportunities to create
// loops in the guards path.
//
// A loop is anytime a traversal is made that would retread
// on previous locations. we could map this as a graph with
// some special properties
//
// Each node is directed, but it is directed in a way that
// we can always know, base off of the incoming direction
// (North -> East) (East -> South) (South -> West) (West -> North)
// We can then build out a graph of visited nodes.
