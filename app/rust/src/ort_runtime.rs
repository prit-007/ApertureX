//! ONNX Runtime Mobile backend spike (ADR 0010, #87).
//!
//! This module is compiled only with the optional `ai` feature. It creates an
//! ORT environment and runs models loaded from embedded bytes — no model
//! downloads or telemetry at runtime.

use std::sync::OnceLock;

use ort::environment::Environment;
use ort::session::Session;
use ort::value::Tensor;

static ENVIRONMENT: OnceLock<Result<Environment, String>> = OnceLock::new();

#[cfg(any(target_os = "android", target_os = "ios"))]
fn init_environment() -> Result<Environment, String> {
    let library = if cfg!(target_os = "android") {
        "libonnxruntime.so"
    } else {
        "libonnxruntime.dylib"
    };
    ort::init_from(library)
        .map_err(|e| format!("ONNX Runtime native library unavailable: {e}"))?
        .build()
        .map_err(|e| format!("ONNX Runtime init failed: {e}"))
}

#[cfg(not(any(target_os = "android", target_os = "ios")))]
fn init_environment() -> Result<Environment, String> {
    ort::init()
        .build()
        .map_err(|e| format!("ONNX Runtime init failed: {e}"))
}

fn environment() -> Result<&'static Environment, String> {
    ENVIRONMENT
        .get_or_init(init_environment)
        .as_ref()
        .map_err(Clone::clone)
}

pub(crate) fn create_session(model: &[u8]) -> Result<Session, String> {
    if model.is_empty() {
        return Err("ONNX model bytes are empty".into());
    }
    let environment = environment()?;
    #[allow(unused_mut)]
    let mut builder = Session::builder(environment)
        .map_err(|e| format!("ONNX Runtime session builder failed: {e}"))?;

    #[cfg(feature = "ai-nnapi")]
    {
        builder = builder
            .with_execution_providers([ort::ep::NNAPI::default().build()])
            .map_err(|e| format!("ONNX Runtime NNAPI setup failed: {e}"))?;
    }

    #[cfg(feature = "ai-coreml")]
    {
        builder = builder
            .with_execution_providers([ort::ep::CoreML::default().build()])
            .map_err(|e| format!("ONNX Runtime CoreML setup failed: {e}"))?;
    }

    builder
        .commit_from_memory(model)
        .map_err(|e| format!("ONNX Runtime model load failed: {e}"))
}

fn validate_input(input: &[f32], shape: &[usize]) -> Result<(), String> {
    let expected = shape
        .iter()
        .try_fold(1usize, |acc, &dim| acc.checked_mul(dim))
        .ok_or_else(|| "input shape overflows usize".to_string())?;
    if expected != input.len() {
        return Err(format!(
            "input has {} values, but shape {shape:?} needs {expected}",
            input.len()
        ));
    }
    Ok(())
}

/// Runs a single-input f32 model and returns every output tensor by name.
///
/// Multi-head models (e.g. YuNet's 12 detection heads) need all outputs, not
/// just the first one.
pub(crate) fn run_session_all(
    session: &mut Session,
    input: &[f32],
    shape: &[usize],
) -> Result<Vec<(String, Vec<f32>)>, String> {
    validate_input(input, shape)?;

    let tensor = Tensor::from_array((shape.to_vec(), input.to_vec()))
        .map_err(|e| format!("ONNX Runtime input tensor failed: {e}"))?;
    let outputs = session
        .run(ort::inputs![tensor])
        .map_err(|e| format!("ONNX Runtime inference failed: {e}"))?;

    let mut result = Vec::with_capacity(outputs.len());
    for (name, value) in outputs.iter() {
        let (_, data) = value
            .try_extract_tensor::<f32>()
            .map_err(|e| format!("ONNX Runtime output '{name}' failed: {e}"))?;
        result.push((name.to_string(), data.to_vec()));
    }
    if result.is_empty() {
        return Err("ONNX Runtime model returned no outputs".into());
    }
    Ok(result)
}

pub(crate) fn run_session(
    session: &mut Session,
    input: &[f32],
    shape: &[usize],
) -> Result<Vec<f32>, String> {
    let mut outputs = run_session_all(session, input, shape)?;
    Ok(outputs.remove(0).1)
}

/// Runs a single-input, single-output f32 ONNX model and returns the first
/// output tensor as a flat slice.
///
/// The engine deliberately keeps the model bytes in memory so an embedded
/// asset or a bundled model can be loaded without a temp file.
pub fn run_f32(model: &[u8], input: &[f32], shape: &[usize]) -> Result<Vec<f32>, String> {
    let mut session = create_session(model)?;
    run_session(&mut session, input, shape)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Tiny Add-one graph: input `x:[1,3]` + `one:[1,3]` -> `y:[1,3]`.
    const ADD_ONE_MODEL: &[u8] = &[
        0x08, 0x08, 0x12, 0x0f, 0x61, 0x70, 0x65, 0x72, 0x74, 0x75, 0x72, 0x65, 0x78, 0x2d, 0x73,
        0x70, 0x69, 0x6b, 0x65, 0x3a, 0x60, 0x0a, 0x10, 0x0a, 0x01, 0x78, 0x0a, 0x03, 0x6f, 0x6e,
        0x65, 0x12, 0x01, 0x79, 0x22, 0x03, 0x41, 0x64, 0x64, 0x12, 0x07, 0x61, 0x64, 0x64, 0x5f,
        0x6f, 0x6e, 0x65, 0x2a, 0x19, 0x08, 0x01, 0x08, 0x03, 0x10, 0x01, 0x22, 0x0c, 0x00, 0x00,
        0x80, 0x3f, 0x00, 0x00, 0x80, 0x3f, 0x00, 0x00, 0x80, 0x3f, 0x42, 0x03, 0x6f, 0x6e, 0x65,
        0x5a, 0x13, 0x0a, 0x01, 0x78, 0x12, 0x0e, 0x0a, 0x0c, 0x08, 0x01, 0x12, 0x08, 0x0a, 0x02,
        0x08, 0x01, 0x0a, 0x02, 0x08, 0x03, 0x62, 0x13, 0x0a, 0x01, 0x79, 0x12, 0x0e, 0x0a, 0x0c,
        0x08, 0x01, 0x12, 0x08, 0x0a, 0x02, 0x08, 0x01, 0x0a, 0x02, 0x08, 0x03, 0x42, 0x04, 0x0a,
        0x00, 0x10, 0x0d,
    ];

    #[test]
    fn runs_an_in_memory_model() {
        let out = run_f32(ADD_ONE_MODEL, &[1.0, 2.0, 3.0], &[1, 3]).expect("inference");
        assert_eq!(out, vec![2.0, 3.0, 4.0]);
    }

    #[test]
    fn rejects_an_empty_model() {
        let err = run_f32(&[], &[1.0], &[1]).unwrap_err();
        assert!(err.contains("empty"), "unexpected error: {err}");
    }

    #[test]
    fn rejects_a_shape_mismatch() {
        let err = run_f32(ADD_ONE_MODEL, &[1.0, 2.0], &[1, 3]).unwrap_err();
        assert!(err.contains("needs 3"), "unexpected error: {err}");
    }
}
