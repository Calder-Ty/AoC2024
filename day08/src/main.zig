//! https://adventofcode.com/2024/day/8
//!
//! 268 is too low
const std = @import("std");
const math = std.math;
const fs = std.fs;
const fmt = std.fmt;
const sort = std.sort;
const Allocator = std.mem.Allocator;

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const global_alloc = arena.allocator();
const max_read = 21 * 1024;
const prod_size = 50;
// This could be fun to play with Vectors, but lets solve first!
const StationList = std.ArrayList(Coord);
const FrequencyMap = std.AutoHashMap(u8, StationList);
const AntinodeRow = std.bit_set.StaticBitSet(prod_size);
const AntinodeChart = [prod_size]AntinodeRow;

const Coord = struct { x: i8, y: i8 };
const Bounds = struct { x_max: u8, y_max: u8 };

var bounds: Bounds = .{ .x_max = 0, .y_max = 0 };

pub fn main() !void {
    // Set up Basic structures
    var freq_map = FrequencyMap.init(global_alloc);
    var antinode_chart: AntinodeChart = [1]AntinodeRow{AntinodeRow.initEmpty()} ** prod_size;

    const data = try loadData(global_alloc, "data/prod.txt");
    try parseDiagram(data, &freq_map);
    var freq_mapit = freq_map.iterator();
    while (freq_mapit.next()) |item| {
        const v = item.value_ptr.*;
        findAntinodes(v.items, &antinode_chart);
    }

    var total: usize = 0;
    for (antinode_chart) |row| {
        total += row.count();
    }

    std.debug.print("Found {d}\n", .{total});
}

fn parseDiagram(data: []u8, freqs: *FrequencyMap) !void {
    var lines = std.mem.tokenizeScalar(u8, data, '\n');
    var y:i8 = 0;
    var x:i8 = 0;
    while (lines.next()) |line| {
        x = 0;
        for (line) |value| {
            if (value != '.') {
                // Store the coordinate
                var gop = try freqs.getOrPut(value);
                if (gop.found_existing) {
                    try gop.value_ptr.append(.{ .x = x, .y = y });
                } else {
                    const li = try global_alloc.create(StationList);
                    li.* = StationList.init(global_alloc);
                    try li.*.append(.{ .x = x, .y = y });
                    gop.value_ptr.* = li.*;
                }
            }
            x += 1;
        }
        y += 1;
    }
    bounds.x_max = @as(u8, @intCast(x));
    bounds.y_max = @as(u8, @intCast(y));
}

fn findAntinodes(stations: []Coord, antinodes: *AntinodeChart) void {
    var i: usize = 0;
    while (i < stations.len) : (i += 1) {
        const first = stations[i];
        for (stations[i + 1 ..]) |next| {
            computeAntinodes(first, next, antinodes);
        }
    }
}

fn computeAntinodes(a: Coord, b: Coord, antinodes: *AntinodeChart) void {
    const rise = b.y - a.y;
    const run = b.x - a.x;
    // Do A's Antinode first: Since Rise/Run are calculated going _from_ a to
    // _b_ (i.e values point towards b, doing the opposit will lead us away.
    const anti_a: Coord = .{ .x = a.x - run, .y = a.y - rise };
    // Similarly for b, if we keep going, we will go further from a
    const anti_b: Coord = .{ .x = b.x + run, .y = b.y + rise };


    if (inBounds(anti_a)) antinodes[@intCast(anti_a.y)].set(@intCast(anti_a.x));
    if (inBounds(anti_b)) antinodes[@intCast(anti_b.y)].set(@intCast(anti_b.x));
}

fn inBounds(coord: Coord) bool {
    return coord.x >= 0 and coord.y >= 0 and coord.x < bounds.x_max and coord.y < bounds.y_max;
}

/// Load the Data from path
fn loadData(allocator: Allocator, path: []const u8) ![]u8 {
    const fd = try fs.cwd().openFile(path, .{});
    return try fd.readToEndAlloc(allocator, max_read);
}
