import test from "tape";
import { config } from "dotenv";
import { Ed25519KeyIdentity } from "@dfinity/identity";
import { capsule_canister_id } from "./actor_canister_ids.mjs";
import { capsule_interface } from "./actor_interface.mjs";
import { getActor } from "./actor.mjs";

config();

const parseIdentity = (privateKeyHex) => {
  const privateKey = Uint8Array.from(Buffer.from(privateKeyHex, "hex"));

  // Initialize an identity from the secret key
  return Ed25519KeyIdentity.fromSecretKey(privateKey);
};

let motoko_identity = parseIdentity(process.env.MOTOKO_IDENTITY);

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

  // NOTE: too much browser dep code from crypto libs.
  // Because of this will need to continue dev / testing in browser, so switching to UI
});
