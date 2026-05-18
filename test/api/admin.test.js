import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const BASE_URL = process.env.PUBLIC_REPO_URL || 'http://localhost:8080/exist/apps/public-repo';
const __dirname = dirname(fileURLToPath(import.meta.url));
const XAR_PATH = join(__dirname, '..', 'cypress', 'fixtures', 'test-app.xar');

describe('admin login, upload, and logout flow', () => {
    let sessionCookie;

    it('should show login page when not authenticated', async () => {
        const res = await fetch(`${BASE_URL}/admin`);
        assert.equal(res.status, 200);
        const text = await res.text();
        assert.ok(text.includes('Administrator Login'), 'Expected login page');
        assert.ok(text.includes('name="user"'), 'Expected user input');
        assert.ok(text.includes('name="password"'), 'Expected password input');
    });

    it('should authenticate with valid credentials', async () => {
        const params = new URLSearchParams();
        params.append('user', 'repo');
        params.append('password', 'repo');

        const res = await fetch(`${BASE_URL}/admin`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: params.toString(),
            redirect: 'manual'
        });

        // Collect session cookies from response
        const cookies = res.headers.getSetCookie?.() || [];
        sessionCookie = cookies.join('; ');

        // Follow through to the admin page with cookies
        const adminRes = await fetch(`${BASE_URL}/admin`, {
            headers: { 'Cookie': sessionCookie }
        });
        const text = await adminRes.text();
        // Should see admin content, not login form
        assert.ok(
            text.includes('Admin') || text.includes('Upload') || text.includes('package-group'),
            'Expected admin page content after login'
        );
    });

    it('should upload a XAR package successfully', async () => {
        assert.ok(sessionCookie, 'Must be logged in first');

        const xarBinary = readFileSync(XAR_PATH);
        const blob = new Blob([xarBinary], { type: 'application/octet-stream' });
        const formData = new FormData();
        formData.append('files[]', blob, 'test-app.xar');

        const origin = new URL(BASE_URL).origin;
        const res = await fetch(`${BASE_URL}/publish`, {
            method: 'POST',
            headers: { 'Cookie': sessionCookie, 'Origin': origin },
            body: formData
        });

        assert.equal(res.status, 200, `Upload failed with status ${res.status}`);
        const body = await res.json();
        assert.ok(body.files, 'Expected files in response');
        assert.ok(body.files.length > 0, 'Expected at least one file');

        // After fix for #133, filename should be versioned: test-app-1.0.1.xar
        const uploadedName = body.files[0].name;
        assert.equal(uploadedName, 'test-app-1.0.1.xar',
            `Expected versioned filename, got "${uploadedName}"`);
        assert.ok(body.files[0].size > 0, 'Expected non-zero file size');
    });

    it('should show uploaded package in listing', async () => {
        assert.ok(sessionCookie, 'Must be logged in first');

        const res = await fetch(`${BASE_URL}/admin`, {
            headers: { 'Cookie': sessionCookie }
        });
        assert.equal(res.status, 200);
        const text = await res.text();
        assert.ok(text.includes('test-app') || text.includes('Test App'),
            'Expected uploaded package in admin listing');
    });

    it('should allow downloading the uploaded package', async () => {
        const res = await fetch(`${BASE_URL}/public/test-app-1.0.1.xar`);
        assert.equal(res.status, 200, 'Expected 200 for uploaded package download');
        const contentType = res.headers.get('content-type');
        assert.ok(contentType.includes('zip') || contentType.includes('octet'),
            `Expected binary content-type, got ${contentType}`);
    });

    it('should find the uploaded package via /find', async () => {
        // test-app requires eXist 4.0.0+, so pass a compatible processor version
        const res = await fetch(`${BASE_URL}/find?abbrev=test-app&processor=7.0.0&info=true`, {
            headers: { 'Accept': 'application/json' }
        });
        assert.equal(res.status, 200, 'Expected package to be findable after upload');
        const body = await res.json();
        assert.equal(body.abbrev, 'test-app');
        assert.equal(body.version, '1.0.1');
        assert.equal(body.path, 'test-app-1.0.1.xar',
            'Expected versioned filename in find response');
    });

    it('should show the package detail page', async () => {
        const res = await fetch(`${BASE_URL}/packages/test-app`);
        assert.equal(res.status, 200);
        const text = await res.text();
        assert.ok(text.includes('Test App') || text.includes('test-app'),
            'Expected package info on detail page');
    });

    it('should list the uploaded package in apps.xml', async () => {
        const res = await fetch(`${BASE_URL}/public/apps.xml?version=4.0.0`);
        assert.equal(res.status, 200);
        const text = await res.text();
        assert.ok(text.includes('test-app'), 'Expected test-app in apps.xml listing');
    });

    it('should log out successfully', async () => {
        assert.ok(sessionCookie, 'Must be logged in first');

        const res = await fetch(`${BASE_URL}/admin?logout=true`, {
            headers: { 'Cookie': sessionCookie },
            redirect: 'manual'
        });

        // After logout, visiting admin should show login page again
        const adminRes = await fetch(`${BASE_URL}/admin`);
        const text = await adminRes.text();
        assert.ok(text.includes('Administrator Login'),
            'Expected login page after logout');
    });
});

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
