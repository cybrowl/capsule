const test = require("tape");
const { config } = require("dotenv");
const { Ed25519KeyIdentity } = require("@dfinity/identity");

// Canister Ids
const { capsule_canister_id } = require("./actor_canister_ids.cjs");
const { capsule_interface } = require("./actor_interface.cjs");

config();

const parseIdentity = (privateKeyHex) => {
  const privateKey = Uint8Array.from(Buffer.from(privateKeyHex, "hex"));

  // Initialize an identity from the secret key
  return Ed25519KeyIdentity.fromSecretKey(privateKey);
};

let motoko_identity = parseIdentity(process.env.MOTOKO_IDENTITY);

const { getActor } = require("./actor.cjs");
let capsule_actor = {};

test("Setup Actors", async function () {
  console.log("=========== Capsule ===========");

  capsule_actor.motoko = await getActor(
    capsule_canister_id,
    capsule_interface,
    motoko_identity
  );

  test("Capsule[motoko].version(): get version => #ok - version num", async function (t) {
    const version = await capsule_actor.motoko.version();

    t.equal(version, 1n);
  });
});
