import * as agent from '@dfinity/agent';
import * as vetkd from 'ic-vetkd-utils';

export class CryptoService {
	constructor(actor) {
		this.actor = actor;
		this.vetAesGcmKey = null;
	}

	async init_caller() {
		const seed = window.crypto.getRandomValues(new Uint8Array(32));
		const tsk = new vetkd.TransportSecretKey(seed);

		const { ok: ek_bytes_hex, err: error } = await this.actor.encrypted_symmetric_key_for_caller(
			tsk.public_key()
		);

		if (error) {
			console.log('error: ', error);

			return error;
		}

		const pk_bytes_hex = await this.actor.symmetric_key_verification_key();
		const principal = await agent.Actor.agentOf(this.actor).getPrincipal();

		const aes_256_gcm_key_raw = tsk.decrypt_and_hash(
			hex_decode(ek_bytes_hex),
			hex_decode(pk_bytes_hex),
			principal.toUint8Array(),
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

		let data_encoded;

		if (typeof data === 'string') {
			data_encoded = new TextEncoder().encode(data);
		} else if (data instanceof ArrayBuffer) {
			data_encoded = data;
		} else {
			throw new Error('Invalid data type for encryption. Expected string or ArrayBuffer.');
		}

		const iv = window.crypto.getRandomValues(new Uint8Array(12));

		const ciphertext = await window.crypto.subtle.encrypt(
			{
				name: 'AES-GCM',
				iv: iv
			},
			this.vetAesGcmKey,
			data_encoded
		);

		const iv_base64 = this.arrayBufferToBase64(iv);
		const cipher_base64 = this.arrayBufferToBase64(ciphertext);

		return iv_base64 + cipher_base64;
	}

	async decrypt(data) {
		if (this.vetAesGcmKey === null) {
			throw new Error('null shared secret!');
		}

		const iv_base64 = data.slice(0, 16);
		const cipher_base64 = data.slice(16);

		const iv_encoded = this.base64ToBuffer(iv_base64);
		const ciphertext_encoded = this.base64ToBuffer(cipher_base64);

		const decrypted_data_encoded = await window.crypto.subtle.decrypt(
			{
				name: 'AES-GCM',
				iv: iv_encoded
			},
			this.vetAesGcmKey,
			ciphertext_encoded
		);

		return decrypted_data_encoded;
	}

	arrayBufferToBase64(buffer) {
		let binary = '';
		const bytes = new Uint8Array(buffer);
		for (let i = 0; i < bytes.byteLength; i++) {
			binary += String.fromCharCode(bytes[i]);
		}
		return btoa(binary);
	}

	base64ToBuffer(base64) {
		const binStr = atob(base64);
		const len = binStr.length;
		const bytes = new Uint8Array(len);
		for (let i = 0; i < len; i++) {
			bytes[i] = binStr.charCodeAt(i);
		}
		return bytes.buffer;
	}
}

const hex_decode = (hexString) =>
	Uint8Array.from(hexString.match(/.{1,2}/g).map((byte) => parseInt(byte, 16)));

// const hex_encode = (bytes) =>
//   bytes.reduce((str, byte) => str + byte.toString(16).padStart(2, "0"), "");
