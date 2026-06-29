#!/usr/bin/env node
import inquirer from 'inquirer';
import chalk from 'chalk';
import boxen from 'boxen';
import figlet from 'figlet';
import ora from 'ora';
import {execSync} from 'child_process';
import {hrtime} from 'process';

const GITHUB_USER = 'MyName-Yuuki';
const GITHUB_REPO = 'kantongkresek';
const BRANCH      = 'main';
const BASE_URL    = `https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${BRANCH}/scripts/`;
const VERSION     = '1.0.0';

const MENU = [
  {key: '1', label: 'Install Base',         desc: 'phpMyAdmin, Java, MariaDB',            script: 'install_base.sh'},
  {key: '2', label: 'Configurations',       desc: 'Nginx + PHP-FPM + Packages',           scripts: ['configurations.sh', 'configurations_base_I.sh']},
  {key: '3', label: 'Install Database',     desc: 'Provision database schema',            script: 'database.sh'},
  {key: '4', label: 'Install SSL',          desc: 'Let\'s Encrypt via Certbot',           script: 'install_ssl_certbot.sh'},
  {key: '0', label: 'Exit',                 desc: 'Close the installer',                  script: null},
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
      lines.push(chalk.gray(`  v${VERSION}  •  SSH Friendly  •  Server Deploy`));
      resolve(lines.join('\n'));
    });
  });
}

function statusBar(online) {
  const items = [
    (online ? chalk.hex('#10B981').bold('● ONLINE') : chalk.hex('#EF4444').bold('● OFFLINE')),
    chalk.gray('•'),
    chalk.hex('#10B981').bold(`user:${process.env.USER || 'Kantong'}`),
    chalk.gray('•'),
    chalk.hex('#F59E0B').bold(`host:${process.env.HOSTNAME || 'Kresek'}`),
    chalk.gray('•'),
    chalk.hex('#9CA3AF').bold(`s/${GITHUB_REPO}`),
  ];
  return boxen(items.join('  '), {
    padding: {left: 1, right: 1},
    borderStyle: 'single',
    borderColor: online ? '#10B981' : '#EF4444',
  });
}

function menuPanel(termWidth) {
  const W = Math.min(termWidth - 6, 62);
  const items = MENU.map(it => {
    const key = chalk.hex('#F59E0B').bold(`[${it.key}]`);
    const name = chalk.bold(pad(it.label, 20));
    const sep = chalk.gray('·');
    const desc = chalk.gray(it.desc);
    return `  ${key} ${name} ${sep} ${desc}`;
  });
  const separator = chalk.gray('  ' + '─'.repeat(W - 4));
  const footer = chalk.gray(`  ${'↑/↓ to navigate  •  Enter to select  •  or type the number'}`);

  return boxen([
    chalk.hex('#F59E0B').bold('  ✦ MAIN MENU'),
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
  for (const name of list) {
    const spinner = ora({
      text: '  ' + chalk.cyan.bold('▶ FETCHING') + '  ' + chalk.yellow(name),
      color: 'cyan',
      spinner: 'dots',
    }).start();

    const t0 = hrtime.bigint();
    try {
      execSync(`bash <(curl -fsSL ${BASE_URL}${name})`, {
        stdio: 'inherit',
        shell: '/bin/bash',
      });
      const ms = Number(hrtime.bigint() - t0) / 1e6;
      spinner.succeed(
        chalk.hex('#10B981').bold('  ✓ ' + name) +
        chalk.gray(`  (${(ms / 1000).toFixed(1)}s)`)
      );
    } catch (e) {
      spinner.fail(chalk.hex('#EF4444').bold('  ✗ ' + name));
      throw e;
    }
  }
}

async function footerPrompt() {
  await inquirer.prompt([{
    type: 'input',
    name: 'c',
    message: chalk.gray('  Press Enter to return to menu...'),
  }]);
}

async function main() {
  const termWidth = process.stdout.columns || 80;
  const online = await checkOnline();

  console.clear();
  console.log(await banner(termWidth));
  console.log();
  console.log(statusBar(online));

  while (true) {
    console.clear();
    console.log(await banner(termWidth));
    console.log();
    console.log(statusBar(online));
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
      console.log();
      console.log(boxen(
        chalk.hex('#10B981').bold('  Thanks for using KantongKresek. Goodbye!'),
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
