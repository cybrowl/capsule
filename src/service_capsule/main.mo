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
	let { thash; phash } = Map;

	public type ErrVetKD = {
		#NotAuthorized : Bool;
		#Locked : Bool;
	};

	public type Kind = {
		#Capsule;
		#Terminated;
		#TimeEncrypt;
	};

	public type Asset = {
		created : Int;
		content_type : Text;
		locked_minutes : Nat;
		filename : Text; // filename is public, not PII
		url : Text; // url is public but encrypted data
	};

	type CapsuleId = Text;
	type Asset_ID = Text;
	type Time = Int;

	type Capsule = {
		id : CapsuleId;
		kind : Kind;
		files : [Asset];
		authorized : [Principal]; // anon already
		owner : Principal; // anon already

		owner_is_terminated : Bool;
		countdown_minutes : Nat;
		last_login : Time;

		is_unlocked : Bool;
		locked_minutes : Nat;
		locked_start : Time;
	};

	public type Err = {
		#Anon : Bool;
		#AssetNotFound : Bool;
		#NotOwner : Bool;
		#CapsuleNotFound : Bool;
		#CapsuleExists : Bool;
		#WrongKind : Bool;
	};

	public type Ok = {
		#CreatedCapsule : Bool;
		#AddedFile : Bool;
		#AddedTime : Bool;
	};

	private var capsules = Map.new<CapsuleId, Capsule>(thash);
	private var capsule_owner = Map.new<Principal, CapsuleId>(phash);

	private func minutes_to_nanoseconds(minutes : Nat) : Nat {
		return 60_000_000_000 * minutes;
	};

	private func round_to_nearest_ten_minutes(t : Time) : Time {
		// 10 minutes * 60 seconds * 1_000_000_000 nanoseconds
		let nanoseconds_per_ten_minutes = 600_000_000_000;

		return (t / nanoseconds_per_ten_minutes) * nanoseconds_per_ten_minutes;
	};

	private func time_elapsed_since(start_time : Time) : Int {
		let now = Time.now();
		let difference = now - start_time;

		let differenceInMinutes = difference / (1_000_000_000 * 60);

		return differenceInMinutes;
	};

	private func has_duration_elapsed(start_time : Time, duration : Nat) : Bool {
		let timeElapsed = time_elapsed_since(start_time);

		return timeElapsed >= duration;
	};

	private func check_owner_terminated(last_login : Time, countdown : Nat) : Bool {
		let hasElapsed = has_duration_elapsed(last_login, countdown);

		if (hasElapsed) {
			return true;
		};

		return false;
	};

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

	public shared ({ caller }) func get_capsule(id : CapsuleId) : async Result.Result<Capsule, Err> {
		switch (Map.get(capsules, thash, id)) {
			case (?capsule) {
				let is_terminated : Bool = check_owner_terminated(capsule.last_login, capsule.countdown_minutes);
				let is_unlocked : Bool = has_duration_elapsed(capsule.locked_start, capsule.locked_minutes);

				// (Terminated) execute only if owner terminated
				if (capsule.kind == #Terminated and is_terminated == true) {
					switch (Map.get(capsules, thash, id)) {
						case (?capsule) {

							let capsule_updated : Capsule = {
								capsule with owner_is_terminated = true;
							};

							Map.set(capsules, thash, capsule.id, capsule_updated);

							return #ok(capsule_updated);
						};
						case (_) {};
					};
				};

				// (TimeEncrypt) execute only if time encrypted
				if (capsule.kind == #TimeEncrypt) {
					switch (Map.get(capsules, thash, id)) {
						case (?capsule) {
							return #ok(capsule);
						};
						case (_) {};
					};
				};

				// (Capsule) execute only if is_locked
				if (capsule.kind == #Capsule and is_unlocked == false) {
					switch (Map.get(capsules, thash, id)) {
						case (?capsule) {

							let capsule_updated : Capsule = {
								capsule with is_unlocked = false;
							};

							Map.set(capsules, thash, capsule.id, capsule_updated);

							let capsule_public : Capsule = {
								capsule with is_unlocked = false;
								files = [];
								authorized = [];
							};

							return #ok(capsule_public);
						};
						case (_) {};
					};
				};

				//TODO: add authorized to return
				if (Principal.equal(caller, capsule.owner)) {
					// update last login
					let capsule_updated : Capsule = {
						capsule with last_login = Time.now();
						locked_start = 0;
						locked_minutes = 0;
						is_unlocked = true;
					};

					Map.set(capsules, thash, capsule.id, capsule_updated);

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

	public shared ({ caller }) func create_capsule(id : CapsuleId, kind : Kind) : async Result.Result<Ok, Err> {
		if (kind == #TimeEncrypt) {
			let capsule : Capsule = {
				id = id;
				kind = kind;
				files = [];
				authorized = [];
				owner = caller;

				owner_is_terminated = false;
				countdown_minutes = 0;
				last_login = Time.now();

				is_unlocked = true;
				locked_minutes = 0;
				locked_start = 0;
			};

			ignore Map.put(capsules, thash, id, capsule);
			ignore Map.put(capsule_owner, phash, caller, id);

			return #ok(#CreatedCapsule(true));
		};

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
					kind = kind;
					files = [];
					authorized = [];
					owner = caller;

					owner_is_terminated = false;
					countdown_minutes = 4320;
					last_login = Time.now();

					is_unlocked = true;
					locked_minutes = 0;
					locked_start = 0;
				};

				ignore Map.put(capsules, thash, id, capsule);
				ignore Map.put(capsule_owner, phash, caller, id);

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
								locked_minutes = 0;
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

	public shared ({ caller }) func add_file_with_time(capsule_id : CapsuleId, asset_id : Asset_ID, minutes : Nat) : async Result.Result<Ok, Err> {
		switch (await FileStorage.get(asset_id)) {
			case (#err asset_err) {
				return #err(#AssetNotFound(true));
			};
			case (#ok asset) {
				switch (Map.get(capsules, thash, capsule_id)) {
					case (?capsule) {
						let file : Asset = {
							created = asset.created;
							content_type = asset.content_type;
							filename = asset.filename;
							locked_minutes = minutes;
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
			};
		};
	};

	public shared ({ caller }) func add_time(capsule_id : CapsuleId, minutes : Nat) : async Result.Result<Ok, Err> {
		if (Principal.isAnonymous(caller)) {
			return #err(#Anon(true));
		};

		switch (Map.get(capsules, thash, capsule_id)) {
			case (?capsule) {

				if (capsule.kind == #Terminated) {
					return #err(#WrongKind(true));
				};

				if (Principal.equal(capsule.owner, caller)) {
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

	public shared ({ caller }) func update_countdown(id : CapsuleId, minutes : Nat) : async Result.Result<Capsule, Err> {
		if (Principal.isAnonymous(caller)) {
			return #err(#Anon(true));
		};

		switch (Map.get(capsules, thash, id)) {
			case (?capsule) {

				if (capsule.kind == #Capsule) {
					return #err(#WrongKind(true));
				};

				if (Principal.equal(caller, capsule.owner)) {
					// update countdown minutes
					let capsule_updated : Capsule = {
						capsule with countdown_minutes = minutes;
					};

					ignore Map.put(capsules, thash, capsule.id, capsule_updated);

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

	public shared ({ caller }) func encrypted_symmetric_key_for_caller(encryption_public_key : Blob, id : CapsuleId) : async Result.Result<Text, ErrVetKD> {
		var principal_id : Principal = caller;

		switch (Map.get(capsules, thash, id)) {
			case (?capsule) {
				let is_terminated : Bool = check_owner_terminated(capsule.last_login, capsule.countdown_minutes);
				let is_unlocked : Bool = has_duration_elapsed(capsule.locked_start, capsule.locked_minutes);

				// (Terminated) execute only if owner terminated
				if (capsule.kind == #Terminated and is_terminated == true) {
					principal_id := capsule.owner;
				};

				// (Capsule) execute only if capsule locked
				if (capsule.kind == #Capsule and is_unlocked == false) {
					return #err(#Locked(true));
				};
			};
			case (_) {};
		};

		let { encrypted_key } = await vetkd_system_api.vetkd_encrypted_key({
			derivation_id = Principal.toBlob(principal_id);
			public_key_derivation_path = Array.make(Text.encodeUtf8("symmetric_key"));
			key_id = { curve = #bls12_381; name = "test_key_1" };
			encryption_public_key;
		});

		return #ok(Hex.encode(Blob.toArray(encrypted_key)));
	};

	// time encryption
	public shared func encrypted_symmetric_key_by_time(encryption_public_key : Blob, minutes : ?Nat) : async (Text, Blob) {
		var time : Time = round_to_nearest_ten_minutes(Time.now());

		switch (minutes) {
			case (null) {};
			case (?minutes) {
				time := round_to_nearest_ten_minutes(Time.now() + minutes_to_nanoseconds(minutes));
			};
		};

		let time_encoded : Blob = Text.encodeUtf8(debug_show (time));

		let { encrypted_key } = await vetkd_system_api.vetkd_encrypted_key({
			derivation_id = time_encoded;
			public_key_derivation_path = Array.make(Text.encodeUtf8("symmetric_key"));
			key_id = { curve = #bls12_381; name = "test_key_1" };
			encryption_public_key;
		});

		(Hex.encode(Blob.toArray(encrypted_key)), time_encoded);
	};
};
