#!/usr/bin/env node
// generate_license.js — Universal license key generator for KantongKresek
// Usage:
//   node scripts/generate_license.js --owner "Customer Name" [--expiry 365] [--count 1] [--secret <secret>]
//   node scripts/generate_license.js --no-expiry --owner "Customer Name"
//
// Output goes to stdout. Supports batch generation with --count.

import {generateLicense} from '../lib/license.js';
import chalk from 'chalk';

const BR = chalk.bgHex('#7C3AED').hex('#FFFFFF').bold;
const CY = chalk.hex('#06B6D4').bold;
const GN = chalk.hex('#10B981');
const YL = chalk.hex('#F59E0B');
const RD = chalk.hex('#EF4444');
const GM = chalk.gray;

function parseArgs(argv) {
  const out = {owner: null, expiry: null, count: 1, secret: null};
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--owner' || a === '-o') out.owner = argv[++i];
    else if (a === '--expiry' || a === '-e') out.expiry = parseInt(argv[++i], 10);
    else if (a === '--no-expiry') out.expiry = 0;
    else if (a === '--count' || a === '-c') out.count = parseInt(argv[++i], 10) || 1;
    else if (a === '--secret' || a === '-s') out.secret = argv[++i];
    else if (a === '--help' || a === '-h') {
      printHelp();
      process.exit(0);
    } else if (!out.owner) {
      out.owner = a;
    }
  }
  return out;
}

function printHelp() {
  console.log(`
${BR('  KANTONGKRESEK LICENSE GENERATOR  ')}

Usage:
  node scripts/generate_license.js [options]

Options:
  -o, --owner <name>     Owner / customer name (required)
  -e, --expiry <days>    Expiry in days (e.g. 365 for 1 year)
      --no-expiry        License never expires
  -c, --count <n>        Generate N keys (default: 1)
  -s, --secret <secret>  Override the signing secret
  -h, --help             Show this help

Examples:
  node scripts/generate_license.js --owner "PT. ABC"
  node scripts/generate_license.js --owner "Toko X" --expiry 365
  node scripts/generate_license.js --owner "Bulk" --no-expiry --count 10

Environment:
  KANTONGKRESEK_SECRET     Override signing secret
`);
}

const args = parseArgs(process.argv);

console.log();
console.log(BR('  KANTONGKRESEK LICENSE GENERATOR  '));
console.log(GM('  Generate universal license keys\n'));

if (!args.owner) {
  console.log(RD('  Error: --owner <name> is required'));
  printHelp();
  process.exit(1);
}

const secret = args.secret || process.env.KANTONGKRESEK_SECRET || undefined;

console.log(GM(`  Owner     : ${args.owner}`));
console.log(GM(`  Expiry    : ${args.expiry === 0 ? 'never' : (args.expiry ? args.expiry + ' days' : 'never')}`));
console.log(GM(`  Count     : ${args.count}`));
console.log(GM(`  Secret    : ${secret ? 'custom' : 'default'}`));
console.log();

for (let i = 0; i < args.count; i++) {
  const expiryArg = args.expiry === 0 ? null : args.expiry;
  const lic = generateLicense({
    owner: args.count > 1 ? `${args.owner} #${i + 1}` : args.owner,
    expiryDays: expiryArg,
    secret,
  });

  console.log(YL(`  ${lic.key}`));
  console.log(GM(`  └─ issued ${lic.issuedAt}${lic.expiresAt ? ' → expires ' + lic.expiresAt : ' → never expires'}`));
}

console.log();
console.log(GM(`  ${args.count} license key(s) generated. Distribute to your customer.`));
console.log(GM('  Key works on any machine — verification is signature-only.'));
console.log();