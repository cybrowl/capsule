import CRC32 from 'crc-32';
import { Buffer } from 'buffer';

export class AssetManager {
	constructor(actor) {
		this._actor = actor;
	}

	async store(file, { content_type, filename }) {
		this.validateFile(file);

		const chunkSize = 2000000;
		const { promises, checksum } = this.createUploadPromises(file, chunkSize);

		const chunk_ids = await Promise.all(promises);

		return await this.commit({
			chunk_ids,
			checksum,
			content_type,
			filename
		});
	}

	validateFile(file) {
		if (file === undefined) {
			throw new Error('file is required');
		}

		if (!(file instanceof Uint8Array)) {
			throw new Error('file must be a Uint8Array');
		}
	}

	async uploadChunk({ chunk, order }) {
		return this._actor.create_chunk(chunk, order);
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

	updateChecksum(chunk, checksum) {
		const moduloValue = 400000000;

		const signedChecksum = CRC32.buf(Buffer.from(chunk), 0);
		const unsignedChecksum = signedChecksum >>> 0;
		const updatedChecksum = (checksum + unsignedChecksum) % moduloValue;

		return updatedChecksum;
	}

	createUploadPromises(file, chunkSize) {
		const promises = [];
		let checksum = 0;

		for (let start = 0, index = 0; start < file.length; start += chunkSize, index++) {
			const chunk = file.slice(start, start + chunkSize);

			// TODO: encrypt chunk
			checksum = this.updateChecksum(chunk, checksum);

			promises.push(
				this.uploadChunkWithRetry({
					chunk,
					order: index
				})
			);
		}

		return { promises, checksum };
	}

	async commit({
		chunk_ids,
		checksum,
		content_type = 'application/octet-stream',
		filename = 'file'
	}) {
		if (chunk_ids.length < 1) {
			throw new Error('chunk_ids is required');
		}

		const response = await this._actor.commit_batch(chunk_ids, {
			filename,
			checksum: checksum,
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
