import { idlFactory as capsuleIdlFactory } from "../.dfx/local/canisters/capsule/service.did.test.cjs";
import { idlFactory as fileStorageIdlFactory } from "../.dfx/local/canisters/file_storage/service.did.test.cjs";

function getInterface(canister) {
  switch (canister) {
    case "capsule":
      return capsuleIdlFactory;
    case "file_storage":
      return fileStorageIdlFactory;
    default:
      throw new Error(`Unsupported canister: ${canister}`);
  }
}

export const capsule_interface = getInterface("capsule");
export const file_storage_interface = getInterface("file_storage");
