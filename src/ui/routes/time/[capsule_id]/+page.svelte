<script>
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { actor_capsule, actor_file_storage } from '$stores_ref/actors';
	import { auth_actors, crypto_service, init_auth } from '$stores_ref/auth_client';
	import { get } from 'lodash';
	import { DateTime } from 'luxon';

	import { AssetManager } from '../../../libs/file_storage';
	import { CryptoService } from '../../../libs/crypto';
	import init_vetkd_wasm from 'ic-vetkd-utils';

	import JellyFish from '../../../components/JellyFish.svelte';

	let file_input_elem;

	let capsule_id = '';
	let capsule_ref = {
		is_unlocked: true,
		files: []
	};

	let is_loading = false;
	let is_loading_msg = '';

	let minutes_locked = 10;

	onMount(async () => {
		is_loading = true;
		is_loading_msg = 'Setting Up Encryption';

		capsule_id = $page.params.capsule_id;

		// auth actors
		await init_auth();
		await auth_actors.capsule();
		await auth_actors.file_storage();

		// get owner principal
		let { ok: capsule, err: error } = await $actor_capsule.actor.get_capsule(capsule_id);

		console.group('%cCapsule Information', 'color: blue; font-weight: bold;');
		console.log('%cCapsule:', 'color: blue;', capsule);
		console.groupEnd();
		console.log('error: ', error);

		if (capsule) {
			capsule_ref = capsule;
		}

		if (error) {
			let { ok: created, err: error_create } = await $actor_capsule.actor.create_capsule(
				capsule_id,
				{
					TimeEncrypt: null
				}
			);

			let { ok: capsule, err: error_get } = await $actor_capsule.actor.get_capsule(capsule_id);

			capsule_ref = capsule;
		}

		// vetkey init wasm
		await init_vetkd_wasm();

		const cryptoService = new CryptoService($actor_capsule.actor);
		crypto_service.set(cryptoService);

		is_loading = false;
		is_loading_msg = '';
	});

	function showDownloadButton(created, locked_minutes) {
		let unlockTimeMillis = Number(created) / 1000000 + Number(locked_minutes) * 60 * 1000;
		let currentTimeMillis = DateTime.local().toMillis();

		// Time difference in minutes
		let timeDifference = (currentTimeMillis - unlockTimeMillis) / (60 * 1000);

		// Return true if the time difference is between 0 to 10
		return timeDifference >= 0 && timeDifference <= 10;
	}

	function triggerFileSelectionBrowser(e) {
		file_input_elem.click();
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
				const response = await $crypto_service.init_time();
				console.log('response: ', response);

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
		is_loading = true;
		is_loading_msg = 'Encrypting File and Storing...';

		const response = await $crypto_service.init_time(minutes_locked);

		let file_storage_lib = new AssetManager($actor_file_storage.actor, $crypto_service);

		const file = e.target.files[0];
		const file_name = get(file, 'name', '');
		const file_type = get(file, 'type', '');
		const file_array_buffer = await file.arrayBuffer();

		e.target.value = '';

		const { ok: asset_id, err: error_store } = await file_storage_lib.store(file_array_buffer, {
			content_type: file_type,
			filename: file_name
		});

		const { ok: added_file, err: err_adding_file } = await $actor_capsule.actor.add_file_with_time(
			capsule_id,
			asset_id,
			minutes_locked
		);

		let { ok: capsule } = await $actor_capsule.actor.get_capsule(capsule_id);
		capsule_ref = capsule;

		is_loading = false;
		is_loading_msg = '';
	}
</script>

<svelte:head>
	<title>Capsule</title>
</svelte:head>

<main class="grid grid-cols-12 h-screen">
	<!-- Left column with the image -->
	<div class="col-span-4 relative">
		<img src="/header.jpeg" alt="Description" class="absolute inset-0 w-full h-full object-cover" />
	</div>

	<!-- Right column with the files table -->
	<div class="col-span-8 grid grid-rows-5 bg-gray-950">
		<!-- Loading View -->
		{#if is_loading === true}
			<div class="row-span-5 bg-gray-950 flex justify-center items-center flex-col">
				<JellyFish />
				<p class="text-white mt-4">{is_loading_msg}</p>
			</div>
		{/if}

		{#if is_loading === false}
			<div class="row-span-5 relative">
				<div class="actions p-4 flex items-center flex-row gap-x-4">
					<button
						class="bg-zinc-900 hover:bg-zinc-700 text-white font-bold py-2 px-4 rounded"
						on:click={triggerFileSelectionBrowser}
					>
						Upload
					</button>

					<input
						id="numberInput"
						type="number"
						class="bg-gray-800 p-2 w-28 rounded text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-gray-600"
						bind:value={minutes_locked}
						on:keydown={(event) => {
							if (
								![
									'0',
									'1',
									'2',
									'3',
									'4',
									'5',
									'6',
									'7',
									'8',
									'9',
									'Backspace',
									'ArrowLeft',
									'ArrowRight',
									'Tab',
									'Delete'
								].includes(event.key)
							) {
								event.preventDefault();
							}
						}}
						on:input={(event) => {
							if (/^\d+$/.test(event.target.value) || event.target.value === '') {
								minutes_locked = Number(event.target.value);
							} else {
								event.target.value = minutes_locked;
							}
						}}
					/>
				</div>
				<h2 class="text-yellow-500 m-4">
					The unlock window is available for only 10 minutes at the designated unlock time.
				</h2>

				<table class="min-w-full text-white">
					<thead>
						<tr>
							<th class="py-2 px-4 border-b border-zinc-900 text-left">Filename</th>
							<th class="py-2 px-4 border-b border-zinc-900 text-left">Created</th>
							<th class="py-2 px-4 border-b border-zinc-900 text-left">Locked Minutes</th>
							<th class="py-2 px-4 border-b border-zinc-900 text-left">Unlock Date</th>
							<th class="py-2 px-4 border-b border-zinc-900 text-left">Content Type</th>
						</tr>
					</thead>
					<tbody>
						{#each capsule_ref.files as { filename, created, content_type, locked_minutes, url }}
							<tr>
								<td class="py-2 px-4 border-b border-zinc-900">{filename}</td>
								<td class="py-2 px-4 border-b border-zinc-900"
									>{DateTime.fromMillis(Number(created) / 1000000).toLocaleString(
										DateTime.DATETIME_MED
									)}</td
								>
								<td class="py-2 px-4 border-b border-zinc-900">{locked_minutes}</td>
								<td class="py-2 px-4 border-b border-zinc-900">
									{DateTime.fromMillis(
										Number(created) / 1000000 + Number(locked_minutes) * 60 * 1000
									).toLocaleString(DateTime.DATETIME_MED)}
								</td>
								<td class="py-2 px-4 border-b border-zinc-900">{content_type}</td>
								{#if showDownloadButton(created, locked_minutes)}
									<td class="py-2 px-4 border-b border-zinc-900">
										<button
											class="bg-zinc-900 hover:bg-zinc-700 text-white font-bold py-2 px-4 rounded"
											on:click={() => decryptAndDownloadFile(url, filename)}
										>
											Download
										</button>
									</td>
								{/if}
							</tr>
						{/each}
					</tbody>
				</table>
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
