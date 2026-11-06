# Contributing

Contributions use the [MIT license](LICENSE). Open an issue before a larger change; send small fixes as a pull request.

Follow the [build guide](Documentation/Development.md) and run `Scripts/build.sh`. Set `DUO_TEST_DESTINATION` to an installed simulator for client tests. Check the affected fold and keyboard layouts when changing controls.

Edit `project.yml` and run `xcodegen generate` when adding files or changing targets. Put generated files in `.artifacts/` and signing credentials in `.secrets/`.

Tests must use their own identities and revocation journals. Don't replace saved keys or delete a user's security records to get a test passing.

In the pull request, explain what changed and how you checked it. Include screenshots with test data for visible changes, and state what still needs testing. Keep required license notices when adding external code.
