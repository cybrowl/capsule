<script lang="js">
	import init_vetkd_wasm from 'ic-vetkd-utils';
	import { CryptoService } from '../libs/crypto';
	import { actor_capsule } from '$stores_ref/actors';

	const init_service = async () => {
		const super_secret_string = 'dogecoin is my safe word';

		const cryptoService = new CryptoService($actor_capsule.actor);
		await cryptoService.init();

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
