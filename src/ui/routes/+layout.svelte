<script lang="js">
	import { onMount } from 'svelte';

	import init_vetkd_wasm from 'ic-vetkd-utils';
	import { CryptoService } from '../libs/crypto';

	import { actor_capsule } from '$stores_ref/actors';
	import { auth_actors, crypto_service } from '$stores_ref/auth_client';

	onMount(async () => {});

	const init_service = async () => {
		await auth_actors.capsule();
		await auth_actors.file_storage();

		const cryptoService = new CryptoService($actor_capsule.actor);
		crypto_service.set(cryptoService);
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
