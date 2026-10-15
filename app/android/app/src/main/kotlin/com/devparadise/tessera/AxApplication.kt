package com.devparadise.tessera

import android.app.Application

/**
 * Installs the process-wide uncaught-exception evidence (ADR 0012 §6).
 *
 * A main-thread throwable still ends the process — Android owns that — but the
 * handler records it (`native.log` + `crash_marker.json`) **before** chaining
 * to the previous handler, so the next launch can offer the log page with the
 * exact stack. Everything short of process death (channel faults, executor
 * tasks) is caught in [MainActivity] instead and surfaces as a popup + log
 * entry while the app keeps living.
 */
class AxApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        NativeLog.init(this)

        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                NativeLog.record("uncaught exception on ${thread.name}", throwable)
                NativeLog.writeCrashMarker(throwable)
            } catch (_: Throwable) {
                // Evidence gathering must never mask the original throwable.
            }
            previous?.uncaughtException(thread, throwable)
        }
    }
}
