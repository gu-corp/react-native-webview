import { NativeModules } from 'react-native';

interface UtilityWebViewT {
  removeNonPersistentStoreIncognito: () => void;
}

const { UtilityWebView } = NativeModules;
export default UtilityWebView as UtilityWebViewT;
