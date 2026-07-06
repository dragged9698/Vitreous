<script lang="ts">
	import './layout.css';
	import favicon from '$lib/assets/favicon.svg';

	let { children } = $props();

	const siteSchema = {
		"@context": "https://schema.org",
		"@type": "WebSite",
		"name": "Vitreous",
		"url": "https://vitreous.app"
	};

	const orgSchema = {
		"@context": "https://schema.org",
		"@type": "Organization",
		"name": "Vitreous",
		"url": "https://vitreous.app",
		"logo": "https://vitreous.app/og/vitreous-social.png",
		"sameAs": ["https://github.com/dragged9698/Vitreous"]
	};
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	{@html `<script type="application/ld+json">${JSON.stringify(siteSchema)}</script>`}
	{@html `<script type="application/ld+json">${JSON.stringify(orgSchema)}</script>`}
</svelte:head>
{@render children()}
