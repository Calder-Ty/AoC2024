//! https://adventofcode.com/2024/day/6
//
// 1999 is too large
// 1940 ?
// 1939 ? its wrong
// 1075 ? it's wrong, but i wanted to see why went wrong
// 500 is too low
const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const sort = std.sort;
const Allocator = std.mem.Allocator;
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const global_alloc = arena.allocator();
const max_read = 21 * 1024;

const size = 130;
var steps: usize = 0;

const StepData = struct {
    // Keep track of the direction traveled when visited
    directions: Directions,
};

const Directions = packed struct {
    north: bool = false,
    east: bool = false,
    south: bool = false,
    west: bool = false,

    fn empty() Directions {
        return .{};
    }
};

const VisitedRow = [size]?StepData;
const Visited = [size]VisitedRow;
var map: [size][]u8 = undefined;

const ObstaclePositionsRow = std.bit_set.StaticBitSet(size);
const ObstaclePositions = [size]ObstaclePositionsRow;

var obstaclePositions: ObstaclePositions = [1]ObstaclePositionsRow{ObstaclePositionsRow.initEmpty()} ** size;

pub fn main() !void {
    for (&map) |*row| {
        row.* = try global_alloc.alloc(u8, size);
    }
    const data = try loadData(global_alloc, "data/prod.txt");
    var visited: Visited = [_]VisitedRow{[_]?StepData{null} ** size} ** size;

    var iter = std.mem.tokenizeScalar(u8, data, '\n');

    var row_num: u8 = 0;
    var guard = Guard{ .pos = undefined, .direction = '.' };
    while (iter.next()) |map_row| : (row_num += 1) {
        @memcpy(map[row_num][0..map_row.len], map_row);
        if (std.mem.indexOfAny(u8, map_row, "^><v")) |col| {
            guard.pos = .{ .row = row_num, .col = @truncate(col) };
            guard.direction = map_row[col];
        }
    }

    // Let's walk (Part 1)
    _ = try walkRoute(guard, row_num, &visited);
    var sum: usize = 0;
    for (visited) |row_line| {
        sum += count(row_line);
    }

    var loops: usize = 0;
    for (obstaclePositions) |row| {
        loops += row.count();
    }
    std.debug.print("Traveled {d} spaces\n", .{sum});
    std.debug.print("Found {d} possible loops\n", .{loops});
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

fn walkRoute(grd: Guard, max_rows: usize, visited: *Visited) !usize {
    var guard = grd;
    var total_loops: usize = 0;

    // Let's walk
    while (guard.pos.col < max_rows and guard.pos.col >= 0 and guard.pos.row < max_rows and guard.pos.row >= 0) {
        // Search for loops
        if (try findLoop(guard, max_rows, visited)) {
            total_loops += 1;
        }

        var step: StepData = visited[guard.pos.row][guard.pos.col] orelse .{ .directions = Directions.empty() };
        switch (guard.direction) {
            '^' => step.directions.north = true,
            '>' => step.directions.east = true,
            'v' => step.directions.south = true,
            '<' => step.directions.west = true,
            else => unreachable,
        }
        visited[guard.pos.row][guard.pos.col] = step;
        if (!mvGuard(&guard, max_rows)) {
            break;
        }
    }
    try drawpath(visited, 9999, null, guard);
    return total_loops;
}

fn mvGuard(guard: *Guard, max_rows: usize) bool {
    const ret = switch (guard.direction) {
        '^' => ret: {
            if (guard.pos.row == 0) break :ret false ;
            if (map[guard.pos.row - 1][guard.pos.col] == '#') {
                guard.turn();
            } else guard.pos.row -= 1;
            break :ret true;
        },
        '>' => ret: {
            if (guard.pos.col == max_rows - 1) break :ret false;
            if (map[guard.pos.row][guard.pos.col + 1] == '#') {
                guard.turn();
            } else guard.pos.col += 1;
            break :ret true;
        },
        'v' => ret: {
            if (guard.pos.row == max_rows - 1) break :ret false;
            if (map[guard.pos.row + 1][guard.pos.col] == '#') {
                guard.turn();
            } else guard.pos.row += 1;
            break :ret true;
        },
        '<' => ret: {
            if (guard.pos.col == 0) break :ret false;
            if (map[guard.pos.row][guard.pos.col - 1] == '#') {
                guard.turn();
            } else guard.pos.col -= 1;
            break :ret true;
        },
        else => true,
    };
    return ret;
}

// Counts the number of loops (part2)
fn findLoop(grd: Guard, max_rows: usize, visited: *Visited) !bool {
    var guard: Guard = grd;
    // Don't block if the guard is on the edge, or there is already an obstacle
    const block: Coord = switch (guard.direction) {
        '^' => blk: {
            if (guard.pos.row == 0) {
                return false;
            }
            if (map[guard.pos.row - 1][guard.pos.col] == '#') {
                return false;
            }
            break :blk .{ .row = guard.pos.row - 1, .col = guard.pos.col };

        },
        '>' => blk: {
            if (guard.pos.col == max_rows) {
                return false;
            }
            if (map[guard.pos.row][guard.pos.col + 1] == '#') {
                return false;
            }
            break :blk .{ .row = guard.pos.row, .col = guard.pos.col + 1 };
        },
        'v' => blk: {
            if (guard.pos.row == max_rows) {
                return false;
            }
            if (map[guard.pos.row + 1][guard.pos.col] == '#') {
                return false;
            }
            break :blk .{ .row = guard.pos.row + 1, .col = guard.pos.col };
        },
        '<' => blk: {
            if (guard.pos.col == 0) {
                return false;
            }
            if (map[guard.pos.row][guard.pos.col - 1] == '#') {
                return false;
            }
            break :blk .{ .row = guard.pos.row, .col = guard.pos.col - 1 };
        },
        else => unreachable,
    };

    const temp = map[block.row][block.col];
    map[block.row][block.col] = '#';
    defer map[block.row][block.col] = temp;
    var hypothetical: Visited = undefined;
    @memcpy(&hypothetical, visited);
    hypothetical[guard.pos.row][guard.pos.col] = .{ .directions = guard.getDirection() };
    guard.turn();

    // Redo the walk... But at each step, we need to check for loops!
    walk: while (guard.pos.col < max_rows and guard.pos.col >= 0 and guard.pos.row < max_rows and guard.pos.row >= 0) {
        // Have we been here before:
        var step: StepData = hypothetical[guard.pos.row][guard.pos.col] orelse .{ .directions = Directions.empty() };
        if ((@as(u4, @bitCast(guard.getDirection())) & @as(u4, @bitCast(step.directions))) == @as(u4, @bitCast(guard.getDirection()))) {
            obstaclePositions[block.row].set(block.col);
            try drawpath(&hypothetical, steps, block, guard);
            std.debug.print("x={d}, y={d}\n", .{block.col, block.row});
            return true;
        }
        switch (guard.direction) {
            '^' => step.directions.north = true,
            '>' => step.directions.east = true,
            'v' => step.directions.south = true,
            '<' => step.directions.west = true,
            else => unreachable,
        }
        hypothetical[guard.pos.row][guard.pos.col] = step;

        if (!mvGuard(&guard, max_rows)) {
            break :walk;
        }

    } 
    steps += 1;
    return false;
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

    fn getDirection(self: Guard) Directions {
        return switch (self.direction) {
            '^' => .{ .north = true },
            '>' => .{ .east = true },
            'v' => .{ .south = true },
            '<' => .{ .west = true },
            else => unreachable,
        };
    }
};

/// Load the Data from path
fn loadData(allocator: Allocator, path: []const u8) ![]u8 {
    const fd = try fs.cwd().openFile(path, .{});
    return try fd.readToEndAlloc(allocator, max_read);
}

fn drawpath(path: *Visited, i: usize, block: ?Coord, guard: Guard) !void {
    var canvas: [size][size]u8 = undefined;
    for (&canvas, 0..) |*v, x| {
        @memcpy(v[0..map[x].len], map[x]);
    }
    for (path, 0..) |row, y| {
        for (row[0..map[y].len], 0..) |value, x| {
            if (map[y][x] == '^' or map[y][x] == '>' or map[y][x] == 'v' or map[y][x] == '<') {
                continue;
            }
            if (value) |v| {
                const char: u8 = char: {
                    if ((v.directions.north or v.directions.south) and !v.directions.east and !v.directions.west) {
                        break :char '|';
                    }
                    if ((v.directions.west or v.directions.east) and !v.directions.north and !v.directions.south) {
                        break :char '-';
                    }
                    if ((v.directions.west or v.directions.east) and (v.directions.north or v.directions.south)) {
                        break :char '+';
                    }
                    unreachable;
                };
                canvas[y][x] = char;
            }
        }
    }
    if (block) |blk| {
        canvas[blk.row][blk.col] = 'O';
    }
    canvas[guard.pos.row][guard.pos.col] = 'G';

    const fd = try fs.cwd().createFile(try fmt.allocPrint(global_alloc, "out/{d}.txt", .{i}), .{});
    defer fd.close();
    var bufferdWriter = std.io.bufferedWriter(fd.writer());
    for (canvas) |value| {
        _ = try bufferdWriter.write(&value);
        _ = try bufferdWriter.write("\n");
    }
    try bufferdWriter.flush();
}
