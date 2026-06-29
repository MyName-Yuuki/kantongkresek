#!/usr/bin/env node
// generate_license.js — License key generator for KantongKresek
// Usage: node scripts/generate_license.js [fingerprint-hex] [secret]
//
// Without args: auto-detect fingerprint from this machine
// With args: generate key for a specific fingerprint (useful for remote activation)

import {execSync} from 'child_process';
import {createHash} from 'crypto';
import {readFileSync, existsSync} from 'fs';
import {generateLicense, fingerprintFromData, getFingerprint} from '../lib/license.js';
import chalk from 'chalk';

const BR = chalk.bgHex('#7C3AED').hex('#FFFFFF').bold;
const CY = chalk.hex('#06B6D4').bold;
const GN = chalk.hex('#10B981');
const YL = chalk.hex('#F59E0B');
const RD = chalk.hex('#EF4444');
const GM = chalk.gray;

console.log();
console.log(BR('  KANTONGKRESEK LICENSE GENERATOR  '));
console.log(GM('  Generate a license key for KantongKresek installation\n'));

// --- Determine fingerprint ---
let fpData;
const argFp = process.argv[2];

if (argFp) {
  // Manual fingerprint provided
  const clean = argFp.toLowerCase().replace(/[^a-f0-9]/g, '');
  if (clean.length < 16) {
    console.error(RD('  Error: fingerprint hex must be at least 16 chars'));
    process.exit(1);
  }
  fpData = {hostname: 'remote', mac: 'manual', machineId: clean};
  console.log(YL('  Manual fingerprint mode'));
  console.log(GM('  Fingerprint: ' + clean.slice(0, 24) + '...\n'));
} else {
  // Auto-detect from this machine
  fpData = getFingerprint();
  if (!fpData.hostname && !fpData.mac && !fpData.machineId) {
    // Fallback: use hostname as machine id
    fpData.hostname = execSync('hostname', {encoding: 'utf8'}).trim();
    fpData.machineId = fpData.hostname;
  }
  console.log(GN('  Auto-detected from this machine'));
  console.log(GM(`  Hostname: ${fpData.hostname || '(unknown)'}`));
  console.log(GM(`  MAC:      ${fpData.mac || '(unknown)'}`));
  console.log(GM(`  MachineID: ${fpData.machineId || '(unknown)'}`));
  console.log();
}

// Compute SHA-256 fingerprint
const fpHex = fingerprintFromData(fpData);
console.log(GM('  SHA256 fingerprint: ' + fpHex));
console.log();

// Secret
const secret = process.argv[3] || process.env.KANTONGKRESEK_SECRET || 'KK-DEV-SECRET-7c3aed06b6d4f59e0b1a2c3d4e5f6a7b';
if (process.argv[3]) {
  console.log(YL('  Using custom secret'));
} else {
  console.log(GM('  Using default secret'));
  console.log(GM('  Override with: KANTONGKRESEK_SECRET=<secret> or pass as arg 3\n'));
}

// Generate
const key = generateLicense(fpHex, secret);

console.log();
console.log(BR('  GENERATED LICENSE KEY  '));
console.log();
console.log(`  ${YL(key)}`);
console.log();
console.log(GM('  Copy this key and give it to your customer.'));
console.log(GM('  When they run "kantongkresek", paste this key to activate.'));
console.log(GM('  The key is bound to the machine fingerprint above.\n'));

// Also output machine data for records
console.log(GM('  Machine data (for your records):'));
console.log(`  ${GM(JSON.stringify(fpData))}`);
console.log(`  ${GM('Fingerprint: ' + fpHex)}`);
console.log();
