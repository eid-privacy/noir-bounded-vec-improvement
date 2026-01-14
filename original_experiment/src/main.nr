use noir_base64::BASE64_URL_ENCODER;
use sha256::sha256_var;

mod CustomBoundedVec;
use CustomBoundedVec::OptimizedBoundedVec;

global PAYLOAD_MAX_LEN: u32 = 2000;

global ENCODED_PAYLOAD_MAX_LEN: u32 = (PAYLOAD_MAX_LEN * 4 + 2) / 3;

global SIGNING_INPUT_MAX_LEN: u32 = 37 + ENCODED_PAYLOAD_MAX_LEN;

global ASCII_DOT: u8 = 46;
global EIGHTEEN_YEARS_SECONDS: u64 = 18 * 365 * 24 * 60 * 60; // Not exact but close enough

global ENCODED_HEADER: [u8; 36] = [
    // Pre-encoded JWT header: {"typ":"JWT","alg":"ES256"}
    101, 121, 74, 48, 101, 88, 65, 105, 79, 105, 74, 75, 86, 49, 81, 105, 76, 67, 74, 104, 98, 71,
    99, 105, 79, 105, 74, 70, 85, 122, 73, 49, 78, 105, 74, 57,
];

/// Extracts a decimal number from payload at given offset.
/// Safety: Payload is verified via JWT signature.
unconstrained fn extract_number<let N: u32>(data: [u8; N], data_len: u32, offset: u32) -> u64 {
    let mut value: u64 = 0;
    let mut i = offset;

    // Parse digits until non-digit
    while i < data_len {
        let byte = data[i];
        if (byte >= 48) & (byte <= 57) {
            value = value * 10 + ((byte - 48) as u64);
            i += 1;
        } else {
            break;
        }
    }
    value
}

fn main(
    payload: BoundedVec<u8, PAYLOAD_MAX_LEN>,
    jwt_signature: [u8; 64],
    issuer_pub_x: pub [u8; 32],
    issuer_pub_y: pub [u8; 32],
    dob_offset: u32,
    time_now_unix: pub u64,
) {
    let encoded_payload = BASE64_URL_ENCODER::encode_var(payload);

    let mut signing_input: OptimizedBoundedVec<u8, SIGNING_INPUT_MAX_LEN> =
        OptimizedBoundedVec::from(ENCODED_HEADER);
    signing_input.push(ASCII_DOT);

    signing_input.extend_from_bounded_vec(encoded_payload);

    let signing_input_hash = sha256_var(signing_input.storage(), signing_input.len());

    let valid_jwt_sig = std::ecdsa_secp256r1::verify_signature(
        issuer_pub_x,
        issuer_pub_y,
        jwt_signature,
        signing_input_hash,
    );
    assert(valid_jwt_sig, "Invalid JWT signature");

    // First verify "dob": pattern exists at claimed offset
    // Pattern: "dob": = [34, 100, 111, 98, 34, 58]
    let payload_storage = payload.storage();
    assert(payload_storage[dob_offset] == 34, "DOB key not found"); // "
    assert(payload_storage[dob_offset + 1] == 100, "DOB key not found"); // d
    assert(payload_storage[dob_offset + 2] == 111, "DOB key not found"); // o
    assert(payload_storage[dob_offset + 3] == 98, "DOB key not found"); // b
    assert(payload_storage[dob_offset + 4] == 34, "DOB key not found"); // "
    assert(payload_storage[dob_offset + 5] == 58, "DOB key not found"); // :`
    // Safety: Parse the decimal string as u64. This is safe because we extracted it from verified payload.
    let date_of_birth = unsafe { extract_number(payload_storage, payload.len(), dob_offset + 6) };

    // We verify the device here - To be added later to focus on the age verification right now!
    let date_of_birth_plus_18: u64 = date_of_birth + EIGHTEEN_YEARS_SECONDS;
    assert(date_of_birth_plus_18 <= time_now_unix, "User must be 18 or older");
}

#[test]
fn test_jwt_verification() {
    // {
    //     "cnf": {
    //         "kty": "EC",
    //         "use": "sig",
    //         "crv": "P-256",
    //         "kid": "e5fd0b37-572a-4a95-b515-d7d7412cd54f",
    //         "x": "4Ch_SBDcVSHipLePUBp8y5RH18VOlirVRtOt-tB-Y_Y",
    //         "y": "ePh6PDXQ2cbm53W6aL832Xr8LH5P-bScppq-5eMIl0A"
    //     },
    //     "iat": 1739801909,
    //     "document_number": "BETA-ID-P5Y700MS",
    //     "given_name": "Helvetia",
    //     "family_name": "National",
    //     "birth_date": "1988-01-01",
    //     "dob": 23331000,
    //     "birth_place": "Luzern",
    //     "place_of_origin": "Altdorf UR",
    //     "sex": "2",
    //     "nationality": "CH",
    //     "expiry_date": "2025-05-17"
    // }
    let payload_bytes: [u8; 445] = [
        123, 34, 99, 110, 102, 34, 58, 123, 34, 107, 116, 121, 34, 58, 34, 69, 67, 34, 44, 34, 117,
        115, 101, 34, 58, 34, 115, 105, 103, 34, 44, 34, 99, 114, 118, 34, 58, 34, 80, 45, 50, 53,
        54, 34, 44, 34, 107, 105, 100, 34, 58, 34, 101, 53, 102, 100, 48, 98, 51, 55, 45, 53, 55,
        50, 97, 45, 52, 97, 57, 53, 45, 98, 53, 49, 53, 45, 100, 55, 100, 55, 52, 49, 50, 99, 100,
        53, 52, 102, 34, 44, 34, 120, 34, 58, 34, 52, 67, 104, 95, 83, 66, 68, 99, 86, 83, 72, 105,
        112, 76, 101, 80, 85, 66, 112, 56, 121, 53, 82, 72, 49, 56, 86, 79, 108, 105, 114, 86, 82,
        116, 79, 116, 45, 116, 66, 45, 89, 95, 89, 34, 44, 34, 121, 34, 58, 34, 101, 80, 104, 54,
        80, 68, 88, 81, 50, 99, 98, 109, 53, 51, 87, 54, 97, 76, 56, 51, 50, 88, 114, 56, 76, 72,
        53, 80, 45, 98, 83, 99, 112, 112, 113, 45, 53, 101, 77, 73, 108, 48, 65, 34, 125, 44, 34,
        105, 97, 116, 34, 58, 49, 55, 51, 57, 56, 48, 49, 57, 48, 57, 44, 34, 100, 111, 99, 117,
        109, 101, 110, 116, 95, 110, 117, 109, 98, 101, 114, 34, 58, 34, 66, 69, 84, 65, 45, 73, 68,
        45, 80, 53, 89, 55, 48, 48, 77, 83, 34, 44, 34, 103, 105, 118, 101, 110, 95, 110, 97, 109,
        101, 34, 58, 34, 72, 101, 108, 118, 101, 116, 105, 97, 34, 44, 34, 102, 97, 109, 105, 108,
        121, 95, 110, 97, 109, 101, 34, 58, 34, 78, 97, 116, 105, 111, 110, 97, 108, 34, 44, 34, 98,
        105, 114, 116, 104, 95, 100, 97, 116, 101, 34, 58, 34, 49, 57, 56, 56, 45, 48, 49, 45, 48,
        49, 34, 44, 34, 100, 111, 98, 34, 58, 50, 51, 51, 51, 49, 48, 48, 48, 44, 34, 98, 105, 114,
        116, 104, 95, 112, 108, 97, 99, 101, 34, 58, 34, 76, 117, 122, 101, 114, 110, 34, 44, 34,
        112, 108, 97, 99, 101, 95, 111, 102, 95, 111, 114, 105, 103, 105, 110, 34, 58, 34, 65, 108,
        116, 100, 111, 114, 102, 32, 85, 82, 34, 44, 34, 115, 101, 120, 34, 58, 34, 50, 34, 44, 34,
        110, 97, 116, 105, 111, 110, 97, 108, 105, 116, 121, 34, 58, 34, 67, 72, 34, 44, 34, 101,
        120, 112, 105, 114, 121, 95, 100, 97, 116, 101, 34, 58, 34, 50, 48, 50, 53, 45, 48, 53, 45,
        49, 55, 34, 125,
    ];
    let payload = BoundedVec::from(payload_bytes);

    let jwt_signature: [u8; 64] = [
        146, 72, 53, 84, 73, 130, 168, 164, 121, 30, 69, 152, 114, 0, 25, 119, 30, 238, 111, 78, 97,
        1, 150, 100, 219, 44, 166, 243, 244, 210, 109, 194, 50, 159, 6, 33, 21, 19, 95, 85, 154,
        248, 106, 41, 31, 228, 89, 162, 17, 23, 50, 68, 73, 148, 119, 90, 21, 66, 41, 114, 41, 236,
        22, 198,
    ];

    let issuer_x: [u8; 32] = [
        0xa7, 0x58, 0xf2, 0x69, 0xca, 0x2d, 0x2b, 0xde, 0xc4, 0x93, 0x1a, 0xf6, 0x0a, 0x5f, 0xaa,
        0xea, 0x9f, 0x45, 0x3a, 0x84, 0xbb, 0x43, 0x9b, 0x43, 0x00, 0xcb, 0xd6, 0x33, 0xd8, 0x4a,
        0xe9, 0xee,
    ];
    let issuer_y: [u8; 32] = [
        0xc7, 0x80, 0x52, 0xde, 0x32, 0x22, 0x5e, 0xc2, 0x1f, 0xdd, 0xd3, 0xe2, 0xd2, 0x5d, 0xcc,
        0x94, 0x09, 0xdd, 0xf3, 0xf8, 0x69, 0xea, 0x35, 0x7f, 0x68, 0xe8, 0xd7, 0x9e, 0xb0, 0xa8,
        0xed, 0x20,
    ];

    // Current time (example: January 1, 2024)
    let time_now_unix: u64 = 1704067200;
    let dob_offset: u32 = 320; // Position of "dob": in payload

    main(
        payload,
        jwt_signature,
        issuer_x,
        issuer_y,
        dob_offset,
        time_now_unix,
    )
}
