import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Map "mo:map/Map";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

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
	type Time = Int;

	type Capsule = {
		id : CapsuleId;
		owner : Principal; // anon already
		authorized : [Principal]; // anon already
		locked_minutes : Nat;
		locked_start : Time;
		files : [Asset];
	};

	public type Err = {
		#Anon : Bool;
		#AssetNotFound : Bool;
		#NotOwner : Bool;
		#CapsuleNotFound : Bool;
		#CapsuleExists : Bool;
	};

	public type Ok = {
		#CreatedCapsule : Bool;
		#AddedFile : Bool;
		#AddedTime : Bool;
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

	public query func get_capsules_size() : async Nat {
		return Map.size(capsules);
	};

	public query ({ caller }) func get_capsule(id : CapsuleId) : async Result.Result<Capsule, Err> {
		if (Principal.isAnonymous(caller)) {
			return #err(#Anon(true));
		};

		// TODO: if capsule is locked do NOT return capsule info

		switch (Map.get(capsules, thash, id)) {
			case (?capsule) {
				if (Principal.equal(caller, capsule.owner)) {
					let anonymousPrincipal : Blob = "\04";

					let capsule_updated : Capsule = {
						capsule with owner = Principal.fromBlob(anonymousPrincipal)
					};

					return #ok(capsule_updated);
				} else {
					return #err(#NotOwner(true));
				};

			};
			case (_) {
				return #err(#CapsuleNotFound(true));
			};
		};
	};

	public shared ({ caller }) func create_capsule(id : CapsuleId) : async Result.Result<Ok, Err> {
		if (Principal.isAnonymous(caller)) {
			return #err(#Anon(true));
		};

		switch (Map.get(capsules, thash, id)) {
			case (?capsule) {
				return #err(#CapsuleExists(true));
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

				return #ok(#CreatedCapsule(true));
			};
		};
	};

	public shared ({ caller }) func add_file(capsule_id : CapsuleId, asset_id : Asset_ID) : async Result.Result<Ok, Err> {
		if (Principal.isAnonymous(caller)) {
			return #err(#Anon(true));
		};

		switch (await FileStorage.get(asset_id)) {
			case (#err asset_err) {
				return #err(#AssetNotFound(true));
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

							return #ok(#AddedFile(true));
						};
						case (_) {
							return #err(#CapsuleNotFound(true));
						};
					};
				} else {
					return #err(#NotOwner(true));
				};
			};
		};
	};

	public shared ({ caller }) func add_time(capsule_id : CapsuleId, minutes : Nat) : async Result.Result<Ok, Err> {
		if (Principal.isAnonymous(caller)) {
			return #err(#Anon(true));
		};

		switch (Map.get(capsules, thash, capsule_id)) {
			case (?capsule) {
				if (Principal.equal(capsule.owner, caller)) {

					//TODO: check if it is unlocked, if true reset `locked_start` to 0 & `locked_minutes` to 0
					let locked_minutes_updated : Nat = capsule.locked_minutes + minutes;

					if (capsule.locked_start == 0) {
						let capsule_updated : Capsule = {
							capsule with locked_minutes = locked_minutes_updated;
							locked_start = Time.now();
						};

						Map.set(capsules, thash, capsule_id, capsule_updated);
					} else {
						let capsule_updated : Capsule = {
							capsule with locked_minutes = locked_minutes_updated;
						};

						Map.set(capsules, thash, capsule_id, capsule_updated);
					};

					return #ok(#AddedTime(true));
				} else {
					return #err(#NotOwner(true));
				};
			};
			case (_) {
				return #err(#CapsuleNotFound(true));
			};
		};
	};

	public shared ({ caller }) func add_user(capsule_id : CapsuleId, user : Text) : async Result.Result<Ok, Err> {
		if (Principal.isAnonymous(caller)) {
			return #err(#Anon(true));
		};

		let user_principal : Principal = Principal.fromText(user);

		switch (Map.get(capsules, thash, capsule_id)) {
			case (?capsule) {
				if (Principal.equal(capsule.owner, user_principal)) {

					var authorized_updated : Buffer.Buffer<Principal> = Buffer.fromArray(capsule.authorized);
					authorized_updated.add(user_principal);

					let capsule_updated : Capsule = {
						capsule with authorized = Buffer.toArray(authorized_updated);
					};

					ignore Map.put(capsules, thash, capsule_id, capsule_updated);

					return #ok(#AddedTime(true));
				} else {
					return #err(#NotOwner(true));
				};
			};
			case (_) {
				return #err(#CapsuleNotFound(true));
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
