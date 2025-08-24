import { type TurboModule, TurboModuleRegistry } from 'react-native';
import type { Double } from 'react-native/Libraries/Types/CodegenTypes';

export interface Spec extends TurboModule {
  isPencilKitAvailable(): boolean;
  isiOSEqualsOrGreaterThan17(): boolean;
  isiOSEqualsOrGreaterThan16_4(): boolean;
  getAvailableTools(): string[];
  getBase64Data(viewId: Double): Promise<string>;
  getBase64PngData(
    viewId: Double,
    scale: Double,
    x: Double,
    y: Double,
    width: Double,
    height: Double,
  ): Promise<string>;
  getBase64JpegData(viewId: Double, scale: Double, compression: Double): Promise<string>;
  getDrawingBounds(
    viewId: Double,
  ): Promise<{ x: Double; y: Double; width: Double; height: Double }>;
  saveDrawing(viewId: Double, path: string): Promise<string>;
  loadDrawing(viewId: Double, path: string): Promise<void>;
  loadBase64Data(viewId: Double, base64: string): Promise<void>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('RNPencilKitUtil');
