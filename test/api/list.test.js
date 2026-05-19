import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

const BASE_URL = process.env.PUBLIC_REPO_URL || 'http://localhost:8080/exist/apps/public-repo';

describe('/public/apps.xml endpoint', () => {
    it('should return XML with apps element', async () => {
        const res = await fetch(`${BASE_URL}/public/apps.xml`);
        assert.equal(res.status, 200);
        const contentType = res.headers.get('content-type');
        assert.ok(contentType.includes('xml'), `Expected XML content-type, got ${contentType}`);
        const text = await res.text();
        assert.ok(text.includes('<apps'), 'Expected <apps> root element');
    });

    it('should include version attribute on apps element', async () => {
        const res = await fetch(`${BASE_URL}/public/apps.xml`);
        const text = await res.text();
        assert.ok(text.includes('version='), 'Expected version attribute on <apps>');
    });

    it('should accept version parameter', async () => {
        const res = await fetch(`${BASE_URL}/public/apps.xml?version=6.0.0`);
        assert.equal(res.status, 200);
        const text = await res.text();
        assert.ok(text.includes('<apps'), 'Expected <apps> root element');
        assert.ok(text.includes('version="6.0.0"'), 'Expected version attribute to reflect parameter');
    });

    it('should contain app elements with expected structure when packages exist', async () => {
        const res = await fetch(`${BASE_URL}/public/apps.xml`);
        const text = await res.text();
        // If there are any packages, they should have basic metadata
        if (text.includes('<app ')) {
            assert.ok(text.includes('<title>'), 'Expected title in app element');
            assert.ok(text.includes('<name>'), 'Expected name in app element');
            assert.ok(text.includes('<version>'), 'Expected version in app element');
        }
        // If no packages exist yet, the empty <apps/> element is still valid
        assert.ok(text.includes('<apps'), 'Expected apps root element');
    });
});
