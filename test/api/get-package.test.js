import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

const BASE_URL = process.env.PUBLIC_REPO_URL || 'http://localhost:8080/exist/apps/public-repo';

describe('/public/{filename}.xar endpoint', () => {
    it('should return 404 for non-existent package', async () => {
        const res = await fetch(`${BASE_URL}/public/nonexistent-package-99.99.99.xar`);
        assert.equal(res.status, 404);
    });

    it('should return structured error XML for non-existent package', async () => {
        const res = await fetch(`${BASE_URL}/public/nonexistent-package-99.99.99.xar`);
        assert.equal(res.status, 404);
        const text = await res.text();
        assert.ok(text.includes('<error>'), 'Expected XML error response');
    });

    it('should return 404 for non-existent zip package', async () => {
        const res = await fetch(`${BASE_URL}/public/nonexistent-package-99.99.99.xar.zip`);
        assert.equal(res.status, 404);
    });
});
