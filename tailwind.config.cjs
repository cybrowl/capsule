module.exports = {
	mode: 'jit',
	content: ['./src/ui/**/*.svelte'],
	darkMode: 'class', // or 'media' or 'class'
	theme: {
		extend: {
			fontFamily: {
				sans: ['Roboto', 'sans-serif']
			},
			colors: {
				backdrop: '#1B1A22',
				'black-a': '#212029'
			}
		}
	},
	variants: {
		extend: {}
	},
	plugins: []
};
