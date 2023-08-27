<script lang="js">
	import { AuthClient } from '@dfinity/auth-client';
	import { onMount } from 'svelte';

	import init_vetkd_wasm from 'ic-vetkd-utils';
	import { CryptoService } from '../libs/crypto';

	import { actor_capsule } from '$stores_ref/actors';
	import { auth_client } from '$stores_ref/auth_client';

	onMount(async () => {});

	const init_service = async () => {
		const authClient = await AuthClient.create({
			idleOptions: {
				idleTimeout: 1000 * 60 * 60 * 24 * 30,
				disableDefaultIdleCallback: true
			}
		});

		auth_client.set(authClient);
		console.log('authClient 1: ', authClient);

		const super_secret_string = 'dogecoin is my safe word';

		const cryptoService = new CryptoService($actor_capsule.actor);
		await cryptoService.init_pw('ocean');

		const encrypted_msg = await cryptoService.encrypt(super_secret_string);
		const dencrypted_msg = await cryptoService.decrypt(encrypted_msg);

		console.log('encrypted_msg: ', encrypted_msg);
		console.log('dencrypted_msg: ', dencrypted_msg);
	};

	const init = async () => {
		try {
			await init_vetkd_wasm();
			console.log('WebAssembly module initialized.');

			init_service();
		} catch (error) {
			console.error('Error initializing WebAssembly module:', error);
		}
	};

	init();
</script>

<slot />

<style lang="postcss">
	@import '../app.css';
</style>
