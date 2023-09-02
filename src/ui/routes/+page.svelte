<script>
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { v4 as uuidv4 } from 'uuid';
	import { page } from '$app/stores';

	onMount(() => {
		let { capsule_id } = $page.params;

		if (!capsule_id) {
			capsule_id = uuidv4();

			const capsule_route = '/' + capsule_id;
			goto(capsule_route);
		}
	});
</script>

<svelte:head>
	<title>Capsule</title>
</svelte:head>
