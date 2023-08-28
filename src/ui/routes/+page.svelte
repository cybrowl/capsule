<script>
	import { actor_capsule, actor_file_storage } from '$stores_ref/actors';
	import { auth_actors, login, crypto_service } from '$stores_ref/auth_client';
	import { get } from 'lodash';
	import { AssetManager } from '../libs/file_storage';

	let file_input_elem;
	let is_uploading_design_file = false;

	function triggerFileSelectionBrowser(e) {
		file_input_elem.click();
	}

	async function handleAuth() {
		await auth_actors.capsule();

		try {
			if ($actor_capsule.loggedIn) {
				let version = await $actor_capsule.actor.version();

				console.log('version: ', version);

				window.location.reload();
			}
		} catch (error) {}
	}

	function handleLoginClick() {
		login(false, handleAuth);
	}

	function handleCreateAccountClick() {
		// handle add card logic here
		alert('Add card button clicked!');
	}

	async function downloadFileAndConvertToBase64(fileUrl) {
		// NOTE: some cors issue happening locally???
		return fetch(fileUrl)
			.then(async (response) => {
				console.log('response: ', response);
				const arrayBuffer = await response.arrayBuffer();
				const uint8Array = new Uint8Array(arrayBuffer);
				const base64 = arrayBufferToBase64(uint8Array);

				return base64;
			})
			.catch((error) => {
				console.error('Fetch error: ', error);
			});
	}

	function arrayBufferToBase64(buffer) {
		let binary = '';
		const bytes = new Uint8Array(buffer);
		const len = bytes.byteLength;
		for (let i = 0; i < len; i++) {
			binary += String.fromCharCode(bytes[i]);
		}
		return window.btoa(binary);
	}

	async function handleUploadClick(e) {
		let file_storage_lib = new AssetManager($actor_file_storage.actor, $crypto_service);

		downloadFileAndConvertToBase64(
			'https://ifw4i-haaaa-aaaag-abrja-cai.raw.icp0.io/asset/c9c594c9-5b4-a24-6c3-810e272d4a15'
		)
			.then((base64) => {
				console.log('Base64 encoded file:', base64);
			})
			.catch((error) => {
				console.error('Error:', error);
			});

		const file = e.target.files[0];

		const file_name = get(file, 'name', '');
		const file_type = get(file, 'type', '');
		const file_array_buffer = await file.arrayBuffer();

		e.target.value = '';

		if ($actor_capsule.loggedIn) {
			// Get encrypted key
			await $crypto_service.init_caller();
			// await $crypto_service.init_pw('ocean');

			let version = await $actor_capsule.actor.version();
			const all_assets = await file_storage_lib.getAllAssets();

			console.log('version: ', version);
			console.log('all_assets: ', all_assets);

			// await file_storage_lib.store(file_array_buffer, {
			// 	content_type: file_type,
			// 	filename: file_name
			// });

			// await $actor_capsule.actor.save_msg(encrypted_data);

			// const response = await $actor_capsule.actor.get_msg();

			// console.log('response: ', response);

			// const decrypted_data = await $crypto_service.decrypt(response);

			// downloadDecryptedFile(decrypted_data, 'yoda.jpeg', 'image/jpeg');
		}
	}
</script>

<svelte:head>
	<title>Capsule</title>
</svelte:head>

<main class="grid grid-cols-12 h-screen">
	<!-- Left column with the image -->
	<div class="col-span-6 relative">
		<img src="fish_bg.jpeg" alt="Description" class="absolute inset-0 w-full h-full object-cover" />
	</div>
	<div class="col-span-6 grid grid-rows-2">
		<!-- 6 columns content for the right side -->
		<div class="row-span-1 bg-gray-800 relative">
			<button
				class="absolute top-4 right-4 bg-zinc-900 hover:bg-zinc-700 text-white font-bold py-2 px-4 rounded"
				on:click={handleCreateAccountClick}
			>
				Create Account
			</button>
		</div>
		{#if $actor_capsule.loggedIn === false}
			<div class="row-span-1 bg-gray-950 flex justify-center items-center">
				<button
					class="bg-zinc-300 hover:bg-stone-100 text-violet-500 font-bold py-2 px-4 rounded"
					on:click={handleLoginClick}
				>
					Login
				</button>
			</div>
		{/if}

		{#if $actor_capsule.loggedIn}
			<div class="row-span-1 bg-gray-950 relative">
				<button
					class="absolute top-4 right-4 bg-zinc-900 hover:bg-zinc-700 text-white font-bold py-2 px-4 rounded"
					on:click={triggerFileSelectionBrowser}
				>
					Upload
				</button>
			</div>
		{/if}
	</div>

	<input
		class="invisible w-0 h-0 absolute"
		type="file"
		on:change={(e) => handleUploadClick(e)}
		bind:this={file_input_elem}
	/>
</main>

<style lang="postcss">
</style>
