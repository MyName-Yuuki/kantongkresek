#!/usr/bin/env node
import inquirer from 'inquirer';
import chalk from 'chalk';
import boxen from 'boxen';
import figlet from 'figlet';
import ora from 'ora';
import {execSync} from 'child_process';
import {hrtime} from 'process';
import os from 'os';
import fs from 'fs';
import {spawn} from 'child_process';
import {
  generateLicense,
  verifyLicense,
  loadLicense,
  saveLicense,
  clearLicense,
} from './lib/license.js';

const GITHUB_USER = 'MyName-Yuuki';
const GITHUB_REPO = 'kantongkresek';
const BRANCH      = 'main';
const BASE_URL    = `https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${BRANCH}/scripts/`;
const VERSION     = '1.3.2';

// ---- Fetch latest version from remote ----
function fetchLatestVersion() {
  try {
    const raw = execSync(
      `curl -fsSL --max-time 5 https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${BRANCH}/version.txt`,
      {stdio: 'pipe', shell: '/bin/bash'}
    ).toString().trim();
    return /^v?\d+(?:\.\d+){0,2}$/.test(raw) ? raw.replace(/^v/, '') : null;
  } catch {
    return null; // return null if fetch fails, not a version string
  }
}
const REMOTE_VERSION = fetchLatestVersion(); // null if can't reach GitHub, otherwise a version string like '1.3.1'
const HAS_UPDATE = REMOTE_VERSION !== null && REMOTE_VERSION !== VERSION; // only true if remote is different
const DISPLAY_VERSION = REMOTE_VERSION === VERSION
  ? `v${VERSION}`
  : (REMOTE_VERSION ? `v${REMOTE_VERSION} (this: v${VERSION})` : `v${VERSION}  ☁  update-check unavailable`);

const MENU = [
  {key: '1', label: 'Install Base',         desc: 'PHP, Java, MariaDB — Full Environment',     script: 'install_base.sh'},
  {key: '2', label: 'Configurations',       desc: 'Nginx + PHP-FPM + Packages — Server Stack', scripts: ['configurations.sh', 'configurations_base_I.sh']},
  {key: '3', label: 'Install Database',     desc: 'Provision Schema + Data — Auto Select',     script: null},
  {key: '4', label: 'Install SSL',          desc: 'Let\'s Encrypt via Certbot — HTTPS Ready',  script: 'install_ssl_certbot.sh'},
  {key: '0', label: 'Exit',                 desc: 'Close the installer',                       script: null},
];

function pad(s, n) {
  s = String(s);
  return s + ' '.repeat(Math.max(0, n - s.length));
}

function banner(termWidth) {
  return new Promise((resolve) => {
    figlet.text('KANTONGKRESEK', {font: 'ANSI Shadow', width: Math.min(termWidth, 100)}, (err, logo) => {
      if (err) {
        resolve(chalk.bgHex('#7C3AED').hex('#FFFFFF').bold('  KANTONGKRESEK INSTALLER  '));
        return;
      }
      const lines = [];
      lines.push(chalk.bgHex('#7C3AED').hex('#FFFFFF').bold('  KANTONGKRESEK INSTALLER  '));
      for (const line of logo.split('\n')) {
        lines.push(chalk.hex('#06B6D4').bold(line));
      }
      lines.push(chalk.hex('#06B6D4').bold(`  Kantong Kresek Installer — Base, Lib, System for PWServer`));
      lines.push(chalk.gray(`  ${DISPLAY_VERSION}  •  SSH Friendly  •  Server Deploy`));
      resolve(lines.join('\n'));
    });
  });
}

function statusBar(online, license) {
  // License status icon + label
  const licBadge = license?.activated
    ? chalk.hex('#10B981').bold('◆ ACTIVATED')
    : license
      ? chalk.hex('#F59E0B').bold('◇ LICENSE')
      : chalk.hex('#EF4444').bold('○ UNLICENSED');

  const licType = license?.activated
    ? chalk.hex('#10B981')(license.type || 'permanent')
    : chalk.gray('—');

  const items = [
    licBadge,
    chalk.gray('•'),
    licType,
    chalk.gray('•'),
    chalk.hex('#06B6D4').bold(`user:${process.env.USER || 'Kantong'}`),
    chalk.gray('•'),
    chalk.hex('#F59E0B').bold(`host:${process.env.HOSTNAME || 'Kresek'}`),
    chalk.gray('•'),
    chalk.hex('#9CA3AF').bold(`${DISPLAY_VERSION}`),
  ];
  return boxen(items.join('  '), {
    padding: {left: 1, right: 1},
    borderStyle: 'single',
    borderColor: license?.activated ? '#10B981' : (online ? '#7C3AED' : '#EF4444'),
  });
}

function menuPanel(termWidth) {
  const W = Math.min(termWidth - 6, 68);
  const items = MENU.map(it => {
    const key = chalk.hex('#F59E0B').bold(`[${it.key}]`);
    const name = chalk.bold(pad(it.label, 20));
    const sep = chalk.hex('#7C3AED')('◆');
    const desc = chalk.gray(it.desc);
    return `  ${key} ${name} ${sep} ${desc}`;
  });
  const separator = chalk.hex('#7C3AED').dim('  ' + '─'.repeat(W - 4));
  const footer = chalk.gray(`  ${'↑/↓ to navigate  •  Enter to select  •  or type the number'}`);

  return boxen([
    chalk.hex('#F59E0B').bold('  ✦ MAIN MENU') + chalk.gray(`  ·  Kantong Kresek Installer Base, Lib, System`),
    chalk.hex('#9CA3AF')('      Base For PWServer'),
    separator,
    ...items,
    separator,
    footer,
  ].join('\n'), {
    padding: {top: 1, bottom: 1, left: 2, right: 2},
    margin: {top: 1, bottom: 1, left: 0, right: 0},
    borderStyle: 'round',
    borderColor: '#7C3AED',
  });
}

async function checkOnline() {
  try {
    execSync(`curl -fsSL -o /dev/null -w "%{http_code}" --max-time 5 ${BASE_URL}install_base.sh`, {
      stdio: 'pipe',
      shell: '/bin/bash',
    });
    return true;
  } catch {
    return false;
  }
}

function runScripts(scripts) {
  const list = Array.isArray(scripts) ? scripts : [scripts];
  const promises = [];

  for (const entry of list) {
    const name = typeof entry === 'string' ? entry : entry.script;
    const argList = typeof entry === 'object' && entry.args ? entry.args : [];
    const spinner = ora({
      text: '  ' + chalk.cyan.bold('▶ FETCHING') + '  ' + chalk.yellow(name),
      color: 'cyan',
      spinner: 'dots',
    }).start();

    const promise = (async () => {
      const t0 = hrtime.bigint();
      const dlUrl = `${BASE_URL}${name}`;

      try {
        if (argList.length > 0) {
          // Fetch remote script to temp, run with args
          const tmpDir = os.tmpdir();
          const tmpFile = `${tmpDir}/${name}.${Date.now()}.sh`;
          execSync(`curl -fsSL "${dlUrl}" -o "${tmpFile}" 2>/dev/null`);

          await new Promise((resolve, reject) => {
            const child = spawn('bash', [tmpFile, ...argList], {
              stdio: 'inherit',
            });
            child.on('close', (code) => {
              fs.unlink(tmpFile, () => {});
              if (code !== 0) reject(new Error(`Exit code ${code}`));
              else resolve();
            });
            child.on('error', reject);
          });
        } else {
          // No args: pipe through curl | bash
          execSync(`bash <(curl -fsSL "${dlUrl}")`, {
            stdio: 'inherit',
            shell: '/bin/bash',
          });
        }
        const ms = Number(hrtime.bigint() - t0) / 1e6;
        spinner.succeed(
          chalk.hex('#10B981').bold('  ✓ ' + name) +
          chalk.gray(`  (${(ms / 1000).toFixed(1)}s)`)
        );
      } catch (e) {
        spinner.fail(chalk.hex('#EF4444').bold('  ✗ ' + name));
        throw e;
      }
    })();

    promises.push(promise);
  }

  return Promise.all(promises);
}

async function footerPrompt() {
  await inquirer.prompt([{
    type: 'input',
    name: 'c',
    message: chalk.gray('  Press Enter to return to menu...'),
  }]);
}

// ---- LICENSE ACTIVATION ----
const LICENSE_KEY_RE = /^kantong-[0-9A-F]{8}-[0-9A-F]{8}-[0-9A-F]{8}-[0-9A-F]{8}_kresek$/i;

async function ensureLicense() {
  // Check existing stored license
  const stored = loadLicense();
  if (stored && stored.key) {
    const result = verifyLicense(stored.key);
    if (result.ok) {
      console.log(chalk.hex('#10B981').bold('  License verified. Welcome back.'));
      if (result.expiresAt) {
        console.log(chalk.gray(`  Expires at: ${result.expiresAt}`));
      } else {
        console.log(chalk.gray('  License type: permanent'));
      }
      console.log();
      return true;
    }
    // Expired / tampered — wipe and re-prompt
    try { clearLicense(); } catch {}
    console.log(chalk.yellow('  Previous license expired or invalid. Activating new key...\n'));
  }

  // Activation prompt loop
  while (true) {
    console.clear();
    console.log(chalk.bgHex('#7C3AED').hex('#FFFFFF').bold('  KANTONGKRESEK LICENSE ACTIVATION  '));
    console.log();
    console.log(chalk.gray('  Masukkan license key untuk melanjutkan.'));
    console.log(chalk.gray('  Format: kantong-XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX_kresek'));
    console.log(chalk.gray('  License key ini universal — bisa dipakai di mesin mana saja.'));
    console.log();
    console.log(chalk.gray('  Jika belum memiliki license, hubungi administrator.'));
    console.log();

    const {licenseKey} = await inquirer.prompt([{
      type: 'input',
      name: 'licenseKey',
      message: chalk.bold('  License Key'),
      prefix: chalk.hex('#7C3AED').bold('◆'),
      validate: (input) => {
        const trimmed = (input || '').trim();
        if (!trimmed) return 'License key tidak boleh kosong';
        if (!LICENSE_KEY_RE.test(trimmed)) {
          return 'Format salah. Contoh: kantong-AF3296B6-9FF84DEF-6C237390-C5073FC5_kresek';
        }
        return true;
      },
    }]);

    const result = verifyLicense(licenseKey.trim());
    if (result.ok) {
      saveLicense({
        key: licenseKey.trim(),
        activatedAt: new Date().toISOString(),
        expiresAt: result.expiresAt,
      });

      console.log();
      console.log(boxen(
        chalk.hex('#10B981').bold('  License activated successfully.') + '\n' +
        chalk.gray('  Activated at: ' + new Date().toISOString()) + '\n' +
        chalk.gray('  Expires at:   ' + (result.expiresAt || 'never (permanent)')),
        {padding: 1, margin: 1, borderStyle: 'round', borderColor: '#10B981'}
      ));
      console.log();
      await new Promise(r => setTimeout(r, 2000));
      return true;
    }

    console.log();
    console.log(chalk.hex('#EF4444').bold(`  ✕ ${result.reason}`));
    console.log();
    await inquirer.prompt([{type: 'input', name: 'c', message: chalk.gray('Press Enter untuk coba lagi...')}]);
  }
}

// ---- Self-update function ----
async function selfUpdate(targetVersion) {
  try {
    console.log();
    console.log(boxen(
      chalk.hex('#10B981').bold(`  ✦ Update ${VERSION} → ${targetVersion} available!`) + '\n' +
      chalk.gray('  Performing self-update via npm...') + '\n' +
      chalk.gray('  Please wait, do not close this window.'),
      {padding: 1, margin: 1, borderStyle: 'round', borderColor: '#10B981'}
    ));
    console.log();

    // npm update — run synchronously with inherit stdio
    execSync(`npm update -g kantongkresek 2>&1`, {
      stdio: 'inherit',
      shell: '/bin/bash',
    });

    console.log();
    console.log(boxen(
      chalk.hex('#10B981').bold('  ✓ Update successful!') + '\n' +
      chalk.gray('  Version ') + chalk.green.bold(`v${targetVersion}`) + chalk.gray(' is now installed.') + '\n' +
      chalk.gray('  To start, type: ') + chalk.yellow.bold('kantongkresek'),
      {padding: 1, margin: 1, borderStyle: 'round', borderColor: '#10B981'}
    ));
    console.log();
    process.exit(0);
  } catch (e) {
    console.log();
    console.log(boxen(
      chalk.hex('#EF4444').bold('  ✗ Update failed. Please update manually:') + '\n' +
      chalk.gray('  Run: ') + chalk.white.bold('npm update -g kantongkresek'),
      {padding: 1, margin: 1, borderStyle: 'round', borderColor: '#EF4444'}
    ));
    console.log();
    await new Promise(r => setTimeout(r, 3000));
  }
}

async function checkAndPromptUpdate(localVer, latestVer) {
  // Only prompt once per session — no spam on menu refresh
  console.log();
  console.log(boxen(
    chalk.yellow.bold('  ⚑ Update Available!') + '\n' +
    chalk.gray('  Current version: ') + chalk.green(`v${localVer}`) + '\n' +
    chalk.gray('  Latest version:  ') + chalk.cyan(`v${latestVer}`) + '\n' +
    chalk.gray('  Run ' + chalk.yellow.bold('self-update') + ' to get the latest version?') + '\n' +
    chalk.gray('  Press Enter to skip for now.'),
    {padding: 1, margin: 1, borderStyle: 'round', borderColor: '#F59E0B'}
  ));

  const {confirm} = await inquirer.prompt([{
    type: 'input',
    name: 'confirm',
    message: chalk.yellow.bold('  Update now? (y/N): '),
  }]);

  if (confirm.trim().toLowerCase() === 'y' || confirm.trim().toLowerCase() === 'yes') {
    await selfUpdate(latestVer);
  } else {
    console.log();
  }
}

async function main() {
  const termWidth = process.stdout.columns || 80;
  const online = await checkOnline();

  // ---- LICENSE GATE ----
  const activated = await ensureLicense();
  if (!activated) {
    console.log();
    console.log(boxen(
      chalk.hex('#EF4444').bold('  License check failed. Exiting.'),
      {padding: 1, margin: 1, borderStyle: 'round', borderColor: '#EF4444'}
    ));
    process.exit(1);
  }

  // ---- UPDATE CHECK ----
  // If local version doesn't match latest, prompt for self-update
  if (HAS_UPDATE && REMOTE_VERSION) {
    await checkAndPromptUpdate(VERSION, REMOTE_VERSION);
  }

  // Build a license info object for the status bar
  const licenseInfo = (() => {
    const lic = loadLicense();
    if (!lic) return { activated: false, type: null };
    return {
      activated: true,
      type: lic.expiresAt ? 'temporary' : 'permanent',
      expiresAt: lic.expiresAt || null,
    };
  })();

  console.clear();
  console.log(await banner(termWidth));
  console.log();
  console.log(statusBar(online, licenseInfo));

  while (true) {
    console.clear();
    console.log(await banner(termWidth));
    console.log();
    console.log(statusBar(online, licenseInfo));
    console.log(menuPanel(termWidth));

    const {menu} = await inquirer.prompt([{
      type: 'list',
      name: 'menu',
      message: '',
      pageSize: MENU.length,
      loop: true,
      choices: MENU.map(it => ({
        name: `${chalk.hex('#F59E0B').bold(`[${it.key}] `)}${chalk.bold(pad(it.label, 18))} ${chalk.gray('· ' + it.desc)}`,
        value: it.key,
      })),
    }]);

    if (menu === '0') {
      // Clear license on exit — next run requires re-entry
      try { clearLicense(); } catch {}
      console.log();
      console.log(boxen(
        chalk.hex('#10B981').bold('  Thanks for using KantongKresek. Goodbye!') + '\n' +
        chalk.gray('  License cleared — you will need to activate again next time.'),
        {
          padding: 1,
          margin: 1,
          borderStyle: 'round',
          borderColor: '#10B981',
        }
      ));
      process.exit(0);
    }

    const found = MENU.find(m => m.key === menu);

    // Menu 3: sub-pick database version before running
    if (menu === '3') {
      console.log();
      const DB_CHOICES = [
        {key: '1', file: 'ykpw144-155.sql',  label: '14*-155 database',     desc: 'Schema + procedures (pw_new compatible)'},
        {key: '2', file: 'ykpw16*-17*.sql',   label: '16*-17_ Database',     desc: 'Schema only (ykpw compatible)'},
      ];
      const {dbChoice} = await inquirer.prompt([{
        type: 'list',
        name: 'dbChoice',
        message: chalk.hex('#7C3AED').bold('  Pilih database yang akan di-install:'),
        pageSize: DB_CHOICES.length + 2,
        choices: [
          ...DB_CHOICES.map(d => ({
            name: `${chalk.hex('#F59E0B').bold(`[${d.key}] `)}${chalk.bold(pad(d.label, 18))} ${chalk.gray('· ' + d.desc)}`,
            value: d.file,
          })),
          {name: chalk.gray('  ↩ Cancel (back to menu)'), value: '__cancel'},
        ],
      }]);
      if (dbChoice === '__cancel') {
        await footerPrompt();
        continue;
      }

      console.log(chalk.gray(`\n  Running: Install Database (${dbChoice})\n`));
      try {
        await runScripts([{script: 'database.sh', args: [dbChoice]}]);
        console.log(chalk.hex('#10B981').bold('\n  ✓ Done!'));
      } catch (e) {
        console.log(chalk.hex('#EF4444').bold('\n  ✗ Script aborted.\n'));
      }
      await footerPrompt();
      continue;
    }

    const target = found?.script || found?.scripts;
    if (!target) {
      console.log(chalk.red('  Unknown menu option.\n'));
      await footerPrompt();
      continue;
    }

    console.log(chalk.gray(`\n  Running: ${found.label}\n`));
    try {
      await runScripts(target);
      console.log(chalk.hex('#10B981').bold('\n  ✓ Done!'));
    } catch (e) {
      console.log(chalk.hex('#EF4444').bold('\n  ✗ Script aborted.\n'));
    }
    await footerPrompt();
  }
}

main().catch(e => {
  console.error(chalk.red('Fatal: '), e?.message || e);
  process.exit(1);
});
