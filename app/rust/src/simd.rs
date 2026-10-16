//! SIMD-vectorized primitives for spatial filtering kernels (Issue #56).
//!
//! Provides hardware-accelerated vector paths (NEON on ARM64, SSE on x86_64)
//! with a portable chunked scalar fallback, guaranteeing identical numerical results.

#[cfg(target_arch = "x86_64")]
use std::arch::x86_64::*;

#[cfg(target_arch = "aarch64")]
use std::arch::aarch64::*;

/// Computes `out[i] = a[i] * b[i]` across all elements.
pub fn vector_mul(a: &[f32], b: &[f32], out: &mut [f32]) {
    assert_eq!(a.len(), b.len());
    assert_eq!(a.len(), out.len());
    let len = a.len();
    let chunks = len / 4;
    let remainder = chunks * 4;

    #[cfg(target_arch = "x86_64")]
    {
        for i in 0..chunks {
            let offset = i * 4;
            unsafe {
                let va = _mm_loadu_ps(a.as_ptr().add(offset));
                let vb = _mm_loadu_ps(b.as_ptr().add(offset));
                let vres = _mm_mul_ps(va, vb);
                _mm_storeu_ps(out.as_mut_ptr().add(offset), vres);
            }
        }
    }

    #[cfg(target_arch = "aarch64")]
    {
        for i in 0..chunks {
            let offset = i * 4;
            unsafe {
                let va = vld1q_f32(a.as_ptr().add(offset));
                let vb = vld1q_f32(b.as_ptr().add(offset));
                let vres = vmulq_f32(va, vb);
                vst1q_f32(out.as_mut_ptr().add(offset), vres);
            }
        }
    }

    #[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
    {
        for i in 0..chunks {
            let offset = i * 4;
            out[offset] = a[offset] * b[offset];
            out[offset + 1] = a[offset + 1] * b[offset + 1];
            out[offset + 2] = a[offset + 2] * b[offset + 2];
            out[offset + 3] = a[offset + 3] * b[offset + 3];
        }
    }

    for i in remainder..len {
        out[i] = a[i] * b[i];
    }
}

/// Computes `out[i] = a[i] * a[i]` across all elements.
pub fn vector_sqr(a: &[f32], out: &mut [f32]) {
    vector_mul(a, a, out);
}

/// Computes `out[i] = a[i] * b[i] + c[i]` across all elements (linear combination / MAC).
pub fn vector_linear_combination(a: &[f32], b: &[f32], c: &[f32], out: &mut [f32]) {
    assert_eq!(a.len(), b.len());
    assert_eq!(a.len(), c.len());
    assert_eq!(a.len(), out.len());
    let len = a.len();
    let chunks = len / 4;
    let remainder = chunks * 4;

    #[cfg(target_arch = "x86_64")]
    {
        for i in 0..chunks {
            let offset = i * 4;
            unsafe {
                let va = _mm_loadu_ps(a.as_ptr().add(offset));
                let vb = _mm_loadu_ps(b.as_ptr().add(offset));
                let vc = _mm_loadu_ps(c.as_ptr().add(offset));
                let vmul = _mm_mul_ps(va, vb);
                let vres = _mm_add_ps(vmul, vc);
                _mm_storeu_ps(out.as_mut_ptr().add(offset), vres);
            }
        }
    }

    #[cfg(target_arch = "aarch64")]
    {
        for i in 0..chunks {
            let offset = i * 4;
            unsafe {
                let va = vld1q_f32(a.as_ptr().add(offset));
                let vb = vld1q_f32(b.as_ptr().add(offset));
                let vc = vld1q_f32(c.as_ptr().add(offset));
                let vres = vfmaq_f32(vc, va, vb);
                vst1q_f32(out.as_mut_ptr().add(offset), vres);
            }
        }
    }

    #[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
    {
        for i in 0..chunks {
            let offset = i * 4;
            out[offset] = a[offset] * b[offset] + c[offset];
            out[offset + 1] = a[offset + 1] * b[offset + 1] + c[offset + 1];
            out[offset + 2] = a[offset + 2] * b[offset + 2] + c[offset + 2];
            out[offset + 3] = a[offset + 3] * b[offset + 3] + c[offset + 3];
        }
    }

    for i in remainder..len {
        out[i] = a[i] * b[i] + c[i];
    }
}

/// Vectorized guided filter coefficient step:
/// `var_i = (mean_ii - mean_i * mean_i).max(0.0)`
/// `cov_ip = mean_ip - mean_i * mean_p`
/// `a = cov_ip / (var_i + eps)`
/// `b = mean_p - a * mean_i`
pub fn vector_guided_coeffs(
    mean_i: &[f32],
    mean_p: &[f32],
    mean_ii: &[f32],
    mean_ip: &[f32],
    eps: f32,
    a_out: &mut [f32],
    b_out: &mut [f32],
) {
    let len = mean_i.len();
    assert_eq!(len, mean_p.len());
    assert_eq!(len, mean_ii.len());
    assert_eq!(len, mean_ip.len());
    assert_eq!(len, a_out.len());
    assert_eq!(len, b_out.len());

    let chunks = len / 4;
    let remainder = chunks * 4;

    #[cfg(target_arch = "x86_64")]
    {
        unsafe {
            let veps = _mm_set1_ps(eps);
            let vzero = _mm_setzero_ps();
            for i in 0..chunks {
                let offset = i * 4;
                let mi = _mm_loadu_ps(mean_i.as_ptr().add(offset));
                let mp = _mm_loadu_ps(mean_p.as_ptr().add(offset));
                let mii = _mm_loadu_ps(mean_ii.as_ptr().add(offset));
                let mip = _mm_loadu_ps(mean_ip.as_ptr().add(offset));

                // var_i = max(0.0, mii - mi * mi)
                let mi_sq = _mm_mul_ps(mi, mi);
                let diff_var = _mm_sub_ps(mii, mi_sq);
                let var_i = _mm_max_ps(vzero, diff_var);

                // cov_ip = mip - mi * mp
                let mi_mp = _mm_mul_ps(mi, mp);
                let cov_ip = _mm_sub_ps(mip, mi_mp);

                // a = cov_ip / (var_i + eps)
                let denom = _mm_add_ps(var_i, veps);
                let a = _mm_div_ps(cov_ip, denom);

                // b = mp - a * mi
                let a_mi = _mm_mul_ps(a, mi);
                let b = _mm_sub_ps(mp, a_mi);

                _mm_storeu_ps(a_out.as_mut_ptr().add(offset), a);
                _mm_storeu_ps(b_out.as_mut_ptr().add(offset), b);
            }
        }
    }

    #[cfg(target_arch = "aarch64")]
    {
        unsafe {
            let veps = vdupq_n_f32(eps);
            let vzero = vdupq_n_f32(0.0);
            for i in 0..chunks {
                let offset = i * 4;
                let mi = vld1q_f32(mean_i.as_ptr().add(offset));
                let mp = vld1q_f32(mean_p.as_ptr().add(offset));
                let mii = vld1q_f32(mean_ii.as_ptr().add(offset));
                let mip = vld1q_f32(mean_ip.as_ptr().add(offset));

                let mi_sq = vmulq_f32(mi, mi);
                let diff_var = vsubq_f32(mii, mi_sq);
                let var_i = vmaxq_f32(vzero, diff_var);

                let mi_mp = vmulq_f32(mi, mp);
                let cov_ip = vsubq_f32(mip, mi_mp);

                let denom = vaddq_f32(var_i, veps);
                let a = vdivq_f32(cov_ip, denom);

                let a_mi = vmulq_f32(a, mi);
                let b = vsubq_f32(mp, a_mi);

                vst1q_f32(a_out.as_mut_ptr().add(offset), a);
                vst1q_f32(b_out.as_mut_ptr().add(offset), b);
            }
        }
    }

    #[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
    {
        for i in 0..chunks {
            let offset = i * 4;
            for j in 0..4 {
                let idx = offset + j;
                let var_i = (mean_ii[idx] - mean_i[idx] * mean_i[idx]).max(0.0);
                let cov_ip = mean_ip[idx] - mean_i[idx] * mean_p[idx];
                let a = cov_ip / (var_i + eps);
                let b = mean_p[idx] - a * mean_i[idx];
                a_out[idx] = a;
                b_out[idx] = b;
            }
        }
    }

    for i in remainder..len {
        let var_i = (mean_ii[i] - mean_i[i] * mean_i[i]).max(0.0);
        let cov_ip = mean_ip[i] - mean_i[i] * mean_p[i];
        let a = cov_ip / (var_i + eps);
        let b = mean_p[i] - a * mean_i[i];
        a_out[i] = a;
        b_out[i] = b;
    }
}

/// Vectorized variance step:
/// `var_out[i] = (mean_ii[i] - mean_i[i] * mean_i[i]).max(0.0)`
pub fn vector_variance(mean_ii: &[f32], mean_i: &[f32], var_out: &mut [f32]) {
    let len = mean_ii.len();
    assert_eq!(len, mean_i.len());
    assert_eq!(len, var_out.len());
    let chunks = len / 4;
    let remainder = chunks * 4;

    #[cfg(target_arch = "x86_64")]
    {
        unsafe {
            let vzero = _mm_setzero_ps();
            for i in 0..chunks {
                let offset = i * 4;
                let mi = _mm_loadu_ps(mean_i.as_ptr().add(offset));
                let mii = _mm_loadu_ps(mean_ii.as_ptr().add(offset));
                let mi_sq = _mm_mul_ps(mi, mi);
                let diff_var = _mm_sub_ps(mii, mi_sq);
                let var_i = _mm_max_ps(vzero, diff_var);
                _mm_storeu_ps(var_out.as_mut_ptr().add(offset), var_i);
            }
        }
    }

    #[cfg(target_arch = "aarch64")]
    {
        unsafe {
            let vzero = vdupq_n_f32(0.0);
            for i in 0..chunks {
                let offset = i * 4;
                let mi = vld1q_f32(mean_i.as_ptr().add(offset));
                let mii = vld1q_f32(mean_ii.as_ptr().add(offset));
                let mi_sq = vmulq_f32(mi, mi);
                let diff_var = vsubq_f32(mii, mi_sq);
                let var_i = vmaxq_f32(vzero, diff_var);
                vst1q_f32(var_out.as_mut_ptr().add(offset), var_i);
            }
        }
    }

    #[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
    {
        for i in 0..chunks {
            let offset = i * 4;
            for j in 0..4 {
                let idx = offset + j;
                var_out[idx] = (mean_ii[idx] - mean_i[idx] * mean_i[idx]).max(0.0);
            }
        }
    }

    for i in remainder..len {
        var_out[i] = (mean_ii[i] - mean_i[i] * mean_i[i]).max(0.0);
    }
}

/// Vectorized guided filter coefficient step with precomputed variance:
/// `cov_ip = mean_ip - mean_i * mean_p`
/// `a = cov_ip / (var_i + eps)`
/// `b = mean_p - a * mean_i`
pub fn vector_guided_coeffs_with_var(
    mean_i: &[f32],
    mean_p: &[f32],
    var_i: &[f32],
    mean_ip: &[f32],
    eps: f32,
    a_out: &mut [f32],
    b_out: &mut [f32],
) {
    let len = mean_i.len();
    assert_eq!(len, mean_p.len());
    assert_eq!(len, var_i.len());
    assert_eq!(len, mean_ip.len());
    assert_eq!(len, a_out.len());
    assert_eq!(len, b_out.len());

    let chunks = len / 4;
    let remainder = chunks * 4;

    #[cfg(target_arch = "x86_64")]
    {
        unsafe {
            let veps = _mm_set1_ps(eps);
            for i in 0..chunks {
                let offset = i * 4;
                let mi = _mm_loadu_ps(mean_i.as_ptr().add(offset));
                let mp = _mm_loadu_ps(mean_p.as_ptr().add(offset));
                let v_var = _mm_loadu_ps(var_i.as_ptr().add(offset));
                let mip = _mm_loadu_ps(mean_ip.as_ptr().add(offset));

                let mi_mp = _mm_mul_ps(mi, mp);
                let cov_ip = _mm_sub_ps(mip, mi_mp);

                let denom = _mm_add_ps(v_var, veps);
                let a = _mm_div_ps(cov_ip, denom);

                let a_mi = _mm_mul_ps(a, mi);
                let b = _mm_sub_ps(mp, a_mi);

                _mm_storeu_ps(a_out.as_mut_ptr().add(offset), a);
                _mm_storeu_ps(b_out.as_mut_ptr().add(offset), b);
            }
        }
    }

    #[cfg(target_arch = "aarch64")]
    {
        unsafe {
            let veps = vdupq_n_f32(eps);
            for i in 0..chunks {
                let offset = i * 4;
                let mi = vld1q_f32(mean_i.as_ptr().add(offset));
                let mp = vld1q_f32(mean_p.as_ptr().add(offset));
                let v_var = vld1q_f32(var_i.as_ptr().add(offset));
                let mip = vld1q_f32(mean_ip.as_ptr().add(offset));

                let mi_mp = vmulq_f32(mi, mp);
                let cov_ip = vsubq_f32(mip, mi_mp);

                let denom = vaddq_f32(v_var, veps);
                let a = vdivq_f32(cov_ip, denom);

                let a_mi = vmulq_f32(a, mi);
                let b = vsubq_f32(mp, a_mi);

                vst1q_f32(a_out.as_mut_ptr().add(offset), a);
                vst1q_f32(b_out.as_mut_ptr().add(offset), b);
            }
        }
    }

    #[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
    {
        for i in 0..chunks {
            let offset = i * 4;
            for j in 0..4 {
                let idx = offset + j;
                let cov_ip = mean_ip[idx] - mean_i[idx] * mean_p[idx];
                let a = cov_ip / (var_i[idx] + eps);
                let b = mean_p[idx] - a * mean_i[idx];
                a_out[idx] = a;
                b_out[idx] = b;
            }
        }
    }

    for i in remainder..len {
        let cov_ip = mean_ip[i] - mean_i[i] * mean_p[i];
        let a = cov_ip / (var_i[i] + eps);
        let b = mean_p[i] - a * mean_i[i];
        a_out[i] = a;
        b_out[i] = b;
    }
}

/// Vectorized unsharp pass: `out = (src + (src - base) * amount).clamp(0, 255)`.
pub fn vector_unsharp(src: &[u8], base: &[u8], amount: f32, out: &mut [u8]) {
    assert_eq!(src.len(), base.len());
    assert_eq!(src.len(), out.len());

    let num_pixels = src.len() / 4;

    #[cfg(target_arch = "x86_64")]
    {
        unsafe {
            let v_amount = _mm_set1_ps(amount);
            let v_zero = _mm_setzero_ps();
            let v_255 = _mm_set1_ps(255.0);

            for i in 0..num_pixels {
                let offset = i * 4;
                let o0 = src[offset] as f32;
                let o1 = src[offset + 1] as f32;
                let o2 = src[offset + 2] as f32;
                let b0 = base[offset] as f32;
                let b1 = base[offset + 1] as f32;
                let b2 = base[offset + 2] as f32;

                let vo = _mm_set_ps(0.0, o2, o1, o0);
                let vb = _mm_set_ps(0.0, b2, b1, b0);
                let vdiff = _mm_sub_ps(vo, vb);
                let vscaled = _mm_mul_ps(vdiff, v_amount);
                let vres = _mm_add_ps(vo, vscaled);
                let vclamped = _mm_min_ps(v_255, _mm_max_ps(v_zero, vres));

                let mut res = [0.0f32; 4];
                _mm_storeu_ps(res.as_mut_ptr(), vclamped);

                out[offset] = res[0] as u8;
                out[offset + 1] = res[1] as u8;
                out[offset + 2] = res[2] as u8;
                out[offset + 3] = src[offset + 3];
            }
        }
    }

    #[cfg(target_arch = "aarch64")]
    {
        unsafe {
            let v_amount = vdupq_n_f32(amount);
            let v_zero = vdupq_n_f32(0.0);
            let v_255 = vdupq_n_f32(255.0);

            for i in 0..num_pixels {
                let offset = i * 4;
                let o0 = src[offset] as f32;
                let o1 = src[offset + 1] as f32;
                let o2 = src[offset + 2] as f32;
                let b0 = base[offset] as f32;
                let b1 = base[offset + 1] as f32;
                let b2 = base[offset + 2] as f32;

                let vo = [o0, o1, o2, 0.0f32];
                let vb = [b0, b1, b2, 0.0f32];
                let vvo = vld1q_f32(vo.as_ptr());
                let vvb = vld1q_f32(vb.as_ptr());
                let vdiff = vsubq_f32(vvo, vvb);
                let vscaled = vmulq_f32(vdiff, v_amount);
                let vres = vaddq_f32(vvo, vscaled);
                let vclamped = vminq_f32(v_255, vmaxq_f32(v_zero, vres));

                let mut res = [0.0f32; 4];
                vst1q_f32(res.as_mut_ptr(), vclamped);

                out[offset] = res[0] as u8;
                out[offset + 1] = res[1] as u8;
                out[offset + 2] = res[2] as u8;
                out[offset + 3] = src[offset + 3];
            }
        }
    }

    #[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
    {
        for i in 0..num_pixels {
            let offset = i * 4;
            for c in 0..3 {
                let o = src[offset + c] as f32;
                let b = base[offset + c] as f32;
                out[offset + c] = (o + (o - b) * amount).clamp(0.0, 255.0) as u8;
            }
            out[offset + 3] = src[offset + 3];
        }
    }
}

// ============================================================================
// Scalar reference implementations for correctness verification
// ============================================================================

pub fn scalar_mul(a: &[f32], b: &[f32], out: &mut [f32]) {
    for i in 0..a.len() {
        out[i] = a[i] * b[i];
    }
}

pub fn scalar_linear_combination(a: &[f32], b: &[f32], c: &[f32], out: &mut [f32]) {
    for i in 0..a.len() {
        out[i] = a[i] * b[i] + c[i];
    }
}

pub fn scalar_guided_coeffs(
    mean_i: &[f32],
    mean_p: &[f32],
    mean_ii: &[f32],
    mean_ip: &[f32],
    eps: f32,
    a_out: &mut [f32],
    b_out: &mut [f32],
) {
    for i in 0..mean_i.len() {
        let var_i = (mean_ii[i] - mean_i[i] * mean_i[i]).max(0.0);
        let cov_ip = mean_ip[i] - mean_i[i] * mean_p[i];
        let a = cov_ip / (var_i + eps);
        let b = mean_p[i] - a * mean_i[i];
        a_out[i] = a;
        b_out[i] = b;
    }
}

pub fn scalar_unsharp(src: &[u8], base: &[u8], amount: f32, out: &mut [u8]) {
    for i in 0..src.len() / 4 {
        for c in 0..3 {
            let o = src[i * 4 + c] as f32;
            let b = base[i * 4 + c] as f32;
            out[i * 4 + c] = (o + (o - b) * amount).clamp(0.0, 255.0) as u8;
        }
        out[i * 4 + 3] = src[i * 4 + 3];
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_vector_mul_matches_scalar() {
        for size in [1, 4, 7, 16, 33, 1024] {
            let a: Vec<f32> = (0..size).map(|i| (i as f32 * 0.1) + 1.0).collect();
            let b: Vec<f32> = (0..size).map(|i| (i as f32 * 0.2) + 0.5).collect();
            let mut out_simd = vec![0.0f32; size];
            let mut out_scalar = vec![0.0f32; size];

            vector_mul(&a, &b, &mut out_simd);
            scalar_mul(&a, &b, &mut out_scalar);

            for i in 0..size {
                assert!(
                    (out_simd[i] - out_scalar[i]).abs() < 1e-6,
                    "Mismatch at index {i} for size {size}: simd={}, scalar={}",
                    out_simd[i],
                    out_scalar[i]
                );
            }
        }
    }

    #[test]
    fn test_vector_linear_combination_matches_scalar() {
        for size in [1, 4, 7, 16, 33, 1024] {
            let a: Vec<f32> = (0..size).map(|i| i as f32 * 0.3).collect();
            let b: Vec<f32> = (0..size).map(|i| (i as f32 * 0.1) + 0.2).collect();
            let c: Vec<f32> = (0..size).map(|i| i as f32 * -0.05).collect();
            let mut out_simd = vec![0.0f32; size];
            let mut out_scalar = vec![0.0f32; size];

            vector_linear_combination(&a, &b, &c, &mut out_simd);
            scalar_linear_combination(&a, &b, &c, &mut out_scalar);

            for i in 0..size {
                assert!(
                    (out_simd[i] - out_scalar[i]).abs() < 1e-5,
                    "Mismatch at index {i} for size {size}: simd={}, scalar={}",
                    out_simd[i],
                    out_scalar[i]
                );
            }
        }
    }

    #[test]
    fn test_vector_guided_coeffs_matches_scalar() {
        for size in [1, 4, 7, 16, 33, 1024] {
            let mi: Vec<f32> = (0..size).map(|i| (i % 256) as f32 / 255.0).collect();
            let mp: Vec<f32> = (0..size).map(|i| ((i + 50) % 256) as f32 / 255.0).collect();
            let mii: Vec<f32> = mi.iter().map(|&v| v * v + 0.05).collect();
            let mip: Vec<f32> = mi
                .iter()
                .zip(mp.iter())
                .map(|(&i, &p)| i * p + 0.02)
                .collect();

            let mut a_simd = vec![0.0f32; size];
            let mut b_simd = vec![0.0f32; size];
            let mut a_scalar = vec![0.0f32; size];
            let mut b_scalar = vec![0.0f32; size];

            let eps = 1e-3f32;
            vector_guided_coeffs(&mi, &mp, &mii, &mip, eps, &mut a_simd, &mut b_simd);
            scalar_guided_coeffs(&mi, &mp, &mii, &mip, eps, &mut a_scalar, &mut b_scalar);

            for i in 0..size {
                assert!(
                    (a_simd[i] - a_scalar[i]).abs() < 1e-5,
                    "Coeff a mismatch at {i}: simd={}, scalar={}",
                    a_simd[i],
                    a_scalar[i]
                );
                assert!(
                    (b_simd[i] - b_scalar[i]).abs() < 1e-5,
                    "Coeff b mismatch at {i}: simd={}, scalar={}",
                    b_simd[i],
                    b_scalar[i]
                );
            }
        }
    }

    #[test]
    fn test_vector_unsharp_matches_scalar() {
        let size = 64; // 16 pixels * 4 channels
        let src: Vec<u8> = (0..size).map(|i| (i * 3) as u8).collect();
        let base: Vec<u8> = (0..size).map(|i| (i * 2 + 10) as u8).collect();
        let mut out_simd = vec![0u8; size];
        let mut out_scalar = vec![0u8; size];

        vector_unsharp(&src, &base, 0.5, &mut out_simd);
        scalar_unsharp(&src, &base, 0.5, &mut out_scalar);

        assert_eq!(out_simd, out_scalar);
    }
}
