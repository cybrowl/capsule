function getInterface(canister) {
  const {
    idlFactory,
  } = require(`../.dfx/local/canisters/${canister}/service.did.test.cjs`);
  return idlFactory;
}

module.exports = {
  capsule_interface: getInterface("capsule"),
  file_storage_interface: getInterface("file_storage"),
};
