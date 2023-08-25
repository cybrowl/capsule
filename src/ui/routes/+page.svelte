<script>
</script>

<svelte:head>
	<title>Capsule</title>
</svelte:head>

<main class="grid grid-cols-12 h-screen">
	<!-- Left column with the image -->
	<div class="col-span-6 relative">
		<img src="fish_bg.jpeg" alt="Description" class="absolute inset-0 w-full h-full object-cover" />
	</div>
	<div class="col-span-6 bg-red-500 grid grid-rows-2">
		<!-- 6 columns content for the right side -->
		<div class="row-span-1 bg-green-500">Top content here.</div>
		<div class="row-span-1 bg-yellow-500">Bottom content here.</div>
	</div>
</main>

<style lang="postcss">
</style>
