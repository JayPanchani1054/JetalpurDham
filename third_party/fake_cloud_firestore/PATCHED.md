# Vendored fake_cloud_firestore 4.3.0 (patched)

Copied from https://pub.dev/packages/fake_cloud_firestore (BSD licence, see
LICENSE) and used only by tests and the demo/preview build
(`preview/main_preview.dart`).

Patch: `MockFieldValueFactoryPlatform` now *extends* `FieldValueFactoryPlatform`
and `MockFieldValuePlatform` no longer mixes in `MockPlatformInterfaceMixin`.
The upstream classes use that test-only mixin, which makes
`FakeFirebaseFirestore()` throw in release and profile builds, so the demo
APK / web preview could not start. Nothing else differs from upstream.
