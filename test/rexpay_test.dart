import 'package:flutter_test/flutter_test.dart';
import 'package:rexpay/rexpay2.dart';
import 'package:rexpay/rexpay_platform_interface.dart';
import 'package:rexpay/rexpay_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockRexpayPlatform
    with MockPlatformInterfaceMixin
    implements RexpayPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final RexpayPlatform initialPlatform = RexpayPlatform.instance;

  test('$MethodChannelRexpay is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRexpay>());
  });

  test('getPlatformVersion', () async {
    Rexpay rexpayPlugin = Rexpay();
    MockRexpayPlatform fakePlatform = MockRexpayPlatform();
    RexpayPlatform.instance = fakePlatform;

    expect(await rexpayPlugin.getPlatformVersion(), '42');
  });
}
