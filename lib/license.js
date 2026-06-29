import {createHash, createHmac, randomBytes} from 'crypto';
import {readFileSync, writeFileSync, existsSync, mkdirSync, unlinkSync} from 'fs';
import {join} from 'path';
import {homedir} from 'os';
import {execSync} from 'child_process';

const LICENSE_FILE = join(homedir(), '.kantongkresek', 'license.json');
const SECRET = process.env.KANTONGKRESEK_SECRET || 'KK-DEV-SECRET-7c3aed06b6d4f59e0b1a2c3d4e5f6a7b';

// Crockford-ish base32 alphabet (no I/O/0/1 to avoid visual confusion)
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

// ---------------------------------------------------------------------------
// Machine fingerprint
// ---------------------------------------------------------------------------
export function fingerprintFromData(data) {
  const raw = (data.hostname || '') + '|' + (data.mac || '') + '|' + (data.machineId || '');
  return createHash('sha256').update(raw).digest('hex');
}

export function getFingerprint() {
  const out = {};
  try { out.hostname = execSync('hostname', {encoding: 'utf8'}).trim(); } catch {}
  try {
    const mac = execSync("cat /sys/class/net/*/address 2>/dev/null | grep -v '^00:00:00:00:00:00$' | head -1", {encoding: 'utf8'}).trim();
    if (mac) out.mac = mac;
  } catch {}
  try {
    for (const p of ['/etc/machine-id', '/var/lib/dbus/machine-id']) {
      if (existsSync(p)) { out.machineId = readFileSync(p, 'utf8').trim(); break; }
    }
  } catch {}
  return out;
}

// ---------------------------------------------------------------------------
// License key helpers (format: KK-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX)
// ---------------------------------------------------------------------------
function toBlocks(hex) {
  const groups = [];
  for (let i = 0; i < hex.length; i += 4) {
    groups.push(hex.slice(i, i + 4).toUpperCase());
  }
  return groups.slice(0, 8);
}

function isValidBlock(s) {
  return /^[A-Z0-9]{4}$/.test(s);
}

function isValidKey(k) {
  if (!k || typeof k !== 'string') return false;
  const clean = k.trim().toUpperCase().replace(/^KK-/, '');
  const blocks = clean.split('-');
  return blocks.length === 8 && blocks.every(isValidBlock);
}

// ---------------------------------------------------------------------------
// Generate a new license for a given fingerprint
// ---------------------------------------------------------------------------
export function generateLicense(fingerprintHex, secret = SECRET) {
  const clean = String(fingerprintHex || '').toLowerCase().replace(/[^a-f0-9]/g, '');
  if (clean.length < 8) throw new Error('Fingerprint must be at least 8 hex chars');

  const payload = clean.slice(0, 24).padEnd(24, '0');
  const sig = createHmac('sha256', secret).update(payload).digest('hex').slice(0, 8);
  const combined = (payload + sig).slice(0, 32);
  const blocks = toBlocks(combined);
  return 'KK-' + blocks.join('-');
}

// ---------------------------------------------------------------------------
// Verify a license key against a fingerprint
// ---------------------------------------------------------------------------
export function verifyLicense(licenseKey, fingerprintHex, secret = SECRET) {
  try {
    const key = String(licenseKey || '').trim();
    if (!isValidKey(key)) {
      return {ok: false, reason: 'Format tidak valid. Gunakan format: KK-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX'};
    }

    const clean = key.toUpperCase().replace(/^KK-/, '');
    const blocks = clean.split('-').map(s => s.trim());
    const combined = blocks.join('');
    const payload = combined.slice(0, 24);
    const sig = combined.slice(24, 32);

    const cleanFp = String(fingerprintHex || '').toLowerCase().replace(/[^a-f0-9]/g, '');
    const expectedFp = cleanFp.slice(0, 24).padEnd(24, '0');

    if (payload.toLowerCase() !== expectedFp.toLowerCase()) {
      return {ok: false, reason: 'Lisensi tidak cocok dengan mesin ini (machine fingerprint mismatch)'};
    }

    const expectedSig = createHmac('sha256', secret).update(payload.toLowerCase()).digest('hex').slice(0, 8);
    if (sig.toLowerCase() !== expectedSig.toLowerCase()) {
      return {ok: false, reason: 'Tanda tangan lisensi tidak valid (lisensi diubah atau secret salah)'};
    }

    return {ok: true, fingerprint: payload, signature: sig};
  } catch (e) {
    return {ok: false, reason: e.message};
  }
}

// ---------------------------------------------------------------------------
// Persisted license state
// ---------------------------------------------------------------------------
export function loadLicense() {
  try {
    if (!existsSync(LICENSE_FILE)) return null;
    return JSON.parse(readFileSync(LICENSE_FILE, 'utf8'));
  } catch {
    return null;
  }
}

export function saveLicense(data) {
  const dir = dirname(LICENSE_FILE);
  if (!existsSync(dir)) mkdirSync(dir, {recursive: true, mode: 0o700});
  writeFileSync(LICENSE_FILE, JSON.stringify(data, null, 2), {mode: 0o600});
}

export function clearLicense() {
  try {
    if (existsSync(LICENSE_FILE)) unlinkSync(LICENSE_FILE);
  } catch {}
}

export function licenseFilePath() {
  return LICENSE_FILE;
}
