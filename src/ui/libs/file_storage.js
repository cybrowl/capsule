export class AssetManager {
	constructor(actor, crypto_lib) {
		this._actor = actor;
		this.crypto_lib = crypto_lib;
	}

	async store(file, { content_type, filename }) {
		this.validateFile(file);

		const chunkSize = 2000000;

		const promises = await this.createUploadPromises(file, chunkSize);
		const chunk_ids = await Promise.all(promises);

		return await this.commit({
			chunk_ids,
			content_type,
			filename
		});
	}

	validateFile(file) {
		if (file === undefined) {
			throw new Error('file is required');
		}

		// if (!(file instanceof Uint8Array)) {
		// 	throw new Error('file must be a Uint8Array');
		// }
	}

	async uploadChunk({ chunk, order }) {
		const chunk_unit_8 = new Uint8Array(chunk);

		return this._actor.create_chunk(chunk_unit_8, order);
	}

	async uploadChunkWithRetry({ chunk, order, retries = 3, delay = 1000 }) {
		try {
			return await this.uploadChunk({ chunk, order });
		} catch (error) {
			if (retries > 0) {
				await new Promise((resolve) => setTimeout(resolve, delay));
				return this.uploadChunkWithRetry({
					chunk,
					order,
					retries: retries - 1,
					delay
				});
			} else {
				console.log(`Failed to upload chunk ${order} after multiple retries`);
				throw error;
			}
		}
	}

	async createUploadPromises(file, chunkSize) {
		const promises = [];

		for (let start = 0, index = 0; start < file.byteLength; start += chunkSize, index++) {
			const chunk = file.slice(start, start + chunkSize);

			const encrypted_chunk = await this.crypto_lib.encrypt(chunk);

			promises.push(
				this.uploadChunkWithRetry({
					chunk: encrypted_chunk,
					order: index
				})
			);
		}

		return promises;
	}

	async commit({ chunk_ids, content_type = 'application/octet-stream', filename = 'file' }) {
		if (chunk_ids.length < 1) {
			throw new Error('chunk_ids is required');
		}

		const response = await this._actor.commit_batch(chunk_ids, {
			filename,
			content_encoding: { Identity: null },
			content_type
		});

		return response;
	}

	async getAllAssets() {
		return this._actor.get_all_assets();
	}

	async getAsset(id) {
		return this._actor.get(id);
	}

	async getHealth() {
		return this._actor.get_health();
	}

	async deleteAsset(id) {
		return this._actor.delete_asset(id);
	}

	async chunksSize() {
		return this._actor.chunks_size();
	}

	async version() {
		return this._actor.version();
	}
}
