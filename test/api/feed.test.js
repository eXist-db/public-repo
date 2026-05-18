import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

const BASE_URL = process.env.PUBLIC_REPO_URL || 'http://localhost:8080/exist/apps/public-repo';

describe('/feed.xml endpoint', () => {
    it('should return valid Atom feed', async () => {
        const res = await fetch(`${BASE_URL}/feed.xml`);
        assert.equal(res.status, 200);
        const contentType = res.headers.get('content-type');
        assert.ok(
            contentType.includes('atom') || contentType.includes('xml'),
            `Expected Atom/XML content-type, got ${contentType}`
        );
    });

    it('should contain Atom feed root element', async () => {
        const res = await fetch(`${BASE_URL}/feed.xml`);
        const text = await res.text();
        assert.ok(text.includes('<feed'), 'Expected <feed> root element');
        assert.ok(text.includes('xmlns="http://www.w3.org/2005/Atom"'), 'Expected Atom namespace');
    });

    it('should contain required Atom feed elements', async () => {
        const res = await fetch(`${BASE_URL}/feed.xml`);
        const text = await res.text();
        assert.ok(text.includes('<title>'), 'Expected <title> element');
        assert.ok(text.includes('<id>'), 'Expected <id> element');
        assert.ok(text.includes('<updated>'), 'Expected <updated> element');
    });

    it('should contain entry elements with expected structure if packages exist', async () => {
        const res = await fetch(`${BASE_URL}/feed.xml`);
        const text = await res.text();
        if (text.includes('<entry>') || text.includes('<entry ')) {
            assert.ok(text.includes('<title>'), 'Expected <title> in entry');
            assert.ok(text.includes('<link'), 'Expected <link> in entry');
            assert.ok(text.includes('<content'), 'Expected <content> in entry');
        }
    });
});
