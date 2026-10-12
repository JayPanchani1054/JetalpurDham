import 'package:fake_cloud_firestore/src/mock_field_value_platform.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';

// PATCHED (Jetalpur Dham demo build): extend the platform interface instead
// of implementing it with the test-only MockPlatformInterfaceMixin, which
// throws in release/profile builds. Behaviour is otherwise unchanged.
class MockFieldValueFactoryPlatform extends FieldValueFactoryPlatform {
  @override
  FieldValuePlatform delete() {
    return MockFieldValuePlatform(FakeFieldValue.delete);
  }

  @override
  FieldValuePlatform serverTimestamp() {
    return MockFieldValuePlatform(FakeFieldValue.serverTimestamp);
  }

  @override
  FieldValuePlatform increment(num value) {
    return MockFieldValuePlatform(FieldValueIncrement(value));
  }

  @override
  FieldValuePlatform arrayRemove(List elements) {
    return MockFieldValuePlatform(FieldValueArrayRemove(elements));
  }

  @override
  FieldValuePlatform arrayUnion(List elements) {
    return MockFieldValuePlatform(FieldValueArrayUnion(elements));
  }
}
