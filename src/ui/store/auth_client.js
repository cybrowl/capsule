import { writable } from 'svelte/store';
import { AuthClient } from '@dfinity/auth-client';
import { actor_capsule, actor_file_storage, createActor } from '$stores_ref/actors';

export const auth_actors = {};
export const crypto_service = writable({});

let auth_client = {};

// authenticate and pair with actor
const authenticate_actor = async (actor_name, actor) => {
	const isAuthenticated = await auth_client.isAuthenticated();

	if (isAuthenticated) {
		actor.update(() => ({
			loggedIn: true,
			actor: createActor({
				actor_name,
				identity: auth_client.getIdentity()
			})
		}));
	}
};

export async function init_auth() {
	auth_client = await AuthClient.create({
		idleOptions: {
			idleTimeout: 1000 * 60 * 60 * 24 * 30,
			disableDefaultIdleCallback: true
		}
	});

	const actors_list = [
		{ name: 'capsule', actor: actor_capsule },
		{ name: 'file_storage', actor: actor_file_storage }
	];

	actors_list.forEach(({ name, actor }) => {
		auth_actors[name] = () => authenticate_actor(name, actor);
	});
}

// login
export async function login(isProd, handleAuth) {
	auth_client.login({
		identityProvider: isProd
			? 'https://identity.ic0.app/#authorize'
			: 'http://cpmcr-yeaaa-aaaaa-qaala-cai.localhost:8080/',
		maxTimeToLive: BigInt(30 * 24 * 60 * 60 * 1000 * 1000 * 1000 * 1000),
		onSuccess: handleAuth
	});
}

// logout
const logout_actor = async (actor_name, actor) => {
	const authClient = await AuthClient.create();

	const isAuthenticated = await authClient.isAuthenticated();

	if (!isAuthenticated) {
		actor.update(() => ({
			loggedIn: false,
			actor: createActor({
				actor_name,
				identity: authClient.getIdentity()
			})
		}));
	}
};

export const auth_logout_all = async () => {
	await auth_client.logout();

	const actors_list = [
		{ name: 'capsule', actor: actor_capsule },
		{ name: 'file_storage', actor: actor_file_storage }
	];

	actors_list.forEach(({ name, actor }) => {
		logout_actor(name, actor);
	});
};
