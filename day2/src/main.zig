const std = @import("std");
const fmt = std.fmt;
const fs = std.fs;
const Allocator = std.mem.Allocator;

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const global_alloc = arena.allocator();
const max_read = 20 * 1024;

pub fn main() !void {

    const data = try loadData(global_alloc, "data/prod.txt");
    var iter = std.mem.tokenizeScalar(u8, data, '\n');
    var safe: usize = 0;
    var safe_with_dampner: usize = 0;
    while (iter.next()) |d| {
        const report = try parseReport(global_alloc, d);
        if (try analyzeReport(report)){
            safe +=1;
        } else if (try applyProblemDampner(report)){
            safe_with_dampner += 1;
        }
    }
    std.debug.print("# of Safe Reports is: {d}\n", .{safe}); 
    std.debug.print("# of Safe Reports (with dampner) is: {d}\n", .{safe + safe_with_dampner}); 
}

/// Load the Data from path
fn loadData(allocator: Allocator, path: []const u8) ![]u8 {
    const fd = try fs.cwd().openFile(path, .{});
    return try fd.readToEndAlloc(allocator, max_read);
}

fn applyProblemDampner(data:[] const isize) !bool {
    var i: usize = 0;
    var subArray = try global_alloc.alloc(isize, data.len - 1);
    while (i < data.len) : (i += 1) {
        if (i == 0) {
            @memcpy(subArray, data[1..]);

        } else if (i == data.len - 1) {
            @memcpy(subArray, data[0..data.len - 1]);
        } else {
            @memcpy(subArray[0..i], data[0..i]);
            const after = subArray[i..];
            const before = data[i + 1..];
            @memcpy(after,before); 
        }
        if (try analyzeReport(subArray)) {
            return true;
        }

    }
    return false;
}

fn analyzeReport(report: []const isize) !bool {

    var window_iter = std.mem.window(isize, report, 2, 1);
    var increasing:?bool = null;
    while (window_iter.next()) | win | {
        const delta = win[0] - win[1];
        if(@abs(delta) < 1 or @abs(delta) > 3) {
            return false;
        }
        if (increasing == null) {
            increasing = delta > 0;
        } else if (increasing.? and delta < 0) {
            return false;
        } else if (!increasing.? and delta > 0) {
            return false;
        }
    }
    return true;
}

fn parseReport(allocator: Allocator, data: [] const u8) ![]isize {
    var list = std.ArrayList(isize).init(allocator);
    var iter = std.mem.tokenizeScalar(u8, data, ' ');
    while (iter.next()) |val|{
        try list.append(try fmt.parseInt(isize, val, 10));
    }
    return list.toOwnedSlice();
}
