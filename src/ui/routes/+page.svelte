<script>
	import { actor_capsule } from '$stores_ref/actors';
	import { auth_actors, login, crypto_service } from '$stores_ref/auth_client';

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

	async function handleUploadClick() {
		await $crypto_service.init_pw('ocean');

		const super_secret_string = 'hello';
		const encrypted_msg = await $crypto_service.encrypt(super_secret_string);

		console.log('encrypted_msg: ', encrypted_msg);

		if ($actor_capsule.loggedIn) {
			let version = await $actor_capsule.actor.version();

			console.log('version: ', version);
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
					on:click={handleUploadClick}
				>
					Upload
				</button>
			</div>
		{/if}
	</div>
</main>

<style lang="postcss">
</style>
