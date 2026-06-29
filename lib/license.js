import {createHash, createHmac, randomBytes} from 'crypto';
import {readFileSync, writeFileSync, existsSync, mkdirSync, unlinkSync} from 'fs';
import {join, dirname} from 'path';
import {homedir} from 'os';

const LICENSE_FILE = join(homedir(), '.kantongkresek', 'license.json');
const SECRET = process.env.KANTONGKRESEK_SECRET || 'KK-DEV-SECRET-7c3aed06b6d4f59e0b1a2c3d4e5f6a7b';

// License key format:
//   kantong-XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX_kresek
//   4 blocks of 8 uppercase hex chars each
//
// Layout:
//   Block 1: 32-bit owner hash (unique per owner name)
//   Block 2: 32-bit issue nonce (random per issuance)
//   Block 3: 32-bit expiry flag — 0 = never, else Unix epoch (32-bit)
//   Block 4: 32-bit HMAC-SHA256 of Blocks 1-3

const KEY_RE = /^kantong-([0-9A-F]{8})-([0-9A-F]{8})-([0-9A-F]{8})-([0-9A-F]{8})_kresek$/i;

// ---------------------------------------------------------------------------
// Block helpers
// ---------------------------------------------------------------------------
function blockOf(str) {
  return createHash('sha256').update(String(str)).digest('hex').slice(0, 8).toUpperCase();
}

function isValidKey(k) {
  if (!k || typeof k !== 'string') return false;
  return KEY_RE.test(k.trim());
}

// ---------------------------------------------------------------------------
// Generate universal license key
// ---------------------------------------------------------------------------
export function generateLicense({owner = 'default', expiryDays = null, secret = SECRET} = {}) {
  if (!owner || typeof owner !== 'string') {
    throw new Error('owner must be a non-empty string');
  }

  const issuedAtMs = Date.now();
  const block1 = blockOf(owner); // hash of owner name
  const block2 = blockOf(issuedAtMs.toString()).slice(0, 8); // random-ish nonce
  let block3;
  const expiresAtMs = expiryDays ? issuedAtMs + expiryDays * 86400000 : 0;

  // 32-bit expiry: cast to uint32
  if (expiresAtMs > 0 && expiresAtMs <= 0xFFFFFFFF * 1000) {
    const epochSec = Math.floor(expiresAtMs / 1000) >>> 0;
    block3 = epochSec.toString(16).toUpperCase().padStart(8, '0');
  } else {
    block3 = expiresAtMs > 0 ? 'FFFFFFFF' : '00000000';
  }

  // HMAC signature over blocks 1, 2, 3
  const payload = block1 + '-' + block2 + '-' + block3;
  const block4 = createHmac('sha256', secret).update(payload).digest('hex').slice(0, 8).toUpperCase();

  const key = `kantong-${block1}-${block2}-${block3}-${block4}_kresek`;

  return {
    key,
    owner,
    issuedAt: new Date(issuedAtMs).toISOString(),
    expiresAt: expiresAtMs > 0 ? new Date(expiresAtMs).toISOString() : null,
  };
}

// ---------------------------------------------------------------------------
// Verify license key (works on any machine — signature only)
// ---------------------------------------------------------------------------
export function verifyLicense(licenseKey, secret = SECRET) {
  try {
    const key = String(licenseKey || '').trim();
    if (!isValidKey(key)) {
      return {
        ok: false,
        reason: 'Format tidak valid. Gunakan: kantong-XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX_kresek',
      };
    }

    const m = key.match(KEY_RE);
    const [, block1, block2, block3, block4] = m.map(s => s.toUpperCase());
    const payload = block1 + '-' + block2 + '-' + block3;
    const expectedSig = createHmac('sha256', secret).update(payload).digest('hex').slice(0, 8).toUpperCase();

    if (block4 !== expectedSig) {
      return {
        ok: false,
        reason: 'Tanda tangan lisensi tidak valid (lisensi diubah atau secret salah)',
      };
    }

    // Parse expiry
    const expirySec = parseInt(block3, 16) >>> 0;
    const expiresAt = expirySec > 0 ? new Date(expirySec * 1000).toISOString() : null;
    if (expirySec > 0 && Date.now() > expirySec * 1000) {
      return {
        ok: false,
        reason: `Lisensi sudah kedaluwarsa pada ${expiresAt}`,
      };
    }

    return {
      ok: true,
      block1,
      block2,
      block3,
      block4,
      expiresAt,
    };
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