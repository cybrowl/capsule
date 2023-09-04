<script>
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { actor_capsule, actor_file_storage } from '$stores_ref/actors';
	import { auth_actors, login, crypto_service, init_auth } from '$stores_ref/auth_client';
	import { get } from 'lodash';
	import { AssetManager } from '../../libs/file_storage';
	import { CryptoService } from '../../libs/crypto';
	import init_vetkd_wasm from 'ic-vetkd-utils';
	import JellyFish from '../loading/JellyFish.svelte';

	let file_input_elem;

	let capsule_id = '';
	let files = [];
	let is_loading = false;
	let is_loading_msg = '';

	onMount(async () => {
		is_loading = true;
		is_loading_msg = 'Setting Up Encryption';

		await init_auth();

		await auth_actors.capsule();
		await auth_actors.file_storage();

		await init_vetkd_wasm();

		const cryptoService = new CryptoService($actor_capsule.actor);
		crypto_service.set(cryptoService);

		await cryptoService.init_caller();

		// NOTE: Another way of doing encryption based on password
		// await $crypto_service.init_pw('ocean');

		capsule_id = $page.params.capsule_id;

		if ($actor_capsule.loggedIn === true) {
			let exists = await $actor_capsule.actor.check_capsule_exists(capsule_id);

			if (exists === false) {
				let { ok: created, err: error } = await $actor_capsule.actor.create_capsule(capsule_id);
			}

			let { ok: capsule } = await $actor_capsule.actor.get_capsule(capsule_id);

			files = capsule.files;

			is_loading = false;
			is_loading_msg = '';
		}
	});

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

	async function decryptInChunks(encryptedBuffer) {
		const CHUNK_SIZE = 2000000;
		const ENCRYPTED_CHUNK_SIZE = CHUNK_SIZE + 28;

		const decryptedChunks = [];
		const numChunks = Math.ceil(encryptedBuffer.byteLength / ENCRYPTED_CHUNK_SIZE);

		for (let i = 0; i < numChunks; i++) {
			const startByte = i * ENCRYPTED_CHUNK_SIZE;
			const endByte = Math.min(encryptedBuffer.byteLength, startByte + ENCRYPTED_CHUNK_SIZE);
			const chunk = encryptedBuffer.slice(startByte, endByte);

			const decryptedChunk = await $crypto_service.decrypt(chunk);

			decryptedChunks.push(decryptedChunk);
		}

		// Combine decrypted chunks into a single buffer
		let totalSize = decryptedChunks.reduce((acc, chunk) => acc + chunk.byteLength, 0);
		let combined = new Uint8Array(totalSize);
		let position = 0;
		for (let chunk of decryptedChunks) {
			combined.set(new Uint8Array(chunk), position);
			position += chunk.byteLength;
		}

		return combined.buffer;
	}

	function decryptAndDownloadFile(url, filename) {
		is_loading = true;
		is_loading_msg = 'Decrypting File and Saving...';

		fetchFile(url)
			.then(async (encrypted_file_buffer) => {
				const decrypted_data = await decryptInChunks(encrypted_file_buffer);
				downloadFile(decrypted_data, filename);

				is_loading = false;
				is_loading_msg = '';
			})
			.catch((error) => {
				is_loading = false;
				is_loading_msg = '';

				console.error('Error:', error);
			});
	}

	async function handleUploadClick(e) {
		let file_storage_lib = new AssetManager($actor_file_storage.actor, $crypto_service);

		is_loading = true;
		is_loading_msg = 'Encrypting File and Storing...';

		const file = e.target.files[0];
		const file_name = get(file, 'name', '');
		const file_type = get(file, 'type', '');
		const file_array_buffer = await file.arrayBuffer();

		e.target.value = '';

		if ($actor_capsule.loggedIn) {
			const { ok: asset_id, err: error_store } = await file_storage_lib.store(file_array_buffer, {
				content_type: file_type,
				filename: file_name
			});

			const { ok: added_file, err: err_adding_file } = await $actor_capsule.actor.add_file(
				capsule_id,
				asset_id
			);

			let { ok: capsule } = await $actor_capsule.actor.get_capsule(capsule_id);

			files = capsule.files;
			is_loading = false;
			is_loading_msg = '';
		}
	}
</script>

<svelte:head>
	<title>Capsule</title>
</svelte:head>

<main class="grid grid-cols-12 h-screen">
	<!-- Left column with the image -->
	<div class="col-span-4 relative">
		<img src="header.jpg" alt="Description" class="absolute inset-0 w-full h-full object-cover" />
	</div>
	<div class="col-span-8 grid grid-rows-5">
		<!-- 6 columns content for the right side -->
		<div class="row-span-2 bg-gray-800 relative">
			<button
				class="absolute top-4 right-4 bg-zinc-900 hover:bg-zinc-700 text-white font-bold py-2 px-4 rounded"
				on:click={handleCreateAccountClick}
			>
				Create Account
			</button>
		</div>
		{#if $actor_capsule.loggedIn === false}
			<div class="row-span-3 bg-gray-950 flex justify-center items-center">
				<button
					class="bg-zinc-300 hover:bg-stone-100 text-violet-500 font-bold py-2 px-4 rounded"
					on:click={handleLoginClick}
				>
					Login
				</button>
			</div>
		{/if}

		{#if is_loading === true && $actor_capsule.loggedIn}
			<div class="row-span-3 bg-gray-950 flex justify-center items-center flex-col">
				<JellyFish />
				<p class="text-white mt-4">{is_loading_msg}</p>
			</div>
		{/if}

		{#if is_loading === false && $actor_capsule.loggedIn}
			<div class="row-span-3 bg-gray-950 relative">
				<div class="overflow-auto max-h-[60vh]">
					<div class="actions p-4">
						<button
							class="bg-zinc-900 hover:bg-zinc-700 text-white font-bold py-2 px-4 rounded"
							on:click={triggerFileSelectionBrowser}
						>
							Upload
						</button>
					</div>

					<table class="min-w-full text-white">
						<thead>
							<tr>
								<th class="py-2 px-4 border-b border-zinc-900 text-left">Filename</th>
								<th class="py-2 px-4 border-b border-zinc-900 text-left">Created</th>
								<th class="py-2 px-4 border-b border-zinc-900 text-left">Content Type</th>
							</tr>
						</thead>
						<tbody>
							{#each files as { filename, created, content_type, url }}
								<tr>
									<td class="py-2 px-4 border-b border-zinc-900">{filename}</td>
									<td class="py-2 px-4 border-b border-zinc-900">{created}</td>
									<td class="py-2 px-4 border-b border-zinc-900">{content_type}</td>
									<td class="py-2 px-4 border-b border-zinc-900">
										<button
											class="bg-zinc-900 hover:bg-zinc-700 text-white font-bold py-2 px-4 rounded"
											on:click={() => decryptAndDownloadFile(url, filename)}
										>
											Download
										</button>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
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
