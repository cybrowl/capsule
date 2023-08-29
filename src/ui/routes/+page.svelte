<script>
	import { actor_capsule, actor_file_storage } from '$stores_ref/actors';
	import { auth_actors, login, crypto_service } from '$stores_ref/auth_client';
	import { get } from 'lodash';
	import { AssetManager } from '../libs/file_storage';

	let file_input_elem;

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
		login(true, handleAuth);
	}

	function handleCreateAccountClick() {
		// handle add card logic here
		alert('Add card button clicked!');
	}

	async function fetchFile(fileUrl) {
		// NOTE: some cors issue happening locally???
		return fetch(fileUrl)
			.then(async (response) => {
				const file_array_buffer = await response.arrayBuffer();

				return file_array_buffer;
			})
			.catch((error) => {
				console.error('Fetch error: ', error);
			});
	}

	function downloadFile(arrayBuffer, filename) {
		// Create a blob from the ArrayBuffer
		const blob = new Blob([arrayBuffer]);

		// Create a URL for the blob
		const url = window.URL.createObjectURL(blob);

		// Create a temporary anchor element
		const a = document.createElement('a');
		a.style.display = 'none';
		a.href = url;
		a.download = filename;

		// Append anchor to the body, click it, then remove it
		document.body.appendChild(a);
		a.click();
		document.body.removeChild(a);

		// Release the created URL
		setTimeout(function () {
			window.URL.revokeObjectURL(url);
		}, 100);
	}

	async function handleUploadClick(e) {
		let file_storage_lib = new AssetManager($actor_file_storage.actor, $crypto_service);
		await $crypto_service.init_caller();

		fetchFile(
			'https://pvbg6-liaaa-aaaag-abwha-cai.raw.icp0.io/asset/6acf708a-68b-05a-b6f-ea08b9762ac2'
		)
			.then(async (encrypted_file_buffer) => {
				//TODO: decrypt in chunks 2MB?
				const decrypted_data = await $crypto_service.decrypt(encrypted_file_buffer);

				downloadFile(decrypted_data, 'poro.jpeg');

				console.log('decrypted_data: ', decrypted_data);
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
			// await $crypto_service.init_pw('ocean');

			let version = await $actor_capsule.actor.version();
			const all_assets = await file_storage_lib.getAllAssets();

			console.log('version: ', version);
			console.log('all_assets: ', all_assets);

			// await file_storage_lib.store(file_array_buffer, {
			// 	content_type: file_type,
			// 	filename: file_name
			// });
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
