<script>
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { actor_capsule, actor_file_storage } from '$stores_ref/actors';
	import {
		auth_actors,
		login,
		auth_logout_all,
		crypto_service,
		init_auth
	} from '$stores_ref/auth_client';
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
		settings_selected: false,
		locked_selected: false,
		terminated_selected: false
	};

	const views_deselect = {
		home_selected: false,
		time_selected: false,
		settings_selected: false,
		locked_selected: false,
		terminated_selected: false
	};

	let time_input = 0;

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

		// capsule doesn't exist
		if (error && error.CapsuleNotFound) {
			is_loading = false;
			is_loading_msg = '';

			return null;
		}

		// capsule locked state
		if (capsule && capsule.is_unlocked == false) {
			is_loading = false;
			is_loading_msg = '';

			has_capsule = true;
			capsule_ref = capsule;

			views = {
				...views_deselect,
				locked_selected: true
			};

			return null;
		}

		if (capsule) {
			has_capsule = true;
			capsule_ref = capsule;

			// terminated
			if (capsule.owner_is_terminated == true) {
				views = {
					...views_deselect,
					terminated_selected: true
				};
			} else {
				views = {
					...views_deselect,
					home_selected: true
				};
			}

			console.group('%cCapsule Information', 'color: blue; font-weight: bold;');
			console.log('%cCapsule:', 'color: green;', capsule);
			console.groupEnd();

			const owner_principal = capsule.owner._arr;

			const cryptoService = new CryptoService($actor_capsule.actor);
			crypto_service.set(cryptoService);

			await cryptoService.init_caller(capsule.id, owner_principal);

			if ($actor_capsule.loggedIn === true && capsule.owner_is_terminated == false) {
				let { ok: capsule } = await $actor_capsule.actor.get_capsule(capsule_id);

				files = capsule.files;

				is_loading = false;
				is_loading_msg = '';
			} else {
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
				let { ok: capsule, err: error } = await $actor_capsule.actor.get_capsule(capsule_id);

				if (capsule) {
					window.location.reload();
				}
			}
		} catch (error) {
			console.log('handleAuth - error: ', error);
		}
	}

	async function handleAccountCreation(kind) {
		if ($actor_capsule.loggedIn === true) {
			is_loading = true;
			is_loading_msg = 'Creating Account';

			let exists = await $actor_capsule.actor.check_capsule_exists(capsule_id);

			if (exists === false) {
				let { ok: created, err: error } = await $actor_capsule.actor.create_capsule(capsule_id, {
					[kind]: null
				});

				window.location.reload();
			} else {
				is_loading = false;
				is_loading_msg = '';
			}
		}
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

	async function handleUpdateCountdown() {
		if ($actor_capsule.loggedIn) {
			is_loading = true;

			let timeInputInt = parseInt(time_input, 10);

			if ('Terminated' in capsule_ref?.kind) {
				is_loading_msg = 'Updating Countdown';

				const { ok: updated_countdown, err: err_update_countdown } =
					await $actor_capsule.actor.update_countdown(capsule_id, timeInputInt);
			} else {
				is_loading_msg = 'Updating Locked Minutes';

				const { ok: updated_locked, err: err_update_locked } = await $actor_capsule.actor.add_time(
					capsule_id,
					timeInputInt
				);
			}

			let { ok: capsule } = await $actor_capsule.actor.get_capsule(capsule_id);
			capsule_ref = capsule;

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
		<!-- Loading View -->
		{#if is_loading === true}
			<div class="row-span-5 bg-gray-950 flex justify-center items-center flex-col">
				<JellyFish />
				<p class="text-white mt-4">{is_loading_msg}</p>
			</div>
		{/if}

		<!-- Login View -->
		{#if is_loading === false && $actor_capsule.loggedIn === false && views.terminated_selected === false}
			<div class="row-span-5 flex justify-center items-center">
				<button
					class="bg-zinc-300 hover:bg-stone-100 text-violet-500 font-bold py-4 px-6 rounded"
					on:click={handleLoginClick}
				>
					Identity Login
				</button>
			</div>
		{/if}

		<!-- Terminated View -->
		{#if is_loading === false && views.terminated_selected === true}
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

		{#if is_loading === false && $actor_capsule.loggedIn && views.terminated_selected === false}
			<!-- Create Account View -->
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

			<!-- Views -->
			{#if has_capsule === true}
				<div class="row-span-5 relative">
					<div class="overflow-auto max-h-[100vh]">
						<!-- Actions Bar -->
						<div class="actions p-4 flex justify-between items-center">
							<button
								class="bg-zinc-900 hover:bg-zinc-700 text-white font-bold py-2 px-4 rounded
								{capsule_ref.is_unlocked == false ? 'opacity-0 pointer-events-none' : ''}"
								on:click={triggerFileSelectionBrowser}
							>
								Upload
							</button>

							<span class="flex flex-row gap-x-4">
								<Icon
									name="home"
									on:click={() => {
										if (capsule_ref.is_unlocked == true) {
											views = {
												...views_deselect,
												home_selected: true
											};
										} else {
											views = {
												...views_deselect,
												locked_selected: true
											};
										}
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

						<!-- Locked View -->
						{#if views.locked_selected === true}
							<div class="flex justify-center items-center min-h-screen bg-gray-950">
								<div class="text-white bg-gray-800 rounded-lg shadow-md p-10">
									<h1 class="text-4xl font-bold text-center">Capsule is Locked</h1>
								</div>
							</div>
						{/if}

						<!-- Home View -->
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

						<!-- Time View -->
						{#if views.time_selected === true}
							<div class="text-white m-10 p-10">
								{#if 'Capsule' in capsule_ref?.kind}
									<div class="mb-10 font-medium flex flex-col gap-y-4">
										<span>
											<strong>Locked Start:</strong>
											{#if capsule_ref.locked_start < 2}
												<p>None</p>
											{:else}
												<p>
													{DateTime.fromMillis(
														Number(capsule_ref.locked_start) / 1000000
													).toLocaleString(DateTime.DATETIME_MED)}
												</p>
											{/if}
										</span>

										<span>
											<strong>Locked:</strong>
											<p>
												{capsule_ref.locked_minutes} minutes
											</p>
										</span>
									</div>
								{/if}

								{#if 'Terminated' in capsule_ref?.kind}
									<div class="mb-10 font-medium flex flex-col gap-y-4">
										<span>
											<strong>Last Login:</strong>
											<p>
												{DateTime.fromMillis(
													Number(capsule_ref.last_login) / 1000000
												).toLocaleString(DateTime.DATETIME_MED)}
											</p>
										</span>

										<span>
											<strong>Countdown Constant:</strong>
											<p>
												{capsule_ref.countdown_minutes} minutes
											</p>
										</span>
									</div>
								{/if}

								{#if 'Capsule' in capsule_ref?.kind}
									<label for="numberInput" class="block mb-2 font-medium">Add Minutes to Lock</label
									>
								{/if}
								{#if 'Terminated' in capsule_ref?.kind}
									<label for="numberInput" class="block mb-2 font-medium"
										>Countdown Minutes Constant to Unlock</label
									>
								{/if}

								<input
									id="numberInput"
									type="number"
									class="bg-gray-800 p-2 w-1/4 rounded text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-gray-600"
									bind:value={time_input}
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
											time_input = event.target.value;
										} else {
											event.target.value = time_input;
										}
									}}
								/>

								<button
									class="bg-gray-800 hover:bg-gray-600 font-bold ml-4 py-2 px-6 rounded"
									on:click={handleUpdateCountdown}
								>
									Update
								</button>
							</div>
						{/if}

						<!-- Settings View -->
						{#if views.settings_selected === true}
							<div class="text-white m-10 p-10">
								<div class="mb-10">
									{#if 'Capsule' in capsule_ref?.kind}
										<p><strong>Capsule Kind:</strong> Identity Time Capsule</p>
										<img src="time_capsule.png" alt="Capsule Icon" class="my-4 w-16 h-16" />
									{/if}
									{#if 'Terminated' in capsule_ref?.kind}
										<p><strong>Capsule Kind:</strong> Terminated Time Capsule</p>
										<img
											src="dead_bunny.png"
											alt="Switch Icon"
											class="my-4 w-16 h-16 bg-gray-700 rounded-full"
										/>
									{/if}
								</div>

								<button
									class="bg-zinc-900 hover:bg-zinc-700 text-red-500 font-bold py-2 px-4 rounded"
									on:click={async () => {
										await auth_logout_all();
									}}
								>
									Logout
								</button>
							</div>
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
