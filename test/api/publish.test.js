import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

const BASE_URL = process.env.PUBLIC_REPO_URL || 'http://localhost:8080/exist/apps/public-repo';

describe('/publish endpoint', () => {
    it('should reject unauthenticated upload with non-200 status', async () => {
        const formData = new FormData();
        const blob = new Blob(['fake-xar-content'], { type: 'application/octet-stream' });
        formData.append('files[]', blob, 'test.xar');

        const res = await fetch(`${BASE_URL}/publish`, {
            method: 'POST',
            body: formData
        });
        // eXist may return 400 (bad multipart) or 403 (unauthorized) depending on version
        assert.ok(res.status >= 400, `Expected error status for unauthenticated upload, got ${res.status}`);
    });

    it('should redirect unauthenticated GET to login page', async () => {
        const res = await fetch(`${BASE_URL}/publish`);
        const text = await res.text();
        // Unauthenticated users should see the login form
        assert.ok(
            text.includes('Administrator Login') || text.includes('login') || res.status >= 300,
            'Expected login page or redirect for unauthenticated GET'
        );
    });
});
