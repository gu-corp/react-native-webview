import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';
import { Double } from 'react-native/Libraries/Types/CodegenTypes';

export interface Spec extends TurboModule {
  isFileUploadSupported(): Promise<boolean>;
  shouldStartLoadWithLockIdentifier(
    shouldStart: boolean,
    lockIdentifier: Double
  ): void;

  // #region Lunascape
  // Adblock
  addAdblockRulesFromAsset(name: string, assetPath: string): Promise<boolean>;
  addAdblockRules(name: string, rules: string): Promise<boolean>;
  removeAdblockRules(name: string, rules: string): Promise<boolean>;

  // Download manager
  getDownloadingFiles(): Promise<Object>;
  deleteDownloadingFileById(downloadId: Double): Promise<boolean>;
  pauseDownloadingFileById(downloadId: Double): void;
  resumeDownloadingFileById(
    downloadId: Double,
    downloadFolderConfig: string
  ): Promise<boolean>;
  // #endregion Lunascape
}

export default TurboModuleRegistry.getEnforcing<Spec>('RNCWebViewModule');
