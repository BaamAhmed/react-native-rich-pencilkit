import type React from 'react';
import { type ComponentType } from 'react';
import type { ViewProps } from 'react-native';
import type {
  DirectEventHandler,
  Double,
  Int32,
  WithDefault,
} from 'react-native/Libraries/Types/CodegenTypes';
import codegenNativeCommands from 'react-native/Libraries/Utilities/codegenNativeCommands';
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';

export interface NativeProps extends ViewProps {
  alwaysBounceVertical: boolean;
  alwaysBounceHorizontal: boolean;
  isRulerActive: boolean;
  backgroundColor: Int32;
  drawingPolicy?: WithDefault<'default' | 'anyinput' | 'pencilonly', 'default'>;
  isOpaque?: boolean;
  contentSize?: {
    width: Double;
    height: Double;
  };

  minimumZoomScale?: Double;
  maximumZoomScale?: Double;
  contentAlignmentPoint?: {
    x: Double;
    y: Double;
  };
  contentInset?: {
    top: Double;
    right: Double;
    bottom: Double;
    left: Double;
  };
  contentAreaBorderWidth?: Double;
  contentAreaBorderColor?: Int32;
  contentAreaBackgroundColor?: Int32;
  allowInfiniteScroll?: boolean;

  onToolPickerVisibilityDidChange?: DirectEventHandler<{}>;
  onToolPickerIsRulerActiveDidChange?: DirectEventHandler<{}>;
  onToolPickerFramesObscuredDidChange?: DirectEventHandler<{}>;
  onToolPickerSelectedToolDidChange?: DirectEventHandler<{}>;
  onCanvasViewDidBeginUsingTool?: DirectEventHandler<{}>;
  onCanvasViewDidEndUsingTool?: DirectEventHandler<{}>;
  onCanvasViewDrawingDidChange?: DirectEventHandler<{}>;
  onCanvasViewDidFinishRendering?: DirectEventHandler<{}>;
  onPencilDoubleTap?: DirectEventHandler<{}>;
}

export interface PencilKitCommands {
  clear: (ref: React.ElementRef<ComponentType>) => void;
  clearUndoStack: (ref: React.ElementRef<ComponentType>) => void;
  showToolPicker: (ref: React.ElementRef<ComponentType>) => void;
  hideToolPicker: (ref: React.ElementRef<ComponentType>) => void;
  redo: (ref: React.ElementRef<ComponentType>) => void;
  undo: (ref: React.ElementRef<ComponentType>) => void;
  setTool: (
    ref: React.ElementRef<ComponentType>,
    toolType: string,
    width?: Double,
    color?: Int32,
  ) => void;
  getTool: (ref: React.ElementRef<ComponentType>) => void;
}

export const Commands: PencilKitCommands = codegenNativeCommands<PencilKitCommands>({
  supportedCommands: [
    'clear',
    'clearUndoStack',
    'showToolPicker',
    'hideToolPicker',
    'redo',
    'undo',
    'setTool',
    'getTool',
  ],
});
export default codegenNativeComponent<NativeProps>('RNPencilKit');
