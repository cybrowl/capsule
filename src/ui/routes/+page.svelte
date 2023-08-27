<script>
	import { actor_capsule, actor_file_storage } from '$stores_ref/actors';
	import { auth_actors, login, crypto_service } from '$stores_ref/auth_client';
	import { get } from 'lodash';

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

	function downloadDecryptedFile(decryptedData, fileName, mimeType = 'application/octet-stream') {
		// Convert the decrypted data to a Blob
		const blob = new Blob([decryptedData], { type: mimeType });

		// Create an object URL from the Blob
		const url = URL.createObjectURL(blob);

		// Create a hidden anchor element and set the href attribute to the object URL
		const a = document.createElement('a');
		a.style.display = 'none';
		a.href = url;
		a.download = fileName;

		// Append the anchor to the document, trigger a click, and then remove it
		document.body.appendChild(a);
		a.click();
		document.body.removeChild(a);

		// Revoke the object URL to free up memory
		URL.revokeObjectURL(url);
	}

	async function handleUploadClick(e) {
		const file = e.target.files[0];

		const file_name = get(file, 'name', '');
		const file_type = get(file, 'type', '');
		const file_array_buffer = await file.arrayBuffer();

		e.target.value = '';

		if ($actor_capsule.loggedIn) {
			// await $crypto_service.init_pw('ocean');
			let version = await $actor_capsule.actor.version();
			let version_2 = await $actor_file_storage.actor.version();

			console.log('version: ', version);
			console.log('version_2: ', version_2);

			await $crypto_service.init_caller();

			console.log('file_name: ', file_name);
			console.log('file_type: ', file_type);

			const encrypted_data = await $crypto_service.encrypt(file_array_buffer);

			console.log('encrypted_data: ', encrypted_data);

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
