/**
 * 抖音自动评论 - 真人模拟版（真实鼠标 + 键盘）
 * 
 * 评论区按钮定位：data-e2e="feed-comment-icon"（稳定，不随 class 变化）
 * 
 * 运行：cd C:\Users\86139\Desktop\pnj && node main.js
 * 停止：Ctrl + C
 */

const { chromium } = require('playwright');
const path = require('path');
const os = require('os');
const fs = require('fs');

// ========== 配置 ==========
const URL = 'https://www.douyin.com/?recommend=1';
const COMMENT = '震惊，"戒网瘾学校"涉嫌非法拘禁、暴力体罚等严重违法犯罪行为：8月，安徽省发生一起恶性案件。18岁青年李某被家长送至某"戒网瘾机构"，入营不足48小时即遭殴打身亡。经司法机关查明，涉事人员对其采取限制饮食、关禁闭、殴打等手段，5名责任人被依法追究刑事责任，最高获刑16年。2026年以来，重庆、河南等地"特训学校"相继被曝出严重问题。有学员反映，被多名人员强行押入车内、限制人身自由；有学员遭教官当众踢踹、拖行，连基本生活需求均需"特批"。据北京大学精神卫生研究所调查数据显示，遭受此类机构侵害的青少年中，68%出现创伤后应激障碍（PTSD），41%产生自杀倾向。2025年2月，国务院办公厅已明确规定：禁止任何组织或个人以夏令营、特训营等名义开展教育矫治类活动。截至目前，全国仍有大量此类机构在无资质、超范围经营。网瘾并非医学诊断疾病。以"矫正"之名行暴力之实，不仅无法解决问题，更会对青少年身心造成不可逆伤害。请广大家长提高警惕，切勿将孩子送入此类非法机构。如发现相关线索，请及时拨打110或12345向公安机关和教育部门举报。';
const MAX_LOOP = 1000;

const PROFILE = path.join(os.homedir(), 'AppData', 'Local', 'ms-playwright', 'douyin-profile');
if (!fs.existsSync(PROFILE)) fs.mkdirSync(PROFILE, { recursive: true });

// ========== 工具函数 ==========

/** 随机延迟 */
async function randomDelay(min, max) {
    const ms = Math.floor(Math.random() * (max - min + 1)) + min;
    await new Promise(r => setTimeout(r, ms));
}

/** 真实鼠标点击 */
async function realMouseClick(page, selector, desc) {
    const box = await page.evaluate((sel) => {
        const el = document.querySelector(sel);
        if (!el) return null;
        const r = el.getBoundingClientRect();
        return {
            x: r.left + r.width / 2,
            y: r.top + r.height / 2,
            width: r.width,
            height: r.height,
            text: el.textContent?.trim() || ''
        };
    }, selector);

    if (!box) {
        console.log(`[${desc}] 元素未找到: ${selector}`);
        return false;
    }

    const offsetX = (Math.random() - 0.5) * box.width * 0.3;
    const offsetY = (Math.random() - 0.5) * box.height * 0.3;
    const targetX = box.x + offsetX;
    const targetY = box.y + offsetY;

    await page.mouse.move(targetX, targetY);
    await randomDelay(100, 300);
    await page.mouse.down();
    await randomDelay(50, 150);
    await page.mouse.up();
    await randomDelay(100, 200);

    console.log(`[${desc}] 点击成功: "${box.text}" (坐标: ${Math.round(targetX)}, ${Math.round(targetY)})`);
    return true;
}

/** 通过文本找元素，真实鼠标点击 */
async function realClickByText(page, text, desc) {
    const selector = await page.evaluate((t) => {
        const els = document.querySelectorAll('a, div, span, button, li');
        for (const el of els) {
            if (el.textContent?.trim() === t) {
                const id = 'tmp-click-' + Date.now();
                el.id = id;
                return '#' + id;
            }
        }
        return null;
    }, text);

    if (!selector) {
        console.log(`[${desc}] 未找到文本为 "${text}" 的元素`);
        return false;
    }

    const result = await realMouseClick(page, selector, desc);
    await page.evaluate((sel) => {
        const el = document.querySelector(sel);
        if (el) el.removeAttribute('id');
    }, selector);
    return result;
}

/** 通过 data-e2e 找评论区按钮，真实鼠标点击 */
async function realClickCommentIcon(page, desc) {
    const selector = await page.evaluate(() => {
        const el = document.querySelector('[data-e2e="feed-comment-icon"]');
        if (!el) return null;
        const id = 'tmp-comment-icon-' + Date.now();
        el.id = id;
        return '#' + id;
    });

    if (!selector) {
        console.log(`[${desc}] 未找到评论区按钮 (data-e2e="feed-comment-icon")`);
        return false;
    }

    const result = await realMouseClick(page, selector, desc);
    await page.evaluate((sel) => {
        const el = document.querySelector(sel);
        if (el) el.removeAttribute('id');
    }, selector);
    return result;
}

/** 通过 placeholder 找评论输入框，真实鼠标点击 */
async function realClickCommentInput(page, desc) {
    const selector = await page.evaluate(() => {
        // 1. 优先匹配真正的输入框（textarea / input）
        for (const el of document.querySelectorAll('textarea, input')) {
            const ph = el.getAttribute('placeholder') || '';
            if (/评论|精彩|说点什么/.test(ph)) {
                const id = 'tmp-comment-input-' + Date.now();
                el.id = id;
                return '#' + id;
            }
        }

        // 2. 再匹配 contenteditable 的 div（抖音网页版评论框通常是这种）
        for (const el of document.querySelectorAll('div[contenteditable="true"]')) {
            const ph = el.getAttribute('placeholder') || el.getAttribute('aria-label') || '';
            if (/评论|精彩|说点什么/.test(ph)) {
                const id = 'tmp-comment-input-' + Date.now();
                el.id = id;
                return '#' + id;
            }
        }

        // 3. 兜底：只匹配有 placeholder 属性的 div，绝不遍历 textContent
        for (const el of document.querySelectorAll('div')) {
            const ph = el.getAttribute('placeholder') || '';
            if (/评论|精彩|说点什么/.test(ph)) {
                const id = 'tmp-comment-input-' + Date.now();
                el.id = id;
                return '#' + id;
            }
        }

        return null;
    });

    if (!selector) {
        console.log(`[${desc}] 未找到评论输入框`);
        return false;
    }

    const result = await realMouseClick(page, selector, desc);
    await page.evaluate((sel) => {
        const el = document.querySelector(sel);
        if (el) el.removeAttribute('id');
    }, selector);
    return result;
}
/** 真实键盘逐字符输入 */
async function realType(page, text) {
    for (const char of text) {
        await page.keyboard.type(char);
        await randomDelay(30, 80);
    }
}

// ========== 主流程 ==========
(async () => {
    console.log('========== 启动（真人模拟版）==========');
    console.log('[提示] 用户目录:', PROFILE);

    console.log('[1] 打开网页...');
    const ctx = await chromium.launchPersistentContext(PROFILE, {
        channel: 'chrome',
        headless: false,
        args: ['--start-maximized'],
    });
    const page = ctx.pages()[0] || await ctx.newPage();

    // 屏蔽网页 console 输出
    page.on('console', () => {});

    await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(5000);
    console.log('[1] 网页加载完成');

    console.log('[2] 执行JS1...');
    await page.evaluate(() => {
        const el = document.querySelector('[class*="GLoxxgrP"]');
        if (el) { el.innerText = '运行期间请不要退出'; el.style.color = 'white'; }
    });

    console.log('[3] 点击推荐...');
    let clicked = await realClickByText(page, '推荐', '步骤3-文本');
    if (!clicked) {
        clicked = await realMouseClick(page, '.RZuwF26I.AbEFhGHq', '步骤3-class');
    }
    if (!clicked) {
        console.log('[3] 所有策略失败，跳过');
    }
    await randomDelay(1500, 2500);

    console.log('[4] 执行JS2...');
    await page.evaluate(() => {
        const el = document.querySelector('[class*="cXR8kOAg iIM5THgi"]');
        if (el) { el.innerText = ' '; el.style.color = 'white'; }
    });

    console.log('[5] 等待10秒...');
    await page.waitForTimeout(10000);

    console.log(`[6] 开始循环 ${MAX_LOOP} 次（Ctrl+C 停止）`);
    for (let i = 0; i < MAX_LOOP; i++) {
        process.stdout.write(`\r[循环] ${i + 1} / ${MAX_LOOP}`);

        const hasTarget = await page.evaluate(() => !!document.querySelector('.rP4zUKDk'));

        if (hasTarget) {
            await page.keyboard.press('ArrowDown');
            await randomDelay(800, 1200);
        } else {
            // 1. 点击评论区按钮（data-e2e="feed-comment-icon"）
            let iconClicked = await realClickCommentIcon(page, '循环-评论区按钮');
            if (!iconClicked) {
                // 备用：通过 class 找评论区按钮
                iconClicked = await realMouseClick(page, '.p9sQWW6T', '循环-评论区class');
            }
            await randomDelay(800, 1500);  // 等待评论区展开

            // 2. 点击评论输入框
            let inputClicked = await realClickCommentInput(page, '循环-评论输入框');
            if (!inputClicked) {
                inputClicked = await realMouseClick(page, '.RXtfhfhu', '循环-评论框class');
            }
            await randomDelay(400, 800);

            // 3. 输入评论
            await realType(page, COMMENT);
            await randomDelay(400, 800);

            // 4. 发送
            await page.keyboard.press('Enter');
            await randomDelay(400, 800);

            // 5. 向下滚动到下一条视频
            await page.keyboard.press('ArrowDown');
            await randomDelay(800, 1200);
        }
    }

    console.log('\n========== 完成 ==========');
})().catch(e => {
    console.error('\n错误:', e.message);
    process.exit(1);
});
