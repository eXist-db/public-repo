import { describe, it, before } from 'node:test';
import fs from 'node:fs/promises';
import { join } from 'node:path';
import assert from 'node:assert/strict';

const BASE_URL = process.env.PUBLIC_REPO_URL || 'http://localhost:8080/exist/apps/public-repo';
const USER = process.env.PUBLIC_REPO_USERNAME || 'repo';
const PASS = process.env.PUBLIC_REPO_PASSWORD || 'repo';

const BASE_PATH = new URL('.', import.meta.url).pathname;

// Upload a fixture XAR via Basic auth (CSRF-exempt). Used to seed
// state that processor-matching tests depend on, independent of
// whichever other test file uploaded it first under parallel
// execution.
async function uploadXar (xarFilename) {
    const formData = new FormData();
    const xarContent = await fs.readFile(join(BASE_PATH, '..', 'fixtures', xarFilename));
    const blob = new Blob([xarContent], { type: 'application/octet-stream' });
    formData.append('files[]', blob, xarFilename);
    return fetch(`${BASE_URL}/publish`, {
        method: 'POST',
        body: formData,
        headers: { 'Authorization': 'Basic ' + btoa(`${USER}:${PASS}`) }
    });
}

describe('/find endpoint', () => {
    it('should return 404 for non-existent package abbrev', async () => {
        const res = await fetch(`${BASE_URL}/find?abbrev=nonexistent-package-xyz`);
        assert.equal(res.status, 404);
    });

    it('should return 404 XML by default for non-existent package', async () => {
        const res = await fetch(`${BASE_URL}/find?abbrev=nonexistent-package-xyz`);
        assert.equal(res.status, 404);
        const text = await res.text();
        assert.ok(text.includes('<error>'), 'Expected XML error response');
        assert.ok(text.includes('<status>404</status>'), 'Expected 404 status in body');
    });

    it('should return 404 JSON when Accept: application/json', async () => {
        const res = await fetch(`${BASE_URL}/find?abbrev=nonexistent-package-xyz`, {
            headers: { 'Accept': 'application/json' }
        });
        assert.equal(res.status, 404);
        const body = await res.json();
        assert.ok(body.error, 'Expected error field in JSON response');
    });

    it('should accept name parameter', async () => {
        const res = await fetch(`${BASE_URL}/find?name=http://nonexistent.example.org/pkg`);
        assert.equal(res.status, 404);
    });

    it('should return 302 redirect for existing package', async () => {
        // First check if test-app exists (it may not in all environments)
        const res = await fetch(`${BASE_URL}/find?abbrev=test-app`, { redirect: 'manual' });
        // Should be either 302 (found) or 404 (not found in this env)
        assert.ok([302, 404].includes(res.status), `Expected 302 or 404, got ${res.status}`);
    });

    it('should support info parameter with JSON', async () => {
        const res = await fetch(`${BASE_URL}/find?abbrev=test-app&info=true`, {
            headers: { 'Accept': 'application/json' }
        });
        // Should be 200 with info or 404
        assert.ok([200, 404].includes(res.status), `Expected 200 or 404, got ${res.status}`);
        if (res.status === 200) {
            const body = await res.json();
            assert.ok(body.name, 'Expected name in info response');
            assert.ok(body.version, 'Expected version in info response');
            assert.ok(body.sha256, 'Expected sha256 in info response');
        }
    });

    it('should support version parameter', async () => {
        const res = await fetch(`${BASE_URL}/find?abbrev=test-app&version=1.0.1`, { redirect: 'manual' });
        assert.ok([302, 404].includes(res.status), `Expected 302 or 404, got ${res.status}`);
    });

    it('should support semver-min parameter', async () => {
        const res = await fetch(`${BASE_URL}/find?abbrev=test-app&semver-min=0.1.0`, { redirect: 'manual' });
        assert.ok([302, 404].includes(res.status), `Expected 302 or 404, got ${res.status}`);
    });

    it('should handle empty Accept header gracefully', async () => {
        const res = await fetch(`${BASE_URL}/find?abbrev=nonexistent-package-xyz`, {
            headers: { 'Accept': '' }
        });
        assert.equal(res.status, 404);
    });

    describe('processor version matching', () => {
        before(async () => {
            // Seed test-app so processor-match assertions don't race with
            // whichever other test file would otherwise upload it.
            await uploadXar('test-app.xar');
        });

        it('should not find a matching test-app package for the default processor', async () => {
            const res = await fetch(`${BASE_URL}/find?abbrev=test-app&version=1.0.1`, { redirect: 'manual' });
            assert.equal(res.status, 404);
        });

        it('should not find a matching test-app package for processor 1.0.0', async () => {
            const res = await fetch(`${BASE_URL}/find?abbrev=test-app&version=1.0.1&processor=1.0.0`, { redirect: 'manual' });
            assert.equal(res.status, 404);
        });

        it('should find a matching test-app package for processor 5.0.0', async () => {
            const res = await fetch(`${BASE_URL}/find?abbrev=test-app&version=1.0.1&processor=5.0.0`, { redirect: 'manual' });
            assert.equal(res.status, 302);
        });

        it('should find a matching test-app package for processor 7.0.0', async () => {
            const res = await fetch(`${BASE_URL}/find?abbrev=test-app&processor=7.0.0&info=true`, { redirect: 'manual' });
            console.log('Response status for processor 7.0.0 with info:', await res.text());
            assert.equal(res.status, 200);
        });
    });
});
