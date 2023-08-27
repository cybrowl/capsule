<script>
	function handleLoginClick() {
		// handle login logic here
		alert('Login button clicked!');
	}

	function handleAddCardClick() {
		// handle add card logic here
		alert('Add card button clicked!');
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
				on:click={handleAddCardClick}
			>
				Create Account
			</button>
		</div>
		<div class="row-span-1 bg-gray-950 flex justify-center items-center">
			<!-- Button centered in the middle with onClick handler -->
			<button
				class="bg-zinc-300 hover:bg-stone-100 text-violet-500 font-bold py-2 px-4 rounded"
				on:click={handleLoginClick}
			>
				Login
			</button>
		</div>
	</div>
</main>

<style lang="postcss">
</style>
