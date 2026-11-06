# How security works

Each installation has its own identity key in Keychain. Connections use TLS 1.3, and the Mac must approve a device before sending it video or accepting input. One device can stream at a time.

## Pairing

Create an invitation in Duo Workspace Host and paste it into the iPhone or iPad. It expires after five minutes and works once. Invitations contain a secret; keep them out of logs and screenshots.

Compare the six-digit codes before approving on the Mac. The code is tied to both identities and that TLS connection. A pending request expires after one minute and has no video or input access.

Both sides present certificates. The client checks the Mac against its saved public-key fingerprint, and the host checks the device's approval. Approved devices can reconnect while sharing is enabled.

## Ending access

| Action | What happens |
| --- | --- |
| Disconnect | Ends the session. The device stays paired. |
| Stop sharing | Closes connections and stops accepting new ones. |
| Revoke access on the Mac | Disconnects the device and blocks it until a new invitation and approval. |
| Forget Mac on the device | Removes the saved connection and Mac identity. The Mac keeps its approval record until revoked. |

Disconnecting, revoking access and stopping the host release held input. Native touch uses the same approval checks as other input.

## Clipboard and files

Clipboard operations and file transfers need control access. A file connection must use the same approved identity as the active workspace. Ending that workspace or revoking the device closes its file connection too.

Clipboard text changes only after an explicit action and is limited to 16 KB. File transfers accept regular files up to 2 GB. The receiver checks the size and digest before publishing a file, keeps existing files, and never opens a received file automatically. Received names can't contain paths.

## Saved approval

Revocation blocks access immediately. The host saves it in Keychain and a signed journal. Either saved denial keeps the device blocked after restart.

If a write fails, use Retry saving. If neither store saves the denial, sharing stops. Repair storage before restarting so the revocation survives.

The journal is `~/Library/Application Support/DuoWorkspace/Security/Revocations-v1.json`. It holds signed device identifiers, not private keys. Once required, a missing or invalid journal disables sharing. It isn't a cache: deleting it won't reset pairing safely. A process lock prevents two hosts from overwriting each other's access decisions.

A failed Keychain read never causes the host to replace an existing identity. Client keys use non-syncing `WhenUnlockedThisDeviceOnly` storage.

An approved device with control access can operate the logged-in Mac. The protocol cannot protect a compromised endpoint or stop a compromised local account from rolling back all saved state. Incoming messages have size and rate limits.
