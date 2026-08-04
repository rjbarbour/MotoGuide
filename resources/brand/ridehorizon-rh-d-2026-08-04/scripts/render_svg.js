const path = require("node:path");

const sharp = require(process.env.RIDEHORIZON_SHARP_PATH || "sharp");

const [inputPath, outputPath, widthText = "512", heightText = widthText] = process.argv.slice(2);
if (!inputPath || !outputPath) {
  throw new Error("Usage: render_svg.js INPUT.svg OUTPUT.png [WIDTH] [HEIGHT]");
}

const width = Number.parseInt(widthText, 10);
const height = Number.parseInt(heightText, 10);
sharp(path.resolve(inputPath), { density: 288 })
  .resize(width, height, { fit: "fill" })
  .png()
  .toFile(path.resolve(outputPath));
