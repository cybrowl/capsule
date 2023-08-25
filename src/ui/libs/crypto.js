import * as agent from '@dfinity/agent';
import * as vetkd from 'ic-vetkd-utils';

export class CryptoService {
	constructor(actor) {
		this.actor = actor;
		this.vetAesGcmKey = null;
	}

	async init() {
		const seed = window.crypto.getRandomValues(new Uint8Array(32));
		const tsk = new vetkd.TransportSecretKey(seed);

		console.log('tsk: ', tsk);

		const { ok: ek_bytes_hex, err: error } = await this.actor.encrypted_symmetric_key_for_caller(
			tsk.public_key()
		);

		if (error) {
			return error;
		}

		console.log('ek_bytes_hex: ', ek_bytes_hex);

		const pk_bytes_hex = await this.actor.symmetric_key_verification_key();
		const principal = await agent.Actor.agentOf(this.actor).getPrincipal();

		const aes_256_gcm_key_raw = tsk.decrypt_and_hash(
			hex_decode(ek_bytes_hex),
			hex_decode(pk_bytes_hex),
			principal.toUint8Array(),
			32,
			new TextEncoder().encode('aes-256-gcm')
		);

		console.log('aes_256_gcm_key_raw: ', aes_256_gcm_key_raw);

		this.vetAesGcmKey = await window.crypto.subtle.importKey(
			'raw',
			aes_256_gcm_key_raw,
			'AES-GCM',
			false,
			['encrypt', 'decrypt']
		);

		console.log('this.vetAesGcmKey: ', this.vetAesGcmKey);

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

		const data_encoded = Uint8Array.from([...data].map((ch) => ch.charCodeAt(0))).buffer;
		const iv = window.crypto.getRandomValues(new Uint8Array(12));

		const ciphertext = await window.crypto.subtle.encrypt(
			{
				name: 'AES-GCM',
				iv: iv
			},
			this.vetAesGcmKey,
			data_encoded
		);

		const iv_decoded = String.fromCharCode(...new Uint8Array(iv));
		const cipher_decoded = String.fromCharCode(...new Uint8Array(ciphertext));

		return iv_decoded + cipher_decoded;
	}

	async decrypt(data) {
		if (this.vetAesGcmKey === null) {
			throw new Error('null shared secret!');
		}

		if (data.length < 13) {
			throw new Error('wrong encoding, too short to contain iv');
		}

		const iv_decoded = data.slice(0, 12);
		const cipher_decoded = data.slice(12);

		const iv_encoded = Uint8Array.from([...iv_decoded].map((ch) => ch.charCodeAt(0))).buffer;
		const ciphertext_encoded = Uint8Array.from(
			[...cipher_decoded].map((ch) => ch.charCodeAt(0))
		).buffer;

		let decrypted_data_encoded = await window.crypto.subtle.decrypt(
			{
				name: 'AES-GCM',
				iv: iv_encoded
			},
			this.vetAesGcmKey,
			ciphertext_encoded
		);

		const decrypted_data_decoded = String.fromCharCode(...new Uint8Array(decrypted_data_encoded));

		return decrypted_data_decoded;
	}
}

const hex_decode = (hexString) =>
	Uint8Array.from(hexString.match(/.{1,2}/g).map((byte) => parseInt(byte, 16)));

// const hex_encode = (bytes) =>
//   bytes.reduce((str, byte) => str + byte.toString(16).padStart(2, "0"), "");
