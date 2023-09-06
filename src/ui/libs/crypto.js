import * as agent from '@dfinity/agent';
import * as vetkd from 'ic-vetkd-utils';

export class CryptoService {
	constructor(actor) {
		this.actor = actor;
		this.vetAesGcmKey = null;
	}

	async init_caller(capsule_id, owner_principal) {
		if (capsule_id === undefined || owner_principal === undefined) {
			throw new Error('capsule_id and owner_principal must be defined');
		}

		const seed = window.crypto.getRandomValues(new Uint8Array(32));
		const tsk = new vetkd.TransportSecretKey(seed);

		const { ok: ek_bytes_hex, err: error } = await this.actor.encrypted_symmetric_key_for_caller(
			tsk.public_key(),
			capsule_id
		);

		if (error) {
			console.log('error: ', error);

			return error;
		}

		const pk_bytes_hex = await this.actor.symmetric_key_verification_key();

		const aes_256_gcm_key_raw = tsk.decrypt_and_hash(
			hex_decode(ek_bytes_hex),
			hex_decode(pk_bytes_hex),
			owner_principal,
			32,
			new TextEncoder().encode('aes-256-gcm')
		);

		this.vetAesGcmKey = await window.crypto.subtle.importKey(
			'raw',
			aes_256_gcm_key_raw,
			'AES-GCM',
			false,
			['encrypt', 'decrypt']
		);

		return 'key created';
	}

	async init_pw(password) {
		const seed = window.crypto.getRandomValues(new Uint8Array(32));
		const tsk = new vetkd.TransportSecretKey(seed);

		if (password === undefined) {
			throw new Error('null password!');
		}

		const ek_bytes_hex = await this.actor.encrypted_symmetric_key_by_pass(
			password,
			tsk.public_key()
		);

		const pk_bytes_hex = await this.actor.symmetric_key_verification_key();

		const aes_256_gcm_key_raw = tsk.decrypt_and_hash(
			hex_decode(ek_bytes_hex),
			hex_decode(pk_bytes_hex),
			new TextEncoder().encode(password),
			32,
			new TextEncoder().encode('aes-256-gcm')
		);

		this.vetAesGcmKey = await window.crypto.subtle.importKey(
			'raw',
			aes_256_gcm_key_raw,
			'AES-GCM',
			false,
			['encrypt', 'decrypt']
		);

		return 'key created';
	}

	logout() {
		this.vetAesGcmKey = null;
	}

	isInitialized() {
		return this.vetAesGcmKey !== null;
	}

	async encrypt(data) {
		if (this.vetAesGcmKey === null) {
			throw new Error('null shared secret!');
		}

		const iv = window.crypto.getRandomValues(new Uint8Array(12));

		try {
			const ciphertext = await window.crypto.subtle.encrypt(
				{
					name: 'AES-GCM',
					iv: iv
				},
				this.vetAesGcmKey,
				data
			);

			return this.concatArrayBuffers(iv, ciphertext);
		} catch (error) {
			console.log('CryptoService.encrypt Err: ', error);
		}
	}

	async decrypt(data) {
		if (this.vetAesGcmKey === null) {
			throw new Error('null shared secret!');
		}

		const iv = data.slice(0, 12);
		const ciphertext = data.slice(12);

		try {
			const decrypted_data = await window.crypto.subtle.decrypt(
				{
					name: 'AES-GCM',
					iv: iv
				},
				this.vetAesGcmKey,
				ciphertext
			);

			return decrypted_data;
		} catch (error) {
			console.log('CryptoService.decrypt Err: ', error);
		}
	}

	concatArrayBuffers(buffer1, buffer2) {
		const tmp = new Uint8Array(buffer1.byteLength + buffer2.byteLength);
		tmp.set(new Uint8Array(buffer1), 0);
		tmp.set(new Uint8Array(buffer2), buffer1.byteLength);
		return tmp.buffer;
	}
}

const hex_decode = (hexString) =>
	Uint8Array.from(hexString.match(/.{1,2}/g).map((byte) => parseInt(byte, 16)));

// const hex_encode = (bytes) =>
//   bytes.reduce((str, byte) => str + byte.toString(16).padStart(2, "0"), "");
