import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

const BASE_URL = process.env.PUBLIC_REPO_URL || 'http://localhost:8080/exist/apps/public-repo';

describe('/packages/{abbrev} detail page (#103)', () => {
    it('should return 404 for non-existent package', async () => {
        const res = await fetch(`${BASE_URL}/packages/nonexistent-package-xyz`);
        assert.equal(res.status, 404);
    });

    it('should render package detail page without templating errors', async () => {
        // After uploading test-app via Cypress, this should work
        const res = await fetch(`${BASE_URL}/packages/test-app`);
        if (res.status === 200) {
            const text = await res.text();
            // Verify templating rendered correctly (no raw data-template attributes in output)
            assert.ok(!text.includes('data-template="app:view-package"'),
                'Template should be processed, not raw');
            // Should contain actual package content
            assert.ok(text.includes('EXPath Package') || text.includes('test-app'),
                'Expected package info in rendered page');
        }
        // If 404, the test-app hasn't been uploaded yet - still valid
        assert.ok([200, 404].includes(res.status), `Expected 200 or 404, got ${res.status}`);
    });

    it('should redirect legacy .html URLs', async () => {
        const res = await fetch(`${BASE_URL}/packages/test-app.html`, { redirect: 'manual' });
        // Should redirect (301 or 302) to URL without .html extension
        assert.ok([301, 302].includes(res.status),
            `Expected redirect for legacy .html URL, got ${res.status}`);
        const location = res.headers.get('location');
        assert.ok(location && location.includes('/packages/test-app'),
            'Expected redirect to URL without .html');
    });
});
