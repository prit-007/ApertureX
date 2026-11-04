#import "GeneratedPluginRegistrant.h"

#include <stdbool.h>
#include <stdint.h>

/// Binds a CVPixelBuffer base address to a Rust preview handle (zero-copy
/// write path). Implemented in Rust (`preview.rs`, `#[cfg(target_os = "ios")]`).
bool aperturex_bind_window(uint64_t handle, int64_t window_ptr);
