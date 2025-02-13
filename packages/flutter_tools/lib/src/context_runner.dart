// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';

import 'package:process/process.dart';

import 'android/android_builder.dart';
import 'android/android_sdk.dart';
import 'android/android_studio.dart';
import 'android/android_workflow.dart';
import 'android/gradle.dart';
import 'android/gradle_utils.dart';
import 'application_package.dart';
import 'artifacts.dart';
import 'asset.dart';
import 'base/config.dart';
import 'base/context.dart';
import 'base/error_handling_io.dart';
import 'base/io.dart';
import 'base/logger.dart';
import 'base/os.dart';
import 'base/process.dart';
import 'base/terminal.dart';
import 'base/time.dart';
import 'base/user_messages.dart';
import 'build_info.dart';
import 'build_system/build_system.dart';
import 'cache.dart';
import 'dart/pub.dart';
import 'devfs.dart';
import 'device.dart';
import 'devtools_launcher.dart';
import 'doctor.dart';
import 'emulator.dart';
import 'features.dart';
import 'flutter_device_manager.dart';
import 'fuchsia/fuchsia_device.dart' show FuchsiaDeviceTools;
import 'fuchsia/fuchsia_sdk.dart' show FuchsiaSdk, FuchsiaArtifacts;
import 'fuchsia/fuchsia_workflow.dart' show FuchsiaWorkflow, fuchsiaWorkflow;
import 'globals.dart' as globals;
import 'ios/ios_workflow.dart';
import 'ios/iproxy.dart';
import 'ios/simulators.dart';
import 'ios/xcodeproj.dart';
import 'macos/cocoapods.dart';
import 'macos/cocoapods_validator.dart';
import 'macos/macos_workflow.dart';
import 'macos/xcode.dart';
import 'mdns_discovery.dart';
import 'persistent_tool_state.dart';
import 'reporting/first_run.dart';
import 'reporting/reporting.dart';
import 'resident_runner.dart';
import 'run_hot.dart';
import 'runner/local_engine.dart';
import 'version.dart';
import 'web/workflow.dart';
import 'windows/visual_studio.dart';
import 'windows/visual_studio_validator.dart';
import 'windows/windows_workflow.dart';

Future<T> runInContext<T>(
  FutureOr<T> Function() runner, {
  Map<Type, Generator> overrides,
}) async {

  // Wrap runner with any asynchronous initialization that should run with the
  // overrides and callbacks.
  bool runningOnBot;
  FutureOr<T> runnerWrapper() async {
    runningOnBot = await globals.isRunningOnBot;
    return runner();
  }

  return context.run<T>(
    name: 'global fallbacks',
    body: runnerWrapper,
    overrides: overrides,
    fallbacks: <Type, Generator>{
      AndroidBuilder: () => AndroidGradleBuilder(
        logger: globals.logger,
        processManager: globals.processManager,
        fileSystem: globals.fs,
        artifacts: globals.artifacts,
        usage: globals.flutterUsage,
        gradleUtils: globals.gradleUtils,
        platform: globals.platform,
      ),
      AndroidLicenseValidator: () => AndroidLicenseValidator(
        operatingSystemUtils: globals.os,
        platform: globals.platform,
        userMessages: globals.userMessages,
        processManager: globals.processManager,
        androidStudio: globals.androidStudio,
        androidSdk: globals.androidSdk,
        logger: globals.logger,
        fileSystem: globals.fs,
        stdio: globals.stdio,
      ),
      AndroidSdk: AndroidSdk.locateAndroidSdk,
      AndroidStudio: AndroidStudio.latestValid,
      AndroidValidator: () => AndroidValidator(
        androidStudio: globals.androidStudio,
        androidSdk: globals.androidSdk,
        fileSystem: globals.fs,
        logger: globals.logger,
        platform: globals.platform,
        processManager: globals.processManager,
        userMessages: globals.userMessages,
      ),
      AndroidWorkflow: () => AndroidWorkflow(
        androidSdk: globals.androidSdk,
        featureFlags: featureFlags,
        operatingSystemUtils: globals.os,
      ),
      ApplicationPackageFactory: () => ApplicationPackageFactory(
        userMessages: globals.userMessages,
        processManager: globals.processManager,
        logger: globals.logger,
        fileSystem: globals.fs,
        androidSdk: globals.androidSdk,
      ),
      Artifacts: () => CachedArtifacts(
        fileSystem: globals.fs,
        cache: globals.cache,
        platform: globals.platform,
        operatingSystemUtils: globals.os,
      ),
      AssetBundleFactory: () {
        return AssetBundleFactory.defaultInstance(
          logger: globals.logger,
          fileSystem: globals.fs,
          platform: globals.platform,
        );
      },
      BuildSystem: () => FlutterBuildSystem(
        fileSystem: globals.fs,
        logger: globals.logger,
        platform: globals.platform,
      ),
      Cache: () => Cache(
        fileSystem: globals.fs,
        logger: globals.logger,
        platform: globals.platform,
        osUtils: globals.os,
      ),
      CocoaPods: () => CocoaPods(
        fileSystem: globals.fs,
        processManager: globals.processManager,
        logger: globals.logger,
        platform: globals.platform,
        xcodeProjectInterpreter: globals.xcodeProjectInterpreter,
        usage: globals.flutterUsage,
      ),
      CocoaPodsValidator: () => CocoaPodsValidator(
        globals.cocoaPods,
        globals.userMessages,
      ),
      Config: () => Config(
        Config.kFlutterSettings,
        fileSystem: globals.fs,
        logger: globals.logger,
        platform: globals.platform,
      ),
      CrashReporter: () => CrashReporter(
        fileSystem: globals.fs,
        logger: globals.logger,
        flutterProjectFactory: globals.projectFactory,
        client: globals.httpClientFactory?.call() ?? HttpClient(),
      ),
      DevFSConfig: () => DevFSConfig(),
      DeviceManager: () => FlutterDeviceManager(
        logger: globals.logger,
        processManager: globals.processManager,
        platform: globals.platform,
        androidSdk: globals.androidSdk,
        iosSimulatorUtils: globals.iosSimulatorUtils,
        featureFlags: featureFlags,
        fileSystem: globals.fs,
        iosWorkflow: globals.iosWorkflow,
        artifacts: globals.artifacts,
        flutterVersion: globals.flutterVersion,
        androidWorkflow: androidWorkflow,
        config: globals.config,
        fuchsiaWorkflow: fuchsiaWorkflow,
        xcDevice: globals.xcdevice,
        userMessages: globals.userMessages,
        windowsWorkflow: windowsWorkflow,
        macOSWorkflow: MacOSWorkflow(
          platform: globals.platform,
          featureFlags: featureFlags,
        ),
        operatingSystemUtils: globals.os,
        terminal: globals.terminal,
      ),
      DevtoolsLauncher: () => DevtoolsServerLauncher(
        processManager: globals.processManager,
        pubExecutable: globals.artifacts.getArtifactPath(Artifact.pubExecutable),
        logger: globals.logger,
        platform: globals.platform,
        persistentToolState: globals.persistentToolState,
      ),
      Doctor: () => Doctor(logger: globals.logger),
      DoctorValidatorsProvider: () => DoctorValidatorsProvider.defaultInstance,
      EmulatorManager: () => EmulatorManager(
        androidSdk: globals.androidSdk,
        processManager: globals.processManager,
        logger: globals.logger,
        fileSystem: globals.fs,
        androidWorkflow: androidWorkflow,
      ),
      FeatureFlags: () => FlutterFeatureFlags(
        flutterVersion: globals.flutterVersion,
        config: globals.config,
        platform: globals.platform,
      ),
      FlutterVersion: () => FlutterVersion(clock: const SystemClock()),
      FuchsiaArtifacts: () => FuchsiaArtifacts.find(),
      FuchsiaDeviceTools: () => FuchsiaDeviceTools(),
      FuchsiaSdk: () => FuchsiaSdk(),
      FuchsiaWorkflow: () => FuchsiaWorkflow(
        featureFlags: featureFlags,
        platform: globals.platform,
        fuchsiaArtifacts: globals.fuchsiaArtifacts,
      ),
      GradleUtils: () => GradleUtils(
        fileSystem: globals.fs,
        operatingSystemUtils: globals.os,
        logger: globals.logger,
        platform: globals.platform,
        cache: globals.cache,
      ),
      HotRunnerConfig: () => HotRunnerConfig(),
      IOSSimulatorUtils: () => IOSSimulatorUtils(
        logger: globals.logger,
        processManager: globals.processManager,
        xcode: globals.xcode,
      ),
      IOSWorkflow: () => IOSWorkflow(
        featureFlags: featureFlags,
        xcode: globals.xcode,
        platform: globals.platform,
      ),
      LocalEngineLocator: () => LocalEngineLocator(
        userMessages: userMessages,
        logger: globals.logger,
        platform: globals.platform,
        fileSystem: globals.fs,
        flutterRoot: Cache.flutterRoot,
      ),
      Logger: () => globals.platform.isWindows
        ? WindowsStdoutLogger(
            terminal: globals.terminal,
            stdio: globals.stdio,
            outputPreferences: globals.outputPreferences,
          )
        : StdoutLogger(
            terminal: globals.terminal,
            stdio: globals.stdio,
            outputPreferences: globals.outputPreferences,
          ),
      MacOSWorkflow: () => MacOSWorkflow(
        featureFlags: featureFlags,
        platform: globals.platform,
      ),
      MDnsObservatoryDiscovery: () => MDnsObservatoryDiscovery(
        logger: globals.logger,
        flutterUsage: globals.flutterUsage,
      ),
      OperatingSystemUtils: () => OperatingSystemUtils(
        fileSystem: globals.fs,
        logger: globals.logger,
        platform: globals.platform,
        processManager: globals.processManager,
      ),
      OutputPreferences: () => OutputPreferences(
        wrapText: globals.stdio.hasTerminal ?? false,
        showColor:  globals.platform.stdoutSupportsAnsi,
        stdio: globals.stdio,
      ),
      PersistentToolState: () => PersistentToolState(
        fileSystem: globals.fs,
        logger: globals.logger,
        platform: globals.platform,
      ),
      ProcessInfo: () => ProcessInfo(globals.fs),
      ProcessManager: () => ErrorHandlingProcessManager(
        delegate: const LocalProcessManager(),
        platform: globals.platform,
      ),
      ProcessUtils: () => ProcessUtils(
        processManager: globals.processManager,
        logger: globals.logger,
      ),
      Pub: () => Pub(
        fileSystem: globals.fs,
        logger: globals.logger,
        processManager: globals.processManager,
        botDetector: globals.botDetector,
        platform: globals.platform,
        usage: globals.flutterUsage,
      ),
      ShutdownHooks: () => ShutdownHooks(logger: globals.logger),
      Stdio: () => Stdio(),
      SystemClock: () => const SystemClock(),
      Usage: () => Usage(
        runningOnBot: runningOnBot,
        firstRunMessenger: FirstRunMessenger(persistentToolState: globals.persistentToolState),
      ),
      UserMessages: () => UserMessages(),
      VisualStudioValidator: () => VisualStudioValidator(
        userMessages: globals.userMessages,
        visualStudio: VisualStudio(
          fileSystem: globals.fs,
          platform: globals.platform,
          logger: globals.logger,
          processManager: globals.processManager,
        )
      ),
      WebWorkflow: () => WebWorkflow(
        featureFlags: featureFlags,
        platform: globals.platform,
      ),
      WindowsWorkflow: () => WindowsWorkflow(
        featureFlags: featureFlags,
        platform: globals.platform,
      ),
      Xcode: () => Xcode(
        logger: globals.logger,
        processManager: globals.processManager,
        platform: globals.platform,
        fileSystem: globals.fs,
        xcodeProjectInterpreter: globals.xcodeProjectInterpreter,
      ),
      XCDevice: () => XCDevice(
        processManager: globals.processManager,
        logger: globals.logger,
        artifacts: globals.artifacts,
        cache: globals.cache,
        platform: globals.platform,
        xcode: globals.xcode,
        iproxy: IProxy(
          iproxyPath: globals.artifacts.getArtifactPath(
            Artifact.iproxy,
            platform: TargetPlatform.ios,
          ),
          logger: globals.logger,
          processManager: globals.processManager,
          dyLdLibEntry: globals.cache.dyLdLibEntry,
        ),
      ),
      XcodeProjectInterpreter: () => XcodeProjectInterpreter(
        logger: globals.logger,
        processManager: globals.processManager,
        platform: globals.platform,
        fileSystem: globals.fs,
        usage: globals.flutterUsage,
      ),
    },
  );
}
