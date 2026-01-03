import { type ForwardedRef, forwardRef } from 'react';
import { type ColorValue, Text, type ViewProps } from 'react-native';
import type { DirectEventHandler, WithDefault } from 'react-native/Libraries/Types/CodegenTypes';

export type PencilKitProps = {
  isRulerActive?: boolean;
  drawingPolicy?: WithDefault<'default' | 'anyinput' | 'pencilonly', 'default'>;
  isOpaque?: boolean;

  // zoom/pan props
  minimumZoomScale?: number;
  maximumZoomScale?: number;
  alwaysBounceVertical?: boolean;
  alwaysBounceHorizontal?: boolean;

  allowInfiniteScroll?: boolean;
  infiniteScrollDirection?: WithDefault<
    'bidirectional' | 'vertical' | 'horizontal',
    'bidirectional'
  >;
  showDebugInfo?: boolean;

  paperTemplate?: WithDefault<'blank' | 'lined' | 'dotted' | 'grid', 'blank'>;
  backgroundColor?: ColorValue;
  pdfPath?: string;

  onToolPickerVisibilityDidChange?: DirectEventHandler<{}>;
  onToolPickerIsRulerActiveDidChange?: DirectEventHandler<{}>;
  onToolPickerFramesObscuredDidChange?: DirectEventHandler<{}>;
  onToolPickerSelectedToolDidChange?: DirectEventHandler<{}>;
  onCanvasViewDidBeginUsingTool?: DirectEventHandler<{}>;
  onCanvasViewDidEndUsingTool?: DirectEventHandler<{}>;
  onCanvasViewDrawingDidChange?: DirectEventHandler<{}>;
  onCanvasViewDidFinishRendering?: DirectEventHandler<{}>;
  onPencilDoubleTap?: DirectEventHandler<{}>;
} & ViewProps;
export type PencilKitTool =
  | 'pen'
  | 'pencil'
  | 'marker'
  | 'select'
  | 'monoline'
  | 'fountainPen'
  | 'watercolor'
  | 'crayon'
  | 'eraserVector'
  | 'eraserBitmap'
  | 'eraserFixedWidthBitmap';
export type PencilKitRef = {
  clear: () => void;
  clearUndoStack: () => void;
  showToolPicker: () => void;
  hideToolPicker: () => void;
  redo: () => void;
  undo: () => void;
  setTool: (params: { toolType: PencilKitTool; width?: number; color?: ColorValue }) => void;
  getTool: () => void;
  saveDrawing: (path: string) => Promise<string>;
  loadDrawing: (path: string) => Promise<void>;
  getBase64Data: () => Promise<string>;
  getBase64PngData: (params?: {
    scale?: number;
    x?: number;
    y?: number;
    width?: number;
    height?: number;
  }) => Promise<string>;
  getDrawingBounds: () => Promise<{
    x: number;
    y: number;
    width: number;
    height: number;
  }>;
  getBase64JpegData: (params?: { scale?: number; compression?: number }) => Promise<string>;
  loadBase64Data: (base64: string) => Promise<void>;
};
// eslint-disable-next-line @typescript-eslint/no-unused-vars
export const PencilKit = forwardRef((props: PencilKitProps, ref: ForwardedRef<PencilKitRef>) => {
  return <Text>{"This platform doesn't support pencilkit"}</Text>;
});
