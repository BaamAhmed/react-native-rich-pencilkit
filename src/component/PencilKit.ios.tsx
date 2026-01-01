import { type ForwardedRef, forwardRef, useImperativeHandle, useRef } from 'react';
import { findNodeHandle, processColor, Text } from 'react-native';

import { type PencilKitProps, type PencilKitRef, PencilKitUtil } from '../index';
import NativeRNPencilKitUtil from '../spec/NativeRNPencilKitUtil';
import NativePencilKitView, { Commands } from '../spec/RNPencilKitNativeComponent';

function PencilKitComponent(
  {
    alwaysBounceHorizontal = true,
    alwaysBounceVertical = true,
    isRulerActive = false,
    drawingPolicy = 'default',
    backgroundColor,
    isOpaque = true,
    contentSize,
    minimumZoomScale = 1.0,
    maximumZoomScale = 1.0,
    contentAlignmentPoint,
    contentInset,
    contentAreaBorderWidth,
    contentAreaBorderColor,
    contentAreaBackgroundColor,
    pageBackgroundImage,
    allowInfiniteScroll = false,
    infiniteScrollDirection = 'bidirectional',
    showDebugInfo = false,
    showLinedPaper = false,
    onToolPickerFramesObscuredDidChange,
    onToolPickerIsRulerActiveDidChange,
    onToolPickerSelectedToolDidChange,
    onToolPickerVisibilityDidChange,
    onCanvasViewDidBeginUsingTool,
    onCanvasViewDidEndUsingTool,
    onCanvasViewDidFinishRendering,
    onCanvasViewDrawingDidChange,
    ...rest
  }: PencilKitProps,
  ref: ForwardedRef<PencilKitRef>,
) {
  const nativeRef = useRef(null);

  useImperativeHandle(
    ref,
    () => ({
      clear: () => Commands.clear(nativeRef.current!),
      clearUndoStack: () => Commands.clear(nativeRef.current!),
      showToolPicker: () => Commands.showToolPicker(nativeRef.current!),
      hideToolPicker: () => Commands.hideToolPicker(nativeRef.current!),
      redo: () => Commands.redo(nativeRef.current!),
      undo: () => Commands.undo(nativeRef.current!),
      saveDrawing: async (path) => {
        const handle = findNodeHandle(nativeRef.current) ?? -1;

        return NativeRNPencilKitUtil.saveDrawing(handle, path);
      },
      loadDrawing: async (path) => {
        const handle = findNodeHandle(nativeRef.current) ?? -1;

        return NativeRNPencilKitUtil.loadDrawing(handle, path);
      },
      getDrawingBounds: async () => {
        const handle = findNodeHandle(nativeRef.current) ?? -1;

        return NativeRNPencilKitUtil.getDrawingBounds(handle);
      },
      getBase64Data: async () => {
        const handle = findNodeHandle(nativeRef.current) ?? -1;

        return NativeRNPencilKitUtil.getBase64Data(handle);
      },
      getBase64PngData: async (
        { scale = 0, x = 0, y = 0, width = 0, height = 0 } = {
          scale: 0,
          x: 0,
          y: 0,
          width: 0,
          height: 0,
        },
      ) => {
        const handle = findNodeHandle(nativeRef.current) ?? -1;
        return NativeRNPencilKitUtil.getBase64PngData(handle, scale, x, y, width, height).then(
          (d) => `data:image/png;base64,${d}`,
        );
      },
      getBase64JpegData: async ({ scale = 0, compression = 0 } = { scale: 0, compression: 0 }) => {
        const handle = findNodeHandle(nativeRef.current) ?? -1;

        return NativeRNPencilKitUtil.getBase64JpegData(handle, scale, compression).then(
          (d) => `data:image/jpeg;base64,${d}`,
        );
      },
      loadBase64Data: async (base64) => {
        const handle = findNodeHandle(nativeRef.current) ?? -1;

        return NativeRNPencilKitUtil.loadBase64Data(handle, base64);
      },
      setTool: ({ color, toolType, width }) =>
        Commands.setTool(
          nativeRef.current!,
          toolType,
          width ?? 0,
          color ? (processColor(color) as number) : 0,
        ),
      getTool: () => Commands.getTool(nativeRef.current!),
    }),
    [],
  );

  if (!PencilKitUtil.isPencilKitAvailable()) {
    return (
      <Text>{"This iOS version doesn't support pencilkit. The minimum requirement is 14.0"}</Text>
    );
  }

  return (
    <NativePencilKitView
      ref={nativeRef}
      {...{
        alwaysBounceHorizontal,
        alwaysBounceVertical,
        isRulerActive,
        drawingPolicy,
        backgroundColor: processColor(backgroundColor) as number,
        isOpaque,
        contentSize,
        minimumZoomScale,
        maximumZoomScale,
        contentAlignmentPoint,
        contentInset,
        contentAreaBorderWidth,
        contentAreaBorderColor: processColor(contentAreaBorderColor) as number,
        contentAreaBackgroundColor: processColor(contentAreaBackgroundColor) as number,
        pageBackgroundImage,
        allowInfiniteScroll,
        infiniteScrollDirection,
        showDebugInfo,
        showLinedPaper,
        onToolPickerFramesObscuredDidChange,
        onToolPickerIsRulerActiveDidChange,
        onToolPickerSelectedToolDidChange,
        onToolPickerVisibilityDidChange,
        onCanvasViewDidBeginUsingTool,
        onCanvasViewDidEndUsingTool,
        onCanvasViewDidFinishRendering,
        onCanvasViewDrawingDidChange,
      }}
      {...rest}
    />
  );
}

export const PencilKit = forwardRef(PencilKitComponent);
