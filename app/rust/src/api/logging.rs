//! Rust-side panic evidence for the error boundary (ADR 0012 §7).
//!
//! `init_panic_hook(dir)` installs (once) a hook that appends each panic to
//! `<dir>/rust_panic.log` as **LogEntry-compatible JSONL** before unwinding —
//! so the frontend hydrates it straight into the in-app log page, and FRB's
//! unwind capture additionally delivers the panic as a Dart exception (popup +
//! crash marker). The hook exists for panics that escape the bridge (worker
//! threads, callbacks) where no Dart boundary would otherwise see them.

use std::fs::OpenOptions;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};

/// The single writer's target; first `init_panic_hook` call wins for the
/// process lifetime (re-inits are no-ops — matches the "one writer" rule).
static TARGET: OnceLock<Mutex<PathBuf>> = OnceLock::new();

/// Installs the panic hook once, pointing it at `<dir>/rust_panic.log`.
/// Any failure to install or write is swallowed: evidence gathering must
/// never become a second panic.
pub fn init_panic_hook(dir: String) {
    let path = PathBuf::from(dir).join("rust_panic.log");
    if TARGET.set(Mutex::new(path)).is_err() {
        return; // already installed by an earlier call
    }
    let previous = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        record(info);
        previous(info);
    }));
}

fn record(info: &std::panic::PanicHookInfo<'_>) {
    let Some(target) = TARGET.get() else { return };
    let Ok(target) = target.lock() else { return };
    append_panic_line(&target, info);
}

fn append_panic_line(path: &Path, info: &std::panic::PanicHookInfo<'_>) {
    let payload = truncate(&extract_payload(info), MAX_FIELD_CHARS);
    let location = info
        .location()
        .map(|l| format!("{}:{}:{}", l.file(), l.line(), l.column()))
        .unwrap_or_else(|| "unknown location".to_string());
    // Same JSONL shape `LogEntry` decodes on the Dart side, so the frontend
    // can hydrate rust_panic.log straight into the log page (ADR 0012 §4).
    let t = now_rfc3339();
    let m = json_escape(&format!("Rust panic: {payload}"));
    let e = json_escape(&payload);
    let s = json_escape(&truncate(
        &format!("panicked at {location}"),
        MAX_FIELD_CHARS,
    ));
    if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(path) {
        let _ = writeln!(
            file,
            r#"{{"t":"{t}","d":"crash","l":"error","m":"{m}","e":"{e}","s":"{s}"}}"#
        );
    }
}

fn extract_payload(info: &std::panic::PanicHookInfo<'_>) -> String {
    info.payload()
        .downcast_ref::<&str>()
        .map(|s| (*s).to_string())
        .or_else(|| info.payload().downcast_ref::<String>().cloned())
        .unwrap_or_else(|| "non-string panic payload".to_string())
}

const MAX_FIELD_CHARS: usize = 4 * 1024;

fn truncate(s: &str, max: usize) -> String {
    if s.len() <= max {
        return s.to_string();
    }
    let mut end = max;
    while !s.is_char_boundary(end) {
        end -= 1;
    }
    format!("{}...", &s[..end])
}

fn json_escape(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 8);
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out
}

/// `YYYY-MM-DDTHH:MM:SS.mmmZ` from wall-clock — RFC3339, `DateTime.parse`-able
/// on the Dart side, without adding a time crate (ADR 0012 keeps deps flat).
fn now_rfc3339() -> String {
    let since_epoch = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default();
    format_utc(since_epoch.as_millis() as u64)
}

/// Civil date/time from unix milliseconds (Howard Hinnant's `civil_from_days`),
/// UTC only — the log viewer renders local time from the parsed instant.
fn format_utc(unix_ms: u64) -> String {
    let days = (unix_ms / 86_400_000) as i64;
    let rem = unix_ms % 86_400_000;
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = (z - era * 146_097) as u64; // [0, 146096]
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365; // [0, 399]
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100); // [0, 365]
    let mp = (5 * doy + 2) / 153; // [0, 11]
    let day = doy - (153 * mp + 2) / 5 + 1; // [1, 31]
    let month = if mp < 10 { mp + 3 } else { mp - 9 }; // [1, 12]
    let year = if month <= 2 { y + 1 } else { y };
    let hour = rem / 3_600_000;
    let minute = rem % 3_600_000 / 60_000;
    let second = rem % 60_000 / 1000;
    let ms = rem % 1000;
    format!("{year:04}-{month:02}-{day:02}T{hour:02}:{minute:02}:{second:02}.{ms:03}Z")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn format_utc_is_rfc3339_parseable() {
        assert_eq!(format_utc(0), "1970-01-01T00:00:00.000Z");
        assert_eq!(format_utc(86_400_000), "1970-01-02T00:00:00.000Z");
        assert_eq!(format_utc(1_700_000_000_000), "2023-11-14T22:13:20.000Z");
    }

    #[test]
    fn json_escape_neutralises_control_and_quote_chars() {
        assert_eq!(json_escape(r#"a"b\c"#), r#"a\"b\\c"#);
        assert_eq!(json_escape("line1\nline2\tend"), r#"line1\nline2\tend"#);
        assert_eq!(json_escape("ok"), "ok");
    }

    /// One process-wide test: `init_panic_hook` is global state, so splitting
    /// it into several `#[test]`s would race the `OnceLock` and each other.
    #[test]
    fn panic_hook_writes_frontend_decodable_logentry_jsonl() {
        let dir = std::env::temp_dir().join(format!(
            "aperturex_rust_panic_{}_{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&dir).unwrap();

        init_panic_hook(dir.to_string_lossy().into_owned());
        // Re-init must be a no-op (first writer wins).
        init_panic_hook("/nonexistent/aperturex_second_init".into());

        let first = std::panic::catch_unwind(|| panic!("boom from the engine"));
        assert!(first.is_err(), "panic must still unwind normally");

        // A pathologically long payload must stay bounded (schema ~8 KB cap).
        let huge = "x".repeat(9000);
        let second = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| panic!("{huge}")));
        assert!(second.is_err());

        let log = dir.join("rust_panic.log");
        let text = fs::read_to_string(&log).expect("rust_panic.log written");
        let mut lines = text.lines();

        // Line 1: decodable by Dart's LogEntry (keys t/d/l/m/e/s, RFC3339 t).
        let line = lines.next().expect("first line");
        assert!(line.starts_with(r#"{"t":""#), "t first: {line}");
        assert!(
            line.contains(r#"","d":"crash","l":"error","m":"Rust panic: boom from the engine""#),
            "fields: {line}"
        );
        assert!(line.contains(r#""e":"boom from the engine""#), "e: {line}");
        assert!(
            line.contains(r#""s":"panicked at src/api/logging.rs:"#),
            "s: {line}"
        );

        // Line 2: payload capped per field (m + e), still one JSONL line.
        let long_line = lines.next().expect("second line");
        assert!(long_line.len() < 9_000, "bounded: {}", long_line.len());
        assert!(!long_line.contains('\n'), "JSONL stays single-line");
        assert!(lines.next().is_none(), "exactly two lines");

        // Second init never wrote anywhere else.
        assert!(!Path::new("/nonexistent/aperturex_second_init").exists());

        let _ = fs::remove_dir_all(&dir);
    }
}
