//! Pure-Rust RFC 8032 compliant Ed25519 digital signature algorithm.
//!
//! 100% offline, self-contained implementation with zero external network dependencies,
//! providing mathematically verifiable asymmetric cryptography for C2PA Content Credentials.

use num_bigint::BigUint;
use num_traits::{One, Zero};
use std::sync::LazyLock;

use crate::sha512::sha512;

// Curve parameters for Edwards25519: -x^2 + y^2 = 1 + d*x^2*y^2 (mod p)
static P: LazyLock<BigUint> = LazyLock::new(|| (BigUint::one() << 255) - BigUint::from(19u32));

static L: LazyLock<BigUint> = LazyLock::new(|| {
    (BigUint::one() << 252)
        + BigUint::parse_bytes(b"27742317777372353535851937790883648493", 10).unwrap()
});

static D: LazyLock<BigUint> = LazyLock::new(|| {
    // d = -121665 * 121666^-1 (mod p)
    BigUint::parse_bytes(
        b"37095705934669439343138083508754565189542113879843219016388785533085940283555",
        10,
    )
    .unwrap()
});

static SQRT_M1: LazyLock<BigUint> = LazyLock::new(|| {
    // 2^((p-1)/4) mod p
    BigUint::parse_bytes(
        b"19681161376707505956807079304988542015446066515923890162744021073123829784752",
        10,
    )
    .unwrap()
});

static BASE_X: LazyLock<BigUint> = LazyLock::new(|| {
    BigUint::parse_bytes(
        b"15112221349535400772501151409588531511454012693041857206046113283949847762202",
        10,
    )
    .unwrap()
});

static BASE_Y: LazyLock<BigUint> = LazyLock::new(|| {
    BigUint::parse_bytes(
        b"46316835694926478169428394003475163141307993866256225615783033603165251855960",
        10,
    )
    .unwrap()
});

#[derive(Clone, Debug, PartialEq)]
pub struct Point {
    pub x: BigUint,
    pub y: BigUint,
}

impl Point {
    pub fn identity() -> Self {
        Self {
            x: BigUint::zero(),
            y: BigUint::one(),
        }
    }

    pub fn base() -> Self {
        Self {
            x: BASE_X.clone(),
            y: BASE_Y.clone(),
        }
    }
}

/// Computes modular inverse using Fermat's Little Theorem: a^(p-2) mod p.
fn mod_inv(a: &BigUint, m: &BigUint) -> BigUint {
    a.modpow(&(m - BigUint::from(2u32)), m)
}

/// Point addition on Edwards25519 curve: P1 + P2.
pub fn point_add(p1: &Point, p2: &Point) -> Point {
    let p = &*P;
    let d = &*D;

    let x1 = &p1.x;
    let y1 = &p1.y;
    let x2 = &p2.x;
    let y2 = &p2.y;

    // x3 = (x1*y2 + y1*x2) / (1 + d*x1*x2*y1*y2) mod p
    let num_x = ((x1 * y2) % p + (y1 * x2) % p) % p;
    let dxxyy = (((((d * x1) % p) * x2 % p) * y1 % p) * y2) % p;
    let den_x = (BigUint::one() + &dxxyy) % p;
    let x3 = (num_x * mod_inv(&den_x, p)) % p;

    // y3 = (y1*y2 + x1*x2) / (1 - d*x1*x2*y1*y2) mod p
    let num_y = ((y1 * y2) % p + (x1 * x2) % p) % p;
    let den_y = (p + BigUint::one() - (&dxxyy % p)) % p;
    let y3 = (num_y * mod_inv(&den_y, p)) % p;

    Point { x: x3, y: y3 }
}

/// Scalar multiplication: k * P via double-and-add.
pub fn point_mul(k: &BigUint, pt: &Point) -> Point {
    let mut result = Point::identity();
    let mut addend = pt.clone();
    let bits = k.to_bytes_le();

    for byte in bits {
        for bit_idx in 0..8 {
            if (byte >> bit_idx) & 1 == 1 {
                result = point_add(&result, &addend);
            }
            addend = point_add(&addend, &addend);
        }
    }
    result
}

/// Encodes a curve point into 32 bytes according to RFC 8032.
pub fn encode_point(pt: &Point) -> [u8; 32] {
    let mut bytes = [0u8; 32];
    let y_bytes = pt.y.to_bytes_le();
    bytes[..y_bytes.len()].copy_from_slice(&y_bytes);
    if (&pt.x & BigUint::one()) == BigUint::one() {
        bytes[31] |= 0x80;
    }
    bytes
}

/// Decodes 32 bytes into a curve point according to RFC 8032.
pub fn decode_point(bytes: &[u8; 32]) -> Option<Point> {
    let p = &*P;
    let d = &*D;

    let x_sign = (bytes[31] >> 7) & 1;
    let mut y_bytes = *bytes;
    y_bytes[31] &= 0x7F;

    let y = BigUint::from_bytes_le(&y_bytes);
    if y >= *p {
        return None;
    }

    // x^2 = (y^2 - 1) / (d*y^2 + 1) mod p
    let y2 = (&y * &y) % p;
    let u = (p + &y2 - BigUint::one()) % p;
    let v = ((d * &y2) % p + BigUint::one()) % p;

    let v_inv = mod_inv(&v, p);
    let u_v_inv = (&u * &v_inv) % p;

    if u_v_inv.is_zero() {
        if x_sign == 1 {
            return None;
        }
        return Some(Point {
            x: BigUint::zero(),
            y,
        });
    }

    let p_plus_3_div_8 = (p + BigUint::from(3u32)) / BigUint::from(8u32);
    let mut x = u_v_inv.modpow(&p_plus_3_div_8, p);

    let vx2 = ((&v * &x) % p * &x) % p;
    if vx2 == u {
        // Correct root
    } else if vx2 == (p - &u) % p {
        x = (&x * &*SQRT_M1) % p;
    } else {
        return None; // No square root
    }
    let vx2_final = ((&v * &x) % p * &x) % p;
    if vx2_final != u {
        return None;
    }

    if ((&x & BigUint::one()) == BigUint::one()) as u8 != x_sign {
        x = p - x;
    }

    Some(Point { x, y })
}

/// Derives the 32-byte Ed25519 public key from a 32-byte secret seed.
pub fn public_key_from_seed(seed: &[u8; 32]) -> [u8; 32] {
    let h = sha512(seed);
    let mut s = [0u8; 32];
    s.copy_from_slice(&h[0..32]);
    s[0] &= 248;
    s[31] &= 127;
    s[31] |= 64;

    let scalar = BigUint::from_bytes_le(&s);
    let pt = point_mul(&scalar, &Point::base());
    encode_point(&pt)
}

/// Signs a message using an Ed25519 32-byte secret seed. Returns a 64-byte signature.
pub fn sign_ed25519(seed: &[u8; 32], message: &[u8]) -> [u8; 64] {
    let l = &*L;
    let h = sha512(seed);

    let mut s = [0u8; 32];
    s.copy_from_slice(&h[0..32]);
    s[0] &= 248;
    s[31] &= 127;
    s[31] |= 64;
    let s_scalar = BigUint::from_bytes_le(&s);

    let public_key = public_key_from_seed(seed);

    // Nonce: r = SHA-512(h[32..64] || message) mod L
    let mut nonce_hasher_input = Vec::with_capacity(32 + message.len());
    nonce_hasher_input.extend_from_slice(&h[32..64]);
    nonce_hasher_input.extend_from_slice(message);
    let r_digest = sha512(&nonce_hasher_input);
    let r = BigUint::from_bytes_le(&r_digest) % l;

    // R = r * B
    let r_point = point_mul(&r, &Point::base());
    let r_bytes = encode_point(&r_point);

    // k = SHA-512(R || public_key || message) mod L
    let mut k_hasher_input = Vec::with_capacity(64 + message.len());
    k_hasher_input.extend_from_slice(&r_bytes);
    k_hasher_input.extend_from_slice(&public_key);
    k_hasher_input.extend_from_slice(message);
    let k_digest = sha512(&k_hasher_input);
    let k = BigUint::from_bytes_le(&k_digest) % l;

    // S = (r + k * s) mod L
    let s_val = (r + (k * s_scalar) % l) % l;
    let mut s_bytes = [0u8; 32];
    let le = s_val.to_bytes_le();
    s_bytes[..le.len()].copy_from_slice(&le);

    let mut sig = [0u8; 64];
    sig[0..32].copy_from_slice(&r_bytes);
    sig[32..64].copy_from_slice(&s_bytes);
    sig
}

/// Verifies an Ed25519 signature against a message and public key.
pub fn verify_ed25519(public_key: &[u8; 32], message: &[u8], signature: &[u8; 64]) -> bool {
    verify_ed25519_internal(public_key, message, signature).unwrap_or(false)
}

fn verify_ed25519_internal(
    public_key: &[u8; 32],
    message: &[u8],
    signature: &[u8; 64],
) -> Option<bool> {
    let l = &*L;

    let mut r_bytes = [0u8; 32];
    r_bytes.copy_from_slice(&signature[0..32]);

    let mut s_bytes = [0u8; 32];
    s_bytes.copy_from_slice(&signature[32..64]);

    let s = BigUint::from_bytes_le(&s_bytes);
    if s >= *l {
        return Some(false);
    }

    let a_point = decode_point(public_key)?;
    let r_point = decode_point(&r_bytes)?;

    let mut k_hasher_input = Vec::with_capacity(64 + message.len());
    k_hasher_input.extend_from_slice(&r_bytes);
    k_hasher_input.extend_from_slice(public_key);
    k_hasher_input.extend_from_slice(message);
    let k_digest = sha512(&k_hasher_input);
    let k = BigUint::from_bytes_le(&k_digest) % l;

    let sb = point_mul(&s, &Point::base());
    let ka = point_mul(&k, &a_point);
    let r_plus_ka = point_add(&r_point, &ka);

    Some(sb == r_plus_ka)
}

#[cfg(test)]
mod tests {
    use super::*;

    // Official RFC 8032 Test Vector 1 (section 7.1)
    #[test]
    fn test_rfc8032_vector_1() {
        let seed: [u8; 32] = [
            0x9d, 0x61, 0xb1, 0x9d, 0xef, 0xfd, 0x5a, 0x60, 0xba, 0x84, 0x4a, 0xf4, 0x92, 0xec,
            0x2c, 0xc4, 0x44, 0x49, 0xc5, 0x69, 0x7b, 0x32, 0x69, 0x19, 0x70, 0x3b, 0xac, 0x03,
            0x1c, 0xae, 0x7f, 0x60,
        ];
        let expected_pk: [u8; 32] = [
            0xd7, 0x5a, 0x98, 0x01, 0x82, 0xb1, 0x0a, 0xb7, 0xd5, 0x4b, 0xfe, 0xd3, 0xc9, 0x64,
            0x07, 0x3a, 0x0e, 0xe1, 0x72, 0xf3, 0xda, 0xa6, 0x23, 0x25, 0xaf, 0x02, 0x1a, 0x68,
            0xf7, 0x07, 0x51, 0x1a,
        ];
        let pk = public_key_from_seed(&seed);
        assert_eq!(pk, expected_pk, "RFC 8032 public key generation mismatch");

        let msg = b"";
        let sig = sign_ed25519(&seed, msg);
        let expected_sig_hex = "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b";
        let sig_hex: String = sig.iter().map(|b| format!("{:02x}", b)).collect();
        assert_eq!(sig_hex, expected_sig_hex, "RFC 8032 signature mismatch");

        assert!(
            verify_ed25519(&pk, msg, &sig),
            "RFC 8032 signature verification must pass"
        );

        // Verification must fail on tampered message
        assert!(
            !verify_ed25519(&pk, b"tampered", &sig),
            "Verification must fail on tampered message"
        );
    }
}
