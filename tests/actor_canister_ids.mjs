import canister_ids from "../.dfx/local/canister_ids.json" assert { type: "json" };

const canisterNames = ["capsule", "file_storage"];

const ids = {};

for (const name of canisterNames) {
  ids[`${name}_canister_id`] = canister_ids[name].local;
}

export const capsule_canister_id = ids.capsule_canister_id;
export const file_storage_canister_id = ids.file_storage_canister_id;
