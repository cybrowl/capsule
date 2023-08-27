import { writable } from 'svelte/store';
import { AuthClient } from '@dfinity/auth-client';
import { actor_capsule, createActor } from '$stores_ref/actors';

export const auth_client = writable({});
export const auth_actors = {};

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

const actors_list = [{ name: 'actor_capsule', actor: actor_capsule }];

actors_list.forEach(({ name, actor }) => {
	auth_actors[name] = () => authenticate_actor(name, actor);
});

// logout
const logout_actor = async (actor_name, actor) => {
	// Not sure if this even does the reset
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

	authActors.forEach(({ name, actor }) => {
		logout_actor(name, actor);
	});
};
