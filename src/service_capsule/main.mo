import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

import Hex "./utils/Hex";

actor {
  public query func version() : async Nat {
    return 1;
  };

  // ------------------------- VETKD_SYSTEM_API -------------------------
  type VETKD_SYSTEM_API = actor {
    vetkd_public_key : ({
      canister_id : ?Principal;
      derivation_path : [Blob];
      key_id : { curve : { #bls12_381 }; name : Text };
    }) -> async ({ public_key : Blob });
    vetkd_encrypted_key : ({
      public_key_derivation_path : [Blob];
      derivation_id : Blob;
      key_id : { curve : { #bls12_381 }; name : Text };
      encryption_public_key : Blob;
    }) -> async ({ encrypted_key : Blob });
  };

  let vetkd_system_api : VETKD_SYSTEM_API = actor ("aaaaa-aa");

  public shared func app_vetkd_public_key(derivation_path : [Blob]) : async Text {
    let { public_key } = await vetkd_system_api.vetkd_public_key({
      canister_id = null;
      derivation_path;
      key_id = { curve = #bls12_381; name = "test_key_1" };
    });

    Hex.encode(Blob.toArray(public_key));
  };

  // symmetric
  public shared ({ caller }) func symmetric_key_verification_key() : async Text {
    let { public_key } = await vetkd_system_api.vetkd_public_key({
      canister_id = null;
      derivation_path = Array.make(Text.encodeUtf8("symmetric_key"));
      key_id = { curve = #bls12_381; name = "test_key_1" };
    });

    Hex.encode(Blob.toArray(public_key));
  };

  public shared ({ caller }) func encrypted_symmetric_key_for_caller(encryption_public_key : Blob) : async Text {

    let { encrypted_key } = await vetkd_system_api.vetkd_encrypted_key({
      derivation_id = Principal.toBlob(caller);
      public_key_derivation_path = Array.make(Text.encodeUtf8("symmetric_key"));
      key_id = { curve = #bls12_381; name = "test_key_1" };
      encryption_public_key;
    });

    Hex.encode(Blob.toArray(encrypted_key));
  };

  // ibe
  public shared func ibe_encryption_key() : async Text {
    let { public_key } = await vetkd_system_api.vetkd_public_key({
      canister_id = null;
      derivation_path = Array.make(Text.encodeUtf8("ibe_encryption"));
      key_id = { curve = #bls12_381; name = "test_key_1" };
    });

    Hex.encode(Blob.toArray(public_key));
  };

  public shared ({ caller }) func encrypted_ibe_decryption_key_for_caller(encryption_public_key : Blob) : async Text {

    let { encrypted_key } = await vetkd_system_api.vetkd_encrypted_key({
      derivation_id = Principal.toBlob(caller);
      public_key_derivation_path = Array.make(Text.encodeUtf8("ibe_encryption"));
      key_id = { curve = #bls12_381; name = "test_key_1" };
      encryption_public_key;
    });

    Hex.encode(Blob.toArray(encrypted_key));
  };
};
