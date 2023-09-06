<script>
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { actor_capsule, actor_file_storage } from '$stores_ref/actors';
	import { auth_actors, login, crypto_service, init_auth } from '$stores_ref/auth_client';
	import { get } from 'lodash';
	import { DateTime } from 'luxon';

	import { AssetManager } from '../../libs/file_storage';
	import { CryptoService } from '../../libs/crypto';
	import init_vetkd_wasm from 'ic-vetkd-utils';

	import JellyFish from '../../components/JellyFish.svelte';
	import Icon from '../../components/Icon.svelte';

	let file_input_elem;

	let capsule_id = '';
	let capsule_ref = {};
	let has_capsule = false;

	let files = [];

	let is_loading = false;
	let is_loading_msg = '';

	let views = {
		home_selected: true,
		time_selected: false,
		settings_selected: false
	};

	const views_deselect = {
		home_selected: false,
		time_selected: false,
		settings_selected: false
	};

	onMount(async () => {
		is_loading = true;
		is_loading_msg = 'Setting Up Encryption';

		capsule_id = $page.params.capsule_id;

		await init_auth();

		await auth_actors.capsule();
		await auth_actors.file_storage();

		await init_vetkd_wasm();

		// get owner principal
		let { ok: capsule, err: error } = await $actor_capsule.actor.get_capsule(capsule_id);

		// if capsule doesn't exist, then return
		if (error && error.CapsuleNotFound) {
			is_loading = false;
			is_loading_msg = '';

			return null;
		}

		if (capsule) {
			has_capsule = true;
			capsule_ref = capsule;

			console.group('%cCapsule Information', 'color: blue; font-weight: bold;');
			console.log('%cCapsule:', 'color: green;', capsule);
			console.groupEnd();

			const owner_principal = capsule.owner._arr;

			const cryptoService = new CryptoService($actor_capsule.actor);
			crypto_service.set(cryptoService);

			await cryptoService.init_caller(capsule.id, owner_principal);

			// NOTE: Another way of doing encryption based on password
			// await $crypto_service.init_pw('ocean');

			if ($actor_capsule.loggedIn === true) {
				let { ok: capsule } = await $actor_capsule.actor.get_capsule(capsule_id);

				files = capsule.files;

				is_loading = false;
				is_loading_msg = '';
			}
		}
	});

	function triggerFileSelectionBrowser(e) {
		file_input_elem.click();
	}

	async function handleAuth() {
		await auth_actors.capsule();

		try {
			if ($actor_capsule.loggedIn) {
				window.location.reload();
			}
		} catch (error) {
			console.log('handleAuth - error: ', error);
		}
	}

	async function handleAccountCreation(kind) {
		is_loading = true;
		is_loading_msg = 'Creating Account';

		if ($actor_capsule.loggedIn === true) {
			let exists = await $actor_capsule.actor.check_capsule_exists(capsule_id);

			if (exists === false) {
				let { ok: created, err: error } = await $actor_capsule.actor.create_capsule(capsule_id, {
					[kind]: null
				});

				window.location.reload();
			}
		}

		is_loading = false;
		is_loading_msg = '';
	}

	function handleLoginClick() {
		login(true, handleAuth);
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
		<img src="header.jpeg" alt="Description" class="absolute inset-0 w-full h-full object-cover" />
	</div>

	<!-- Right column with the files table -->
	<div class="col-span-8 grid grid-rows-5 bg-gray-950">
		<!-- Login Screen -->
		{#if $actor_capsule.loggedIn === false}
			<div class="row-span-5 flex justify-center items-center">
				<button
					class="bg-zinc-300 hover:bg-stone-100 text-violet-500 font-bold py-4 px-6 rounded"
					on:click={handleLoginClick}
				>
					Identity Login
				</button>
			</div>
		{/if}

		<!-- Loading Screen -->
		{#if is_loading === true && $actor_capsule.loggedIn}
			<div class="row-span-5 bg-gray-950 flex justify-center items-center flex-col">
				<JellyFish />
				<p class="text-white mt-4">{is_loading_msg}</p>
			</div>
		{/if}

		{#if is_loading === false && $actor_capsule.loggedIn}
			<!-- Create Account Screen -->
			{#if has_capsule === false}
				<div class="row-span-5 flex justify-center items-center space-x-6 mx-10">
					<div
						role="button"
						class="card transition-shadow hover:shadow-lg cursor-pointer"
						on:click={() => handleAccountCreation('Capsule')}
						on:keydown={(event) => {
							if (event.key === 'Enter') handleAccountCreation('Capsule');
						}}
						tabindex="0"
					>
						<div class="bg-zinc-900 hover:bg-zinc-700 rounded p-6 flex flex-col items-center">
							<img src="time_capsule.png" alt="Capsule Icon" class="mb-4 w-16 h-16" />
							<span class="text-gray-300 font-bold">Create Identity Time Capsule</span>
							<p class="text-gray-300">
								Preserve your memories, moments, or files in a Time Capsule, sealed today and
								intended for discovery or reflection in the future.
							</p>
						</div>
					</div>

					<div
						role="button"
						class="card transition-shadow hover:shadow-lg cursor-pointer"
						on:click={() => handleAccountCreation('Terminated')}
						on:keydown={(event) => {
							if (event.key === 'Enter') handleAccountCreation('Terminated');
						}}
						tabindex="0"
					>
						<div class="bg-zinc-900 hover:bg-zinc-700 rounded p-6 flex flex-col items-center">
							<img src="dead_bunny.png" alt="Switch Icon" class="mb-4 w-16 h-16" />
							<span class="text-gray-300 font-bold">Create Fail-Safe Switch</span>
							<p class="text-gray-300">
								Activate the Fail-Safe Switch, a safety mechanism designed to ensure protection by
								defaulting to a public state in unexpected situations or failures.
							</p>
						</div>
					</div>
				</div>
			{/if}

			<!-- File List Screen -->
			{#if has_capsule === true}
				<div class="row-span-5 relative">
					<div class="overflow-auto max-h-[100vh]">
						<div class="actions p-4 flex justify-between items-center">
							<button
								class="bg-zinc-900 hover:bg-zinc-700 text-white font-bold py-2 px-4 rounded"
								on:click={triggerFileSelectionBrowser}
							>
								Upload
							</button>

							<span class="flex flex-row gap-x-4">
								<Icon
									name="home"
									on:click={() => {
										views = {
											...views_deselect,
											home_selected: true
										};
									}}
								/>
								<Icon
									name="time"
									on:click={() => {
										views = {
											...views_deselect,
											time_selected: true
										};
									}}
								/>

								<Icon
									name="settings"
									on:click={() => {
										views = {
											...views_deselect,
											settings_selected: true
										};
									}}
								/>
							</span>
						</div>

						{#if views.home_selected === true}
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
											<td class="py-2 px-4 border-b border-zinc-900"
												>{DateTime.fromMillis(Number(created) / 1000000).toLocaleString(
													DateTime.DATETIME_MED
												)}</td
											>
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
						{/if}

						{#if views.time_selected === true}
							<div class="text-white">Time</div>
						{/if}

						{#if views.settings_selected === true}
							<div class="text-white">Settings</div>
						{/if}
					</div>
				</div>
			{/if}
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
