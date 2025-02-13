// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:meta/meta.dart';
import 'package:process/process.dart';

import 'android/android_device_discovery.dart';
import 'android/android_sdk.dart';
import 'android/android_workflow.dart';
import 'artifacts.dart';
import 'base/config.dart';
import 'base/file_system.dart';
import 'base/logger.dart';
import 'base/os.dart';
import 'base/platform.dart';
import 'base/terminal.dart';
import 'base/user_messages.dart' hide userMessages;
import 'device.dart';
import 'features.dart';
import 'fuchsia/fuchsia_device.dart';
import 'fuchsia/fuchsia_sdk.dart';
import 'fuchsia/fuchsia_workflow.dart';
import 'ios/devices.dart';
import 'ios/ios_workflow.dart';
import 'ios/simulators.dart';
import 'linux/linux_device.dart';
import 'macos/macos_device.dart';
import 'macos/macos_workflow.dart';
import 'macos/xcode.dart';
import 'tester/flutter_tester.dart';
import 'version.dart';
import 'web/web_device.dart';
import 'windows/windows_device.dart';
import 'windows/windows_workflow.dart';

/// A provider for all of the device discovery instances.
class FlutterDeviceManager extends DeviceManager {
  FlutterDeviceManager({
    @required Logger logger,
    @required Platform platform,
    @required ProcessManager processManager,
    @required FileSystem fileSystem,
    @required AndroidSdk androidSdk,
    @required FeatureFlags featureFlags,
    @required IOSSimulatorUtils iosSimulatorUtils,
    @required XCDevice xcDevice,
    @required AndroidWorkflow androidWorkflow,
    @required IOSWorkflow iosWorkflow,
    @required FuchsiaWorkflow fuchsiaWorkflow,
    @required FlutterVersion flutterVersion,
    @required Config config,
    @required Artifacts artifacts,
    @required MacOSWorkflow macOSWorkflow,
    @required UserMessages userMessages,
    @required OperatingSystemUtils operatingSystemUtils,
    @required WindowsWorkflow windowsWorkflow,
    @required Terminal terminal,
  }) : deviceDiscoverers =  <DeviceDiscovery>[
    AndroidDevices(
      logger: logger,
      androidSdk: androidSdk,
      androidWorkflow: androidWorkflow,
      processManager: processManager,
      fileSystem: fileSystem,
      platform: platform,
      userMessages: userMessages,
    ),
    IOSDevices(
      platform: platform,
      xcdevice: xcDevice,
      iosWorkflow: iosWorkflow,
      logger: logger,
    ),
    IOSSimulators(
      iosSimulatorUtils: iosSimulatorUtils,
    ),
    FuchsiaDevices(
      fuchsiaSdk: fuchsiaSdk,
      logger: logger,
      fuchsiaWorkflow: fuchsiaWorkflow,
      platform: platform,
    ),
    FlutterTesterDevices(
      fileSystem: fileSystem,
      flutterVersion: flutterVersion,
      processManager: processManager,
      config: config,
      logger: logger,
      artifacts: artifacts,
      operatingSystemUtils: operatingSystemUtils,
    ),
    MacOSDevices(
      processManager: processManager,
      macOSWorkflow: macOSWorkflow,
      logger: logger,
      platform: platform,
      fileSystem: fileSystem,
      operatingSystemUtils: operatingSystemUtils,
    ),
    LinuxDevices(
      platform: platform,
      featureFlags: featureFlags,
      processManager: processManager,
      logger: logger,
      fileSystem: fileSystem,
      operatingSystemUtils: operatingSystemUtils,
    ),
    WindowsDevices(
      processManager: processManager,
      operatingSystemUtils: operatingSystemUtils,
      logger: logger,
      fileSystem: fileSystem,
      windowsWorkflow: windowsWorkflow,
      featureFlags: featureFlags,
    ),
    WebDevices(
      featureFlags: featureFlags,
      fileSystem: fileSystem,
      platform: platform,
      processManager: processManager,
      logger: logger,
    ),
  ], super(
      logger: logger,
      terminal: terminal,
      userMessages: userMessages,
    );

  @override
  final List<DeviceDiscovery> deviceDiscoverers;
}
