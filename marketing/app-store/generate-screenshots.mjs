import fs from "node:fs/promises";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const sharp = require("sharp");

const root = path.dirname(new URL(import.meta.url).pathname);
const sourceDirectory = path.join(root, "source");
const screenshotDirectory = path.join(root, "screenshots", "en-US");

const width = 1320;
const height = 2868;
const screenWidth = 1020;
const screenHeight = 2218;
const screenLeft = 150;
const screenTop = 620;

const outputProfiles = [
  { directory: "iPhone-6.9", width: 1320, height: 2868 },
  { directory: "iPhone-6.5", width: 1284, height: 2778 },
];

const slides = [
  {
    number: "01",
    source: "near-you.png",
    output: "01-near-you.png",
    headline: ["Know what’s happening", "nearby."],
    subhead: "311 requests, public permits and local trends—at a glance.",
    colors: ["#4F46E5", "#A855F7", "#F43F5E"],
  },
  {
    number: "02",
    source: "map.png",
    output: "02-map.png",
    headline: ["See the city change", "in real time."],
    subhead: "Explore a colorful, filterable map of the work around you.",
    colors: ["#0F766E", "#06B6D4", "#4F46E5"],
  },
  {
    number: "03",
    source: "requests.png",
    output: "03-requests.png",
    headline: ["Requests and permits.", "One clear timeline."],
    subhead: "Sort nearby public records and open the details that matter.",
    colors: ["#C2410C", "#F97316", "#EAB308"],
  },
  {
    number: "04",
    source: "places.png",
    output: "04-places.png",
    headline: ["Follow the places", "that matter."],
    subhead: "Save Home, browse by ward, or return to any DC address.",
    colors: ["#7E22CE", "#EC4899", "#F43F5E"],
  },
];

const escapeXML = (value) => value
  .replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;")
  .replaceAll('"', "&quot;");

function backgroundSVG(slide) {
  const [start, middle, end] = slide.colors;
  return Buffer.from(`
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="background" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="${start}"/>
          <stop offset="0.56" stop-color="${middle}"/>
          <stop offset="1" stop-color="${end}"/>
        </linearGradient>
        <radialGradient id="glow" cx="50%" cy="0%" r="85%">
          <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.24"/>
          <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
        </radialGradient>
        <filter id="shadow" x="-30%" y="-20%" width="160%" height="160%">
          <feDropShadow dx="0" dy="32" stdDeviation="36" flood-color="#111827" flood-opacity="0.32"/>
        </filter>
      </defs>
      <rect width="${width}" height="${height}" fill="url(#background)"/>
      <rect width="${width}" height="${height}" fill="url(#glow)"/>
      <circle cx="1160" cy="230" r="330" fill="#FFFFFF" opacity="0.055"/>
      <circle cx="80" cy="560" r="260" fill="#FFFFFF" opacity="0.045"/>

      <g transform="translate(84 72)" fill="#FFFFFF">
        <text x="0" y="33" font-family="Helvetica Neue, Arial, sans-serif" font-size="30" font-weight="700" letter-spacing="5">DC PULSE</text>
        <text x="1100" y="33" text-anchor="end" font-family="Helvetica Neue, Arial, sans-serif" font-size="27" font-weight="700" opacity="0.72">${slide.number} / 04</text>
      </g>

      <g fill="#FFFFFF">
        <text x="84" y="205" font-family="Helvetica Neue, Arial, sans-serif" font-size="82" font-weight="800" letter-spacing="-2">${escapeXML(slide.headline[0])}</text>
        <text x="84" y="300" font-family="Helvetica Neue, Arial, sans-serif" font-size="82" font-weight="800" letter-spacing="-2">${escapeXML(slide.headline[1])}</text>
        <text x="86" y="390" font-family="Helvetica Neue, Arial, sans-serif" font-size="35" font-weight="500" opacity="0.88">${escapeXML(slide.subhead)}</text>
      </g>

      <g transform="translate(88 462)" fill="#FFFFFF" opacity="0.72">
        <text x="0" y="30" font-family="Helvetica Neue, Arial, sans-serif" font-size="36">★</text>
        <text x="48" y="30" font-family="Helvetica Neue, Arial, sans-serif" font-size="36">★</text>
        <text x="96" y="30" font-family="Helvetica Neue, Arial, sans-serif" font-size="36">★</text>
        <rect x="158" y="7" width="132" height="7" rx="3.5"/>
        <rect x="158" y="27" width="132" height="7" rx="3.5"/>
      </g>

      <rect x="${screenLeft - 11}" y="${screenTop - 11}" width="${screenWidth + 22}" height="${screenHeight + 22}" rx="94" fill="#111827" opacity="0.9" filter="url(#shadow)"/>
    </svg>
  `);
}

async function roundedScreen(sourcePath) {
  const screen = await sharp(sourcePath)
    .resize(screenWidth, screenHeight, { fit: "fill" })
    .png()
    .toBuffer();
  const mask = Buffer.from(`
    <svg width="${screenWidth}" height="${screenHeight}" xmlns="http://www.w3.org/2000/svg">
      <rect width="${screenWidth}" height="${screenHeight}" rx="82" fill="#FFFFFF"/>
    </svg>
  `);
  return sharp(screen)
    .composite([{ input: mask, blend: "dest-in" }])
    .png()
    .toBuffer();
}

await Promise.all(outputProfiles.map(({ directory }) =>
  fs.mkdir(path.join(screenshotDirectory, directory), { recursive: true })
));

for (const slide of slides) {
  const sourcePath = path.join(sourceDirectory, slide.source);
  const screen = await roundedScreen(sourcePath);
  const canonicalOutput = await sharp(backgroundSVG(slide))
    .composite([{ input: screen, left: screenLeft, top: screenTop }])
    .flatten({ background: "#FFFFFF" })
    .removeAlpha()
    .png({ compressionLevel: 9, palette: false })
    .toBuffer();

  for (const profile of outputProfiles) {
    const outputPath = path.join(screenshotDirectory, profile.directory, slide.output);
    await sharp(canonicalOutput)
      .resize(profile.width, profile.height, { fit: "cover", position: "centre" })
      .flatten({ background: "#FFFFFF" })
      .removeAlpha()
      .png({ compressionLevel: 9, palette: false })
      .toFile(outputPath);

    const metadata = await sharp(outputPath).metadata();
    if (metadata.width !== profile.width || metadata.height !== profile.height || metadata.hasAlpha) {
      throw new Error(`Invalid App Store output: ${profile.directory}/${slide.output}`);
    }
    console.log(`${profile.directory}/${slide.output}: ${metadata.width}x${metadata.height}, alpha=${metadata.hasAlpha}`);
  }
}
