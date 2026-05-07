enum DrawTool {
  // ✏️ BASIC DRAWING
  freeLine,
  straightLine,
  smoothLine,

  // 📐 SHAPES
  rectangle,
  square,
  circle,
  ellipse,
  triangle,
  polygon,

  // 🧲 SELECTION
  select,
  multiSelect,
  boxSelect,

  // 🧽 EDITING
  move,
  resize,
  rotate,
  delete,
  eraser,
  magicEraser, // 🤖 AI Object Removal

  // 🎨 STYLE / FILL
  fillTool,
  colorPicker,
  strokeWidth,

  // 🏠 ROOM DESIGN SPECIFIC
  wall,
  door,
  window,
  furniturePlace,

  // 🤖 ADVANCED (FUTURE AI/AR)
  snapToGrid,
  autoWallDetect,
  autoRoomScan,
}
