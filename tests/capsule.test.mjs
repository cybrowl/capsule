import test from 'tape';
import { config } from 'dotenv';
import { Ed25519KeyIdentity } from '@dfinity/identity';
import { capsule_canister_id, file_storage_canister_id } from './actor_canister_ids.mjs';
import { capsule_interface, file_storage_interface } from './actor_interface.mjs';
import { getActor } from './actor.mjs';
import { v4 as uuidv4 } from 'uuid';

config();

// NOTE: encryption is not tested because too many dep on browser
// Testing is done in browser

const parseIdentity = (privateKeyHex) => {
	const privateKey = Uint8Array.from(Buffer.from(privateKeyHex, 'hex'));

	// Initialize an identity from the secret key
	return Ed25519KeyIdentity.fromSecretKey(privateKey);
};

let motoko_identity = parseIdentity(process.env.MOTOKO_IDENTITY);
let zooko_identity = parseIdentity(process.env.ZOOKO_IDENTITY);
let satoshi_identity = parseIdentity(process.env.SATOSHI_IDENTITY);
let random_identity = Ed25519KeyIdentity.generate();

let capsule_actor = {};
let file_storage_actor = {};

let capsule_x = '';

test('Setup Actors', async function () {
	console.log('=========== Capsule ===========');

	capsule_actor.motoko = await getActor(capsule_canister_id, capsule_interface, motoko_identity);
	capsule_actor.zooko = await getActor(capsule_canister_id, capsule_interface, zooko_identity);
	capsule_actor.satoshi = await getActor(capsule_canister_id, capsule_interface, satoshi_identity);
	capsule_actor.random = await getActor(capsule_canister_id, capsule_interface, random_identity);

	file_storage_actor.random = await getActor(
		file_storage_canister_id,
		file_storage_interface,
		random_identity
	);

	test('Capsule.version(): get version => #ok - version num', async function (t) {
		const version_m = await capsule_actor.motoko.version();
		const version_z = await capsule_actor.zooko.version();
		const version_s = await capsule_actor.satoshi.version();
		const version_r = await capsule_actor.random.version();

		t.equal(version_m, 1n);
		t.equal(version_z, 1n);
		t.equal(version_s, 1n);
		t.equal(version_r, 1n);
	});

	test('FileStorage.version(): get version => #ok - version num', async function (t) {
		const version_r = await file_storage_actor.random.version();

		t.equal(version_r, 4n);
	});

	test('Capsule[random].check_capsule_exists(): with invalid id => #err - false', async function (t) {
		let capsule_id = uuidv4();
		let exists = await capsule_actor.random.check_capsule_exists(capsule_id);

		t.equal(exists, false);
	});

	test('Capsule[random].create_capsule(): with valid id => #ok - CreatedCapsule', async function (t) {
		let capsule_id = uuidv4();
		capsule_x = capsule_id;

		const { ok: created, err: err_creating } = await capsule_actor.random.create_capsule(
			capsule_id
		);

		t.deepEqual(created, { CreatedCapsule: true });
		t.equal(err_creating, undefined);
	});

	test('Capsule[random].create_capsule(): with taken id => #ok - CapsuleExists', async function (t) {
		const { ok: created, err: err_creating } = await capsule_actor.random.create_capsule(capsule_x);

		t.deepEqual(err_creating, { CapsuleExists: true });
		t.equal(created, undefined);
	});

	test('Capsule[random].check_capsule_exists(): => #ok - CapsuleExists', async function (t) {
		let exists = await capsule_actor.random.check_capsule_exists(capsule_x);

		t.equal(exists, true);
	});

	test('Capsule[random].get_capsule(): with valid id => #ok - capsule', async function (t) {
		const { ok: capsule, err: err_creating } = await capsule_actor.random.get_capsule(capsule_x);

		console.log('capsule: ', capsule);
	});
});
