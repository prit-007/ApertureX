package com.devparadise.aperturex

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Platform-side half of the observability system (ADR 0012 §4/§6).
 *
 * Kotlin keeps its **own** single-writer JSONL file (`native.log`) and crash
 * marker (`crash_marker.json`) under `filesDir/aperturex/` — the same record
 * shape `LogEntry` decodes on the Dart side, delivered over the
 * `aperturex/native_log` method channel. Every operation swallows its own
 * failures: a logging problem must never become a second crash.
 */
object NativeLog {
    private const val TAG = "ApertureX"
    private const val MAX_BYTES = 256L * 1024
    private const val KEEP_LINES = 1000

    @Volatile
    private var dir: File? = null

    private val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)

    /** Called from `AxApplication.onCreate` (and defensively from the engine). */
    fun init(context: Context) {
        if (dir != null) return
        val base = File(context.filesDir, "aperturex")
        base.mkdirs()
        dir = base
        rotateIfNeeded(File(base, "native.log"))
    }

    val logFile: File? get() = dir?.let { File(it, "native.log") }
    val markerFile: File? get() = dir?.let { File(it, "crash_marker.json") }

    /** Appends one record; never throws. */
    fun record(message: String, throwable: Throwable? = null, level: String = "error") {
        val file = logFile ?: return
        try {
            val json = JSONObject()
                .put("t", iso.format(Date()))
                .put("d", "native")
                .put("l", level)
                .put("m", message)
            if (throwable != null) {
                json.put("e", throwable.toString())
                json.put("s", Log.getStackTraceString(throwable))
            }
            file.appendText(json.toString() + "\n")
        } catch (_: Throwable) {
            // best effort
        }
    }

    /**
     * Persists the uncaught exception as the next-launch crash record, then
     * chains out so Android kills the process — we cannot keep a dead main
     * thread alive, but the user WILL be offered the log page next launch
     * (ADR 0012 §3).
     */
    fun writeCrashMarker(throwable: Throwable) {
        val file = markerFile ?: return
        try {
            JSONObject()
                .put("t", iso.format(Date()))
                .put("where", "native")
                .put("error", throwable.toString())
                .put("stack", Log.getStackTraceString(throwable))
                .let { file.writeText(it.toString()) }
        } catch (_: Throwable) {
            // best effort
        }
    }

    /** Parses up to [limit] newest records (oldest first) for the channel. */
    fun readEntries(limit: Int): List<Map<String, Any?>> {
        val file = logFile ?: return emptyList()
        return try {
            if (!file.exists()) return emptyList()
            val lines = file.readLines()
            val start = if (lines.size > limit) lines.size - limit else 0
            buildList {
                for (i in start until lines.size) {
                    val parsed = parseLine(lines[i]) ?: continue
                    add(parsed)
                }
            }
        } catch (_: Throwable) {
            emptyList()
        }
    }

    fun readCrashMarker(): Map<String, Any?>? {
        val file = markerFile ?: return null
        return try {
            if (!file.exists()) return null
            val json = JSONObject(file.readText())
            json.keys().asSequence().associateWith { json.opt(it) }
        } catch (_: Throwable) {
            null
        }
    }

    fun clearCrashMarker() {
        try {
            markerFile?.let { if (it.exists()) it.delete() }
        } catch (_: Throwable) {
            // best effort
        }
    }

    /**
     * Reconstructs a crash marker for a process that died without running the
     * JVM uncaught-exception handler — native SIGSEGV/SIGABRT, ANR, or LMK.
     *
     * These exits never reach Dart's zone or Kotlin's exception handler, so
     * `getHistoricalProcessExitReasons` is the only source of truth. Runs once
     * per process start; records the newest unread exit and writes a marker so
     * the next launch can deep-link into the log page (ADR 0012 §3/§6).
     */
    fun capturePreviousExit(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val base = dir ?: return
        try {
            val manager = context.getSystemService(ActivityManager::class.java) ?: return
            val newest = manager
                .getHistoricalProcessExitReasons(context.packageName, 0, 8)
                .maxByOrNull { it.timestamp } ?: return
            if (newest.timestamp <= readLastExitTimestamp(base)) return
            writeLastExitTimestamp(base, newest.timestamp)

            val fatal = newest.reason in FATAL_REASONS
            if (!fatal) return
            // A JVM-handled crash already wrote a richer marker; never replace it.
            if (markerFile?.exists() == true) return

            val description = newest.description?.takeIf { it.isNotBlank() }
                ?: exitReasonName(newest.reason)
            val trace = buildString {
                appendLine("reason=${exitReasonName(newest.reason)} (${newest.reason})")
                appendLine("status=${newest.status}")
                appendLine("timestamp=${iso.format(Date(newest.timestamp))}")
                if (newest.processName.isNotBlank()) appendLine("process=${newest.processName}")
                readTrace(newest)?.takeIf { it.isNotBlank() }?.let {
                    appendLine("trace:")
                    appendLine(it)
                }
            }.trim()

            val error = "Process exit: $description"
            record("$error (reason=${exitReasonName(newest.reason)})")
            writeCrashMarkerRecord(error, trace)
        } catch (_: Throwable) {
            // Evidence gathering must never block startup.
        }
    }

    private fun writeCrashMarkerRecord(error: String, stack: String) {
        val file = markerFile ?: return
        try {
            JSONObject()
                .put("t", iso.format(Date()))
                .put("where", "native")
                .put("error", error)
                .put("stack", stack)
                .let { file.writeText(it.toString()) }
        } catch (_: Throwable) {
            // best effort
        }
    }

    private fun readLastExitTimestamp(base: File): Long = try {
        File(base, "last_exit_ms").takeIf { it.exists() }?.readText()?.toLongOrNull() ?: 0L
    } catch (_: Throwable) {
        0L
    }

    private fun writeLastExitTimestamp(base: File, timestamp: Long) {
        try {
            File(base, "last_exit_ms").writeText(timestamp.toString())
        } catch (_: Throwable) {
            // best effort
        }
    }

    private fun readTrace(reason: ApplicationExitInfo): String? = try {
        reason.traceInputStream?.use { stream ->
            val buffer = ByteArray(64 * 1024)
            var total = 0
            while (total < buffer.size) {
                val read = stream.read(buffer, total, buffer.size - total)
                if (read <= 0) break
                total += read
            }
            String(buffer, 0, total, Charsets.UTF_8)
        }
    } catch (_: Throwable) {
        null
    }

    private fun exitReasonName(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_SIGNALED -> "signaled"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "low memory"
        ApplicationExitInfo.REASON_CRASH -> "crash"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "native crash"
        ApplicationExitInfo.REASON_ANR -> "ANR"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "initialization failure"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "excessive resource usage"
        else -> "exit"
    }

    private val FATAL_REASONS = setOf(
        ApplicationExitInfo.REASON_SIGNALED,
        ApplicationExitInfo.REASON_CRASH,
        ApplicationExitInfo.REASON_CRASH_NATIVE,
        ApplicationExitInfo.REASON_ANR,
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE,
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE,
    )

    private fun parseLine(line: String): Map<String, Any?>? = try {
        if (line.isBlank()) null else {
            val json = JSONObject(line)
            if (!json.has("t") || !json.has("m")) null
            else json.keys().asSequence().associateWith { json.opt(it) }
        }
    } catch (_: Throwable) {
        null
    }

    /** Trim-on-boot: keep the native log bounded like the Dart one. */
    private fun rotateIfNeeded(file: File) {
        try {
            if (!file.exists() || file.length() <= MAX_BYTES) return
            val lines = file.readLines()
            if (lines.size <= KEEP_LINES) return
            file.writeText(lines.takeLast(KEEP_LINES).joinToString("\n") + "\n")
        } catch (_: Throwable) {
            // best effort
        }
    }
}
