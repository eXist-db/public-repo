import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const BASE_URL = process.env.PUBLIC_REPO_URL || 'http://localhost:8080/exist/apps/public-repo';
const __dirname = dirname(fileURLToPath(import.meta.url));
const XAR_PATH = join(__dirname, '..', 'cypress', 'fixtures', 'test-app.xar');

describe('publish endpoint CSRF protection', () => {
    let sessionCookie;
    const ownOrigin = new URL(BASE_URL).origin;

    async function buildUpload() {
        const xarBinary = readFileSync(XAR_PATH);
        const blob = new Blob([xarBinary], { type: 'application/octet-stream' });
        const formData = new FormData();
        formData.append('files[]', blob, 'test-app.xar');
        return formData;
    }

    async function login() {
        const params = new URLSearchParams();
        params.append('user', 'repo');
        params.append('password', 'repo');
        const res = await fetch(`${BASE_URL}/admin`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: params.toString(),
            redirect: 'manual'
        });
        const cookies = res.headers.getSetCookie?.() || [];
        return cookies.join('; ');
    }

    it('logs in for CSRF tests', async () => {
        sessionCookie = await login();
        assert.ok(sessionCookie, 'Expected session cookie after login');
    });

    it('rejects cookie-auth upload with no Origin or Referer (403)', async () => {
        const res = await fetch(`${BASE_URL}/publish`, {
            method: 'POST',
            headers: { 'Cookie': sessionCookie },
            body: await buildUpload()
        });
        assert.equal(res.status, 403, 'Expected 403 for missing Origin');
    });

    it('rejects cookie-auth upload with mismatched Origin (403)', async () => {
        const res = await fetch(`${BASE_URL}/publish`, {
            method: 'POST',
            headers: { 'Cookie': sessionCookie, 'Origin': 'https://evil.example.com' },
            body: await buildUpload()
        });
        assert.equal(res.status, 403, 'Expected 403 for cross-origin upload');
    });

    it('accepts cookie-auth upload with matching Origin (200)', async () => {
        const res = await fetch(`${BASE_URL}/publish`, {
            method: 'POST',
            headers: { 'Cookie': sessionCookie, 'Origin': ownOrigin },
            body: await buildUpload()
        });
        assert.equal(res.status, 200, `Expected 200 for same-origin upload, got ${res.status}`);
    });

    it('accepts cookie-auth upload with matching Referer (200)', async () => {
        const res = await fetch(`${BASE_URL}/publish`, {
            method: 'POST',
            headers: { 'Cookie': sessionCookie, 'Referer': `${ownOrigin}/exist/apps/public-repo/admin` },
            body: await buildUpload()
        });
        assert.equal(res.status, 200, `Expected 200 for matching-Referer upload, got ${res.status}`);
    });

    it('accepts HTTP Basic auth upload without Origin (200)', async () => {
        const auth = 'Basic ' + Buffer.from('repo:repo').toString('base64');
        const res = await fetch(`${BASE_URL}/publish`, {
            method: 'POST',
            headers: { 'Authorization': auth },
            body: await buildUpload()
        });
        assert.equal(res.status, 200, `Expected 200 for Basic-auth upload (CLI client), got ${res.status}`);
    });
});
