<script>
	import * as icons from './icons';
	import { createEventDispatcher } from 'svelte';
	const dispatch = createEventDispatcher();

	export let name;
	export let focusable = false;
	export let viewSize = {
		width: 24,
		height: 24
	};

	export let size = '2rem'; // size is now used for both width and height
	export let scale = 1; // scale factor, adjust this to scale the icon
	export let viewbox = {
		width: viewSize.width / scale,
		height: viewSize.height / scale
	};
</script>

<svg
	class={$$props.class}
	{focusable}
	width={size}
	height={size}
	viewBox={`0 0 ${viewbox.width} ${viewbox.height}`}
	role="button"
	aria-label="Description of the icon's function"
	tabindex="0"
	on:click={(event) => {
		event.stopPropagation();

		dispatch('click', event);
	}}
	on:keypress={(e) => {
		if (e.key === 'Enter' || e.key === ' ') {
			// Handle keypress event for Enter or Space keys
			e.preventDefault();
		}
	}}
>
	{@html icons[name]}
</svg>

<style lang="postcss">
	.cursor_pointer {
		@apply cursor-pointer;
	}
	.cursor_default {
		@apply cursor-default;
	}
</style>
