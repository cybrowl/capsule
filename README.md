# capsule

**Description:**

A capsule/storage to share files with others.

A time capsule for files and cherished memories to unlock at a future date.

A fail-safe switch for moments of fear.

A time-based encryption for revealing things to the world at random.

![Showcse Image](./showcase.png)

## Dev

```
npm i
dfx start --clean

cd src/vetkd_utils
npm i
npm run build

dfx deploy vetkd_system_api
dfx deploy file_storage --argument='(false)'
dfx deploy capsule
dfx deploy ui
```

Note: change `VETKD_SYSTEM_API` for local vs prod

## Testing

```
npm run test
```

## Env

```
MOTOKO_IDENTITY=
ZOOKO_IDENTITY=
SATOSHI_IDENTITY=
```

## Roadmap

### MVP

- [x] Login View
- [x] Account Creation View
- [x] Home View / Auth
- [x] Home View / No Auth
- [x] Settings View
- [x] Timer View

- [x] File Encryption & Upload
- [x] File Decryption & Download
- [x] Access when Owner Terminated by Anon
- [x] Access when Capsule Unlocked
- [x] Deny when Capsule locked

- [x] Integration Tests

### Future

- [ ] Scalable Storage
- [ ] Sharing with others via principal
- [ ] In Browser Streaming and Viewing of content

## License

This project is licensed under the MIT license, see LICENSE.md for details.
