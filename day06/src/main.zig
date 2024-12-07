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

const Directions = enum {
    north,
    east,
    south,
    west,
};

const StepData = std.EnumSet(Directions);
const VisitedRow = [size]StepData;
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
    var visited: Visited = [_]VisitedRow{[_]StepData{StepData.initEmpty()} ** size} ** size;

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
    walkWithObstacles(guard, row_num, &visited);
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
        if (v.count() > 0) {
            sum += 1;
        }
    }
    return sum;
}

/// Walk route, and check return if loop was found
fn walkRoute(grd: Guard, max_rows: usize, visited: *Visited) bool {
    var guard = grd;

    while (guard.pos.col < max_rows and guard.pos.col >= 0 and guard.pos.row < max_rows and guard.pos.row >= 0) {
        var step: StepData = visited[guard.pos.row][guard.pos.col];
        if (step.contains(guard.getDirection())) return true;
        step.setPresent(guard.getDirection(), true);
        visited[guard.pos.row][guard.pos.col] = step;
        if (!mvGuard(&guard, max_rows)) {
            break;
        }
    }
    return false;
}

fn walkWithObstacles(grd: Guard, max_rows: usize, visited: *Visited) void {
    var guard = grd;
    while (guard.pos.col < max_rows and guard.pos.col >= 0 and guard.pos.row < max_rows and guard.pos.row >= 0) {
        // First check if placing a block will get a loop
        findLoop(guard, max_rows, visited);
        var step: StepData = visited[guard.pos.row][guard.pos.col];
        if (step.contains(guard.getDirection())) break;
        step.setPresent(guard.getDirection(), true);
        visited[guard.pos.row][guard.pos.col] = step;
        if (!mvGuard(&guard, max_rows)) {
            break;
        }
    }
}

// Moves or turns the guard, If guard were to go out of bounds, will return false
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

fn isExiting(guard: Guard, max_rows: usize) bool {
    return (
        guard.getDirection() == .north and guard.pos.row == 0
    ) or (
        guard.getDirection() == .south and guard.pos.row == max_rows
    ) or (
        guard.getDirection() == .east and guard.pos.col == max_rows
    ) or (
        guard.getDirection() == .west and guard.pos.col == 0
    );
}

// Counts the number of loops (part2)
fn findLoop(guard: Guard, max_rows: usize, visited: *Visited) void {

    // Don't block if the guard is leaving the map, or there is already an obstacle
    if (isExiting(guard, max_rows)) {
        return;
    }
    const block: Coord = switch (guard.direction) {
        '^' => blk: {
            if (map[guard.pos.row - 1][guard.pos.col] == '#') {
                return;
            }
            break :blk .{ .row = guard.pos.row - 1, .col = guard.pos.col };

        },
        '>' => blk: {
            if (map[guard.pos.row][guard.pos.col + 1] == '#') {
                return;
            }
            break :blk .{ .row = guard.pos.row, .col = guard.pos.col + 1 };
        },
        'v' => blk: {
            if (map[guard.pos.row + 1][guard.pos.col] == '#') {
                return;
            }
            break :blk .{ .row = guard.pos.row + 1, .col = guard.pos.col };
        },
        '<' => blk: {
            if (map[guard.pos.row][guard.pos.col - 1] == '#') {
                return;
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

    // Do the walk...
    const looped = walkRoute(guard, max_rows, &hypothetical);
    if (looped) {
        obstaclePositions[block.row].set(block.col);
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

    fn getDirection(self: Guard) Directions {
        return switch (self.direction) {
            '^' => .north,
            '>' => .east,
            'v' => .south,
            '<' => .west,
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
        for (row[0..map[y].len], 0..) |_, x| {
            if (map[y][x] == '^' or map[y][x] == '>' or map[y][x] == 'v' or map[y][x] == '<') {
                continue;
            }
            const char: u8 = '.';
            canvas[y][x] = char;
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
