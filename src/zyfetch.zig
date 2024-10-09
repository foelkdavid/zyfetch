const std = @import("std");

// Gets GPU Vendor using lspci
fn getVGAInfo(allocator: std.mem.Allocator) ![]const u8 {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "sh", "-c", "lspci | grep VGA" },
    });

    if (result.term.Exited != 0) {
        return error.CommandFailed;
    }

    return allocator.dupe(u8, result.stdout);
}

// Trims Key=Value lines like those in /etc/os-release
pub fn trimName(allocator: std.mem.Allocator, line: []const u8) ![]const u8 {
    const start = std.mem.indexOfScalar(u8, line, '"') orelse return error.InvalidFormat;
    const end = std.mem.lastIndexOfScalar(u8, line, '"') orelse return error.InvalidFormat;

    if (start == end) return error.InvalidFormat;

    return try allocator.dupe(u8, line[start + 1 .. end]);
}

// Reads a file and returns the first line that starts with <string>
pub fn readLine(allocator: std.mem.Allocator, filepath: []const u8, starts_with: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (std.mem.startsWith(u8, line, starts_with)) {
            return try allocator.dupe(u8, line);
        }
    }
    return error.LineNotFound;
}

// Returns a defined part of a String.
// Parts are seperated by whitespaces
pub fn getLinePart(allocator: std.mem.Allocator, line: []const u8, part_index: usize) ![]const u8 {
    var iter = std.mem.split(u8, line, " ");
    var current_index: usize = 0;

    while (iter.next()) |part| {
        if (current_index == part_index) {
            return try allocator.dupe(u8, part);
        }
        current_index += 1;
    }

    return error.PartNotFound;
}

// Returns all content after a defined part of a String.
// Parts are seperated by whitespaces
pub fn getLinePartAndRest(allocator: std.mem.Allocator, line: []const u8, start_index: usize) ![]const u8 {
    var iter = std.mem.split(u8, line, " ");
    var current_index: usize = 0;
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    while (iter.next()) |part| {
        if (current_index >= start_index) {
            if (result.items.len > 0) {
                try result.append(' ');
            }
            try result.appendSlice(part);
        }
        current_index += 1;
    }

    if (result.items.len == 0) {
        return error.PartNotFound;
    }

    return result.toOwnedSlice();
}

// Fetches OS/Distro
pub fn getOS(allocator: std.mem.Allocator) ![]const u8 {
    const full_line = try readLine(allocator, "/etc/os-release", "PRETTY_NAME=");
    defer allocator.free(full_line);
    return try trimName(allocator, full_line);
}

// Fetches hostname
pub fn getHost(allocator: std.mem.Allocator) ![]const u8 {
    const hostname = try readLine(allocator, "/etc/hostname", "");
    return hostname;
}

// Fetches kernel version
pub fn getKernel(allocator: std.mem.Allocator) ![]const u8 {
    const kernel_full_line = try readLine(allocator, "/proc/version", "");
    defer allocator.free(kernel_full_line);
    return try getLinePart(allocator, kernel_full_line, 2);
}

// Fetches uptime <TODO: implement formatting>
pub fn getUptime(allocator: std.mem.Allocator) ![]const u8 {
    const uptime_full_line = try readLine(allocator, "/proc/uptime", "");
    defer allocator.free(uptime_full_line);
    return try getLinePart(allocator, uptime_full_line, 0);
}

// Fetches number of installed packages.
pub fn getPackages() []const u8 {
    return "Not Implemented";
}

// Fetches used shell
pub fn getShell(allocator: std.mem.Allocator) ![]const u8 {
    const shell = std.posix.getenv("SHELL") orelse return error.ShellNotFound;
    return try allocator.dupe(u8, shell);
}

// Fetches resolution
pub fn getResolution() []const u8 {
    return "Not Implemented";
}

// Fetches window manager (if applicable)
pub fn getWM() []const u8 {
    return "Not Implemented";
}

// Fetches terminal
pub fn getTerm() []const u8 {
    return "Not Implemented";
}

// Fetches CPU
pub fn getCPU(allocator: std.mem.Allocator) ![]const u8 {
    const cpu_full_line = try readLine(allocator, "/proc/cpuinfo", "model name");
    defer allocator.free(cpu_full_line);
    return try getLinePartAndRest(allocator, cpu_full_line, 2);
}

// Fetches GPU
pub fn getGPU(allocator: std.mem.Allocator) ![]const u8 {
    const vga_full_line = try getVGAInfo(allocator);
    std.debug.print("Line: {s}\n", .{vga_full_line});
    return "Not Implemented";
}

// Fetches memory stats
pub fn getMemory() []const u8 {
    return "Not Implemented";
}

// Fetches disk stats
pub fn getDisk() []const u8 {
    return "Not Implemented";
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const os_name = try getOS(allocator);
    defer allocator.free(os_name);

    const host_name = try getHost(allocator);
    defer allocator.free(host_name);

    const kernel = try getKernel(allocator);
    defer allocator.free(kernel);

    const uptime = try getUptime(allocator);
    defer allocator.free(uptime);

    const shell = try getShell(allocator);
    defer allocator.free(shell);

    const cpu = try getCPU(allocator);
    defer allocator.free(cpu);

    //const gpu = try getGPU(allocator);
    //defer allocator.free(gpu);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("⚡ zyfetch ⚡\n", .{});
    try stdout.print("-------------\n", .{});
    try stdout.print("OS: {s}\n", .{os_name});
    try stdout.print("Host: {s}\n", .{host_name});
    try stdout.print("Kernel: {s}\n", .{kernel});
    try stdout.print("Uptime: {s}\n", .{uptime});
    try stdout.print("Packages: {s}\n", .{getPackages()});
    try stdout.print("Shell: {s}\n", .{shell});
    //    try stdout.print("Resolution: {s}\n", .{getResolution()});
    //    try stdout.print("WM: {s}\n", .{getWM()});
    //    try stdout.print("Terminal: {s}\n", .{getTerm()});
    try stdout.print("CPU: {s}\n", .{cpu});
    //try stdout.print("GPU: {s}\n", .{gpu});
    try stdout.print("Memory: {s}\n", .{getMemory()});
    try stdout.print("Disk: {s}\n", .{getDisk()});
}
