import test from 'tape';
import { config } from 'dotenv';
import { Ed25519KeyIdentity } from '@dfinity/identity';
import { capsule_canister_id, file_storage_canister_id } from './actor_canister_ids.mjs';
import { capsule_interface, file_storage_interface } from './actor_interface.mjs';
import { getActor } from './actor.mjs';
import { v4 as uuidv4 } from 'uuid';
import fs from 'node:fs';
import sleep from 'sleep-promise';

config();

// NOTE: encryption is not tested because too many dep on browser
// encryption testing is done in browser

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
let asset_id_x = '';
let chunk_ids = [];
let last_login = 0;

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

	test('FileStorage[random].create_chunk(): with 6MB IMG file #ok -> chunk_ids', async function (t) {
		const uploadChunk = async ({ chunk, order }) => {
			return file_storage_actor.random.create_chunk(chunk, order);
		};

		const file_path = 'tests/data/poked_2.jpeg';

		const asset_buffer = fs.readFileSync(file_path);

		const asset_unit8Array = new Uint8Array(asset_buffer);

		const promises = [];
		const chunkSize = 2000000;

		for (let start = 0, index = 0; start < asset_unit8Array.length; start += chunkSize, index++) {
			const chunk = asset_unit8Array.slice(start, start + chunkSize);

			promises.push(
				uploadChunk({
					chunk,
					order: index
				})
			);
		}

		chunk_ids = await Promise.all(promises);

		const hasChunkIds = chunk_ids.length > 2;

		t.equal(hasChunkIds, true);
	});

	test('FileStorage[random].commit_batch(): with 6MB IMG file #ok -> asset_id', async function (t) {
		const asset_filename = 'poked_2.jpeg';
		const asset_content_type = 'image/jpeg';
		const options = {
			filename: asset_filename,
			content_encoding: { Identity: null },
			content_type: asset_content_type
		};

		const ids_sorted = chunk_ids.sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));

		const { ok: asset_id, err: error } = await file_storage_actor.random.commit_batch(
			ids_sorted,
			options
		);

		asset_id_x = asset_id;

		const { ok: asset } = await file_storage_actor.random.get(asset_id);

		t.equal(error, undefined);
		t.equal(asset.filename, 'poked_2.jpeg');
		t.equal(asset.content_type, 'image/jpeg');
	});

	test('Capsule[random].check_capsule_exists(): with invalid id => #err - false', async function (t) {
		let capsule_id = uuidv4();
		let exists = await capsule_actor.random.check_capsule_exists(capsule_id);

		t.equal(exists, false);
	});

	test('Capsule[random].create_capsule(): with valid id => #ok - CreatedCapsule', async function (t) {
		let capsule_id = uuidv4();
		capsule_x = capsule_id;

		let kind = {
			Terminated: null
		};

		const { ok: created, err: err_creating } = await capsule_actor.random.create_capsule(
			capsule_id,
			kind
		);

		t.deepEqual(created, { CreatedCapsule: true });
		t.equal(err_creating, undefined);
	});

	test('Capsule[random].create_capsule(): with taken id => #ok - CapsuleExists', async function (t) {
		let kind = {
			Terminated: null
		};

		const { ok: created, err: err_creating } = await capsule_actor.random.create_capsule(
			capsule_x,
			kind
		);

		t.deepEqual(err_creating, { CapsuleExists: true });
		t.equal(created, undefined);
	});

	test('Capsule[random].check_capsule_exists(): => #ok - CapsuleExists', async function (t) {
		let exists = await capsule_actor.random.check_capsule_exists(capsule_x);

		t.equal(exists, true);
	});

	test('Capsule[random].get_capsule(): with valid id => #ok - capsule', async function (t) {
		const { ok: capsule, err: err_capsule } = await capsule_actor.random.get_capsule(capsule_x);

		t.ok(capsule.id, 'Capsule should have an ID');

		t.deepEqual(capsule.files, [], 'Capsule files should be an empty array');

		t.deepEqual(capsule.authorized, [], 'Capsule authorized should be an empty array');

		t.equal(capsule.locked_start, 0n, 'Capsule locked_start should be 0n');
		t.equal(capsule.locked_minutes, 0n, 'Capsule locked_minutes should be 0n');

		t.equal(err_capsule, undefined, 'There should be no error while fetching the capsule');
	});

	test('Capsule[random].add_file(): with valid asset and capsule => #ok - AddedFile', async function (t) {
		const { ok: added_file, err: err_adding } = await capsule_actor.random.add_file(
			capsule_x,
			asset_id_x
		);

		t.deepEqual(added_file, { AddedFile: true }, 'The file should be successfully added');

		t.equal(err_adding, undefined, 'There should be no error while adding the file');
	});

	test('Capsule[random].get_capsule(): with valid id => #ok - capsule', async function (t) {
		const { ok: capsule, err: err_capsule } = await capsule_actor.random.get_capsule(capsule_x);

		t.equal(err_capsule, undefined, 'There should be no error while getting the capsule');

		t.ok(capsule.id, 'Capsule should have an ID');

		t.deepEqual(capsule.files.length, 1, 'Capsule should contain exactly one file');
		t.equal(
			capsule.files[0].content_type,
			'image/jpeg',
			"File content type should be 'image/jpeg'"
		);
		t.equal(capsule.files[0].filename, 'poked_2.jpeg', "File filename should be 'poked_2.jpeg'");
		t.deepEqual(capsule.authorized, [], 'Capsule authorized should be an empty array');
		t.equal(capsule.locked_start, 0n, 'Capsule locked_start should be 0n');
		t.equal(capsule.locked_minutes, 0n, 'Capsule locked_minutes should be 0n');
	});

	test('Capsule[random].add_time(): with capsule id and minutes => #ok - AddedTime', async function (t) {
		let minutes = 60;

		const { ok: added_time, err: err_adding } = await capsule_actor.random.add_time(
			capsule_x,
			minutes
		);

		t.deepEqual(added_time, { AddedTime: true }, 'The time should be successfully added');

		t.equal(err_adding, undefined, 'There should be no error while adding the file');
	});

	test('Capsule[random].get_capsule(): with valid id => #ok - capsule', async function (t) {
		const { ok: capsule, err: err_capsule } = await capsule_actor.random.get_capsule(capsule_x);

		last_login = capsule.last_login;

		t.equal(err_capsule, undefined, 'There should be no error while getting the capsule');

		t.ok(capsule.id, 'Capsule should have an ID');

		t.ok(
			capsule.locked_start.toString().length > 7,
			'The string representation of capsule.locked_start should have a length greater than 7'
		);
		t.equal(capsule.locked_minutes, 60n, 'Capsule locked_minutes should be 60n');
	});

	test('Capsule[random].update_countdown(): with 1 min => #ok - capsule', async function (t) {
		let minutes = 1;

		const { ok: capsule_updated, err: err_capsule_updated } =
			await capsule_actor.random.update_countdown(capsule_x, minutes);

		t.ok(
			capsule_updated.countdown_minutes.toString().length === 1,
			'The string representation of capsule_updated.countdown_minutes should equal 1'
		);

		t.equal(err_capsule_updated, undefined, 'There should be no error while adding the file');
	});

	test('Capsule[random].get_capsule(): with valid id => #ok - capsule', async function (t) {
		const { ok: capsule, err: err_capsule } = await capsule_actor.random.get_capsule(capsule_x);

		t.notEqual(capsule.last_login, last_login);

		t.equal(err_capsule, undefined, 'There should be no error while getting the capsule');

		t.ok(capsule.id, 'Capsule should have an ID');

		t.ok(
			capsule.countdown_minutes.toString().length === 1,
			'The string representation of capsule.countdown_minutes should equal 1'
		);
		t.equal(capsule.locked_minutes, 60n, 'Capsule locked_minutes should be 60n');
	});

	test('Capsule[satoshi].get_capsule(): with invalid principal => #err - NotOwner', async function (t) {
		const { ok: capsule, err: err_capsule } = await capsule_actor.satoshi.get_capsule(capsule_x);

		t.equal(capsule, undefined, 'There should be no capsule');

		t.deepEqual(err_capsule, { NotOwner: true });
	});

	test('Waiting 2 minutes for is_terminated to be true ', async function (t) {
		await sleep(120000);
	});

	test('Capsule[satoshi].get_capsule(): with invalid principal => #err - NotOwner', async function (t) {
		const { ok: capsule, err: err_capsule } = await capsule_actor.satoshi.get_capsule(capsule_x);

		t.equal(err_capsule, undefined, 'There should be no error while getting the capsule');

		t.ok(capsule.id, 'Capsule should have an ID');

		t.deepEqual(capsule.files.length, 1, 'Capsule should contain exactly one file');
		t.equal(
			capsule.files[0].content_type,
			'image/jpeg',
			"File content type should be 'image/jpeg'"
		);
		t.equal(capsule.files[0].filename, 'poked_2.jpeg', "File filename should be 'poked_2.jpeg'");
		t.deepEqual(capsule.authorized, [], 'Capsule authorized should be an empty array');
		t.equal(capsule.owner_is_terminated, true, "Bye Bye'");
	});
});
