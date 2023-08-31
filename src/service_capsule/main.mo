import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Map "mo:hash-map";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

import Hex "./utils/Hex";

import FileStorage "canister:file_storage";

actor {
	let { thash } = Map;

	public type ErrVetKD = {
		#NotAuthorized : Bool;
	};

	public type Asset = {
		created : Int;
		content_type : Text;
		filename : Text; // filename is public, not PII
		url : Text; // url is public but encrypted data
	};

	type CapsuleId = Text;
	type Asset_ID = Text;

	type Capsule = {
		id : CapsuleId;
		owner : Principal; // anon already
		authorized : [Text]; // anon already
		locked_minutes : Nat;
		locked_start : Nat;
		files : [Asset];
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

	public query ({ caller }) func get_capsule(id : CapsuleId) : async Result.Result<Capsule, Text> {
		if (Principal.isAnonymous(caller)) {
			return #err("Anon");
		};

		// TODO: if capsule is locked do NOT return capsule info

		switch (Map.get(capsules, thash, id)) {
			case (?capsule) {
				if (Principal.equal(caller, capsule.owner)) {
					return #ok(capsule);
				} else {
					return #err("Not Owner");
				};

			};
			case (_) {
				return #err("Not Found");
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
					authorized = [];
					locked_minutes = 0;
					locked_start = 0;
					files = [];
				};

				ignore Map.put(capsules, thash, id, capsule);

				return #ok("Created Capsule");
			};
		};
	};

	public shared ({ caller }) func add_file(capsule_id : CapsuleId, asset_id : Asset_ID) : async Result.Result<Text, Text> {
		if (Principal.isAnonymous(caller)) {
			return #err("Anon");
		};

		switch (await FileStorage.get(asset_id)) {
			case (#err asset_err) {
				return #err(asset_err);
			};
			case (#ok asset) {
				if (Principal.equal(Principal.fromText(asset.owner), caller)) {
					switch (Map.get(capsules, thash, capsule_id)) {
						case (?capsule) {
							let file : Asset = {
								created = asset.created;
								content_type = asset.content_type;
								filename = asset.filename;
								url = asset.url;
							};

							var files_updated : Buffer.Buffer<Asset> = Buffer.fromArray(capsule.files);
							files_updated.add(file);

							let capsule_updated : Capsule = {
								capsule with files = Buffer.toArray(files_updated);
							};

							ignore Map.put(capsules, thash, capsule_id, capsule_updated);

							return #ok("Added File");
						};
						case (_) {

							return #err("Capsule Not Found");
						};
					};
				} else {
					return #err("Not Owner");
				};
			};
		};
	};

	// update capsule time

	// update capsule authorized

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

	// NOTE: this changes if in local vs prod
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
		// TODO: if capsule is locked do NOT verify key

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

		// TODO: if capsule is locked do NOT return key

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
