import fs from "node:fs/promises";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const sharp = require("sharp");

const root = path.dirname(new URL(import.meta.url).pathname);
const sourceDirectory = path.join(root, "source");
const screenshotDirectory = path.join(root, "screenshots", "en-US");
const displayMaskPath = path.join(root, "device-masks", "iphone-17-pro-display-alpha.png");

const width = 1320;
const height = 2868;
// These proportions are measured from Apple Simulator's iPhone 17 Pro window.
// The display itself still uses Simulator's exact alpha mask below.
const screenWidth = 850;
const screenHeight = 1848;
const screenLeft = 235;
const screenTop = 850;
const sourceWidth = 1206;
const sourceHeight = 2622;

const outputProfiles = [
  { directory: "iPhone-6.9", width: 1320, height: 2868 },
  { directory: "iPhone-6.5", width: 1284, height: 2778 },
];

const slides = [
  {
    number: "01",
    source: "near-you.png",
    output: "01-near-you.png",
    headline: ["Your neighborhood,", "at a glance."],
    subhead: "Real public data in a familiar iPhone experience.",
    colors: ["#4338CA", "#7C3AED", "#DB2777"],
  },
  {
    number: "02",
    source: "map.png",
    output: "02-map.png",
    headline: ["See what’s changing", "around you."],
    subhead: "Explore nearby requests and permits on one clear map.",
    colors: ["#075985", "#2563EB", "#6D28D9"],
  },
  {
    number: "03",
    source: "requests.png",
    output: "03-requests.png",
    headline: ["Requests and permits,", "together."],
    subhead: "Sort public activity and open the details that matter.",
    colors: ["#C2410C", "#EA580C", "#DB2777"],
  },
  {
    number: "04",
    source: "places.png",
    output: "04-places.png",
    headline: ["Follow the places", "that matter."],
    subhead: "Save Home, follow places and return anytime.",
    colors: ["#6D28D9", "#9333EA", "#E11D48"],
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
          <stop offset="0.55" stop-color="${middle}"/>
          <stop offset="1" stop-color="${end}"/>
        </linearGradient>
        <radialGradient id="glow" cx="50%" cy="0%" r="90%">
          <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.28"/>
          <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
        </radialGradient>
        <filter id="deviceShadow" x="-30%" y="-20%" width="160%" height="160%">
          <feDropShadow dx="0" dy="36" stdDeviation="42" flood-color="#130B2D" flood-opacity="0.38"/>
        </filter>
      </defs>
      <rect width="${width}" height="${height}" fill="url(#background)"/>
      <rect width="${width}" height="${height}" fill="url(#glow)"/>
      <circle cx="1190" cy="190" r="360" fill="#FFFFFF" opacity="0.09"/>
      <circle cx="60" cy="730" r="290" fill="#FFFFFF" opacity="0.055"/>
      <path d="M-120 530 C220 310 440 570 760 350 S1170 190 1460 330" fill="none" stroke="#FFFFFF" stroke-opacity="0.075" stroke-width="92"/>

      <g fill="#FFFFFF">
        <text x="72" y="78" font-family="Helvetica Neue, Arial, sans-serif" font-size="32" font-weight="750" letter-spacing="4.5">DC PULSE</text>
        <text x="1248" y="78" text-anchor="end" font-family="Helvetica Neue, Arial, sans-serif" font-size="28" font-weight="650" opacity="0.76">${slide.number} / 04</text>
        <g transform="translate(72 116)" opacity="0.94">
          <text x="0" y="26" font-family="Helvetica Neue, Arial, sans-serif" font-size="28" letter-spacing="8">★★★</text>
          <rect x="1" y="42" width="130" height="6" rx="3"/>
          <rect x="1" y="57" width="130" height="6" rx="3"/>
        </g>
        <text x="72" y="300" font-family="Helvetica Neue, Arial, sans-serif" font-size="106" font-weight="800" letter-spacing="-3">${escapeXML(slide.headline[0])}</text>
        <text x="72" y="416" font-family="Helvetica Neue, Arial, sans-serif" font-size="106" font-weight="800" letter-spacing="-3">${escapeXML(slide.headline[1])}</text>
        <text x="76" y="495" font-family="Helvetica Neue, Arial, sans-serif" font-size="39" font-weight="520" opacity="0.92">${escapeXML(slide.subhead)}</text>
      </g>

      <!-- Proportions and controls follow Apple Simulator's iPhone 17 Pro bezel. -->
      <g filter="url(#deviceShadow)">
        <rect x="185" y="1030" width="11" height="112" rx="5.5" fill="#5A5B5F"/>
        <rect x="185" y="1200" width="11" height="164" rx="5.5" fill="#5A5B5F"/>
        <rect x="185" y="1412" width="11" height="164" rx="5.5" fill="#5A5B5F"/>
        <rect x="1124" y="1184" width="11" height="238" rx="5.5" fill="#5A5B5F"/>
        <rect x="194" y="814" width="932" height="1920" rx="180" fill="#707174"/>
        <rect x="201" y="821" width="918" height="1906" rx="173" fill="#111214"/>
        <rect x="218" y="838" width="884" height="1872" rx="154" fill="#000000"/>
        <path d="M226 1005 C226 902 282 846 395 838" fill="none" stroke="#FFFFFF" stroke-opacity="0.12" stroke-width="4" stroke-linecap="round"/>
      </g>
    </svg>
  `);
}

async function displayMask() {
  const { data, info } = await sharp(displayMaskPath)
    .extractChannel(0)
    .raw()
    .toBuffer({ resolveWithObject: true });

  return sharp({
    create: { width: sourceWidth, height: sourceHeight, channels: 3, background: "#FFFFFF" },
  })
    .joinChannel(data, { raw: { width: info.width, height: info.height, channels: 1 } })
    .png()
    .toBuffer();
}

async function maskedScreen(sourcePath, mask) {
  const metadata = await sharp(sourcePath).metadata();
  if (metadata.width !== sourceWidth || metadata.height !== sourceHeight) {
    throw new Error(`Source capture must be ${sourceWidth}x${sourceHeight}: ${sourcePath}`);
  }

  const nativeScreen = await sharp(sourcePath)
    .ensureAlpha()
    .composite([{ input: mask, blend: "dest-in" }])
    .png()
    .toBuffer();

  return sharp(nativeScreen)
    .resize(screenWidth, screenHeight, { fit: "fill" })
    .png()
    .toBuffer();
}

await Promise.all(outputProfiles.map(({ directory }) =>
  fs.mkdir(path.join(screenshotDirectory, directory), { recursive: true })
));

const mask = await displayMask();

for (const slide of slides) {
  const sourcePath = path.join(sourceDirectory, slide.source);
  const screen = await maskedScreen(sourcePath, mask);
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
