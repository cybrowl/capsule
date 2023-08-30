import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Map "mo:hash-map";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

import Hex "./utils/Hex";

actor {
	stable var private_message = "";
	let { thash } = Map;

	public type ErrVetKD = {
		#NotAuthorized : Bool;
	};

	public type Asset = {
		created : Int;
		content_type : Text;
		filename : Text;
		url : Text;
	};

	type CapsuleId = Text;

	type Capsule = {
		id : CapsuleId;
		owner : Principal;
		authorized : ?[Text];
		locked_minutes : Nat;
		locked_start : Nat;
		files : ?[Asset];
	};

	private var capsules = Map.new<CapsuleId, Capsule>(thash);

	public query func version() : async Nat {
		return 1;
	};

	public query func check_capsule_exists(id : CapsuleId) : async Bool {
		switch (Map.get(capsules, thash, id)) {
			case (?capsule) {
				return true;
			};
			case (_) {
				return false;
			};
		};
	};

	public shared ({ caller }) func create_capsule(id : CapsuleId) : async Result.Result<Text, Text> {
		if (Principal.isAnonymous(caller)) {
			return #err("Anon");
		};

		switch (Map.get(capsules, thash, id)) {
			case (?capsule) {
				return #err("CapsuleExists");
			};
			case (_) {
				let capsule : Capsule = {
					id = id;
					owner = caller;
					authorized = null;
					locked_minutes = 0;
					locked_start = 0;
					files = null;
				};

				ignore Map.put(capsules, thash, id, capsule);

				return #ok("Created Capsule");
			};
		};
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

	// TODO: principal might need to change to something else in prod
	let vetkd_system_api : VETKD_SYSTEM_API = actor ("p4cnc-5aaaa-aaaag-abwgq-cai");

	public shared func app_vetkd_public_key(derivation_path : [Blob]) : async Text {
		let { public_key } = await vetkd_system_api.vetkd_public_key({
			canister_id = null;
			derivation_path;
			key_id = { curve = #bls12_381; name = "test_key_1" };
		});

		Hex.encode(Blob.toArray(public_key));
	};

	// symmetric
	public shared func symmetric_key_verification_key() : async Text {
		let { public_key } = await vetkd_system_api.vetkd_public_key({
			canister_id = null;
			derivation_path = Array.make(Text.encodeUtf8("symmetric_key"));
			key_id = { curve = #bls12_381; name = "test_key_1" };
		});

		Hex.encode(Blob.toArray(public_key));
	};

	public shared ({ caller }) func encrypted_symmetric_key_for_caller(encryption_public_key : Blob) : async Result.Result<Text, ErrVetKD> {
		if (Principal.isAnonymous(caller)) {
			return #err(#NotAuthorized(true));
		};

		//TODO: check how long until unlock happens for capsule
		// for testing make it 10 secs
		// one owner per capsule
		// capsule can only be claimed once (method to claim capsule if authenticated)

		let { encrypted_key } = await vetkd_system_api.vetkd_encrypted_key({
			derivation_id = Principal.toBlob(caller);
			public_key_derivation_path = Array.make(Text.encodeUtf8("symmetric_key"));
			key_id = { curve = #bls12_381; name = "test_key_1" };
			encryption_public_key;
		});

		return #ok(Hex.encode(Blob.toArray(encrypted_key)));
	};

	public shared func encrypted_symmetric_key_by_pass(password : Text, encryption_public_key : Blob) : async Text {
		let pass : Blob = Text.encodeUtf8(password);

		let { encrypted_key } = await vetkd_system_api.vetkd_encrypted_key({
			derivation_id = pass;
			public_key_derivation_path = Array.make(Text.encodeUtf8("symmetric_key"));
			key_id = { curve = #bls12_381; name = "test_key_1" };
			encryption_public_key;
		});

		Hex.encode(Blob.toArray(encrypted_key));
	};

	// ibe
	// public shared func ibe_encryption_key() : async Text {
	//     let { public_key } = await vetkd_system_api.vetkd_public_key({
	//         canister_id = null;
	//         derivation_path = Array.make(Text.encodeUtf8("ibe_encryption"));
	//         key_id = { curve = #bls12_381; name = "test_key_1" };
	//     });

	//     Hex.encode(Blob.toArray(public_key));
	// };

	// public shared ({ caller }) func encrypted_ibe_decryption_key_for_caller(encryption_public_key : Blob) : async Text {

	//     let { encrypted_key } = await vetkd_system_api.vetkd_encrypted_key({
	//         derivation_id = Principal.toBlob(caller);
	//         public_key_derivation_path = Array.make(Text.encodeUtf8("ibe_encryption"));
	//         key_id = { curve = #bls12_381; name = "test_key_1" };
	//         encryption_public_key;
	//     });

	//     Hex.encode(Blob.toArray(encrypted_key));
	// };
};
