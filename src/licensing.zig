const std = @import("std");
const Sha256 = std.crypto.hash.sha2.Sha256;

/// Generate license key from name, email, and salt.
/// Format: XXXX-XXXX-XXXX-XXXX (16 hex chars + 3 dashes = 19 chars)
/// Inputs are normalized before hashing: lowercased, non-alphanumeric stripped.
/// This means "John Doe" and "johndoe" produce the same key.
pub fn generateLicenseKey(
    name: []const u8,
    email: []const u8,
    salt: []const u8,
) []const u8 {
    var hasher = Sha256.init(.{});
    updateNormalized(&hasher, name);
    updateNormalized(&hasher, email);
    updateNormalized(&hasher, salt);

    var hash: [Sha256.digest_length]u8 = undefined;
    hasher.final(&hash);

    // First 8 bytes → 16 hex chars, grouped as 4-4-4-4 with dashes
    const hex = "0123456789ABCDEF";
    var pos: usize = 0;
    for (hash[0..8], 0..) |b, i| {
        key_buf[pos] = hex[b >> 4];
        key_buf[pos + 1] = hex[b & 0x0F];
        pos += 2;
        if ((i + 1) % 2 == 0 and i != 7) {
            key_buf[pos] = '-';
            pos += 1;
        }
    }

    return key_buf[0..pos];
}

// XXXX-XXXX-XXXX-XXXX = 19 chars
var key_buf: [19]u8 = undefined;

/// Verify a license key against name/email/salt.
/// Both keys are normalized before comparison (strip non-alphanumeric, lowercase)
/// so dashes, spaces, and case differences don't matter.
pub fn verifyLicense(
    name: []const u8,
    email: []const u8,
    salt: []const u8,
    entered_key: []const u8,
) bool {
    const generated = generateLicenseKey(name, email, salt);

    var gen_norm: [16]u8 = undefined;
    const gen_clean = normalize(&gen_norm, generated);

    var entered_norm: [16]u8 = undefined;
    const entered_clean = normalize(&entered_norm, entered_key);

    return std.mem.eql(u8, gen_clean, entered_clean);
}

/// Lowercase and strip everything except alphanumeric.
fn normalize(out: []u8, input: []const u8) []const u8 {
    var i: usize = 0;
    for (input) |c| {
        if (!std.ascii.isAlphanumeric(c)) continue;
        if (i >= out.len) break;
        out[i] = std.ascii.toLower(c);
        i += 1;
    }
    return out[0..i];
}

/// Feed normalized (lowercase, alphanumeric-only) chars into the hasher.
fn updateNormalized(hasher: *Sha256, input: []const u8) void {
    for (input) |c| {
        if (!std.ascii.isAlphanumeric(c)) continue;
        hasher.update(&[1]u8{std.ascii.toLower(c)});
    }
}
