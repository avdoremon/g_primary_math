// Dựng biểu tượng app (PNG) từ logo SVG. Chạy: node tool/render_icons.js
// Cần Playwright (Chromium). Mở từng SVG bằng file:// (không dùng setContent: trang about:blank
// không được phép đọc file cục bộ, ảnh sẽ rỗng).
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const brand = path.join(root, 'assets/svg/brand');
const res = path.join(root, 'android_overlay/app/src/main/res');
const dens = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };

(async () => {
  const browser = await chromium.launch();
  async function shot(svgFile, size, out) {
    const page = await browser.newPage({ viewport: { width: size, height: size } });
    await page.goto('file://' + path.join(brand, svgFile));
    // Tài liệu là SVG thuần (không có <head>): đặt kích thước trên thẻ gốc.
    await page.evaluate((s) => {
      const svg = document.documentElement;
      svg.setAttribute('width', s);
      svg.setAttribute('height', s);
    }, size);
    fs.mkdirSync(path.dirname(out), { recursive: true });
    await page.screenshot({ path: out, omitBackground: true, clip: { x: 0, y: 0, width: size, height: size } });
    await page.close();
  }
  for (const [d, k] of Object.entries(dens)) {
    await shot('logo_mark.svg', Math.round(48 * k), path.join(res, `mipmap-${d}/ic_launcher.png`));
    await shot('logo_foreground.svg', Math.round(108 * k), path.join(res, `mipmap-${d}/ic_launcher_foreground.png`));
  }
  await shot('logo_mark.svg', 512, path.join(root, 'docs/brand/logo_512.png'));
  await browser.close();
})();
