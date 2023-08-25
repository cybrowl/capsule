<script lang="js">
	import init_vetkd_wasm from 'ic-vetkd-utils';
	import { CryptoService } from '../libs/crypto';
	import { actor_capsule } from '$stores_ref/actors';

	const init_service = async () => {
		const cryptoService = new CryptoService($actor_capsule.actor);

		console.log('cryptoService: ', await cryptoService.init());
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
