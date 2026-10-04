// Renders render.html frame by frame with headless Chrome (puppeteer-core) into frames/%05d.jpg
const puppeteer = require('puppeteer-core');
const fs = require('fs'); const path = require('path');
const V = __dirname;
const plan = JSON.parse(fs.readFileSync(path.join(V, 'plan.json'), 'utf8'));
const only = process.argv[2] ? process.argv[2].split(',').map(Number) : null;   // e.g. "0,150,420" (frame numbers)
const outDir = path.join(V, only ? 'preview' : 'frames');
fs.mkdirSync(outDir, { recursive: true });
(async () => {
  const browser = await puppeteer.launch({
    executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: 'new', args: ['--allow-file-access-from-files', '--disable-web-security', '--hide-scrollbars', '--force-color-profile=srgb'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(V, 'render.html'), { waitUntil: 'networkidle0' });
  await page.evaluate(() => document.fonts.ready);
  await page.evaluate((p) => window.setPlan(p), plan);
  const frames = only || plan.frames.map((f) => f.f);
  const t0 = Date.now();
  for (const f of frames) {
    await page.evaluate((i) => window.renderFrame(i), f);
    await page.screenshot({ path: path.join(outDir, String(f).padStart(5, '0') + '.jpg'), type: 'jpeg', quality: 93 });
    if (!only && f % 150 === 0) console.log('frame', f, ((Date.now() - t0) / 1000).toFixed(1) + 's');
  }
  await browser.close();
  console.log('done', frames.length, 'frames in', ((Date.now() - t0) / 1000).toFixed(1), 's');
})().catch((e) => { console.error(e); process.exit(1); });
